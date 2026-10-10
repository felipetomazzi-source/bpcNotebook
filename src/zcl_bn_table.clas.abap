CLASS zcl_bn_table DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_column, name TYPE string, kind TYPE string, END OF ty_column,
           tt_columns TYPE STANDARD TABLE OF ty_column WITH DEFAULT KEY.
    CLASS-METHODS make IMPORTING io TYPE REF TO zcl_bn_context columns TYPE tt_columns RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
    CLASS-METHODS signed_boundary IMPORTING rows TYPE ANY TABLE RAISING zcx_bn.
    CLASS-METHODS compare_ordered IMPORTING io TYPE REF TO zcl_bn_context name TYPE string
      original TYPE STANDARD TABLE notebook TYPE STANDARD TABLE preview_rows TYPE i DEFAULT 100
      RETURNING VALUE(summary) TYPE zcl_bn_context=>ty_comparison RAISING zcx_bn.
    CLASS-METHODS append_row IMPORTING io TYPE REF TO zcl_bn_context row TYPE any CHANGING target TYPE STANDARD TABLE RAISING zcx_bn.
    CLASS-METHODS shape IMPORTING rows TYPE ANY TABLE RETURNING VALUE(result) TYPE REF TO cl_abap_structdescr RAISING zcx_bn.
    CLASS-METHODS keys IMPORTING rows TYPE ANY TABLE names TYPE zcl_bn_types=>tt_ids RAISING zcx_bn.
    CLASS-METHODS check IMPORTING io TYPE REF TO zcl_bn_context rows TYPE ANY TABLE RAISING zcx_bn.
    CLASS-METHODS copy IMPORTING io TYPE REF TO zcl_bn_context rows TYPE ANY TABLE empty TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
    CLASS-METHODS project IMPORTING io TYPE REF TO zcl_bn_context rows TYPE ANY TABLE names TYPE zcl_bn_types=>tt_ids
      RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
    CLASS-METHODS extend IMPORTING io TYPE REF TO zcl_bn_context rows TYPE ANY TABLE columns TYPE tt_columns
      replace TYPE abap_bool DEFAULT abap_false RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
    CLASS-METHODS append IMPORTING io TYPE REF TO zcl_bn_context source TYPE ANY TABLE CHANGING target TYPE STANDARD TABLE RAISING zcx_bn.
    CLASS-METHODS group IMPORTING io TYPE REF TO zcl_bn_context rows TYPE ANY TABLE names TYPE zcl_bn_types=>tt_ids
      mode TYPE string DEFAULT 'include' amount TYPE string DEFAULT 'SIGNEDDATA' RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
    CLASS-METHODS sort IMPORTING io TYPE REF TO zcl_bn_context order TYPE abap_sortorder_tab stable TYPE abap_bool
      CHANGING rows TYPE STANDARD TABLE RAISING zcx_bn.
    CLASS-METHODS changes IMPORTING io TYPE REF TO zcl_bn_context rows TYPE ANY TABLE previous TYPE ANY TABLE
      mode TYPE string amount TYPE string DEFAULT 'SIGNEDDATA' RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
  PRIVATE SECTION.
    CLASS-METHODS new_table IMPORTING structure TYPE REF TO cl_abap_structdescr RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
    CLASS-METHODS compatible IMPORTING left TYPE ANY TABLE right TYPE ANY TABLE RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_table IMPLEMENTATION.
  METHOD compare_ordered.
    compatible( left = original right = notebook ). check( io = io rows = original ). check( io = io rows = notebook ).
    IF preview_rows < 0 OR preview_rows > 5000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_COMPARE' detail = 'Ordered comparison preview must be 0-5000 rows'.
    ENDIF.
    summary-name = name. summary-original_rows = lines( original ). summary-notebook_rows = lines( notebook ).
    DATA(empty) = copy( io = io rows = original empty = abap_true ).
    FIELD-SYMBOLS <empty> TYPE STANDARD TABLE. ASSIGN empty->* TO <empty>.
    DATA(diff) = extend( io = io rows = <empty> columns = VALUE #(
      ( name = 'BN_DIFF_POSITION' kind = 'integer' ) ( name = 'BN_DIFF_SOURCE' kind = 'text' ) ) ).
    FIELD-SYMBOLS <diff> TYPE STANDARD TABLE. ASSIGN diff->* TO <diff>.
    FIELD-SYMBOLS: <left> TYPE any, <right> TYPE any.
    DATA(records) = 0.
    DO nmax( val1 = lines( original ) val2 = lines( notebook ) ) TIMES.
      DATA(position) = sy-index. IF position MOD 1000 = 0. io->check_budget( ). ENDIF.
      UNASSIGN: <left>, <right>.
      READ TABLE original INDEX position ASSIGNING <left>.
      READ TABLE notebook INDEX position ASSIGNING <right>.
      IF <left> IS ASSIGNED AND <right> IS ASSIGNED.
        IF <left> = <right>. summary-unchanged = summary-unchanged + 1. CONTINUE. ENDIF.
        summary-changed = summary-changed + 1. records = records + 2.
      ELSEIF <left> IS ASSIGNED. summary-missing = summary-missing + 1. records = records + 1.
      ELSE. summary-added = summary-added + 1. records = records + 1. ENDIF.
      DO 2 TIMES.
        DATA(side) = sy-index.
        IF lines( <diff> ) >= preview_rows. EXIT. ENDIF.
        IF ( side = 1 AND <left> IS NOT ASSIGNED ) OR ( side = 2 AND <right> IS NOT ASSIGNED ). CONTINUE. ENDIF.
        APPEND INITIAL LINE TO <diff> ASSIGNING FIELD-SYMBOL(<out>).
        IF side = 1. MOVE-CORRESPONDING <left> TO <out>. ELSE. MOVE-CORRESPONDING <right> TO <out>. ENDIF.
        ASSIGN COMPONENT 'BN_DIFF_POSITION' OF STRUCTURE <out> TO FIELD-SYMBOL(<ordinal>). <ordinal> = position.
        ASSIGN COMPONENT 'BN_DIFF_SOURCE' OF STRUCTURE <out> TO FIELD-SYMBOL(<source>).
        <source> = COND string( WHEN side = 1 THEN 'original' ELSE 'notebook' ).
      ENDDO.
    ENDDO.
    io->emit_table( name = name && '/ORDERED_DIFF' rows = <diff> total_count = records ).
    DATA summaries TYPE STANDARD TABLE OF zcl_bn_context=>ty_comparison WITH EMPTY KEY.
    APPEND summary TO summaries. io->emit_table( name = name && '/SUMMARY' rows = summaries ).
  ENDMETHOD.
  METHOD signed_boundary.
    DATA(structure) = shape( rows ). DATA(components) = structure->get_components( ).
    READ TABLE components INTO DATA(amount) WITH KEY name = 'SIGNEDDATA'.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_BOUNDARY' detail = 'Result requires native SIGNEDDATA'.
    ENDIF.
    DATA(native) = cl_abap_typedescr=>describe_by_name( 'UJ_SIGNEDDATA' ).
    IF amount-type->type_kind <> native->type_kind OR amount-type->length <> native->length OR
        amount-type->decimals <> native->decimals OR native->decimals <> 7.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_BOUNDARY' detail = 'Explicitly cast SIGNEDDATA to signed at the calculation boundary'.
    ENDIF.
  ENDMETHOD.
  METHOD make.
    IF columns IS INITIAL OR lines( columns ) > 100.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SCHEMA' detail = 'Declare 1-100 native columns'.
    ENDIF.
    DATA components TYPE cl_abap_structdescr=>component_table.
    LOOP AT columns INTO DATA(column).
      FIND REGEX '^[A-Z][A-Z0-9_]{0,29}$' IN column-name.
      IF sy-subrc <> 0 OR line_exists( components[ name = column-name ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_FIELD' detail = 'Invalid or duplicate native column'.
      ENDIF.
      DATA(element) = CAST cl_abap_elemdescr( cl_abap_typedescr=>describe_by_name( 'UJ_SIGNEDDATA' ) ).
      CASE column-kind.
        WHEN 'signed'.
        WHEN 'decimal'. element = cl_abap_elemdescr=>get_decfloat34( ).
        WHEN 'float'. element = cl_abap_elemdescr=>get_f( ).
        WHEN 'integer'. element = cl_abap_elemdescr=>get_i( ).
        WHEN 'text'. element = cl_abap_elemdescr=>get_string( ).
        WHEN 'member'. element ?= cl_abap_typedescr=>describe_by_name( 'UJ_DIM_MEMBER' ).
        WHEN 'boolean'. element = cl_abap_elemdescr=>get_c( 1 ).
        WHEN OTHERS. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_TYPE' detail = 'Unsupported native column type'.
      ENDCASE.
      APPEND VALUE #( name = column-name type = element ) TO components.
    ENDLOOP.
    result = new_table( cl_abap_structdescr=>create( components ) ). io->check_budget( ).
  ENDMETHOD.
  METHOD append_row.
    DATA(structure) = shape( target ).
    DATA(source_shape) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( row ) ).
    DATA(source_components) = source_shape->get_components( ). DATA(target_components) = structure->get_components( ).
    IF lines( source_components ) <> lines( target_components ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SCHEMA' detail = 'Append row schemas differ'.
    ENDIF.
    LOOP AT source_components INTO DATA(source_component).
      DATA(target_component) = target_components[ sy-tabix ].
      IF source_component-name <> target_component-name OR source_component-type->type_kind <> target_component-type->type_kind OR
          source_component-type->length <> target_component-type->length OR source_component-type->decimals <> target_component-type->decimals.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SCHEMA' detail = 'Append row native types differ'.
      ENDIF.
    ENDLOOP.
    io->check_rows( lines( target ) + 1 ). APPEND row TO target.
    io->check_working_bytes( CONV int8( lines( target ) ) * ( structure->length + 32 ) ).
  ENDMETHOD.
  METHOD shape.
    TRY.
        DATA(table_type) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( rows ) ).
        result ?= table_type->get_table_line_type( ).
        IF lines( result->get_components( ) ) > 100.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SCHEMA' detail = 'Working table exceeds 100 fields'.
        ENDIF.
        LOOP AT result->get_components( ) INTO DATA(component).
          IF component-type->kind <> cl_abap_typedescr=>kind_elem.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SCHEMA' detail = 'Script working tables must be flat native structures'.
          ENDIF.
        ENDLOOP.
      CATCH zcx_bn INTO DATA(fault). RAISE EXCEPTION fault.
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SCHEMA' detail = error->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD new_table.
    TRY.
        DATA(table_type) = cl_abap_tabledescr=>create( p_line_type = structure
          p_table_kind = cl_abap_tabledescr=>tablekind_std p_key_kind = cl_abap_tabledescr=>keydefkind_empty ).
        CREATE DATA result TYPE HANDLE table_type.
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SCHEMA' detail = error->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD keys.
    DATA(structure) = shape( rows ). DATA(components) = structure->get_components( ).
    DATA(seen) = VALUE zcl_bn_types=>tt_ids( ).
    LOOP AT names INTO DATA(name).
      IF NOT line_exists( components[ name = name ] ) OR line_exists( seen[ table_line = name ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_FIELD' detail = |Unknown or duplicate field { name }|.
      ENDIF.
      APPEND name TO seen.
    ENDLOOP.
  ENDMETHOD.
  METHOD check.
    io->check_budget( ). io->check_rows( lines( rows ) ).
    DATA(structure) = shape( rows ).
    DATA(memory) = CONV int8( lines( rows ) ) * ( structure->length + 32 ).
    io->check_working_bytes( memory ).
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      DATA(row_index) = sy-tabix.
      LOOP AT structure->get_components( ) INTO DATA(component)
        WHERE type->type_kind = cl_abap_typedescr=>typekind_string OR type->type_kind = cl_abap_typedescr=>typekind_xstring.
        ASSIGN COMPONENT component-name OF STRUCTURE <row> TO FIELD-SYMBOL(<value>).
        IF component-type->type_kind = cl_abap_typedescr=>typekind_string.
          memory = memory + strlen( <value> ) * cl_abap_char_utilities=>charsize.
        ELSE. memory = memory + xstrlen( <value> ). ENDIF.
      ENDLOOP.
      IF row_index MOD 1000 = 0. io->check_budget( ). io->check_working_bytes( memory ). ENDIF.
    ENDLOOP.
    io->check_working_bytes( memory ).
  ENDMETHOD.
  METHOD copy.
    io->check_budget( ).
    IF empty = abap_false. check( io = io rows = rows ). ENDIF.
    result = new_table( shape( rows ) ).
    FIELD-SYMBOLS <result> TYPE STANDARD TABLE. ASSIGN result->* TO <result>.
    IF empty = abap_false.
      LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>). APPEND <row> TO <result>. ENDLOOP.
    ENDIF.
  ENDMETHOD.
  METHOD compatible.
    DATA(left_shape) = shape( left ). DATA(right_shape) = shape( right ).
    DATA(lc) = left_shape->get_components( ). DATA(rc) = right_shape->get_components( ).
    IF lines( lc ) <> lines( rc ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SCHEMA' detail = 'Table schemas differ'.
    ENDIF.
    LOOP AT lc INTO DATA(l).
      DATA(r) = rc[ sy-tabix ].
      IF l-name <> r-name OR l-type->type_kind <> r-type->type_kind OR l-type->length <> r-type->length OR l-type->decimals <> r-type->decimals.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SCHEMA' detail = |Native field differs: { l-name }|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD project.
    check( io = io rows = rows ). keys( rows = rows names = names ).
    IF names IS INITIAL. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SCHEMA' detail = 'Projection needs fields'. ENDIF.
    DATA(structure) = shape( rows ). DATA(components) = structure->get_components( ).
    DATA(selected) = VALUE cl_abap_structdescr=>component_table( ).
    LOOP AT names INTO DATA(name). APPEND components[ name = name ] TO selected. ENDLOOP.
    result = new_table( cl_abap_structdescr=>create( selected ) ).
    FIELD-SYMBOLS <result> TYPE STANDARD TABLE. ASSIGN result->* TO <result>.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      APPEND INITIAL LINE TO <result> ASSIGNING FIELD-SYMBOL(<out>). MOVE-CORRESPONDING <row> TO <out>.
    ENDLOOP.
    check( io = io rows = <result> ).
  ENDMETHOD.
  METHOD extend.
    check( io = io rows = rows ). DATA(structure) = shape( rows ). DATA(components) = structure->get_components( ).
    DATA(seen) = VALUE zcl_bn_types=>tt_ids( ).
    LOOP AT columns INTO DATA(column).
      FIND REGEX '^[A-Z][A-Z0-9_]{0,29}$' IN column-name.
      IF sy-subrc <> 0 OR line_exists( seen[ table_line = column-name ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_FIELD' detail = 'Invalid or duplicate working column'.
      ENDIF.
      APPEND column-name TO seen.
      DATA(element) = CAST cl_abap_elemdescr( cl_abap_typedescr=>describe_by_name( 'UJ_SIGNEDDATA' ) ).
      CASE column-kind.
        WHEN 'signed'.
        WHEN 'decimal'. element = cl_abap_elemdescr=>get_decfloat34( ).
        WHEN 'float'. element = cl_abap_elemdescr=>get_f( ).
        WHEN 'integer'. element = cl_abap_elemdescr=>get_i( ).
        WHEN 'text'. element = cl_abap_elemdescr=>get_string( ).
        WHEN 'member'. element ?= cl_abap_typedescr=>describe_by_name( 'UJ_DIM_MEMBER' ).
        WHEN 'boolean'. element = cl_abap_elemdescr=>get_c( 1 ).
        WHEN OTHERS. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_TYPE' detail = 'Unsupported working column type'.
      ENDCASE.
      READ TABLE components ASSIGNING FIELD-SYMBOL(<component>) WITH KEY name = column-name.
      IF sy-subrc = 0.
        IF replace = abap_false. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_FIELD' detail = 'Column already exists'. ENDIF.
        <component>-type = element.
      ELSE.
        IF replace = abap_true. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_FIELD' detail = 'Cast field does not exist'. ENDIF.
        APPEND VALUE #( name = column-name type = element ) TO components.
      ENDIF.
    ENDLOOP.
    result = new_table( cl_abap_structdescr=>create( components ) ).
    FIELD-SYMBOLS <result> TYPE STANDARD TABLE. ASSIGN result->* TO <result>.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      APPEND INITIAL LINE TO <result> ASSIGNING FIELD-SYMBOL(<out>). MOVE-CORRESPONDING <row> TO <out>.
    ENDLOOP.
    check( io = io rows = <result> ).
  ENDMETHOD.
  METHOD append.
    compatible( left = source right = target ). io->check_rows( lines( source ) + lines( target ) ).
    LOOP AT source ASSIGNING FIELD-SYMBOL(<row>). APPEND <row> TO target. ENDLOOP.
    check( io = io rows = target ).
  ENDMETHOD.
  METHOD group.
    check( io = io rows = rows ). keys( rows = rows names = names ). keys( rows = rows names = VALUE #( ( amount ) ) ).
    IF mode <> 'include' AND mode <> 'exclude' AND mode <> 'all'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_GROUP' detail = 'Grouping mode must be include, exclude or all'.
    ENDIF.
    IF line_exists( names[ table_line = amount ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_GROUP' detail = 'Amount cannot be a grouping field'.
    ENDIF.
    DATA(structure) = shape( rows ). DATA(components) = structure->get_components( ).
    DATA(amount_type) = components[ name = amount ]-type.
    IF amount_type->type_kind NA 'PFaebsI8'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_TYPE' detail = 'Grouped amount must be numeric'.
    ENDIF.
    DATA(key_fields) = VALUE abap_keydescr_tab( ).
    LOOP AT components INTO DATA(component) WHERE name <> amount.
      APPEND VALUE #( name = component-name ) TO key_fields.
    ENDLOOP.
    IF key_fields IS INITIAL. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_GROUP' detail = 'Grouping requires a nonamount field'. ENDIF.
    DATA(index_type) = cl_abap_tabledescr=>create( p_line_type = structure p_table_kind = cl_abap_tabledescr=>tablekind_hashed
      p_unique = abap_true p_key = key_fields p_key_kind = cl_abap_tabledescr=>keydefkind_user ).
    DATA index TYPE REF TO data. CREATE DATA index TYPE HANDLE index_type.
    FIELD-SYMBOLS <index> TYPE ANY TABLE. ASSIGN index->* TO <index>.
    result = new_table( structure ). FIELD-SYMBOLS <result> TYPE STANDARD TABLE. ASSIGN result->* TO <result>.
    DATA candidate TYPE REF TO data. CREATE DATA candidate TYPE HANDLE structure.
    FIELD-SYMBOLS <candidate> TYPE any. ASSIGN candidate->* TO <candidate>.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      DATA(row_index) = sy-tabix. IF row_index MOD 1000 = 0. io->check_budget( ). ENDIF.
      <candidate> = <row>.
      LOOP AT components INTO component WHERE name <> amount.
        IF ( mode = 'include' AND NOT line_exists( names[ table_line = component-name ] ) ) OR
           ( mode = 'exclude' AND line_exists( names[ table_line = component-name ] ) ).
          ASSIGN COMPONENT component-name OF STRUCTURE <candidate> TO FIELD-SYMBOL(<value>). CLEAR <value>.
        ENDIF.
      ENDLOOP.
      READ TABLE <index> FROM <candidate> ASSIGNING FIELD-SYMBOL(<total>).
      IF sy-subrc <> 0.
        INSERT <candidate> INTO TABLE <index>. APPEND <candidate> TO <result>.
      ELSE.
        ASSIGN COMPONENT amount OF STRUCTURE <total> TO FIELD-SYMBOL(<sum>).
        ASSIGN COMPONENT amount OF STRUCTURE <candidate> TO FIELD-SYMBOL(<add>).
        <sum> = <sum> + <add>.
      ENDIF.
    ENDLOOP.
    LOOP AT <result> ASSIGNING FIELD-SYMBOL(<out>).
      READ TABLE <index> FROM <out> ASSIGNING <total>. <out> = <total>.
    ENDLOOP.
    check( io = io rows = <result> ).
  ENDMETHOD.
  METHOD sort.
    DATA(names) = VALUE zcl_bn_types=>tt_ids( ).
    LOOP AT order INTO DATA(item). APPEND item-name TO names. ENDLOOP.
    keys( rows = rows names = names ). check( io = io rows = rows ).
    IF order IS INITIAL. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_SORT' detail = 'Sort requires explicit fields'. ENDIF.
    IF stable = abap_true. SORT rows STABLE BY (order). ELSE. SORT rows BY (order). ENDIF.
  ENDMETHOD.
  METHOD changes.
    compatible( left = rows right = previous ). check( io = io rows = rows ). check( io = io rows = previous ).
    keys( rows = rows names = VALUE #( ( amount ) ) ).
    IF mode <> 'unique' AND mode <> 'legacy'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SCRIPT_DELTA' detail = 'Change-set mode must be unique or legacy'.
    ENDIF.
    DATA(structure) = shape( rows ). DATA(components) = structure->get_components( ).
    DATA(names) = VALUE zcl_bn_types=>tt_ids( ). DATA(order) = VALUE abap_sortorder_tab( ).
    LOOP AT components INTO DATA(component) WHERE name <> amount.
      APPEND component-name TO names. APPEND VALUE #( name = component-name ) TO order.
    ENDLOOP.
    SORT order BY name. CLEAR names. LOOP AT order INTO DATA(sort_field). APPEND sort_field-name TO names. ENDLOOP.
    DATA(old_copy) = copy( io = io rows = previous ). FIELD-SYMBOLS <old> TYPE STANDARD TABLE. ASSIGN old_copy->* TO <old>.
    sort( EXPORTING io = io order = order stable = abap_false CHANGING rows = <old> ).
    IF mode = 'unique'.
      DATA(old_index) = NEW zcl_bn_index( io = io rows = <old> names = names cardinality = 'unique' ).
      DATA(new_index) = NEW zcl_bn_index( io = io rows = rows names = names cardinality = 'unique' ).
    ENDIF.
    " Native hashed key -> first sorted old position; no amount aggregation.
    DATA(index) = NEW zcl_bn_index( io = io rows = <old> names = names ).
    result = new_table( structure ). FIELD-SYMBOLS <result> TYPE STANDARD TABLE. ASSIGN result->* TO <result>.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      DATA(position) = index->position( <row> ).
      IF position = 0. APPEND <row> TO <result>. CONTINUE. ENDIF.
      READ TABLE <old> INDEX position ASSIGNING FIELD-SYMBOL(<prior>).
      ASSIGN COMPONENT amount OF STRUCTURE <row> TO FIELD-SYMBOL(<new_amount>).
      ASSIGN COMPONENT amount OF STRUCTURE <prior> TO FIELD-SYMBOL(<old_amount>).
      IF <new_amount> <> <old_amount>. APPEND <row> TO <result>. ENDIF.
      CLEAR <old_amount>.
    ENDLOOP.
    LOOP AT <old> ASSIGNING <prior>.
      ASSIGN COMPONENT amount OF STRUCTURE <prior> TO <old_amount>.
      IF <old_amount> IS NOT INITIAL. CLEAR <old_amount>. APPEND <prior> TO <result>. ENDIF.
    ENDLOOP.
    check( io = io rows = <result> ).
  ENDMETHOD.
ENDCLASS.
