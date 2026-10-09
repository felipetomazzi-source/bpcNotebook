CLASS zcl_bn_validation_check DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION. INTERFACES if_oo_adt_classrun.
ENDCLASS.
CLASS zcl_bn_validation_check IMPLEMENTATION.
 METHOD if_oo_adt_classrun~main.
  TRY.
   DATA(io) = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'validation' ).
   TYPES: BEGIN OF ty_result, account TYPE uj_dim_member, time TYPE uj_dim_member, signeddata TYPE uj_sdata, END OF ty_result.
   TYPES tt_result TYPE STANDARD TABLE OF ty_result WITH DEFAULT KEY.
   DATA original TYPE tt_result. DATA notebook TYPE tt_result.
   original = VALUE #( ( account = 'A' time = 'P1' signeddata = '1.0000001' )
    ( account = 'B' time = 'P1' signeddata = '-50' ) ( account = 'C' time = 'P1' signeddata = '20' ) ).
   notebook = VALUE #( ( account = 'C' time = 'P1' signeddata = '20' )
    ( account = 'A' time = 'P1' signeddata = '1.0000002' ) ( account = 'D' time = 'P1' signeddata = '9' ) ).
   DATA(summary) = io->compare_results( name = 'EXACT' original = original notebook = notebook preview_rows = 1 ).
   ASSERT summary-added = 1 AND summary-missing = 1 AND summary-changed = 1 AND summary-unchanged = 1.
   ASSERT io->tables[ name = 'EXACT/DIFFERENCES' ]-row_count = 1.
   ASSERT io->tables[ name = 'EXACT/DIFFERENCES' ]-total_count = 3.
   out->write( 'BNCHECK|all dimensions and exact native SIGNEDDATA; added/missing/changed; bounded differences' ).
   CLEAR: original, notebook.
   DO 6001 TIMES.
    APPEND VALUE #( account = |A{ sy-index }| time = 'P' signeddata = '1.0000001' ) TO original.
    APPEND VALUE #( account = |A{ sy-index }| time = 'P' signeddata = '1.0000001' ) TO notebook.
   ENDDO.
   notebook[ 6001 ]-signeddata = '1.0000002'.
   summary = io->compare_results( name = 'FULL' original = original notebook = notebook ).
   ASSERT summary-changed = 1 AND summary-unchanged = 6000.
   out->write( 'BNCHECK|comparison examines complete 6001-row native inputs beyond the preview limit' ).
   APPEND original[ 1 ] TO original.
   TRY.
    summary = io->compare_results( name = 'DUPLICATE' original = original notebook = notebook ).
    RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST' detail = 'Duplicate key was accepted'.
   CATCH zcx_bn INTO DATA(duplicate). ASSERT duplicate->code = 'COMPARISON_DUPLICATE_KEY'. ENDTRY.
   TYPES: BEGIN OF ty_bad, account TYPE uj_dim_member, time TYPE uj_dim_member, signeddata TYPE decfloat34, END OF ty_bad.
   DATA bad TYPE STANDARD TABLE OF ty_bad WITH DEFAULT KEY.
   TRY.
    summary = io->compare_results( name = 'BAD_SCHEMA' original = notebook notebook = bad ).
    RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST' detail = 'Wrong native amount type accepted'.
   CATCH zcx_bn INTO DATA(schema). ASSERT schema->code = 'COMPARISON_SCHEMA'. ENDTRY.
   DATA empty TYPE tt_result.
   summary = io->compare_results( name = 'EMPTY' original = empty notebook = empty ).
   ASSERT summary-original_rows = 0 AND summary-notebook_rows = 0.
   ASSERT lines( io->tables[ name = 'EMPTY/DIFFERENCES' ]-schema ) = 5.
   out->write( 'BNCHECK|duplicate keys and mismatched schemas fail; empty results retain full difference schema' ).
   DATA(definition) = VALUE zcl_bn_types=>ty_notebook( environment = 'CH_PLANNING' model = 'DEMREVID'
    inputs = VALUE #( ( name = 'CATEGORY' type = 'member' dimension = 'CATEGORY' required = abap_true selected = VALUE #( ( `Actual` ) ) )
      ( name = 'TIME' type = 'range' dimension = 'TIME' hierarchy = 'PARENTH1' required = abap_true selected = VALUE #( ( `2025.007` ) ) ) ) ).
   zcl_bn_bpc=>resolve( EXPORTING complete = abap_true CHANGING notebook = definition ).
   DATA(live) = NEW zcl_bn_context( environment = 'CH_PLANNING' model = 'DEMREVID' inputs = definition-inputs
     bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'live' ).
   DATA(adapter) = live->bpc_model( ).
   DATA(ref) = adapter->read_data( max_rows = 100000 ).
   FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN ref->* TO <rows>.
   ASSERT lines( live->reads ) = 1.
   ASSERT live->reads[ 1 ]-row_count = lines( <rows> ) AND live->reads[ 1 ]-state = 'succeeded'.
   ASSERT live->reads[ 1 ]-effective_filters[ dimension = 'CATEGORY' ]-members[ 1 ] = 'Actual'.
   ASSERT live->reads[ 1 ]-effective_filters[ dimension = 'TIME' ]-members[ 1 ] = '2025.007'.
   ASSERT live->reads[ 1 ]-security = 'SAP_AUTH_ON; QUERY_BADI_OFF'.
   out->write( 'BNCHECK|' && |Actual / 2025.007 complete read count={ lines( <rows> ) }; frozen filters and security recorded| ).
   definition-inputs[ name = 'TIME' ]-selected = VALUE #( ( `2027.006` ) ).
   zcl_bn_bpc=>resolve( EXPORTING complete = abap_true CHANGING notebook = definition ).
   DATA(seed) = NEW zcl_bn_context( environment = 'CH_PLANNING' model = 'DEMREVID' inputs = definition-inputs
     bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'seed' ).
   adapter = seed->bpc_model( ). ref = adapter->read_data( max_rows = 100000 ). ASSIGN ref->* TO <rows>.
   ASSERT lines( <rows> ) > 2. DELETE <rows> FROM 4.
   DATA(fixtures) = VALUE zcl_bn_context=>tt_fixtures( ( environment = 'CH_PLANNING' model = 'DEMREVID' rows = ref ) ).
   DATA(test) = NEW zcl_bn_context( environment = 'CH_PLANNING' model = 'DEMREVID' inputs = definition-inputs
     bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'fixtures' ).
   test->enable_fixtures( fixtures ).
   adapter = test->bpc_model( ). DATA(first) = adapter->read_data( ). DATA(second) = adapter->read_data( ).
   FIELD-SYMBOLS <first> TYPE STANDARD TABLE. ASSIGN first->* TO <first>.
   FIELD-SYMBOLS <second> TYPE STANDARD TABLE. ASSIGN second->* TO <second>.
   ASSERT <first> = <second> AND lines( <first> ) = 3.
   ASSERT test->reads[ 1 ]-source = 'fixture' AND test->reads[ 1 ]-packages = 0.
   ASSERT test->reads[ 2 ]-source = 'fixture'.
   READ TABLE <first> ASSIGNING FIELD-SYMBOL(<row>) INDEX 1.
   FIELD-SYMBOLS <amount> TYPE any. ASSIGN COMPONENT 'SIGNEDDATA' OF STRUCTURE <row> TO <amount>. <amount> = 999.
   ASSERT <first> <> <second>.
   DATA(third) = adapter->read_data( ). FIELD-SYMBOLS <third> TYPE STANDARD TABLE. ASSIGN third->* TO <third>.
   ASSERT <third> = <second>.
   DELETE <rows> FROM 1. DATA(fourth) = adapter->read_data( ). ASSIGN fourth->* TO <third>. ASSERT <third> = <second>.
   out->write( 'BNCHECK|complete fixtures are privately frozen; identical inputs and returned copy isolation; no live query' ).
   TRY.
    test->allocation_result( name = 'FORBIDDEN' rows = <second> kind = 'delta' ).
    RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST' detail = 'Fixture posting accepted'.
   CATCH zcx_bn INTO DATA(posting). ASSERT posting->code = 'FIXTURE_POSTING'. ENDTRY.
   TRY.
    ref = test->fixture_read( environment = 'CH_PLANNING' model = 'MISSING' filters = VALUE #( ) max_rows = 100 ).
    RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST' detail = 'Live fallback accepted'.
   CATCH zcx_bn INTO DATA(missing). ASSERT missing->code = 'FIXTURE_MISSING'. ENDTRY.
   TRY.
    ref = adapter->read_data( max_rows = 1 ).
    RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST' detail = 'Partial fixture input accepted'.
   CATCH zcx_bn INTO DATA(overflow). ASSERT overflow->code = 'BPC_READ_LIMIT'. ENDTRY.
   ASSERT test->reads[ lines( test->reads ) ]-state = 'failed'.
   TRY.
    seed->enable_fixtures( fixtures ).
    RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST' detail = 'Mixed live and fixture context accepted'.
   CATCH zcx_bn INTO DATA(mixed). ASSERT mixed->code = 'FIXTURE_MODE'. ENDTRY.
   DATA(logic) = NEW zcl_bn_context( environment = 'CH_PLANNING' model = 'DEMREVID' inputs = definition-inputs
    bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'logic' logic_call = abap_true ).
   TRY.
    logic->enable_fixtures( fixtures ).
    RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST' detail = 'Script Logic fixtures accepted'.
   CATCH zcx_bn INTO DATA(logic_error). ASSERT logic_error->code = 'FIXTURE_MODE'. ENDTRY.
   out->write( 'BNCHECK|fixture posting, live fallback, partial inputs, mixed reads and Script Logic injection rejected' ).
   ref = second.
   TYPES: BEGIN OF ty_snapshot, rows TYPE REF TO data, END OF ty_snapshot.
   DATA(original_result) = second. DATA(notebook_result) = fourth.
   summary = test->compare_results( name = 'IDENTICAL' original = <second> notebook = <third> ).
   ASSERT summary-unchanged = 3 AND summary-added = 0 AND summary-missing = 0 AND summary-changed = 0.
   out->write( 'BNCHECK|native comparison accepts identical complete multidimensional fixture result tables' ).
  CATCH cx_root INTO DATA(error).
   out->write( 'BNERROR|' && error->get_text( ) ).
  ENDTRY.
 ENDMETHOD.
ENDCLASS.
