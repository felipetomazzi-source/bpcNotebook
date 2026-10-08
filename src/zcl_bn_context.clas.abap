CLASS zcl_bn_context DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_row,
             key TYPE string, amount TYPE decfloat34,
           END OF ty_row,
           tt_rows TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_column,
             name TYPE string, type TYPE string,
           END OF ty_column,
           tt_schema TYPE STANDARD TABLE OF ty_column WITH DEFAULT KEY,
           BEGIN OF ty_table_row,
             values TYPE zcl_bn_types=>tt_ids,
           END OF ty_table_row,
           tt_table_rows TYPE STANDARD TABLE OF ty_table_row WITH DEFAULT KEY,
           BEGIN OF ty_table,
             name TYPE string, schema TYPE tt_schema, rows TYPE tt_table_rows,
             row_count TYPE i, total_count TYPE i, truncated TYPE abap_bool,
             elapsed_us TYPE i,
           END OF ty_table,
           tt_tables TYPE STANDARD TABLE OF ty_table WITH DEFAULT KEY.
    DATA tables TYPE tt_tables READ-ONLY.
    METHODS emit_table IMPORTING name TYPE string rows TYPE ANY TABLE
      total_count TYPE i DEFAULT -1 elapsed_us TYPE i DEFAULT 0 RAISING zcx_bn.
    DATA environment TYPE uj_appset_id READ-ONLY.
    DATA model TYPE uj_appl_id READ-ONLY.
    DATA outputs TYPE tt_rows READ-ONLY.
    DATA messages TYPE zcl_bn_types=>tt_messages READ-ONLY.
    METHODS constructor IMPORTING inputs TYPE zcl_bn_types=>tt_inputs
      bindings TYPE zcl_bn_types=>tt_bindings dependencies TYPE zcl_bn_types=>tt_ids cell_id TYPE string
      environment TYPE string DEFAULT '' model TYPE string DEFAULT ''.
    METHODS bpc_dimension IMPORTING name TYPE string model_name TYPE string DEFAULT ''
      RETURNING VALUE(adapter) TYPE REF TO zcl_bn_bpc RAISING zcx_bn.
    METHODS bpc_model IMPORTING name TYPE string DEFAULT ''
      RETURNING VALUE(adapter) TYPE REF TO zcl_bn_bpc RAISING zcx_bn.
    METHODS input IMPORTING name TYPE string RETURNING VALUE(value) TYPE string RAISING zcx_bn.
    METHODS member IMPORTING name TYPE string RETURNING VALUE(value) TYPE uj_dim_member RAISING zcx_bn.
    METHODS selection IMPORTING name TYPE string RETURNING VALUE(value) TYPE zcl_bn_types=>tt_ids RAISING zcx_bn.
    METHODS range IMPORTING name TYPE string RETURNING VALUE(value) TYPE uja_t_dim_member RAISING zcx_bn.
    METHODS current_view RETURNING VALUE(value) TYPE ujk_t_cv RAISING zcx_bn.
    METHODS script_parameters RETURNING VALUE(value) TYPE ujk_t_script_logic_hashtable RAISING zcx_bn.
    METHODS read IMPORTING dependency TYPE string RETURNING VALUE(rows) TYPE tt_rows RAISING zcx_bn.
    METHODS emit IMPORTING rows TYPE tt_rows RAISING zcx_bn.
    METHODS message IMPORTING text TYPE string.
  PRIVATE SECTION.
    DATA mt_inputs TYPE zcl_bn_types=>tt_inputs.
    DATA mt_bindings TYPE zcl_bn_types=>tt_bindings.
    DATA mt_dependencies TYPE zcl_bn_types=>tt_ids.
    DATA mv_cell_id TYPE string.
ENDCLASS.
CLASS zcl_bn_context IMPLEMENTATION.
  METHOD constructor.
    me->environment = environment. me->model = model.
    mt_inputs = inputs. mt_bindings = bindings. mt_dependencies = dependencies. mv_cell_id = cell_id.
  ENDMETHOD.
  METHOD bpc_dimension.
    adapter = NEW zcl_bn_bpc( environment = CONV #( environment )
      model = COND #( WHEN model_name IS INITIAL THEN CONV string( model ) ELSE model_name )
      dimension = name inputs = mt_inputs ).
    IF name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_DIMENSION' detail = 'Choose a dimension name'.
    ENDIF.
  ENDMETHOD.
  METHOD bpc_model.
    adapter = NEW zcl_bn_bpc( environment = CONV #( environment )
      model = COND #( WHEN name IS INITIAL THEN CONV string( model ) ELSE name ) inputs = mt_inputs ).
  ENDMETHOD.
  METHOD input.
    READ TABLE mt_inputs INTO DATA(parameter) WITH KEY name = name.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT' detail = |Unknown input { name }|.
    ENDIF.
    IF parameter-type = 'member' OR parameter-type = 'range'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Use member(), selection() or range() for BPC inputs'.
    ENDIF.
    value = parameter-value.
  ENDMETHOD.
  METHOD member.
    READ TABLE mt_inputs INTO DATA(parameter) WITH KEY name = name.
    IF sy-subrc <> 0 OR parameter-type <> 'member' OR lines( parameter-selected ) <> 1.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Expected a selected single member'.
    ENDIF.
    value = parameter-selected[ 1 ].
  ENDMETHOD.
  METHOD selection.
    READ TABLE mt_inputs INTO DATA(parameter) WITH KEY name = name.
    IF sy-subrc <> 0 OR ( parameter-type <> 'member' AND parameter-type <> 'range' ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Expected a BPC selection'.
    ENDIF.
    value = parameter-selected.
  ENDMETHOD.
  METHOD range.
    READ TABLE mt_inputs INTO DATA(parameter) WITH KEY name = name.
    IF sy-subrc <> 0 OR ( parameter-type <> 'member' AND parameter-type <> 'range' ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Expected a BPC selection'.
    ENDIF.
    LOOP AT parameter-resolved INTO DATA(id). APPEND CONV uj_dim_member( id ) TO value. ENDLOOP.
  ENDMETHOD.
  METHOD current_view.
    value = zcl_bn_bpc=>current_view( mt_inputs ).
  ENDMETHOD.
  METHOD script_parameters.
    value = zcl_bn_bpc=>script_parameters( mt_inputs ).
  ENDMETHOD.
  METHOD read.
    IF NOT line_exists( mt_dependencies[ table_line = dependency ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEPENDENCY' detail = 'Cell did not declare this dependency'.
    ENDIF.
    READ TABLE mt_bindings INTO DATA(binding) WITH KEY cell_id = dependency.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEPENDENCY' detail = 'Dependency output missing'.
    ENDIF.
    DATA json TYPE string.
    json = zcl_bn_store=>read( kind = 'D' id = |{ binding-run_id }:{ dependency }| revision = binding-revision ).
    TYPES: BEGIN OF ty_dataset,
             rows TYPE tt_rows,
           END OF ty_dataset.
    DATA dataset TYPE ty_dataset.
    /ui2/cl_json=>deserialize( EXPORTING json = json pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = dataset ).
    rows = dataset-rows.
  ENDMETHOD.
  METHOD emit.
    IF lines( rows ) > 10000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_LIMIT' detail = 'DEV prototype supports at most 10000 output rows'.
    ENDIF.
    outputs = rows.
  ENDMETHOD.
  METHOD emit_table.
    IF name IS INITIAL OR lines( tables ) >= 50 OR line_exists( tables[ name = name ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TABLE_NAME' detail = 'Unique table name required; maximum 50 tables'.
    ENDIF.
    DATA descriptor TYPE REF TO cl_abap_tabledescr.
    descriptor ?= cl_abap_typedescr=>describe_by_data( rows ).
    DATA structure TYPE REF TO cl_abap_structdescr.
    TRY.
        structure ?= descriptor->get_table_line_type( ).
      CATCH cx_sy_move_cast_error.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TABLE_TYPE' detail = 'Expected a table of flat structures'.
    ENDTRY.
    DATA(table) = VALUE ty_table( name = name row_count = nmin( val1 = lines( rows ) val2 = 5000 )
      total_count = COND #( WHEN total_count < 0 THEN lines( rows ) ELSE total_count ) elapsed_us = elapsed_us ).
    IF table-total_count < lines( rows ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TABLE_COUNT' detail = 'Total count cannot be smaller than supplied rows'.
    ENDIF.
    table-truncated = xsdbool( table-total_count > table-row_count ).
    DATA(components) = structure->get_components( ).
    LOOP AT components INTO DATA(component).
      IF component-type->kind <> cl_abap_typedescr=>kind_elem.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TABLE_TYPE' detail = 'Nested or reference columns are unsupported'.
      ENDIF.
      APPEND VALUE #( name = to_lower( component-name ) type = COND #(
        WHEN component-type->type_kind = cl_abap_typedescr=>typekind_packed OR
             component-type->type_kind = cl_abap_typedescr=>typekind_decfloat16 OR
             component-type->type_kind = cl_abap_typedescr=>typekind_decfloat34 OR
             component-type->type_kind = cl_abap_typedescr=>typekind_float OR
             component-type->type_kind = cl_abap_typedescr=>typekind_int
        THEN 'decimal' ELSE 'string' ) ) TO table-schema.
    ENDLOOP.
    FIELD-SYMBOLS <row> TYPE any.
    FIELD-SYMBOLS <value> TYPE any.
    DATA index TYPE i.
    LOOP AT rows ASSIGNING <row>.
      index = index + 1.
      IF index > 5000. EXIT. ENDIF.
      DATA(outrow) = VALUE ty_table_row( ).
      LOOP AT components INTO component.
        ASSIGN COMPONENT component-name OF STRUCTURE <row> TO <value>.
        APPEND |{ <value> }| TO outrow-values.
      ENDLOOP.
      APPEND outrow TO table-rows.
    ENDLOOP.
    APPEND table TO tables.
  ENDMETHOD.
  METHOD message.
    APPEND VALUE #( cell_id = mv_cell_id severity = 'Information' text = text ) TO messages.
  ENDMETHOD.
ENDCLASS.


