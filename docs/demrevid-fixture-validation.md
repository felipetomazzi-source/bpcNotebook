# DEMREVID003 complete native validation: prepared, not deployed

Branch: codex/SSNG-3218-fixture-validation in both Chorus and Notebook repositories.

The Chorus reader seam is pushed in commit 6d6e556, following captured live baseline b74e159. It adds ZIF_BPC_VALIDATION_READER and ZCX_BPC_VALIDATION, routes opt-in reads and fiscal offsets through that reader, and exposes ZCL_BPC_DEMREVID_CALC_003=>VALIDATE_WITH_READER. This entry point returns complete replacement/delta tables without SET_DATA. Ordinary BAdI execution retains its original behavior.

The Notebook comparison service is ZCL_BN_DEM_VALIDATION=>EXECUTE. A caller first installs a complete authorized native fixture catalog with io->enable_fixtures. The service creates independent private fixture contexts, runs the original through its reader and the port through ZCL_BN_DEM_ALLOC=>VALIDATE_FIXTURES, then compares all result dimensions and exact SIGNEDDATA for REPLACEMENT and DELTA. Diagnostic previews are prefixed ORIGINAL and NOTEBOOK. The adapter-backed reader deliberately shares generic fixture read/filter preparation; arithmetic, allocation and delta transformations remain in the two separate implementations.

No allocation_result, financial writeback, COMMIT or ROLLBACK is called by either validation entry point. Fixture mode rejects live fallback. Fiscal offsets come from frozen context metadata. Bounded displays never feed the calculation.

Context helpers fixture_copy and include_fixture_outputs preserve frozen inputs/scope and the original deadline, copy fixtures privately and enforce combined table/read/display budgets. They do not add full-table cross-cell handoff.

## Verified blocker

On NPL/client001, a read-only syntax check of the prepared ZCL_BPC_DIM_MATCONN source returned: line 86, type /BI0/OIMATERIAL is unknown. The runtime stored-property early return does not eliminate this static compile dependency; the source still contains BW material and product-hierarchy table references. Do not claim that this seam compiles or that skipping the virtual branch fixes the missing DDIC objects.

A safe next revision must avoid adding a static BW dependency to the validation path, while preserving the ordinary customer's virtual-property behavior. Do not fabricate BW master-data types or alter production enrichment to make the DEV test pass.

There is also unrelated live DEMREV_CALC_005 metadata flagged by abapGit despite its retrieved local/remote serialized files matching byte-for-byte. Do not perform a whole-repository pull until this is accounted for safely. The Chorus SAP repository remains on feature/SSNG-2735-bpc-demrev-project-conn-half-year; Notebook remains on main.

## Pending acceptance

These new sources are not compiled/deployed and no complete fixture comparison has run. A fixture builder, executable independent validation notebook, representative nonempty path coverage, suppression on/off, lookback/carry-forward, lookup precedence and exact disappeared-record clearing remain to be completed. The earlier 18 Unit methods and empty full-period runs are separate evidence and do not prove equivalence for this new service. No financial data or existing LGF binding was changed.
