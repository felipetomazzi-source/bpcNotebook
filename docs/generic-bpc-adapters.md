# Generic BPC adapters and authoring helpers

Notebook cells can read SAP BPC dimensions and models without a Chorus class or a generated ABAP type per model. The adapters use the notebook run's selected environment, the current SAP user, live BPC metadata and dynamic flat tables. The existing number/string/boolean input methods, named output tables and input selection adapters remain supported.

## Dimension access

```abap
DATA(dimension) = io->bpc_dimension( 'MATCONN' ).
DATA(member_table) = dimension->member_data( ).
FIELD-SYMBOLS <members> TYPE STANDARD TABLE.
ASSIGN member_table->* TO <members>.

" Processing happens on SAP; emit_table stores only a bounded preview.
io->emit_table( name = 'MEMBERS' rows = <members> ).
DATA(properties) = dimension->properties( ).
io->emit_table( name = 'PROPERTY_FIELDS' rows = properties ).
DATA(hierarchies) = dimension->hierarchies( ).
```

`member_data( ids = VALUE #( ( CONV string( 'MEMBER_ID' ) ) ) )` reads specific IDs. Omitted IDs return authorized members. A requested missing/unauthorized ID fails instead of being silently removed. Member IDs and descriptions are the stored `ID` and `EVDESCRIPTION` fields. Other properties and hierarchy parent columns are discovered from the actual SAP table. `hierarchies()` returns actual hierarchy names; neither method expands a node into periods.

`property( member = 'MEMBER_ID' name = 'PROPERTY_NAME' )` returns a stored value as a string. `properties()` returns field name, ABAP type kind, length, decimals and source `stored`. Character/numeric-text lengths are characters; packed lengths are bytes. Property/field discovery preserves an empty table's schema.

The optional `model_name` argument selects another authorized model in the same environment. It does not change the notebook's execution context.

## Model access and frozen filters

```abap
DATA(model) = io->bpc_model( ). " Optional name = 'OTHER_MODEL'
DATA(fields) = model->fields( ).
DATA(periods) = io->range( 'TIME' ). " Already-resolved frozen base IDs
DATA(filters) = VALUE zcl_bn_bpc=>tt_filters(
  ( dimension = 'TIME'
    members = VALUE #( ( CONV string( periods[ 1 ] ) ) ) ) ).
DATA(model_table) = model->read_data( filters = filters ).
FIELD-SYMBOLS <data> TYPE STANDARD TABLE.
ASSIGN model_table->* TO <data>.
io->emit_table( name = 'MODEL_DATA' rows = <data> ).
```

The result has one 32-character member column per model dimension plus native `UJ_SDATA` `SIGNEDDATA`. `dimensions()` and `fields()` discover the actual model schema. Keep calculations in ABAP using the dynamic table; the browser receives persisted pages of the existing named-table preview.

All frozen member/range inputs whose dimension exists in the target model are applied by default. Additional filters intersect these constraints and cannot widen them. A disjoint intersection fails. Duplicate filters for one dimension also intersect; IDs within one filter are alternatives. Requested IDs are validated before intersection, including IDs that would otherwise be discarded. An explicitly empty member list fails. Model filters accept existing authorized base IDs only; nodes/calculated members fail with `BPC_BASE_FILTER`. TIME is never re-expanded inside adapter reads.

For another model, frozen IDs are applied to dimensions with the same name and revalidated there. Dimensions absent from that model do not constrain it. Authors must supply any additional model-specific selection contract explicitly; shared names do not imply business equivalence.

Reads validate environment/model membership and BPC member authorization, establish a security-enabled context, and call SAP's query adapter with `if_check_security = abap_true`. The adapter uses equality selections and disables query BAdI enrichment. Unknown dimensions, models, properties and members fail closed. This remains the trusted-author DEV notebook contract; it is not an ABAP sandbox.

`max_rows` defaults to 100,000 and can be explicitly set from 1 to 1,000,000. SAP reads packages of 1,000 and returns a complete result or raises `BPC_READ_LIMIT`; it does not quietly return a partial calculation input. A 10,000-package guard also limits sparse queries. Emitted named previews retain at most 5,000 rows per table, preserve the full source count, and are fetched in bounded pages.

## Authoring assistance

Use **BPC code** on a cell, or the notebook toolbar after focusing a cell. Choose an operation, search an authorized model/dimension/member, and discover stored properties or model fields. The helper previews ABAP and appends it to the active cell using unique variable/output names. Save and validate before execution. Selecting a helper model does not change the notebook's configured model.

Available operations are dimension members, property-field discovery, hierarchy names, a stored property value, model data with frozen selections, an extra base-member filter, and model-field access. Metadata lists use the existing search and 100-item paging. Names and IDs are escaped as ABAP literals; string-table IDs use explicit conversion. Node members cannot be inserted as model filters.

Execution review now opens the latest persisted run when a notebook is opened, resets named-table selection when changing notebooks/runs/cells, and ignores superseded preview responses. Standard UI5 responsive-table pop-ins display additional model columns on narrow screens. Empty tables keep their schema and report zero rows.

## Virtual properties and legacy calculations

Stored properties are not Chorus virtual/computed properties. A request with `source = 'virtual'` raises `BPC_VIRTUAL_PROPERTY`. `ZCL_BN_BPC` has a protected `virtual_property` hook and context fields for a future explicitly installed subclass/provider; the base implementation never enriches or substitutes values. No provider registry or Chorus enrichment is implemented in this version.

No BPC data-write API is provided. A future write adapter needs its own validation, authorization, snapshot and transaction contract.

An unchanged allocation class still depends on its existing typed classes. Refactor its dimension/model reads to use these adapters explicitly, and separately replace any required virtual-property logic. This does not repair `/BI0/OIMATERIAL` or make the full legacy DEMREVID calculation executable.

## Verification

Run `node tools/check-generic-bpc.cjs --notebook=<selected CATEGORY/TIME notebook ID> --dimension=<dimension ID>` with the configured ADT credentials and `BPC_ADT_TOOL_ROOT`. The tool creates read-only verification notebooks, compiles all seven helper operations, runs generic reads and validation guards in SAP background processing, checks frozen TIME IDs, and verifies bounded named-table pages. Evidence contains schemas and counts, not model financial values.

On NPL, generic MATCONN access returned 7,391 members with 13 stored columns, despite the missing BW type used by the legacy class. The tested DEMREVID period selection returned an empty model result with the expected 21-column schema. This verifies the query/schema path, not a nonempty transactional calculation or the legacy allocation. ABAP Unit covers frozen-filter intersection and the existing scalar/typed/named-output contracts. See `docs/evidence/generic-bpc.json`, UI screenshots, and the SAP round-trip evidence.
