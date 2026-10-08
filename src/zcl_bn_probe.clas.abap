CLASS zcl_bn_probe DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS compile IMPORTING bad TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(result) TYPE i.
ENDCLASS.
CLASS zcl_bn_probe IMPLEMENTATION.
  METHOD compile.
    DATA source TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA pool TYPE progname.
    DATA message TYPE string.
    DATA line TYPE i.
    DATA word TYPE string.
    APPEND 'PROGRAM SUBPOOL.' TO source.
    APPEND 'FORM execute CHANGING result TYPE i.' TO source.
    IF bad = abap_true.
      APPEND 'this_is_not_valid_abap.' TO source.
    ELSE.
      APPEND 'result = 42.' TO source.
    ENDIF.
    APPEND 'ENDFORM.' TO source.
    GENERATE SUBROUTINE POOL source NAME pool
      MESSAGE message LINE line WORD word.
    IF sy-subrc <> 0.
      result = - sy-subrc.
      RETURN.
    ENDIF.
    PERFORM execute IN PROGRAM (pool) CHANGING result.
  ENDMETHOD.
ENDCLASS.
