<#
.SYNOPSIS
    Removes a Microsoft Entra directory role assignment from a service principal at tenant scope.

.DESCRIPTION
    Companion to Assign-DirectoryRole.ps1, for revoking a role that's no longer needed - e.g.
    an elevated role granted to test a hypothesis that didn't pan out.

    Requires the caller to hold Privileged Role Administrator or Global Administrator.

.PARAMETER AppId
    The Application (client) ID of the app registration whose service principal should have
    the role removed.

.PARAMETER RoleName
    The display name of the Microsoft Entra built-in directory role to remove.

.EXAMPLE
    .\Remove-DirectoryRole.ps1 -AppId '11111111-2222-3333-4444-555555555555' -RoleName 'Power Platform Administrator'

.NOTES
    Modules: Microsoft.Graph.Authentication, Microsoft.Graph.Applications, Microsoft.Graph.Identity.Governance

    If you have multiple side-by-side versions of these modules installed, run this script
    in a brand-new PowerShell session (no Microsoft.Graph module imported yet).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $AppId,

    [Parameter(Mandatory, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string] $RoleName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$requiredModules = 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Applications', 'Microsoft.Graph.Identity.Governance'

$commonVersion = $null
foreach ($module in $requiredModules) {
    $available = Get-Module -ListAvailable -Name $module
    if (-not $available) {
        throw "Required module '$module' isn't installed. Run: Install-Module Microsoft.Graph -Scope CurrentUser"
    }
    $versions = [System.Collections.Generic.HashSet[version]]::new([version[]]$available.Version)
    if ($null -eq $commonVersion) {
        $commonVersion = $versions
    }
    else {
        $commonVersion.IntersectWith($versions)
    }
}
if (-not $commonVersion -or $commonVersion.Count -eq 0) {
    throw "No single version of $($requiredModules -join ', ') is installed for all modules. Run: Install-Module Microsoft.Graph -Scope CurrentUser -Force to align versions."
}
$pinnedVersion = ($commonVersion | Sort-Object -Descending | Select-Object -First 1)

foreach ($module in $requiredModules) {
    $loaded = Get-Module -Name $module
    if ($loaded) {
        if ($loaded.Version -ne $pinnedVersion) {
            throw "Module '$module' is already loaded at version $($loaded.Version), which doesn't match the pinned version $pinnedVersion. Close this PowerShell session, open a brand-new one, and re-run this script."
        }
        Write-Host "$module already loaded at version $pinnedVersion - skipping import." -ForegroundColor DarkGray
        continue
    }
    Write-Host "Importing $module version $pinnedVersion..." -ForegroundColor DarkCyan
    Import-Module -Name $module -RequiredVersion $pinnedVersion
}

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes 'Application.Read.All', 'RoleManagement.Read.Directory', 'RoleManagement.ReadWrite.Directory' -NoWelcome

$servicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$AppId'"
if (-not $servicePrincipal) {
    throw "No service principal found for application ID '$AppId'."
}

$roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$RoleName'"
if (-not $roleDefinition) {
    throw "No directory role definition found with display name '$RoleName'."
}

$assignment = Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$($servicePrincipal.Id)' and roleDefinitionId eq '$($roleDefinition.Id)'"
if (-not $assignment) {
    Write-Host "Service principal '$($servicePrincipal.DisplayName)' doesn't have the '$RoleName' role assigned - nothing to remove." -ForegroundColor Yellow
    return
}

if ($PSCmdlet.ShouldProcess($servicePrincipal.DisplayName, "Remove directory role '$RoleName'")) {
    Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId $assignment.Id
    Write-Host "Removed '$RoleName' from '$($servicePrincipal.DisplayName)'." -ForegroundColor Green
}
