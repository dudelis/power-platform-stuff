# Power Platform Inventory via Azure Resource Graph (service principal)

The native [Power Platform Inventory API](https://learn.microsoft.com/en-us/power-platform/admin/inventory-api) only
supports **delegated** (signed-in user) auth. The `PowerPlatformResources` table exposed through
[Azure Resource Graph (ARG)](https://learn.microsoft.com/en-us/power-platform/admin/inventory-sample-queries) sits on
top of `management.azure.com`, whose data plane **does support service-principal (app-only) auth**.

The blocker isn't authentication — it's authorization. Querying `PowerPlatformResources` requires the caller to hold
one of these **Microsoft Entra directory roles** (tenant-wide, not Azure RBAC, since these resources aren't scoped to
a subscription): Global Administrator, Power Platform Administrator, Dynamics 365 Administrator, Global Reader (full
visibility), or AI Administrator / AI Reader (AI-scoped resources only).

Directory roles **can** be assigned to service principals (not just users), via Microsoft Graph. That's the approach
here: create an app registration, assign it **Global Reader** (read-only, least privilege) at tenant scope, then call
ARG with a client-credentials token.

> **Confirmed working (2026-08-13).** This combination (SP + Global Reader directory role + app-only token → ARG →
> `PowerPlatformResources`) isn't documented anywhere as an explicitly supported pattern, but it works: a service
> principal with the Global Reader role, authenticating via client-credentials, successfully queried
> `PowerPlatformResources` through Azure Resource Graph with no delegated/user auth involved.

## Step 1 — Create the app registration (Azure Portal, manual)

1. Go to **Microsoft Entra ID** > **App registrations** > **New registration**.
2. Name it something like `pp-inventory-reader`. Leave redirect URI blank (this is a daemon/service app, no
   interactive sign-in). Supported account type: **single tenant**.
3. After creation, note down (you'll need these for the scripts below, do **not** paste the secret value to me):
   - **Application (client) ID**
   - **Directory (tenant) ID**
4. Go to **Certificates & secrets** > **New client secret**. Copy the secret **value** immediately (shown once).
5. No API permissions are required on the app registration itself — access is granted entirely through the
   directory role assignment in Step 2, not through delegated/application permissions or admin consent.

## Step 2 — Assign the Global Reader directory role to the service principal

Run [`Assign-DirectoryRole.ps1`](./Assign-DirectoryRole.ps1) as a user with **Privileged Role Administrator** or
**Global Administrator** (you confirmed you have this):

```powershell
.\Assign-DirectoryRole.ps1 -AppId '<application-client-id>'
```

This uses Microsoft Graph PowerShell (`Microsoft.Graph.Authentication` / `Microsoft.Graph.Identity.Governance`) to
assign the **Global Reader** role to the service principal at tenant scope (`directoryScopeId '/'`). Pass
`-RoleName 'Power Platform Administrator'` instead if you later decide you need broader (write) access.

Role assignments can take a few minutes to propagate before tokens reflect the new role.

## Step 3 — Query the inventory

Run [`Invoke-PowerPlatformInventoryQuery.ps1`](./Invoke-PowerPlatformInventoryQuery.ps1) with the app registration's
credentials. It will prompt for the client secret as a `SecureString` if you don't pass `-ClientSecretEnvVar`:

```powershell
# simplest smoke test - total resource count
.\Invoke-PowerPlatformInventoryQuery.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' -Query 'PowerPlatformResources | count'

# counts by resource type
.\Invoke-PowerPlatformInventoryQuery.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' `
    -Query 'PowerPlatformResources | summarize resourceCount = count() by type | order by resourceCount desc'
```

More sample KQL queries (counts by environment/region, connector usage, resource lookups) are in the
[official sample queries doc](https://learn.microsoft.com/en-us/power-platform/admin/inventory-sample-queries) — just
pass them via `-Query`.

```powershell
# app counts by category (canvas / model-driven / code app subtype / app builder)
# see https://learn.microsoft.com/en-us/power-platform/admin/inventory-schema for the full resource-type / field reference
.\Invoke-PowerPlatformInventoryQuery.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' `
    -Query 'PowerPlatformResources | where type in ("microsoft.powerapps/canvasapps","microsoft.powerapps/modeldrivenapps","microsoft.powerapps/codeapps","microsoft.powerapps/apps") | extend properties = parse_json(properties) | project displayName = tostring(properties.displayName), type, subType = tostring(properties.subType), environmentId = tostring(properties.environmentId) | summarize appCount = count() by type, subType | order by appCount desc'
```

Note: there's no dedicated resource type for SharePoint list form customizations — those are canvas apps
(`microsoft.powerapps/canvasapps`) under the hood and aren't distinguishable from any other canvas app via the
inventory schema.

## Finding GitHub Copilot harness agents

Copilot Studio agents created through the GitHub Copilot harness ("CLI agents") carry
`properties.isCLIAgent == true` on the `microsoft.copilotstudio/agents` resource type — this is the field
[Microsoft's inventory schema reference](https://learn.microsoft.com/power-platform/admin/inventory-schema)
documents as "Whether the agent was created through the GitHub Copilot harness" (see also the [sample "Count
agents by harness" query](https://learn.microsoft.com/power-platform/admin/inventory-sample-queries#count-agents-by-harness)
and [this write-up](https://www.russrimmerman.com/blog/find-github-copilot-harness-agents-resource-graph/)).

[`Find-GitHubCopilotHarnessAgents.ps1`](./Find-GitHubCopilotHarnessAgents.ps1) wraps
`Invoke-PowerPlatformInventoryQuery.ps1` with this filter:

```powershell
# list every GitHub Copilot harness agent in the tenant
.\Find-GitHubCopilotHarnessAgents.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>'

# scope to one environment, and export to CSV
.\Find-GitHubCopilotHarnessAgents.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' `
    -EnvironmentId '<environment-id>' -OutputCsvPath .\github-copilot-agents.csv

# instead, summarize all Copilot Studio agents by harness (GitHub Copilot / Copilot Chat / Standard)
.\Find-GitHubCopilotHarnessAgents.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' -CountByHarness
```

### If it fails

- **401** — token acquisition problem (bad tenant/client id, bad secret, secret expired). Not related to the
  inventory-specific authorization question.
- **403** — the app-only token was rejected for this resource type. This is the scenario to watch for: it would mean
  ARG's `PowerPlatformResources` provider requires a *delegated* token even though ARG itself accepts app-only tokens
  for normal Azure resources. If this happens, the fallback is to use a delegated (user) token instead — e.g. via
  `Connect-AzAccount` interactively, or a certificate-based confidential client acting **on behalf of** a licensed
  admin user — which defeats the "no delegated auth" goal but confirms the platform's actual constraint.
- Empty result / `count = 0` — check role propagation delay (wait 5-10 minutes and retry), and confirm the directory
  role assignment actually landed (`Get-MgServicePrincipal` + `Get-MgRoleManagementDirectoryRoleAssignment`).

## Identifying SharePoint list form customizations reliably

`displayName` naming patterns (like `"<List> on <Site> forms"`) are only a heuristic — they break the moment someone
renames the app. The reliable, rename-proof signal is that every SharePoint list form customization contains a
control named/typed **`SharePointIntegration`** in its actual app definition (see
[Understand SharePoint forms integration](https://learn.microsoft.com/power-apps/maker/canvas-apps/sharepoint-form-integration)).
Reading that requires downloading the app's `.msapp` package (`pac canvas download`/`unpack`), which needs access to
the app's actual **content**, not just its inventory metadata.

**CONFIRMED NOT WORKING as a service-principal-only, no-per-environment-grant approach (2026-08-13):** assigning the
service principal the **Power Platform Administrator** Entra directory role does not grant it access to `pac canvas
download` for apps it doesn't own. `pac canvas download` returns `403 Forbidden` on
`Microsoft.BusinessAppPlatform/scopes/admin/environments`, even in the tenant's Default environment, even with the
role assignment confirmed in place (ruling out propagation delay). The legacy `Microsoft.BusinessAppPlatform` admin
API doesn't honor Entra directory roles for service principals the way the ARG `PowerPlatformResources` endpoint
does. Getting real content-level access would require a per-environment grant (System Administrator role, or app
ownership/sharing) or a delegated admin user session — both outside the "SP-only, no per-environment permissions"
constraint this was trying to satisfy.

**Practical approach instead:** the naming-pattern + connector heuristic from ARG inventory data alone (see the
`bag_keys()`/connector queries above) — works today with just Global Reader, no extra permission, though it's a
heuristic rather than a certainty.

`Resolve-CanvasAppType.ps1` and `Invoke-CanvasAppTypeScan.ps1` are kept in this folder for reference (they work
correctly as pac CLI wrappers), but don't run them expecting SP-only, zero-extra-permission results — that
combination doesn't work against this API.

The SP's **Power Platform Administrator** role was reverted back to just **Global Reader** after this was confirmed
not to work — use `Remove-DirectoryRole.ps1` if you need to revoke an elevated role again in the future.

## Files


| File | Purpose |
| --- | --- |
| `Assign-DirectoryRole.ps1` | Assigns an Entra directory role (default: Global Reader) to a service principal at tenant scope |
| `Remove-DirectoryRole.ps1` | Removes a previously assigned Entra directory role from a service principal |
| `Invoke-PowerPlatformInventoryQuery.ps1` | Acquires an app-only token and runs a KQL query against `PowerPlatformResources` via Azure Resource Graph |
| `Find-GitHubCopilotHarnessAgents.ps1` | Lists (or counts by harness) Copilot Studio agents built with the GitHub Copilot harness, via `properties.isCLIAgent` |
| `Resolve-CanvasAppType.ps1` | Downloads one canvas app's `.msapp` via pac CLI and checks for the `SharePointIntegration` control |
| `Invoke-CanvasAppTypeScan.ps1` | Orchestrator: pulls all canvas apps from inventory, then resolves each one via `Resolve-CanvasAppType.ps1` |
