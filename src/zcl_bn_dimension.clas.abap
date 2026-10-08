CLASS zcl_bn_dimension DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION.
 TYPES: BEGIN OF ty_member,
   id TYPE uj_dim_member, product_type TYPE uj_dim_member, rev_id_group TYPE uj_dim_member,
   evdescription TYPE uj_desc, alternative_text TYPE char120,
 END OF ty_member, tt_members TYPE STANDARD TABLE OF ty_member WITH DEFAULT KEY.
 METHODS constructor IMPORTING io TYPE REF TO zcl_bn_context name TYPE uj_dim_name.
 METHODS get_member IMPORTING i_member TYPE uj_dim_member RETURNING VALUE(member) TYPE ty_member.
 METHODS get_member_by_index IMPORTING member_index TYPE uj_signeddata RETURNING VALUE(member) TYPE uj_dim_member.
 METHODS get_children_range IMPORTING i_parent_mbr TYPE uj_dim_member i_hier_name TYPE uj_hier_name DEFAULT 'PARENTH1'
   dimension TYPE uj_dim_name OPTIONAL sign TYPE uj_sign DEFAULT 'I' option TYPE uj_option DEFAULT 'EQ'
   RETURNING VALUE(members_range) TYPE ujw_t_dimmem_range.
 METHODS get_range_by_attribute IMPORTING attribute TYPE uj_dim_name value TYPE uj_value
   sign TYPE uj_sign DEFAULT 'I' option TYPE uj_option DEFAULT 'EQ' RETURNING VALUE(member_ranges) TYPE ujw_t_dimmem_range.
 METHODS get_att_value IMPORTING member TYPE uj_dim_member attribute TYPE uj_dim_name RETURNING VALUE(att_value) TYPE uj_value.
 PRIVATE SECTION. DATA adapter TYPE REF TO zcl_bn_bpc. DATA members TYPE tt_members.
ENDCLASS.
CLASS zcl_bn_dimension IMPLEMENTATION.
 METHOD constructor.
 TRY.

   adapter = io->bpc_dimension( CONV string( name ) ).
   DATA(ref) = adapter->member_data( ). FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN ref->* TO <rows>.
   LOOP AT <rows> ASSIGNING FIELD-SYMBOL(<row>). APPEND CORRESPONDING #( <row> ) TO members. ENDLOOP.
   SORT members BY id.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
 ENDMETHOD.
 METHOD get_member.
 READ TABLE members INTO member WITH KEY id = i_member.
 ENDMETHOD.
 METHOD get_member_by_index.
 TRY.
   DATA(id) = CONV uj_dim_member( 'PRODUCT_TYPE_' ) && CONV num03( member_index ).
   READ TABLE members INTO DATA(row) WITH KEY id = id BINARY SEARCH. IF sy-subrc = 0. member = row-id. ENDIF.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
 ENDMETHOD.
 METHOD get_children_range.
 TRY.

   LOOP AT adapter->children( member = CONV string( i_parent_mbr ) hierarchy = CONV string( i_hier_name ) ) INTO DATA(id).
     APPEND VALUE #( sign = sign option = option low = id ) TO members_range.
   ENDLOOP.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
 ENDMETHOD.
 METHOD get_range_by_attribute.
 TRY.

   DATA(ref) = adapter->member_data( ). FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN ref->* TO <rows>.
   FIELD-SYMBOLS <value> TYPE any. FIELD-SYMBOLS <id> TYPE any.
   LOOP AT <rows> ASSIGNING FIELD-SYMBOL(<row>).
     UNASSIGN: <value>, <id>.
     ASSIGN COMPONENT attribute OF STRUCTURE <row> TO <value>. ASSIGN COMPONENT 'ID' OF STRUCTURE <row> TO <id>.
     IF <value> IS NOT ASSIGNED OR <id> IS NOT ASSIGNED.
       RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = 'PROPERTY' detail = 'Unknown stored attribute'.
     ENDIF.
     IF to_upper( CONV string( <value> ) ) = to_upper( CONV string( value ) ).
       APPEND VALUE #( low = <id> sign = sign option = option ) TO member_ranges.
     ENDIF.
   ENDLOOP.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
 ENDMETHOD.
 METHOD get_att_value.
 TRY.
 att_value = adapter->property( member = CONV string( member ) name = CONV string( attribute ) ).
 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
 ENDMETHOD.
ENDCLASS.
