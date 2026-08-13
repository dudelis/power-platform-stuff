<#
.SYNOPSIS
    Determines whether a single canvas app is a SharePoint list form customization, by
    downloading its .msapp package and inspecting its control tree for the
    SharePointIntegration control.

.DESCRIPTION
    SharePoint list form customizations always contain a control named/typed
    'SharePointIntegration' (see https://learn.microsoft.com/power-apps/maker/canvas-apps/sharepoint-form-integration).
    This is baked into the app's actual definition, unlike the app's display name, so it
    survives renames and is far more reliable than any naming-convention heuristic.

    Requires an already-authenticated pac CLI session (run `pac auth create` /
    `pac auth select` beforehand - this script doesn't manage auth, since it's meant to be
    called repeatedly for many apps under one shared session).

.PARAMETER EnvironmentId
    The environment ID that contains the app.

.PARAMETER AppId
    The canvas app's GUID (the inventory 'name'/'appId' field).

.PARAMETER DisplayName
    Optional display name to carry through into the result for reporting purposes.

.EXAMPLE
    .\Resolve-CanvasAppType.ps1 -EnvironmentId 'Default-1e7886bb-...' -AppId '84b5d360-65f3-40dd-bb45-a5bcc716076e'

.NOTES
    Requires the Power Platform CLI (pac). Install: https://aka.ms/PowerPlatformCLI
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $EnvironmentId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $AppId,

    [Parameter()]
    [string] $DisplayName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-Result {
    param($Status, $IsSharePointFormApp, $Detail)
    [PSCustomObject]@{
        AppId               = $AppId
        DisplayName         = $DisplayName
        EnvironmentId       = $EnvironmentId
        IsSharePointFormApp = $IsSharePointFormApp
        Status              = $Status
        Detail              = $Detail
    }
}

if (-not (Get-Command pac -ErrorAction SilentlyContinue)) {
    return New-Result -Status 'Error' -IsSharePointFormApp $null -Detail "pac CLI not found on PATH. Install: https://aka.ms/PowerPlatformCLI"
}

# Inventory reports the tenant's default environment as 'Default-<tenantId>', but pac CLI's
# --environment only accepts a raw GUID or an https URL. For the default environment, the
# environment ID is the same GUID as the tenant ID, so strip the prefix.
$pacEnvironmentId = $EnvironmentId -replace '^Default-', ''

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) "pp-inventory-$AppId"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$msappPath = Join-Path $workDir "$AppId.msapp"
$sourcesPath = Join-Path $workDir 'src'

try {
    $downloadOutput = & pac canvas download --name $AppId --environment $pacEnvironmentId --file-name $msappPath --overwrite 2>&1
    if ($LASTEXITCODE -ne 0) {
        $message = ($downloadOutput | Out-String).Trim()
        $status = if ($message -match 'access|denied|forbidden|permission|unauthorized') { 'AccessDenied' } else { 'Error' }
        return New-Result -Status $status -IsSharePointFormApp $null -Detail $message
    }

    $unpackOutput = & pac canvas unpack --msapp $msappPath --sources $sourcesPath --overwrite 2>&1
    if ($LASTEXITCODE -ne 0) {
        return New-Result -Status 'Error' -IsSharePointFormApp $null -Detail (($unpackOutput | Out-String).Trim())
    }

    $match = Get-ChildItem -Path $sourcesPath -Recurse -File -ErrorAction SilentlyContinue |
        Select-String -Pattern 'SharePointIntegration' -SimpleMatch -List |
        Select-Object -First 1

    New-Result -Status 'Resolved' -IsSharePointFormApp ([bool]$match) -Detail $(if ($match) { "Matched in $($match.Path)" } else { 'No SharePointIntegration control found' })
}
finally {
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}
