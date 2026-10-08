# BPC dimension inputs

In SAP, **Open allocation demo** first asks for an authorized environment and model. The demo discovers that model’s category and time dimensions by BPC dimension type, then defines required `CATEGORY` and `TIME` parameters alongside `total`, `factor`, and an optional `suppressZero` boolean. Choose members with the value-help buttons, save, and run. Search matches member IDs and descriptions; selectors page through SAP metadata in batches of 100.

Other notebooks use **BPC model** to choose their context and **Inputs → Add dimension parameter** to define selections from that model’s dimensions. The Inputs editor also supports advanced JSON definitions. Existing number, string, and boolean definitions continue to work.

```json
{
  "environment": "<authorized environment ID>",
  "model": "<authorized model ID>",
  "inputs": [
    {"name": "CATEGORY", "type": "member", "dimension": "<category dimension ID>", "required": true, "selected": []},
    {"name": "TIME", "type": "range", "dimension": "<time dimension ID>", "hierarchy": "<metadata hierarchy ID>", "required": true, "selected": []},
    {"name": "suppressZero", "type": "boolean", "value": true}
  ]
}
```

`member` accepts one member ID. `range` accepts up to 100 selected nodes and/or individual members. It expands nodes to base members using `CL_UJA_DIM->GET_CHILDREN_MBR` in the chosen hierarchy, removes duplicate base members and orders IDs deterministically. There is no date parsing, year prefix matching or invented period list. A hierarchy is required when the dimension has hierarchies. Definitions may be saved with missing required selections, but cannot run until they are provided.

The backend owns `resolved`; it ignores and recomputes values supplied by a client during saves. It validates environment/model access, dimension membership, hierarchy existence, each selected ID, and every resolved base ID. The BPC context belongs to the SAP request/job user and must have security enabled. Member checks use BPC read authorization (`CHECK_MEMBER_ACCESS`, `I_RW = 'R'`); selection does not grant permission to write BPC data. Calculation APIs retain their own authorization requirements.

Submission resolves and validates again. If the base-member set differs from the saved revision, submission asks the author to save again instead of silently changing the run’s calculation context. Selected IDs, resolved IDs, environment, model, flags and primitive values are included in the checksummed immutable run snapshot. All cells receive that same snapshot. Background execution and retries recheck access without expanding the frozen selections again. Revoked access or removed metadata blocks execution. Retrying uses the original run’s selections, source and bindings, even after later notebook edits.

Selection and model changes mark previous cell outputs stale. Output fingerprints include the model context and complete typed inputs; the backend also detects staleness after saving and reopening.

## Cell API and calculation adapter

```abap
DATA total TYPE decfloat34.
total = io->input( 'total' ).
DATA category TYPE uj_dim_member.
category = io->member( 'CATEGORY' ).
DATA chosen TYPE zcl_bn_types=>tt_ids.
chosen = io->selection( 'TIME' ).  "Original selected nodes/member IDs
DATA periods TYPE uja_t_dim_member.
periods = io->range( 'TIME' ).     "Frozen base IDs, never re-expanded
DATA cv TYPE ujk_t_cv.
cv = io->current_view( ).
DATA parameters TYPE ujk_t_script_logic_hashtable.
parameters = io->script_parameters( ).
"io->environment and io->model provide the frozen BPC context.
```

`io->input()` keeps its scalar string-returning contract. Using it for a member/range raises `INPUT_TYPE`; `member()` requires exactly one selected member. `selection()` returns the original selection IDs; `range()` returns the resolved IDs for either selection type. The context exposes read-only environment and model properties.

`current_view()` produces `UJK_T_CV`, with actual dimension names, uppercase dimension keys and `USER_SPECIFIED = X`. It combines and deduplicates resolved IDs for inputs targeting the same dimension. Scalars do not become current-view dimensions. `script_parameters()` produces `UJK_T_SCRIPT_LOGIC_HASHTABLE`: `HASHKEY` is the notebook parameter name; `HASHVALUE` is the scalar value or comma-separated frozen resolved IDs. Parameter names and flag meanings remain notebook-defined. Cells pass these values to their existing BPC calculation APIs; the adapter does not execute Script Logic or write business data itself.

## Verification

The harmless ABAP Unit tests in `ZCL_BN_BPC` verify typed/scalar access, Unicode, range conversion, current-view deduplication and Script Logic flags. `docs/evidence/bpc-input-unit.json` records their SAP result. `docs/evidence/bpc-selections.json` records a real model run through the HTTP service, including fiscal-node expansion, required inputs, forged resolved IDs, snapshot consistency, stale outputs, invalid selections and historical retry.

Repeat the integration check on a development model with an authorized category and a node containing more than one base member:

```powershell
$env:BPC_ADT_TOOL_ROOT = '<installed mcp-abap-abap-adt-api directory>'
node tools/check-bpc-selections.cjs --environment=<ID> --model=<ID> --category=<ID> --node=<ID> --hierarchy=<ID>
```

This check creates a notebook and runs calculation-only example cells. It uses configured ADT credentials without printing them. The local Node simulation deliberately returns `SAP_REQUIRED` for member inputs and metadata: it cannot verify actual BPC authorization or supply production choices. Primitive notebooks remain available locally.

SAP serialization evidence remains in `docs/evidence/sap-roundtrip.json`; the comparison covers all native object metadata, ABAP sources/test includes, BSP bodies and UI5 mappings, including UTF-8/BOM/whitespace conventions.
