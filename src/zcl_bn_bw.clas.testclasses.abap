CLASS ltc_bw DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS invalid_request FOR TESTING.
    METHODS fixture_guard FOR TESTING.
    METHODS direct_fixture_guard FOR TESTING.
    METHODS denied_read FOR TESTING.
    METHODS partial_read FOR TESTING.
    METHODS overflow FOR TESTING.
    METHODS exact_limit FOR TESTING RAISING zcx_bn.
    METHODS invalid_fields FOR TESTING.
    METHODS invalid_filter FOR TESTING.
    METHODS split_read FOR TESTING.
    METHODS empty_read FOR TESTING RAISING zcx_bn.
    METHODS logic_guard FOR TESTING.
    METHODS context RETURNING VALUE(io) TYPE REF TO zcl_bn_context.
    METHODS read RETURNING VALUE(rows) TYPE REF TO data RAISING zcx_bn.
ENDCLASS.
CLASS ltc_bw IMPLEMENTATION.
  METHOD context.
    io = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'TEST' ).
  ENDMETHOD.
  METHOD read.
    rows = zcl_bn_bw=>read_data( io = context( ) provider = 'ZTEST'
      fields = VALUE #( ( infoobject = '0CLIENT' alias = 'CLIENT' ddic_type = 'MANDT' kind = 'characteristic' ) )
      filters = VALUE #( ) max_rows = 1 ).
  ENDMETHOD.
  METHOD direct_fixture_guard.
    DATA(io) = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( )
      dependencies = VALUE #( ) cell_id = 'TEST' fixture_required = abap_true ).
    TRY.
        DATA(rows) = zcl_bn_bw=>read_data( io = io provider = 'ZTEST'
          fields = VALUE #( ) filters = VALUE #( ) max_rows = 1 ).
        cl_abap_unit_assert=>fail( 'Direct adapter call must preserve fixture guard' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BW_CONTEXT' ).
    ENDTRY.
  ENDMETHOD.
  METHOD denied_read.
    TEST-INJECTION bw_read.
      sy-subrc = 1.
    END-TEST-INJECTION.
    TRY.
        DATA(rows) = read( ).
        cl_abap_unit_assert=>fail( 'SAP failure must not return data' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BW_READ' ).
    ENDTRY.
  ENDMETHOD.
  METHOD partial_read.
    TEST-INJECTION bw_read.
      APPEND INITIAL LINE TO <rows>.
      ended = abap_false. sy-subrc = 0.
    END-TEST-INJECTION.
    TRY.
        DATA(rows) = read( ).
        cl_abap_unit_assert=>fail( 'An unfinished package must fail even below the limit' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BW_LIMIT' ).
    ENDTRY.
  ENDMETHOD.
  METHOD overflow.
    TEST-INJECTION bw_read.
      APPEND INITIAL LINE TO <rows>. APPEND INITIAL LINE TO <rows>.
      ended = abap_true. sy-subrc = 0.
    END-TEST-INJECTION.
    TRY.
        DATA(rows) = read( ).
        cl_abap_unit_assert=>fail( 'Overflow must fail even with end-of-data' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BW_LIMIT' ).
    ENDTRY.
  ENDMETHOD.
  METHOD exact_limit.
    TEST-INJECTION bw_read.
      cl_abap_unit_assert=>assert_equals( act = fetch_limit exp = 2 ).
      APPEND INITIAL LINE TO <rows>.
      ended = abap_true. sy-subrc = 0.
    END-TEST-INJECTION.
    DATA(rows) = read( ).
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN rows->* TO <rows>.
    cl_abap_unit_assert=>assert_equals( act = lines( <rows> ) exp = 1 ).
  ENDMETHOD.
  METHOD invalid_fields.
    TRY.
        DATA(rows) = zcl_bn_bw=>read_data( io = context( ) provider = 'ZTEST'
          fields = VALUE #( ( infoobject = '0CLIENT;SELECT' alias = 'CLIENT' ddic_type = 'MANDT' kind = 'characteristic' ) )
          filters = VALUE #( ) max_rows = 1 ).
        cl_abap_unit_assert=>fail( 'Invalid identifiers must fail before SAP' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BW_FIELDS' ).
    ENDTRY.
  ENDMETHOD.
  METHOD invalid_filter.
    TRY.
        DATA(rows) = zcl_bn_bw=>read_data( io = context( ) provider = 'ZTEST'
          fields = VALUE #( ( infoobject = '0CLIENT' alias = 'CLIENT' ddic_type = 'MANDT' kind = 'characteristic' ) )
          filters = VALUE #( ( dimension = '0CLIENT' ) ) max_rows = 1 ).
        cl_abap_unit_assert=>fail( 'An empty filter cannot become unrestricted' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BW_FILTER' ).
    ENDTRY.
  ENDMETHOD.
  METHOD split_read.
    TEST-INJECTION bw_read.
      ended = abap_true. split_occurred = 'X'. sy-subrc = 0.
    END-TEST-INJECTION.
    TRY.
        DATA(rows) = read( ).
        cl_abap_unit_assert=>fail( 'Split aggregation cannot be used as complete data' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BW_LIMIT' ).
    ENDTRY.
  ENDMETHOD.
  METHOD empty_read.
    TEST-INJECTION bw_read.
      ended = abap_true. sy-subrc = 0.
    END-TEST-INJECTION.
    DATA(rows) = read( ).
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN rows->* TO <rows>.
    cl_abap_unit_assert=>assert_equals( act = lines( <rows> ) exp = 0 ).
  ENDMETHOD.
  METHOD logic_guard.
    DATA(io) = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( )
      dependencies = VALUE #( ) cell_id = 'TEST' logic_call = abap_true ).
    TRY.
        DATA(rows) = zcl_bn_bw=>read_data( io = io provider = 'ZTEST'
          fields = VALUE #( ) filters = VALUE #( ) max_rows = 1 ).
        cl_abap_unit_assert=>fail( 'Direct adapter call must preserve Script Logic scope' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BW_CONTEXT' ).
    ENDTRY.
  ENDMETHOD.
  METHOD invalid_request.
    TRY.
        DATA(rows) = zcl_bn_bw=>read_data( io = VALUE #( ) provider = 'ZTEST'
          fields = VALUE #( ) filters = VALUE #( ) max_rows = 100001 ).
        cl_abap_unit_assert=>fail( 'Invalid request must fail before SAP read' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BW_REQUEST' ).
    ENDTRY.
  ENDMETHOD.
  METHOD fixture_guard.
    DATA(io) = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( )
      dependencies = VALUE #( ) cell_id = 'TEST' fixture_required = abap_true ).
    TRY.
        DATA(rows) = io->bw_data( provider = 'ZTEST' fields = VALUE #( ) filters = VALUE #( ) max_rows = 1 ).
        cl_abap_unit_assert=>fail( 'Fixture runs must not read live BW' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BW_CONTEXT' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
