class zcl_bpc_dim_product_type definition
  public
  final
  create public
  inheriting from zcl_bpc_dimension.


  public section.

    interfaces zif_bpc_dimension.

    aliases get_id_by_desc for zif_bpc_dimension~get_id_by_desc.
    aliases get_children_range for zif_bpc_dimension~get_children_range.

    types:
      begin of struct,
        id                    type uj_dim_member,
        evdescription         type uj_desc,
        alternative_text      type char120,
        description_ucase     type uj_desc,
        alternative_text_list type uj0_t_dim_member,
        rev_id_group          type uj_dim_member,
        rev_id_group_desc     type c length 120,
      end of struct .
    types:
      tabl type table of struct with default key .

    methods constructor
      importing
        !environment type ref to zcl_bpc_environment optional.

    methods get_member
      importing
        !i_member     type uj_dim_member
      returning
        value(member) type struct.

    methods get_member_by_index
      importing
        !member_index type uj_signeddata
      returning
        value(member) type uj_dim_member.

    data members type tabl .
  protected section.
  private section.

    constants _dim_name type uj_dim_name value 'PRODUCT_TYPE'.

ENDCLASS.



CLASS ZCL_BPC_DIM_PRODUCT_TYPE IMPLEMENTATION.


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

    loop at members assigning field-symbol(<_members>).
      <_members>-description_ucase = <_members>-evdescription.
      translate <_members>-description_ucase to upper case.

      if <_members>-alternative_text is not initial.
        split <_members>-alternative_text at ';'
            into table data(alternative_text_list).
        loop at alternative_text_list into data(_alternative_text).
          translate _alternative_text to upper case.
          append _alternative_text to <_members>-alternative_text_list.
        endloop.
      endif.
    endloop.
  endmethod.


  method get_member_by_index.
    data _product_type type uj_dim_member.
    _product_type = conv uj_dim_member( 'PRODUCT_TYPE_' ) && conv num03( member_index ).
    read table members into data(_member)
        with key id = _product_type
            binary search.
    if sy-subrc is initial.
      member = _member-id.
    endif.
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
    try.
        member = members[ id = i_member ].
      catch cx_sy_itab_line_not_found.
    endtry.
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
    loop at zif_bpc_dimension~get_children_mbr(
           dimension = _dim_name
           i_hier_name      = i_hier_name
           i_parent_mbr     = i_parent_mbr
           if_only_base_mbr = abap_true
         ) into data(l_member).
      append value #( low = l_member sign = sign option = option ) to members_range.
    endloop.
  endmethod.


  method zif_bpc_dimension~get_id_by_desc.

    data(product_type_desc) = description.
    translate product_type_desc to upper case.

    " Look for the PRODUCT_TYPE description in the dimension master.
    read table members
      into data(_product_type) with key
          description_ucase = product_type_desc.
    if sy-subrc is initial.
      id = _product_type-id.
      return.
    else.
      " If not found, try to look for the description in the ALTERNATIVE_TEXT property
      " of the dimension.
      loop at members into _product_type
          where alternative_text is not initial.
        loop at _product_type-alternative_text_list into data(_alternative_text_list).
          if _alternative_text_list eq product_type_desc.
            id = _product_type-id.
            return.
          endif.
        endloop.
      endloop.
    endif.

    " Not Assigned Product Type
    id = 'PRODUCT_TYPE_NA'.
  endmethod.
ENDCLASS.
