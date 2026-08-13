<#
.SYNOPSIS
    Lists the Data Loss Prevention (DLP) policies that apply to a specific
    Power Platform environment.

.DESCRIPTION
    Given an environment GUID, this script determines every DLP policy in the
    tenant that applies to it, taking into account all three DLP scoping modes:

        - AllEnvironments   : the policy applies to every environment.
        - OnlyEnvironments  : the policy applies only to a listed set of
                              environments (the environment is directly assigned).
        - ExceptEnvironments: the policy applies to all environments except a
                              listed set (the environment is not in the excluded set).

    For each matching policy it reports why the policy applies via the
    'AppliedVia' column:

        AllEnvironments  -> policy targets all environments
        DirectlyAssigned -> environment is explicitly included (OnlyEnvironments)
        ExcludedSet      -> policy is scoped as "all except", and this
                            environment is not in the excluded list

    Requires the Microsoft.PowerApps.Administration.PowerShell module. The
    script checks for an existing authenticated session and, if none is found,
    triggers an interactive sign-in.

.PARAMETER EnvironmentId
    The GUID of the Power Platform environment to evaluate.

.PARAMETER AsJson
    Emit the results as a JSON string instead of PowerShell objects.

.EXAMPLE
    .\Get-EnvironmentDlpPolicies.ps1 -EnvironmentId '0d1cf9f4-1a2b-3c4d-5e6f-1234567890ab'

    Lists all DLP policies that apply to the given environment as a table.

.EXAMPLE
    .\Get-EnvironmentDlpPolicies.ps1 -EnvironmentId '0d1cf9f4-...' -AsJson

    Returns the same results as JSON, ready to redirect to a file.

.NOTES
    Module: Microsoft.PowerApps.Administration.PowerShell
    Install: Install-Module Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $EnvironmentId,

    [Parameter()]
    [switch] $AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- 1. Ensure the required module is available (check only, do not install) ---
$moduleName = 'Microsoft.PowerApps.Administration.PowerShell'
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    throw "Required module '$moduleName' is not installed. " +
          "Install it with: Install-Module $moduleName -Scope CurrentUser"
}
Import-Module $moduleName -ErrorAction Stop

# --- 2. Ensure we have an authenticated session (interactive fallback) ---
$authenticated = $false
try {
    # A lightweight call that fails if there is no valid session.
    $null = Get-AdminPowerAppEnvironment -ErrorAction Stop
    $authenticated = $true
}
catch {
    $authenticated = $false
}

if (-not $authenticated) {
    Write-Verbose 'No active Power Apps session found. Launching interactive sign-in...'
    Add-PowerAppsAccount -ErrorAction Stop | Out-Null
}

# --- 3. Validate the environment exists ---
try {
    $environment = Get-AdminPowerAppEnvironment -EnvironmentName $EnvironmentId -ErrorAction Stop
}
catch {
    $environment = $null
}

if (-not $environment) {
    throw "The environment cannot be found. No environment with ID '$EnvironmentId' exists in this tenant."
}

# --- 4. Retrieve all DLP policies and evaluate scope against the environment ---
$policies = Get-DlpPolicy -ErrorAction Stop

# Get-DlpPolicy returns an object with a 'value' collection on some module
# versions, and a flat array on others. Normalize to a plain collection.
if ($policies -and ($policies.PSObject.Properties.Name -contains 'value')) {
    $policies = $policies.value
}

$results = foreach ($policy in $policies) {

    # environmentType drives the scoping mode.
    $environmentType = $policy.environmentType

    # The list of environment GUIDs referenced by this policy (empty for AllEnvironments).
    $policyEnvironmentIds = @()
    if ($policy.PSObject.Properties.Name -contains 'environments' -and $policy.environments) {
        $policyEnvironmentIds = @($policy.environments | ForEach-Object { $_.name })
    }

    $containsEnvironment = $policyEnvironmentIds -contains $EnvironmentId

    $appliedVia = switch ($environmentType) {
        'AllEnvironments'    { 'AllEnvironments' }
        'OnlyEnvironments'   { if ($containsEnvironment) { 'DirectlyAssigned' } else { $null } }
        'ExceptEnvironments' { if ($containsEnvironment) { $null } else { 'ExcludedSet' } }
        default              { $null }
    }

    if ($appliedVia) {
        [PSCustomObject]@{
            PolicyName = $policy.displayName
            PolicyId   = $policy.name
            AppliedVia = $appliedVia
        }
    }
}

$results = @($results)

# --- 5. Emit results ---
if ($AsJson) {
    $results | ConvertTo-Json -Depth 4
}
else {
    $results
}
