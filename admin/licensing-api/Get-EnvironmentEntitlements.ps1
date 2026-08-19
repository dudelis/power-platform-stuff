<#
.SYNOPSIS
    Retrieves the licensing entitlements for a Power Platform environment, using a
    delegated (signed-in user) token.

.DESCRIPTION
    Calls the Power Platform API's "Get Many Environment Entitlements" operation:

        GET https://api.powerplatform.com/licensing/environments/{environmentId}/entitlements?api-version=2024-10-01

    This returns one entry per entitlement scoped to the environment (capacity
    allocated/consumed/available, pay-as-you-go usage, addons, permissions, and
    environment metadata such as type and managed-environment status).

    Authentication is delegated and uses the Microsoft.PowerApps.Administration.PowerShell
    module (Add-PowerAppsAccount / Get-JwtToken) instead of Az.Accounts - this module talks
    directly to Microsoft Identity Client (MSAL) for the requested audience and never touches
    Azure subscriptions, so it works cleanly for admin accounts that have Power Platform/Entra
    admin roles but no Azure RBAC access at all (which is what Az.Accounts' Connect-AzAccount
    trips over: it tries to resolve a default Azure subscription as part of sign-in).

    This is exploratory: by default the script prints the raw parsed response so you can
    inspect exactly what the API returns. Pass -RawOutputPath to also save the untouched JSON
    body to a file.

.PARAMETER EnvironmentId
    The GUID of the Power Platform environment to query.

.PARAMETER Filter
    Optional OData $filter expression to pass through to the API.

.PARAMETER ApiVersion
    The api-version query parameter. Defaults to '2024-10-01' (the version
    documented for this operation as of 2026-08).

.PARAMETER RawOutputPath
    Optional path to save the raw JSON response body, exactly as returned by the
    API, for closer inspection.

.PARAMETER TenantId
    Optional Entra tenant ID to sign in against. Passed through to Add-PowerAppsAccount.
    Useful when your account belongs to more than one tenant and you need to pin which one
    to authenticate against, rather than picking interactively.

.PARAMETER UseSystemBrowser
    Sign in using the system's default browser instead of the module's embedded web view.
    Use this if your sign-in requires 2FA/a security key, or the embedded view fails.

.PARAMETER ReAuth
    Forces a fresh interactive sign-in (Remove-PowerAppsAccount then a new login) even if a
    cached, still-valid session exists for this PowerShell process. Use this whenever the
    cached session might be stale or signed into the wrong account/tenant.

.EXAMPLE
    .\Get-EnvironmentEntitlements.ps1 -EnvironmentId '0d1cf9f4-1a2b-3c4d-5e6f-1234567890ab'

    Signs in interactively (if not already signed in for this session), then prints the
    entitlements for the given environment.

.EXAMPLE
    .\Get-EnvironmentEntitlements.ps1 -EnvironmentId '0d1cf9f4-...' -RawOutputPath .\entitlements.json

    Same, but also writes the untouched JSON response to entitlements.json.

.EXAMPLE
    .\Get-EnvironmentEntitlements.ps1 -EnvironmentId '0d1cf9f4-...' -ReAuth -TenantId '11111111-2222-3333-4444-555555555555'

    Forces a fresh sign-in against the given tenant before calling the API - use this when a
    404/403 turns out to be caused by a stale session signed into the wrong tenant or account.

.NOTES
    Module: Microsoft.PowerApps.Administration.PowerShell (Add-PowerAppsAccount / Get-JwtToken /
    Remove-PowerAppsAccount)
    Install: Install-Module Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser

    Docs: https://learn.microsoft.com/en-us/rest/api/power-platform/licensing/entitlement/get-many-environment-entitlements
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $EnvironmentId,

    [Parameter()]
    [string] $Filter,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ApiVersion = '2024-10-01',

    [Parameter()]
    [string] $RawOutputPath,

    [Parameter()]
    [string] $TenantId,

    [Parameter()]
    [switch] $UseSystemBrowser,

    [Parameter()]
    [switch] $ReAuth
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resourceUrl = 'https://api.powerplatform.com'
$audience = "$resourceUrl/"

# --- 1. Ensure the PowerApps admin module is available ---
$moduleName = 'Microsoft.PowerApps.Administration.PowerShell'
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    throw "Required module '$moduleName' is not installed. Install it with: Install-Module $moduleName -Scope CurrentUser"
}
Import-Module $moduleName -ErrorAction Stop

# --- 2. Ensure we have a delegated (signed-in user) session for this audience ---
# Add-PowerAppsAccountInternal (called by both Add-PowerAppsAccount and Get-JwtToken) already
# reuses a cached, still-valid token for the requested audience, so calling Add-PowerAppsAccount
# here is cheap even if we're already signed in - it's only a real interactive prompt the first
# time, or after -ReAuth clears the cached session.
if ($ReAuth) {
    Write-Host "Forcing fresh interactive sign-in (-ReAuth)..." -ForegroundColor Cyan
    Remove-PowerAppsAccount
}

Write-Host "Signing in (or reusing cached session) for audience $audience..." -ForegroundColor Cyan
$signInParams = @{ Audience = $audience }
if ($TenantId) { $signInParams['TenantID'] = $TenantId }
if ($UseSystemBrowser) { $signInParams['UseSystemBrowser'] = $true }
Add-PowerAppsAccount @signInParams | Out-Null

# --- 3. Grab the delegated access token for the Power Platform API resource ---
$accessToken = Get-JwtToken -Audience $audience

# --- 4. Build the request URI ---
$uriBuilder = [System.UriBuilder]::new("$resourceUrl/licensing/environments/$EnvironmentId/entitlements")
$queryParams = [System.Collections.Specialized.NameValueCollection]::new()
$queryParams.Add('api-version', $ApiVersion)
if ($Filter) {
    $queryParams.Add('$filter', $Filter)
}
$uriBuilder.Query = ($queryParams.AllKeys | ForEach-Object { "$([Uri]::EscapeDataString($_))=$([Uri]::EscapeDataString($queryParams[$_]))" }) -join '&'
$uri = $uriBuilder.Uri.AbsoluteUri

Write-Host "GET $uri" -ForegroundColor Cyan

# --- 5. Call the API ---
$headers = @{ Authorization = "Bearer $accessToken" }

try {
    $response = Invoke-WebRequest -Method Get -Uri $uri -Headers $headers -ErrorAction Stop

    if ($RawOutputPath) {
        Set-Content -Path $RawOutputPath -Value $response.Content -Encoding UTF8
        Write-Host "Raw response body saved to $RawOutputPath" -ForegroundColor Green
    }

    if ([string]::IsNullOrWhiteSpace($response.Content)) {
        Write-Host "204 No Content - the API returned an empty body (no entitlements found for this environment)." -ForegroundColor Yellow
        return
    }

    $parsed = $response.Content | ConvertFrom-Json -Depth 20
    $parsed | ConvertTo-Json -Depth 20
}
catch {
    $statusCode = $null
    if ($_.Exception.PSObject.Properties.Name -contains 'Response' -and $_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
    }

    switch ($statusCode) {
        401 { Write-Warning "401 Unauthorized: the delegated token was rejected. Check that you signed in with an account that has a Power Platform admin role, and that the token was issued for $resourceUrl." }
        403 { Write-Warning "403 Forbidden: signed-in user lacks permission to view entitlements for this environment. Confirm the account holds a Power Platform admin role (e.g. Power Platform Administrator, Dynamics 365 Administrator, or Global Administrator)." }
        404 { Write-Warning "404 Not Found: no environment with ID '$EnvironmentId' exists, or it isn't visible to this account. If you're signed into the wrong tenant, retry with -ReAuth -TenantId '<correct-tenant-id>'." }
        default { Write-Warning "Request failed$(if ($statusCode) { " with status $statusCode" })." }
    }
    throw
}
