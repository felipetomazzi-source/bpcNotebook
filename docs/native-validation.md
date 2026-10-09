# Native comparison, read diagnostics and controlled fixtures

These APIs execute inside SAP. They compare complete native tables; browser output remains a bounded preview. They help validate a conversion, but do not establish DEMREVID003 equivalence until both complete implementations have been run against representative identical inputs.

## Compare original and notebook results

Call this from an ABAP cell or reviewed validation service after both implementations return their complete result tables:

```abap
DATA(summary) = io->compare_results(
  name = 'DEMREVID003'
  original = original_result
  notebook = notebook_result
  preview_rows = 100 ).
```

Both tables must be flat, structured native ABAP tables with the same field names, lengths, decimal places and elementary types. Supply every result dimension and `SIGNEDDATA`, without projecting columns or taking a preview first. Every field other than `SIGNEDDATA` forms the complete dimensional key. Row order does not affect matching. Empty tables retain their schema.

`SIGNEDDATA` must be a native packed decimal or decimal floating-point type. Comparison uses native exact equality without conversion through JavaScript, tolerance or rounding. `added` means a key exists only in the notebook result; `missing` means it exists only in the original; `changed` means the same key has a different amount; `unchanged` counts exact matches. A dimension change appears as a missing key and an added key.

Duplicate complete keys fail with `COMPARISON_DUPLICATE_KEY`; the comparator never invents aggregation or lookup precedence. Apply the original calculation's established grouping before comparing. Schema errors fail with `COMPARISON_SCHEMA`.

The returned `ty_comparison` contains `original_rows`, `notebook_rows`, `added`, `missing`, `changed` and `unchanged`. In the execution output selector:

- `DEMREVID003/SUMMARY` contains the full counts.
- `DEMREVID003/DIFFERENCES` contains all dimensions, `DIFFERENCE_KIND`, `ORIGINAL_SIGNEDDATA` and `NOTEBOOK_SIGNEDDATA` for the first differences in deterministic key order.

The difference preview defaults to 100 rows and accepts 1–5,000. Its `total_count` counts every difference even when its preview is smaller. Absence is indicated by the difference kind; a missing side's zero amount must not be interpreted as an existing zero-valued record. Full comparison work stays on SAP and obeys `WORK_ROWS` and execution deadlines.

## Automatic read diagnostics

Model reads obtained through `io->bpc_model( )`, `io->bpc_dimension( )` and `io->reference_model( )` record diagnostics automatically. The context's `reads` property contains the complete structured trace, and the execution dataset persists it on SAP.

For each read the execution output selector exposes:

- `READ_n/SUMMARY`: environment, model, calculation/reference scope, live/fixture source, security mode, completion state, full row count, package count, requested maximum and error code.
- `READ_n/FILTERS_AND_PERIODS`: effective member filters after validation/intersection, frozen output TIME periods and declared reference TIME periods. These categories remain separate.

Successful reads record the complete native count, including zero. A failed read reports `row_count = -1`, because the complete count is unknown; partial packages never become valid calculation input. Read-limit, security, cancellation and query failures remain failures. A zero-row read also adds an explanatory execution message. Filter previews obey the existing 5,000-row display bound; the full trace remains in the SAP execution dataset and in `io->reads`.

Live reads record `SAP_AUTH_ON; QUERY_BADI_OFF`, reflecting the existing adapter's actual query settings. Fixtures record `MEMBER_AUTH_ON; NO_QUERY`. These labels do not disable authorization. Direct legacy queries and separately constructed adapters without a context diagnostic sink are not intercepted.

The native check of `CH_PLANNING / DEMREVID`, CATEGORY `Actual`, TIME `2025.007` returned **zero authorized rows** with those effective filters. This establishes the result of that secured read; it does not prove that no records exist outside the caller's authorized view. Inspect the recorded environment, model, filters and scope before changing the calculation.

There are at most 50 diagnostic reads per cell, with two preview tables per read. Exceeding the limit fails explicitly with `READ_DIAGNOSTICS_LIMIT`. Existing preview-table and resource budgets also apply; split an excessively large validation service into supported execution boundaries rather than silently dropping diagnostics.

## Controlled native fixture injection

Install complete native input tables before the context performs its first model read:

```abap
" fixture_ref points to a complete, native flat table for this model.
io->enable_fixtures( VALUE #(
  ( environment = 'CH_PLANNING'
    model = 'DEMREVID'
    rows = fixture_ref ) ) ).

DATA(adapter) = io->bpc_model( ).
DATA(input_ref) = adapter->read_data( max_rows = 100000 ).
```

`tt_fixtures` supports up to ten distinct environment/model tables. Their environment must match the context. Tables must exactly match each model's complete native schema, including `SIGNEDDATA`. Every dimension member passes the usual member/read-authorization validation, and all rows obey working-table budgets. Fixture metadata is still real SAP metadata. No HTTP JSON fixture-upload API is exposed.

Installation validates all fixtures before enabling the mode and makes private copies. Subsequent adapter reads apply the normal frozen/requested filters to those copies and return a fresh working table each time. Mutating either the source fixture or a returned table cannot change another read. Every read must find an explicitly installed fixture; `FIXTURE_MISSING` fails instead of querying live financial data. `BPC_READ_LIMIT` fails instead of returning partial inputs.

Notebook fixture execution supports one independent cell with no cell dependencies. Keep both implementations and their full working tables inside its validation service. A multi-cell fixture run fails before publishing a completed dataset; full native fixture handoff between cells is not implemented.

Fixture mode rejects installation after live reads or result publication, repeated installation, and Script Logic invocation (`FIXTURE_MODE`). `allocation_result( )` rejects fixture mode with `FIXTURE_POSTING`. Fixture datasets cannot satisfy ordinary later-cell prerequisites, and historical fixture retry fails with `DATA_SNAPSHOT`: start a new validation run and install the same complete fixtures again. Raw fixtures are not retained as an archival replay store.

To compare both implementations against identical inputs, create a separate fresh context for each, install the same fixture catalog into both, and pass their adapter-backed readers into the original and converted calculations. Capture both full returned result tables and call `compare_results` afterward. Keep old-output/reference inputs in that explicit catalog as required by the original delta calculation.

The original calculation must expose an input-reader/testing seam. This feature cannot automatically replace arbitrary legacy RSDRI calls or prevent arbitrary trusted ABAP from invoking a separate writer. Review the validation service so both implementations return in-memory results and do not invoke posting. No financial-data write is needed to use this API.

## Verification and remaining acceptance

The maintained connected DEV check is:

```powershell
$env:BPC_ADT_TOOL_ROOT = 'C:\Users\FelipeTomazzi\mcps\mcp-abap-abap-adt-api'
node tools/check-native-validation.cjs --codex-env
node tools/check-native-validation-api.cjs
```

The first command creates/updates the temporary `$TMP` class `ZCL_BN_VALIDATION_CHECK`, activates it and executes seven assertion groups. It uses authorized existing metadata and a privately copied sample of native input rows. It never publishes allocation output, writes financial facts or creates notebooks. The second command verifies real background execution, persisted comparison/read previews, fixture retry/dependency rejection and the single-cell boundary; it creates temporary notebooks and deletes them afterward. Both sources intentionally target the connected DEV model/periods; adapt those explicit test selections for another system.

Checks cover exact small decimal differences, all supplied dimensions, a changed record beyond 6,000 rows, added/missing counts, bounded previews, duplicate/schema errors, empty schemas, the secured zero-row read, complete multidimensional fixture comparison, copy isolation, missing-fixture/live-fallback rejection, read-limit failure, posting rejection and Script Logic rejection. Evidence is in [native-validation.json](evidence/native-validation.json).

These APIs are native SAP features; the local demo server does not simulate them. These checks validate the comparison and injection mechanisms. Full DEMREVID003 business equivalence, fiscal/mapping/fallback coverage, suppression modes, carry-forward, final delta and caller rollback still require the original and converted allocation to be wired to the same fixture reader and run with representative nonempty data.
