CLASS ltcl_compiler DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS wrapper_and_output FOR TESTING RAISING zcx_bn.
    METHODS syntax_line_mapping FOR TESTING.
    METHODS typed_json_inputs FOR TESTING.
    METHODS crlf_compilation FOR TESTING.
    METHODS json_controls FOR TESTING.
ENDCLASS.
CLASS ltcl_compiler IMPLEMENTATION.
  METHOD crlf_compilation.
    DATA(source) = |DATA total TYPE i.{ cl_abap_char_utilities=>cr_lf }| &&
      |{ cl_abap_char_utilities=>cr_lf }total = 1.{ cl_abap_char_utilities=>cr_lf }|.
    DATA(original) = source.
    DATA pool TYPE progname.
    DATA diagnostics TYPE zcl_bn_types=>tt_diagnostics.
    zcl_bn_compiler=>compile( EXPORTING source = source IMPORTING pool = pool diagnostics = diagnostics ).
    cl_abap_unit_assert=>assert_not_initial( pool ).
    cl_abap_unit_assert=>assert_initial( diagnostics ).
    cl_abap_unit_assert=>assert_equals( act = source exp = original ).
  ENDMETHOD.
  METHOD json_controls.
    TYPES: BEGIN OF ty_text, word TYPE string, message TYPE string, END OF ty_text.
    DATA(input) = VALUE ty_text( word = cl_abap_char_utilities=>cr_lf
      message = |É · "quoted" \\ slash| ).
    DO 32 TIMES.
      DATA hex TYPE x LENGTH 2.
      hex = sy-index - 1.
      input-message = input-message && cl_abap_conv_in_ce=>uccp( hex ).
    ENDDO.
    DATA(json) = zcl_bn_types=>json( input ).
    FIND REGEX '[[:cntrl:]]' IN json.
    cl_abap_unit_assert=>assert_equals( act = sy-subrc exp = 4 ).
    DATA output TYPE ty_text.
    /ui2/cl_json=>deserialize( EXPORTING json = json CHANGING data = output ).
    cl_abap_unit_assert=>assert_equals( act = output exp = input ).
  ENDMETHOD.
  METHOD wrapper_and_output.
    DATA source TYPE string.
    source = |DATA rows TYPE zcl_bn_context=>tt_rows.\n| &&
      |DATA total TYPE decfloat34.\n| &&
      |total = io->input( 'total' ).\n| &&
      |APPEND VALUE #( key = 'CC100' amount = total * '0.5' ) TO rows.\n| &&
      |io->emit( rows ).|.
    DATA pool TYPE progname.
    DATA diagnostics TYPE zcl_bn_types=>tt_diagnostics.
    zcl_bn_compiler=>compile( EXPORTING source = source IMPORTING pool = pool diagnostics = diagnostics ).
    cl_abap_unit_assert=>assert_not_initial( pool ).
    cl_abap_unit_assert=>assert_initial( diagnostics ).
    DATA(context) = NEW zcl_bn_context( inputs = VALUE #( ( name = 'total' type = 'number' value = '120000' ) )
      bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'seed' ).
    PERFORM execute IN PROGRAM (pool) USING context.
    cl_abap_unit_assert=>assert_equals( act = context->outputs[ 1 ]-amount exp = 60000 ).
  ENDMETHOD.
  METHOD syntax_line_mapping.
    DATA pool TYPE progname.
    DATA diagnostics TYPE zcl_bn_types=>tt_diagnostics.
    zcl_bn_compiler=>compile( EXPORTING source = 'this_is_not_valid_abap.' IMPORTING pool = pool diagnostics = diagnostics ).
    cl_abap_unit_assert=>assert_initial( pool ).
    cl_abap_unit_assert=>assert_equals( act = diagnostics[ 1 ]-line exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = diagnostics[ 1 ]-generated_line exp = 3 ).
  ENDMETHOD.
  METHOD typed_json_inputs.
    DATA inputs TYPE zcl_bn_types=>tt_inputs.
    /ui2/cl_json=>deserialize( EXPORTING json =
      '[{"name":"amount","type":"number","value":12.5},{"name":"flag","type":"boolean","value":true}]'
      CHANGING data = inputs ).
    inputs = zcl_bn_types=>normalize_inputs( inputs ).
    cl_abap_unit_assert=>assert_equals( act = inputs[ 1 ]-value exp = '12.5' ).
    cl_abap_unit_assert=>assert_equals( act = inputs[ 2 ]-value exp = 'true' ).
  ENDMETHOD.
ENDCLASS.
