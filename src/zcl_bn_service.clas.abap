CLASS zcl_bn_service DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_column,
             name TYPE string, type TYPE string,
           END OF ty_column,
           tt_schema TYPE STANDARD TABLE OF ty_column WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_dataset,
             run_id TYPE string, cell_id TYPE string, revision TYPE i,
             notebook_id TYPE string, fingerprint TYPE string,
             created_at TYPE string, row_count TYPE i, logic_call TYPE abap_bool,
             bindings TYPE zcl_bn_types=>tt_bindings,
             schema TYPE tt_schema, retention_until TYPE timestampl,
             rows TYPE zcl_bn_context=>tt_rows,
             tables TYPE zcl_bn_context=>tt_tables,
             checkpoints TYPE zcl_bn_context=>tt_checkpoints,
             reads TYPE zcl_bn_context=>tt_reads, fixture_mode TYPE abap_bool,
             artifacts TYPE zcl_bn_dataset=>tt_headers, dataset_reads TYPE zcl_bn_dataset=>tt_access,
           END OF ty_dataset.
    CLASS-METHODS authorize IMPORTING activity TYPE char2 RAISING zcx_bn.
    CLASS-METHODS get_notebook IMPORTING id TYPE string
      RETURNING VALUE(notebook) TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
    CLASS-METHODS get_run IMPORTING id TYPE string
      RETURNING VALUE(run) TYPE zcl_bn_types=>ty_run RAISING zcx_bn.
    CLASS-METHODS dispatch IMPORTING path TYPE string method TYPE string body TYPE string
      id TYPE string DEFAULT '' notebook_id TYPE string DEFAULT ''
      run_id TYPE string DEFAULT '' cell_id TYPE string DEFAULT '' table_name TYPE string DEFAULT ''
      revision TYPE i DEFAULT 0 offset TYPE i DEFAULT 0 page_size TYPE i DEFAULT 20
      RETURNING VALUE(json) TYPE string RAISING zcx_bn.
    CLASS-METHODS run_logic IMPORTING notebook TYPE zcl_bn_types=>ty_notebook
      parameters TYPE ujk_t_script_logic_hashtable scope TYPE ujk_t_cv
      handler TYPE string handler_revision TYPE i allocation TYPE abap_bool DEFAULT abap_false
      EXPORTING result_data TYPE REF TO data
      RETURNING VALUE(run) TYPE zcl_bn_types=>ty_run RAISING zcx_bn.
    CLASS-METHODS work IMPORTING id TYPE string RAISING zcx_bn.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_notebook_header,
             id TYPE string, title TYPE string, revision TYPE i, author TYPE string, saved_at TYPE string,
             environment TYPE string, model TYPE string, explanation TYPE string,
           END OF ty_notebook_header,
           tt_notebook_headers TYPE STANDARD TABLE OF ty_notebook_header WITH DEFAULT KEY,
           BEGIN OF ty_run_header,
             id TYPE string, notebook_id TYPE string, state TYPE string, scope TYPE string,
             created_at TYPE string, finished_at TYPE string, results TYPE zcl_bn_types=>tt_results,
           END OF ty_run_header,
           tt_run_headers TYPE STANDARD TABLE OF ty_run_header WITH DEFAULT KEY,
           BEGIN OF ty_dataset_header,
             run_id TYPE string, cell_id TYPE string, revision TYPE i, notebook_id TYPE string,
             fingerprint TYPE string, created_at TYPE string, row_count TYPE i, logic_call TYPE abap_bool,
             fixture_mode TYPE abap_bool,
             bindings TYPE zcl_bn_types=>tt_bindings, artifacts TYPE zcl_bn_dataset=>tt_headers,
             retention_until TYPE timestampl,
           END OF ty_dataset_header,
           tt_dataset_headers TYPE HASHED TABLE OF ty_dataset_header WITH UNIQUE KEY cell_id.
    TYPES: BEGIN OF ty_folder,
             id TYPE string, name TYPE string,
           END OF ty_folder,
           tt_folders TYPE STANDARD TABLE OF ty_folder WITH DEFAULT KEY,
           BEGIN OF ty_membership,
             notebook_id TYPE string, folder_id TYPE string,
           END OF ty_membership,
           tt_memberships TYPE STANDARD TABLE OF ty_membership WITH DEFAULT KEY,
           BEGIN OF ty_organization,
             revision TYPE i, expected_revision TYPE i,
             folders TYPE tt_folders, memberships TYPE tt_memberships,
           END OF ty_organization.
    CLASS-METHODS organization RETURNING VALUE(result) TYPE ty_organization RAISING zcx_bn.
    CLASS-METHODS save_organization IMPORTING body TYPE string RETURNING VALUE(result) TYPE ty_organization RAISING zcx_bn.
    CLASS-DATA mv_cached_notebook TYPE string.
    CLASS-DATA mt_latest TYPE tt_dataset_headers.
    CLASS-METHODS run_headers IMPORTING notebook_id TYPE string RETURNING VALUE(result) TYPE tt_run_headers RAISING zcx_bn.
    CLASS-METHODS delete_notebook IMPORTING id TYPE string expected TYPE i RAISING zcx_bn.
    TYPES: BEGIN OF ty_request,
             id TYPE string, notebook_id TYPE string, expected_revision TYPE i,
             handler TYPE string, handler_revision TYPE i, execution_mode TYPE string,
             scope TYPE string, cell_id TYPE string, idempotency_key TYPE string,
             title TYPE string, explanation TYPE string, cells TYPE zcl_bn_types=>tt_cells,
             inputs TYPE zcl_bn_types=>tt_inputs, demo TYPE abap_bool,
             retry_run_id TYPE string,
             environment TYPE string, model TYPE string, kind TYPE string,
             dimension TYPE string, hierarchy TYPE string, search TYPE string, offset TYPE i,
           END OF ty_request.
    CLASS-METHODS save IMPORTING request TYPE ty_request
      RETURNING VALUE(notebook) TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
    CLASS-METHODS submit IMPORTING request TYPE ty_request
      RETURNING VALUE(run) TYPE zcl_bn_types=>ty_run RAISING zcx_bn.
    CLASS-METHODS persist_artifacts IMPORTING notebook_id TYPE string run_id TYPE string
      cell TYPE zcl_bn_types=>ty_cell fingerprint TYPE string packets TYPE zcl_bn_dataset=>tt_packets RAISING zcx_bn.
    CLASS-METHODS budget_seconds IMPORTING inputs TYPE zcl_bn_types=>tt_inputs RETURNING VALUE(seconds) TYPE i RAISING zcx_bn.
    CLASS-METHODS check_definition IMPORTING notebook TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
    CLASS-METHODS fingerprint IMPORTING notebook TYPE zcl_bn_types=>ty_notebook cell_id TYPE string
      RETURNING VALUE(result) TYPE string RAISING zcx_bn.
    CLASS-METHODS latest IMPORTING notebook TYPE zcl_bn_types=>ty_notebook cell_id TYPE string
      RETURNING VALUE(dataset) TYPE ty_dataset RAISING zcx_bn.
    CLASS-METHODS is_current IMPORTING notebook TYPE zcl_bn_types=>ty_notebook dataset TYPE ty_dataset
      RETURNING VALUE(result) TYPE abap_bool RAISING zcx_bn.
    CLASS-METHODS reconcile CHANGING run TYPE zcl_bn_types=>ty_run RAISING zcx_bn.
    CLASS-METHODS demo IMPORTING environment TYPE string DEFAULT '' model TYPE string DEFAULT ''
      RETURNING VALUE(request) TYPE ty_request RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_service IMPLEMENTATION.
  METHOD authorize.
    " Arbitrary ABAP is not sandboxed: only explicitly enabled trusted DEV users.
    SELECT SINGLE cccategory FROM t000 INTO @DATA(category) WHERE mandt = @sy-mandt.
    IF category = 'P'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PRD_BLOCKED' detail = 'Production requires approved release execution' status = 403.
    ENDIF.
    DATA allow_name TYPE tvarvc-name.
    allow_name = |ZBN_DEV_{ sy-sysid }_{ sy-mandt }|.
    SELECT SINGLE low FROM tvarvc INTO @DATA(allowed)
      WHERE name = @allow_name AND type = 'S' AND sign = 'I' AND opti = 'EQ' AND low = @sy-uname.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DISABLED' detail = 'Notebook DEV access is not enabled for this SAP user' status = 403.
    ENDIF.
    AUTHORITY-CHECK OBJECT 'S_DEVELOP' ID 'DEVCLASS' FIELD 'ZBPC_NOTEBOOK'
      ID 'OBJTYPE' FIELD 'PROG' ID 'OBJNAME' FIELD 'ZBN_JOB'
      ID 'P_GROUP' DUMMY ID 'ACTVT' FIELD activity.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FORBIDDEN' detail = 'Notebook development authorization missing' status = 403.
    ENDIF.
  ENDMETHOD.
  METHOD get_notebook.
    IF zcl_bn_store=>current( kind = 'A' id = id ) > 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NOTEBOOK_DELETED' detail = 'Notebook has been deleted' status = 410.
    ENDIF.
    DATA(payload) = zcl_bn_store=>read( kind = 'N' id = id ).
    /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( payload ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = notebook ).
  ENDMETHOD.
  METHOD get_run.
    DATA(payload) = zcl_bn_store=>read( kind = 'R' id = id ).
    /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( payload ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = run ).
  ENDMETHOD.
  METHOD budget_seconds.
    seconds = 600.
    READ TABLE inputs INTO DATA(input) WITH KEY name = 'RUN_SECONDS'.
    IF sy-subrc = 0.
      DATA(value) = CONV decfloat34( input-value ).
      IF input-type <> 'number' OR value < 1 OR value > 7200 OR value <> trunc( value ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESOURCE_BUDGET' detail = 'RUN_SECONDS must be an integer from 1 to 7200'.
      ENDIF.
      seconds = CONV i( value ).
    ENDIF.
  ENDMETHOD.
  METHOD check_definition.
    zcl_bn_types=>validate_text( notebook-title ). zcl_bn_types=>validate_text( notebook-explanation ).
    budget_seconds( notebook-inputs ).
    LOOP AT notebook-inputs INTO DATA(resource) WHERE name = 'READ_LIMIT' OR name = 'WORK_ROWS' OR name = 'PREVIEW_ROWS' OR name = 'DATASET_BYTES'.
      DATA(limit_value) = CONV decfloat34( resource-value ).
      DATA(maximum) = COND i( WHEN resource-name = 'PREVIEW_ROWS' THEN 5000
        WHEN resource-name = 'DATASET_BYTES' THEN 268435456 ELSE 1000000 ).
      IF resource-type <> 'number' OR limit_value < 1 OR limit_value > maximum OR limit_value <> trunc( limit_value ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESOURCE_BUDGET' detail = 'Read, working-table and preview budgets must be positive integers within the server limit'.
      ENDIF.
    ENDLOOP.
    IF notebook-title IS INITIAL OR strlen( notebook-title ) > 120 OR lines( notebook-cells ) > 30 OR lines( notebook-inputs ) > 50.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEFINITION' detail = 'Title required; maximum 30 cells and 50 inputs'.
    ENDIF.
    IF strlen( notebook-explanation ) > 8000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'EXPLANATION' detail = 'Setup explanation exceeds 8000 characters'.
    ENDIF.
    DATA seen TYPE zcl_bn_types=>tt_ids.
    LOOP AT notebook-inputs INTO DATA(parameter).
      zcl_bn_types=>validate_text( parameter-value ).
      FIND REGEX '^[A-Za-z][A-Za-z0-9_]{0,29}$' IN parameter-name.
      IF sy-subrc <> 0 OR line_exists( seen[ table_line = parameter-name ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_NAME' detail = 'Input names must be unique identifiers'.
      ENDIF.
      CASE parameter-type.
        WHEN 'number'.
          TRY.
              DATA(number) = CONV decfloat34( parameter-value ).
            CATCH cx_sy_conversion_error.
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Numeric input is invalid'.
          ENDTRY.
        WHEN 'boolean'.
          IF parameter-value <> 'true' AND parameter-value <> 'false'.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Boolean input must be true or false'.
          ENDIF.
        WHEN 'string' OR 'member' OR 'range'.
        WHEN OTHERS.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Supported input types: number, string, boolean, member, range'.
      ENDCASE.
      APPEND parameter-name TO seen.
    ENDLOOP.
    CLEAR seen.
    LOOP AT notebook-cells INTO DATA(cell).
      zcl_bn_types=>validate_text( cell-source ). zcl_bn_types=>validate_text( cell-title ).
      zcl_bn_types=>validate_text( cell-explanation ).
      IF strlen( cell-explanation ) > 4000.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'EXPLANATION' detail = 'Stage explanation exceeds 4000 characters'.
      ENDIF.
      FIND REGEX '^[A-Za-z][A-Za-z0-9_-]{0,29}$' IN cell-id.
      IF sy-subrc <> 0 OR line_exists( seen[ table_line = cell-id ] ) OR strlen( cell-source ) > 60000.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CELL' detail = 'Invalid or duplicate cell ID, or source too long'.
      ENDIF.
      DATA unique TYPE zcl_bn_types=>tt_ids.
      CLEAR unique.
      LOOP AT cell-dependencies INTO DATA(dependency).
        IF NOT line_exists( seen[ table_line = dependency ] ) OR line_exists( unique[ table_line = dependency ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEPENDENCY_ORDER' detail = 'Dependencies must be unique earlier cell IDs'.
        ENDIF.
        APPEND dependency TO unique.
      ENDLOOP.
      APPEND cell-id TO seen.
    ENDLOOP.
  ENDMETHOD.
  METHOD fingerprint.
    READ TABLE notebook-cells INTO DATA(cell) WITH KEY id = cell_id.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CELL' detail = 'Cell is missing'.
    ENDIF.
    DATA(sequence) = sy-tabix.
    DATA text TYPE string.
    text = |{ cell-id }:{ sequence }:{ cell-checksum }:{ notebook-environment }:{ notebook-model }:{ zcl_bn_types=>json( notebook-inputs ) }|.
    LOOP AT cell-dependencies INTO DATA(dependency).
      text = |{ text }:{ fingerprint( notebook = notebook cell_id = dependency ) }|.
    ENDLOOP.
    result = zcl_bn_types=>hash( text ).
  ENDMETHOD.
  METHOD run_headers.
    LOOP AT zcl_bn_store=>documents( 'R' ) INTO DATA(document).
      DATA header TYPE ty_run_header.
      CLEAR header.
      /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( document-payload ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = header ).
      IF header-notebook_id = notebook_id. APPEND header TO result. ENDIF.
    ENDLOOP.
    SORT result BY created_at DESCENDING id DESCENDING.
  ENDMETHOD.
  METHOD delete_notebook.
    authorize( '02' ).
    DATA(revision) = zcl_bn_store=>lock_notebook( id ).
    IF revision <> expected.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CONFLICT' detail = 'Notebook changed; reload before deleting' status = 409.
    ENDIF.
    LOOP AT run_headers( id ) INTO DATA(header).
      IF header-state = 'queued' OR header-state = 'running'.
        DATA(run) = get_run( header-id ).
        reconcile( CHANGING run = run ).
        IF run-state = 'queued' OR run-state = 'running'.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NOTEBOOK_BUSY'
            detail = 'Cancel or finish active executions before deleting this notebook' status = 409.
        ENDIF.
      ENDIF.
    ENDLOOP.
    TYPES: BEGIN OF ty_deletion,
             notebook_id TYPE string, notebook_revision TYPE i, deleted_at TYPE string, deleted_by TYPE syuname,
           END OF ty_deletion.
    zcl_bn_store=>write( kind = 'A' id = id expected = 0 payload = zcl_bn_types=>json(
      VALUE ty_deletion( notebook_id = id notebook_revision = revision deleted_at = zcl_bn_types=>timestamp( ) deleted_by = sy-uname ) ) ).
  ENDMETHOD.
  METHOD latest.
    IF mv_cached_notebook <> notebook-id.
      CLEAR mt_latest. mv_cached_notebook = notebook-id.
      FIELD-SYMBOLS <latest> TYPE ty_dataset_header.
      LOOP AT run_headers( notebook-id ) INTO DATA(header).
        LOOP AT header-results INTO DATA(result).
          UNASSIGN <latest>.
          READ TABLE mt_latest ASSIGNING <latest> WITH KEY cell_id = result-cell_id.
          IF sy-subrc = 0 AND result-created_at IS NOT INITIAL AND result-created_at <= <latest>-created_at. CONTINUE. ENDIF.
          DATA(payload) = zcl_bn_store=>read( kind = 'D' id = |{ result-run_id }:{ result-cell_id }| revision = result-revision ).
          DATA candidate TYPE ty_dataset_header.
          CLEAR candidate.
          /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( payload ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = candidate ).
          IF candidate-notebook_id <> notebook-id. CONTINUE. ENDIF.
          IF <latest> IS ASSIGNED.
            IF candidate-created_at > <latest>-created_at. <latest> = candidate. ENDIF.
          ELSE.
            INSERT candidate INTO TABLE mt_latest.
          ENDIF.
          UNASSIGN <latest>.
        ENDLOOP.
      ENDLOOP.
    ENDIF.
    READ TABLE mt_latest INTO DATA(found) WITH KEY cell_id = cell_id.
    IF sy-subrc = 0. dataset = CORRESPONDING #( found ). ENDIF.
  ENDMETHOD.
  METHOD save.
    authorize( '02' ).
    notebook-id = request-id.
    IF notebook-id IS NOT INITIAL. zcl_bn_store=>lock_notebook( notebook-id ). ENDIF.
    IF notebook-id IS INITIAL.
      notebook-id = zcl_bn_types=>uuid( ).
    ENDIF.
    notebook-title = request-title. notebook-cells = request-cells. notebook-explanation = request-explanation.
    notebook-environment = request-environment. notebook-model = request-model.
    notebook-inputs = zcl_bn_types=>normalize_inputs( request-inputs ).
    check_definition( notebook ).
    " Script saves must pass the native compiler before any immutable rows are written.
    LOOP AT notebook-cells INTO DATA(script_cell).
      FIND REGEX '^\* BPC Notebook Script v[12]' IN script_cell-source.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      zcl_bn_compiler=>compile( EXPORTING source = script_cell-source
        IMPORTING pool = DATA(script_pool) diagnostics = DATA(script_diagnostics) ).
      IF script_diagnostics IS NOT INITIAL.
        DATA(script_diagnostic) = script_diagnostics[ 1 ].
        DATA script_body TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
        DATA script_number TYPE string.
        DATA(script_origin) = 1.
        SPLIT script_cell-source AT cl_abap_char_utilities=>newline INTO TABLE script_body.
        LOOP AT script_body INTO DATA(script_line) FROM 1 TO script_diagnostic-line.
          FIND REGEX '^\* @bn-line ([0-9]+)$' IN script_line SUBMATCHES script_number.
          IF sy-subrc = 0. script_origin = CONV i( script_number ). ENDIF.
        ENDLOOP.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_ABAP'
          detail = |Cell { script_cell-id }, script line { script_origin }: { script_diagnostic-message }|.
      ENDIF.
    ENDLOOP.
    zcl_bn_bpc=>resolve( CHANGING notebook = notebook ).
    DATA previous TYPE zcl_bn_types=>ty_notebook.
    IF request-expected_revision > 0.
      previous = get_notebook( notebook-id ).
    ENDIF.
    LOOP AT notebook-cells ASSIGNING FIELD-SYMBOL(<cell>).
      DATA(sequence) = sy-tabix.
      DATA old TYPE zcl_bn_types=>ty_cell.
      CLEAR old.
      READ TABLE previous-cells INTO old WITH KEY id = <cell>-id.
      IF sy-subrc <> 0.
        SELECT MAX( version ) FROM zbn_src INTO @old-source_version
          WHERE notebook_id = @notebook-id AND cell_id = @<cell>-id.
        IF old-source_version > 0.
          SELECT SINGLE checksum FROM zbn_src INTO @old-checksum
            WHERE notebook_id = @notebook-id AND cell_id = @<cell>-id AND version = @old-source_version.
        ENDIF.
      ENDIF.
      <cell>-checksum = zcl_bn_types=>hash( <cell>-source ).
      <cell>-source_version = old-source_version.
      CLEAR <cell>-output.
      IF old-checksum <> <cell>-checksum.
        <cell>-source_version = old-source_version + 1.
        DATA row TYPE zbn_src.
        CLEAR row.
        row-mandt = sy-mandt. row-notebook_id = notebook-id. row-cell_id = <cell>-id.
        row-version = <cell>-source_version. row-sequence = sequence. row-source = <cell>-source.
        row-dependencies = zcl_bn_types=>json( <cell>-dependencies ).
        row-checksum = <cell>-checksum. row-author = sy-uname. GET TIME STAMP FIELD row-created_at.
        INSERT zbn_src FROM @row.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SOURCE_CONFLICT' detail = 'Immutable source version already exists' status = 409.
        ENDIF.
      ENDIF.
    ENDLOOP.
    notebook-revision = request-expected_revision + 1.
    notebook-author = sy-uname. notebook-saved_at = zcl_bn_types=>timestamp( ).
    notebook-checksum = zcl_bn_types=>hash( zcl_bn_types=>json( notebook ) ).
    zcl_bn_store=>write( kind = 'N' id = notebook-id payload = zcl_bn_types=>json( notebook ) expected = request-expected_revision ).
  ENDMETHOD.
  METHOD is_current.
    IF dataset-logic_call = abap_true OR dataset-fixture_mode = abap_true. RETURN. ENDIF.
    IF dataset-run_id IS INITIAL OR dataset-fingerprint <> fingerprint( notebook = notebook cell_id = dataset-cell_id ). RETURN. ENDIF.
    IF dataset-artifacts IS NOT INITIAL.
      DATA stamp TYPE timestampl. GET TIME STAMP FIELD stamp.
      IF dataset-retention_until < stamp. RETURN. ENDIF.
      LOOP AT dataset-artifacts INTO DATA(artifact).
        IF zcl_bn_store=>current( kind = 'W' id = zcl_bn_dataset=>storage_id(
          run_id = dataset-run_id cell_id = dataset-cell_id name = artifact-name ) ) = 0. RETURN. ENDIF.
      ENDLOOP.
    ENDIF.
    READ TABLE notebook-cells INTO DATA(cell) WITH KEY id = dataset-cell_id.
    LOOP AT cell-dependencies INTO DATA(dependency).
      DATA upstream TYPE ty_dataset.
      upstream = latest( notebook = notebook cell_id = dependency ).
      READ TABLE dataset-bindings INTO DATA(binding) WITH KEY cell_id = dependency.
      IF sy-subrc <> 0 OR binding-run_id <> upstream-run_id OR is_current( notebook = notebook dataset = upstream ) = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
    result = abap_true.
  ENDMETHOD.
  METHOD submit.
    authorize( '16' ).
    IF strlen( request-idempotency_key ) < 8 OR strlen( request-idempotency_key ) > 80.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'KEY' detail = 'Submission key must have 8 to 80 characters'.
    ENDIF.
    DATA key TYPE string.
    key = zcl_bn_types=>hash( |{ sy-uname }:{ request-idempotency_key }| ).
    TYPES: BEGIN OF ty_reservation,
             id TYPE string, checksum TYPE string,
           END OF ty_reservation.
    DATA reservation TYPE ty_reservation.
    DATA digest TYPE string.
    digest = zcl_bn_types=>hash( zcl_bn_types=>json( request ) ).
    IF zcl_bn_store=>current( kind = 'K' id = key ) > 0.
      DATA(existing) = zcl_bn_store=>read( kind = 'K' id = key ).
      /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( existing ) CHANGING data = reservation ).
      IF reservation-checksum <> digest.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'KEY_REUSED' detail = 'Key was used for another request' status = 409.
      ENDIF.
      run = get_run( reservation-id ). RETURN.
    ENDIF.
    DATA notebook TYPE zcl_bn_types=>ty_notebook.
    DATA original TYPE zcl_bn_types=>ty_run.
    IF request-retry_run_id IS NOT INITIAL.
      original = get_run( request-retry_run_id ).
      IF original-fixture_mode = abap_true.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATA_SNAPSHOT'
          detail = 'Fixture inputs are private working tables; install them again in a new validation run' status = 409.
      ENDIF.
      IF original-snapshot-model IS NOT INITIAL OR line_exists( original-snapshot-inputs[ purpose = 'reference' ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATA_SNAPSHOT'
          detail = 'BPC reads are not historical fact snapshots; start a new Run all instead of rereading facts under an old revision' status = 409.
      ENDIF.
      zcl_bn_store=>lock_notebook( original-notebook_id ).
      DATA(original_json) = zcl_bn_store=>read( kind = 'N' id = original-notebook_id revision = original-snapshot-revision ).
      /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( original_json ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = notebook ).
    ELSE.
      zcl_bn_store=>lock_notebook( request-notebook_id ).
      notebook = get_notebook( request-notebook_id ).
    ENDIF.
    IF notebook-revision <> request-expected_revision.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CONFLICT' detail = 'Notebook revision changed' status = 409.
    ENDIF.
    check_definition( notebook ).
    IF original-id IS NOT INITIAL.
      notebook-inputs = original-snapshot-inputs.
      zcl_bn_bpc=>validate_frozen( notebook ).
    ELSE.
      DATA(before) = zcl_bn_types=>json( notebook-inputs ).
      zcl_bn_bpc=>resolve( EXPORTING complete = abap_true CHANGING notebook = notebook ).
      IF before <> zcl_bn_types=>json( notebook-inputs ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA_CHANGED'
          detail = 'Hierarchy changed since save; save again to review current base members' status = 409.
      ENDIF.
    ENDIF.
    DATA selected TYPE zcl_bn_types=>tt_cells.
    DATA index TYPE i.
    READ TABLE notebook-cells TRANSPORTING NO FIELDS WITH KEY id = request-cell_id.
    index = sy-tabix.
    IF request-scope <> 'all' AND sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CELL' detail = 'Selected cell missing'.
    ENDIF.
    CASE request-scope.
      WHEN 'all'. selected = notebook-cells.
      WHEN 'one'. APPEND notebook-cells[ index ] TO selected.
      WHEN 'through'. APPEND LINES OF notebook-cells FROM 1 TO index TO selected.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCOPE' detail = 'Invalid execution scope'.
    ENDCASE.
    IF selected IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'EMPTY' detail = 'No cells selected'.
    ENDIF.
    LOOP AT selected INTO DATA(cell).
      LOOP AT cell-dependencies INTO DATA(dependency).
        IF NOT line_exists( selected[ id = dependency ] ).
          DATA dataset TYPE ty_dataset.
          IF original-id IS NOT INITIAL.
            READ TABLE original-bindings INTO DATA(old_binding) WITH KEY cell_id = dependency.
            IF sy-subrc <> 0.
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEPENDENCY' detail = 'Historical binding missing'.
            ENDIF.
            DATA(old_output) = zcl_bn_store=>read( kind = 'D' id = |{ old_binding-run_id }:{ dependency }| revision = old_binding-revision ).
            /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( old_output ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = dataset ).
          ELSE.
            dataset = latest( notebook = notebook cell_id = dependency ).
            IF is_current( notebook = notebook dataset = dataset ) = abap_false.
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'STALE_DEPENDENCY' detail = |Execute current dependency { dependency }| status = 409.
            ENDIF.
          ENDIF.
          IF dataset-fixture_mode = abap_true.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE'
              detail = 'Fixture datasets cannot satisfy ordinary or historical cell dependencies' status = 409.
          ENDIF.
          IF NOT line_exists( run-bindings[ cell_id = dependency ] ).
            APPEND VALUE #( cell_id = dependency run_id = dataset-run_id revision = dataset-revision ) TO run-bindings.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    run-id = zcl_bn_types=>uuid( ). run-owner = sy-uname. run-notebook_id = notebook-id.
    run-snapshot = notebook. run-snapshot-cells = selected.
    run-created_at = zcl_bn_types=>timestamp( ). run-state = 'queued'. run-native = abap_true.
    GET TIME STAMP FIELD run-deadline.
    run-deadline = cl_abap_tstmp=>add( tstmp = run-deadline secs = budget_seconds( notebook-inputs ) ).
    run-scope = request-scope. run-frozen_bindings = run-bindings.
    run-checksum = zcl_bn_types=>hash( zcl_bn_types=>json( run-snapshot ) && zcl_bn_types=>json( run-frozen_bindings ) ).
    run-job_name = |ZBN_{ run-id(20) }|.
    " Snapshot, binding references and idempotency reservation share a database LUW.
    reservation-id = run-id. reservation-checksum = digest.
    zcl_bn_store=>write( kind = 'K' id = key payload = zcl_bn_types=>json( reservation ) expected = 0 ).
    zcl_bn_store=>write( kind = 'R' id = run-id payload = zcl_bn_types=>json( run ) expected = 0 ).
    COMMIT WORK AND WAIT.
    CALL FUNCTION 'JOB_OPEN' EXPORTING jobname = run-job_name
      IMPORTING jobcount = run-job_id EXCEPTIONS OTHERS = 1.
    IF sy-subrc = 0.
      SUBMIT zbn_job WITH p_run = run-id VIA JOB run-job_name NUMBER run-job_id AND RETURN.
      IF sy-subrc = 0.
        " Persist job identity before release: the worker must find its frozen snapshot.
        zcl_bn_store=>write( kind = 'R' id = run-id payload = zcl_bn_types=>json( run ) expected = 1 ).
        COMMIT WORK AND WAIT.
        CALL FUNCTION 'JOB_CLOSE' EXPORTING jobname = run-job_name jobcount = run-job_id
          strtimmed = abap_true EXCEPTIONS OTHERS = 1.
      ENDIF.
    ENDIF.
    IF sy-subrc <> 0.
      run-state = 'failed'. run-error-code = 'JOB_SUBMISSION'. run-error-message = 'Background job could not be released; inspect SM37'.
      zcl_bn_store=>write( kind = 'R' id = run-id payload = zcl_bn_types=>json( run )
        expected = zcl_bn_store=>current( kind = 'R' id = run-id ) ).
      COMMIT WORK AND WAIT.
    ENDIF.
  ENDMETHOD.
  METHOD reconcile.
    IF run-state <> 'queued' AND run-state <> 'running'. RETURN. ENDIF.
    DATA now TYPE timestampl.
    GET TIME STAMP FIELD now.
    IF run-deadline IS NOT INITIAL AND now > run-deadline.
      DATA(timeout_revision) = zcl_bn_store=>lock_run( run-id ).
      run = get_run( run-id ).
      IF run-state <> 'queued' AND run-state <> 'running'. RETURN. ENDIF.
      run-state = 'failed'. run-error-code = 'TIMEOUT'.
      run-error-message = 'Deadline exceeded. Inspect and terminate any active job in SM37; no automatic retry'.
      run-finished_at = zcl_bn_types=>timestamp( ).
      zcl_bn_store=>write( kind = 'R' id = run-id payload = zcl_bn_types=>json( run ) expected = timeout_revision ).
      RETURN.
    ENDIF.
    DATA status TYPE btcstatus.
    IF run-job_id IS NOT INITIAL.
      CALL FUNCTION 'BP_JOB_STATUS_GET' EXPORTING jobname = run-job_name jobcount = run-job_id
        IMPORTING status = status EXCEPTIONS OTHERS = 1.
      IF sy-subrc = 0 AND ( status = 'A' OR status = 'F' ).
        DATA(revision) = zcl_bn_store=>lock_run( run-id ).
        run = get_run( run-id ).
        IF run-state <> 'queued' AND run-state <> 'running'. RETURN. ENDIF.
        run-state = 'failed'. run-error-code = 'JOB_TERMINATED'.
        run-error-message = 'SAP job ended without a completed notebook result; inspect SM37/ST22'.
        run-finished_at = zcl_bn_types=>timestamp( ).
        zcl_bn_store=>write( kind = 'R' id = run-id payload = zcl_bn_types=>json( run )
          expected = revision ).
      ENDIF.
    ENDIF.
  ENDMETHOD.
  METHOD run_logic.
    " Synchronous execution in the Script Logic caller LUW: no jobs or transaction boundaries.
    authorize( '16' ).
    check_definition( notebook ).
    zcl_bn_bpc=>validate_frozen( notebook ).
    zcl_bn_bpc=>validate_scope( environment = notebook-environment model = notebook-model scope = scope ).
    run = VALUE #( id = zcl_bn_types=>uuid( ) owner = sy-uname notebook_id = notebook-id
      state = 'running' scope = 'logic' native = abap_true created_at = zcl_bn_types=>timestamp( )
      started_at = zcl_bn_types=>timestamp( ) snapshot = notebook current_view = scope
      logic_parameters = parameters handler = handler handler_revision = handler_revision ).
    run-checksum = zcl_bn_types=>hash( zcl_bn_types=>json( run-snapshot ) && zcl_bn_types=>json( scope ) &&
      zcl_bn_types=>json( parameters ) && handler && |{ handler_revision }| ).
    DATA started TYPE timestampl.
    DATA stamp TYPE timestampl.
    GET TIME STAMP FIELD started.
    DATA live TYPE zcl_bn_context=>tt_live_outputs.
    DATA live_datasets TYPE zcl_bn_dataset=>tt_live.
    DATA datasets TYPE STANDARD TABLE OF ty_dataset WITH DEFAULT KEY.
    LOOP AT notebook-cells INTO DATA(cell).
      GET TIME STAMP FIELD stamp.
      IF cl_abap_tstmp=>subtract( tstmp1 = stamp tstmp2 = started ) > budget_seconds( notebook-inputs ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TIMEOUT' detail = 'Script Logic notebook deadline exceeded between cells'.
      ENDIF.
      SELECT SINGLE source, checksum FROM zbn_src INTO (@DATA(source), @DATA(checksum))
        WHERE notebook_id = @notebook-id AND cell_id = @cell-id AND version = @cell-source_version.
      IF sy-subrc <> 0 OR checksum <> cell-checksum OR zcl_bn_types=>hash( source ) <> checksum.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SOURCE_INTEGRITY' detail = 'Saved handler source is missing or changed'.
      ENDIF.
      DATA pool TYPE progname.
      DATA diagnostics TYPE zcl_bn_types=>tt_diagnostics.
      zcl_bn_compiler=>compile( EXPORTING source = source IMPORTING pool = pool diagnostics = diagnostics ).
      IF pool IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SYNTAX'
          detail = |Handler { handler }, cell { cell-id }: saved source compilation failed|.
      ENDIF.
      DATA(context) = NEW zcl_bn_context( inputs = notebook-inputs bindings = run-bindings
        dependencies = cell-dependencies cell_id = cell-id run_id = run-id environment = notebook-environment model = notebook-model
        live_outputs = live live_datasets = live_datasets notebook_id = notebook-id
        scope = scope logic_parameters = parameters logic_call = abap_true ).
      DATA cell_started TYPE timestampl.
      GET TIME STAMP FIELD cell_started.
      TRY.
        zcl_bn_bpc=>begin_cell_cache( ).
        PERFORM execute IN PROGRAM (pool) USING context.
        context->check_budget( ).
        zcl_bn_bpc=>end_cell_cache( ).
      CLEANUP.
        zcl_bn_bpc=>end_cell_cache( ).
      ENDTRY.
      IF context->result_rows IS BOUND AND allocation = abap_true.
        IF result_data IS BOUND OR context->result_kind <> 'delta'.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_CONTRACT' detail = 'Publish exactly one delta result for allocation'.
        ENDIF.
        result_data = context->result_rows.
      ENDIF.
      GET TIME STAMP FIELD stamp.
      DATA(dataset) = VALUE ty_dataset( logic_call = abap_true run_id = run-id cell_id = cell-id revision = 1 notebook_id = notebook-id
        rows = context->outputs tables = context->tables checkpoints = context->checkpoints
        reads = context->reads fixture_mode = context->fixture_mode artifacts = context->artifacts
        dataset_reads = context->dataset_reads row_count = lines( context->outputs )
        created_at = zcl_bn_types=>timestamp( ) fingerprint = fingerprint( notebook = notebook cell_id = cell-id )
        schema = VALUE #( ( name = 'key' type = 'string' ) ( name = 'amount' type = 'decimal' ) ) ).
      IF dataset-artifacts IS NOT INITIAL.
        dataset-row_count = 0.
        LOOP AT dataset-artifacts INTO DATA(artifact_count). dataset-row_count = dataset-row_count + artifact_count-row_count. ENDLOOP.
      ELSE.
        LOOP AT dataset-tables INTO DATA(table). dataset-row_count = dataset-row_count + table-row_count. ENDLOOP.
      ENDIF.
      GET TIME STAMP FIELD dataset-retention_until.
      dataset-retention_until = cl_abap_tstmp=>add( tstmp = dataset-retention_until secs = 2592000 ).
      LOOP AT cell-dependencies INTO DATA(dependency).
        READ TABLE run-bindings INTO DATA(binding) WITH KEY cell_id = dependency.
        IF sy-subrc = 0. APPEND binding TO dataset-bindings. ENDIF.
      ENDLOOP.
      APPEND dataset TO datasets.
      APPEND VALUE #( cell_id = cell-id packets = context->dataset_packets( ) ) TO live_datasets.
      APPEND VALUE #( cell_id = cell-id rows = context->outputs ) TO live.
      APPEND VALUE #( cell_id = cell-id run_id = run-id revision = 1 ) TO run-bindings.
      APPEND VALUE #( cell_id = cell-id run_id = run-id revision = 1 row_count = dataset-row_count
        duration_ms = cl_abap_tstmp=>subtract( tstmp1 = stamp tstmp2 = cell_started ) * 1000
        checksum = zcl_bn_types=>hash( zcl_bn_types=>json( dataset ) ) created_at = dataset-created_at ) TO run-results.
      APPEND LINES OF context->messages TO run-messages. APPEND LINES OF context->checkpoints TO run-checkpoints.
    ENDLOOP.
    IF allocation = abap_true.
      IF result_data IS NOT BOUND.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_CONTRACT' detail = 'Allocation requires one explicit final delta dataset'.
      ENDIF.
      FIELD-SYMBOLS <result> TYPE STANDARD TABLE. ASSIGN result_data->* TO <result>.
      zcl_bn_bpc=>validate_result( environment = notebook-environment model = notebook-model rows = <result>
        output_view = zcl_bn_bpc=>scoped_view( inputs = notebook-inputs scope = scope ) ).
    ENDIF.
    " Stage records only after every cell succeeds. Script Logic owns commit/rollback.
    LOOP AT datasets INTO dataset.
      READ TABLE notebook-cells INTO cell WITH KEY id = dataset-cell_id.
      READ TABLE live_datasets INTO DATA(native) WITH KEY cell_id = dataset-cell_id.
      persist_artifacts( notebook_id = notebook-id run_id = run-id cell = cell
        fingerprint = dataset-fingerprint packets = native-packets ).
      zcl_bn_store=>write( kind = 'D' id = |{ run-id }:{ dataset-cell_id }|
        payload = zcl_bn_types=>json( dataset ) expected = 0 ).
    ENDLOOP.
    GET TIME STAMP FIELD stamp.
    run-state = 'succeeded'. run-progress = 1. run-finished_at = zcl_bn_types=>timestamp( ).
    run-duration_ms = cl_abap_tstmp=>subtract( tstmp1 = stamp tstmp2 = started ) * 1000.
    zcl_bn_store=>write( kind = 'R' id = run-id payload = zcl_bn_types=>json( run ) expected = 0 ).
  ENDMETHOD.
  METHOD persist_artifacts.
    LOOP AT packets INTO DATA(packet).
      DATA(saved) = VALUE zcl_bn_dataset=>ty_saved( notebook_id = notebook_id run_id = run_id cell_id = cell-id
        revision = 1 source_checksum = cell-checksum source_version = cell-source_version fingerprint = fingerprint packet = packet ).
      zcl_bn_store=>write( kind = 'W' id = zcl_bn_dataset=>storage_id( run_id = run_id cell_id = cell-id name = packet-name )
        expected = 0 payload = zcl_bn_types=>json( saved ) ).
    ENDLOOP.
  ENDMETHOD.
  METHOD work.
    CLEAR: mv_cached_notebook, mt_latest.
    authorize( '16' ).
    DATA run TYPE zcl_bn_types=>ty_run.
    DATA rev TYPE i.
    rev = zcl_bn_store=>lock_run( id ).
    run = get_run( id ).
    IF run-state <> 'queued'. RETURN. ENDIF.
    IF run-checksum <> zcl_bn_types=>hash( zcl_bn_types=>json( run-snapshot ) && zcl_bn_types=>json( run-frozen_bindings ) ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INTEGRITY' detail = 'Frozen snapshot checksum mismatch'.
    ENDIF.
    run-state = 'running'. run-started_at = zcl_bn_types=>timestamp( ).
    zcl_bn_store=>write( kind = 'R' id = id payload = zcl_bn_types=>json( run ) expected = rev ).
    COMMIT WORK AND WAIT.
    DATA started TYPE timestampl.
    GET TIME STAMP FIELD started.
    TRY.
        zcl_bn_bpc=>validate_frozen( run-snapshot ).
        " Read the full immutable notebook revision for recursive fingerprints (one-cell scope).
        DATA(full_json) = zcl_bn_store=>read( kind = 'N' id = run-notebook_id revision = run-snapshot-revision ).
        DATA full TYPE zcl_bn_types=>ty_notebook.
        /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( full_json ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = full ).
        LOOP AT run-snapshot-cells INTO DATA(cell).
          DATA current TYPE zcl_bn_types=>ty_run.
          current = get_run( id ).
          IF current-cancel_requested = abap_true.
            run-cancel_requested = abap_true. run-state = 'cancelled'. EXIT.
          ENDIF.
          DATA stamp TYPE timestampl.
          GET TIME STAMP FIELD stamp.
          IF cl_abap_tstmp=>subtract( tstmp1 = stamp tstmp2 = started ) > budget_seconds( run-snapshot-inputs ).
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TIMEOUT' detail = 'Configured execution deadline exceeded between cells'.
          ENDIF.
          " Source is loaded from the immutable SAP source table, never the HTTP request.
          SELECT SINGLE source, checksum FROM zbn_src INTO (@DATA(source), @DATA(checksum))
            WHERE notebook_id = @run-notebook_id AND cell_id = @cell-id AND version = @cell-source_version.
          IF sy-subrc <> 0 OR checksum <> cell-checksum OR zcl_bn_types=>hash( source ) <> checksum.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SOURCE_INTEGRITY' detail = 'Saved source version is missing or changed'.
          ENDIF.
          DATA pool TYPE progname.
          DATA diagnostics TYPE zcl_bn_types=>tt_diagnostics.
          zcl_bn_compiler=>compile( EXPORTING source = source IMPORTING pool = pool diagnostics = diagnostics ).
          IF pool IS INITIAL.
            LOOP AT diagnostics INTO DATA(diagnostic).
              diagnostic-cell_id = cell-id. APPEND diagnostic TO run-diagnostics.
              APPEND VALUE #( cell_id = cell-id severity = 'error'
                text = |Line { diagnostic-line }: { diagnostic-message }| ) TO run-messages.
            ENDLOOP.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SYNTAX' detail = 'Cell compilation failed; see diagnostics'.
          ENDIF.
          DATA(context) = NEW zcl_bn_context( inputs = run-snapshot-inputs bindings = run-bindings
            dependencies = cell-dependencies cell_id = cell-id run_id = run-id
            environment = run-snapshot-environment model = run-snapshot-model notebook_id = run-notebook_id
            fixture_required = run-fixture_mode ).
          DATA cell_started TYPE timestampl.
          GET TIME STAMP FIELD cell_started.
          TRY.
            zcl_bn_bpc=>begin_cell_cache( ).
            PERFORM execute IN PROGRAM (pool) USING context.
            context->check_budget( ).
            zcl_bn_bpc=>end_cell_cache( ).
          CLEANUP.
            zcl_bn_bpc=>end_cell_cache( ).
          ENDTRY.
          IF context->fixture_mode = abap_true.
            IF run-fixture_mode <> abap_true AND run-results IS NOT INITIAL.
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE'
                detail = 'Fixture validation must begin in the first executed cell; live and fixture runs cannot be mixed'.
            ENDIF.
            run-fixture_mode = abap_true.
          ELSEIF run-fixture_mode = abap_true.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE'
              detail = 'Each fixture validation stage must enable its retained fixture tables; live fallback is blocked'.
          ENDIF.
          GET TIME STAMP FIELD stamp.
          DATA dataset TYPE ty_dataset.
          CLEAR dataset.
          dataset-run_id = id. dataset-cell_id = cell-id. dataset-revision = 1.
          dataset-notebook_id = run-notebook_id. dataset-rows = context->outputs.
          dataset-tables = context->tables. dataset-checkpoints = context->checkpoints.
          dataset-reads = context->reads. dataset-fixture_mode = context->fixture_mode.
          dataset-artifacts = context->artifacts. dataset-dataset_reads = context->dataset_reads.
          dataset-row_count = lines( dataset-rows ).
          IF dataset-artifacts IS NOT INITIAL.
            dataset-row_count = 0.
            LOOP AT dataset-artifacts INTO DATA(full_count). dataset-row_count = dataset-row_count + full_count-row_count. ENDLOOP.
          ELSE.
            LOOP AT dataset-tables INTO DATA(counted_table).
              dataset-row_count = dataset-row_count + counted_table-row_count.
            ENDLOOP.
          ENDIF.
          dataset-created_at = zcl_bn_types=>timestamp( ).
          dataset-schema = VALUE #( ( name = 'key' type = 'string' ) ( name = 'amount' type = 'decimal' ) ).
          GET TIME STAMP FIELD dataset-retention_until.
          dataset-retention_until = cl_abap_tstmp=>add( tstmp = dataset-retention_until secs = 2592000 ).
          dataset-fingerprint = fingerprint( notebook = full cell_id = cell-id ).
          LOOP AT cell-dependencies INTO DATA(dependency).
            READ TABLE run-bindings INTO DATA(binding) WITH KEY cell_id = dependency.
            IF sy-subrc = 0. APPEND binding TO dataset-bindings. ENDIF.
          ENDLOOP.
          persist_artifacts( notebook_id = run-notebook_id run_id = id cell = cell
            fingerprint = dataset-fingerprint packets = context->dataset_packets( ) ).
          zcl_bn_store=>write( kind = 'D' id = |{ id }:{ cell-id }| payload = zcl_bn_types=>json( dataset ) expected = 0 ).
          DELETE run-bindings WHERE cell_id = cell-id.
          APPEND VALUE #( cell_id = cell-id run_id = id revision = 1 ) TO run-bindings.
          APPEND VALUE #( cell_id = cell-id run_id = id revision = 1 row_count = dataset-row_count
            duration_ms = cl_abap_tstmp=>subtract( tstmp1 = stamp tstmp2 = cell_started ) * 1000
            checksum = zcl_bn_types=>hash( zcl_bn_types=>json( dataset ) ) created_at = dataset-created_at ) TO run-results.
          APPEND LINES OF context->messages TO run-messages. APPEND LINES OF context->checkpoints TO run-checkpoints.
          run-progress = lines( run-results ) / lines( run-snapshot-cells ).
          " A concurrent cancellation changes the head: retry state publication without losing it.
          rev = zcl_bn_store=>lock_run( id ).
          current = get_run( id ). run-cancel_requested = current-cancel_requested.
          IF current-state <> 'running'.
            ROLLBACK WORK. RETURN.
          ENDIF.
          zcl_bn_store=>write( kind = 'R' id = id payload = zcl_bn_types=>json( run )
            expected = rev ).
          COMMIT WORK AND WAIT.
        ENDLOOP.
        IF run-state = 'running'. run-state = 'succeeded'. ENDIF.
      CATCH zcx_bn INTO DATA(fault).
        ROLLBACK WORK.
        run-state = COND #( WHEN fault->code = 'CANCELLED' THEN 'cancelled' ELSE 'failed' ). run-error-code = fault->code. run-error-message = fault->detail.
      CATCH zcx_bn_engine INTO DATA(engine_error).
        ROLLBACK WORK.
        run-state = COND #( WHEN engine_error->code = 'CANCELLED' THEN 'cancelled' ELSE 'failed' ).
        run-error-code = engine_error->code. run-error-message = engine_error->detail.
      CATCH cx_root INTO DATA(error).
        ROLLBACK WORK.
        run-state = 'failed'. run-error-code = 'EXECUTION'. run-error-message = error->get_text( ).
    ENDTRY.
    IF context IS BOUND AND ( run-state = 'failed' OR run-state = 'cancelled' ).
      IF context->fixture_mode = abap_true. run-fixture_mode = abap_true. ENDIF.
      APPEND LINES OF context->checkpoints TO run-checkpoints.
      LOOP AT run-checkpoints ASSIGNING FIELD-SYMBOL(<failed_step>) WHERE state = 'running'.
        <failed_step>-state = run-state. <failed_step>-finished_at = zcl_bn_types=>timestamp( ).
      ENDLOOP.
      IF context->tables IS NOT INITIAL.
        run-checkpoint_cell = cell-id.
        DATA(partial) = VALUE ty_dataset( run_id = id cell_id = cell-id revision = 1 notebook_id = run-notebook_id
          tables = context->tables checkpoints = context->checkpoints
          reads = context->reads fixture_mode = context->fixture_mode created_at = zcl_bn_types=>timestamp( ) ).
        LOOP AT partial-checkpoints ASSIGNING FIELD-SYMBOL(<partial_step>) WHERE state = 'running'.
          <partial_step>-state = run-state. <partial_step>-finished_at = zcl_bn_types=>timestamp( ).
        ENDLOOP.
        zcl_bn_store=>write( kind = 'P' id = |{ id }:{ cell-id }| payload = zcl_bn_types=>json( partial ) expected = 0 ).
      ENDIF.
    ENDIF.
    GET TIME STAMP FIELD stamp.
    run-duration_ms = cl_abap_tstmp=>subtract( tstmp1 = stamp tstmp2 = started ) * 1000.
    run-finished_at = zcl_bn_types=>timestamp( ).
    rev = zcl_bn_store=>lock_run( id ).
    current = get_run( id ). run-cancel_requested = current-cancel_requested.
    IF current-state <> 'running'. ROLLBACK WORK. RETURN. ENDIF.
    IF run-state = 'succeeded' AND current-cancel_requested = abap_true. run-state = 'cancelled'. ENDIF.
    zcl_bn_store=>write( kind = 'R' id = id payload = zcl_bn_types=>json( run ) expected = rev ).
    COMMIT WORK AND WAIT.
  ENDMETHOD.
  METHOD organization.
    DATA revision TYPE i.
    revision = zcl_bn_store=>current( kind = 'O' id = CONV string( sy-uname ) ).
    IF revision = 0. RETURN. ENDIF.
    DATA(payload) = zcl_bn_store=>read( kind = 'O' id = CONV string( sy-uname ) ).
    /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( payload )
      pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = result ).
    " Deleted notebooks retain their history, but no longer need navigation membership.
    DATA(deleted) = zcl_bn_store=>heads( 'A' ).
    LOOP AT deleted INTO DATA(deleted_id).
      DELETE result-memberships WHERE notebook_id = deleted_id.
    ENDLOOP.
  ENDMETHOD.
  METHOD save_organization.
    authorize( '02' ).
    /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( zcl_bn_types=>request_json( body ) )
      pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = result ).
    DATA(previous) = organization( ).
    IF result-expected_revision <> previous-revision.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CONFLICT' detail = 'Folders changed; reload organization' status = 409.
    ENDIF.
    IF lines( result-folders ) > 200 OR lines( result-memberships ) > 10000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FOLDER_LIMIT' detail = 'Folder organization exceeds limits'.
    ENDIF.
    DATA ids TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA names TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT result-folders ASSIGNING FIELD-SYMBOL(<folder>).
      zcl_bn_types=>validate_text( <folder>-name ).
      FIND REGEX '^[A-Za-z0-9_-]{1,64}$' IN <folder>-id.
      IF sy-subrc <> 0 OR strlen( <folder>-name ) > 80 OR <folder>-name IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FOLDER' detail = 'Folder requires a valid ID and name (1-80 characters)'.
      ENDIF.
      FIND REGEX '[[:cntrl:]]' IN <folder>-name.
      IF sy-subrc = 0.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FOLDER' detail = 'Folder name cannot contain line breaks or controls'.
      ENDIF.
      DATA(trimmed_name) = <folder>-name.
      CONDENSE trimmed_name.
      IF trimmed_name IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FOLDER' detail = 'Folder name cannot be blank'.
      ENDIF.
      INSERT <folder>-id INTO TABLE ids.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FOLDER' detail = 'Duplicate folder ID'.
      ENDIF.
      INSERT to_upper( trimmed_name ) INTO TABLE names.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FOLDER' detail = 'Duplicate folder name'.
      ENDIF.
    ENDLOOP.
    LOOP AT previous-folders INTO DATA(old_folder).
      IF NOT line_exists( ids[ table_line = old_folder-id ] ) AND
          line_exists( previous-memberships[ folder_id = old_folder-id ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FOLDER_NOT_EMPTY' detail = 'Move notebooks out before removing a folder' status = 409.
      ENDIF.
    ENDLOOP.
    CLEAR ids.
    LOOP AT result-memberships INTO DATA(membership).
      IF NOT line_exists( result-folders[ id = membership-folder_id ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FOLDER' detail = 'Unknown folder'.
      ENDIF.
      INSERT membership-notebook_id INTO TABLE ids.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FOLDER' detail = 'Notebook can belong to only one folder'.
      ENDIF.
      " Owner/deletion and current BPC context authorization are enforced on the server.
      DATA(member_notebook) = get_notebook( membership-notebook_id ).
      IF member_notebook-environment IS NOT INITIAL AND member_notebook-model IS NOT INITIAL.
        DATA(adapter) = NEW zcl_bn_bpc( environment = member_notebook-environment model = member_notebook-model ).
      ENDIF.
    ENDLOOP.
    result-revision = previous-revision + 1. CLEAR result-expected_revision.
    zcl_bn_store=>write( kind = 'O' id = CONV string( sy-uname ) payload = zcl_bn_types=>json( result )
      expected = previous-revision ).
  ENDMETHOD.
  METHOD dispatch.
    CLEAR: mv_cached_notebook, mt_latest.
    authorize( '03' ).
    DATA request TYPE ty_request.
    IF body IS NOT INITIAL.
      /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( zcl_bn_types=>request_json( body ) ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = request ).
    ENDIF.
    DATA notebook TYPE zcl_bn_types=>ty_notebook.
    DATA run TYPE zcl_bn_types=>ty_run.
    CASE |{ method } { path }|.
      WHEN 'GET /folders'.
        json = zcl_bn_types=>json( organization( ) ).
      WHEN 'PUT /folders'.
        json = zcl_bn_types=>json( save_organization( body ) ).
      WHEN 'POST /logic-handler'.
        json = zcl_bn_types=>json( zcl_bn_logic=>register( name = request-handler notebook_id = request-notebook_id
          notebook_revision = request-expected_revision expected = request-handler_revision
          execution_mode = COND #( WHEN request-execution_mode IS INITIAL THEN 'preview' ELSE request-execution_mode ) ) ).
      WHEN 'GET /logic-handler'.
        json = zcl_bn_types=>json( zcl_bn_logic=>binding( id ) ).
      WHEN 'POST /metadata'.
        json = zcl_bn_types=>json( zcl_bn_bpc=>metadata( kind = request-kind environment = request-environment
          model = request-model dimension = request-dimension hierarchy = request-hierarchy
          search = request-search offset = request-offset ) ).
      WHEN 'POST /delete-notebook'.
        delete_notebook( id = request-notebook_id expected = request-expected_revision ).
        json = '{"deleted":true}'.
      WHEN 'GET /notebooks'.
        DATA notebooks TYPE tt_notebook_headers.
        DATA(deleted) = zcl_bn_store=>heads( 'A' ).
        LOOP AT zcl_bn_store=>documents( 'N' ) INTO DATA(document).
          IF line_exists( deleted[ table_line = document-id ] ). CONTINUE. ENDIF.
          DATA listing TYPE ty_notebook_header.
          CLEAR listing.
          /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( document-payload ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = listing ).
          APPEND listing TO notebooks.
        ENDLOOP.
        SORT notebooks BY saved_at DESCENDING id.
        json = zcl_bn_types=>json( notebooks ).
      WHEN 'POST /notebooks'.
        IF request-demo = abap_true. request = demo( environment = request-environment model = request-model ). ENDIF.
        CLEAR: request-id, request-expected_revision.
        json = zcl_bn_types=>json( save( request ) ).
      WHEN 'PUT /notebook'.
        json = zcl_bn_types=>json( save( request ) ).
      WHEN 'GET /notebook'.
        notebook = get_notebook( id ).
        LOOP AT notebook-cells ASSIGNING FIELD-SYMBOL(<cell>).
          DATA(dataset) = latest( notebook = notebook cell_id = <cell>-id ).
          IF dataset-run_id IS NOT INITIAL.
            <cell>-output = VALUE #( run_id = dataset-run_id cell_id = <cell>-id revision = 1
              row_count = dataset-row_count stale = xsdbool( is_current( notebook = notebook dataset = dataset ) = abap_false ) ).
          ENDIF.
        ENDLOOP.
        json = zcl_bn_types=>json( notebook ).
      WHEN 'GET /versions'.
        DATA versions TYPE zcl_bn_types=>tt_notebooks.
        DO zcl_bn_store=>current( kind = 'N' id = id ) TIMES.
          DATA(payload) = zcl_bn_store=>read( kind = 'N' id = id revision = sy-index ).
          CLEAR notebook.
          /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( payload ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = notebook ).
          APPEND notebook TO versions.
        ENDDO.
        json = zcl_bn_types=>json( versions ).
      WHEN 'POST /validate'.
        authorize( '16' ).
        notebook = get_notebook( request-notebook_id ).
        READ TABLE notebook-cells INTO DATA(cell) WITH KEY id = request-cell_id.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CELL' detail = 'Cell missing'.
        ENDIF.
        TYPES: BEGIN OF ty_validation,
                 native TYPE abap_bool, supported TYPE abap_bool,
                 diagnostics TYPE zcl_bn_types=>tt_diagnostics,
               END OF ty_validation.
        DATA validation TYPE ty_validation.
        DATA pool TYPE progname.
        zcl_bn_compiler=>compile( EXPORTING source = cell-source IMPORTING pool = pool diagnostics = validation-diagnostics ).
        validation-native = abap_true. validation-supported = xsdbool( pool IS NOT INITIAL ).
        json = zcl_bn_types=>json( validation ).
      WHEN 'POST /runs'. json = zcl_bn_types=>json( submit( request ) ).
      WHEN 'POST /retry'.
        run = get_run( request-id ).
        IF run-scope = 'logic'.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_RETRY'
            detail = 'Invoke the handler again from Script Logic to preserve its current view and transaction'.
        ENDIF.
        IF run-state = 'queued' OR run-state = 'running'.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RETRY_ACTIVE' detail = 'Wait for the original run to finish' status = 409.
        ENDIF.
        request-retry_run_id = run-id. request-notebook_id = run-notebook_id.
        request-expected_revision = run-snapshot-revision. request-scope = run-scope.
        request-cell_id = run-snapshot-cells[ lines( run-snapshot-cells ) ]-id.
        json = zcl_bn_types=>json( submit( request ) ).
      WHEN 'GET /runs'.
        notebook = get_notebook( notebook_id ).
        DATA(runs) = run_headers( notebook_id ).
        LOOP AT runs ASSIGNING FIELD-SYMBOL(<header>) WHERE state = 'queued' OR state = 'running'.
          run = get_run( <header>-id ). reconcile( CHANGING run = run ).
          <header>-state = run-state. <header>-finished_at = run-finished_at.
        ENDLOOP.
        json = zcl_bn_types=>json( runs ).
      WHEN 'GET /run'.
        run = get_run( id ). reconcile( CHANGING run = run ). json = zcl_bn_types=>json( run ).
      WHEN 'POST /cancel'.
        authorize( '16' ).
        DATA(cancel_revision) = zcl_bn_store=>lock_run( request-id ).
        run = get_run( request-id ).
        IF run-state = 'queued' OR run-state = 'running'.
          run-cancel_requested = abap_true.
          zcl_bn_store=>write( kind = 'R' id = run-id payload = zcl_bn_types=>json( run )
            expected = cancel_revision ).
        ENDIF.
        json = zcl_bn_types=>json( run ).
      WHEN 'GET /datasets'.
        run = get_run( run_id ).
        READ TABLE run-results TRANSPORTING NO FIELDS WITH KEY cell_id = cell_id.
        IF sy-subrc <> 0 OR revision <> 1.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_BINDING' detail = 'Choose a completed cell result'.
        ENDIF.
        DATA(header_json) = zcl_bn_store=>read( kind = 'D' id = |{ run_id }:{ cell_id }| revision = revision ).
        DATA native_headers TYPE ty_dataset.
        /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( header_json ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = native_headers ).
        IF native_headers-notebook_id <> run-notebook_id OR native_headers-run_id <> run_id OR native_headers-cell_id <> cell_id OR native_headers-revision <> revision.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_INTEGRITY' detail = 'Dataset metadata does not match the completed result'.
        ENDIF.
        TYPES: BEGIN OF ty_dataset_info,
                 artifacts TYPE zcl_bn_dataset=>tt_headers, reads TYPE zcl_bn_dataset=>tt_access,
               END OF ty_dataset_info.
        json = zcl_bn_types=>json( VALUE ty_dataset_info( artifacts = native_headers-artifacts reads = native_headers-dataset_reads ) ).
      WHEN 'GET /output'.
        run = get_run( run_id ).
        IF revision <> 1 OR offset < 0 OR page_size < 1 OR page_size > 100.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PAGE' detail = 'Revision must be 1; nonnegative offset; page size 1 to 100' status = 409.
        ENDIF.
        DATA output_json TYPE string.
        DATA partial_preview TYPE abap_bool.
        IF zcl_bn_store=>current( kind = 'D' id = |{ run_id }:{ cell_id }| ) = 0 AND
           run-checkpoint_cell = cell_id AND ( run-state = 'failed' OR run-state = 'cancelled' ).
          output_json = zcl_bn_store=>read( kind = 'P' id = |{ run_id }:{ cell_id }| revision = revision ).
          partial_preview = abap_true.
        ELSE.
          output_json = zcl_bn_store=>read( kind = 'D' id = |{ run_id }:{ cell_id }| revision = revision ).
        ENDIF.
        CLEAR dataset.
        /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( output_json ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = dataset ).
        IF dataset-tables IS NOT INITIAL.
          DATA selected_table TYPE zcl_bn_context=>ty_table.
          IF table_name IS INITIAL.
            selected_table = dataset-tables[ 1 ].
            LOOP AT dataset-tables INTO DATA(preferred_table).
              IF preferred_table-name NP 'READ_*/SUMMARY' AND preferred_table-name NP 'READ_*/FILTERS_AND_PERIODS'.
                selected_table = preferred_table. EXIT.
              ENDIF.
            ENDLOOP.
          ELSE.
            READ TABLE dataset-tables INTO selected_table WITH KEY name = table_name.
            IF sy-subrc <> 0.
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TABLE_NAME' detail = 'Unknown output table'.
            ENDIF.
          ENDIF.
          TYPES: BEGIN OF ty_table_info,
                   name TYPE string, row_count TYPE i, total_count TYPE i,
                   truncated TYPE abap_bool, elapsed_us TYPE i,
                 END OF ty_table_info,
                 tt_table_info TYPE STANDARD TABLE OF ty_table_info WITH DEFAULT KEY,
                 BEGIN OF ty_table_page,
                   run_id TYPE string, cell_id TYPE string, revision TYPE i,
                   total TYPE i, source_total TYPE i, offset TYPE i, limit TYPE i,
                   truncated TYPE abap_bool, table_name TYPE string,
                   tables TYPE tt_table_info, partial TYPE abap_bool, checkpoints TYPE zcl_bn_types=>tt_checkpoints,
                   schema TYPE zcl_bn_context=>tt_schema,
                   rows TYPE zcl_bn_context=>tt_table_rows,
                 END OF ty_table_page.
          DATA(table_page) = VALUE ty_table_page(
            run_id = run_id cell_id = cell_id revision = revision offset = offset limit = page_size
            partial = partial_preview checkpoints = dataset-checkpoints
            total = selected_table-row_count source_total = selected_table-total_count
            truncated = selected_table-truncated table_name = selected_table-name schema = selected_table-schema ).
          LOOP AT dataset-tables INTO DATA(output_table).
            APPEND CORRESPONDING #( output_table ) TO table_page-tables.
          ENDLOOP.
          LOOP AT selected_table-rows INTO DATA(table_row) FROM offset + 1 TO offset + page_size.
            APPEND table_row TO table_page-rows.
          ENDLOOP.
          json = zcl_bn_types=>json( table_page ).
          RETURN.
        ENDIF.
        TYPES: BEGIN OF ty_page,
                 run_id TYPE string, cell_id TYPE string, revision TYPE i,
                 total TYPE i, offset TYPE i, limit TYPE i,
                 schema TYPE tt_schema,
                 rows TYPE zcl_bn_context=>tt_rows,
               END OF ty_page.
        DATA page TYPE ty_page.
        page-run_id = run_id. page-cell_id = cell_id. page-revision = revision.
        page-total = dataset-row_count. page-offset = offset. page-limit = page_size.
        page-schema = dataset-schema.
        LOOP AT dataset-rows INTO DATA(row) FROM offset + 1 TO offset + page_size.
          APPEND row TO page-rows.
        ENDLOOP.
        json = zcl_bn_types=>json( page ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'ROUTE' detail = 'Unknown endpoint or method' status = 404.
    ENDCASE.
  ENDMETHOD.
  METHOD demo.
    DATA nl TYPE string VALUE cl_abap_char_utilities=>newline.
    request-title = 'Allocation - operating expenses'.
    request-environment = environment. request-model = model.
    request-inputs = VALUE #( ( name = 'total' type = 'number' value = '120000' ) ( name = 'factor' type = 'number' value = '1.1' ) ).
    IF environment IS NOT INITIAL AND model IS NOT INITIAL.
      DATA(dimensions) = zcl_bn_bpc=>metadata( kind = 'dimensions' environment = environment model = model
        dimension = '' hierarchy = '' search = '' ).
      READ TABLE dimensions-items INTO DATA(category_dim) WITH KEY dim_type = 'C'.
      READ TABLE dimensions-items INTO DATA(time_dim) WITH KEY dim_type = 'T'.
      IF category_dim-id IS INITIAL OR time_dim-id IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_DIMENSION' detail = 'Allocation example requires category and time dimensions'.
      ENDIF.
      DATA(times) = zcl_bn_bpc=>metadata( kind = 'members' environment = environment model = model
        dimension = time_dim-id hierarchy = '' search = '' ).
      DATA hierarchy TYPE string.
      IF times-hierarchies IS NOT INITIAL. hierarchy = times-hierarchies[ 1 ]. ENDIF.
      APPEND VALUE #( name = 'CATEGORY' type = 'member' dimension = category_dim-id required = abap_true ) TO request-inputs.
      APPEND VALUE #( name = 'TIME' type = 'range' dimension = time_dim-id hierarchy = hierarchy required = abap_true ) TO request-inputs.
      APPEND VALUE #( name = 'suppressZero' type = 'boolean' value = 'true' ) TO request-inputs.
    ENDIF.
    APPEND VALUE #( id = 'seed' title = '01 - Prepare cost centres' source =
      |DATA rows TYPE zcl_bn_context=>tt_rows.{ nl }DATA total TYPE decfloat34.{ nl }total = io->input( 'total' ).{ nl }| &&
      |APPEND VALUE #( key = 'CC100' amount = total * '0.5' ) TO rows.{ nl }| &&
      |APPEND VALUE #( key = 'CC200' amount = total * '0.3' ) TO rows.{ nl }| &&
      |APPEND VALUE #( key = 'CC300' amount = total * '0.2' ) TO rows.{ nl }io->emit( rows ).{ nl }| &&
      |io->message( 'Prepared three cost centres' ).| ) TO request-cells.
    APPEND VALUE #( id = 'allocate' title = '02 - Apply planning factor' dependencies = VALUE #( ( `seed` ) ) source =
      |DATA rows TYPE zcl_bn_context=>tt_rows.{ nl }DATA factor TYPE decfloat34.{ nl }rows = io->read( 'seed' ).{ nl }| &&
      |factor = io->input( 'factor' ).{ nl }LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).{ nl }| &&
      |  <row>-amount = <row>-amount * factor.{ nl }ENDLOOP.{ nl }io->emit( rows ).{ nl }io->message( 'Planning factor applied' ).| ) TO request-cells.
    IF environment IS NOT INITIAL.
      LOOP AT request-cells ASSIGNING FIELD-SYMBOL(<cell>).
        <cell>-source = |DATA category TYPE uj_dim_member.{ nl }category = io->member( 'CATEGORY' ).{ nl }| &&
          |DATA periods TYPE uja_t_dim_member.{ nl }periods = io->range( 'TIME' ).{ nl }| &&
          |DATA cv TYPE ujk_t_cv.{ nl }cv = io->current_view( ).{ nl }| &&
          |DATA params TYPE ujk_t_script_logic_hashtable.{ nl }params = io->script_parameters( ).{ nl }| &&
          |io->message( category && ': ' && CONV string( lines( periods ) ) && ' frozen periods' ).{ nl }| && <cell>-source.
        <cell>-source = <cell>-source && |{ nl }IF io->input( 'suppressZero' ) = 'true'.{ nl }| &&
          |DELETE rows WHERE amount = 0.{ nl }io->emit( rows ).{ nl }ENDIF.|.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
ENDCLASS.




