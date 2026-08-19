# Power Platform Licensing API - environment entitlements (delegated auth)

Exploratory script for the Power Platform API's licensing surface, specifically
[Get Many Environment Entitlements](https://learn.microsoft.com/en-us/rest/api/power-platform/licensing/entitlement/get-many-environment-entitlements):

```
GET https://api.powerplatform.com/licensing/environments/{environmentId}/entitlements?api-version=2024-10-01
```

This returns the licensing entitlements scoped to a single environment - capacity
(allocated/consumed/available), pay-as-you-go usage, BAP addons, permissions, and
environment metadata (type, managed-environment status, disaster recovery state,
etc.) - as an array, one entry per entitlement/product category attached to the
environment.

## Auth

Delegated (signed-in user) only, on purpose - this mirrors the constraint the
[Inventory API](../inventory-api/README.md) has, and the goal here is to see
what a real admin's delegated token gets back, not to stand up an app
registration.

[`Get-EnvironmentEntitlements.ps1`](./Get-EnvironmentEntitlements.ps1) uses the
**Microsoft.PowerApps.Administration.PowerShell** module
(`Add-PowerAppsAccount` / `Get-JwtToken`) rather than `Az.Accounts`. That module
talks to MSAL directly for whatever audience you ask for (here,
`https://api.powerplatform.com/`) and never tries to resolve an Azure
subscription - which is what tripped up the `Az.Accounts`/`Connect-AzAccount`
version of this script for admin accounts that have Power Platform/Entra admin
roles but no Azure RBAC access at all (a very normal combination: the two
permission systems are unrelated). No app registration or secret is needed
either way - just a Power Platform admin role (Power Platform Administrator,
Dynamics 365 Administrator, or Global Administrator) on the signed-in account.

## Usage

```powershell
# prints the parsed response
.\Get-EnvironmentEntitlements.ps1 -EnvironmentId '<environment-id>'

# also saves the untouched JSON body for closer inspection
.\Get-EnvironmentEntitlements.ps1 -EnvironmentId '<environment-id>' -RawOutputPath .\entitlements.json

# with an OData filter
.\Get-EnvironmentEntitlements.ps1 -EnvironmentId '<environment-id>' -Filter "productCategories/any(p: p eq 'Dataverse')"

# force a fresh sign-in - use this if you get a 404/403 that's actually a stale
# or wrong-tenant/account session
.\Get-EnvironmentEntitlements.ps1 -EnvironmentId '<environment-id>' -ReAuth -TenantId '<tenant-id>'

# if the embedded sign-in window fails or you need 2FA/a security key
.\Get-EnvironmentEntitlements.ps1 -EnvironmentId '<environment-id>' -UseSystemBrowser
```

### Stale session / wrong tenant

The script reuses a cached sign-in for the `https://api.powerplatform.com/`
audience by default (held in-memory, for this PowerShell process only - it
isn't persisted to disk the way `Az.Accounts` context is). If a call fails with
a 404 or 403 and you're confident the environment ID is correct, pass `-ReAuth`
(and `-TenantId` if you're working across multiple tenants) to force a fresh
interactive sign-in instead of guessing.

## Files

| File | Purpose |
| --- | --- |
| `Get-EnvironmentEntitlements.ps1` | Signs in via Microsoft.PowerApps.Administration.PowerShell and calls Get Many Environment Entitlements for one environment |
