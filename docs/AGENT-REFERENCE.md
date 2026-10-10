# BPC Notebook: definitive calculation conversion guide

Updated: 9 October 2026. Includes complete native working datasets, accountant-facing stages, hub embedding, model search, hierarchy pickers, grid previews and native validation tools. This guide consolidates the current implementation; earlier milestone documents can describe superseded limitations.

## 1. Instructions for the conversion agent

Convert the requested calculation while preserving business behavior, SAP numeric types, authorization, fiscal-period semantics and transaction ownership. Successful compilation or an empty result does not establish equivalence.

Inventory the original calculation before editing: environment/model, inputs, dimensions, stored/computed properties, reference periods, lookup precedence, grouping, signs, ordering, rounding, output comparison and posting semantics. Identify installed classes/DDIC dependencies and representative comparison data.

Use generic BPC adapters for reads. Use ABAP cells or installed custom ABAP services for complex transformations. Use Notebook Script only within its documented grammar. Never use a bounded preview as complete calculation state or as implicit writeback.

**Calculation architecture:** use visible ABAP stages with `publish_dataset` / `read_dataset` for complete native multidimensional handoff. A single ABAP cell/service is also supported. Read complete output/reference facts in the initial stage and retain them; later stages use those artifacts. See [working datasets and execution boundaries](working-datasets.md).

## 2. Capability map

| Feature | Implemented behavior |
|---|---|
| Authoring | ABAP and Script cells, typed inputs, immutable saved versions/history |
| Execution | Native SAP compilation/background jobs and frozen run snapshots |
| Dependencies | Earlier-cell dependencies, freshness checks, all/through/one execution |
| Working state | Complete typed/dynamic flat SAP tables, immutable publication and private consuming copies |
| Selections | Authorized dimension members/ranges, actual hierarchy expansion |
| Metadata | Generic members, descriptions, properties, fields and hierarchies |
| Model reads | Security-enabled, validated, dynamically typed flat SAP tables |
| Reference data | Explicit mapping/lookback read scope separate from output periods |
| Custom code | ABAP cells can call installed ABAP classes/services |
| Inspection | Messages, bounded named previews, schemas/counts, stage timing/checkpoints |
| Result comparison | Complete native tables, all supplied dimensions and exact SIGNEDDATA; added/missing/changed counts and bounded differences |
| Read diagnostics | Effective filters, separate output/reference periods, security mode and complete native row counts |
| Test fixtures | Explicit native schema/member-validated private input tables; no live fallback or allocation publication |
| Script Logic | Revision-pinned NOTEBOOK BAdI handlers; preview/allocation modes |
| Allocation result | Explicit native result validated before returning CT_DATA |
| UI | Standard UI5 Setup/stage tabs, explanations, collapsed Advanced ABAP, boolean switches, tree selectors, grid previews, Horizon themes, model grouping/search |
| Management | Notebook/cell deletion, saved history, Save/Discard/Cancel navigation |
| Hub | Shared UI5 core/theme, environment setting and guarded Back event |

Not implemented: automatic recursive-driver scheduling, a circular-dependency solver, installed derived-property providers, a Process Flow screen, analytical OData binding, cross-user published handlers, or production release approval.

For validation, use `io->compare_results( name = ... original = ... notebook = ... preview_rows = 100 )` on complete native results. Adapter reads expose `READ_n/SUMMARY` and `READ_n/FILTERS_AND_PERIODS` automatically. Reviewed test services can install native tables with `io->enable_fixtures( )` before reading. See [the full native validation contract and examples](native-validation.md), including duplicate-key rules, input-reader injection into both implementations, retry restrictions and verification evidence.

## 3. Application and source locations

- Repository: https://github.com/felipetomazzi-source/bpcNotebook
- SAP package/BSP: `ZBPC_NOTEBOOK`.
- Standalone: `/sap/bc/ui5_ui5/sap/zbpc_notebook/index.html?sap-client=<client>`.
- Component: `bpc.notebook`; URL `/sap/bc/ui5_ui5/sap/zbpc_notebook/`.
- Native REST base: `/sap/bc/zbpc_notebook`; preserve authenticated SAP client.
- UI5 minimum 1.120.0; tested runtime reports 1.120.40.
- Libraries: `sap.m`, `sap.ui.table`, `sap.ui.layout`, `sap.ui.codeeditor`.
- Frontend source: `webapp/`; generated padded BSP resources: `src/zbpc_notebook.wapa.*`.
- Cell context API: `src/zcl_bn_context.clas.abap`.
- Generic adapter: `src/zcl_bn_bpc.clas.abap`.
- Execution/storage: `src/zcl_bn_service.clas.abap`, `src/zcl_bn_store.clas.abap`.
- Compiler/Script: `src/zcl_bn_compiler.clas.abap`, `webapp/model/Script.js`.
- BAdI: `src/zcl_bn_logic.clas.abap`, enhancement `ZBN_NOTEBOOK_BADI`.

Current repository bootstrap files reference SAP's UI5 CDN. A sealed remote installation can have different hosting. Verify its deployed runtime rather than assuming the connected test deployment proves that remote configuration.

## 4. Authoring and management

1. Create a notebook and select an authorized environment/model.
2. Define required calculation inputs, reference inputs and optional flags/budgets.
3. Add ABAP or Script cells with stable unique IDs and declared earlier-cell dependencies.
4. Save, validate with SAP's compiler, then execute and compare with the original.
5. Inspect messages, stage boundaries and named previews.
6. Bind a saved revision to Script Logic only after reviewing its scope/result contract.

Missing required selections may be saved as a draft but block execution. Source/input/context changes mark affected results stale. Notebook navigation groups by model and searches titles, models, environments and IDs; embedded navigation stays in the hub-selected environment. Search preserves an open unsaved draft.

ABAP editors have syntax colors/line numbers. **BPC code** selects models, dimensions, properties and members, previews ABAP and inserts a snippet into the active ABAP cell. It does not change the notebook model. Script cells offer metadata completion and **Generated ABAP** inspection.

Deleting a notebook hides it, blocks new execution and bound handlers, and retains immutable history/runs. Active queued/running jobs prevent deletion. Deleting a cell also removes transitive dependents after confirmation; save applies the edit. Navigation offers Save/Discard/Cancel; a failed save or Cancel prevents leaving.

## 5. Input definitions and typed access

Definition shape below requires actual authorized IDs and real ABAP source before use:

```json
{
  "title":"Reviewed allocation", "environment":"<ENVIRONMENT>", "model":"<MODEL>",
  "inputs":[
    {"name":"CATEGORY","type":"member","dimension":"CATEGORY","required":true,"selected":["<CATEGORY_ID>"]},
    {"name":"TIME","type":"range","dimension":"TIME","hierarchy":"<REAL_HIERARCHY>","required":true,"selected":["<NODE_OR_PERIOD>"]},
    {"name":"factor","type":"number","value":1.1},
    {"name":"suppressZero","type":"boolean","value":false},
    {"name":"label","type":"string","value":"Allocation"},
    {"name":"RUN_SECONDS","type":"number","value":600}
  ],
  "cells":[{"id":"calculate","title":"Calculate","dependencies":[],"source":"<ABAP>"}]
}
```

Member selects one ID. Range accepts up to 100 selected nodes/base IDs; SAP expands nodes through the actual hierarchy, authorizes base members, deduplicates and freezes the result. `resolved` and fiscal links are backend-owned. Use metadata instead of hardcoded choices. Deterministic ID ordering is not fiscal ordering.

```abap
DATA factor TYPE decfloat34.
factor = io->input( 'factor' ).
DATA(category) = io->member( 'CATEGORY' ).
DATA(selected_time) = io->selection( 'TIME' ).
DATA(output_periods) = io->range( 'TIME' ).
DATA(suppress) = xsdbool( io->input( 'suppressZero' ) = 'true' ).
DATA(cv) = io->current_view( ).
DATA(parameters) = io->script_parameters( ).
```

| API | Contract |
|---|---|
| `input(name)` | Scalar string representation; member/range raises INPUT_TYPE |
| `member(name)` | `UJ_DIM_MEMBER`, exactly one selection |
| `selection(name)` | `ZCL_BN_TYPES=>TT_IDS`, original selected IDs/nodes |
| `range(name)` | `UJA_T_DIM_MEMBER`, frozen resolved IDs |
| `current_view()` | `UJK_T_CV`, resolved calculation dimensions; excludes reference-only inputs |
| `script_parameters()` | `UJK_T_SCRIPT_LOGIC_HASHTABLE`, scalar/comma-separated resolved parameter values |
| `environment`, `model` | Read-only frozen context |

All cells receive the same frozen inputs. Submission validates again; changed expansion requires saving again. Execution/retry rechecks access without silently changing IDs.

## 6. Reference data and fiscal periods

Ordinary model reads remain inside calculation scope. Explicitly declare mapping/lookback periods outside output scope:

```json
{
  "name":"REFERENCE_TIME","type":"range","dimension":"TIME",
  "hierarchy":"<REAL_HIERARCHY>","required":true,
  "selected":["<MAPPING_PERIOD_ID>"],"purpose":"reference",
  "lookbackFrom":"TIME","lookbackSteps":1
}
```

`lookbackFrom` names the calculation input. Lookback steps support 1–24. SAP uses stored `PRIOR_PERIOD`/`NEXT_PERIOD`, authorizes and freezes required members/links. It fails if needed metadata/access is missing.

```abap
DATA(calculation_model) = io->bpc_model( ).
DATA(reference_model) = io->reference_model( ).
" Guard an empty output_periods table before indexing.
DATA(prior_period) = io->offset_period(
  member = output_periods[ 1 ] offset_by = -1 ).
```

`reference_model()` reads output IDs plus declared references for explicit reference dimensions. Other dimensions retain restrictions. Reference-only IDs do not become output periods. `offset_period()` follows frozen links, supports absolute offset at most 24, defaults dimension to TIME and rejects targets outside frozen authorized periods.

For period-specific conditions, use membership in selected/resolved rule-period sets or reviewed fiscal metadata logic. Define overlap precedence. Never slice member names, compare them alphabetically for date ordering or assume twelve calendar periods.

Script Logic references require explicit `READ_REFERENCES = DECLARED`: permission to replace caller **read** restrictions for declared reference dimensions only. It does not widen output/write scope. Reference input/hierarchy overrides are prohibited.

## 7. Generic dimensions

```abap
DATA(dim) = io->bpc_dimension( 'MATCONN' ).
DATA(member_ref) = dim->member_data( ).
FIELD-SYMBOLS <members> TYPE STANDARD TABLE.
ASSIGN member_ref->* TO <members>.
DATA(properties) = dim->properties( ).
DATA(hierarchies) = dim->hierarchies( ).
DATA(product_type) = dim->property(
  member = '<MEMBER_ID>' name = 'PRODUCT_TYPE' ).
DATA(children) = dim->children(
  member = '<NODE_ID>' hierarchy = '<REAL_HIERARCHY>' ).
io->emit_table( name = 'MEMBERS' rows = <members> ).
```

`member_data(ids = VALUE #( ( CONV string( '<ID>' ) ) ))` restricts IDs. Omitted IDs return authorized members; requested missing/unauthorized IDs fail. Native fields include ID, EVDESCRIPTION, stored properties and hierarchy parent columns. `properties()` describes name/type/length/decimals/source; `hierarchies()` discovers names; `children()` resolves base children, not a UI node page.

Optional `model_name` selects another model in the same environment outside Script Logic. Script Logic adapters use the calling model.

For explicit fiscal metadata discovery, `dim->fiscal_links(ids)` returns dimension/member/prior/next links from stored properties. It does not authorize arbitrary output periods; frozen runtime offsets still use `io->offset_period()`. `ZCL_BN_BPC=>describe_table(table = data_reference source = 'stored')` describes a dynamic table, including its empty schema. These are metadata utilities, not calculation/write adapters.

UI member selection uses a resizable standard tree with hierarchy/display controls, search, selected members, removal and Clear all. All authorized metadata pages load before Apply. Budget: 50,000 members, explicit failure on overflow/incomplete loading. Unauthorized parent IDs are omitted. Backend save/run validation is authoritative.

## 8. Generic model reads

```abap
DATA(adapter) = io->bpc_model( ).
DATA(dimensions) = adapter->dimensions( ).
DATA(fields) = adapter->fields( ).
DATA(facts_ref) = adapter->read_data( max_rows = 100000 ).
FIELD-SYMBOLS <facts> TYPE STANDARD TABLE.
ASSIGN facts_ref->* TO <facts>.
io->check_rows( lines( <facts> ) ).
io->emit_table( name = 'FACTS' rows = <facts> ).
```

The reference points to a native flat SAP table: dimension member columns and native `UJ_SDATA` SIGNEDDATA. Keep full tables in SAP for arithmetic; discover schema instead of inventing types.

```abap
DATA(filters) = VALUE zcl_bn_bpc=>tt_filters(
  ( dimension = 'ACCOUNT'
    members = VALUE #( ( CONV string( '<BASE_ACCOUNT_ID>' ) ) ) ) ).
DATA(filtered_ref) = adapter->read_data(
  filters = filters max_rows = 100000 ).
```

Additional filters intersect frozen selections/caller scope and cannot widen them. IDs within one filter are alternatives; duplicate dimension filters intersect. Empty filters, unknown dimensions, unauthorized/missing IDs, nodes and disjoint intersections fail. IDs are validated even if intersection would discard them. Each explicit filter supports 1–10,000 base IDs.

`bpc_model(name = '<OTHER_MODEL>')` is available outside Script Logic. Shared dimension names inherit/revalidate selections; absent dimensions do not constrain the other model. Shared names do not prove business equivalence.

Reads enable SAP security, disable query BAdI enrichment and use 1,000-row packages. Default max_rows is 100,000; range 1–1,000,000. Overflow raises BPC_READ_LIMIT, never a partial calculation input. A 10,000-package guard applies.

## 9. Cell dependencies and full working state

Dependencies must reference unique earlier cell IDs. Missing dependencies, invalid ordering and cycles fail.

```abap
" Producer cell prepare, dependencies: []
DATA rows TYPE zcl_bn_context=>tt_rows.
APPEND VALUE #( key = 'DRIVER_2' amount = '100' ) TO rows.
APPEND VALUE #( key = 'DRIVER_3' amount = '50' ) TO rows.
io->emit( rows ).
```

```abap
" Separate consumer cell, dependencies: ["prepare"]
DATA(rows) = io->read( 'prepare' ).
" Modify the private copy and publish it when appropriate.
io->emit( rows ).
```

TT_ROWS contains only `key TYPE string`, `amount TYPE decfloat34`. `read()` returns a private value copy of a declared scalar dependency; `emit()` publishes up to 10,000 scalar rows. `emit_table()` does not create a full working dataset and cannot be retrieved as one through `read()`.

For full multidimensional state, publish a complete flat table and retrieve a private native copy:

```abap
" Producer, retaining native dimensions and SIGNEDDATA.
io->publish_dataset( name = 'REVENUES' rows = revenues ).
" Consumer declares the producing cell as a dependency.
DATA(native_rows) = io->read_dataset( dependency = 'prepare' name = 'REVENUES' ).
FIELD-SYMBOLS <revenues> TYPE STANDARD TABLE.
ASSIGN native_rows->* TO <revenues>.
```

Native types, exact numeric values, iteration order and empty schemas are preserved. Returned tables are standard tables with an empty key; original sorted/hashed keys are not retained. Full tables remain on SAP; automatic DATASET/<name> previews are bounded. Ownership, member authorization, source/output revision, checksums, dependencies, budgets and 30-day retention are checked. Published artifacts commit only at successful cell boundaries; mid-cell failures are not resumable. `/datasets` returns full counts and schemas without binary contents. See [the full dataset contract](working-datasets.md).


| Execution scope | Boundary |
|---|---|
| all | All cells in notebook order |
| through | First cell through selected cell |
| one | Selected cell using valid prior prerequisite publications |

Missing/stale prerequisites block one-cell execution. Source/input/context changes or superseding upstream publication invalidate consumers even if values match. BAdI results cannot satisfy ordinary editor-run dependencies.

## 10. Custom ABAP, recursive drivers and transformations

An ABAP cell can call an installed class:

```abap
" Proposed custom class: implement and activate before using this example.
zcl_my_driver_resolver=>execute( io = io ).
```

A service can accept `io TYPE REF TO zcl_bn_context`, raise zcx_bn, read generic adapters and retain complete native multidimensional tables. Use ABAP for joins, grouping, lookups, sorting, deletion and native numeric assignments.

For driver 10 -> 7 -> {2,3}, discover dependencies, calculate 2/3 before 7 and then 10, caching each result once per run. Visiting/visited states detect cycles. Actual circular calculations require explicit initial values, convergence rules and iteration limits; no built-in solver exists.

Preserve original duplicate/fallback precedence, first-match ordering, signs, zero denominators, missing-member normalization and assignment rounding. Do not replace a business-specific correction with mathematical normalization.

Trusted ABAP is not sandboxed. Honor authorization and the BAdI transaction contract; do not introduce direct business writes into preview execution. Notebook source snapshots do not freeze a called class implementation: pin/record its transport/version separately.

## 11. Messages, previews and stage checkpoints

```abap
io->checkpoint( name = 'CALCULATE' state = 'running'
  inputs = VALUE #( ( `SOURCE_FACTS` ) )
  outputs = VALUE #( ( `CALCULATE/RESULT` ) ) ).
" Work with full native tables here.
io->check_budget( ).
io->emit_table( name = 'CALCULATE/RESULT' rows = <facts> ).
io->message( |Calculated { lines( <facts> ) } working rows| ).
io->checkpoint( name = 'CALCULATE' state = 'succeeded' ).
```

Checkpoint states are running then succeeded, with one active stage at a time, unique names and timing. Tables named `STAGE/...` are associated on completion. These boundaries document progress; they do not enable arbitrary restart/resume.

`emit_table(name, rows, total_count, elapsed_us)` accepts flat structured typed/dynamic tables. It preserves empty schemas, stores up to 5,000 preview rows and records full source count. Nested/reference columns fail. A manually sliced preview may supply the full total_count; that count cannot be smaller than supplied rows. Maximum 200 named tables and one million aggregate preview values per cell.

PREVIEW_ROWS is a service convention for manually slicing previews, not an automatic setting in generic emit_table. The service must apply it, as the allocation port does.

Grid previews use `sap.ui.table.Table`, 50-row server pages, column resizing/reordering and horizontal scrolling. IDs/amounts stay exact strings. `1–50 of 100 · preview of 3550 source rows` means a saved 100-row preview of 3,550 source rows. Empty results retain columns. Automatic analytical totals/grouping/OData binding are not implemented.

Failed/cancelled background runs may expose labeled partial previews; those cannot satisfy dependencies or final allocation publication. Synchronous BAdI failure publishes no completed result.

## 12. Notebook Script v1 language

Script compiles deterministically to ABAP on save. Exact authored text is preserved in a versioned UTF-8/base64 envelope with script-line diagnostic markers. SAP checks generated source before accepting a script save. Arbitrary ABAP/general method calls cannot be mixed into a Script cell.

```text
# Requires CATEGORY, TIME and factor inputs. Names are model examples.
dimension materials = DEMREVID-MATCONN
members connections = materials
show connections as "MEMBERS"

model plan = DEMREVID
data facts = plan where TIME = range("TIME") and CATEGORY = selection("CATEGORY") limit 10000
let factor = number(input("factor"))
for row in facts
  if row.SIGNEDDATA != 0
    row.SIGNEDDATA = row.SIGNEDDATA * factor
  end
end
show facts as "FACTS"
```

| Syntax | Meaning |
|---|---|
| `dimension d = MODEL-DIMENSION` | Dimension adapter; a dimension alone uses notebook model |
| `model m = MODEL` | Model adapter |
| `members rows = d` | Native members; optional `["ID", "ID2"]` |
| `let label = d-PROPERTY("ID")` | Stored property; fully qualified model-dimension-property also works |
| `data rows = m where DIM = ["ID"] and OTHER = range("INPUT") limit 10000` | Validated model read; where/limit optional |
| `let factor = number(input("factor"))` | Typed variable/expression |
| `for row in rows` / `end` | Loop and runtime-checked field access |
| `if condition` / `else` / `end` | Conditional |
| `show rows as "RESULT"` | Named bounded preview |
| `table rows` | Declare scalar key/amount table |
| `append rows key = "DRIVER" amount = factor * 100` | Append scalar row |
| `read rows = "earlier_cell"` | Declared scalar dependency |
| `emit rows` | Publish scalar result |
| `message expression` | Diagnostic message |

Expressions support numbers, double-quoted text, true/false, parentheses, `+ - * / %`, comparisons `== != < <= > >=`, and `and or not`. Built-ins: input, member, selection, range, number, text, count, concat. Convert numeric input strings with number; use concat for text. Test a boolean input with `input("suppressZero") == "true"`. `#` begins an unquoted comment. Variable identifiers are case-sensitive ASCII names; table fields resolve case-insensitively to SAP components.

Typing `MODEL-` suggests dimensions; `MODEL-DIMENSION-` or a declared dimension alias suggests stored properties. Ctrl+Space requests completion. Authorized metadata is session-cached; reload after metadata changes. Suggestions do not replace runtime checks.

Script v1 lacks grouped aggregation, joins, keyed lookups, sorting, general row deletion/calls, reference-model sugar and allocation-result publication. Use ABAP for these. Generated cell source must fit 60,000 characters. Do not alter the saved envelope to invent grammar. Editing generated ABAP outside the Script editor causes ordinary ABAP treatment rather than silently discarding the edit.

## 13. Stored versus derived properties

Stored property access reads real stored metadata. A `source = 'virtual'` request reaches an extension hook whose base behavior rejects it. `io->property_provider(implementation, version)` currently always raises PROPERTY_PROVIDER: no reviewed provider is installed.

Do not instantiate Chorus constructors automatically or substitute a stored value for a computed property. Remove unused legacy dependencies, calculate simple required derived values explicitly in ABAP, or implement a separately reviewed/versioned provider extension and document its dependency/version.

For DEMREVID003, stored MATCONN PRODUCT_TYPE is consumed; the failing legacy `_PROD_TYPE_ID` constructor output is a separate concept and is not required by the current port. Inspect actual usage before restoring such dependencies.

## 14. Script Logic handlers

Save a notebook with environment/model, then bind a named handler using **Script Logic**. Binding pins notebook revision/checksum; later saves do not move it. Rebind explicitly. Bindings belong to the executing owner and use optimistic handler revision checks. Names are case-insensitive identifiers of 1–30 characters, starting with a letter.

```text
*START_BADI NOTEBOOK
QUERY = OFF
WRITE = OFF
EXECUTION = PREVIEW
HANDLER = MY_REVIEWED_HANDLER
INPUT_FACTOR = $FACTOR$
INPUT_SUPPRESSZERO = ON
*END_BADI
```

Declare factor/suppressZero before passing these example overrides. INPUT_<name> only overrides declared inputs. Boolean overrides accept TRUE/FALSE, ON/OFF, 1/0 or X/empty. Member/range overrides are comma-separated IDs; HIERARCHY_<name> accompanies an explicit selection where required.

Without an override, matching caller CV members supply the input; otherwise the saved selection/default applies. Explicit selections/defaults must stay within caller scope. Caller filters also constrain dimensions without notebook inputs. Caller CV allows up to 10,000 base IDs per dimension; input ranges still allow only 100 selected IDs and never silently truncate a larger caller selection.

Reference input/hierarchy overrides are prohibited. Reference reads require READ_REFERENCES = DECLARED. Adapters inside Script Logic use the caller model.

Execution is synchronous under the caller's user/environment/model. No background submission, internal COMMIT or ROLLBACK is introduced. Completed notebook records are staged only after success in the caller LUW: commit makes them durable, rollback removes them. Reinvoke Script Logic for another run; ordinary /retry rejects Script Logic runs. Exceptions become CX_UJ_CUSTOM_LOGIC failures.

## 15. Explicit BPC result and posting contract

Browser runs have no direct BPC save endpoint. Preview tables never implicitly become writeback. Allocation requires **both** an allocation-mode handler binding and explicit allocation invocation:

```text
*START_BADI NOTEBOOK
QUERY = OFF
WRITE = ON
EXECUTION = ALLOCATION
READ_REFERENCES = DECLARED
HANDLER = MY_REVIEWED_ALLOCATION
*END_BADI
```

READ_REFERENCES is needed when the calculation uses declared reference reads. Changing WRITE alone is insufficient.

```abap
" final_delta must use the exact target flat schema and native amount type.
io->allocation_result( name = 'FINAL_DELTA'
  rows = final_delta kind = 'delta' ).
```

This creates a private complete typed copy in SAP, separate from previews. The context distinguishes replacement and delta; the allocation execution path requires exactly one delta result and does not reinterpret replacement automatically. It validates target context, exact model dimensions/native amount schema, base members, calculation/caller output scope and member write authorization. CT_DATA changes only after the whole result validates/converts; failure leaves incoming CT_DATA intact. BPC owns subsequent posting and its transaction.

For the existing DEMREVID003 port, delta means a **replacement change-set**, not additive new-minus-old arithmetic:

| Previous | New | Returned change-set |
|---|---|---|
| 100 | 120 | 120 |
| 100 | 100 | Omit record |
| -50 | Record disappears | 0 at the old complete dimensional key |
| No record | -25 | -25 |

Preserve the original calculation's semantics; never subtract old amounts again or forget clearing vanished records. The result-return boundary has native BAdI fixture tests. Actual intended financial posting/rollback and full business equivalence remain acceptance work; production restrictions remain.

## 16. Snapshots, retries and resource budgets

Runs freeze notebook/source revision, scalar values, selected/resolved IDs, fiscal links and dependency bindings. They do not archive every live external fact input or freeze called custom class implementations.

- Scalar-only ordinary retry preserves historical source/inputs/bindings and rechecks access. BPC model-bound historical retries fail DATA_SNAPSHOT; Run all establishes a new fact snapshot. A stage consuming a prior-run artifact cannot issue fresh generic model fact reads.
- Historical reference-read retry fails DATA_SNAPSHOT (409). Run all establishes a new source/data invocation instead of silently mixing historical context and fresh references.
- Fixture validation runs also reject historical retry with DATA_SNAPSHOT. Reinstall identical complete fixtures in a new run; fixture datasets cannot satisfy ordinary-run prerequisites. Within the same validation run, each stage may retrieve retained fixture artifacts and must enable them before model reads; live fallback is blocked. Fixture Run cell reusing another run is rejected.
- Script Logic runs must be reinvoked by their caller.
- Run states: queued, running, succeeded, failed, cancelled. No automatic business-calculation retry.
- Cancellation/timeouts are cooperative at cell/stage/read boundaries and explicit check_budget calls. Arbitrary ABAP is not safely preempted by this API; SAP job controls may be required.

| Budget | Current contract |
|---|---|
| Cell source | 60,000 characters |
| RUN_SECONDS | Integer 1–7,200; default 600 seconds |
| WORK_ROWS | Integer 1–1,000,000; enforced where service calls check_rows |
| READ_LIMIT | Allocation/service convention; pass to read_data explicitly |
| read_data max_rows | 1–1,000,000; default 100,000; complete result or error |
| PREVIEW_ROWS | 1–5,000; native artifact previews default to 200 |
| DATASET_BYTES | Per-cell aggregate native input/output byte budget; default 64 MiB, maximum 256 MiB; complete data or explicit error |
| Scalar emit | Maximum 10,000 rows |
| Named previews | 200 tables; 5,000 rows/table; one million aggregate values |
| HTTP output page | 1–100 rows; UI requests 50 |
| Fiscal offset/lookback | Maximum 24 steps in frozen authorized links |
| Range input | Maximum 100 selected IDs |

check_rows detects growth without truncating; custom services must call row/budget checks at meaningful boundaries. Larger workloads may require additional packaging, server-side state processing or SAP memory/job configuration.

## 17. DEMREVID003 reference implementation

```abap
zcl_bn_dem_alloc=>execute(
  io = io stop_after = io->input( 'STOP_AFTER' ) ).
```

The original single-cell example declares STOP_AFTER as a string and runs its 20 internal stages inside one cell. The newer `examples/demrevid-stepwise` definitions expose separate ABAP stages and native artifacts; their allocation equivalence is checked separately by the conversion agent. Inputs also include CATEGORY, TIME, REFERENCE_TIME, READ_LIMIT, WORK_ROWS, PREVIEW_ROWS, RUN_SECONDS, FFLASMATGROUPS, FFLASMATGROUPSID, DEBUG and HSNS_REALLOC_LOCATIONS. See [the exact allocation contract](demrevid-allocation.md).

STOP_AFTER executes from INITIALISE through a chosen boundary with fresh state and returns no final BPC result. There is no run-only-internal-stage, old-state injection or mid-stage resume.

FFLAS checkpoints retain base revenues before exclusions, skipped-material flags, revenues after exclusions, numerators, ratios before rounding and final ratios/flags. Its correction adds discrepancy to the original selected existing row; do not substitute normalization or invent a remainder row.

ZCL_BN_DEM_MODEL, ZCL_BN_TRANSFORM and ZCL_BN_DIMENSION are legacy compatibility implementations, not universal adapters for every calculation. Installed ZCL_BPC_PARAM/ZCL_BPC_CURRENT_VIEW and BPC DDIC/interfaces remain dependencies when transporting this port.

Connected DEV tests established nonempty metadata/query/checkpoint paths, principally prices with no revenues for the tested selection. That does not prove full allocation equivalence. Representative comparison remains required.

## 18. HTTP API for automation

Use the service rather than direct database manipulation. Native base /sap/bc/zbpc_notebook; local base /api. Preserve sap-client and same-origin authenticated credentials. JSON writes require `X-BPC-Notebook: 1`. Errors carry HTTP status and `{code,message}`. Never log credentials.

| Method/path | Main fields |
|---|---|
| POST /metadata | kind, environment, model, dimension, hierarchy, search, offset |
| GET /notebooks | Owned summaries, including environment/model |
| GET /datasets | runId, cellId, revision=1; completed native output/input manifests, no full binary data |
| POST /notebooks | title, environment, model, inputs, cells; creates revision 1 |
| GET /notebook?id=... | Definition/freshness |
| PUT /notebook | id, title, environment, model, inputs, cells, expectedRevision |
| GET /versions?id=... | Saved immutable history |
| POST /validate | notebookId, cellId; saved source |
| POST /runs | notebookId, expectedRevision, scope, cellId where needed, idempotencyKey |
| GET /runs?notebookId=... | Run summaries |
| GET /run?id=... | Snapshot/status/job/diagnostics/results |
| POST /cancel | id |
| POST /retry | id, idempotencyKey; restrictions above apply |
| GET /output | runId, cellId, revision=1, offset, limit, optional table |
| POST /delete-notebook | notebookId, expectedRevision |
| GET /logic-handler?id=... | Current owner's binding |
| POST /logic-handler | handler, notebookId, expectedRevision, handlerRevision, executionMode |

Metadata kinds: environments, models, dimensions, members, properties, fields. Pages contain up to 100 authorized items; follow more. Member metadata includes id, description, isNode and chosen-hierarchy parent.

Expected revisions prevent lost updates. Source versions/checksums are server-owned. Reuse the identical idempotency key/request after uncertain submission; changed requests with the same key fail. A new intentional run needs a new key. Run requests execute saved source, never new source passed inline.

## 19. Hub integration and visual features

```javascript
var component = sap.ui.component({
  name: 'bpc.notebook', url: '/sap/bc/ui5_ui5/sap/zbpc_notebook/',
  settings: {embedded: true, environment: selectedEnvironment}
});
var container = new sap.ui.core.ComponentContainer({
  component: component, width: '100%', height: '100%'
});
component.attachNavigateBack(function () {
  // Show hub; then destroy container/component using host lifecycle.
});
// Hub Back: component.requestNavigateBack();
// Context changes: component.setEnvironment(environment);
```

The hub retains its header/Back button, loads the core once and supplies the theme. Notebook hides standalone header/theme controls. Both public methods return the component, not approval promises. Cancel/failed Save emits no navigateBack. Environment changes can be cancelled; getEnvironment reports the accepted value. Destroy only after the navigation event.

Standard Horizon Light/Dark, hierarchy selector and grid preview are integrated. ProcessFlow is available in the tested UI5 runtime but **no Notebook Process Flow screen exists**. It would visualize dependencies, not execute them. AnalyticalTable is available but its required analytical OData service/binding is not implemented.

## 20. Local simulation, encoding and deployment

`npm start` serves the loopback prototype at port 4173. It simulates two demo operations and cannot execute arbitrary ABAP/Script, BPC metadata, authorization or posting. Use SAP for acceptance. `npm test` runs local regressions; native evidence is separate.

Edit webapp then run `npm run pack:sap`; do not edit generated WAPA bodies. Preserve explicit UTF-8, existing file-type BOM conventions, line endings, trailing padding and blank lines. ABAP checkout uses UTF-8 without BOM/CRLF; XML preserves BOM/CRLF. Git canonicalization differs from checkout bytes. Never globally trim/reformat serializer artifacts.

A clean diff is insufficient: pull/import in SAP, activate, serialize with actual abapGit and compare against Git blobs. Current evidence covers 56 files, including BSP metadata/mappings. See [encoding instructions](evidence/ENCODING.md). Developer tools use BPC_ADT_TOOL_ROOT and optional --codex-env credentials; SDK/configuration credentials are not product dependencies and must not be copied into the repo.

Verification tools may create fixtures. Remove them afterward using the deletion API; do not repopulate the workspace with test notebooks unnecessarily. Historical versions/executions remain available.

## 21. Acceptance checklist and handoff

- Preserve output/reference scopes, fiscal metadata, member coverage and authorization.
- Compare representative nonempty results with the original across every dimension.
- Compare grouped amounts, signs, precision, assignment rounding and lookup/fallback/duplicate precedence.
- Test suppression on/off, zero denominators, empty input and missing members.
- Compare carry-forward/lookbacks and node/base expansion without name arithmetic.
- Verify missing/stale prerequisites and unauthorized reads/references/writes fail explicitly.
- Compare full replacement and exact delta/change-set, including vanished-record clearing.
- Verify intended caller posting/rollback and failure isolation before business acceptance.
- Exercise cancellation/timeouts/resource overflow; no partial completed publication.
- Pin/version external ABAP implementations and document installed prerequisites.
- Verify real SAP abapGit serialization after deployment.
- Deliver notebook definition/source, class changes, handler revision/contract, comparison evidence and remaining gaps.

Do not claim production readiness from compiler success, UI checks, zero rows or isolated CT_DATA fixtures. Current trusted-author DEV gates/production block remain; arbitrary ABAP is not a sandbox and published cross-user execution is not implemented.

On the connected implementation, DEV access requires exact-user enablement and scoped S_DEVELOP author/view/execute permissions plus necessary job/BPC permissions. Production client category P is rejected. Do not loosen these gates as part of a calculation conversion; use the installation instructions for the actual target.

### Suggested prompt for another agent

> Read docs/AGENT-REFERENCE.md before changing the calculation. Inspect the original calculation and its called dependencies, then port it to BPC Notebook using the implemented generic adapters. Preserve authorization, output/reference scope, actual fiscal-period metadata, numeric types, precedence, rounding and BPC delta semantics. Use visible ABAP stages and complete native dataset handoff, or one ABAP service/cell when appropriate. Do not use bounded previews as working data, invent unsupported Script syntax, or assume derived-property providers exist. Use only the documented complete native dataset API for full-table handoff. Deliver the notebook definition, required ABAP class changes, handler contract if posting is needed, representative original-versus-port comparison evidence and explicit remaining gaps. Keep DEV/production controls and the caller transaction intact.

## 22. Detailed references

This guide is the current entry point. Older file counts, responsive-table paragraphs and no-writeback statements in milestone documents are superseded by the contracts above.

- [Typed inputs](bpc-inputs.md)
- [Generic adapters](generic-bpc-adapters.md)
- [Script grammar](notebook-script.md)
- [Script Logic](notebook-script-logic.md)
- [Allocation/reference/result contract](demrevid-allocation.md)
- [Management](notebook-management.md)
- [HTTP API](API.md)
- [Installation](INSTALL.md)
- [README and hub example](../README.md)
- Native/browser/round-trip evidence under docs/evidence.

## Notebook folders

Use **New folder**, a folder's rename button, and each notebook's move button to organize your own notebooks. **Unfiled** retains all existing notebooks until you move them. Search includes explanations across folders; models group within folders. Folder metadata has its own owner-scoped revision and never rewrites notebook source, execution snapshots or bindings. See [folder contract and verification](notebook-folders.md).
