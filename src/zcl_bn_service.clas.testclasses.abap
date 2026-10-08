CLASS ltcl_integration DEFINITION FINAL FOR TESTING
  DURATION LONG RISK LEVEL DANGEROUS.
  PRIVATE SECTION.
    METHODS frozen_background_dataset FOR TESTING RAISING zcx_bn.
ENDCLASS.
CLASS ltcl_integration IMPLEMENTATION.
  METHOD frozen_background_dataset.
    " Requires trusted DEV enablement and SAUNIT_CLIENT_SETUP allowing dangerous tests.
    " Leaves immutable notebook/run records for inspection; no business-data writes.
    DATA notebook TYPE zcl_bn_types=>ty_notebook.
    DATA(json) = zcl_bn_service=>dispatch( path = '/notebooks' method = 'POST' body = '{"demo":true}' ).
    /ui2/cl_json=>deserialize( EXPORTING json = json pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = notebook ).
    COMMIT WORK AND WAIT.
    SELECT COUNT( * ) FROM zbn_src INTO @DATA(source_count) WHERE notebook_id = @notebook-id.
    cl_abap_unit_assert=>assert_equals( act = source_count exp = 2 ).
    TYPES: BEGIN OF ty_submit,
             notebook_id TYPE string, expected_revision TYPE i,
             scope TYPE string, idempotency_key TYPE string,
           END OF ty_submit.
    DATA request TYPE ty_submit.
    request-notebook_id = notebook-id. request-expected_revision = 1. request-scope = 'all'.
    request-idempotency_key = zcl_bn_types=>uuid( ).
    json = zcl_bn_service=>dispatch( path = '/runs' method = 'POST' body = zcl_bn_types=>json( request ) ).
    DATA run TYPE zcl_bn_types=>ty_run.
    /ui2/cl_json=>deserialize( EXPORTING json = json pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = run ).
    cl_abap_unit_assert=>assert_not_initial( run-job_id ).
    DO 60 TIMES.
      WAIT UP TO 1 SECONDS.
      json = zcl_bn_service=>dispatch( path = '/run' method = 'GET' body = '' id = run-id ).
      /ui2/cl_json=>deserialize( EXPORTING json = json pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = run ).
      COMMIT WORK AND WAIT.
      IF run-state <> 'queued' AND run-state <> 'running'. EXIT. ENDIF.
    ENDDO.
    cl_abap_unit_assert=>assert_equals( act = run-state exp = 'succeeded' msg = run-error-message ).
    cl_abap_unit_assert=>assert_equals( act = lines( run-results ) exp = 2 ).
    json = zcl_bn_service=>dispatch( path = '/output' method = 'GET' body = '' run_id = run-id
      cell_id = 'allocate' revision = 1 offset = 0 page_size = 2 ).
    TYPES: BEGIN OF ty_page,
             total TYPE i, rows TYPE zcl_bn_context=>tt_rows,
           END OF ty_page.
    DATA page TYPE ty_page.
    /ui2/cl_json=>deserialize( EXPORTING json = json CHANGING data = page ).
    cl_abap_unit_assert=>assert_equals( act = page-total exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lines( page-rows ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = page-rows[ 1 ]-amount exp = 66000 ).
    TYPES: BEGIN OF ty_save,
             id TYPE string, title TYPE string, expected_revision TYPE i,
             cells TYPE zcl_bn_types=>tt_cells, inputs TYPE zcl_bn_types=>tt_inputs,
           END OF ty_save.
    DATA edit TYPE ty_save.
    edit-id = notebook-id. edit-title = notebook-title. edit-expected_revision = 1.
    edit-cells = notebook-cells. edit-inputs = notebook-inputs.
    edit-inputs[ 1 ]-value = '10'.
    json = zcl_bn_service=>dispatch( path = '/notebook' method = 'PUT' body = zcl_bn_types=>json( edit ) ).
    COMMIT WORK AND WAIT.
    json = zcl_bn_service=>dispatch( path = '/notebook' method = 'GET' body = '' id = notebook-id ).
    /ui2/cl_json=>deserialize( EXPORTING json = json pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = notebook ).
    cl_abap_unit_assert=>assert_true( notebook-cells[ 2 ]-output-stale ).
    run = zcl_bn_service=>get_run( run-id ).
    cl_abap_unit_assert=>assert_equals( act = run-snapshot-inputs[ 1 ]-value exp = '120000' ).
  ENDMETHOD.
ENDCLASS.
