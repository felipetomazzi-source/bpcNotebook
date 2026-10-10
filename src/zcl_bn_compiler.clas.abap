CLASS zcl_bn_compiler DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS compile IMPORTING source TYPE string
      EXPORTING pool TYPE progname diagnostics TYPE zcl_bn_types=>tt_diagnostics.
ENDCLASS.
CLASS zcl_bn_compiler IMPLEMENTATION.
  METHOD compile.
    DATA code TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA body TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA message TYPE string.
    DATA line TYPE i.
    DATA word TYPE string.
    CLEAR: pool, diagnostics.
    APPEND 'PROGRAM SUBPOOL.' TO code.
    APPEND 'FORM execute USING io TYPE REF TO zcl_bn_context RAISING zcx_bn.' TO code.
    " Normalize only the compiler's private text; saved source/hash stays byte-identical.
    DATA(compiler_source) = replace( val = source sub = cl_abap_char_utilities=>cr_lf
      with = cl_abap_char_utilities=>newline occ = 0 ).
    SPLIT compiler_source AT cl_abap_char_utilities=>newline INTO TABLE body.
    APPEND LINES OF body TO code.
    APPEND 'ENDFORM.' TO code.
    TRY.
        GENERATE SUBROUTINE POOL code NAME pool MESSAGE message LINE line WORD word.
        IF sy-subrc <> 0.
          CLEAR pool.
          APPEND VALUE #( severity = 'error' line = nmax( val1 = 1 val2 = line - 2 )
            generated_line = line word = word message = message ) TO diagnostics.
        ENDIF.
      CATCH cx_sy_generate_subpool_full INTO DATA(error).
        CLEAR pool.
        APPEND VALUE #( severity = 'error' message = error->get_text( ) ) TO diagnostics.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
