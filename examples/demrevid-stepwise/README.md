# DEMREVID003 step-by-step conversion

Status: source draft, awaiting working-dataset/tab platform deployment and native verification. **This is not yet a saved, executable SAP notebook.** The existing one-cell allocation notebook is unchanged.

`definition.draft.json` contains one notebook with 20 numbered calculation cells and a final replacement/delta reconciliation cell. `rules.json` supplies an accountant-facing explanation and check for each tab. `cells/` contains the visible ABAP bodies. `lineage.json` records native table dependencies. `build.cjs` mechanically expands the reviewed port's stage bodies; it does not invoke the allocation engine.

The business rules are in the cells. Repeated enrichment and driver-precedence rules are expanded in place. Generic Notebook IO handles frozen selections, security, complete reads, native working artifacts and bounded previews. Existing `ZCL_BN_DEM_MODEL`, `ZCL_BN_DIMENSION`, `ZCL_BN_TRANSFORM`, BPC parameter/current-view classes and SAP types remain helper dependencies in this first iteration. This is not yet a no-code rule editor or a port to the limited Script v1 grammar.

Requested platform contract, being implemented by the **Build BPC Notebook** session:

```abap
io->publish_dataset( name = 'REVENUES' rows = complete_native_table ).
DATA(table_ref) = io->read_dataset( dependency = 'step_01' name = 'REVENUES' ).
```

The API must preserve native SAP amounts, every dimension, original row order, schema and provenance. A preview never serves as a calculation input. Dependencies use the latest producer of each changed table; unchanged tables retain their original producer. Stage dependencies also include the previous step to enforce the ordered chain. Rerunning a step must invalidate affected downstream results.

`cells[].explanation` and `notebook.explanation` provide plain-text guidance. Each cell must be reachable through the forthcoming tab navigation. Accountants select CATEGORY and output TIME, review separate reference periods and suppression flags, then run each tab and inspect the output. Advanced source remains inspectable/editable. Input selections and source edits require fresh dependent results.

Before publishing the finished notebook:

1. Integrate the documented working-table and tab API into the pushed feature branch, check live drift and deploy through abapGit.
2. Save and SAP-validate every cell; review expanded helpers and exact table lineage.
3. Run all cells on complete nonempty native fixtures; compare final replacement and delta against the unchanged original calculation across all dimensions and exact SIGNEDDATA.
4. Repeat suppression, fallback, rounding, negative amounts, carry-forward, HSNS and disappeared-old-record cases.
5. Exercise Run cell, Run through, Run all, source/input changes, stale dependencies, failed cells and resource limits.
6. Verify real selected customer data separately. Empty reads and successful compilation do not prove equivalence.

No `allocation_result`, financial write, Script Logic binding or transaction commit is included. Final artifacts preserve complete replacement and delta for inspection/comparison only. Posting requires separate acceptance and the explicit caller-owned change-set contract.
