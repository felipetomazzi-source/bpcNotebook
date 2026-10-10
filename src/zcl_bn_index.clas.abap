CLASS zcl_bn_index DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES tt_positions TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA found TYPE abap_bool READ-ONLY.
    METHODS constructor IMPORTING io TYPE REF TO zcl_bn_context rows TYPE ANY TABLE
      names TYPE zcl_bn_types=>tt_ids cardinality TYPE string DEFAULT 'many' RAISING zcx_bn.
    METHODS position IMPORTING pattern TYPE any policy TYPE string DEFAULT 'first'
      RETURNING VALUE(result) TYPE i RAISING zcx_bn.
    METHODS lookup IMPORTING pattern TYPE any policy TYPE string missing TYPE string
      RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
    METHODS matches IMPORTING pattern TYPE any RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
  PRIVATE SECTION.
    DATA mo_io TYPE REF TO zcl_bn_context.
    DATA mr_source TYPE REF TO data.
    DATA mr_index TYPE REF TO data.
    DATA mr_probe TYPE REF TO data.
    DATA mo_shape TYPE REF TO cl_abap_structdescr.
    METHODS positions IMPORTING pattern TYPE any RETURNING VALUE(result) TYPE tt_positions RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_index IMPLEMENTATION.
  METHOD constructor.
    IF names IS INITIAL OR ( cardinality <> 'many' AND cardinality <> 'unique' ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_INDEX' detail = 'Index requires keys and many/unique cardinality'.
    ENDIF.
    mo_io = io. zcl_bn_table=>keys( rows = rows names = names ).
    mr_source = zcl_bn_table=>copy( io = io rows = rows ). mo_shape = zcl_bn_table=>shape( rows ).
    DATA(source_components) = mo_shape->get_components( ).
    DATA(components) = VALUE cl_abap_structdescr=>component_table( ).
    DATA(key_fields) = VALUE abap_keydescr_tab( ).
    LOOP AT names INTO DATA(name).
      APPEND source_components[ name = name ] TO components. APPEND VALUE #( name = name ) TO key_fields.
    ENDLOOP.
    IF line_exists( source_components[ name = 'BN_INTERNAL_POSITIONS' ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_INDEX' detail = 'Reserved index field name'.
    ENDIF.
    APPEND VALUE #( name = 'BN_INTERNAL_POSITIONS' type = cl_abap_refdescr=>get_ref_to_data( ) ) TO components.
    DATA(structure) = cl_abap_structdescr=>create( components ).
    DATA(table_type) = cl_abap_tabledescr=>create( p_line_type = structure p_table_kind = cl_abap_tabledescr=>tablekind_hashed
      p_unique = abap_true p_key = key_fields p_key_kind = cl_abap_tabledescr=>keydefkind_user ).
    CREATE DATA mr_index TYPE HANDLE table_type. CREATE DATA mr_probe TYPE HANDLE structure.
    FIELD-SYMBOLS <index> TYPE ANY TABLE. ASSIGN mr_index->* TO <index>.
    FIELD-SYMBOLS <probe> TYPE any. ASSIGN mr_probe->* TO <probe>.
    FIELD-SYMBOLS <source> TYPE STANDARD TABLE. ASSIGN mr_source->* TO <source>.
    LOOP AT <source> ASSIGNING FIELD-SYMBOL(<row>).
      DATA(ordinal) = sy-tabix. IF ordinal MOD 1000 = 0. io->check_budget( ). ENDIF.
      CLEAR <probe>. MOVE-CORRESPONDING <row> TO <probe>.
      READ TABLE <index> FROM <probe> ASSIGNING FIELD-SYMBOL(<bucket>).
      IF sy-subrc <> 0.
        FIELD-SYMBOLS <new_ref> TYPE REF TO data.
        ASSIGN COMPONENT 'BN_INTERNAL_POSITIONS' OF STRUCTURE <probe> TO <new_ref>.
        CREATE DATA <new_ref> TYPE tt_positions.
        INSERT <probe> INTO TABLE <index> ASSIGNING <bucket>.
      ELSEIF cardinality = 'unique'.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_CARDINALITY' detail = 'Index keys are not unique'.
      ENDIF.
      FIELD-SYMBOLS <positions_ref> TYPE REF TO data.
      ASSIGN COMPONENT 'BN_INTERNAL_POSITIONS' OF STRUCTURE <bucket> TO <positions_ref>.
      FIELD-SYMBOLS <positions> TYPE tt_positions. ASSIGN <positions_ref>->* TO <positions>.
      APPEND ordinal TO <positions>.
    ENDLOOP.
    io->check_working_bytes( CONV int8( lines( <source> ) ) * ( mo_shape->length + structure->length + 72 ) ).
  ENDMETHOD.
  METHOD positions.
    mo_io->check_budget( ).
    FIELD-SYMBOLS <probe> TYPE any. ASSIGN mr_probe->* TO <probe>.
    FIELD-SYMBOLS <index> TYPE ANY TABLE. ASSIGN mr_index->* TO <index>.
    CLEAR <probe>. MOVE-CORRESPONDING pattern TO <probe>.
    READ TABLE <index> FROM <probe> ASSIGNING FIELD-SYMBOL(<bucket>).
    found = xsdbool( sy-subrc = 0 ).
    IF found = abap_false. RETURN. ENDIF.
    FIELD-SYMBOLS <positions_ref> TYPE REF TO data.
    ASSIGN COMPONENT 'BN_INTERNAL_POSITIONS' OF STRUCTURE <bucket> TO <positions_ref>.
    FIELD-SYMBOLS <positions> TYPE tt_positions. ASSIGN <positions_ref>->* TO <positions>. result = <positions>.
  ENDMETHOD.
  METHOD position.
    IF policy <> 'first' AND policy <> 'last' AND policy <> 'unique'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_INDEX' detail = 'Lookup policy must be first, last or unique'.
    ENDIF.
    DATA(matches) = positions( pattern ).
    IF matches IS INITIAL. RETURN. ENDIF.
    IF policy = 'unique' AND lines( matches ) <> 1.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_CARDINALITY' detail = 'Lookup expected one matching row'.
    ENDIF.
    result = matches[ COND #( WHEN policy = 'last' THEN lines( matches ) ELSE 1 ) ].
  ENDMETHOD.
  METHOD lookup.
    IF missing <> 'initial' AND missing <> 'error'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_INDEX' detail = 'Lookup missing policy must be initial or error'.
    ENDIF.
    CREATE DATA result TYPE HANDLE mo_shape. FIELD-SYMBOLS <result> TYPE any. ASSIGN result->* TO <result>.
    DATA(ordinal) = position( pattern = pattern policy = policy ).
    IF ordinal = 0.
      IF missing = 'error'. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_MISSING' detail = 'Lookup row not found'. ENDIF.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <source> TYPE STANDARD TABLE. ASSIGN mr_source->* TO <source>.
    READ TABLE <source> INDEX ordinal INTO <result>.
  ENDMETHOD.
  METHOD matches.
    FIELD-SYMBOLS <source> TYPE STANDARD TABLE. ASSIGN mr_source->* TO <source>.
    result = zcl_bn_table=>copy( io = mo_io rows = <source> empty = abap_true ).
    FIELD-SYMBOLS <result> TYPE STANDARD TABLE. ASSIGN result->* TO <result>.
    LOOP AT positions( pattern ) INTO DATA(ordinal).
      READ TABLE <source> INDEX ordinal ASSIGNING FIELD-SYMBOL(<row>). APPEND <row> TO <result>.
    ENDLOOP.
    zcl_bn_table=>check( io = mo_io rows = <result> ).
  ENDMETHOD.
ENDCLASS.
