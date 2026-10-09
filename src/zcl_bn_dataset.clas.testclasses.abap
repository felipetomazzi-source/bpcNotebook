CLASS ltcl_dataset DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_row,
             category TYPE uj_dim_member, time TYPE uj_dim_member, account TYPE uj_dim_member,
             signeddata TYPE uj_signeddata, ratio TYPE decfloat34, position TYPE i,
           END OF ty_row,
           tt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    METHODS native_round_trip FOR TESTING RAISING zcx_bn.
    METHODS empty_schema FOR TESTING RAISING zcx_bn.
    METHODS private_copies FOR TESTING RAISING zcx_bn.
    METHODS checksums_and_budgets FOR TESTING RAISING zcx_bn.
    METHODS context_handoff FOR TESTING RAISING zcx_bn.
    METHODS unsupported_shapes FOR TESTING RAISING zcx_bn.
    METHODS data_read_policy FOR TESTING RAISING zcx_bn.
ENDCLASS.
CLASS ltcl_dataset IMPLEMENTATION.
  METHOD native_round_trip.
    DATA original TYPE tt_rows.
    DO 12003 TIMES.
      APPEND VALUE #( category = 'Actual' time = '2025.007' account = 'ACCOUNT'
        signeddata = CONV uj_signeddata( '-0.0000001' ) * sy-index
        ratio = CONV decfloat34( '0.000000000000000000000000000000001' ) position = sy-index ) TO original.
    ENDDO.
    DATA(packet) = zcl_bn_dataset=>freeze( name = 'REVENUES' rows = original ).
    DATA(copy) = zcl_bn_dataset=>thaw( packet ).
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN copy->* TO <rows>.
    DATA actual TYPE tt_rows. actual = <rows>.
    cl_abap_unit_assert=>assert_equals( act = actual exp = original ).
    cl_abap_unit_assert=>assert_equals( act = packet-row_count exp = 12003 ).
    cl_abap_unit_assert=>assert_equals( act = packet-schema[ name = 'SIGNEDDATA' ]-native_type exp = 'UJ_SIGNEDDATA' ).
    cl_abap_unit_assert=>assert_equals( act = packet-schema[ name = 'CATEGORY' ]-native_type exp = 'UJ_DIM_MEMBER' ).
  ENDMETHOD.
  METHOD empty_schema.
    DATA empty TYPE tt_rows.
    DATA(packet) = zcl_bn_dataset=>freeze( name = 'EMPTY' rows = empty ).
    DATA(copy) = zcl_bn_dataset=>thaw( packet ).
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN copy->* TO <rows>.
    cl_abap_unit_assert=>assert_equals( act = lines( <rows> ) exp = 0 ).
    DATA(type) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data_ref( copy ) ).
    DATA(structure) = CAST cl_abap_structdescr( type->get_table_line_type( ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( structure->get_components( ) ) exp = 6 ).
  ENDMETHOD.
  METHOD private_copies.
    DATA original TYPE tt_rows.
    original = VALUE #( ( signeddata = 1 position = 7 ) ).
    DATA(packet) = zcl_bn_dataset=>freeze( name = 'PRIVATE' rows = original ).
    original[ 1 ]-signeddata = 999.
    DATA(first) = zcl_bn_dataset=>thaw( packet ).
    DATA(second) = zcl_bn_dataset=>thaw( packet ).
    FIELD-SYMBOLS <a> TYPE STANDARD TABLE. FIELD-SYMBOLS <b> TYPE STANDARD TABLE.
    ASSIGN first->* TO <a>. ASSIGN second->* TO <b>.
    CLEAR <a>.
    DATA actual TYPE tt_rows. actual = <b>.
    cl_abap_unit_assert=>assert_equals( act = actual[ 1 ]-signeddata exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = packet-row_count exp = 1 ).
  ENDMETHOD.
  METHOD checksums_and_budgets.
    DATA rows TYPE tt_rows.
    rows = VALUE #( ( signeddata = 1 ) ).
    DATA(packet) = zcl_bn_dataset=>freeze( name = 'SAFE' rows = rows ).
    packet-content = packet-content && 'AAAA'.
    TRY.
        zcl_bn_dataset=>thaw( packet ).
        cl_abap_unit_assert=>fail( 'Corrupt native payload accepted' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'DATASET_INTEGRITY' ).
    ENDTRY.
    TRY.
        zcl_bn_dataset=>freeze( name = 'LIMIT' rows = rows max_bytes = 1 ).
        cl_abap_unit_assert=>fail( 'Budget silently truncated the input' ).
      CATCH zcx_bn INTO error.
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'DATASET_BUDGET' ).
    ENDTRY.
  ENDMETHOD.
  METHOD context_handoff.
    DATA rows TYPE tt_rows.
    rows = VALUE #( ( signeddata = 42 position = 1 ) ).
    DATA(publisher) = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'first' ).
    publisher->publish_dataset( name = 'FULL' rows = rows ).
    rows[ 1 ]-signeddata = 99.
    DATA(consumer) = NEW zcl_bn_context( inputs = VALUE #( )
      bindings = VALUE #( ( cell_id = 'first' run_id = 'RUN' revision = 1 ) )
      dependencies = VALUE #( ( `first` ) ) cell_id = 'second' run_id = 'RUN'
      live_datasets = VALUE #( ( cell_id = 'first' packets = publisher->dataset_packets( ) ) ) ).
    DATA(copy) = consumer->read_dataset( dependency = 'first' name = 'FULL' ).
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN copy->* TO <rows>.
    DATA actual TYPE tt_rows. actual = <rows>.
    cl_abap_unit_assert=>assert_equals( act = actual[ 1 ]-signeddata exp = 42 ).
    cl_abap_unit_assert=>assert_equals( act = publisher->tables[ 1 ]-total_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = consumer->dataset_reads[ 1 ]-name exp = 'FULL' ).
    TRY.
        consumer->read_dataset( dependency = 'unrelated' name = 'FULL' ).
        cl_abap_unit_assert=>fail( 'Undeclared dependency accepted' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'DEPENDENCY' ).
    ENDTRY.
  ENDMETHOD.
  METHOD unsupported_shapes.
    TYPES: BEGIN OF ty_nested, rows TYPE tt_rows, END OF ty_nested.
    DATA nested TYPE STANDARD TABLE OF ty_nested.
    TRY.
        zcl_bn_dataset=>freeze( name = 'NESTED' rows = nested ).
        cl_abap_unit_assert=>fail( 'Nested tables accepted' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'DATASET_TYPE' ).
    ENDTRY.
  ENDMETHOD.
  METHOD data_read_policy.
    DATA(context) = NEW zcl_bn_context( inputs = VALUE #( )
      bindings = VALUE #( ( cell_id = 'first' run_id = 'OLD' revision = 1 ) )
      dependencies = VALUE #( ( `first` ) ) cell_id = 'second' run_id = 'NEW' ).
    TRY.
        context->check_data_snapshot( ).
        cl_abap_unit_assert=>fail( 'Fresh reads with reused prior-run state accepted' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'DATA_SNAPSHOT' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
