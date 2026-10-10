# DEMREVID003 Notebook: use and validation

Two notebooks are saved in NPL, SAP client 001, under DEVELOPER, in CH_PLANNING / DEMREVID. They appear in the application notebook list after refresh.

- **DEMREVID003 - allocation** (`E82AEA36D1571FD1B0EFCAF3D7BB92AE`): the complete 20-stage calculation using actual authorized BPC model reads. One ABAP cell calls ZCL_BN_DEM_ALLOC; full multidimensional working tables stay in SAP.
- **DEMREVID003 - original versus Notebook validation** (`E82AEA36D1571FD1B0EFCB12C2BD12AE`): both complete calculations use independent private copies of the same authorized native fixtures. It compares every dimension and exact native SIGNEDDATA for replacement and delta outputs.

## Run the allocation

1. Refresh BPC Notebook and choose CH_PLANNING / DEMREVID. Open **DEMREVID003 - allocation**.
2. Choose CATEGORY and TIME using SAP member value help. Default: Actual / 2025.007. Use the actual hierarchy for a selected fiscal node; the backend expands it through SAP metadata.
3. Review REFERENCE_TIME. It declares TIME_NA and a metadata-derived one-period lookback. The supplied one-period example also explicitly declares 2025.008 for the original connection algorithm's forward shift. If output periods change, select the appropriate next period(s) from real NEXT_PERIOD metadata; do not infer IDs from date strings. Reference-only periods are not permission to post outside the selected output scope.
4. Set FFLASMATGROUPS on/off and review FFLASMATGROUPSID. Keep STOP_AFTER empty to execute all 20 stages. Save and Run all.
5. Inspect FINAL_REPLACEMENT, FINAL_DELTA and stage tables. DEMREVID047 contains material ratios; DEMREVID052 contains skipped-material flags when suppression applies. READ_n/SUMMARY and FILTERS_AND_PERIODS show the effective read scope and complete counts.

Display tables are bounded previews. The calculation and comparator use complete native tables, never preview pages. READ_LIMIT/WORK_ROWS guard complete reads and working tables; limit failures must not be treated as valid partial results.

The newly saved allocation notebook completed all 20 stages with Actual / 2025.007. Its secured live data was empty; this run verifies execution only. It does not establish that no data exists outside DEVELOPER's authorized view, nor prove business equivalence.

## Run independent validation

Open **DEMREVID003 - original versus Notebook validation**. Select one authorized output period and its required reference periods, then choose FIXTURE_CASE: standard, fallback, rounding, negative, carry or hsns. Set FFLASMATGROUPS, save and Run all. The default source uses the connected DEV model's authorized Actual / 2027.006 price data only as a member-ID/schema seed; it replaces the amounts with synthetic inputs. If that seed is unavailable, execution fails explicitly.

The original calculation uses VALIDATE_WITH_READER and its original transformation helpers. The notebook uses VALIDATE_FIXTURES and its separate ported helpers. Both route read/filter preparation through the same generic fixture adapter and retain independent complete working tables. No arbitrary legacy query remains available through the injected reader; an uninstalled fixture fails instead of querying live financial data.

Outputs include REPLACEMENT/SUMMARY and DELTA/SUMMARY, bounded DIFFERENCES tables, NOTEBOOK/FINAL_REPLACEMENT, NOTEBOOK/FINAL_DELTA, COVERAGE, and ORIGINAL/NOTEBOOK read diagnostics. Added, missing and changed counts must all be zero. A zero-row run is insufficient. Compare native exact amounts; do not apply JavaScript rounding or a numerical tolerance.

The final delta is the original replacement change-set: a changed 100-to-120 record returns 120; unchanged records are omitted; disappeared old records return their original complete key with zero. It is not an arithmetic difference table.

Reproduce the maintained DEV checks:

```powershell
$env:BPC_ADT_TOOL_ROOT = 'C:\Users\FelipeTomazzi\mcps\mcp-abap-abap-adt-api'
node tools/check-demrevid-complete.cjs --notebook=E82AEA36D1571FD1B0EFCB12C2BD12AE
```

## Verification result

Ten nonempty full-calculation runs matched exactly, with zero added/missing/changed records in both replacement and delta: suppression on/off, fallback ratios, native rounding, negative revenues, connection carry-forward with suppression on/off, HSNS with suppression on/off, and a repeat of the standard case. Result sizes ranged from 19 to 42 replacement records and 20 to 43 delta records. Every run verified the disappeared old ratio's zero clear. All traced calculation reads used fixture data with MEMBER_AUTH_ON; NO_QUERY. Eighteen allocation ABAP Unit methods also passed.

The carry test initially failed because an exclusion filter enumerated hierarchy nodes. ZCL_BN_TRANSFORM now removes calculated members and known parents when converting such ranges to explicit base filters. The generic reader's authorization/base-member checks remain intact. No financial amount difference was suppressed or rounded away.

## Scope and remaining acceptance

This is preview/validation, with no financial posting or replacement of the existing LGF/BAdI binding. Publication of a native delta inside the allocation context is separate from business posting. The Data Manager transaction remains the caller's responsibility.

Representative fixture evidence is in docs/evidence/demrevid-complete-fixtures.json; the live empty-period execution is recorded separately in demrevid-created-allocation-run.json. Exact matches prove only the documented fixture paths. Customer-data acceptance, all lookup/property-overwrite combinations, restricted-user authorization, large-volume performance, and the intended Data Manager posting/rollback still require verification.

The original connection algorithm can carry records into a later period; matching its complete in-memory result does not authorize widening the caller's write scope. Review that behavior before binding an allocation handler. Historical fixture retry is unsupported; Run all creates a fresh validated run.

The temporary Chorus NPL branch disables BW-derived MATCONN _PROD_TYPE_ID enrichment and BW master-data refresh. Stored PRODUCT_TYPE remains available, and DEMREVID003 does not consume _PROD_TYPE_ID. This branch is not a production replacement for BW enrichment.

ABAP changes were committed, pushed and deployed through abapGit. The Notebook branch is codex/SSNG-3218-fixture-validation; the Chorus DEV bypass/reader hook is on codex/SSNG-3218-npl-skip-bw-enrichment. DEMREV005 was preserved and is outside this conversion.
