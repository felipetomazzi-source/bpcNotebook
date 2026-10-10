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
    TYPES: BEGIN OF ty_comparison,
      name TYPE string, original_rows TYPE i, notebook_rows TYPE i,
      unchanged TYPE i, added TYPE i, missing TYPE i, changed TYPE i,
    END OF ty_comparison.
    TYPES: BEGIN OF ty_fixture,
      environment TYPE string, model TYPE string, rows TYPE REF TO data,
    END OF ty_fixture, tt_fixtures TYPE STANDARD TABLE OF ty_fixture WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_read,
      id TYPE string, environment TYPE string, model TYPE string, scope TYPE string,
      source TYPE string, security TYPE string, state TYPE string,
      row_count TYPE i, packages TYPE i, max_rows TYPE i, error_code TYPE string,
      effective_filters TYPE zcl_bn_bpc=>tt_filters,
      output_periods TYPE zcl_bn_types=>tt_ids, reference_periods TYPE zcl_bn_types=>tt_ids,
    END OF ty_read, tt_reads TYPE STANDARD TABLE OF ty_read WITH DEFAULT KEY.
    DATA reads TYPE tt_reads READ-ONLY.
    DATA fixture_mode TYPE abap_bool READ-ONLY.
    METHODS compare_results IMPORTING name TYPE string original TYPE ANY TABLE notebook TYPE ANY TABLE
      preview_rows TYPE i DEFAULT 100 RETURNING VALUE(summary) TYPE ty_comparison RAISING zcx_bn.
    METHODS enable_fixtures IMPORTING fixtures TYPE tt_fixtures RAISING zcx_bn.
    METHODS fixture_copy IMPORTING cell_id TYPE string
      RETURNING VALUE(result) TYPE REF TO zcl_bn_context RAISING zcx_bn.
    METHODS include_fixture_outputs IMPORTING context TYPE REF TO zcl_bn_context prefix TYPE string RAISING zcx_bn.
    METHODS fixture_read IMPORTING environment TYPE string model TYPE string filters TYPE zcl_bn_bpc=>tt_filters
      max_rows TYPE i RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
    METHODS record_read IMPORTING diagnostic TYPE ty_read RAISING zcx_bn.
    METHODS checkpoint IMPORTING name TYPE string state TYPE string
      inputs TYPE zcl_bn_types=>tt_ids OPTIONAL outputs TYPE zcl_bn_types=>tt_ids OPTIONAL RAISING zcx_bn.
    METHODS check_budget RAISING zcx_bn.
    METHODS check_data_snapshot RAISING zcx_bn.
    METHODS check_rows IMPORTING count TYPE i RAISING zcx_bn.
    METHODS check_working_bytes IMPORTING count TYPE int8 RAISING zcx_bn.
    DATA artifacts TYPE zcl_bn_dataset=>tt_headers READ-ONLY.
    DATA dataset_reads TYPE zcl_bn_dataset=>tt_access READ-ONLY.
    METHODS publish_dataset IMPORTING name TYPE string rows TYPE ANY TABLE RAISING zcx_bn.
    METHODS read_dataset IMPORTING dependency TYPE string name TYPE string
      RETURNING VALUE(rows) TYPE REF TO data RAISING zcx_bn.
    METHODS dataset_packets RETURNING VALUE(packets) TYPE zcl_bn_dataset=>tt_packets.
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
      run_id TYPE string DEFAULT '' notebook_id TYPE string DEFAULT ''
      live_datasets TYPE zcl_bn_dataset=>tt_live OPTIONAL
      fixture_required TYPE abap_bool DEFAULT abap_false
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
    DATA mt_packets TYPE zcl_bn_dataset=>tt_packets.
    DATA mt_live_datasets TYPE zcl_bn_dataset=>tt_live.
    DATA mv_notebook_id TYPE string.
    DATA mv_fixture_required TYPE abap_bool.
    DATA mv_dataset_rows TYPE i.
    DATA mv_dataset_bytes TYPE i.
    METHODS reserve_dataset IMPORTING row_count TYPE i byte_count TYPE i RAISING zcx_bn.
    METHODS dataset_budget RETURNING VALUE(maximum) TYPE i RAISING zcx_bn.
    DATA mt_fixtures TYPE tt_fixtures.
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
    mv_run_id = run_id. mv_notebook_id = notebook_id. mt_live_datasets = live_datasets.
    mv_fixture_required = fixture_required.
    GET TIME STAMP FIELD mv_started.
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
      /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( json ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = run ).
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
      dimension = name inputs = mt_inputs scope = mt_scope diagnostics = me ).
    IF name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_DIMENSION' detail = 'Choose a dimension name'.
    ENDIF.
  ENDMETHOD.
  METHOD bpc_model.
    check_logic_model( name ).
    adapter = NEW zcl_bn_bpc( environment = CONV #( environment )
      model = COND #( WHEN name IS INITIAL THEN CONV string( model ) ELSE name ) inputs = mt_inputs scope = mt_scope diagnostics = me ).
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
      model = COND #( WHEN name IS INITIAL THEN CONV string( model ) ELSE name ) inputs = inputs scope = scope
      diagnostics = me read_scope = 'reference' ).
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
    IF fixture_mode = abap_true.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_POSTING' detail = 'Fixture executions cannot publish BPC allocation results'.
    ENDIF.
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
    /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( json ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = dataset ).
    rows = dataset-rows.
  ENDMETHOD.
  METHOD check_data_snapshot.
    IF mv_fixture_required = abap_true AND fixture_mode <> abap_true.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE' detail = 'Enable the retained fixtures before any model read in this validation stage'.
    ENDIF.
    LOOP AT mt_bindings INTO DATA(binding) WHERE run_id <> mv_run_id.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATA_SNAPSHOT'
        detail = 'A cell reusing prior-run datasets cannot read fresh model facts; run through the read stages instead'.
    ENDLOOP.
  ENDMETHOD.
  METHOD dataset_budget.
    maximum = 67108864.
    READ TABLE mt_inputs INTO DATA(limit) WITH KEY name = 'DATASET_BYTES'.
    IF sy-subrc = 0.
      DATA(value) = CONV decfloat34( limit-value ).
      IF limit-type <> 'number' OR value < 1 OR value > 268435456 OR value <> trunc( value ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESOURCE_BUDGET' detail = 'DATASET_BYTES must be an integer from 1 to 268435456'.
      ENDIF.
      maximum = CONV i( value ).
    ENDIF.
  ENDMETHOD.
  METHOD check_working_bytes.
    check_budget( ).
    IF count < 0 OR count > dataset_budget( ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_BUDGET' detail = 'Script working table exceeds DATASET_BYTES; calculation was not truncated'.
    ENDIF.
  ENDMETHOD.
  METHOD reserve_dataset.
    check_budget( ).
    DATA(maximum) = dataset_budget( ).
    check_rows( mv_dataset_rows + row_count ).
    IF byte_count < 0 OR row_count < 0 OR mv_dataset_bytes + byte_count > maximum.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_BUDGET' detail = 'Full working datasets exceed DATASET_BYTES; nothing was truncated'.
    ENDIF.
    mv_dataset_rows = mv_dataset_rows + row_count. mv_dataset_bytes = mv_dataset_bytes + byte_count.
  ENDMETHOD.
  METHOD dataset_packets.
    packets = mt_packets.
  ENDMETHOD.
  METHOD publish_dataset.
    IF line_exists( artifacts[ name = name ] ) OR lines( artifacts ) >= 100.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_NAME' detail = 'Publish each dataset once per cell; maximum 100 datasets'.
    ENDIF.
    check_budget( ). check_rows( mv_dataset_rows + lines( rows ) ).
    DATA(packet) = zcl_bn_dataset=>freeze( name = name rows = rows max_bytes = dataset_budget( ) - mv_dataset_bytes ).
    reserve_dataset( row_count = packet-row_count byte_count = nmax( val1 = packet-byte_count val2 = packet-memory_bytes ) ).
    IF environment IS NOT INITIAL.
      zcl_bn_bpc=>validate_working( environment = CONV #( environment ) model = CONV #( model ) rows = rows ).
    ENDIF.
    " The binary packet, not the caller's mutable reference, is the publication.
    DATA preview_max TYPE i VALUE 200.
    READ TABLE mt_inputs INTO DATA(preview) WITH KEY name = 'PREVIEW_ROWS'.
    IF sy-subrc = 0. preview_max = preview-value. ENDIF.
    IF preview_max < 1 OR preview_max > 5000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESOURCE_BUDGET' detail = 'PREVIEW_ROWS must be from 1 to 5000'.
    ENDIF.
    DATA(preview_type) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( rows ) ).
    DATA(preview_standard) = cl_abap_tabledescr=>create( p_line_type = preview_type->get_table_line_type( ) ).
    DATA preview_rows TYPE REF TO data.
    CREATE DATA preview_rows TYPE HANDLE preview_standard.
    FIELD-SYMBOLS <preview> TYPE STANDARD TABLE.
    ASSIGN preview_rows->* TO <preview>.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      IF lines( <preview> ) >= preview_max. EXIT. ENDIF.
      APPEND <row> TO <preview>.
    ENDLOOP.
    emit_table( name = |DATASET/{ name }| rows = <preview> total_count = packet-row_count ).
    APPEND packet TO mt_packets. APPEND CORRESPONDING #( packet ) TO artifacts.
  ENDMETHOD.
  METHOD read_dataset.
    check_budget( ).
    IF NOT line_exists( mt_dependencies[ table_line = dependency ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEPENDENCY' detail = 'Declare the producing cell as a dependency'.
    ENDIF.
    READ TABLE mt_bindings INTO DATA(binding) WITH KEY cell_id = dependency.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEPENDENCY' detail = 'Producing cell has no completed bound dataset'.
    ENDIF.
    DATA packet TYPE zcl_bn_dataset=>ty_packet.
    READ TABLE mt_live_datasets INTO DATA(live) WITH KEY cell_id = dependency.
    IF sy-subrc = 0.
      READ TABLE live-packets INTO packet WITH KEY name = name.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_MISSING' detail = 'Producer did not publish the named dataset'.
      ENDIF.
    ELSE.
      TYPES: BEGIN OF ty_bound,
               notebook_id TYPE string, run_id TYPE string, cell_id TYPE string, revision TYPE i,
               fingerprint TYPE string, fixture_mode TYPE abap_bool, retention_until TYPE timestampl,
               artifacts TYPE zcl_bn_dataset=>tt_headers,
             END OF ty_bound.
      DATA bound TYPE ty_bound.
      IF mv_notebook_id IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_BINDING' detail = 'Persisted dataset access requires a notebook execution context'.
      ENDIF.
      DATA(json) = zcl_bn_store=>read( kind = 'D' id = |{ binding-run_id }:{ dependency }| revision = binding-revision ).
      /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( json ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = bound ).
      IF bound-notebook_id <> mv_notebook_id OR bound-run_id <> binding-run_id OR bound-cell_id <> dependency OR
         bound-revision <> binding-revision.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_BINDING' detail = 'Producer does not match the frozen notebook dependency'.
      ENDIF.
      IF bound-fixture_mode = abap_true AND ( mv_fixture_required <> abap_true OR binding-run_id <> mv_run_id ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE' detail = 'Fixture artifacts can be consumed only inside their original validation run'.
      ENDIF.
      DATA stamp TYPE timestampl. GET TIME STAMP FIELD stamp.
      IF bound-retention_until < stamp.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_EXPIRED' detail = 'Working dataset retention expired; execute its producer again'.
      ENDIF.
      READ TABLE bound-artifacts INTO DATA(header) WITH KEY name = name.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_MISSING' detail = 'Named dataset is not a published producer output'.
      ENDIF.
      DATA(key) = zcl_bn_dataset=>storage_id( run_id = binding-run_id cell_id = dependency name = name ).
      DATA(saved_json) = zcl_bn_store=>read( kind = 'W' id = key revision = 1 ).
      DATA saved TYPE zcl_bn_dataset=>ty_saved.
      /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( saved_json ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = saved ).
      IF saved-notebook_id <> mv_notebook_id OR saved-run_id <> binding-run_id OR saved-cell_id <> dependency OR
         saved-revision <> binding-revision OR saved-fingerprint <> bound-fingerprint OR
         CORRESPONDING zcl_bn_dataset=>ty_header( saved-packet ) <> header.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_INTEGRITY' detail = 'Native artifact does not match the frozen producer'.
      ENDIF.
      DATA(producer_json) = zcl_bn_store=>read( kind = 'R' id = binding-run_id ).
      DATA producer TYPE zcl_bn_types=>ty_run.
      /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( producer_json ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = producer ).
      READ TABLE producer-snapshot-cells INTO DATA(producing_cell) WITH KEY id = dependency.
      IF sy-subrc <> 0 OR producer-notebook_id <> mv_notebook_id OR NOT line_exists( producer-results[ cell_id = dependency ] ) OR
         producing_cell-source_version <> saved-source_version OR producing_cell-checksum <> saved-source_checksum.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SOURCE_INTEGRITY' detail = 'Artifact is not a completed frozen producer result'.
      ENDIF.
      SELECT SINGLE source, checksum FROM zbn_src INTO (@DATA(source), @DATA(source_checksum))
        WHERE notebook_id = @mv_notebook_id AND cell_id = @dependency AND version = @saved-source_version.
      IF sy-subrc <> 0 OR source_checksum <> saved-source_checksum OR zcl_bn_types=>hash( source ) <> source_checksum.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SOURCE_INTEGRITY' detail = 'Published native artifact source binding is missing'.
      ENDIF.
      packet = saved-packet.
    ENDIF.
    reserve_dataset( row_count = packet-row_count byte_count = nmax( val1 = packet-byte_count val2 = packet-memory_bytes ) ).
    rows = zcl_bn_dataset=>thaw( packet ).
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN rows->* TO <rows>.
    IF environment IS NOT INITIAL.
      zcl_bn_bpc=>validate_working( environment = CONV #( environment ) model = CONV #( model ) rows = <rows> ).
    ENDIF.
    APPEND VALUE #( dependency = dependency name = name run_id = binding-run_id revision = binding-revision
      row_count = packet-row_count byte_count = packet-byte_count checksum = packet-checksum ) TO dataset_reads.
    check_budget( ).
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
  METHOD compare_results.
    IF name IS INITIAL OR preview_rows < 1 OR preview_rows > 5000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'COMPARISON' detail = 'Named comparison and preview_rows from 1 to 5000 required'.
    ENDIF.
    check_budget( ). check_rows( lines( original ) ). check_rows( lines( notebook ) ).
    DATA left_type TYPE REF TO cl_abap_structdescr.
    DATA right_type TYPE REF TO cl_abap_structdescr.
    TRY.
        left_type ?= CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( original ) )->get_table_line_type( ).
        right_type ?= CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( notebook ) )->get_table_line_type( ).
      CATCH cx_root.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'COMPARISON_SCHEMA' detail = 'Comparison needs flat structured tables'.
    ENDTRY.
    DATA components TYPE cl_abap_structdescr=>component_table.
    components = left_type->get_components( ).
    DATA right_components TYPE cl_abap_structdescr=>component_table.
    right_components = right_type->get_components( ).
    IF lines( components ) <> lines( right_components ) OR lines( components ) < 2.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'COMPARISON_SCHEMA' detail = 'Both result schemas must match exactly'.
    ENDIF.
    DATA diff_components TYPE cl_abap_structdescr=>component_table.
    DATA amount_type TYPE REF TO cl_abap_elemdescr.
    LOOP AT components INTO DATA(component).
      READ TABLE right_components INTO DATA(other) WITH KEY name = component-name.
      IF sy-subrc <> 0 OR component-type->kind <> cl_abap_typedescr=>kind_elem.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'COMPARISON_SCHEMA' detail = 'Flat identical result fields required'.
      ENDIF.
      IF component-type->type_kind <> other-type->type_kind OR component-type->length <> other-type->length
         OR component-type->decimals <> other-type->decimals.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'COMPARISON_SCHEMA' detail = 'Native result field types must match exactly'.
      ENDIF.
      IF component-name = 'SIGNEDDATA'.
        amount_type ?= component-type.
        IF amount_type->type_kind <> cl_abap_typedescr=>typekind_packed AND
           amount_type->type_kind <> cl_abap_typedescr=>typekind_decfloat16 AND
           amount_type->type_kind <> cl_abap_typedescr=>typekind_decfloat34.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'COMPARISON_SCHEMA' detail = 'SIGNEDDATA must be an exact native decimal type'.
        ENDIF.
      ELSE.
        IF component-name = 'DIFFERENCE_KIND' OR component-name = 'ORIGINAL_SIGNEDDATA' OR component-name = 'NOTEBOOK_SIGNEDDATA'.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'COMPARISON_SCHEMA' detail = 'Reserved difference fields in input schema'.
        ENDIF.
        APPEND component TO diff_components.
      ENDIF.
    ENDLOOP.
    IF amount_type IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'COMPARISON_SCHEMA' detail = 'SIGNEDDATA required'.
    ENDIF.
    APPEND VALUE #( name = 'DIFFERENCE_KIND' type = cl_abap_elemdescr=>get_string( ) ) TO diff_components.
    APPEND VALUE #( name = 'ORIGINAL_SIGNEDDATA' type = amount_type ) TO diff_components.
    APPEND VALUE #( name = 'NOTEBOOK_SIGNEDDATA' type = amount_type ) TO diff_components.
    DATA diff_ref TYPE REF TO data.
    DATA diff_row TYPE REF TO data.
    DATA diff_type TYPE REF TO cl_abap_structdescr.
    diff_type = cl_abap_structdescr=>create( diff_components ).
    DATA diff_table_type TYPE REF TO cl_abap_tabledescr.
    diff_table_type = cl_abap_tabledescr=>create( diff_type ).
    CREATE DATA diff_ref TYPE HANDLE diff_table_type.
    CREATE DATA diff_row TYPE HANDLE diff_type.
    FIELD-SYMBOLS <differences> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <difference> TYPE any.
    FIELD-SYMBOLS <field> TYPE any.
    FIELD-SYMBOLS <left> TYPE any.
    FIELD-SYMBOLS <right> TYPE any.
    FIELD-SYMBOLS <left_amount> TYPE any.
    FIELD-SYMBOLS <right_amount> TYPE any.
    ASSIGN diff_ref->* TO <differences>. ASSIGN diff_row->* TO <difference>.
    TYPES: BEGIN OF ty_index, key TYPE string, row TYPE REF TO data, END OF ty_index.
    TYPES tt_index TYPE SORTED TABLE OF ty_index WITH UNIQUE KEY key.
    DATA left_index TYPE tt_index. DATA right_index TYPE tt_index.
    DATA index TYPE ty_index.
    DATA values TYPE zcl_bn_types=>tt_ids.
    DO 2 TIMES.
      FIELD-SYMBOLS <source> TYPE ANY TABLE.
      FIELD-SYMBOLS <index> TYPE tt_index.
      IF sy-index = 1. ASSIGN original TO <source>. ASSIGN left_index TO <index>.
      ELSE. ASSIGN notebook TO <source>. ASSIGN right_index TO <index>. ENDIF.
      LOOP AT <source> ASSIGNING <left>.
        CLEAR: values, index.
        LOOP AT components INTO component WHERE name <> 'SIGNEDDATA'.
          ASSIGN COMPONENT component-name OF STRUCTURE <left> TO <field>.
          APPEND CONV string( <field> ) TO values.
        ENDLOOP.
        index-key = zcl_bn_types=>json( values ). GET REFERENCE OF <left> INTO index-row.
        INSERT index INTO TABLE <index>.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'COMPARISON_DUPLICATE_KEY'
            detail = 'Duplicate complete dimensional key; apply the original grouping rule before comparing'.
        ENDIF.
        check_rows( lines( <index> ) ).
        IF lines( <index> ) MOD 1000 = 0. check_budget( ). ENDIF.
      ENDLOOP.
    ENDDO.
    summary-name = name. summary-original_rows = lines( original ). summary-notebook_rows = lines( notebook ).
    DATA combined TYPE STANDARD TABLE OF ty_index WITH DEFAULT KEY.
    combined = CORRESPONDING #( left_index ).
    LOOP AT right_index INTO index.
      IF NOT line_exists( left_index[ key = index-key ] ). APPEND index TO combined. ENDIF.
    ENDLOOP.
    check_rows( lines( combined ) ).
    SORT combined BY key.
    DATA compared TYPE i.
    LOOP AT combined INTO index.
      compared = compared + 1.
      IF compared MOD 1000 = 0. check_budget( ). ENDIF.
      CLEAR <difference>.
      UNASSIGN: <left>, <right>, <left_amount>, <right_amount>.
      READ TABLE left_index INTO DATA(left_entry) WITH TABLE KEY key = index-key.
      IF sy-subrc = 0.
        ASSIGN left_entry-row->* TO <left>.
        ASSIGN COMPONENT 'SIGNEDDATA' OF STRUCTURE <left> TO <left_amount>.
      ENDIF.
      READ TABLE right_index INTO DATA(right_entry) WITH TABLE KEY key = index-key.
      IF sy-subrc = 0.
        ASSIGN right_entry-row->* TO <right>.
        ASSIGN COMPONENT 'SIGNEDDATA' OF STRUCTURE <right> TO <right_amount>.
      ENDIF.
      DATA kind TYPE string.
      IF <left> IS NOT ASSIGNED. kind = 'added'. summary-added = summary-added + 1.
      ELSEIF <right> IS NOT ASSIGNED. kind = 'missing'. summary-missing = summary-missing + 1.
      ELSEIF <left_amount> <> <right_amount>. kind = 'changed'. summary-changed = summary-changed + 1.
      ELSE. summary-unchanged = summary-unchanged + 1. CONTINUE. ENDIF.
      IF lines( <differences> ) < preview_rows.
        IF <right> IS ASSIGNED. MOVE-CORRESPONDING <right> TO <difference>.
        ELSE. MOVE-CORRESPONDING <left> TO <difference>. ENDIF.
        ASSIGN COMPONENT 'DIFFERENCE_KIND' OF STRUCTURE <difference> TO <field>. <field> = kind.
        IF <left_amount> IS ASSIGNED.
          ASSIGN COMPONENT 'ORIGINAL_SIGNEDDATA' OF STRUCTURE <difference> TO <field>. <field> = <left_amount>.
        ENDIF.
        IF <right_amount> IS ASSIGNED.
          ASSIGN COMPONENT 'NOTEBOOK_SIGNEDDATA' OF STRUCTURE <difference> TO <field>. <field> = <right_amount>.
        ENDIF.
        APPEND <difference> TO <differences>.
      ENDIF.
    ENDLOOP.
    DATA summaries TYPE STANDARD TABLE OF ty_comparison WITH DEFAULT KEY.
    APPEND summary TO summaries.
    emit_table( name = name && '/SUMMARY' rows = summaries ).
    emit_table( name = name && '/DIFFERENCES' rows = <differences>
      total_count = summary-added + summary-missing + summary-changed ).
  ENDMETHOD.
  METHOD enable_fixtures.
    zcl_bn_service=>authorize( '16' ).
    IF mv_logic_call = abap_true OR fixture_mode = abap_true OR reads IS NOT INITIAL OR result_rows IS BOUND
       OR fixtures IS INITIAL OR lines( fixtures ) > 10.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE'
        detail = 'Fixtures require a fresh DEV preview context, 1 to 10 model tables, and cannot be enabled in Script Logic'.
    ENDIF.
    check_budget( ).
    DATA copies TYPE tt_fixtures.
    LOOP AT fixtures INTO DATA(fixture).
      IF fixture-rows IS NOT BOUND OR fixture-environment <> environment OR fixture-model IS INITIAL
         OR line_exists( copies[ environment = fixture-environment model = fixture-model ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE' detail = 'Unique model tables in this environment required'.
      ENDIF.
      FIELD-SYMBOLS <source> TYPE ANY TABLE.
      ASSIGN fixture-rows->* TO <source>.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_SCHEMA' detail = 'Fixture data reference must point to a table'.
      ENDIF.
      check_rows( lines( <source> ) ).
      zcl_bn_bpc=>validate_fixture( environment = fixture-environment model = fixture-model rows = <source> ).
      DATA(descriptor) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( <source> ) ).
      DATA(copy) = VALUE ty_fixture( environment = fixture-environment model = fixture-model ).
      CREATE DATA copy-rows TYPE HANDLE descriptor.
      FIELD-SYMBOLS <target> TYPE ANY TABLE. ASSIGN copy-rows->* TO <target>. <target> = <source>.
      APPEND copy TO copies.
      check_budget( ).
    ENDLOOP.
    mt_fixtures = copies. fixture_mode = abap_true.
    message( 'FIXTURE MODE: in-memory inputs only; no live model reads or allocation result publication' ).
  ENDMETHOD.
  METHOD fixture_copy.
    IF fixture_mode <> abap_true OR mv_logic_call = abap_true OR cell_id IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE' detail = 'Copy requires an enabled fixture context and cell name'.
    ENDIF.
    result = NEW zcl_bn_context( inputs = mt_inputs bindings = VALUE #( ) dependencies = VALUE #( )
      cell_id = cell_id environment = CONV #( environment ) model = CONV #( model ) run_id = mv_run_id
      scope = mt_scope logic_parameters = mt_logic_parameters ).
    result->mv_started = mv_started.
    result->enable_fixtures( mt_fixtures ).
  ENDMETHOD.
  METHOD include_fixture_outputs.
    IF fixture_mode <> abap_true OR context IS NOT BOUND OR prefix IS INITIAL OR
       context->fixture_mode <> abap_true OR context->environment <> environment OR context->model <> model.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE' detail = 'Matching fixture contexts and a diagnostic prefix required'.
    ENDIF.
    IF zcl_bn_types=>json( context->mt_inputs ) <> zcl_bn_types=>json( mt_inputs ) OR
       lines( tables ) + lines( context->tables ) > 200 OR lines( reads ) + lines( context->reads ) > 50.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESOURCE_BUDGET' detail = 'Fixture output snapshot mismatch or diagnostic budget exceeded'.
    ENDIF.
    DATA preview_values TYPE i.
    LOOP AT tables INTO DATA(existing_table).
      preview_values = preview_values + existing_table-row_count * lines( existing_table-schema ).
    ENDLOOP.
    LOOP AT context->tables INTO DATA(table).
      preview_values = preview_values + table-row_count * lines( table-schema ).
      IF preview_values > 1000000.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESOURCE_BUDGET' detail = 'Combined fixture previews exceed the display budget'.
      ENDIF.
      table-name = prefix && '/' && table-name.
      IF line_exists( tables[ name = table-name ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TABLE_NAME' detail = 'Fixture diagnostic names must be unique'.
      ENDIF.
    ENDLOOP.
    LOOP AT context->tables INTO table.
      table-name = prefix && '/' && table-name. APPEND table TO tables.
    ENDLOOP.
    LOOP AT context->reads INTO DATA(read).
      read-id = prefix && '/' && read-id. APPEND read TO reads.
    ENDLOOP.
    LOOP AT context->messages INTO DATA(message).
      message-cell_id = mv_cell_id. message-text = prefix && ': ' && message-text. APPEND message TO messages.
    ENDLOOP.
    LOOP AT context->checkpoints INTO DATA(step).
      step-name = prefix && '/' && step-name. APPEND step TO checkpoints.
    ENDLOOP.
    check_budget( ).
  ENDMETHOD.
  METHOD fixture_read.
    IF fixture_mode <> abap_true.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE' detail = 'Fixture mode is not enabled'.
    ENDIF.
    READ TABLE mt_fixtures INTO DATA(fixture) WITH KEY environment = environment model = model.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MISSING' detail = 'Required model fixture is missing; live fallback is prohibited'.
    ENDIF.
    FIELD-SYMBOLS <source> TYPE ANY TABLE.
    ASSIGN fixture-rows->* TO <source>.
    DATA(descriptor) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( <source> ) ).
    DATA result_type TYPE REF TO cl_abap_tabledescr.
    result_type = cl_abap_tabledescr=>create( descriptor->get_table_line_type( ) ).
    CREATE DATA result TYPE HANDLE result_type.
    FIELD-SYMBOLS <result> TYPE STANDARD TABLE. ASSIGN result->* TO <result>.
    DATA visited TYPE i.
    LOOP AT <source> ASSIGNING FIELD-SYMBOL(<row>).
      visited = visited + 1.
      DATA keep TYPE abap_bool VALUE abap_true. keep = abap_true.
      LOOP AT filters INTO DATA(filter).
        FIELD-SYMBOLS <value> TYPE any.
        ASSIGN COMPONENT filter-dimension OF STRUCTURE <row> TO <value>.
        IF sy-subrc <> 0 OR NOT line_exists( filter-members[ table_line = CONV string( <value> ) ] ).
          keep = abap_false. EXIT.
        ENDIF.
      ENDLOOP.
      IF keep = abap_true.
        IF lines( <result> ) >= max_rows.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_READ_LIMIT' detail = 'Complete fixture read exceeds max_rows'.
        ENDIF.
        APPEND <row> TO <result>.
      ENDIF.
      IF visited MOD 1000 = 0. check_budget( ). ENDIF.
    ENDLOOP.
    check_rows( lines( <result> ) ). check_budget( ).
  ENDMETHOD.
  METHOD record_read.
    IF lines( reads ) >= 50.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'READ_DIAGNOSTICS_LIMIT' detail = 'Maximum 50 diagnostic reads per cell; reduce reads or split processing steps'.
    ENDIF.
    DATA(record) = diagnostic. record-id = |READ_{ lines( reads ) + 1 }|.
    LOOP AT mt_inputs INTO DATA(input) WHERE dimension = 'TIME'.
      IF input-purpose = 'reference'. APPEND LINES OF input-resolved TO record-reference_periods.
      ELSE. APPEND LINES OF input-resolved TO record-output_periods. ENDIF.
    ENDLOOP.
    SORT record-output_periods. DELETE ADJACENT DUPLICATES FROM record-output_periods.
    SORT record-reference_periods. DELETE ADJACENT DUPLICATES FROM record-reference_periods.
    APPEND record TO reads.
    TYPES: BEGIN OF ty_summary,
      environment TYPE string, model TYPE string, scope TYPE string, source TYPE string,
      security TYPE string, state TYPE string, row_count TYPE i, packages TYPE i, max_rows TYPE i, error_code TYPE string,
    END OF ty_summary.
    DATA summaries TYPE STANDARD TABLE OF ty_summary WITH DEFAULT KEY.
    APPEND CORRESPONDING #( record ) TO summaries.
    emit_table( name = record-id && '/SUMMARY' rows = summaries ).
    TYPES: BEGIN OF ty_selection, purpose TYPE string, dimension TYPE string, member TYPE string, END OF ty_selection.
    DATA selections TYPE STANDARD TABLE OF ty_selection WITH DEFAULT KEY.
    LOOP AT record-effective_filters INTO DATA(filter).
      LOOP AT filter-members INTO DATA(member).
        APPEND VALUE #( purpose = 'effective filter' dimension = filter-dimension member = member ) TO selections.
      ENDLOOP.
    ENDLOOP.
    LOOP AT record-output_periods INTO member.
      APPEND VALUE #( purpose = 'output period' dimension = 'TIME' member = member ) TO selections.
    ENDLOOP.
    LOOP AT record-reference_periods INTO member.
      APPEND VALUE #( purpose = 'declared reference period' dimension = 'TIME' member = member ) TO selections.
    ENDLOOP.
    emit_table( name = record-id && '/FILTERS_AND_PERIODS' rows = selections ).
    IF record-row_count = 0 AND record-state = 'succeeded'.
      message( record-id && ': complete read returned zero rows; inspect effective filters and security diagnostics' ).
    ENDIF.
  ENDMETHOD.
  METHOD message.
    APPEND VALUE #( cell_id = mv_cell_id severity = 'Information' text = text ) TO messages.
  ENDMETHOD.
ENDCLASS.


