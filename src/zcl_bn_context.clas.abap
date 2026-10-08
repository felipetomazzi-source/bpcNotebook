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
    TYPES: BEGIN OF ty_live_output,
             cell_id TYPE string, rows TYPE tt_rows,
           END OF ty_live_output,
           tt_live_outputs TYPE STANDARD TABLE OF ty_live_output WITH DEFAULT KEY.
    TYPES ty_checkpoint TYPE zcl_bn_types=>ty_checkpoint.
    TYPES tt_checkpoints TYPE zcl_bn_types=>tt_checkpoints.
    DATA checkpoints TYPE tt_checkpoints READ-ONLY.
    METHODS checkpoint IMPORTING name TYPE string state TYPE string
      inputs TYPE zcl_bn_types=>tt_ids OPTIONAL outputs TYPE zcl_bn_types=>tt_ids OPTIONAL RAISING zcx_bn.
    METHODS check_budget RAISING zcx_bn.
    METHODS check_rows IMPORTING count TYPE i RAISING zcx_bn.
    DATA tables TYPE tt_tables READ-ONLY.
    METHODS emit_table IMPORTING name TYPE string rows TYPE ANY TABLE
      total_count TYPE i DEFAULT -1 elapsed_us TYPE i DEFAULT 0 RAISING zcx_bn.
    DATA environment TYPE uj_appset_id READ-ONLY.
    DATA model TYPE uj_appl_id READ-ONLY.
    DATA outputs TYPE tt_rows READ-ONLY.
    DATA messages TYPE zcl_bn_types=>tt_messages READ-ONLY.
    METHODS constructor IMPORTING inputs TYPE zcl_bn_types=>tt_inputs
      bindings TYPE zcl_bn_types=>tt_bindings dependencies TYPE zcl_bn_types=>tt_ids cell_id TYPE string
      environment TYPE string DEFAULT '' model TYPE string DEFAULT ''
      run_id TYPE string DEFAULT ''
      live_outputs TYPE tt_live_outputs OPTIONAL scope TYPE ujk_t_cv OPTIONAL
      logic_parameters TYPE ujk_t_script_logic_hashtable OPTIONAL logic_call TYPE abap_bool DEFAULT abap_false.
    METHODS bpc_dimension IMPORTING name TYPE string model_name TYPE string DEFAULT ''
      RETURNING VALUE(adapter) TYPE REF TO zcl_bn_bpc RAISING zcx_bn.
    METHODS bpc_model IMPORTING name TYPE string DEFAULT ''
      RETURNING VALUE(adapter) TYPE REF TO zcl_bn_bpc RAISING zcx_bn.
    METHODS reference_model IMPORTING name TYPE string DEFAULT ''
      RETURNING VALUE(adapter) TYPE REF TO zcl_bn_bpc RAISING zcx_bn.
    METHODS offset_period IMPORTING member TYPE uj_dim_member offset_by TYPE i dimension TYPE string DEFAULT 'TIME'
      RETURNING VALUE(result) TYPE uj_dim_member RAISING zcx_bn.
    METHODS property_provider IMPORTING implementation TYPE string version TYPE string
      RETURNING VALUE(provider) TYPE REF TO object RAISING zcx_bn.
    METHODS allocation_result IMPORTING name TYPE string rows TYPE ANY TABLE kind TYPE string
      RAISING zcx_bn.
    DATA result_name TYPE string READ-ONLY.
    DATA result_kind TYPE string READ-ONLY.
    DATA result_rows TYPE REF TO data READ-ONLY.
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
    DATA mv_run_id TYPE string.
    DATA mv_started TYPE timestampl.
    DATA mv_seconds TYPE i VALUE 600.
    DATA mv_step_started TYPE i.
    DATA mv_active_step TYPE string.
    DATA mt_inputs TYPE zcl_bn_types=>tt_inputs.
    DATA mt_bindings TYPE zcl_bn_types=>tt_bindings.
    DATA mt_dependencies TYPE zcl_bn_types=>tt_ids.
    METHODS check_logic_model IMPORTING name TYPE string RAISING zcx_bn.
    DATA mv_cell_id TYPE string.
    DATA mt_live_outputs TYPE tt_live_outputs.
    DATA mt_scope TYPE ujk_t_cv.
    DATA mt_logic_parameters TYPE ujk_t_script_logic_hashtable.
    DATA mv_logic_call TYPE abap_bool.
ENDCLASS.
CLASS zcl_bn_context IMPLEMENTATION.
  METHOD constructor.
    mv_run_id = run_id. GET TIME STAMP FIELD mv_started.
    READ TABLE inputs INTO DATA(budget) WITH KEY name = 'RUN_SECONDS'.
    IF sy-subrc = 0. mv_seconds = budget-value. ENDIF.
    me->environment = environment. me->model = model.
    mt_live_outputs = live_outputs. mt_scope = scope.
    mt_logic_parameters = logic_parameters. mv_logic_call = logic_call.
    mt_inputs = inputs. mt_bindings = bindings. mt_dependencies = dependencies. mv_cell_id = cell_id.
  ENDMETHOD.
  METHOD check_budget.
    DATA stamp TYPE timestampl. GET TIME STAMP FIELD stamp.
    IF mv_seconds < 1 OR mv_seconds > 7200 OR cl_abap_tstmp=>subtract( tstmp1 = stamp tstmp2 = mv_started ) > mv_seconds.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TIMEOUT' detail = 'Calculation resource deadline exceeded'.
    ENDIF.
    IF mv_run_id IS NOT INITIAL AND zcl_bn_store=>current( kind = 'R' id = mv_run_id ) > 0.
      DATA json TYPE string. json = zcl_bn_store=>read( kind = 'R' id = mv_run_id ).
      DATA run TYPE zcl_bn_types=>ty_run.
      /ui2/cl_json=>deserialize( EXPORTING json = json pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = run ).
      IF run-cancel_requested = abap_true.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CANCELLED' detail = 'Cancellation requested at a calculation boundary'.
      ENDIF.
    ENDIF.
  ENDMETHOD.
  METHOD check_rows.
    DATA maximum TYPE i VALUE 1000000.
    READ TABLE mt_inputs INTO DATA(limit) WITH KEY name = 'WORK_ROWS'.
    IF sy-subrc = 0.
      DATA(value) = CONV decfloat34( limit-value ).
      IF limit-type <> 'number' OR value < 1 OR value > 1000000 OR value <> trunc( value ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESOURCE_BUDGET' detail = 'WORK_ROWS must be an integer from 1 to 1000000'.
      ENDIF.
      maximum = CONV i( value ).
    ENDIF.
    IF count > maximum.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESOURCE_BUDGET' detail = 'Full working table exceeds WORK_ROWS; calculation was not truncated'.
    ENDIF.
    IF count MOD 1000 = 0. check_budget( ). ENDIF.
  ENDMETHOD.
  METHOD checkpoint.
    check_budget( ).
    IF state = 'running'.
      IF mv_active_step IS NOT INITIAL OR line_exists( checkpoints[ name = name ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CHECKPOINT' detail = 'Overlapping or duplicate step'.
      ENDIF.
      APPEND VALUE #( name = name state = state inputs = inputs outputs = outputs started_at = zcl_bn_types=>timestamp( ) ) TO checkpoints.
      mv_active_step = name. GET RUN TIME FIELD mv_step_started.
      RETURN.
    ENDIF.
    READ TABLE checkpoints ASSIGNING FIELD-SYMBOL(<step>) WITH KEY name = name.
    IF sy-subrc <> 0 OR mv_active_step <> name OR state <> 'succeeded'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CHECKPOINT' detail = 'Invalid step completion boundary'.
    ENDIF.
    GET RUN TIME FIELD DATA(finished). <step>-duration_us = finished - mv_step_started.
    LOOP AT tables INTO DATA(table) WHERE name CP name && '/*'.
      APPEND table-name TO <step>-outputs.
    ENDLOOP.
    <step>-state = state. <step>-finished_at = zcl_bn_types=>timestamp( ).
    CLEAR mv_active_step.
  ENDMETHOD.
  METHOD bpc_dimension.
    check_logic_model( model_name ).
    adapter = NEW zcl_bn_bpc( environment = CONV #( environment )
      model = COND #( WHEN model_name IS INITIAL THEN CONV string( model ) ELSE model_name )
      dimension = name inputs = mt_inputs scope = mt_scope ).
    IF name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_DIMENSION' detail = 'Choose a dimension name'.
    ENDIF.
  ENDMETHOD.
  METHOD bpc_model.
    check_logic_model( name ).
    adapter = NEW zcl_bn_bpc( environment = CONV #( environment )
      model = COND #( WHEN name IS INITIAL THEN CONV string( model ) ELSE name ) inputs = mt_inputs scope = mt_scope ).
  ENDMETHOD.
  METHOD check_logic_model.
    IF mv_logic_call = abap_true AND name IS NOT INITIAL AND name <> model.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_MODEL'
        detail = 'Script Logic notebook adapters must use the calling model'.
    ENDIF.
  ENDMETHOD.
  METHOD reference_model.
    check_logic_model( name ).
    DATA inputs TYPE zcl_bn_types=>tt_inputs. inputs = mt_inputs.
    DATA scope TYPE ujk_t_cv. scope = mt_scope.
    DATA dimensions TYPE zcl_bn_types=>tt_ids.
    LOOP AT inputs INTO DATA(reference) WHERE purpose = 'reference'.
      APPEND reference-dimension TO dimensions.
    ENDLOOP.
    IF dimensions IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'REFERENCE_SCOPE' detail = 'Declare an explicit reference selection first'.
    ENDIF.
    IF mv_logic_call = abap_true.
      READ TABLE mt_logic_parameters INTO DATA(policy) WITH KEY hashkey = 'READ_REFERENCES'.
      IF sy-subrc <> 0 OR policy-hashvalue <> 'DECLARED'.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'REFERENCE_POLICY'
          detail = 'Script Logic reference reads require explicit READ_REFERENCES = DECLARED' status = 403.
      ENDIF.
    ENDIF.
    LOOP AT dimensions INTO DATA(dim).
      DATA(output_ids) = VALUE zcl_bn_types=>tt_ids( ).
      LOOP AT mt_inputs INTO DATA(calculation) WHERE dimension = dim AND purpose <> 'reference'.
        APPEND LINES OF calculation-resolved TO output_ids.
      ENDLOOP.
      LOOP AT inputs ASSIGNING FIELD-SYMBOL(<reference>) WHERE dimension = dim AND purpose = 'reference'.
        APPEND LINES OF output_ids TO <reference>-resolved.
        SORT <reference>-resolved. DELETE ADJACENT DUPLICATES FROM <reference>-resolved.
      ENDLOOP.
      DELETE inputs WHERE dimension = dim AND purpose <> 'reference'.
      " Only explicitly declared reference dimensions may replace caller read scope.
      DELETE scope WHERE dimension = dim.
    ENDLOOP.
    LOOP AT inputs ASSIGNING FIELD-SYMBOL(<input>). CLEAR <input>-purpose. ENDLOOP.
    adapter = NEW zcl_bn_bpc( environment = CONV string( environment )
      model = COND #( WHEN name IS INITIAL THEN CONV string( model ) ELSE name ) inputs = inputs scope = scope ).
  ENDMETHOD.
  METHOD offset_period.
    result = member.
    IF abs( offset_by ) > 24.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FISCAL_OFFSET' detail = 'Offset exceeds frozen fiscal budget'.
    ENDIF.
    DO abs( offset_by ) TIMES.
      DATA found TYPE abap_bool. CLEAR found.
      LOOP AT mt_inputs INTO DATA(input).
        READ TABLE input-fiscal_links INTO DATA(link) WITH KEY dimension = dimension member = result.
        IF sy-subrc <> 0. CONTINUE. ENDIF.
        result = COND #( WHEN offset_by < 0 THEN link-prior ELSE link-next ). found = abap_true. EXIT.
      ENDLOOP.
      DATA authorized TYPE abap_bool. CLEAR authorized.
      LOOP AT mt_inputs INTO input WHERE dimension = dimension.
        IF line_exists( input-resolved[ table_line = CONV string( result ) ] ). authorized = abap_true. EXIT. ENDIF.
      ENDLOOP.
      IF found = abap_false OR result IS INITIAL OR authorized = abap_false.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FISCAL_OFFSET' detail = 'Offset not available in frozen authorized periods'.
      ENDIF.
    ENDDO.
  ENDMETHOD.
  METHOD property_provider.
    " Explicit extension point; no provider or implicit legacy constructor is enabled.
    RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PROPERTY_PROVIDER'
      detail = 'No reviewed server-side provider is installed; stored properties are separate'.
  ENDMETHOD.
  METHOD allocation_result.
    IF result_rows IS BOUND OR name IS INITIAL OR ( kind <> 'replacement' AND kind <> 'delta' ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_CONTRACT' detail = 'Publish one explicitly named replacement or delta result'.
    ENDIF.
    check_budget( ). check_rows( lines( rows ) ).
    zcl_bn_bpc=>describe_table( table = REF #( rows ) source = 'allocation' ).
    DATA(descr) = CAST cl_abap_tabledescr( cl_abap_tabledescr=>describe_by_data( rows ) ).
    CREATE DATA result_rows TYPE HANDLE descr.
    FIELD-SYMBOLS <copy> TYPE ANY TABLE. ASSIGN result_rows->* TO <copy>. <copy> = rows.
    result_name = name. result_kind = kind.
    " The result is server-side state. Named preview emission is a separate explicit operation.
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
    value = zcl_bn_bpc=>scoped_view( inputs = mt_inputs scope = mt_scope ).
  ENDMETHOD.
  METHOD script_parameters.
    value = mt_logic_parameters.
    LOOP AT zcl_bn_bpc=>script_parameters( mt_inputs ) INTO DATA(parameter).
      DELETE value WHERE hashkey = parameter-hashkey.
      INSERT parameter INTO TABLE value.
    ENDLOOP.
  ENDMETHOD.
  METHOD read.
    IF NOT line_exists( mt_dependencies[ table_line = dependency ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEPENDENCY' detail = 'Cell did not declare this dependency'.
    ENDIF.
    READ TABLE mt_live_outputs INTO DATA(live) WITH KEY cell_id = dependency.
    IF sy-subrc = 0. rows = live-rows. RETURN. ENDIF.
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
    IF name IS INITIAL OR lines( tables ) >= 200 OR line_exists( tables[ name = name ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TABLE_NAME' detail = 'Unique table name required; maximum 200 tables'.
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
    DATA preview_values TYPE i.
    LOOP AT tables INTO DATA(existing).
      preview_values = preview_values + existing-row_count * lines( existing-schema ).
    ENDLOOP.
    IF preview_values + table-row_count * lines( table-schema ) > 1000000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PREVIEW_BUDGET' detail = 'Aggregate preview exceeds one million values; reduce PREVIEW_ROWS'.
    ENDIF.
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


