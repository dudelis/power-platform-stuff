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

> This exact combination (SP + directory role → ARG → `PowerPlatformResources`) isn't explicitly documented as
> supported — steps 1-2 are solid, documented behavior; step 3 (does ARG actually authorize the app-only token for
> this specific virtual table) is what we're validating.

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

## Files

| File | Purpose |
| --- | --- |
| `Assign-DirectoryRole.ps1` | Assigns an Entra directory role (default: Global Reader) to a service principal at tenant scope |
| `Invoke-PowerPlatformInventoryQuery.ps1` | Acquires an app-only token and runs a KQL query against `PowerPlatformResources` via Azure Resource Graph |
