# DEMREVID 003 inspection adapter

Deploy this branch's Notebook classes/UI before the Chorus class `ZCL_BPC_DEMREVID_NOTEBOOK`, which depends on `ZCL_BN_CONTEXT->EMIT_TABLE`. The Chorus calculation must include the step-inspection refactor.

The adapter accepts only `CH_PLANNING / DEMREVID`. CATEGORY must contain one member and TIME must contain frozen base members. It passes `io->current_view()` and `io->script_parameters()` to `INSPECT_UNTIL`; the calculation's current-view helper builds EQ ranges without expanding TIME again.

Define `FFLASMATGROUPS` as a boolean. The adapter maps true/false to the existing calculation's 1/0 convention. `FFLASMATGROUPSID` must be `MATGROUPID038` for Network Services suppression.

```abap
zcl_bpc_demrevid_notebook=>execute(
  io = io
  stop_after = io->input( 'STOP_AFTER' )
  row_limit = CONV i( io->input( 'ROW_LIMIT' ) ) ).
```

Each execution reruns prerequisites in a fresh calculation instance through the chosen step. It emits named, bounded snapshots and FINAL_OUTPUT; it does not call BPC writeback. This is inspection, not a replacement Data Manager package.

## Named output tables

`io->emit_table( name = 'NAME' rows = flat_table total_count = source_count )` copies a flat structured ABAP table, including its schema when empty. Nested/reference columns are rejected. There are at most 50 unique named tables per cell and 5,000 preview rows per table. Values remain text to preserve member IDs and decimal precision.

`GET /output?...&table=<encoded name>` returns schema, positional `rows[].values`, stored `total`, full `sourceTotal`, truncation status and a table catalog. Existing key/amount output remains supported. The UI offers a dataset selector and renders the returned dimension columns.

## NPL verification, 8 October 2026

ABAP Unit passed for the Notebook BPC/context tests and Chorus adapter guards. A synthetic background run verified all 21 DEMREVID columns, leading-zero account IDs, DEMREVID052, truncation, empty-table schema and rejection of unknown table names. See `evidence/named-tables.json`. All 41 serialized Notebook files matched SAP; 16 local tests passed.

The clone's category is `Actual` (case-sensitive). Fiscal node `2025.REG` requires hierarchy `PARENTH2`. A ready notebook is saved as `E82AEA36D1571FD1B0DE3B85743482FF`, titled **DEMREVID 003 - allocation inspection**.

Full live inspection is blocked: DEMREVID initialization reaches `ZCL_BPC_DIM_MATCONN`, which references missing BW type `/BI0/OIMATERIAL`. The failed job is preserved in `evidence/demrevid-inspection.json`. No full allocation result or suppression correctness is claimed from the synthetic display test. Restore that dependency on the clone, then run the inspection through `FFLAS_RATIOS_BY_MATERIAL` and select `FFLAS_RATIOS_BY_MATERIAL/SKIPPED_MATERIAL_FLAGS`.

To create another notebook using existing configured credentials without printing them:

```powershell
$env:BPC_ADT_TOOL_ROOT = '<installed ADT MCP package directory>'
node tools/create-demrevid-inspection.cjs --category=Actual --time=2025.REG --hierarchy=PARENTH2
# Add --run only when the calculation dependencies are available.
node tools/check-named-tables.cjs
```
