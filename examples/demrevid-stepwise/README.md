# DEMREVID003 step-by-step allocation

Saved SAP notebook: **DEMREVID003 - step-by-step allocation**, ID `E82AEA36D1571FD1B0F434ABC4D096B7`, environment **CH_PLANNING**, model **DEMREVID**. The source is on branch `codex/SSNG-3218-fixture-validation`.

One notebook contains 20 ordered calculation tabs and a final reconciliation tab. Business rules are visible in these cells; the operational notebook does not call the original allocation class or the one-cell allocation engine. Each calculation tab names its original method and explains its rule and the control to inspect. Cells declare only the constants, parameters and flags they use. Local variables needed to import a preceding complete dataset remain local to each independently compiled cell. Advanced ABAP is available for technical maintenance. This first version uses installed generic table/dimension/transform helpers; it is not a no-code rule editor.

## How to test

1. Open BPC Notebook and select CH_PLANNING → DEMREVID → **DEMREVID003 - step-by-step allocation**.
2. In Setup choose CATEGORY and output TIME. Review REFERENCE_TIME separately: it includes mapping periods and any required fiscal lookback/next periods. The saved example uses Actual / 2025.007, with TIME_NA and 2025.008 plus one metadata-based prior period. Change references to suit your output periods; do not infer dates from member names.
3. Review FFLASMATGROUPS and its corresponding FFLASMATGROUPSID. The default suppresses MATGROUPID038. Keep paired flag/ID semantics when configuring more groups.
4. Start at tab 1 using **Run cell**, or select a later tab and use **Run through**. **Run all** executes the complete chain. Later cells require completed, fresh declared predecessors.
5. Inspect read diagnostics, complete dataset counts, bounded DATASET previews and CONTROL_TOTALS. Totals retain key figure/account/material/audit-trail grain; prices and ratios must not be added to revenue totals.
6. In the reconciliation tab inspect complete replacement and delta counts/totals. Zero delta amounts intentionally clear disappeared old records.

Changing inputs or source requires fresh downstream execution. Rerunning the initial stage establishes new complete financial inputs. It retains output/reference facts on SAP; later cells filter those native artifacts rather than reading new financial amounts. Metadata and authorization are checked at each cell boundary. A preview is never a calculation input.

## Actual / 2026.006 simulation

Saved operational revision 5 selects Actual / 2026.006, with metadata-resolved references 2026.005, 2026.007 and TIME_NA. DATASET_BYTES is 268435456 (256 MiB); the 64 MiB default stopped the first attempt without truncation or posting. All 21 cells completed after increasing this supported input budget. The live query returned 44,110 rows, matching the nonzero row count in the local DEMREVID (7).csv export (64,894 total, including 20,784 zero records). This is a count comparison, not a full value comparison. Complete replacement: 20,482 rows; final delta: 2,513 rows. See simulation-2026-006.json. No business data was posted, and this customer-data run has not yet been compared against the original calculation.

## Verification and limits

Every primary cell passed native SAP compilation. `verify-native.cjs` runs a separate nonposting comparison notebook against the original calculation using identical complete native fixtures. It compares every dimension and exact SAP SIGNEDDATA for replacement and delta. See `native-evidence.json` for completed scenario evidence, including suppression, fallback, rounding, negative amounts, carry-forward, HSNS and disappeared records. All nine scenarios passed with zero added, missing or changed records. The polling integrity incident and its repeated successful case are recorded separately; this is fixture equivalence, not customer acceptance.

`verify-execution.cjs` checks all/one/through execution on the operational notebook; `execution-evidence.json` records results when complete. Empty customer data proves execution only. Actual 2025.007 customer financial equivalence and production-scale performance remain acceptance tasks.

Complete working tables remain in SAP with explicit row/byte budgets. The browser receives bounded previews. Budget failures stop the calculation rather than truncate inputs; million-row workloads have not been validated.

No financial posting, Script Logic binding, allocation_result or transaction commit is included. The existing Data Manager calculation remains unchanged. Posting requires separate acceptance and its caller-owned CT_DATA change-set contract.

## Source maintenance

`build.cjs` expands reviewed stage bodies and repeated lookup/enrichment rules into visible cells. `rules.json` supplies explanations, `lineage.json` records dependencies, and `definition.draft.json` is the executable saved definition (historical filename retained for tooling compatibility). `build-validation.cjs` adds fixture preparation and independent original comparison around the same stages. Never interpret `check-source.cjs` substituted-body syntax checks as native API/runtime evidence.

Global ABAP helpers/platform changes must be committed, pushed and imported through abapGit with a transport. Notebook definitions are saved through the Notebook API. Do not upload global ABAP source directly through ADT.

The platform diagnostics used two temporary $TMP classes, ZCL_BN_JSON_CHECK and ZCL_BN_RUN_DOC_CHECK, created directly through ADT during investigation. This violated the requested deployment workflow; they are unreferenced diagnostics and did not change financial records or the allocation implementation. Further probes use Notebook cells/existing helpers. Delivered platform source was imported through abapGit.
