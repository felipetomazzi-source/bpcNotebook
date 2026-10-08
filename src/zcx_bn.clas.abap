CLASS zcx_bn DEFINITION PUBLIC INHERITING FROM cx_static_check CREATE PUBLIC.
  PUBLIC SECTION.
    DATA code TYPE string READ-ONLY.
    DATA detail TYPE string READ-ONLY.
    DATA status TYPE i READ-ONLY.
    METHODS constructor IMPORTING code TYPE string detail TYPE string status TYPE i DEFAULT 400.
ENDCLASS.
CLASS zcx_bn IMPLEMENTATION.
  METHOD constructor.
    super->constructor( ).
    me->code = code. me->detail = detail. me->status = status.
  ENDMETHOD.
ENDCLASS.
