CLASS ltcl_inputs DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS adapters FOR TESTING RAISING zcx_bn.
    METHODS typed_access FOR TESTING RAISING zcx_bn.
ENDCLASS.
CLASS ltcl_inputs IMPLEMENTATION.
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
