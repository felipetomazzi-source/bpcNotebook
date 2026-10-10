# bpcNotebook

For calculation conversion agents, start with the [definitive feature and implementation guide](docs/AGENT-REFERENCE.md). It consolidates current APIs, Script syntax, reference scopes, dependency limits and the BPC result contract.

For complete native tables between ABAP stages and accountant-facing stage pages, see [working datasets and execution boundaries](docs/working-datasets.md).


A standalone SAPUI5 notebook for ABAP calculations with versioned source, typed inputs, explicit dependencies, frozen runs and persisted output previews.

```powershell
npm start
# Open http://127.0.0.1:4173 → New notebook → add cells → Save version
npm test
npm run pack:sap
```

The local service **simulates two demo cell bodies**. The SAP DEV version is deployed on the connected ABAP system, client **001**, with access enabled for **DEVELOPER**. The browser allocation demo completed as a real SAP background job and produced CC100 = **66,000**. The completed allocation integration is on `main` and is pulled through SAP abapGit using transport `NPLK900126`. All **56** repository artifacts pass actual SAP import/serialization comparison. Automated dangerous ABAP Unit tests remain blocked by the client risk policy. Production execution remains blocked.

[Open the deployed SAP notebook](http://vhcalnplci:8000/sap/bc/ui5_ui5/sap/zbpc_notebook/index.html?sap-client=001). Log in as DEVELOPER, open an existing notebook or choose **New notebook**, select its parameters, then **Save version → Run all** and select **allocate**.

- [Design and runtime contract](docs/DESIGN.md)
- [Installation and remaining production requirements](docs/INSTALL.md)
- [BPC selections, frozen parameters and calculation adapters](docs/bpc-inputs.md)
- [Notebook Script and metadata completion](docs/notebook-script.md)
- [BW InfoProvider reads: explicit fields, SAP authorization and bounded results](docs/bw-infoproviders.md)
- [Notebook Script v2: generic native tables, lookup and allocation contracts](docs/notebook-script-v2.md)
- [Notebook handlers in BPC Script Logic](docs/notebook-script-logic.md)
- [Notebook deletion and loading performance](docs/notebook-management.md)
- The **Steps** list uses standard UI5 selection highlighting and wraps complete step titles. The full selected title also appears above the step. Switching steps keeps editor drafts intact. The retired allocation demo button is no longer shown.
- Each cell has **Pretty print**: native SAP ABAP formatting or Notebook Script indentation. Formatting edits the draft; **Save version** persists it. ABAP formatting uses the same SAP system's ADT service and requires ADT access.
- **Export JSON** downloads the whole current notebook, including unsaved author code, ABAP/Script languages, ordered steps, explanations, dependencies, input definitions and selections. UTF-8 format `bpc-notebook`, version `1`, retains exact author text and line endings. Origin revision and unsaved status are recorded; execution datasets, results, history, ownership and handler bindings are excluded.
- **Import JSON** in the workspace creates a new notebook at revision 1. Choose an authorized target environment/model and an available technical name; imported definitions pass the normal SAP save, compiler, member and authorization checks. Resolved periods are recomputed by SAP. Import never overwrites an existing notebook, executes code or enables posting. Maximum 8 MB JSON file, 30 steps and 50 inputs; the compiled import must fit the existing SAP 2 MB request limit. A JSON draft containing invalid Script can be exported for backup, but must be corrected before importing.
- **Print / PDF** opens a complete printable document with notebook identity, context, revision/draft status, explanations, input definitions, step dependencies and all author code with line numbers. Select **Save as PDF** in the browser print dialog. This works offline using the browser and includes current unsaved edits. Permit popups for the SAP application if needed.
- [API contract](docs/API.md)
- [Native result comparison, read diagnostics and controlled fixtures](docs/native-validation.md)
- [Native activation/test evidence](docs/evidence/native-check.json)
- [Encoding conventions and SAP round-trip evidence](docs/evidence/ENCODING.md)

Package/BSP: `ZBPC_NOTEBOOK`. API: `/sap/bc/zbpc_notebook`. URL: `/sap/bc/ui5_ui5/sap/zbpc_notebook/index.html?sap-client=<client>`. BPCIO tile integration is documented; adjacent repositories were not modified.

## Embed in the bpcIO hub

bpcIO remains the hub. The Notebook tile loads this separate component into the
hub's content area; the hub keeps its header and **Back to hub** button visible.

- Component namespace: **`bpc.notebook`** (`bpc.notebook.Component`).
- SAP component base URL: **`/sap/bc/ui5_ui5/sap/zbpc_notebook/`**.
- Connected DEV URL: **`http://vhcalnplci:8000/sap/bc/ui5_ui5/sap/zbpc_notebook/`**.
- Required host UI5: **1.120.0+**, tested with SAP runtime **1.120.40**. Required libraries are
  `sap.m`, `sap.ui.table`, `sap.ui.layout` and `sap.ui.codeeditor`, declared in the manifest.
- Backend remains **`/sap/bc/zbpc_notebook`** in this repository/package. Load
  from the same SAP origin and authenticated client as the hub.

The minimum UI5 version is higher than BPC Git's. Upgrade the hub's single core
when needed; do not load another UI5 core inside Notebook. The embedded component
inherits the current hub theme, including Horizon Dark and later theme changes.
It hides its standalone header/theme selector, loads its own scoped layout CSS
through the manifest, and does not change the hub's theme, routing or header.
Do not load the standalone `index.html` for embedding.

```javascript
sap.ui.require(["sap/ui/core/ComponentContainer"], function (ComponentContainer) {
  var notebook = sap.ui.component({
    name: "bpc.notebook",
    url: "/sap/bc/ui5_ui5/sap/zbpc_notebook/",
    settings: { embedded: true, environment: selectedEnvironment }
  });
  var container = new ComponentContainer({
    component: notebook, height: "100%", width: "100%"
  });
  notebook.attachNavigateBack(function (event) {
    showHub(event.getParameter("environment"));
    container.destroy();
    notebook.destroy();
  });
  container.placeAt("hubNotebookContent");
  // Hub Back button: call this; wait for navigateBack before leaving/destroying.
  backToHubButton.attachPress(function () { notebook.requestNavigateBack(); });
  // Later environment selection:
  // notebook.setEnvironment(selectedEnvironment);
});
```

`requestNavigateBack()` checks unsaved changes using Save / Discard / Cancel.
It fires `navigateBack({environment: string})` only after successful saving,
explicit discard, or when the workspace is clean. Cancel, validation errors and
save failures keep Notebook open. It does not cancel an already submitted SAP
calculation; those runs remain independent and can be inspected later.

`setEnvironment(environment)` accepts an environment ID string and returns the
component, as in BPC Git. It also protects unsaved work: the environment change
is deferred until the user saves or discards, and Cancel retains the previous
environment. `getEnvironment()` reports the accepted selection; the hub should
retain that selection if the user cancels. After acceptance, old previews,
drafts and dialogs are cleared, old responses are ignored, and the notebook list
is scoped to the authorized selected environment. Saved notebooks and historical
snapshots are never rewritten to another environment. New notebooks use the hub
environment and ask only for its model. An empty/unauthorized environment shows
a message and never falls back to a remembered environment.

No `componentData` is required. ComponentContainer must occupy a sized hub
content area. Keep the component alive until `navigateBack`; destroy both its
container and component after leaving so polling and dialogs are cleaned up.
Standalone launch remains supported with its own header, theme picker and
environment/model selection.

Notebook navigation uses standard UI5 model group headers and a SearchField. Search filters notebook names, model/environment IDs and notebook IDs locally without loading notebook contents. Standalone groups identify the environment as well as the model; embedded navigation remains restricted to the hub-selected environment. Filtering does not discard an open notebook or unsaved edits.

Dimension member selection uses a standard UI5 Tree in a resizable two-panel dialog: hierarchy choice, ID/description display, search, selected-member removal and Clear all. The chosen SAP hierarchy supplies parent relationships; unauthorized parent IDs are omitted. Search preserves selected IDs and backend save/run validation still resolves nodes. All authorized metadata pages must load before Apply is enabled; more than 50,000 members fails explicitly. Other metadata pickers remain simple lists.

Result previews use the standard `sap.ui.table.Table` grid, with resizable/reorderable columns, horizontal scrolling and 50-row server pages. Cell values preserve exact SAP decimal text and member IDs. This is a grid preview, not AnalyticalTable: the REST/JSON service does not supply analytical OData binding, so no automatic totals/subtotals are implied.

## Refresh deployed UI resources

The standalone bootstrap enables SAPUI5's standard application cache buster. The component manifest loads its stylesheet, avoiding an additional unversioned CSS request. After an abapGit import, refresh metadata for this repository using `node tools/refresh-ui-cache.cjs --codex-env` with `BPC_ADT_TOOL_ROOT` configured. This calls `/sap/bc/ui5_ui5/sap/zbpc_notebook/do-update-meta-data` and verifies the cache-busted component resource. It does not invalidate other applications or change hosting.

SAP documents [bootstrap cache-buster configuration](https://help.sap.com/docs/SAPUI5/7d0efeaa9ccd4731afb386284cfdc3a9/c1c3e2f70066465dbb794c866b933ed5.html) and [per-repository metadata refresh](https://help.sap.com/docs/SAPUI5/b2f662dd9d7a4ec680056733050b4d34/4cfe7eff3001447a9d4b0abeaba95166.html). Embedded mode continues to use the hub's core; the hub should load the component using its standard UI5 application cache-buster integration.

## Notebook folders

The left workspace supports private one-level folders, rename, move/unfile, collapse/expand and search across folders. Existing notebooks remain Unfiled until moved. Folder organization does not change source, notebook revisions, runs or handler bindings. See [folder usage and persistence](docs/notebook-folders.md).

## Notebook technical identity

SAP creation first selects the authorized BPC environment/model, then requires a technical name and description. The same requirement applies to New Notebook, demo creation and `POST /notebooks`; APIs must supply `technicalName` and `description`. A dimension is selected for each dimension input, not part of notebook identity. The local simulator has no SAP context picker and uses an explicit unassigned environment/model scope when these fields are empty.

Technical names match `^[A-Z][A-Z0-9_]{0,29}$`: 1–30 uppercase ASCII letters, digits and underscores, starting with a letter. Names are unique across all users in the SAP client for the exact environment/model pair. A name is immutable after assignment. Reservations remain after deletion or a context move, preventing ambiguous reuse; a context move reserves the same name in the new scope and fails atomically if taken. Descriptions are required single-line Unicode text, at most 240 characters, and can be edited using **Notebook identity**. Names and descriptions appear in the header/list and are searchable.

Existing notebooks show “Technical name not assigned”. Assign identity explicitly using the toolbar; no automatic names are invented. The UUID, source revisions, historical runs, datasets, checksums and unsaved editor drafts remain unchanged. Identity has its own optimistic revision and immutable sidecar history. Legacy notebooks can still be edited/executed by UUID until assigned. Calculation saves do not edit descriptions; use the identity endpoint/dialog.

`POST /notebook-identity` takes `{notebookId, expectedRevision, expectedIdentityRevision, technicalName, description}`. `expectedIdentityRevision` is zero for first assignment. The endpoint returns `{technicalName, description, identityRevision}` and checks notebook ownership/current revision before assigning. Read/create/save/list responses include these identity fields; historical calculation snapshots remain in their original format.

Future integration can resolve an explicitly pinned revision with `POST /notebook-resolve`: `{environment, model, technicalName, approvedRevision}`. The corresponding ABAP API is `zcl_bn_identity=>resolve( environment = ... model = ... technical_name = ... approved_revision = ... )`, returning the immutable notebook including its UUID/revision. It validates owner access, document integrity, deletion status and the exact context of that saved revision. There is no implicit latest revision, approval workflow or cross-user release. Old scope reservations can resolve only saved revisions actually using that scope.

This resolution contract does not execute Script Logic or enable posting. Existing Script Logic handlers still use their separately registered pinned binding; an approved integration must resolve the technical name and explicitly bind/execute a reviewed revision. Financial output validation and transaction rules remain required.
