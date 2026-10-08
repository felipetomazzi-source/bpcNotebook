# bpcNotebook

For calculation conversion agents, start with the [definitive feature and implementation guide](docs/AGENT-REFERENCE.md). It consolidates current APIs, Script syntax, reference scopes, dependency limits and the BPC result contract.


A standalone SAPUI5 notebook for ABAP calculations with versioned source, typed inputs, explicit dependencies, frozen runs and persisted output previews.

```powershell
npm start
# Open http://127.0.0.1:4173 → Open allocation demo → Run all
npm test
npm run pack:sap
```

The local service **simulates two demo cell bodies**. The SAP DEV version is deployed on the connected ABAP system, client **001**, with access enabled for **DEVELOPER**. The browser allocation demo completed as a real SAP background job and produced CC100 = **66,000**. The completed allocation integration is on `main` and is pulled through SAP abapGit using transport `NPLK900126`. All **56** repository artifacts pass actual SAP import/serialization comparison. Automated dangerous ABAP Unit tests remain blocked by the client risk policy. Production execution remains blocked.

[Open the deployed SAP notebook](http://vhcalnplci:8000/sap/bc/ui5_ui5/sap/zbpc_notebook/index.html?sap-client=001). Log in as DEVELOPER, choose **Open allocation demo**, select the environment/model, choose **CATEGORY** and **TIME**, then **Save version → Run all** and select **allocate**.

- [Design and runtime contract](docs/DESIGN.md)
- [Installation and remaining production requirements](docs/INSTALL.md)
- [BPC selections, frozen parameters and calculation adapters](docs/bpc-inputs.md)
- [Notebook Script and metadata completion](docs/notebook-script.md)
- [Notebook handlers in BPC Script Logic](docs/notebook-script-logic.md)
- [Notebook deletion and loading performance](docs/notebook-management.md)
- [API contract](docs/API.md)
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
