<#
.SYNOPSIS
    Scans every canvas app in the tenant's Power Platform inventory and determines which
    ones are SharePoint list form customizations, entirely from the service principal
    level - no per-environment permissions are granted manually.

.DESCRIPTION
    Pipeline:
    1. Queries PowerPlatformResources via Azure Resource Graph (Invoke-PowerPlatformInventoryQuery.ps1)
       to get every canvas app's AppId/DisplayName/EnvironmentId.
    2. Authenticates the Power Platform CLI (pac) once, as the same service principal.
    3. For each app, calls Resolve-CanvasAppType.ps1, which downloads the app's .msapp and
       checks its control tree for the SharePointIntegration control - the reliable,
       rename-proof signal of a SharePoint form customization.

    This relies on the service principal holding the Microsoft Entra 'Power Platform
    Administrator' directory role, which per Microsoft's documentation grants admin access
    to all environments tenant-wide without being added to each environment individually
    (see https://learn.microsoft.com/power-platform/admin/governance-considerations#security).
    Assign it first with: .\Assign-DirectoryRole.ps1 -AppId '<client-id>' -RoleName 'Power Platform Administrator'

    This is a broad, tenant-wide read/write grant - treat the secret accordingly. This
    script deletes its pac CLI auth profile when finished so the secret isn't left
    persisted in the pac CLI's profile store.

.PARAMETER TenantId
    The Microsoft Entra tenant (directory) ID.

.PARAMETER ClientId
    The Application (client) ID of the app registration.

.PARAMETER ClientSecret
    The client secret, as a SecureString. If omitted, you'll be prompted securely.

.PARAMETER OutputCsvPath
    Optional path to also export the results as CSV.

.EXAMPLE
    .\Invoke-CanvasAppTypeScan.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>'

.EXAMPLE
    .\Invoke-CanvasAppTypeScan.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' -OutputCsvPath .\canvas-app-types.csv

.NOTES
    Requires the Power Platform CLI (pac). Install: https://aka.ms/PowerPlatformCLI
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $TenantId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ClientId,

    [Parameter()]
    [SecureString] $ClientSecret,

    [Parameter()]
    [string] $OutputCsvPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Get-Command pac -ErrorAction SilentlyContinue)) {
    throw "pac CLI not found on PATH. Install: https://aka.ms/PowerPlatformCLI"
}

if (-not $ClientSecret) {
    $ClientSecret = Read-Host -Prompt 'Enter the client secret' -AsSecureString
}
$plainSecret = [System.Net.NetworkCredential]::new('', $ClientSecret).Password

Write-Host "Fetching canvas app inventory via Azure Resource Graph..." -ForegroundColor Cyan
$inventoryQuery = 'PowerPlatformResources | where type == "microsoft.powerapps/canvasapps" | extend properties = parse_json(properties) | project appId = name, displayName = tostring(properties.displayName), environmentId = tostring(properties.environmentId)'
$apps = & (Join-Path $scriptDir 'Invoke-PowerPlatformInventoryQuery.ps1') -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret -Query $inventoryQuery

if (-not $apps) {
    Write-Warning "No canvas apps returned from inventory."
    return
}
Write-Host "Found $(@($apps).Count) canvas apps. Authenticating pac CLI..." -ForegroundColor Cyan

$authProfileName = "pp-inventory-scan-$([guid]::NewGuid().ToString('N').Substring(0,8))"
& pac auth create --name $authProfileName --applicationId $ClientId --clientSecret $plainSecret --tenant $TenantId | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "pac auth create failed. Confirm the service principal has the Power Platform Administrator directory role assigned and has propagated."
}

try {
    $results = foreach ($app in $apps) {
        Write-Host "Resolving $($app.displayName) [$($app.appId)]..." -ForegroundColor DarkCyan
        & (Join-Path $scriptDir 'Resolve-CanvasAppType.ps1') -EnvironmentId $app.environmentId -AppId $app.appId -DisplayName $app.displayName
    }

    $results | Format-Table -AutoSize
    $resolved = @($results | Where-Object Status -eq 'Resolved')
    $sharePointFormCount = @($resolved | Where-Object IsSharePointFormApp).Count
    Write-Host "$sharePointFormCount of $(@($results).Count) apps confirmed as SharePoint form customizations ($($results.Count - $resolved.Count) couldn't be resolved)." -ForegroundColor Green

    if ($OutputCsvPath) {
        $results | Export-Csv -Path $OutputCsvPath -NoTypeInformation
        Write-Host "Exported to $OutputCsvPath" -ForegroundColor Green
    }

    $results
}
finally {
    & pac auth delete --name $authProfileName | Out-Null
}
