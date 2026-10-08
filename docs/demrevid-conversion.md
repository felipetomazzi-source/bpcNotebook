# DEMREVID003 conversion draft

The saved notebook **DEMREVID 003 - generic conversion draft (reads only)** is a partial conversion, not the replacement allocation. Its six cells saved, compiled and ran on NPL client 001 on 9 October 2026. Notebook ID: `E82AEA36D1571FD1B0E2BD7EF9940724`, revision 1. Run ID: `E82AEA36D1571FD1B0E2BDA46FBA4727`.

The source class read through ADT matched the Chorus repository after line-ending normalization. The generic adapters avoid all Chorus dimension/model classes in the executable draft. No ABAP repository object or normal allocation package was changed. No handler was bound and no model facts were written.

## Saved cells

| ID | Language | Dependencies | Behavior |
|---|---|---|---|
| context | Notebook Script | none | Reads the frozen selection and suppression inputs; emits period count. |
| matconn | Notebook Script | context | Reads authorized stored MATCONN members through the generic adapter. |
| product_type | Notebook Script | context | Reads authorized stored PRODUCT_TYPE members. |
| mat_group_id | Notebook Script | context | Reads authorized stored MAT_GROUP_ID members. |
| selected_facts | Notebook Script | context | Reads full DEMREVID facts within frozen periods/category, emits a bounded preview and scalar raw counts/total. |
| conversion_status | ABAP | selected_facts, matconn, product_type, mat_group_id | Lists all 20 retained allocation steps and passes through the scalar read counts. It performs no allocation. |

Inputs use the existing verified environment CH_PLANNING, model DEMREVID, category Actual, fiscal node 2025.REG, hierarchy PARENTH2. TIME resolution is performed by the notebook backend. FFLASMATGROUPS defaults true, FFLASMATGROUPSID is MATGROUPID038, DEBUG is OFF and HSNS_REALLOC_LOCATIONS is empty. These latter two parameters are preserved for the future ABAP port; the draft does not execute their business behavior.

Authored `.bns` files, the ABAP status cell, generated save payload and step inventory are under `examples/demrevid-conversion/`. `retained-abap/` preserves the original class and helper sources, with SHA-256 identities in the inventory. These source snapshots are references, not standalone executable notebook cells.

## Why full conversion cannot be declared yet

The supplied conversion guide explicitly says to retain unsupported operations in ABAP or report the required extension, and requires representative nonempty comparisons before equivalence. Notebook Script v1 has no grouped aggregation, keyed lookup, sorting, hierarchy traversal, table copying/deletion, general method calls or writeback. Its scalar dependency API cannot carry the full multidimensional working tables between allocation cells. The complete algorithm therefore needs an ABAP implementation using the new generic adapters, or explicit extensions to the runtime.

| Original stage | Behavior that must survive the ABAP port |
|---|---|
| INITIALISE | Read selected periods **plus TIME_NA**; select AUDITTRAIL/DEMREVID_KFS descendants in PARENTH1; aggregate revenues excluding costcentre, doc type and audittrail; preserve fill-gaps and mapping-table sort rules. |
| ENRICH_REVENUES | Apply product-type override/index, revenue-ID group, region/layer mapping, material remapping and account/material fallback precedence, material-group override and regulated-service mapping. |
| CONSOLIDATE | Sum grouped revenues with the original dimension inclusion/exclusion rules. |
| LOCATION_ALLOC_METHOD / LOCATION_ALLOC_RATIOS | Preserve material → account → CAL account → connection-region priority, matching keys and ratio methods. |
| ALLOC_RSP_BILLED_DATA / REMAINING_RSP_BILLING / RSP_NOT_BILLED_LOCATION | Preserve allocations, residual values and location fallback. |
| FFLAS_GROUPING / PQ_ID_FFLAS_REVENUE / PQ_FFLAS_RATIO | Preserve grouping, allocations, geo/PQ/ID distinctions and ratio denominators. |
| SUPPLIER_ALLOC_METHOD / SUPPLIER_ALLOC_RATIOS / ALLOC_ID_REV_SUPPLIER | Preserve supplier lookup priority, grouping and allocation keys. |
| PRICE_MATERIAL_LEVEL | Preserve material-level price derivation and matching. |
| HSNS_REV_ALLOC | Preserve premium revenue reassignment, excluded locations, grouped ratios and accrual allocation. |
| FFLAS_RATIOS_BY_MATERIAL | Preserve material-group exclusions, unique Time/Account/Matconn DEMREVID052 flags, DEMREVID047 ratios, FFLASNON remainder, UJ_SIGNEDDATA precision and correction of the first sorted ratio row. |
| TRANSPOSE_REVENUES / TRANSPOSE_PRICES / TRANSPOSE_CONNECTIONS | Preserve reporting transpositions, product hierarchy, fiscal offsets, prior-period connections/closing balances/additional connections and carry-forward of materials without revenue. |
| BAdI execute after all steps | Compare new output with prior output and return the delta through CT_DATA. Current NOTEBOOK preview handler explicitly leaves CT_DATA unchanged. |

### Frozen read scope needs a distinct reference-data contract

The original INITIALISE combines selected TIME with TIME_NA. Generic reads intersect every matching TIME input, so adding a TIME_NA filter cannot widen the frozen selection. Connection transposition also reads periods derived using the original fiscal offset helper. We must not bypass adapter scope by constructing an unrestricted adapter, infer periods from IDs, or add reference periods to the calculation's output-period selection.

A complete port needs separately frozen, authorized output periods and reference/lookback periods. The runtime must define how a reference read uses the latter while preserving caller limits in Script Logic. No such API exists in the referenced implementation. This draft intentionally reads only selected periods and labels its raw counts accordingly.

### Stored and derived properties require careful separation

MATCONN's original constructor performs BW enrichment into `_PROD_TYPE_ID`, causing the missing `/BI0/OIMATERIAL` failure. DEMREVID003's enrichment method actually consumes MATCONN's **PRODUCT_TYPE** field. The port must verify its stored semantics; it must not substitute `_PROD_TYPE_ID`. The generic dimension path successfully bypasses the constructor for stored-property reads.

PRODUCT_TYPE's constructor derives uppercase description and a split alternative-text list. These helpers are not automatically supplied by the generic adapter. The original sources are preserved for review. A virtual provider is needed only for computed values actually required by the converted algorithm, not merely because a legacy constructor computes unrelated values.

## Verification and next implementation

All six SAP validations passed, authored script reopened byte-for-byte, Run all succeeded, and frozen TIME IDs matched the saved selection. The selected transactional slice returned **zero facts** with its 21-column schema. Dimension previews contain real authorized members. `docs/evidence/demrevid-conversion.json` stores schemas/counts and validation results, not financial fact values. All 26 local tests passed.

This does not test nonempty allocation, suppression, rounding, virtual-property equivalence, or CT_DATA delta processing. Next: implement the explicit reference-read scope, port the allocation into one ABAP cell/service using generic adapters (keeping the full working tables server-side), and compare to the original using nonempty data. Split it into independent calculation cells only once a full-table state/dependency contract exists. Bind a NOTEBOOK handler only after the business comparisons and writeback decision are complete.

Recreate the read-stage draft with existing configured credentials:

```powershell
$env:BPC_ADT_TOOL_ROOT = '<installed ADT MCP directory>'
node tools/convert-demrevid.cjs --notebook=<selected DEMREVID notebook ID>
```

The tool creates a new notebook, compiles authored scripts using the actual Script.compile implementation, validates every cell, runs it and records evidence. It never invokes the legacy allocation, binds a handler or writes model facts.
