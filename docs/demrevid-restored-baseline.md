# DEMREVID003: restored-original baseline conversion

The executable notebook definition is `examples/demrevid-allocation/definition.json`. It calls `ZCL_BN_DEM_ALLOC=>EXECUTE` once and runs all 20 allocation stages in native SAP working tables. The older `examples/demrevid-conversion` definition is a historical reads-only draft, not the executable allocation.

## Test it now

1. Open BPC Notebook in NPL, client 001. Select notebook **DEMREVID003 generic allocation - native verification**, ID `E82AEA36D1571FD1B0EE75B4F547719F`.
2. Its context is CH_PLANNING / DEMREVID; CATEGORY is Actual and TIME is 2025.007. Choose an authorized period or fiscal node containing representative source revenues and allocation mappings. Choose its real SAP hierarchy.
3. Keep REFERENCE_TIME declared separately, with TIME_NA and one lookback from TIME. Save so SAP resolves and freezes the selections and fiscal links.
4. Leave STOP_AFTER empty for the full calculation. Keep PREVIEW_ROWS at 100 initially. Run all and inspect each checkpoint, especially SAP_REVENUES, allocation mappings, RATIOS_AND_FLAGS, FINAL_REPLACEMENT and FINAL_DELTA.
5. Repeat with FFLASMATGROUPS on and off. For business acceptance compare complete native original and new result tables for identical category, output periods, reference scope and flags. Compare every dimension and exact native SIGNEDDATA, including deleted-record zero clears. Browser previews are unsuitable for this comparison.

The notebook run is inspection/preview: it does not post financial data. Posting must use a reviewed, revision/checksum-pinned allocation handler and the existing Script Logic/BAdI contract. See `demrevid-allocation.md` for EXECUTION=ALLOCATION, WRITE=ON, READ_REFERENCES=DECLARED and caller-owned CT_DATA/LUW requirements. No existing LGF or customer BAdI binding was replaced.

## Original-versus-new checks

The independent original baseline is commit 2796a7f's ZCL_BPC_DEMREVID_CALC_003. Its method bodies are copied into a test-only local class in the notebook allocation test include. Class identity/friend visibility and the original dimension-name include enable isolation; the customer class itself remains restored and unchanged. Tests call in-memory methods, not its BAdI entry point.

On NPL all 18 allocation ABAP Unit methods passed, including:

- 12 original-versus-port material FFLAS scenarios: positive/negative amounts, thirds/rounding, zero denominator, suppression on/off, duplicate base records, separate account/material keys, no allocated revenues, over-allocation, mixed suppressed groups and empty inputs.
- An original-helper versus notebook-helper replacement change-set comparison: changed 100 to 120 returns 120, unchanged rows disappear, old-only -50 returns a zero clear, and new -25 retains its sign. All dimensions are compared.

Provenance: `demrevid-comparison-baseline.json`. SAP results: `evidence/demrevid-original-comparison.json`.

## Integration result and remaining acceptance gaps

Actual / 2025.007 completed all 20 checkpoints on 9 October 2026 NZ time. The source and final tables were empty. Evidence: `evidence/demrevid-restored-baseline-run.json`. This proves the selected notebook compiles and runs through the integration path; it does not establish allocation equivalence.

The existing Actual / 2027.006 run had price facts but no SAP revenues. Full original-versus-new acceptance still requires nonempty representative revenues, all allocation lookup precedence/fallback routes, HSNS, connection carry-forward and reference/lookback cases; restricted-user authorization; and the intended Data Manager posting/rollback transaction. The isolated FFLAS/change-set tests cover only their stated paths.

Required production ABAP objects already supplied by the notebook port are ZCL_BN_DEM_ALLOC, ZCL_BN_DEM_MODEL, ZCL_BN_TRANSFORM and ZCL_BN_DIMENSION plus the notebook context/generic adapters and allocation BAdI. This change adds the independent comparison tests and executable definition; it does not re-refactor the restored customer class. Existing BPC_PARAM/current-view dependencies remain required. Deploy serialized ABAP by commit, push and abapGit pull, never direct source upload.
