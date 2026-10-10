# DEMREVID003 allocation through BPC Notebook

The saved executable allocation and full native comparison notebooks are described in [demrevid-notebook-usage.md](demrevid-notebook-usage.md), with separate nonempty fixture and live-period evidence. Customer-data acceptance remains pending.

The executable port is `ZCL_BN_DEM_ALLOC=>EXECUTE`. It runs all 20 stages in **one ABAP cell**, with complete native multidimensional working tables in SAP memory. It uses generic authorized BPC reads and stored-property access. Independent execution of an internal stage and full-table transfer between notebook cells are not implemented. This is the permitted initial one-service design.

Business acceptance is **pending**. The connected DEV model has 3,550 authorized Actual / 2027.006 records, principally SAP prices, and no SAP revenues. All stages execute, but the final replacement and change-set are empty. This verifies execution, metadata and inspection; it does not prove end-to-end allocation equivalence.

## Notebook definition

Use environment `CH_PLANNING`, model `DEMREVID`, one ABAP cell:

```abap
zcl_bn_dem_alloc=>execute(
  io = io
  stop_after = io->input( 'STOP_AFTER' ) ).
```

Declare these inputs. Number, string and boolean inputs remain supported.

| Name | Type | Purpose |
|---|---|---|
| CATEGORY | member, CATEGORY dimension | Authorized output category |
| TIME | range, TIME dimension, real hierarchy | Selected output periods or node; SAP resolves authorized base IDs |
| REFERENCE_TIME | range, TIME dimension | `purpose: "reference"`, selected `TIME_NA`, `lookbackFrom: "TIME"`, `lookbackSteps: 1` |
| READ_LIMIT | number | Complete fact-read limit, 1–1,000,000; overflow fails |
| WORK_ROWS | optional number | Maximum rows in a working table, 1–1,000,000; default 1,000,000 |
| PREVIEW_ROWS | number | Rows copied per checkpoint, 1–5,000; use 100 initially |
| RUN_SECONDS | number | Cooperative execution budget, 1–7,200; default 600 |
| FFLASMATGROUPS | boolean or string | Single boolean maps to 1/0; legacy comma-separated flags remain unchanged |
| FFLASMATGROUPSID | string | Original suppression material-group list |
| DEBUG | boolean or string | Boolean maps to ON/OFF; legacy string remains unchanged |
| HSNS_REALLOC_LOCATIONS | string | Original HSNS parameter |
| STOP_AFTER | string | Empty for full execution; otherwise an ID from `GET_STEPS()` |

Reference declaration example:

```json
{
  "name": "REFERENCE_TIME",
  "type": "range",
  "dimension": "TIME",
  "hierarchy": "PARENTH1",
  "required": true,
  "selected": ["TIME_NA"],
  "purpose": "reference",
  "lookbackFrom": "TIME",
  "lookbackSteps": 1
}
```

Use actual metadata-selected IDs rather than copying example IDs to another model. `tools/check-demrevid-allocation.cjs` creates a dedicated DEV notebook with this definition and executes it.

## Calculation scope and reference scope

`io->bpc_model()` retains the frozen calculation selection and caller current view. `io->reference_model()` uses the union of output IDs and **explicitly declared reference IDs** for each declared reference dimension. Other dimensions retain their existing restrictions. This is read permission only: `io->current_view()` and final-result validation exclude reference-only periods from output.

The backend resolves lookbacks using TIME's stored `PRIOR_PERIOD` and `NEXT_PERIOD` properties. It validates base-member authorization, freezes resolved IDs and fiscal links, and fails when metadata or a required authorized member is unavailable. `io->offset_period()` follows those frozen links and rejects a target outside the frozen authorized periods. It never parses member names or assumes twelve calendar months.

For this system, `2025.007` has description January 2025 and explicit prior `2025.006`; the fiscal year node resolves across two numeric year prefixes. This is why member-name arithmetic is unsuitable. Caller FISCPER conversion uses stored FISCYEAR and BASE_PERIOD, rather than slicing TIME.

Historical reference-read retries return `DATA_SNAPSHOT` (409). Use **Run all** to create a new source/data run; each invocation reads required facts again. Source revision, selected/resolved IDs, fiscal links and parameters are frozen, but raw external fact inputs are not archived for replay. A checkpoint preview is not a data snapshot. Reinvoke Script Logic to establish a new run under its current view and caller transaction.

## Full working tables and inspection boundaries

`ZCL_BN_DEM_MODEL` retains the original 20 `UJ_DIM_MEMBER` dimensions and `UJ_SIGNEDDATA` amount. `ZCL_BN_TRANSFORM` retains the original grouping, lookup, division, assignment-rounding, replacement, sorting and missing-field behavior. Its transactional reads are routed through the authorized generic adapter; direct legacy read/write paths are disabled. No bounded preview is used as calculation input.

Each stage records input/output checkpoint names, full table counts, bounded typed previews, start/end timing and success status. The material FFLAS stage additionally exposes:

1. `RATIO_BASE_BEFORE_EXCLUSIONS`
2. `SKIPPED_MATERIAL_FLAGS`
3. `RATIO_BASE_AFTER_EXCLUSIONS`
4. `FFLAS_REVENUE_NUMERATORS`
5. `RATIOS_BEFORE_ROUNDING`
6. `RATIOS_AND_FLAGS`

FFLAS correction preserves the original sorted binary lookup and adds the discrepancy to the selected existing ratio row. It does not introduce a normalization algorithm or a synthetic remainder row when none existed.

`STOP_AFTER` always runs from INITIALISE through that boundary with a fresh engine. It returns no BPC result. There is no “run only this internal stage” operation, no external state injection, and no mid-stage resume. Completed checkpoints document progress; they do not make an interrupted stage resumable.

Failed/cancelled background runs retain available previews as a separate `P` document. `/output` labels them `partial`; they never enter completed results or dependency bindings. The run records its failure/cancellation and diagnostics. A synchronous BAdI failure publishes neither a result nor committed notebook records.

## Explicit BPC result contract

`io->allocation_result( name, rows, kind )` publishes exactly one separate, full, typed result copy. `io->emit_table()` only creates a preview. Preview execution ignores allocation results and leaves CT_DATA unchanged.

The allocation emits `FINAL_REPLACEMENT` for inspection, performs the original `COMPARE_DELTA`, then explicitly publishes `FINAL_DELTA` with `kind = 'delta'`. Here **delta means the legacy replacement change-set**, not an additive numerical difference:

| Previous record | New record | CT_DATA change-set |
|---|---|---|
| 100 | 120 | 120 |
| 100 | 100 | omitted |
| -50 | absent | 0, with the old multidimensional key |
| absent | -25 | -25 |

Do not subtract old amounts again. The implementation preserves the original matching across all dimensions and zero-clearing of old-only records. `kind = 'replacement'` is a distinct construction contract; the allocation handler currently requires `delta` and will not silently reinterpret replacement data.

Allocation execution requires both a handler explicitly bound with `executionMode: "allocation"` and an invocation requesting ALLOCATION. The handler pins notebook revision and checksum. Preview remains the default.

```text
*START_BADI NOTEBOOK
QUERY = OFF
WRITE = ON
EXECUTION = ALLOCATION
READ_REFERENCES = DECLARED
HANDLER = YOUR_REVIEWED_ALLOCATION_BINDING
*END_BADI
```

For preview use `EXECUTION = PREVIEW` and `WRITE = OFF`. `READ_REFERENCES = DECLARED` is still required if the cell uses reference reads. It explicitly permits the reviewed reference dimensions to replace their caller **read** filters with the frozen declared read scope. It never widens output scope, skips member authorization, or overrides other caller dimensions. Without this parameter reference reads fail. Reference selections/hierarchies cannot be changed with INPUT_/HIERARCHY_ overrides; review and rebind the definition instead.

Before returning CT_DATA, the service validates target context, exact model schema, native SIGNEDDATA type, base members, calculation/caller scope and member write authorization. It converts the whole result into a private caller-shaped table and assigns CT_DATA only after successful validation/conversion. A failure leaves incoming CT_DATA intact.

The synchronous path contains no COMMIT, ROLLBACK, background submission or direct business writeback. Run metadata is staged only after successful calculation; the caller owns its LUW and SAP's subsequent business posting. Trusted ABAP cells must honor this same transaction contract. Production execution remains blocked by the existing DEV controls. No existing production LGF or business handler was replaced.

## Stored and derived properties

The port uses MATCONN's stored PRODUCT_TYPE and MAT_GROUP_ID's stored REV_ID_GROUP. It does not invoke the failing Chorus MATCONN constructor, compute `_PROD_TYPE_ID`, or require BW material enrichment. PRODUCT_TYPE's legacy uppercase-description/alternative-text helpers are not used by the allocation's consumed transformations.

The generic adapter keeps stored-property access separate from its explicit virtual-property hook. No derived provider is installed for this port. `io->property_provider( implementation, version )` fails explicitly until a reviewed provider is implemented; it never silently falls back to stored values. Future providers must be explicitly selected/versioned in the reviewed run definition. This extension point is not a claim that arbitrary providers already work.

## Limits and dependencies

Reads are packaged on SAP and overflow raises an error; they never return partial calculation inputs. Working-table growth and stage boundaries check configured budgets. Previews are bounded to 200 named tables and one million aggregate values per cell. Cancellation/deadline checks are cooperative, including stage/read boundaries; arbitrary ABAP is not preemptible. Very large workloads may still require additional packaging or SAP job/memory configuration.

The port still uses the installed BPC interfaces/selection DDIC types, `ZCL_BPC_PARAM`, and `ZCL_BPC_CURRENT_VIEW` for the original parameter/CV semantics. It does not instantiate calculation-specific Chorus dimension/environment classes or use their transactional reader. Those installed prerequisites are required when transporting to another SAP system.

## Verification and remaining acceptance

Recorded evidence is in `docs/evidence/allocation-*.json`:

- Native ABAP Unit: nonempty FFLAS/PQ business cases, suppression disabled, skipped flags, exact existing-row correction, empty/zero behavior, disappeared-record change-set, reference contract and native result-copy isolation.
- Actual GET BADI/CALL BADI: nonempty typed CT_DATA, preview isolation, explicit reference-policy rejection, unchanged caller data on calculation failure, and caller rollback removing staged notebook records. This fixture does not invoke financial writeback.
- Full 20-stage DEV execution and bounded checkpoint inspection.
- Failed checkpoint inspection: retained partial previews, zero completed dependency results and historical reference-retry rejection.
- Actual SAP abapGit import/serialization comparison for all 56 files, including BSP metadata/mappings and encoding conventions.

Still required for business acceptance: original-versus-port comparison on representative revenues/mappings/lookbacks with suppression on/off, lookup/fallback/member coverage, grouped amounts/signs/precision, connection carry-forward, final replacement and exact CT_DATA change-set; a restricted-user authorization fixture; and caller posting/rollback verification in the intended BPC transaction. No zero-row result or isolated test substitutes for these comparisons.
