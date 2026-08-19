# Dataverse Plugins — Hack the Platform

C# plugins for Microsoft Dataverse that back the plugin articles on
[hacktheplatform.dev](https://hacktheplatform.dev). Everything here is a real, working
implementation — the articles walk through the *why*, this folder holds the *what*.

Two ways to use it:

- **Just want the governance fix?** Import the ready-made managed solution — see
  [Ready-to-deploy solution](#ready-to-deploy-solution). No Visual Studio, no
  Plugin Registration Tool.
- **Want to build on it?** Open the Visual Studio solution and register the steps yourself —
  see [Building from source](#building-from-source).

---

## Contents

| Plugin | What it does | Article |
| --- | --- | --- |
| [`BlockCopilotHarnessAgents.cs`](HackThePlatform/Plugins/BlockCopilotHarnessAgents.cs) | Blocks creation/editing of **GitHub Copilot harness** agents, which bill Copilot Credits outside a Microsoft 365 Copilot license | [Block GitHub Copilot Harness Agents with a Dataverse Plugin](https://hacktheplatform.dev/blog/block-copilot-harness-agents) |
| [`BlockBotCreation.cs`](HackThePlatform/Plugins/BlockBotCreation.cs) | Blocks creation of **any** Copilot Studio agent — intended for the Default environment | [Block Copilot Studio in Default Environment with a Simple Plugin](https://hacktheplatform.dev/blog/block-copilot-in-default-environment) |
| [`CreateBlobFolderRestPlugin.cs`](HackThePlatform/Plugins/CreateBlobFolderRestPlugin%20.cs) | Creates an Azure Blob Storage folder per new record via plain REST, then writes the folder URL back | [Auto-Generate Azure Blob Folders from Dataverse Using a Plugin](https://hacktheplatform.dev/blog/plugin-azure-blob-storage) |
| [`FetchXmlToJsonPlugin.cs`](HackThePlatform/Plugins/FetchXmlToJsonPlugin.cs) | Custom API that runs arbitrary FetchXML and returns JSON — call complex queries straight from a Canvas App | [Custom API: Run Complex FetchXML Queries from Canvas App](https://hacktheplatform.dev/blog/custom-api-fetchxml-canvas-app) |

All four compile into a **single signed assembly**, `Plugins.dll`. Registering the assembly
does nothing on its own — each plugin only runs once you register a step (or a Custom API)
for it. That is what makes it safe to ship them together.

---

## Ready-to-deploy solution

`BlockGitHubCopilotHarnessAgents_1_0_0_1_managed.zip` is a **managed Dataverse solution** that
does the whole job of the harness-blocking article for you. Import it into an environment and
GitHub Copilot harness agents can no longer be created there.

### What is inside

| Item | Value |
| --- | --- |
| Unique name | `BlockGitHubCopilotHarnessAgents` |
| Version | `1.0.0.1` |
| Managed | Yes |
| Publisher | Hack the Platform Studio (prefix `hps`) |
| Assembly | `Plugins`, sandbox isolation |
| Registered steps | 2 (see below) |

Two SDK message processing steps, both on the `bot` table, both **PreValidation** and
**Synchronous**:

- `Plugins.BlockCopilotHarnessAgents: Create of bot`
- `Plugins.BlockCopilotHarnessAgents: Update of bot`

The other three plugin types travel inside the assembly but have **no steps registered**, so
they are inert. Nothing in your environment changes because of them.

### Prerequisites

- **Copilot Studio / Power Virtual Agents must be installed in the target environment.** The
  solution takes a dependency on the `bot` table; import fails on an environment that does not
  have it.
- You need **System Administrator** or **System Customizer** in the target environment.

### Import it

Power Platform admin center → **Environments** → *your environment* → **Solutions** →
**Import solution** → pick the zip.

Or with the PAC CLI, which is what you want when rolling this out widely:

```powershell
pac auth create --environment https://contoso.crm4.dynamics.com
pac solution import --path .\BlockGitHubCopilotHarnessAgents_1_0_0_1_managed.zip --publish-changes
```

Across many environments:

```powershell
$envs = @(
  'https://contoso-dev.crm4.dynamics.com',
  'https://contoso-test.crm4.dynamics.com',
  'https://contoso-prod.crm4.dynamics.com'
)

foreach ($url in $envs) {
  Write-Host "Importing into $url"
  pac auth create --environment $url
  pac solution import --path .\BlockGitHubCopilotHarnessAgents_1_0_0_1_managed.zip --publish-changes
}
```

### Verify it works

Open Copilot Studio in the target environment and try to create an agent on the GitHub Copilot
harness. The save is rejected with:

> GitHub Copilot Harness agents cannot be created or edited in this environment.

Copilot Studio wraps that inside its own generic *"Some required fields may be missing or
invalid"* notification, so the message arrives as a validation error rather than a clean policy
notice. Standard-harness agents are unaffected — they still create normally.

### Remove it

Delete the managed solution from the target environment. Managed uninstall removes the
assembly and both steps cleanly.

### Read this before a broad rollout

- **It blocks edits to existing harness agents too.** The Update step throws on any harness
  agent already in the environment. Inventory them first — Power Platform inventory flags them
  with `properties.isCLIAgent` — or you will lock people out of live work.
- **It applies to everyone**, administrators and service accounts included. If you need an
  exemption path, build from source and add a check on `context.InitiatingUserId`.
- **No pre-image is registered in this solution.** On Update the plugin falls back to an
  explicit `Retrieve` of the `configuration` column, which adds a round trip to every agent
  update in the environment. If that matters at your scale, register an Update pre-image
  containing `configuration` on the step after import.
- **It does not stop all spending.** Copilot for Makers bills credits while describing an agent
  in natural language, before any `bot` row is written — the plugin never fires. Pair this with
  a capped credit allocation and **Draw from the available capacity in my tenant** turned off.
- **It keys on an internal marker.** `CLICopilotRecognizer` is not a documented contract.
  Treat this as a monitored stopgap, not something you register and forget.

---

## The plugins

### BlockCopilotHarnessAgents

Agents on the GitHub Copilot harness bill **Copilot Credits on consumption**, are **not covered
by a Microsoft 365 Copilot license**, and start billing when a maker *starts building* rather
than when they publish. There is no admin switch to turn the harness off.

The plugin reads the `configuration` JSON on the `bot` record and throws when the recognizer
kind identifies a harness agent:

```json
{ "recognizer": { "$kind": "CLICopilotRecognizer" } }
```

Standard-harness agents do not carry that value, so makers can keep building the agents your
licenses do cover.

Three implementation details matter:

- It handles **Create and Update**, because the platform may write the `bot` row first and
  populate `configuration` on a later update.
- It resolves `configuration` from **Target → pre-image → `Retrieve`**. Dataverse only sends
  changed columns, so without the fallback, renaming an agent would skip validation entirely.
- It **fails open on malformed JSON** — a parser failure should not break every agent write in
  the environment. The flip side is that a schema change could silently disable the block, so
  watch the trace logs.

**Registration** (already done for you in the managed solution):

| Setting | Value |
| --- | --- |
| Message | `Create` and `Update` |
| Primary entity | `bot` |
| Stage | PreValidation |
| Execution mode | Synchronous |
| Images | Optional Update pre-image with `configuration` (recommended) |

The `workflow` branch in the code is a placeholder that only traces — cloud flows are not
covered.

---

### BlockBotCreation

The blunt version: blocks **every** Copilot Studio agent creation in the environment it is
registered in. Intended for the Default environment, where every licensed user gets
Environment Maker automatically and there is no native control to stop agent creation.

| Setting | Value |
| --- | --- |
| Message | `Create` |
| Primary entity | `bot` |
| Stage | PreValidation |
| Execution mode | Synchronous |

Throws: *"Copilot Agents creation is not allowed in the Default environment."*

Because assemblies and steps can only be changed by System Customizer or System Administrator,
Environment Makers cannot disable it — that is what makes it enforceable rather than advisory.

---

### CreateBlobFolderRestPlugin

On record creation, creates a folder in Azure Blob Storage named after the record's GUID (by
writing a `.keep` block blob into it), then writes the folder URL back to the record. Uses
plain HTTP REST against the Blob service, so there is no dependency on `Azure.Storage.Blobs` —
which keeps the sandboxed assembly small and avoids dependency-loading grief.

**Environment setup**

- An Azure Storage account and a blob container.
- A SAS token with create/write permission on that container.
- A Dataverse table with a text column **`crad2_folderurl`**. Change the schema name in
  [`CreateBlobFolderRestPlugin .cs`](HackThePlatform/Plugins/CreateBlobFolderRestPlugin%20.cs)
  if your publisher prefix differs — it is hard-coded.

**Registration**

| Setting | Value |
| --- | --- |
| Message | `Create` |
| Primary entity | your table |
| Stage | PostOperation |
| Execution mode | Synchronous |
| Unsecure configuration | `Account=yourstorage;Container=dataverse-folders` |
| Secure configuration | `?yourSASToken` |

PostOperation is deliberate: the record ID must exist before the folder can be named after it,
and if the blob call fails the whole transaction rolls back, so you never get a Dataverse
record without its folder.

The SAS token goes in **secure** configuration so it is not readable by non-admins and does not
travel with an exported solution.

---

### FetchXmlToJsonPlugin

Backs a Dataverse **Custom API** that takes a FetchXML string, executes it, and returns the
result as a JSON string. The point is to run complex or aggregate cross-table queries directly
from a Canvas App, without a Power Automate flow in the middle.

**Custom API configuration**

| Setting | Value |
| --- | --- |
| Name | `crad2_FetchXmlToJsonPlugin` |
| Display name | `FetchXML to JSON Plugin` |
| Bound entity | None (global) |
| Is function | No — POST |
| Plugin type | `HackThePlatform.Plugins.FetchXmlToJsonPlugin` |
| Request parameter | `fetchxml` (String) |
| Response property | `json` (String) |

POST rather than a function matters: it lets you send large FetchXML payloads that would not
survive a query string.

**Calling it from a Canvas App** (via the Environment connector):

```powerfx
Set(
    result,
    Environment.crad2_FetchXmlToJson({fetchxml: "<fetch top='10'>...</fetch>"}).json
)
```

Note the plugin serializes raw `Entity` attribute values, so lookups arrive as `EntityReference`
objects and option sets as `OptionSetValue` objects rather than flat scalars. Use aliases and
`aggregate` in your FetchXML, or post-process, depending on what your app expects.

---

## Building from source

**Requirements**

- Visual Studio 2022
- .NET Framework 4.6.2 targeting pack

**Steps**

1. Open [`HackThePlatform/HackThePlatform.sln`](HackThePlatform/HackThePlatform.sln).
2. Restore NuGet packages (`packages.config` — legacy restore, not PackageReference).
3. Build. Output lands in `HackThePlatform/Plugins/bin/`.

The assembly is **signed** with `HackThePlatformKey.snk`, which is committed alongside the
project. Dataverse requires signed plugin assemblies. The key is published purely so the
articles are reproducible — generate your own before shipping anything to production.

**Key NuGet packages**

- `Microsoft.CrmSdk.CoreAssemblies` 9.0.2.59
- `Microsoft.CrmSdk.XrmTooling.CoreAssembly` 9.1.1.65
- `Newtonsoft.Json` 13.0.1

**Registering manually**

```powershell
pac tool prt
```

Connect to your environment, **Register New → Plugin Assembly**, select the built
`Plugins.dll`, then add steps per the tables above.

---

## Articles and videos

- [Block GitHub Copilot Harness Agents with a Dataverse Plugin](https://hacktheplatform.dev/blog/block-copilot-harness-agents)
- [Block Copilot Studio in Default Environment with a Simple Plugin](https://hacktheplatform.dev/blog/block-copilot-in-default-environment)
- [Auto-Generate Azure Blob Folders from Dataverse Using a Plugin](https://hacktheplatform.dev/blog/plugin-azure-blob-storage) — includes the end-to-end build & register walkthrough the other posts refer back to
- [Custom API: Run Complex FetchXML Queries from Canvas App](https://hacktheplatform.dev/blog/custom-api-fetchxml-canvas-app)

Microsoft reference for the licensing situation behind the harness plugin:
[Manage costs for agents powered by the GitHub Copilot harness](https://learn.microsoft.com/en-us/power-platform/admin/manage-usage-github-copilot-harness).

---

## Disclaimer

Sample code, provided as-is under the repository [LICENSE](../LICENSE). The governance plugins
key on internal Dataverse and Copilot Studio behaviour that Microsoft can change without
notice. Test in a non-production environment first, and keep monitoring after you deploy.
