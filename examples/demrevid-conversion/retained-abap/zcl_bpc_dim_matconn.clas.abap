class zcl_bpc_dim_matconn definition
  public
  inheriting from zcl_bpc_dimension
  final
  create public .

  public section.

    interfaces zif_bpc_dimension .

    types:
      begin of struct,
        id                type c length 32,
        calc              type c length 1,
        hir               type c length 60,
        evdescription     type c length 60,
        product_type      type c length 32,
        prod_category     type c length 60,
        prod_family       type c length 60,
        prod_group        type c length 60,
        prod_type         type c length 60,
        rev_id_group      type c length 32,
        rev_id_group_desc type c length 60,
        parenth1          type c length 32,
        " Virtual properties
        _prod_type_id     type uj_dim_member, " Members from PRODUCT_TYPE dimension
      end of struct .
    types:
      tabl type table of struct with default key .

    data members type tabl .

    methods constructor
      importing
        !environment type ref to zcl_bpc_environment optional .
    methods get_member
      importing
        !i_member     type uj_dim_member
      returning
        value(member) type struct .
    methods refresh_members
      importing
        !delta_update            type rs_bool default abap_true
      returning
        value(refreshed_members) type tabl .
    methods write_data
      importing
        !new_data type tabl
        !row_flag type uj_action default uja00_cs_attr_action-insert .
  protected section.
  private section.

    constants _dim_name type uj_dim_name value 'MATCONN'.

endclass.



class zcl_bpc_dim_matconn implementation.


  method constructor.
    super->constructor(
        environment =
            cond #(
                when environment is not bound then
                    new zcl_bpc_ch_planning( ) else environment ) ).

    read_members(
        exporting
            dimension = _dim_name
        changing
            members = members ).

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    " Virtual properties
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

    data(matn1_conv) = new cl_ex_badi_matn1( ).

    " Get list of materials.
    data material_list type range of /bi0/oimaterial.
    loop at members assigning field-symbol(<_member>).
      data(output_material) = <_member>-id.
      call function 'CONVERSION_EXIT_MATN1_INPUT'
        exporting
          input  = <_member>-id
        importing
          output = output_material.
      append value #( sign = 'I' option = 'EQ' low = output_material ) to material_list.
    endloop.
    sort material_list.
    delete adjacent duplicates from material_list.

    " Select the material master data
    " joining with the product hierarchy to find out the product type text.
    select
         material,
        cast( ' ' as char( 32 ) ) as product_type, " Placeholder for PRODUCT_TYPE member.
        prod_hier_text~txtsh as product_type_text
        into table @data(material_bw)
            from /bi0/pmaterial as material_master
                inner join /bi0/tprod_hier as prod_hier_text on prod_hier_text~prod_hier = material_master~prodh4
                    where material in @material_list.

    sort material_bw by material.
    data(product_type_dim) = new zcl_bpc_dim_product_type( environment ).

    " Assign the product type IDs from dimension PRODUCT_TYPE.
    loop at members assigning <_member>.
      call function 'CONVERSION_EXIT_MATN1_INPUT'
        exporting
          input  = <_member>-id
        importing
          output = output_material.

      read table material_bw
          into data(_material_bw)
              with key material = output_material
                  binary search.
      if sy-subrc is initial.
        <_member>-_prod_type_id = product_type_dim->get_id_by_desc( conv uj_desc( _material_bw-product_type_text ) ).
      endif.
    endloop.

    sort members by id.
  endmethod.


  method zif_bpc_dimension~get_children_mbr.
    try.
        data(dim_obj) = new cl_uja_dim(
          i_appset_id = me->environment->get_environment_name( )
          i_dimension = dimension
        ).

        dim_obj->get_children_mbr(
          exporting
            i_hier_name      = i_hier_name
            i_parent_mbr     = i_parent_mbr
            if_only_base_mbr = if_only_base_mbr
          importing
            et_member        = children_members
        ).

      catch cx_uja_admin_error into data(lex).
    endtry.
  endmethod.


  method zif_bpc_dimension~get_range_by_attribute.
    translate: value to upper case, attribute to upper case.
    data attribute_value type uj_value.
    loop at members assigning field-symbol(<_members>).
      assign component attribute of structure <_members> to field-symbol(<_attribute_value>).
      assign component 'ID' of structure <_members> to field-symbol(<_id>).
      attribute_value = <_attribute_value>.
      translate attribute_value to upper case.
      if attribute_value eq value.
        append value #( low = <_id> sign = sign option = option ) to member_ranges.
      endif.
    endloop.
  endmethod.


  method get_member.
    read table members into
        member with key id = i_member
            binary search.
  endmethod.


  method zif_bpc_dimension~get_att_value.
    try.
        data(_member) = members[ id = member ].
        assign component attribute of structure _member to field-symbol(<_att_value>).
        att_value = <_att_value>.
      catch cx_sy_itab_line_not_found.
    endtry.
  endmethod.


  method zif_bpc_dimension~get_children_range.

  endmethod.


  method zif_bpc_dimension~get_id_by_desc.

  endmethod.


  method write_data.
    field-symbols:
      <new_members_data> type standard table,
      <_new_member_data> type any.

    data:
      lr_new_member_data  type ref to data.

    check lines( new_data ) is not initial.

    data(lo_dimension) = cl_uja_bpc_admin_factory=>get_dimension_manager(
          i_appset_id = environment->get_environment_name( )
          i_dimension_id = _dim_name
        ).

    lo_dimension->get(
        exporting
          if_with_hier_maxlevel = abap_false
        importing
          es_dimension = data(ls_dimension)
      ).

    data(lo_master_data_store) =
        cl_ujam_md_store_factory=>create_master_data_store(
            i_appset_id = ls_dimension-appset_id
            i_dimension = ls_dimension-dimension ).

    " Creating master data table
    data(lr_members) = lo_master_data_store->get_table_buffer( ls_dimension ).
    assign lr_members->* to <new_members_data>.

    create data lr_new_member_data like line of <new_members_data>.
    assign lr_new_member_data->* to <_new_member_data>.

    data(struct_desc) =  cast cl_abap_structdescr( cl_abap_datadescr=>describe_by_data( <_new_member_data> ) ).
    data(fields) = struct_desc->get_components( )..

    loop at new_data into data(_new_data).
      loop at fields into data(_fields).
        assign component _fields-name of structure _new_data to field-symbol(<field_value_from>).
        if sy-subrc is not initial.
          continue.
        endif.
        assign component _fields-name of structure <_new_member_data> to field-symbol(<field_value_to>).
        <field_value_to> = <field_value_from>.
      endloop.
      assign component 'OBJVERS' of structure <_new_member_data> to field-symbol(<obj_vers>).
      <obj_vers> = 'M'.
      assign component 'ROWFLAG' of structure <_new_member_data> to field-symbol(<rowflag>).
      <rowflag> = row_flag.
      append <_new_member_data> to <new_members_data>.
    endloop.

    data(lo_member_mgr) = cl_uja_bpc_admin_factory=>get_member_manager(
      i_appset_id    = ls_dimension-appset_id
      i_dimension_id = ls_dimension-dimension
      i_keydate = sy-datum ).

    zcl_bpc_util=>set_admin_context(  ).
    try.
        lo_member_mgr->save(
          exporting
            ir_members  = lr_members            "lr_members    " List of members to save
          importing
            et_errors   = data(lt_errors)
            et_exception_messages = data(lt_exp_messages) "xum 281112 Note 1793591
        ).
      catch cx_uja_admin_error  into data(err) .
        cl_ujk_logger=>log(  err->get_longtext( )  ).
      catch cx_uj_static_check.
        "handle exception
    endtry.

    lo_member_mgr->process(
    exporting
        it_dim_list = value uja_t_dim_name( ( dimension = _dim_name ) )
        if_set_offline = abap_false
        if_validate = abap_true
      importing
        ef_success = data(lf_success)
        et_message_lines = data(lt_messages) ).
  endmethod.


  method refresh_members.

    " List of materials to be refreshed.
    data material_list type range of /bi0/oimaterial.
    data output_material type /bi0/oimaterial.
    loop at members into data(_material)
        where calc eq 'N' and id ne 'MATCONN_NA'.
      call function 'CONVERSION_EXIT_MATN1_INPUT'
        exporting
          input  = _material-id
        importing
          output = output_material.
      append value #( sign = 'I' option = 'EQ' low = output_material ) to material_list.
    endloop.

    " Select the necessary attributes and texts.
    select attribute~material,
        prodh1 as prod_category,
        prodh1_text~txtmd as prod_category_desc,
        prodh2 as prod_family,
        prodh2_text~txtmd as prod_family_desc,
        prodh3 as prod_group,
        prodh3_text~txtmd as prod_group_desc,
        prodh4 as prod_type, text~txtmd as material_desc,
        prodh4_text~txtmd as prod_type_desc
        from /bi0/pmaterial as attribute
            left outer join /bi0/tmaterial as text on
                text~material = attribute~material and
                text~langu = 'E'
            left outer join /bi0/tprod_hier as prodh1_text on
                prodh1_text~prod_hier = attribute~prodh1 and
                prodh1_text~langu = 'E'
            left outer join /bi0/tprod_hier as prodh2_text on
                prodh2_text~prod_hier = attribute~prodh2 and
                prodh2_text~langu = 'E'
            left outer join /bi0/tprod_hier as prodh3_text on
                prodh3_text~prod_hier = attribute~prodh3 and
                prodh3_text~langu = 'E'
            left outer join /bi0/tprod_hier as prodh4_text on
                prodh4_text~prod_hier = attribute~prodh4 and
                prodh4_text~langu = 'E'
                    into table @data(material_master)
                        where attribute~material in @material_list.
    sort material_master by material.

    " Used to find the ID of the Product Type.
    data(product_type_dim) = new zcl_bpc_dim_product_type( ).

    " Compare the attributes in BW master data against the attributes in BPC.
    data new type tabl.
    loop at members into _material
        where calc eq 'N' and id ne 'MATCONN_NA'.
      data(is_changed) = abap_false.
      call function 'CONVERSION_EXIT_MATN1_INPUT'
        exporting
          input  = _material-id
        importing
          output = output_material.

      " Read the material master table.
      read table material_master into data(_material_master)
        with key material = output_material
            binary search.
      if sy-subrc is not initial.
        continue.
      endif.

      if _material-evdescription ne _material_master-material_desc.
        is_changed = abap_true.
        _material-evdescription = _material_master-material_desc.
      endif.

      if _material-prod_category ne _material_master-prod_category_desc.
        is_changed = abap_true.
        _material-prod_category = _material_master-prod_category_desc.
      endif.

      if _material-prod_family ne _material_master-prod_family_desc.
        is_changed = abap_true.
        _material-prod_family = _material_master-prod_family_desc.
      endif.

      if _material-prod_group ne _material_master-prod_group_desc.
        is_changed = abap_true.
        _material-prod_group = _material_master-prod_group_desc.
      endif.

      data(normalised_prod_type) = product_type_dim->get_id_by_desc( conv #( _material_master-prod_type_desc ) ).
      data(normalised_prod_type_desc) = product_type_dim->get_member( normalised_prod_type  )-evdescription.

      if _material-prod_type ne normalised_prod_type_desc or
            _material-product_type is initial.
        is_changed = abap_true.
        _material-prod_type = normalised_prod_type_desc.
        _material-product_type = normalised_prod_type.
        _material-rev_id_group = product_type_dim->get_member(  _material-product_type  )-rev_id_group.
        _material-rev_id_group_desc = product_type_dim->get_member(  _material-product_type  )-rev_id_group_desc.
      endif.

      " If the delta update is false, then update all records.
      if delta_update eq abap_false.
        is_changed = abap_true.
      endif.

      if is_changed eq abap_false.
        continue.
      endif.

      append _material to refreshed_members.
    endloop.

    write_data(
        new_data = refreshed_members
        row_flag = uja00_cs_attr_action-modify ).
  endmethod.
endclass.
