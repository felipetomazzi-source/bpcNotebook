CLASS zcl_bn_context DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_row,
             key TYPE string, amount TYPE decfloat34,
           END OF ty_row,
           tt_rows TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.
    DATA outputs TYPE tt_rows READ-ONLY.
    DATA messages TYPE zcl_bn_types=>tt_messages READ-ONLY.
    METHODS constructor IMPORTING inputs TYPE zcl_bn_types=>tt_inputs
      bindings TYPE zcl_bn_types=>tt_bindings dependencies TYPE zcl_bn_types=>tt_ids cell_id TYPE string.
    METHODS input IMPORTING name TYPE string RETURNING VALUE(value) TYPE string RAISING zcx_bn.
    METHODS read IMPORTING dependency TYPE string RETURNING VALUE(rows) TYPE tt_rows RAISING zcx_bn.
    METHODS emit IMPORTING rows TYPE tt_rows RAISING zcx_bn.
    METHODS message IMPORTING text TYPE string.
  PRIVATE SECTION.
    DATA mt_inputs TYPE zcl_bn_types=>tt_inputs.
    DATA mt_bindings TYPE zcl_bn_types=>tt_bindings.
    DATA mt_dependencies TYPE zcl_bn_types=>tt_ids.
    DATA mv_cell_id TYPE string.
ENDCLASS.
CLASS zcl_bn_context IMPLEMENTATION.
  METHOD constructor.
    mt_inputs = inputs. mt_bindings = bindings. mt_dependencies = dependencies. mv_cell_id = cell_id.
  ENDMETHOD.
  METHOD input.
    READ TABLE mt_inputs INTO DATA(parameter) WITH KEY name = name.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT' detail = |Unknown input { name }|.
    ENDIF.
    value = parameter-value.
  ENDMETHOD.
  METHOD read.
    IF NOT line_exists( mt_dependencies[ table_line = dependency ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEPENDENCY' detail = 'Cell did not declare this dependency'.
    ENDIF.
    READ TABLE mt_bindings INTO DATA(binding) WITH KEY cell_id = dependency.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEPENDENCY' detail = 'Dependency output missing'.
    ENDIF.
    DATA json TYPE string.
    json = zcl_bn_store=>read( kind = 'D' id = |{ binding-run_id }:{ dependency }| revision = binding-revision ).
    TYPES: BEGIN OF ty_dataset,
             rows TYPE tt_rows,
           END OF ty_dataset.
    DATA dataset TYPE ty_dataset.
    /ui2/cl_json=>deserialize( EXPORTING json = json pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = dataset ).
    rows = dataset-rows.
  ENDMETHOD.
  METHOD emit.
    IF lines( rows ) > 10000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_LIMIT' detail = 'DEV prototype supports at most 10000 output rows'.
    ENDIF.
    outputs = rows.
  ENDMETHOD.
  METHOD message.
    APPEND VALUE #( cell_id = mv_cell_id severity = 'Information' text = text ) TO messages.
  ENDMETHOD.
ENDCLASS.
