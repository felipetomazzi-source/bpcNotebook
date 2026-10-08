CLASS zcl_bn_context DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_row,
             key TYPE string, amount TYPE decfloat34,
           END OF ty_row,
           tt_rows TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.
    DATA environment TYPE uj_appset_id READ-ONLY.
    DATA model TYPE uj_appl_id READ-ONLY.
    DATA outputs TYPE tt_rows READ-ONLY.
    DATA messages TYPE zcl_bn_types=>tt_messages READ-ONLY.
    METHODS constructor IMPORTING inputs TYPE zcl_bn_types=>tt_inputs
      bindings TYPE zcl_bn_types=>tt_bindings dependencies TYPE zcl_bn_types=>tt_ids cell_id TYPE string
      environment TYPE string DEFAULT '' model TYPE string DEFAULT ''.
    METHODS input IMPORTING name TYPE string RETURNING VALUE(value) TYPE string RAISING zcx_bn.
    METHODS member IMPORTING name TYPE string RETURNING VALUE(value) TYPE uj_dim_member RAISING zcx_bn.
    METHODS selection IMPORTING name TYPE string RETURNING VALUE(value) TYPE zcl_bn_types=>tt_ids RAISING zcx_bn.
    METHODS range IMPORTING name TYPE string RETURNING VALUE(value) TYPE uja_t_dim_member RAISING zcx_bn.
    METHODS current_view RETURNING VALUE(value) TYPE ujk_t_cv RAISING zcx_bn.
    METHODS script_parameters RETURNING VALUE(value) TYPE ujk_t_script_logic_hashtable RAISING zcx_bn.
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
    me->environment = environment. me->model = model.
    mt_inputs = inputs. mt_bindings = bindings. mt_dependencies = dependencies. mv_cell_id = cell_id.
  ENDMETHOD.
  METHOD input.
    READ TABLE mt_inputs INTO DATA(parameter) WITH KEY name = name.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT' detail = |Unknown input { name }|.
    ENDIF.
    IF parameter-type = 'member' OR parameter-type = 'range'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Use member(), selection() or range() for BPC inputs'.
    ENDIF.
    value = parameter-value.
  ENDMETHOD.
  METHOD member.
    READ TABLE mt_inputs INTO DATA(parameter) WITH KEY name = name.
    IF sy-subrc <> 0 OR parameter-type <> 'member' OR lines( parameter-selected ) <> 1.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Expected a selected single member'.
    ENDIF.
    value = parameter-selected[ 1 ].
  ENDMETHOD.
  METHOD selection.
    READ TABLE mt_inputs INTO DATA(parameter) WITH KEY name = name.
    IF sy-subrc <> 0 OR ( parameter-type <> 'member' AND parameter-type <> 'range' ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Expected a BPC selection'.
    ENDIF.
    value = parameter-selected.
  ENDMETHOD.
  METHOD range.
    READ TABLE mt_inputs INTO DATA(parameter) WITH KEY name = name.
    IF sy-subrc <> 0 OR ( parameter-type <> 'member' AND parameter-type <> 'range' ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_TYPE' detail = 'Expected a BPC selection'.
    ENDIF.
    LOOP AT parameter-resolved INTO DATA(id). APPEND CONV uj_dim_member( id ) TO value. ENDLOOP.
  ENDMETHOD.
  METHOD current_view.
    value = zcl_bn_bpc=>current_view( mt_inputs ).
  ENDMETHOD.
  METHOD script_parameters.
    value = zcl_bn_bpc=>script_parameters( mt_inputs ).
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
