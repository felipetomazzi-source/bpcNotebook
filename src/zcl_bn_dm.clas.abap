CLASS zcl_bn_dm DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS parameters IMPORTING text TYPE string splitter TYPE string DEFAULT '|' equal TYPE string DEFAULT '='
      RETURNING VALUE(result) TYPE ujk_t_script_logic_hashtable RAISING zcx_bn.
    CLASS-METHODS selection IMPORTING text TYPE string
      RETURNING VALUE(result) TYPE ujk_t_cv RAISING zcx_bn cx_uj_static_check.
    CLASS-METHODS preview IMPORTING handler TYPE string handler_revision TYPE i
      environment TYPE string model TYPE string scope TYPE ujk_t_cv
      overrides TYPE ujk_t_script_logic_hashtable
      RETURNING VALUE(run) TYPE zcl_bn_types=>ty_run RAISING zcx_bn.
ENDCLASS.

CLASS zcl_bn_dm IMPLEMENTATION.
  METHOD parameters.
    result = VALUE #( ( hashkey = 'WRITE' hashvalue = 'OFF' ) ( hashkey = 'EXECUTION' hashvalue = 'PREVIEW' ) ).
    IF text IS INITIAL. RETURN. ENDIF.
    IF strlen( splitter ) <> 1 OR strlen( equal ) <> 1 OR splitter = equal.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_PARAMETERS' detail = 'TAB and EQU must be different single characters'.
    ENDIF.
    DATA entries TYPE string_table.
    SPLIT text AT splitter INTO TABLE entries.
    LOOP AT entries INTO DATA(entry).
      FIND FIRST OCCURRENCE OF equal IN entry MATCH OFFSET DATA(offset).
      IF sy-subrc <> 0 OR offset = 0.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_PARAMETERS' detail = 'Each notebook override requires NAME=VALUE'.
      ENDIF.
      DATA(key) = to_upper( substring( val = entry len = offset ) ).
      SHIFT key LEFT DELETING LEADING space. SHIFT key RIGHT DELETING TRAILING space.
      IF key NP 'INPUT_*' AND key NP 'HIERARCHY_*'.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_PARAMETERS' detail = |Unsupported notebook override { key }|.
      ENDIF.
      IF line_exists( result[ hashkey = key ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_PARAMETERS' detail = |Duplicate notebook override { key }|.
      ENDIF.
      DATA(value) = substring( val = entry off = offset + 1 ).
      INSERT VALUE #( hashkey = key hashvalue = value ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.

  METHOD selection.
    IF text IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_SELECTION' detail = 'An explicit Data Manager selection is required'.
    ENDIF.
    DATA(manager) = cl_ujd_selection_mgr=>get_selection( if_filter_all = abap_false if_keep_all = abap_false if_new = abap_true ).
    DATA members TYPE ujd_th_dim_mem.
    manager->get_single_select_tb( EXPORTING i_selection = text IMPORTING et_member_list = members ).
    LOOP AT members INTO DATA(member).
      IF member-dimname IS INITIAL OR member-memname IS INITIAL OR member-memname = '<ALL>'.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_SELECTION' detail = 'Selection must resolve to explicit base members'.
      ENDIF.
      DATA(dimension) = to_upper( member-dimname ).
      READ TABLE result ASSIGNING FIELD-SYMBOL(<cv>) WITH TABLE KEY dim_upper_case = dimension.
      IF sy-subrc <> 0.
        INSERT VALUE #( dimension = dimension dim_upper_case = dimension user_specified = abap_true )
          INTO TABLE result ASSIGNING <cv>.
      ENDIF.
      IF NOT line_exists( <cv>-member[ table_line = member-memname ] ).
        INSERT CONV uj_dim_member( member-memname ) INTO TABLE <cv>-member.
      ENDIF.
    ENDLOOP.
    IF result IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_SELECTION' detail = 'Selection resolved to no members'.
    ENDIF.
  ENDMETHOD.

  METHOD preview.
    zcl_bn_service=>authorize( '16' ).
    DATA(context) = cl_uj_context=>get_cur_context( ).
    IF context IS NOT BOUND OR context->d_appset_id <> environment OR context->d_appl_id <> model OR
       context->ds_user-user_id <> sy-uname.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_CONTEXT' detail = 'Package context must match the executing SAP user, environment and model'.
    ENDIF.
    IF scope IS INITIAL OR handler_revision < 1.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_SELECTION' detail = 'Explicit scope and an approved handler revision are required'.
    ENDIF.
    LOOP AT scope INTO DATA(view).
      IF view-member IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_SELECTION' detail = 'Every selected dimension requires base members'.
      ENDIF.
    ENDLOOP.
    DATA(name) = to_upper( handler ).
    DATA(binding) = zcl_bn_logic=>binding( name ).
    " Protect the checked binding from a concurrent rebind until the package commits.
    SELECT SINGLE FOR UPDATE revision FROM zbn_head INTO @DATA(revision)
      WHERE kind = 'L' AND id = @name AND owner = @sy-uname.
    IF sy-subrc <> 0 OR revision <> handler_revision OR binding-revision <> handler_revision.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_REVISION' detail = 'Handler binding changed; review and update the package revision' status = 409.
    ENDIF.
    DATA params TYPE ujk_t_script_logic_hashtable.
    params = VALUE #( ( hashkey = 'WRITE' hashvalue = 'OFF' ) ( hashkey = 'EXECUTION' hashvalue = 'PREVIEW' ) ).
    LOOP AT overrides INTO DATA(parameter).
      parameter-hashkey = to_upper( parameter-hashkey ).
      IF parameter-hashkey = 'WRITE' AND parameter-hashvalue = 'OFF'. CONTINUE. ENDIF.
      IF parameter-hashkey = 'EXECUTION' AND parameter-hashvalue = 'PREVIEW'. CONTINUE. ENDIF.
      IF parameter-hashkey NP 'INPUT_*' AND parameter-hashkey NP 'HIERARCHY_*'.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_PARAMETERS' detail = |Unsupported notebook override { parameter-hashkey }|.
      ENDIF.
      IF line_exists( params[ hashkey = parameter-hashkey ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_PARAMETERS' detail = 'Duplicate notebook override'.
      ENDIF.
      INSERT parameter INTO TABLE params.
    ENDLOOP.
    DATA output TYPE REF TO data.
    run = zcl_bn_logic=>invoke( EXPORTING name = name environment = environment model = model
      parameters = params scope = scope IMPORTING result_data = output ).
    IF output IS BOUND OR run-state <> 'succeeded'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_RESULT' detail = 'Preview must complete without a business posting result'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

