<#
.SYNOPSIS
    Queries Power Platform inventory data via Azure Resource Graph using a service
    principal (client-credentials), bypassing the Inventory API's delegated-auth-only
    limitation.

.DESCRIPTION
    Acquires an app-only OAuth token for https://management.azure.com/.default using the
    client-credentials grant, then POSTs a KQL query to the Azure Resource Graph REST API.
    No subscription or management group is targeted, since PowerPlatformResources is a
    tenant-scoped virtual table, not a subscription-scoped resource.

    The service principal must already have one of the following Microsoft Entra directory
    roles assigned (see Assign-DirectoryRole.ps1): Global Administrator, Power Platform
    Administrator, Dynamics 365 Administrator, Global Reader, AI Administrator, or AI Reader.

.PARAMETER TenantId
    The Microsoft Entra tenant (directory) ID.

.PARAMETER ClientId
    The Application (client) ID of the app registration.

.PARAMETER ClientSecret
    The client secret, as a SecureString. If omitted, you'll be prompted securely.

.PARAMETER Query
    The KQL query to run against Azure Resource Graph. Defaults to a basic smoke test
    that counts all Power Platform inventory resources.

.EXAMPLE
    .\Invoke-PowerPlatformInventoryQuery.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>'

    Prompts for the client secret, then runs the default smoke-test query
    (PowerPlatformResources | count).

.EXAMPLE
    .\Invoke-PowerPlatformInventoryQuery.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' `
        -Query 'PowerPlatformResources | summarize resourceCount = count() by type | order by resourceCount desc'

.NOTES
    No external modules required - uses Invoke-RestMethod directly.
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
    [ValidateNotNullOrEmpty()]
    [string] $Query = 'PowerPlatformResources | count'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ClientSecret) {
    $ClientSecret = Read-Host -Prompt 'Enter the client secret' -AsSecureString
}
$plainSecret = [System.Net.NetworkCredential]::new('', $ClientSecret).Password

Write-Host "Acquiring app-only token for https://management.azure.com/..." -ForegroundColor Cyan
$tokenBody = @{
    grant_type    = 'client_credentials'
    client_id     = $ClientId
    client_secret = $plainSecret
    scope         = 'https://management.azure.com/.default'
}
$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $tokenBody -ContentType 'application/x-www-form-urlencoded'
$accessToken = $tokenResponse.access_token

Write-Host "Running Azure Resource Graph query..." -ForegroundColor Cyan
$headers = @{ Authorization = "Bearer $accessToken" }
$requestBody = @{ query = $Query } | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Method Post `
        -Uri 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01' `
        -Headers $headers -ContentType 'application/json' -Body $requestBody

    $result.data
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 403) {
        Write-Warning "403 Forbidden: the app-only token was rejected for this query. This may mean PowerPlatformResources requires a delegated (user) token even though ARG accepts app-only tokens generally. Confirm the directory role assignment landed and has propagated (a few minutes), then retry."
    }
    elseif ($statusCode -eq 401) {
        Write-Warning "401 Unauthorized: token acquisition or validation problem - check TenantId, ClientId, and ClientSecret."
    }
    throw
}
