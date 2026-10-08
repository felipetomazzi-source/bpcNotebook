class zcl_bpc_dim_mat_group_id definition
  public
  final
  create public
  inheriting from zcl_bpc_dimension.

  public section.

    interfaces zif_bpc_dimension.

    types:
      begin of struct,
        id           type uj_dim_member,
        rev_id_group type uj_dim_member,
      end of struct .
    types:
      tabl type table of struct with default key .

    methods constructor
      importing
        !environment type ref to zcl_bpc_environment.

    methods get_property_distinct
      importing
        !property                  type uj_attr_name
      returning
        value(distinct_properties) type uj0_t_string.

    methods get_member
      importing
        !i_member     type uj_dim_member
      returning
        value(member) type struct.

    data members type tabl .
  protected section.
  private section.

    constants _dim_name type uj_dim_name value 'MAT_GROUP_ID'.

endclass.



class zcl_bpc_dim_mat_group_id implementation.


  method get_property_distinct.
    field-symbols <property_value> type string.
    loop at members assigning field-symbol(<_members>).
      assign component property of structure <_members> to <property_value>.
      append <property_value> to distinct_properties.
    endloop.
    sort distinct_properties.
    delete adjacent duplicates from distinct_properties.
  endmethod.


  method constructor.
    super->constructor( environment ).
    read_members(
      exporting
        dimension = _dim_name
      changing
        members   = members ).
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


  method zif_bpc_dimension~get_children_range.
    loop at zif_bpc_dimension~get_children_mbr(
              dimension = dimension
              i_hier_name      = i_hier_name
              i_parent_mbr     = i_parent_mbr
              if_only_base_mbr = abap_true
            ) into data(l_member).
      append value #( low = l_member sign = sign option = option ) to members_range.
    endloop.
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

  method zif_bpc_dimension~get_id_by_desc.
    raise exception type cx_rs_not_implemented.
  endmethod.

endclass.
