CLASS ltcl_inputs DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS filter_intersection FOR TESTING RAISING zcx_bn.
    METHODS adapters FOR TESTING RAISING zcx_bn.
    METHODS typed_access FOR TESTING RAISING zcx_bn.
    METHODS named_tables FOR TESTING RAISING zcx_bn.
    METHODS logic_scope FOR TESTING RAISING zcx_bn.
    METHODS live_dependencies FOR TESTING RAISING zcx_bn.
ENDCLASS.
CLASS ltcl_inputs IMPLEMENTATION.
  METHOD filter_intersection.
    DATA frozen TYPE zcl_bn_bpc=>tt_filters.
    frozen = VALUE #( ( dimension = 'TIME' members = VALUE #( ( `P_A` ) ( `P_B` ) ) )
      ( dimension = 'CATEGORY' members = VALUE #( ( `Actual` ) ) ) ).
    DATA(requested) = VALUE zcl_bn_bpc=>tt_filters(
      ( dimension = 'TIME' members = VALUE #( ( `P_B` ) ( `P_C` ) ) )
      ( dimension = 'ENTITY' members = VALUE #( ( `E_1` ) ( `E_1` ) ) ) ).
    DATA(result) = zcl_bn_bpc=>merge_filters( frozen = frozen requested = requested ).
    cl_abap_unit_assert=>assert_equals( act = result[ dimension = 'TIME' ]-members exp = VALUE zcl_bn_types=>tt_ids( ( `P_B` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = result[ dimension = 'CATEGORY' ]-members exp = frozen[ 2 ]-members ).
    cl_abap_unit_assert=>assert_equals( act = lines( result[ dimension = 'ENTITY' ]-members ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( frozen[ 1 ]-members ) exp = 2 ).
    TRY.
        zcl_bn_bpc=>merge_filters( frozen = frozen requested = VALUE #( ( dimension = 'TIME' members = VALUE #( ( `OTHER` ) ) ) ) ).
        cl_abap_unit_assert=>fail( 'Conflicting filters must not broaden a frozen selection' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BPC_FILTER' ).
    ENDTRY.
    TRY.
        zcl_bn_bpc=>merge_filters( frozen = frozen requested = VALUE #( ( dimension = 'ENTITY' ) ) ).
        cl_abap_unit_assert=>fail( 'Empty member filters must not become unrestricted reads' ).
      CATCH zcx_bn INTO error.
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'BPC_FILTER' ).
    ENDTRY.
  ENDMETHOD.
  METHOD adapters.
    DATA inputs TYPE zcl_bn_types=>tt_inputs.
    inputs = VALUE #( ( name = 'TIME' type = 'range' dimension = 'TIME'
      selected = VALUE #( ( `FiscalNode` ) ) resolved = VALUE #( ( `P_03` ) ( `P_01` ) ) )
      ( name = 'extra' type = 'member' dimension = 'TIME' selected = VALUE #( ( `P_01` ) )
        resolved = VALUE #( ( `P_01` ) ) )
      ( name = 'suppressZero' type = 'boolean' value = 'false' ) ).
    DATA(cv) = zcl_bn_bpc=>current_view( inputs ).
    cl_abap_unit_assert=>assert_equals( act = lines( cv ) exp = 1 ).
    DATA(entry) = cv[ dim_upper_case = 'TIME' ].
    cl_abap_unit_assert=>assert_equals( act = lines( entry-member ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = entry-member[ 1 ] exp = 'P_01' ).
    DATA(params) = zcl_bn_bpc=>script_parameters( inputs ).
    cl_abap_unit_assert=>assert_equals( act = params[ hashkey = 'TIME' ]-hashvalue exp = 'P_03,P_01' ).
    cl_abap_unit_assert=>assert_equals( act = params[ hashkey = 'suppressZero' ]-hashvalue exp = 'false' ).
  ENDMETHOD.
  METHOD named_tables.
    DATA(io) = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'test' ).
    TYPES: BEGIN OF ty_record,
             account TYPE uj_dim_member, signeddata TYPE decfloat34,
           END OF ty_record,
           tt_records TYPE STANDARD TABLE OF ty_record WITH DEFAULT KEY.
    DATA rows TYPE tt_records.
    rows = VALUE #( ( account = '001081800' signeddata = '0.1234567890123456789' ) ).
    io->emit_table( name = 'RATIOS' rows = rows total_count = 15 ).
    rows[ 1 ]-account = 'CHANGED'.
    DATA(saved) = io->tables[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = saved-total_count exp = 15 ).
    cl_abap_unit_assert=>assert_equals( act = saved-row_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = saved-truncated exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = saved-schema[ 1 ]-name exp = 'account' ).
    cl_abap_unit_assert=>assert_equals( act = saved-rows[ 1 ]-values[ 1 ] exp = '001081800' ).
    DATA(number) = CONV decfloat34( saved-rows[ 1 ]-values[ 2 ] ).
    cl_abap_unit_assert=>assert_equals( act = number exp = CONV decfloat34( '0.1234567890123456789' ) ).
    TRY.
        io->emit_table( name = 'RATIOS' rows = rows ).
        cl_abap_unit_assert=>fail( 'Duplicate table names must fail' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'TABLE_NAME' ).
    ENDTRY.
    CLEAR rows.
    io->emit_table( name = 'EMPTY' rows = rows ).
    cl_abap_unit_assert=>assert_equals( act = lines( io->tables[ 2 ]-schema ) exp = 2 ).
  ENDMETHOD.
  METHOD logic_scope.
    DATA inputs TYPE zcl_bn_types=>tt_inputs.
    inputs = VALUE #( ( name = 'TIME' type = 'range' dimension = 'TIME'
      resolved = VALUE #( ( `P_A` ) ( `P_B` ) ) ) ).
    DATA scope TYPE ujk_t_cv.
    scope = VALUE #( ( dimension = 'TIME' dim_upper_case = 'TIME' member = VALUE #( ( 'P_B' ) ) )
      ( dimension = 'ENTITY' member = VALUE #( ( 'E1' ) ) ) ).
    DATA(result) = zcl_bn_bpc=>scoped_view( inputs = inputs scope = scope ).
    cl_abap_unit_assert=>assert_equals( act = lines( result ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( result[ dimension = 'TIME' ]-member ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result[ dimension = 'TIME' ]-member[ 1 ] exp = 'P_B' ).
    cl_abap_unit_assert=>assert_equals( act = result[ dimension = 'ENTITY' ]-member[ 1 ] exp = 'E1' ).
    scope[ dimension = 'TIME' ]-member = VALUE #( ( 'OTHER' ) ).
    TRY.
        zcl_bn_bpc=>scoped_view( inputs = inputs scope = scope ).
        cl_abap_unit_assert=>fail( 'A disjoint caller scope must fail' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'LOGIC_CV' ).
    ENDTRY.
  ENDMETHOD.
  METHOD live_dependencies.
    DATA live TYPE zcl_bn_context=>tt_live_outputs.
    live = VALUE #( ( cell_id = 'seed' rows = VALUE #( ( key = 'É · São' amount = 2 ) ) ) ).
    DATA(io) = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( )
      dependencies = VALUE #( ( `seed` ) ) cell_id = 'next' live_outputs = live ).
    live[ 1 ]-rows[ 1 ]-amount = 999.
    DATA(rows) = io->read( 'seed' ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 1 ]-amount exp = CONV decfloat34( 2 ) ).
    rows[ 1 ]-amount = 10.
    rows = io->read( 'seed' ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 1 ]-amount exp = CONV decfloat34( 2 ) ).
    TRY.
        io->read( 'undeclared' ).
        cl_abap_unit_assert=>fail( 'Live execution must still require declared dependencies' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'DEPENDENCY' ).
    ENDTRY.
  ENDMETHOD.
  METHOD typed_access.
    DATA inputs TYPE zcl_bn_types=>tt_inputs.
    inputs = VALUE #( ( name = 'total' type = 'number' value = '12.5' )
      ( name = 'label' type = 'string' value = 'É · São' ) ( name = 'flag' type = 'boolean' value = 'true' )
      ( name = 'CATEGORY' type = 'member' dimension = 'CATEGORY' selected = VALUE #( ( `BUDGET` ) )
        resolved = VALUE #( ( `BUDGET` ) ) )
      ( name = 'TIME' type = 'range' dimension = 'TIME' selected = VALUE #( ( `FiscalNode` ) )
        resolved = VALUE #( ( `P_A` ) ( `P_B` ) ) ) ).
    DATA(io) = NEW zcl_bn_context( inputs = inputs bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'test' ).
    cl_abap_unit_assert=>assert_equals( act = io->input( 'total' ) exp = '12.5' ).
    cl_abap_unit_assert=>assert_equals( act = io->input( 'label' ) exp = 'É · São' ).
    cl_abap_unit_assert=>assert_equals( act = io->input( 'flag' ) exp = 'true' ).
    cl_abap_unit_assert=>assert_equals( act = io->member( 'CATEGORY' ) exp = 'BUDGET' ).
    DATA(selected) = io->selection( 'TIME' ).
    cl_abap_unit_assert=>assert_equals( act = selected[ 1 ] exp = 'FiscalNode' ).
    cl_abap_unit_assert=>assert_equals( act = lines( io->range( 'TIME' ) ) exp = 2 ).
    TRY.
        DATA(wrong) = io->input( 'TIME' ).
        cl_abap_unit_assert=>fail( 'Scalar access must reject BPC ranges' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'INPUT_TYPE' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
