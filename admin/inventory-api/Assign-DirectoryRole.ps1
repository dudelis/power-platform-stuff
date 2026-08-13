<#
.SYNOPSIS
    Assigns a Microsoft Entra directory role to a service principal at tenant scope.

.DESCRIPTION
    Power Platform inventory access via Azure Resource Graph (the PowerPlatformResources
    table) is authorized based on Microsoft Entra directory role membership - Global
    Administrator, Power Platform Administrator, Dynamics 365 Administrator, Global Reader,
    AI Administrator, or AI Reader. Directory roles can be assigned to service principals
    (not just users), which is what this script does using Microsoft Graph PowerShell.

    Requires the caller to hold Privileged Role Administrator or Global Administrator.

.PARAMETER AppId
    The Application (client) ID of the app registration whose service principal should
    receive the role.

.PARAMETER RoleName
    The display name of the Microsoft Entra built-in directory role to assign.
    Defaults to 'Global Reader' (read-only, least privilege, full inventory visibility).
    Use 'Power Platform Administrator' if write access is also needed.

.EXAMPLE
    .\Assign-DirectoryRole.ps1 -AppId '11111111-2222-3333-4444-555555555555'

    Assigns the Global Reader role to the given service principal at tenant scope.

.EXAMPLE
    .\Assign-DirectoryRole.ps1 -AppId '11111111-2222-3333-4444-555555555555' -RoleName 'Power Platform Administrator'

.NOTES
    Modules: Microsoft.Graph.Authentication, Microsoft.Graph.Applications, Microsoft.Graph.Identity.Governance

    If you have multiple side-by-side versions of these modules installed, run this script
    in a brand-new PowerShell session (no Microsoft.Graph module imported yet). Mixing
    versions in one session causes "Assembly with same name is already loaded" errors,
    since the .NET assemblies behind these modules aren't side-by-side safe once loaded.

    Install/update: Install-Module Microsoft.Graph -Scope CurrentUser
    Clean up old versions: Get-InstalledModule Microsoft.Graph* | Uninstall-Module -AllVersions
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $AppId,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $RoleName = 'Global Reader'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$requiredModules = 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Applications', 'Microsoft.Graph.Identity.Governance'

# Pin every required module to the highest version installed for ALL of them, to avoid mixing
# side-by-side versions in the same session (the root cause of "assembly already loaded" errors).
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

# Only (re-)import modules that aren't already loaded at the pinned version. Re-importing an
# already-loaded module (even with -Force) can't swap out its underlying assembly, so if a
# different version is already loaded, the session is unrecoverable and needs a restart.
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
    throw "No service principal found for application ID '$AppId'. Has the app registration's enterprise application been provisioned yet?"
}

$roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$RoleName'"
if (-not $roleDefinition) {
    throw "No directory role definition found with display name '$RoleName'."
}

$existingAssignment = Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$($servicePrincipal.Id)' and roleDefinitionId eq '$($roleDefinition.Id)'"
if ($existingAssignment) {
    Write-Host "Service principal '$($servicePrincipal.DisplayName)' already has the '$RoleName' role assigned (assignment ID: $($existingAssignment.Id))." -ForegroundColor Yellow
    return
}

if ($PSCmdlet.ShouldProcess($servicePrincipal.DisplayName, "Assign directory role '$RoleName' at tenant scope")) {
    $assignment = New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $servicePrincipal.Id -RoleDefinitionId $roleDefinition.Id -DirectoryScopeId '/'
    Write-Host "Assigned '$RoleName' to '$($servicePrincipal.DisplayName)' (assignment ID: $($assignment.Id))." -ForegroundColor Green
    Write-Host "Role propagation can take a few minutes before new tokens reflect the assignment." -ForegroundColor Yellow
}
