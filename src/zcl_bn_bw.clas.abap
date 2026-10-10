CLASS zcl_bn_bw DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_field,
      infoobject TYPE string, alias TYPE string, ddic_type TYPE string,
      kind TYPE string,
    END OF ty_field, tt_fields TYPE STANDARD TABLE OF ty_field WITH EMPTY KEY.
    CLASS-METHODS read_data IMPORTING io TYPE REF TO zcl_bn_context
      provider TYPE string fields TYPE tt_fields filters TYPE zcl_bn_bpc=>tt_filters
      max_rows TYPE i RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_bw IMPLEMENTATION.
  METHOD read_data.
    IF io IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_REQUEST' detail = 'Notebook context required'.
    ENDIF.
    io->check_bw_context( ).
    IF provider IS INITIAL OR strlen( provider ) > 30 OR
       max_rows < 1 OR max_rows > 100000 OR fields IS INITIAL OR lines( fields ) > 100.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_REQUEST' detail = 'Provider, explicit fields and limit 1..100000 required'.
    ENDIF.
    FIND REGEX '^[A-Z0-9_/]+$' IN provider.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_REQUEST' detail = 'Invalid technical provider name'.
    ENDIF.
    DATA components TYPE cl_abap_structdescr=>component_table.
    DATA characteristics TYPE rsdri_th_sfc.
    DATA keyfigures TYPE rsdri_th_sfk.
    DATA ranges TYPE rsdri_t_range.
    DATA seen_objects TYPE zcl_bn_types=>tt_ids.
    TRY.
        LOOP AT fields INTO DATA(field).
          FIND REGEX '^[A-Z][A-Z0-9_]{0,29}$' IN field-alias.
          IF sy-subrc <> 0 OR line_exists( components[ name = field-alias ] ) OR
             field-infoobject IS INITIAL OR strlen( field-infoobject ) > 30 OR
             ( field-kind <> 'characteristic' AND field-kind <> 'keyfigure' ).
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_FIELDS' detail = 'Invalid or duplicate field alias/kind'.
          ENDIF.
          FIND REGEX '^[A-Z0-9_/]{1,30}$' IN field-infoobject.
          IF sy-subrc <> 0 OR line_exists( seen_objects[ table_line = field-infoobject ] ).
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_FIELDS' detail = 'Invalid or duplicate technical InfoObject'.
          ENDIF.
          APPEND field-infoobject TO seen_objects.
          FIND REGEX '^[A-Z0-9_/]{1,30}$' IN field-ddic_type.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_FIELDS' detail = 'Invalid DDIC element name'.
          ENDIF.
          DATA(element) = CAST cl_abap_elemdescr( cl_abap_typedescr=>describe_by_name( field-ddic_type ) ).
          IF element->is_ddic_type( ) = abap_false OR element->type_kind = cl_abap_typedescr=>typekind_string OR
             element->type_kind = cl_abap_typedescr=>typekind_xstring.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_FIELDS' detail = 'Flat DDIC InfoObject element required'.
          ENDIF.
          IF field-kind = 'keyfigure' AND element->type_kind <> cl_abap_typedescr=>typekind_packed AND
             element->type_kind <> cl_abap_typedescr=>typekind_float AND
             element->type_kind <> cl_abap_typedescr=>typekind_int AND
             element->type_kind <> cl_abap_typedescr=>typekind_int8 AND
             element->type_kind <> cl_abap_typedescr=>typekind_decfloat16 AND
             element->type_kind <> cl_abap_typedescr=>typekind_decfloat34.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_FIELDS' detail = 'Key figures require numeric DDIC elements'.
          ENDIF.
          APPEND VALUE #( name = field-alias type = element ) TO components.
          IF field-kind = 'characteristic'.
            INSERT VALUE #( chanm = field-infoobject chaalias = field-alias ) INTO TABLE characteristics.
          ELSE.
            INSERT VALUE #( kyfnm = field-infoobject kyfalias = field-alias aggr = 'SUM' ) INTO TABLE keyfigures.
          ENDIF.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_FIELDS' detail = 'Duplicate InfoObject'.
          ENDIF.
        ENDLOOP.
        DATA(table_type) = cl_abap_tabledescr=>create( p_line_type = cl_abap_structdescr=>create( components ) ).
        CREATE DATA result TYPE HANDLE table_type.
      CATCH cx_sy_type_not_found cx_sy_move_cast_error cx_sy_struct_creation cx_sy_table_creation INTO DATA(schema_error).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_FIELDS' detail = schema_error->get_text( ).
    ENDTRY.
    IF lines( filters ) > 100.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_FILTER' detail = 'At most 100 filters'.
    ENDIF.
    DATA seen_filters TYPE zcl_bn_types=>tt_ids.
    LOOP AT filters INTO DATA(filter).
      IF filter-members IS INITIAL OR lines( filter-members ) > 1000 OR
         NOT line_exists( characteristics[ chanm = filter-dimension ] ) OR
         line_exists( seen_filters[ table_line = filter-dimension ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_FILTER' detail = 'Filters require selected characteristics and 1..1000 exact values'.
      ENDIF.
      APPEND filter-dimension TO seen_filters.
      LOOP AT filter-members INTO DATA(member).
        IF strlen( member ) > 60.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_FILTER' detail = 'Filter value exceeds BW range width'.
        ENDIF.
        APPEND VALUE #( chanm = filter-dimension sign = 'I' compop = 'EQ' low = member ) TO ranges.
      ENDLOOP.
    ENDLOOP.
    io->check_budget( force_poll = abap_true ).
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE.
    ASSIGN result->* TO <rows>.
    DATA(first_call) = abap_true.
    DATA ended TYPE rs_bool.
    DATA split_occurred TYPE rsdr0_split_occurred.
    DATA(fetch_limit) = max_rows + 1.
    io->check_rows( fetch_limit ).
    io->check_working_bytes( CONV int8( fetch_limit ) * ( table_type->get_table_line_type( )->length + 32 ) ).
    TEST-SEAM bw_read.
    CALL FUNCTION 'RSDRI_INFOPROV_READ'
      EXPORTING i_infoprov = CONV rsinfoprov( provider ) i_th_sfc = characteristics
        i_th_sfk = keyfigures i_t_range = ranges i_packagesize = fetch_limit
        i_maxrows = fetch_limit i_authority_check = 'R' i_commit_allowed = abap_false
        i_use_db_aggregation = abap_true i_currency_conversion = abap_false
      IMPORTING e_t_data = <rows> e_end_of_data = ended e_split_occurred = split_occurred
      CHANGING c_first_call = first_call
      EXCEPTIONS OTHERS = 1.
    END-TEST-SEAM.
    IF sy-subrc <> 0.
      CLEAR <rows>.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_READ'
        detail = 'BW read failed: check provider support, fields and SAP authorizations; no fallback'.
    ENDIF.
    IF ended <> abap_true OR split_occurred IS NOT INITIAL OR lines( <rows> ) > max_rows.
      CLEAR <rows>.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_LIMIT' detail = 'Incomplete BW result: narrow filters or increase bounded limit'.
    ENDIF.
    io->check_budget( force_poll = abap_true ).
    zcl_bn_table=>check( io = io rows = <rows> ).
  ENDMETHOD.
ENDCLASS.
