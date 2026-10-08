CLASS zcl_bn_bpc DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_item,
             id TYPE string, description TYPE string, dim_type TYPE string,
             is_node TYPE abap_bool,
           END OF ty_item,
           tt_items TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY,
           BEGIN OF ty_metadata,
             items TYPE tt_items, hierarchies TYPE zcl_bn_types=>tt_ids,
             more TYPE abap_bool,
           END OF ty_metadata.
    CLASS-METHODS metadata IMPORTING kind TYPE string environment TYPE string model TYPE string
      dimension TYPE string hierarchy TYPE string search TYPE string offset TYPE i DEFAULT 0
      RETURNING VALUE(result) TYPE ty_metadata RAISING zcx_bn.
    CLASS-METHODS resolve IMPORTING complete TYPE abap_bool DEFAULT abap_false
      CHANGING notebook TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
    CLASS-METHODS validate_frozen IMPORTING notebook TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
    CLASS-METHODS current_view IMPORTING inputs TYPE zcl_bn_types=>tt_inputs
      RETURNING VALUE(result) TYPE ujk_t_cv RAISING zcx_bn.
    CLASS-METHODS script_parameters IMPORTING inputs TYPE zcl_bn_types=>tt_inputs
      RETURNING VALUE(result) TYPE ujk_t_script_logic_hashtable RAISING zcx_bn.
  PRIVATE SECTION.
    CLASS-METHODS context IMPORTING environment TYPE string model TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE tt_items RAISING zcx_bn.
    CLASS-METHODS permitted IMPORTING dimension TYPE string members TYPE uje_t_mem
      RETURNING VALUE(result) TYPE uje_t_mem RAISING zcx_bn.
    CLASS-METHODS members IMPORTING environment TYPE string model TYPE string dimension TYPE string
      hierarchy TYPE string RETURNING VALUE(result) TYPE ty_metadata RAISING zcx_bn.
    CLASS-METHODS bases IMPORTING environment TYPE string dimension TYPE string hierarchy TYPE string
      member TYPE string is_node TYPE abap_bool RETURNING VALUE(result) TYPE zcl_bn_types=>tt_ids RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_bpc IMPLEMENTATION.
  METHOD context.
    TRY.
        DATA(manager) = cl_uja_bpc_admin_factory=>get_appset_manager( if_disable_security = abap_false ).
        manager->get_appsets( EXPORTING i_user_id = CONV uj_user_id( sy-uname )
          IMPORTING et_appsets = DATA(environments) ).
        IF environment IS INITIAL.
          LOOP AT environments INTO DATA(env).
            APPEND VALUE #( id = env-appset_id ) TO result.
          ENDLOOP.
          RETURN.
        ENDIF.
        IF NOT line_exists( environments[ appset_id = environment ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Environment access denied' status = 403.
        ENDIF.
        cl_uj_context=>set_cur_context( i_appset_id = CONV #( environment ) i_appl_id = CONV #( model )
          is_user = VALUE #( user_id = sy-uname langu = sy-langu ) ).
        DATA(ctx) = cl_uj_context=>get_cur_context( ).
        IF ctx->df_security_check <> abap_true.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'BPC security is disabled' status = 403.
        ENDIF.
        manager = cl_uja_bpc_admin_factory=>get_appset_manager(
          i_appset_id = CONV #( environment ) if_disable_security = abap_false ).
        manager->get_applications( EXPORTING if_summary = abap_false IMPORTING et_applications = DATA(models) ).
        IF model IS INITIAL.
          LOOP AT models INTO DATA(app).
            ctx->check_app_access( EXPORTING i_appl_id = app-application_id IMPORTING ef_success = DATA(allowed) ).
            IF allowed = abap_true. APPEND VALUE #( id = app-application_id description = app-description ) TO result. ENDIF.
          ENDLOOP.
          RETURN.
        ENDIF.
        ctx->check_app_access( EXPORTING i_appl_id = CONV #( model ) IMPORTING ef_success = allowed ).
        READ TABLE models INTO app WITH KEY application_id = model.
        IF sy-subrc <> 0 OR allowed <> abap_true.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Model access denied' status = 403.
        ENDIF.
        LOOP AT app-dimensions INTO DATA(dim).
          APPEND VALUE #( id = dim-dimension description = dim-description dim_type = dim-dim_type ) TO result.
        ENDLOOP.
      CATCH zcx_bn INTO DATA(error). RAISE EXCEPTION error.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA' detail = native->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD permitted.
    IF members IS INITIAL. RETURN. ENDIF.
    DATA(ctx) = cl_uj_context=>get_cur_context( ).
    IF ctx IS INITIAL OR ctx->df_security_check <> abap_true.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Secure BPC context required' status = 403.
    ENDIF.
    ctx->check_member_access( EXPORTING i_dim_name = CONV #( dimension ) i_rw = 'R' it_mem_list = members
      IMPORTING et_mem_list = result ).
  ENDMETHOD.
  METHOD members.
    DATA(dimensions) = context( environment = environment model = model ).
    IF dimension IS INITIAL OR NOT line_exists( dimensions[ id = dimension ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_DIMENSION' detail = 'Dimension does not belong to the selected model'.
    ENDIF.
    TRY.
        DATA(dim) = NEW cl_uja_dim( i_appset_id = CONV #( environment ) i_dimension = CONV #( dimension ) ).
        DATA hi TYPE uja_t_hier.
        DATA hn TYPE uja_t_hier_name.
        IF dim->has_hier( ) = abap_true. dim->get_hier_list( IMPORTING et_hier_info = hi ). ENDIF.
        LOOP AT hi INTO DATA(h). APPEND h-hier_name TO hn. APPEND CONV string( h-hier_name ) TO result-hierarchies. ENDLOOP.
        IF hierarchy IS NOT INITIAL AND NOT line_exists( result-hierarchies[ table_line = hierarchy ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_HIERARCHY' detail = 'Unknown hierarchy'.
        ENDIF.
        dim->read_mbr_data( EXPORTING it_hier_list = hn if_inc_txt = abap_true IMPORTING er_data = DATA(data) ).
        FIELD-SYMBOLS <rows> TYPE STANDARD TABLE.
        FIELD-SYMBOLS <row> TYPE any.
        FIELD-SYMBOLS <value> TYPE any.
        ASSIGN data->* TO <rows>.
        DATA ids TYPE uje_t_mem.
        DATA all TYPE tt_items.
        DATA parents TYPE zcl_bn_types=>tt_ids.
        LOOP AT <rows> ASSIGNING <row>.
          DATA item TYPE ty_item.
          CLEAR item.
          ASSIGN COMPONENT 'ID' OF STRUCTURE <row> TO <value>.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA' detail = 'Member ID column missing'.
          ENDIF.
          item-id = <value>.
          ASSIGN COMPONENT 'EVDESCRIPTION' OF STRUCTURE <row> TO <value>.
          IF sy-subrc = 0. item-description = <value>. ENDIF.
          ASSIGN COMPONENT 'CALC' OF STRUCTURE <row> TO <value>.
          IF sy-subrc = 0. item-is_node = xsdbool( <value> = 'Y' ). ENDIF.
          LOOP AT hn INTO DATA(hierarchy_name).
            ASSIGN COMPONENT hierarchy_name OF STRUCTURE <row> TO <value>.
            IF sy-subrc = 0 AND <value> IS NOT INITIAL. APPEND CONV string( <value> ) TO parents. ENDIF.
          ENDLOOP.
          APPEND item TO all. APPEND CONV uj_dim_member( item-id ) TO ids.
        ENDLOOP.
        DATA(authorized) = permitted( dimension = dimension members = ids ).
        LOOP AT all INTO item.
          IF line_exists( authorized[ table_line = item-id ] ).
            item-is_node = xsdbool( item-is_node = abap_true OR line_exists( parents[ table_line = item-id ] ) ).
            APPEND item TO result-items.
          ENDIF.
        ENDLOOP.
        SORT result-items BY id.
        DELETE ADJACENT DUPLICATES FROM result-items COMPARING id.
      CATCH zcx_bn INTO DATA(error). RAISE EXCEPTION error.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA' detail = native->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD metadata.
    IF kind <> 'environments' AND environment IS INITIAL OR
      ( kind = 'dimensions' OR kind = 'members' ) AND model IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_CONTEXT' detail = 'Metadata context is incomplete'.
    ENDIF.
    CASE kind.
      WHEN 'environments'. result-items = context( environment = '' ).
      WHEN 'models'. result-items = context( environment = environment ).
      WHEN 'dimensions'. result-items = context( environment = environment model = model ).
      WHEN 'members'. result = members( environment = environment model = model dimension = dimension hierarchy = hierarchy ).
      WHEN OTHERS. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA' detail = 'Unknown metadata request'.
    ENDCASE.
    IF offset < 0. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'OFFSET' detail = 'Offset must be nonnegative'. ENDIF.
    DATA filtered TYPE tt_items.
    DATA query TYPE string.
    query = to_upper( search ).
    LOOP AT result-items INTO DATA(item).
      IF query IS INITIAL OR to_upper( item-id ) CS query OR to_upper( item-description ) CS query.
        APPEND item TO filtered.
      ENDIF.
    ENDLOOP.
    CLEAR result-items.
    LOOP AT filtered INTO item FROM offset + 1 TO offset + 100. APPEND item TO result-items. ENDLOOP.
    result-more = xsdbool( lines( filtered ) > offset + 100 ).
  ENDMETHOD.
  METHOD bases.
    TRY.
        DATA(dim) = NEW cl_uja_dim( i_appset_id = CONV #( environment ) i_dimension = CONV #( dimension ) ).
        dim->get_children_mbr( EXPORTING i_hier_name = CONV #( hierarchy ) i_parent_mbr = CONV #( member )
          if_only_base_mbr = abap_true if_self = abap_false IMPORTING et_member = DATA(children) ).
        LOOP AT children INTO DATA(child). APPEND CONV string( child ) TO result. ENDLOOP.
        IF result IS INITIAL.
          IF is_node = abap_true.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_HIERARCHY'
              detail = 'Node has no base members in the selected hierarchy'.
          ENDIF.
          APPEND member TO result.
        ENDIF.
      CATCH zcx_bn INTO DATA(error). RAISE EXCEPTION error.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_HIERARCHY' detail = native->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD resolve.
    IF notebook-environment IS NOT INITIAL OR notebook-model IS NOT INITIAL.
      IF notebook-environment IS INITIAL OR notebook-model IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_CONTEXT' detail = 'Choose both environment and model'.
      ENDIF.
      DATA(dimensions) = context( environment = notebook-environment model = notebook-model ).
    ENDIF.
    LOOP AT notebook-inputs ASSIGNING FIELD-SYMBOL(<input>).
      IF <input>-type <> 'member' AND <input>-type <> 'range'. CONTINUE. ENDIF.
      IF notebook-environment IS INITIAL OR notebook-model IS INITIAL OR <input>-dimension IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_CONTEXT' detail = 'Member inputs require environment, model and dimension'.
      ENDIF.
      IF <input>-type = 'member' AND lines( <input>-selected ) > 1 OR lines( <input>-selected ) > 100.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_SELECTION' detail = 'Single member input accepts one ID; ranges accept up to 100 selections'.
      ENDIF.
      DATA(list) = members( environment = notebook-environment model = notebook-model
        dimension = <input>-dimension hierarchy = <input>-hierarchy ).
      IF <input>-type = 'range' AND <input>-hierarchy IS INITIAL AND list-hierarchies IS NOT INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_HIERARCHY' detail = 'Choose a hierarchy for range inputs'.
      ENDIF.
      CLEAR: <input>-resolved, <input>-value.
      IF complete = abap_true AND <input>-required = abap_true AND <input>-selected IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_REQUIRED' detail = |Select { <input>-name } before running|.
      ENDIF.
      LOOP AT <input>-selected INTO DATA(id).
        IF NOT line_exists( list-items[ id = id ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Selection is unavailable or unauthorized' status = 403.
        ENDIF.
        IF <input>-type = 'range' AND list-hierarchies IS NOT INITIAL.
          DATA(leaves) = bases( environment = notebook-environment dimension = <input>-dimension hierarchy = <input>-hierarchy member = id is_node = list-items[ id = id ]-is_node ).
          APPEND LINES OF leaves TO <input>-resolved.
        ELSE. APPEND id TO <input>-resolved. ENDIF.
      ENDLOOP.
      SORT <input>-selected. DELETE ADJACENT DUPLICATES FROM <input>-selected.
      SORT <input>-resolved. DELETE ADJACENT DUPLICATES FROM <input>-resolved.
      LOOP AT <input>-resolved INTO id.
        IF NOT line_exists( list-items[ id = id ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'All resolved base members must be authorized' status = 403.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
  METHOD validate_frozen.
    IF notebook-environment IS NOT INITIAL.
      DATA(dimensions) = context( environment = notebook-environment model = notebook-model ).
    ENDIF.
    LOOP AT notebook-inputs INTO DATA(input) WHERE type = 'member' OR type = 'range'.
      DATA(list) = members( environment = notebook-environment model = notebook-model dimension = input-dimension hierarchy = input-hierarchy ).
      LOOP AT input-selected INTO DATA(id).
        IF NOT line_exists( list-items[ id = id ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Frozen selection is no longer authorized' status = 403.
        ENDIF.
      ENDLOOP.
      LOOP AT input-resolved INTO id.
        IF NOT line_exists( list-items[ id = id ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Frozen base member is no longer authorized' status = 403.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
  METHOD current_view.
    LOOP AT inputs INTO DATA(input) WHERE type = 'member' OR type = 'range'.
      IF input-resolved IS INITIAL. CONTINUE. ENDIF.
      READ TABLE result ASSIGNING FIELD-SYMBOL(<cv>) WITH KEY dimension = input-dimension.
      IF sy-subrc <> 0.
        INSERT VALUE #( dimension = input-dimension dim_upper_case = to_upper( input-dimension )
          user_specified = abap_true ) INTO TABLE result ASSIGNING <cv>.
      ENDIF.
      LOOP AT input-resolved INTO DATA(id). APPEND CONV uj_dim_member( id ) TO <cv>-member. ENDLOOP.
      SORT <cv>-member. DELETE ADJACENT DUPLICATES FROM <cv>-member.
    ENDLOOP.
  ENDMETHOD.
  METHOD script_parameters.
    LOOP AT inputs INTO DATA(input).
      DATA value TYPE string.
      value = input-value.
      IF input-type = 'member' OR input-type = 'range'.
        CLEAR value.
        LOOP AT input-resolved INTO DATA(id).
          IF value IS NOT INITIAL. value = value && ','. ENDIF.
          value = value && id.
        ENDLOOP.
      ENDIF.
      INSERT VALUE #( hashkey = input-name hashvalue = value ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
