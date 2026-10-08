CLASS zcx_bn_engine DEFINITION PUBLIC INHERITING FROM cx_no_check CREATE PUBLIC.
 PUBLIC SECTION.
 DATA code TYPE string READ-ONLY. DATA detail TYPE string READ-ONLY.
 METHODS constructor IMPORTING code TYPE string detail TYPE string.
 METHODS get_text REDEFINITION.
ENDCLASS.
CLASS zcx_bn_engine IMPLEMENTATION.
 METHOD constructor. super->constructor( ). me->code = code. me->detail = detail. ENDMETHOD.
 METHOD get_text. result = code && ': ' && detail. ENDMETHOD.
ENDCLASS.
