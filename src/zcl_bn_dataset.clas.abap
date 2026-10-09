CLASS zcl_bn_dataset DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_field,
             name TYPE string, native_type TYPE string, type_kind TYPE c LENGTH 1,
             length TYPE i, decimals TYPE i,
           END OF ty_field,
           tt_fields TYPE STANDARD TABLE OF ty_field WITH DEFAULT KEY,
           BEGIN OF ty_header,
             name TYPE string, row_count TYPE i, byte_count TYPE i, memory_bytes TYPE i,
             checksum TYPE string, schema TYPE tt_fields,
           END OF ty_header,
           tt_headers TYPE STANDARD TABLE OF ty_header WITH DEFAULT KEY,
           BEGIN OF ty_packet,
             name TYPE string, row_count TYPE i, byte_count TYPE i, memory_bytes TYPE i,
             checksum TYPE string, schema TYPE tt_fields, content TYPE string,
           END OF ty_packet,
           tt_packets TYPE STANDARD TABLE OF ty_packet WITH DEFAULT KEY,
           BEGIN OF ty_live,
             cell_id TYPE string, packets TYPE tt_packets,
           END OF ty_live,
           tt_live TYPE STANDARD TABLE OF ty_live WITH DEFAULT KEY,
           BEGIN OF ty_access,
             dependency TYPE string, name TYPE string, run_id TYPE string, revision TYPE i,
             row_count TYPE i, byte_count TYPE i, checksum TYPE string,
           END OF ty_access,
           tt_access TYPE STANDARD TABLE OF ty_access WITH DEFAULT KEY,
           BEGIN OF ty_saved,
             notebook_id TYPE string, run_id TYPE string, cell_id TYPE string, revision TYPE i,
             source_checksum TYPE string, source_version TYPE i, fingerprint TYPE string, packet TYPE ty_packet,
           END OF ty_saved.
    CLASS-METHODS freeze IMPORTING name TYPE string rows TYPE ANY TABLE max_bytes TYPE i DEFAULT 268435456
      RETURNING VALUE(packet) TYPE ty_packet RAISING zcx_bn.
    CLASS-METHODS thaw IMPORTING packet TYPE ty_packet
      RETURNING VALUE(rows) TYPE REF TO data RAISING zcx_bn.
    CLASS-METHODS storage_id IMPORTING run_id TYPE string cell_id TYPE string name TYPE string
      RETURNING VALUE(id) TYPE string RAISING zcx_bn.
  PRIVATE SECTION.
    CLASS-METHODS row_type IMPORTING schema TYPE tt_fields
      RETURNING VALUE(result) TYPE REF TO cl_abap_structdescr RAISING zcx_bn.
    CLASS-METHODS digest IMPORTING packet TYPE ty_packet RETURNING VALUE(checksum) TYPE string RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_dataset IMPLEMENTATION.
  METHOD digest.
    DATA(copy) = packet.
    CLEAR copy-checksum.
    checksum = zcl_bn_types=>hash( zcl_bn_types=>json( copy ) ).
  ENDMETHOD.
  METHOD storage_id.
    id = zcl_bn_types=>hash( |{ run_id }:{ cell_id }:{ name }| ).
  ENDMETHOD.
  METHOD row_type.
    DATA components TYPE cl_abap_structdescr=>component_table.
    LOOP AT schema INTO DATA(field).
      DATA element TYPE REF TO cl_abap_elemdescr.
      CLEAR element.
      TRY.
          IF field-native_type IS NOT INITIAL.
            element ?= cl_abap_typedescr=>describe_by_name( field-native_type ).
          ELSE.
            CASE field-type_kind.
              WHEN cl_abap_typedescr=>typekind_char.
                element = cl_abap_elemdescr=>get_c( field-length / cl_abap_char_utilities=>charsize ).
              WHEN cl_abap_typedescr=>typekind_num.
                element = cl_abap_elemdescr=>get_n( field-length / cl_abap_char_utilities=>charsize ).
              WHEN cl_abap_typedescr=>typekind_packed.
                element = cl_abap_elemdescr=>get_p( p_length = field-length p_decimals = field-decimals ).
              WHEN cl_abap_typedescr=>typekind_date. element = cl_abap_elemdescr=>get_d( ).
              WHEN cl_abap_typedescr=>typekind_time. element = cl_abap_elemdescr=>get_t( ).
              WHEN cl_abap_typedescr=>typekind_int. element = cl_abap_elemdescr=>get_i( ).
              WHEN cl_abap_typedescr=>typekind_int1. element = cl_abap_elemdescr=>get_int1( ).
              WHEN cl_abap_typedescr=>typekind_int2. element = cl_abap_elemdescr=>get_int2( ).
              WHEN cl_abap_typedescr=>typekind_int8. element = cl_abap_elemdescr=>get_int8( ).
              WHEN cl_abap_typedescr=>typekind_decfloat16. element = cl_abap_elemdescr=>get_decfloat16( ).
              WHEN cl_abap_typedescr=>typekind_decfloat34. element = cl_abap_elemdescr=>get_decfloat34( ).
              WHEN cl_abap_typedescr=>typekind_float. element = cl_abap_elemdescr=>get_f( ).
              WHEN cl_abap_typedescr=>typekind_string. element = cl_abap_elemdescr=>get_string( ).
              WHEN cl_abap_typedescr=>typekind_hex. element = cl_abap_elemdescr=>get_x( field-length ).
              WHEN cl_abap_typedescr=>typekind_xstring. element = cl_abap_elemdescr=>get_xstring( ).
              WHEN OTHERS.
                RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_TYPE' detail = 'Unsupported native dataset field type'.
            ENDCASE.
          ENDIF.
          IF element->type_kind <> field-type_kind OR element->length <> field-length OR element->decimals <> field-decimals.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_SCHEMA' detail = 'Native type definition changed since publication'.
          ENDIF.
          APPEND VALUE #( name = field-name type = element ) TO components.
        CATCH zcx_bn INTO DATA(fault). RAISE EXCEPTION fault.
        CATCH cx_root INTO DATA(error).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_SCHEMA' detail = error->get_text( ).
      ENDTRY.
    ENDLOOP.
    IF components IS INITIAL OR lines( components ) > 100.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_SCHEMA' detail = 'Dataset requires 1 to 100 flat fields'.
    ENDIF.
    TRY.
        result = cl_abap_structdescr=>create( components ).
      CATCH cx_root INTO error.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_SCHEMA' detail = error->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD freeze.
    FIND REGEX '^[A-Za-z][A-Za-z0-9_]{0,59}$' IN name.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_NAME' detail = 'Dataset name must be a 1 to 60 character identifier'.
    ENDIF.
    DATA descriptor TYPE REF TO cl_abap_tabledescr.
    DATA structure TYPE REF TO cl_abap_structdescr.
    TRY.
        descriptor ?= cl_abap_typedescr=>describe_by_data( rows ).
        structure ?= descriptor->get_table_line_type( ).
      CATCH cx_sy_move_cast_error.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_TYPE' detail = 'Expected a native flat structured table'.
    ENDTRY.
    packet-name = name. packet-row_count = lines( rows ).
    DATA(memory) = CONV int8( lines( rows ) ) * structure->length.
    IF memory > max_bytes OR max_bytes < 1 OR max_bytes > 268435456.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_BUDGET' detail = 'Native table exceeds the working-memory budget'.
    ENDIF.
    LOOP AT structure->get_components( ) INTO DATA(component).
      IF component-type->kind <> cl_abap_typedescr=>kind_elem.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_TYPE' detail = 'Nested tables and object/data references are not datasets'.
      ENDIF.
      DATA element TYPE REF TO cl_abap_elemdescr.
      element ?= component-type.
      DATA(field) = VALUE ty_field( name = component-name type_kind = element->type_kind
        length = element->length decimals = element->decimals ).
      IF element->is_ddic_type( ) = abap_true. field-native_type = element->get_relative_name( ). ENDIF.
      APPEND field TO packet-schema.
    ENDLOOP.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<source_row>).
      LOOP AT packet-schema INTO field WHERE type_kind = cl_abap_typedescr=>typekind_string OR
                                             type_kind = cl_abap_typedescr=>typekind_xstring.
        ASSIGN COMPONENT field-name OF STRUCTURE <source_row> TO FIELD-SYMBOL(<value>).
        IF field-type_kind = cl_abap_typedescr=>typekind_string.
          memory = memory + strlen( <value> ) * cl_abap_char_utilities=>charsize.
        ELSE. memory = memory + xstrlen( <value> ). ENDIF.
        IF memory > max_bytes.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_BUDGET' detail = 'Variable-length values exceed the working-memory budget'.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    packet-memory_bytes = CONV i( memory ).
    " Canonical STANDARD/EMPTY KEY table retains the exact published iteration order.
    DATA(table_type) = cl_abap_tabledescr=>create( p_line_type = row_type( packet-schema )
      p_table_kind = cl_abap_tabledescr=>tablekind_std p_key_kind = cl_abap_tabledescr=>keydefkind_empty ).
    DATA copy TYPE REF TO data.
    CREATE DATA copy TYPE HANDLE table_type.
    FIELD-SYMBOLS <copy> TYPE STANDARD TABLE.
    ASSIGN copy->* TO <copy>.
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>). APPEND <row> TO <copy>. ENDLOOP.
    DATA buffer TYPE xstring.
    EXPORT rows = <copy> TO DATA BUFFER buffer COMPRESSION ON.
    packet-byte_count = xstrlen( buffer ).
    packet-content = cl_http_utility=>encode_x_base64( buffer ).
    packet-checksum = digest( packet ).
  ENDMETHOD.
  METHOD thaw.
    IF packet-checksum IS INITIAL OR packet-checksum <> digest( packet ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_INTEGRITY' detail = 'Native dataset checksum mismatch'.
    ENDIF.
    DATA(buffer) = cl_http_utility=>decode_x_base64( packet-content ).
    IF xstrlen( buffer ) <> packet-byte_count OR cl_http_utility=>encode_x_base64( buffer ) <> packet-content.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_INTEGRITY' detail = 'Invalid native dataset buffer'.
    ENDIF.
    DATA(table_type) = cl_abap_tabledescr=>create( p_line_type = row_type( packet-schema )
      p_table_kind = cl_abap_tabledescr=>tablekind_std p_key_kind = cl_abap_tabledescr=>keydefkind_empty ).
    CREATE DATA rows TYPE HANDLE table_type.
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE.
    ASSIGN rows->* TO <rows>.
    TRY.
        IMPORT rows = <rows> FROM DATA BUFFER buffer.
        IF sy-subrc <> 0 OR lines( <rows> ) <> packet-row_count.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_INTEGRITY' detail = 'Native dataset row count mismatch'.
        ENDIF.
      CATCH zcx_bn INTO DATA(fault). RAISE EXCEPTION fault.
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DATASET_INTEGRITY' detail = error->get_text( ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
