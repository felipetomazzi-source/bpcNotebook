CLASS ltcl_probe DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS dialog_success FOR TESTING.
    METHODS syntax_failure FOR TESTING.
ENDCLASS.
CLASS ltcl_probe IMPLEMENTATION.
  METHOD dialog_success.
    cl_abap_unit_assert=>assert_equals( act = zcl_bn_probe=>compile( ) exp = 42 ).
  ENDMETHOD.
  METHOD syntax_failure.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_bn_probe=>compile( bad = abap_true ) exp = -4 ).
  ENDMETHOD.
ENDCLASS.
CLASS ltcl_background DEFINITION FINAL FOR TESTING
  DURATION MEDIUM RISK LEVEL DANGEROUS.
  PRIVATE SECTION.
    METHODS background_success FOR TESTING RAISING cx_uuid_error.
ENDCLASS.
CLASS ltcl_background IMPLEMENTATION.
  METHOD background_success.
    DATA key TYPE char22.
    DATA jobname TYPE btcjob VALUE 'ZBN_COMPILATION_PROBE'.
    DATA jobcount TYPE btcjobcnt.
    DATA result TYPE i.
    key = cl_system_uuid=>create_uuid_c22_static( ).
    CALL FUNCTION 'JOB_OPEN' EXPORTING jobname = jobname
      IMPORTING jobcount = jobcount EXCEPTIONS OTHERS = 1.
    cl_abap_unit_assert=>assert_subrc( ).
    SUBMIT zbn_probe_job WITH p_key = key VIA JOB jobname
      NUMBER jobcount AND RETURN.
    cl_abap_unit_assert=>assert_subrc( ).
    CALL FUNCTION 'JOB_CLOSE' EXPORTING jobname = jobname jobcount = jobcount
      strtimmed = abap_true EXCEPTIONS OTHERS = 1.
    cl_abap_unit_assert=>assert_subrc( ).
    DO 45 TIMES.
      WAIT UP TO 1 SECONDS.
      IMPORT result = result FROM DATABASE indx(zn) ID key.
      IF sy-subrc = 0.
        EXIT.
      ENDIF.
    ENDDO.
    DELETE FROM DATABASE indx(zn) ID key.
    COMMIT WORK.
    cl_abap_unit_assert=>assert_equals( act = result exp = 42 ).
  ENDMETHOD.
ENDCLASS.
