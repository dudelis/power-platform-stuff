<#
.SYNOPSIS
    Finds Copilot Studio agents built with the GitHub Copilot harness (aka the "CLI agent"
    experience), via Azure Resource Graph inventory data.

.DESCRIPTION
    Wraps Invoke-PowerPlatformInventoryQuery.ps1 with a KQL query against the
    microsoft.copilotstudio/agents resource type, filtered to properties.isCLIAgent == true -
    the field Microsoft's inventory schema documents as "Whether the agent was created through
    the GitHub Copilot harness" (see https://learn.microsoft.com/power-platform/admin/inventory-schema
    and https://www.russrimmerman.com/blog/find-github-copilot-harness-agents-resource-graph/).

    By default, returns one row per matching agent with its display name, environment,
    creation/publish dates, owner, model, and orchestration mode. Pass -CountByHarness to
    instead run Microsoft's "Count agents by harness" sample query, which buckets every
    Copilot Studio agent in the tenant into GitHub Copilot / Copilot Chat / Standard.

    Requires the same service principal setup as Invoke-PowerPlatformInventoryQuery.ps1 (a
    directory role of Global Reader or higher - see README.md).

.PARAMETER TenantId
    The Microsoft Entra tenant (directory) ID.

.PARAMETER ClientId
    The Application (client) ID of the app registration.

.PARAMETER ClientSecret
    The client secret, as a SecureString. If omitted, you'll be prompted securely.

.PARAMETER EnvironmentId
    Optional. Restrict results to a single Power Platform environment ID.

.PARAMETER CountByHarness
    Instead of listing individual GitHub Copilot harness agents, summarize every Copilot
    Studio agent in the tenant by harness (GitHub Copilot / Copilot Chat / Standard).

.PARAMETER OutputCsvPath
    Optional path to also export the results as CSV.

.EXAMPLE
    .\Find-GitHubCopilotHarnessAgents.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>'

    Lists every agent in the tenant created with the GitHub Copilot harness.

.EXAMPLE
    .\Find-GitHubCopilotHarnessAgents.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' -CountByHarness

    Shows agent counts broken down by harness (GitHub Copilot / Copilot Chat / Standard).

.NOTES
    No external modules required - delegates to Invoke-PowerPlatformInventoryQuery.ps1.
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
    [string] $EnvironmentId,

    [Parameter()]
    [switch] $CountByHarness,

    [Parameter()]
    [string] $OutputCsvPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $ClientSecret) {
    $ClientSecret = Read-Host -Prompt 'Enter the client secret' -AsSecureString
}

if ($CountByHarness) {
    Write-Host "Counting Copilot Studio agents by harness (GitHub Copilot / Copilot Chat / Standard)..." -ForegroundColor Cyan
    $query = @'
PowerPlatformResources
| where type == "microsoft.copilotstudio/agents"
| extend properties = parse_json(properties)
| extend
    isCLIAgent = tobool(properties.isCLIAgent),
    model = tostring(properties.model),
    createdIn = tostring(properties.createdIn)
| extend harness = case(
    isCLIAgent == true, "GitHub Copilot",
    model =~ "Microsoft 365 Copilot" or createdIn =~ "Microsoft 365 Copilot Agent Builder", "Copilot Chat",
    "Standard")
| summarize agentCount = count() by harness
| order by agentCount desc
'@
}
else {
    Write-Host "Querying Power Platform inventory for GitHub Copilot harness agents..." -ForegroundColor Cyan
    $environmentFilter = if ($EnvironmentId) { "`n| where tostring(properties.environmentId) == `"$EnvironmentId`"" } else { '' }
    $query = @"
PowerPlatformResources
| where type == "microsoft.copilotstudio/agents"
| extend properties = parse_json(properties)
| where tobool(properties.isCLIAgent) == true$environmentFilter
| project
    displayName = tostring(properties.displayName),
    agentId = name,
    environmentId = tostring(properties.environmentId),
    createdAt = todatetime(properties.createdAt),
    createdBy = tostring(properties.createdBy),
    ownerId = tostring(properties.ownerId),
    lastPublishedAt = todatetime(properties.lastPublishedAt),
    model = tostring(properties.model),
    orchestration = tostring(properties.orchestration),
    isManaged = tobool(properties.isManaged),
    schemaName = tostring(properties.schemaName)
| order by createdAt desc
"@
}

$results = & (Join-Path $scriptDir 'Invoke-PowerPlatformInventoryQuery.ps1') -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret -Query $query

if (-not $results) {
    Write-Warning "No GitHub Copilot harness agents found."
    return
}

$results | Format-Table -AutoSize

if (-not $CountByHarness) {
    Write-Host "$(@($results).Count) GitHub Copilot harness agent(s) found." -ForegroundColor Green
}

if ($OutputCsvPath) {
    $results | Export-Csv -Path $OutputCsvPath -NoTypeInformation
    Write-Host "Exported to $OutputCsvPath" -ForegroundColor Green
}

$results
