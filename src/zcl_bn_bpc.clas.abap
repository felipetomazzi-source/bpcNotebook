CLASS zcl_bn_bpc DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_item,
             id TYPE string, description TYPE string, dim_type TYPE string,
             is_node TYPE abap_bool, parent TYPE string,
           END OF ty_item,
           tt_items TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY,
           BEGIN OF ty_metadata,
             items TYPE tt_items, hierarchies TYPE zcl_bn_types=>tt_ids,
             more TYPE abap_bool,
           END OF ty_metadata.
    CLASS-METHODS metadata IMPORTING kind TYPE string environment TYPE string model TYPE string
      dimension TYPE string hierarchy TYPE string search TYPE string offset TYPE i DEFAULT 0
      RETURNING VALUE(result) TYPE ty_metadata RAISING zcx_bn.
    CLASS-METHODS resolve IMPORTING complete TYPE abap_bool DEFAULT abap_false
      CHANGING notebook TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
    CLASS-METHODS validate_frozen IMPORTING notebook TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
    CLASS-METHODS current_view IMPORTING inputs TYPE zcl_bn_types=>tt_inputs
      RETURNING VALUE(result) TYPE ujk_t_cv RAISING zcx_bn.
    CLASS-METHODS validate_scope IMPORTING environment TYPE string model TYPE string scope TYPE ujk_t_cv
      RAISING zcx_bn.
    CLASS-METHODS scoped_view IMPORTING inputs TYPE zcl_bn_types=>tt_inputs scope TYPE ujk_t_cv
      RETURNING VALUE(result) TYPE ujk_t_cv RAISING zcx_bn.
    CLASS-METHODS script_parameters IMPORTING inputs TYPE zcl_bn_types=>tt_inputs
      RETURNING VALUE(result) TYPE ujk_t_script_logic_hashtable RAISING zcx_bn.
    TYPES: BEGIN OF ty_filter,
             dimension TYPE string, members TYPE zcl_bn_types=>tt_ids,
           END OF ty_filter,
           tt_filters TYPE STANDARD TABLE OF ty_filter WITH DEFAULT KEY,
           BEGIN OF ty_field,
             name TYPE string, type TYPE string, length TYPE i, decimals TYPE i,
             source TYPE string,
           END OF ty_field,
           tt_fields TYPE STANDARD TABLE OF ty_field WITH DEFAULT KEY.
    METHODS children IMPORTING member TYPE string hierarchy TYPE string
      RETURNING VALUE(result) TYPE zcl_bn_types=>tt_ids RAISING zcx_bn.
    METHODS fiscal_links IMPORTING ids TYPE zcl_bn_types=>tt_ids
      RETURNING VALUE(result) TYPE zcl_bn_types=>tt_fiscal_links RAISING zcx_bn.
    CLASS-METHODS validate_result IMPORTING environment TYPE string model TYPE string rows TYPE ANY TABLE
      output_view TYPE ujk_t_cv RAISING zcx_bn.
    METHODS constructor IMPORTING environment TYPE string model TYPE string dimension TYPE string DEFAULT ''
      inputs TYPE zcl_bn_types=>tt_inputs OPTIONAL scope TYPE ujk_t_cv OPTIONAL
      diagnostics TYPE REF TO zcl_bn_context OPTIONAL read_scope TYPE string DEFAULT 'calculation' RAISING zcx_bn.
    CLASS-METHODS validate_fixture IMPORTING environment TYPE string model TYPE string rows TYPE ANY TABLE RAISING zcx_bn.
    METHODS member_data IMPORTING ids TYPE zcl_bn_types=>tt_ids OPTIONAL
      RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
    METHODS properties RETURNING VALUE(result) TYPE tt_fields RAISING zcx_bn.
    METHODS hierarchies RETURNING VALUE(result) TYPE zcl_bn_types=>tt_ids RAISING zcx_bn.
    METHODS property IMPORTING member TYPE string name TYPE string source TYPE string DEFAULT 'stored'
      RETURNING VALUE(result) TYPE string RAISING zcx_bn.
    METHODS dimensions RETURNING VALUE(result) TYPE tt_items RAISING zcx_bn.
    METHODS fields RETURNING VALUE(result) TYPE tt_fields RAISING zcx_bn.
    METHODS read_data IMPORTING filters TYPE tt_filters OPTIONAL max_rows TYPE i DEFAULT 100000
      RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.
    CLASS-METHODS merge_filters IMPORTING frozen TYPE tt_filters requested TYPE tt_filters
      RETURNING VALUE(result) TYPE tt_filters RAISING zcx_bn.
    CLASS-METHODS describe_table IMPORTING table TYPE REF TO data source TYPE string
      RETURNING VALUE(result) TYPE tt_fields RAISING zcx_bn.
  PROTECTED SECTION.
    DATA mv_environment TYPE string.
    DATA mv_model TYPE string.
    DATA mv_dimension TYPE string.
    " Future providers override this hook explicitly; stored properties are never a substitute.
    METHODS virtual_property IMPORTING member TYPE string name TYPE string
      RETURNING VALUE(result) TYPE string RAISING zcx_bn.
  PRIVATE SECTION.
    DATA mo_diagnostics TYPE REF TO zcl_bn_context.
    DATA mv_read_scope TYPE string.
    DATA mt_inputs TYPE zcl_bn_types=>tt_inputs.
    DATA mt_scope TYPE ujk_t_cv.
    CLASS-METHODS validate_filters IMPORTING environment TYPE string model TYPE string filters TYPE tt_filters RAISING zcx_bn.
    CLASS-METHODS model_table IMPORTING dimensions TYPE tt_items
      RETURNING VALUE(result) TYPE REF TO data RAISING zcx_bn.

    CLASS-METHODS context IMPORTING environment TYPE string model TYPE string OPTIONAL
      RETURNING VALUE(result) TYPE tt_items RAISING zcx_bn.
    CLASS-METHODS permitted IMPORTING dimension TYPE string members TYPE uje_t_mem
      RETURNING VALUE(result) TYPE uje_t_mem RAISING zcx_bn.
    CLASS-METHODS list_members IMPORTING environment TYPE string model TYPE string dimension TYPE string
      hierarchy TYPE string RETURNING VALUE(result) TYPE ty_metadata RAISING zcx_bn.
    CLASS-METHODS bases IMPORTING environment TYPE string dimension TYPE string hierarchy TYPE string
      member TYPE string is_node TYPE abap_bool RETURNING VALUE(result) TYPE zcl_bn_types=>tt_ids RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_bpc IMPLEMENTATION.
  METHOD constructor.
    mo_diagnostics = diagnostics. mv_read_scope = read_scope.
    IF environment IS INITIAL OR model IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_CONTEXT' detail = 'An authorized environment and model are required'.
    ENDIF.
    DATA(available) = context( environment = environment model = model ).
    IF dimension IS NOT INITIAL AND NOT line_exists( available[ id = dimension ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_DIMENSION' detail = 'Dimension is not in this model'.
    ENDIF.
    mv_environment = environment. mv_model = model. mv_dimension = dimension. mt_inputs = inputs. mt_scope = scope.
  ENDMETHOD.
  METHOD children.
    DATA(list) = list_members( environment = mv_environment model = mv_model dimension = mv_dimension hierarchy = hierarchy ).
    IF NOT line_exists( list-items[ id = member ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Hierarchy member unavailable' status = 403.
    ENDIF.
    result = bases( environment = mv_environment dimension = mv_dimension hierarchy = hierarchy
      member = member is_node = list-items[ id = member ]-is_node ).
    validate_filters( environment = mv_environment model = mv_model
      filters = VALUE #( ( dimension = mv_dimension members = result ) ) ).
  ENDMETHOD.
  METHOD fiscal_links.
    DATA(ref) = member_data( ids ).
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <id> TYPE any.
    FIELD-SYMBOLS <prior> TYPE any.
    FIELD-SYMBOLS <next> TYPE any.
    ASSIGN ref->* TO <rows>.
    LOOP AT <rows> ASSIGNING FIELD-SYMBOL(<row>).
      UNASSIGN: <id>, <prior>, <next>.
      ASSIGN COMPONENT 'ID' OF STRUCTURE <row> TO <id>.
      ASSIGN COMPONENT 'PRIOR_PERIOD' OF STRUCTURE <row> TO <prior>.
      ASSIGN COMPONENT 'NEXT_PERIOD' OF STRUCTURE <row> TO <next>.
      IF <id> IS NOT ASSIGNED OR <prior> IS NOT ASSIGNED OR <next> IS NOT ASSIGNED.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FISCAL_METADATA' detail = 'Explicit PRIOR_PERIOD and NEXT_PERIOD metadata required'.
      ENDIF.
      APPEND VALUE #( dimension = mv_dimension member = <id> prior = <prior> next = <next> ) TO result.
    ENDLOOP.
  ENDMETHOD.
  METHOD validate_result.
    DATA(adapter) = NEW zcl_bn_bpc( environment = environment model = model ).
    DATA(dims) = adapter->dimensions( ).
    DATA(schema) = describe_table( table = REF #( rows ) source = 'result' ).
    IF lines( schema ) <> lines( dims ) + 1 OR NOT line_exists( schema[ name = 'SIGNEDDATA' ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_SCHEMA' detail = 'Result must contain exactly the model dimensions and SIGNEDDATA'.
    ENDIF.
    DATA(table_type) = CAST cl_abap_tabledescr( cl_abap_tabledescr=>describe_by_data( rows ) ).
    DATA(line_type) = CAST cl_abap_structdescr( table_type->get_table_line_type( ) ).
    DATA(components) = line_type->get_components( ).
    DATA(amount_type) = components[ name = 'SIGNEDDATA' ]-type.
    DATA native_amount TYPE uj_signeddata.
    DATA(native_type) = cl_abap_elemdescr=>describe_by_data( native_amount ).
    IF amount_type->type_kind <> native_type->type_kind OR amount_type->length <> native_type->length OR
       amount_type->decimals <> native_type->decimals.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_SCHEMA' detail = 'SIGNEDDATA must preserve the native UJ_SIGNEDDATA numeric type'.
    ENDIF.
    DATA(context_dims) = context( environment = environment model = model ).
    DATA(ctx) = cl_uj_context=>get_cur_context( ).
    FIELD-SYMBOLS <member> TYPE any.
    LOOP AT dims INTO DATA(dim).
      IF NOT line_exists( schema[ name = dim-id ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_SCHEMA' detail = 'A model dimension is missing'.
      ENDIF.
      DATA(ids) = VALUE zcl_bn_types=>tt_ids( ).
      LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
        UNASSIGN <member>. ASSIGN COMPONENT dim-id OF STRUCTURE <row> TO <member>.
        IF <member> IS NOT ASSIGNED OR <member> IS INITIAL.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_MEMBER' detail = 'Result member missing'.
        ENDIF.
        READ TABLE output_view INTO DATA(view) WITH KEY dimension = dim-id.
        IF sy-subrc = 0 AND NOT line_exists( view-member[ table_line = <member> ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_SCOPE' detail = 'Output exceeds calculation or caller scope' status = 403.
        ENDIF.
        APPEND CONV string( <member> ) TO ids.
      ENDLOOP.
      SORT ids. DELETE ADJACENT DUPLICATES FROM ids.
      IF ids IS INITIAL. CONTINUE. ENDIF.
      validate_filters( environment = environment model = model filters = VALUE #( ( dimension = dim-id members = ids ) ) ).
      context( environment = environment model = model ). ctx = cl_uj_context=>get_cur_context( ).
      DATA writable TYPE uje_t_mem. CLEAR writable.
      LOOP AT ids INTO DATA(id). APPEND CONV #( id ) TO writable. ENDLOOP.
      ctx->check_member_access( EXPORTING i_dim_name = CONV #( dim-id ) i_rw = 'W' it_mem_list = writable
        IMPORTING et_mem_list = DATA(allowed) ).
      LOOP AT writable INTO DATA(wanted).
        IF NOT line_exists( allowed[ table_line = wanted ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_AUTH' detail = 'Result write authorization denied' status = 403.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
  METHOD member_data.
    DATA(available) = context( environment = mv_environment model = mv_model ).
    IF mv_dimension IS INITIAL OR NOT line_exists( available[ id = mv_dimension ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_DIMENSION' detail = 'Use a dimension adapter for member access'.
    ENDIF.
    TRY.
        DATA(dim) = NEW cl_uja_dim( i_appset_id = CONV #( mv_environment ) i_dimension = CONV #( mv_dimension ) ).
        DATA hierarchy_info TYPE uja_t_hier.
        DATA hierarchy_names TYPE uja_t_hier_name.
        IF dim->has_hier( ) = abap_true. dim->get_hier_list( IMPORTING et_hier_info = hierarchy_info ). ENDIF.
        LOOP AT hierarchy_info INTO DATA(h). APPEND h-hier_name TO hierarchy_names. ENDLOOP.
        DATA selected TYPE uja_t_dim_member.
        LOOP AT ids INTO DATA(id).
          IF id IS INITIAL OR strlen( id ) > 32.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_MEMBER' detail = 'A member ID must contain 1 to 32 characters'.
          ENDIF.
          APPEND CONV #( id ) TO selected.
        ENDLOOP.
        dim->read_mbr_data( EXPORTING it_hier_list = hierarchy_names if_inc_txt = abap_true
          it_sel_mbr = selected i_appl_id = CONV #( mv_model ) IMPORTING er_data = result ).
        FIELD-SYMBOLS <rows> TYPE STANDARD TABLE.
        FIELD-SYMBOLS <row> TYPE any.
        FIELD-SYMBOLS <id> TYPE any.
        ASSIGN result->* TO <rows>.
        DATA all_ids TYPE uje_t_mem.
        LOOP AT <rows> ASSIGNING <row>.
          ASSIGN COMPONENT 'ID' OF STRUCTURE <row> TO <id>.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA' detail = 'Member ID column missing'.
          ENDIF.
          APPEND CONV #( <id> ) TO all_ids.
        ENDLOOP.
        DATA(authorized) = permitted( dimension = mv_dimension members = all_ids ).
        LOOP AT ids INTO id.
          IF NOT line_exists( authorized[ table_line = id ] ).
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Member unavailable or unauthorized' status = 403.
          ENDIF.
        ENDLOOP.
        LOOP AT <rows> ASSIGNING <row>.
          DATA(index) = sy-tabix.
          ASSIGN COMPONENT 'ID' OF STRUCTURE <row> TO <id>.
          IF NOT line_exists( authorized[ table_line = <id> ] ). DELETE <rows> INDEX index. ENDIF.
        ENDLOOP.
      CATCH zcx_bn INTO DATA(error). RAISE EXCEPTION error.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA' detail = native->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD describe_table.
    TRY.
        DATA(table_type) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data_ref( table ) ).
        DATA(line_type) = CAST cl_abap_structdescr( table_type->get_table_line_type( ) ).
        LOOP AT line_type->get_components( ) INTO DATA(component).
          APPEND VALUE #( name = component-name type = CONV #( component-type->type_kind )
            length = COND #( WHEN component-type->type_kind = 'C' OR component-type->type_kind = 'N'
              THEN component-type->length / cl_abap_char_utilities=>charsize ELSE component-type->length )
            decimals = component-type->decimals source = source ) TO result.
        ENDLOOP.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_SCHEMA' detail = native->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD properties.
    result = describe_table( table = member_data( ) source = 'stored' ).
  ENDMETHOD.
  METHOD hierarchies.
    DATA(available) = context( environment = mv_environment model = mv_model ).
    IF mv_dimension IS INITIAL OR NOT line_exists( available[ id = mv_dimension ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_DIMENSION' detail = 'Use a dimension adapter for hierarchies'.
    ENDIF.
    TRY.
        DATA(dim) = NEW cl_uja_dim( i_appset_id = CONV #( mv_environment ) i_dimension = CONV #( mv_dimension ) ).
        DATA info TYPE uja_t_hier.
        IF dim->has_hier( ) = abap_true. dim->get_hier_list( IMPORTING et_hier_info = info ). ENDIF.
        LOOP AT info INTO DATA(h). APPEND CONV string( h-hier_name ) TO result. ENDLOOP.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_HIERARCHY' detail = native->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD property.
    DATA(rows) = member_data( VALUE #( ( member ) ) ).
    IF source = 'virtual'. result = virtual_property( member = member name = name ). RETURN. ENDIF.
    IF source <> 'stored' OR name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_PROPERTY' detail = 'Specify a stored property name'.
    ENDIF.
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <row> TYPE any.
    FIELD-SYMBOLS <value> TYPE any.
    ASSIGN rows->* TO <rows>.
    READ TABLE <rows> ASSIGNING <row> INDEX 1.
    ASSIGN COMPONENT name OF STRUCTURE <row> TO <value>.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_PROPERTY' detail = 'Unknown stored property; discover properties first'.
    ENDIF.
    result = <value>.
  ENDMETHOD.
  METHOD virtual_property.
    RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_VIRTUAL_PROPERTY'
      detail = 'No virtual-property provider is installed; stored properties cannot replace computed properties'.
  ENDMETHOD.
  METHOD dimensions.
    result = context( environment = mv_environment model = mv_model ).
  ENDMETHOD.
  METHOD model_table.
    TRY.
        DATA components TYPE cl_abap_structdescr=>component_table.
        LOOP AT dimensions INTO DATA(dim).
          APPEND VALUE #( name = dim-id type = cl_abap_elemdescr=>get_c( 32 ) ) TO components.
        ENDLOOP.
        APPEND VALUE #( name = 'SIGNEDDATA' type = CAST cl_abap_datadescr(
          cl_abap_elemdescr=>describe_by_name( 'UJ_SDATA' ) ) ) TO components.
        DATA(structure) = cl_abap_structdescr=>get( components ).
        DATA(table_type) = cl_abap_tabledescr=>get( p_line_type = structure ).
        CREATE DATA result TYPE HANDLE table_type.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_SCHEMA' detail = native->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD fields.
    result = describe_table( table = model_table( dimensions( ) ) source = 'model' ).
  ENDMETHOD.
  METHOD merge_filters.
    result = frozen.
    LOOP AT requested INTO DATA(filter).
      IF filter-dimension IS INITIAL OR filter-members IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_FILTER' detail = 'Each filter requires a dimension and explicit member IDs'.
      ENDIF.
      IF lines( filter-members ) > 10000.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_FILTER' detail = 'Maximum 10000 IDs per filter'.
      ENDIF.
      READ TABLE result ASSIGNING FIELD-SYMBOL(<existing>) WITH KEY dimension = filter-dimension.
      IF sy-subrc <> 0. APPEND filter TO result. CONTINUE. ENDIF.
      DATA intersection TYPE zcl_bn_types=>tt_ids.
      CLEAR intersection.
      LOOP AT <existing>-members INTO DATA(id).
        IF line_exists( filter-members[ table_line = id ] ). APPEND id TO intersection. ENDIF.
      ENDLOOP.
      IF intersection IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_FILTER' detail = 'Filter conflicts with the frozen run selection'.
      ENDIF.
      <existing>-members = intersection.
    ENDLOOP.
    LOOP AT result ASSIGNING <existing>.
      SORT <existing>-members. DELETE ADJACENT DUPLICATES FROM <existing>-members.
    ENDLOOP.
  ENDMETHOD.
  METHOD validate_filters.
    LOOP AT filters INTO DATA(filter).
      IF filter-members IS INITIAL OR lines( filter-members ) > 10000.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_FILTER' detail = 'Filters require 1 to 10000 explicit base IDs'.
      ENDIF.
      DATA(available) = list_members( environment = environment model = model dimension = filter-dimension hierarchy = '' ).
      LOOP AT filter-members INTO DATA(id).
        IF id IS INITIAL OR strlen( id ) > 32 OR NOT line_exists( available-items[ id = id ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Filter member unavailable or unauthorized' status = 403.
        ENDIF.
        IF available-items[ id = id ]-is_node = abap_true.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_BASE_FILTER'
            detail = 'Model filters accept base IDs only; use frozen io->range() for hierarchy selections'.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
  METHOD validate_fixture.
    DATA(adapter) = NEW zcl_bn_bpc( environment = environment model = model ).
    DATA(dimensions) = adapter->dimensions( ).
    DATA(expected) = model_table( dimensions ).
    DATA supplied TYPE REF TO cl_abap_structdescr.
    DATA native TYPE REF TO cl_abap_structdescr.
    TRY.
        supplied ?= CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( rows ) )->get_table_line_type( ).
        native ?= CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data_ref( expected ) )->get_table_line_type( ).
      CATCH cx_root.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_SCHEMA' detail = 'Fixture must have the full native flat model schema'.
    ENDTRY.
    DATA supplied_fields TYPE cl_abap_structdescr=>component_table.
    supplied_fields = supplied->get_components( ).
    DATA native_fields TYPE cl_abap_structdescr=>component_table.
    native_fields = native->get_components( ).
    IF lines( supplied_fields ) <> lines( native_fields ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_SCHEMA' detail = 'Fixture must include exactly all dimensions and SIGNEDDATA'.
    ENDIF.
    LOOP AT native_fields INTO DATA(field).
      READ TABLE supplied_fields INTO DATA(actual) WITH KEY name = field-name.
      IF sy-subrc <> 0 OR actual-type->kind <> cl_abap_typedescr=>kind_elem.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_SCHEMA' detail = 'Missing or nested fixture field'.
      ENDIF.
      IF actual-type->type_kind <> field-type->type_kind OR actual-type->length <> field-type->length
         OR actual-type->decimals <> field-type->decimals.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_SCHEMA' detail = 'Fixture field types must match the native model exactly'.
      ENDIF.
    ENDLOOP.
    DATA filters TYPE tt_filters.
    LOOP AT dimensions INTO DATA(dimension).
      DATA filter TYPE ty_filter. CLEAR filter. filter-dimension = dimension-id.
      FIELD-SYMBOLS <value> TYPE any.
      LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
        ASSIGN COMPONENT dimension-id OF STRUCTURE <row> TO <value>.
        APPEND CONV string( <value> ) TO filter-members.
      ENDLOOP.
      SORT filter-members. DELETE ADJACENT DUPLICATES FROM filter-members.
      IF filter-members IS NOT INITIAL. APPEND filter TO filters. ENDIF.
    ENDLOOP.
    validate_filters( environment = environment model = model filters = filters ).
  ENDMETHOD.
  METHOD read_data.
    DATA(diagnostic) = VALUE zcl_bn_context=>ty_read( environment = mv_environment model = mv_model
      scope = mv_read_scope source = 'live SAP' security = 'SAP_AUTH_ON; QUERY_BADI_OFF'
      state = 'failed' row_count = -1 max_rows = max_rows ).
    TRY.
    IF mv_dimension IS NOT INITIAL OR max_rows < 1 OR max_rows > 1000000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_READ' detail = 'Use a model adapter; row limit must be 1 to 1000000'.
    ENDIF.
    DATA(available) = dimensions( ).
    DATA frozen TYPE tt_filters.
    DATA(cv) = scoped_view( inputs = mt_inputs scope = mt_scope ).
    LOOP AT cv INTO DATA(view).
      IF NOT line_exists( available[ id = view-dimension ] ). CONTINUE. ENDIF.
      DATA fixed TYPE ty_filter.
      CLEAR fixed. fixed-dimension = view-dimension.
      LOOP AT view-member INTO DATA(member). APPEND CONV string( member ) TO fixed-members. ENDLOOP.
      APPEND fixed TO frozen.
    ENDLOOP.
    " Validate requested IDs before intersection so unauthorized/out-of-scope IDs are never silently discarded.
    validate_filters( environment = mv_environment model = mv_model filters = filters ).
    validate_filters( environment = mv_environment model = mv_model filters = frozen ).
    DATA(effective) = merge_filters( frozen = frozen requested = filters ).
    diagnostic-effective_filters = effective.
    DATA selections TYPE uj0_t_sel.
    LOOP AT effective INTO DATA(filter).
      " Base IDs were validated above; only equality filters reach the query adapter.
      LOOP AT filter-members INTO DATA(id).
        APPEND VALUE #( dimension = filter-dimension sign = 'I' option = 'EQ' low = id ) TO selections.
      ENDLOOP.
    ENDLOOP.
    result = model_table( available ).
    DATA(package) = model_table( available ).
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <package> TYPE STANDARD TABLE.
    ASSIGN result->* TO <rows>. ASSIGN package->* TO <package>.
    DATA dim_names TYPE uja_t_dim_list.
    LOOP AT available INTO DATA(dim). APPEND CONV #( dim-id ) TO dim_names. ENDLOOP.
    TRY.
        IF mo_diagnostics IS BOUND AND mo_diagnostics->fixture_mode = abap_true.
          diagnostic-source = 'fixture'. diagnostic-security = 'MEMBER_AUTH_ON; NO_QUERY'.
          result = mo_diagnostics->fixture_read( environment = mv_environment model = mv_model
            filters = effective max_rows = max_rows ).
          ASSIGN result->* TO <rows>.
        ELSE.
        " Re-establish this adapter's secure model context after member validation.
        context( environment = mv_environment model = mv_model ).
        DATA(query) = cl_ujo_query_factory=>get_query_adapter(
          i_appset_id = CONV #( mv_environment ) i_appl_id = CONV #( mv_model ) ).
        DATA first TYPE rs_bool VALUE abap_true.
        DATA ended TYPE rs_bool.
        DATA messages TYPE uj0_t_message.
        DATA packages TYPE i.
        DO.
          packages = packages + 1. diagnostic-packages = packages.
          IF packages > 10000.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_READ_LIMIT' detail = 'SAP query exceeds 10000 packages; narrow filters'.
          ENDIF.
          CLEAR <package>.
          query->run_rsdri_query( EXPORTING it_dim_name = dim_names it_range = selections
            if_check_security = abap_true i_packagesize = 1000 i_call_badi = abap_false
            IMPORTING et_data = <package> e_end_of_data = ended et_message = messages CHANGING c_first_call = first ).
          LOOP AT messages INTO DATA(message) WHERE msgty = 'E' OR msgty = 'A'.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_READ' detail = 'SAP model query returned an error'.
          ENDLOOP.
          IF lines( <rows> ) + lines( <package> ) > max_rows.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_READ_LIMIT'
              detail = 'Model read exceeds the SAP processing limit; narrow filters or raise max_rows explicitly'.
          ENDIF.
          APPEND LINES OF <package> TO <rows>.
          IF mo_diagnostics IS BOUND. mo_diagnostics->check_budget( ). ENDIF.
          IF ended = abap_true. EXIT. ENDIF.
        ENDDO.
        ENDIF.
      CATCH zcx_bn INTO DATA(error). RAISE EXCEPTION error.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_READ' detail = native->get_text( ).
    ENDTRY.
    diagnostic-state = 'succeeded'. diagnostic-row_count = lines( <rows> ).
    IF mo_diagnostics IS BOUND. mo_diagnostics->record_read( diagnostic ). ENDIF.
    CATCH zcx_bn INTO DATA(read_error).
      diagnostic-state = 'failed'. diagnostic-row_count = -1.
      diagnostic-error_code = read_error->code.
      IF mo_diagnostics IS BOUND.
        TRY. mo_diagnostics->record_read( diagnostic ). CATCH zcx_bn. ENDTRY.
      ENDIF.
      RAISE EXCEPTION read_error.
    CATCH cx_root INTO DATA(read_failure).
      diagnostic-state = 'failed'. diagnostic-row_count = -1.
      diagnostic-error_code = 'BPC_READ'.
      IF mo_diagnostics IS BOUND.
        TRY. mo_diagnostics->record_read( diagnostic ). CATCH zcx_bn. ENDTRY.
      ENDIF.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_READ' detail = read_failure->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD context.
    TRY.
        DATA(manager) = cl_uja_bpc_admin_factory=>get_appset_manager( if_disable_security = abap_false ).
        manager->get_appsets( EXPORTING i_user_id = CONV uj_user_id( sy-uname )
          IMPORTING et_appsets = DATA(environments) ).
        IF environment IS INITIAL.
          LOOP AT environments INTO DATA(env).
            APPEND VALUE #( id = env-appset_id ) TO result.
          ENDLOOP.
          RETURN.
        ENDIF.
        IF NOT line_exists( environments[ appset_id = environment ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Environment access denied' status = 403.
        ENDIF.
        cl_uj_context=>set_cur_context( i_appset_id = CONV #( environment ) i_appl_id = CONV #( model )
          is_user = VALUE #( user_id = sy-uname langu = sy-langu ) ).
        DATA(ctx) = cl_uj_context=>get_cur_context( ).
        IF ctx->df_security_check <> abap_true.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'BPC security is disabled' status = 403.
        ENDIF.
        manager = cl_uja_bpc_admin_factory=>get_appset_manager(
          i_appset_id = CONV #( environment ) if_disable_security = abap_false ).
        manager->get_applications( EXPORTING if_summary = abap_false IMPORTING et_applications = DATA(models) ).
        IF model IS INITIAL.
          LOOP AT models INTO DATA(app).
            ctx->check_app_access( EXPORTING i_appl_id = app-application_id IMPORTING ef_success = DATA(allowed) ).
            IF allowed = abap_true. APPEND VALUE #( id = app-application_id description = app-description ) TO result. ENDIF.
          ENDLOOP.
          RETURN.
        ENDIF.
        ctx->check_app_access( EXPORTING i_appl_id = CONV #( model ) IMPORTING ef_success = allowed ).
        READ TABLE models INTO app WITH KEY application_id = model.
        IF sy-subrc <> 0 OR allowed <> abap_true.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Model access denied' status = 403.
        ENDIF.
        LOOP AT app-dimensions INTO DATA(dim).
          APPEND VALUE #( id = dim-dimension description = dim-description dim_type = dim-dim_type ) TO result.
        ENDLOOP.
      CATCH zcx_bn INTO DATA(error). RAISE EXCEPTION error.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA' detail = native->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD permitted.
    IF members IS INITIAL. RETURN. ENDIF.
    DATA(ctx) = cl_uj_context=>get_cur_context( ).
    IF ctx IS INITIAL OR ctx->df_security_check <> abap_true.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Secure BPC context required' status = 403.
    ENDIF.
    ctx->check_member_access( EXPORTING i_dim_name = CONV #( dimension ) i_rw = 'R' it_mem_list = members
      IMPORTING et_mem_list = result ).
  ENDMETHOD.
  METHOD list_members.
    DATA(dimensions) = context( environment = environment model = model ).
    IF dimension IS INITIAL OR NOT line_exists( dimensions[ id = dimension ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_DIMENSION' detail = 'Dimension does not belong to the selected model'.
    ENDIF.
    TRY.
        DATA(dim) = NEW cl_uja_dim( i_appset_id = CONV #( environment ) i_dimension = CONV #( dimension ) ).
        DATA hi TYPE uja_t_hier.
        DATA hn TYPE uja_t_hier_name.
        IF dim->has_hier( ) = abap_true. dim->get_hier_list( IMPORTING et_hier_info = hi ). ENDIF.
        LOOP AT hi INTO DATA(h). APPEND h-hier_name TO hn. APPEND CONV string( h-hier_name ) TO result-hierarchies. ENDLOOP.
        IF hierarchy IS NOT INITIAL AND NOT line_exists( result-hierarchies[ table_line = hierarchy ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_HIERARCHY' detail = 'Unknown hierarchy'.
        ENDIF.
        dim->read_mbr_data( EXPORTING it_hier_list = hn if_inc_txt = abap_true IMPORTING er_data = DATA(data) ).
        FIELD-SYMBOLS <rows> TYPE STANDARD TABLE.
        FIELD-SYMBOLS <row> TYPE any.
        FIELD-SYMBOLS <value> TYPE any.
        ASSIGN data->* TO <rows>.
        DATA ids TYPE uje_t_mem.
        DATA all TYPE tt_items.
        DATA parents TYPE zcl_bn_types=>tt_ids.
        LOOP AT <rows> ASSIGNING <row>.
          DATA item TYPE ty_item.
          CLEAR item.
          ASSIGN COMPONENT 'ID' OF STRUCTURE <row> TO <value>.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA' detail = 'Member ID column missing'.
          ENDIF.
          item-id = <value>.
          ASSIGN COMPONENT 'EVDESCRIPTION' OF STRUCTURE <row> TO <value>.
          IF sy-subrc = 0. item-description = <value>. ENDIF.
          ASSIGN COMPONENT 'CALC' OF STRUCTURE <row> TO <value>.
          IF sy-subrc = 0. item-is_node = xsdbool( <value> = 'Y' ). ENDIF.
          LOOP AT hn INTO DATA(hierarchy_name).
            ASSIGN COMPONENT hierarchy_name OF STRUCTURE <row> TO <value>.
            IF sy-subrc = 0 AND <value> IS NOT INITIAL. APPEND CONV string( <value> ) TO parents. ENDIF.
          ENDLOOP.
          IF hierarchy IS NOT INITIAL.
            ASSIGN COMPONENT hierarchy OF STRUCTURE <row> TO <value>.
            IF sy-subrc = 0. item-parent = <value>. ENDIF.
          ENDIF.
          APPEND item TO all. APPEND CONV uj_dim_member( item-id ) TO ids.
        ENDLOOP.
        DATA(authorized) = permitted( dimension = dimension members = ids ).
        LOOP AT all INTO item.
          IF line_exists( authorized[ table_line = item-id ] ).
            item-is_node = xsdbool( item-is_node = abap_true OR line_exists( parents[ table_line = item-id ] ) ).
            IF item-parent IS NOT INITIAL AND NOT line_exists( authorized[ table_line = item-parent ] ).
              CLEAR item-parent.
            ENDIF.
            APPEND item TO result-items.
          ENDIF.
        ENDLOOP.
        SORT result-items BY id.
        DELETE ADJACENT DUPLICATES FROM result-items COMPARING id.
      CATCH zcx_bn INTO DATA(error). RAISE EXCEPTION error.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA' detail = native->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD metadata.
    IF kind <> 'environments' AND environment IS INITIAL OR
      ( kind = 'dimensions' OR kind = 'members' OR kind = 'properties' OR kind = 'fields' ) AND model IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_CONTEXT' detail = 'Metadata context is incomplete'.
    ENDIF.
    CASE kind.
      WHEN 'environments'. result-items = context( environment = '' ).
      WHEN 'models'. result-items = context( environment = environment ).
      WHEN 'dimensions'. result-items = context( environment = environment model = model ).
      WHEN 'members'. result = list_members( environment = environment model = model dimension = dimension hierarchy = hierarchy ).
      WHEN 'properties' OR 'fields'.
        DATA(adapter) = NEW zcl_bn_bpc( environment = environment model = model dimension = dimension ).
        DATA discovered TYPE tt_fields.
        IF kind = 'properties'. discovered = adapter->properties( ). ELSE. discovered = adapter->fields( ). ENDIF.
        LOOP AT discovered INTO DATA(field).
          APPEND VALUE #( id = field-name description = |{ field-type } ({ field-length }) / { field-source }| ) TO result-items.
        ENDLOOP.
      WHEN OTHERS. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_METADATA' detail = 'Unknown metadata request'.
    ENDCASE.
    IF offset < 0. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'OFFSET' detail = 'Offset must be nonnegative'. ENDIF.
    DATA filtered TYPE tt_items.
    DATA query TYPE string.
    query = to_upper( search ).
    LOOP AT result-items INTO DATA(item).
      IF query IS INITIAL OR to_upper( item-id ) CS query OR to_upper( item-description ) CS query.
        APPEND item TO filtered.
      ENDIF.
    ENDLOOP.
    CLEAR result-items.
    LOOP AT filtered INTO item FROM offset + 1 TO offset + 100. APPEND item TO result-items. ENDLOOP.
    result-more = xsdbool( lines( filtered ) > offset + 100 ).
  ENDMETHOD.
  METHOD bases.
    TRY.
        DATA(dim) = NEW cl_uja_dim( i_appset_id = CONV #( environment ) i_dimension = CONV #( dimension ) ).
        dim->get_children_mbr( EXPORTING i_hier_name = CONV #( hierarchy ) i_parent_mbr = CONV #( member )
          if_only_base_mbr = abap_true if_self = abap_false IMPORTING et_member = DATA(children) ).
        LOOP AT children INTO DATA(child). APPEND CONV string( child ) TO result. ENDLOOP.
        IF result IS INITIAL.
          IF is_node = abap_true.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_HIERARCHY'
              detail = 'Node has no base members in the selected hierarchy'.
          ENDIF.
          APPEND member TO result.
        ENDIF.
      CATCH zcx_bn INTO DATA(error). RAISE EXCEPTION error.
      CATCH cx_root INTO DATA(native).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_HIERARCHY' detail = native->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD resolve.
    IF notebook-environment IS NOT INITIAL OR notebook-model IS NOT INITIAL.
      IF notebook-environment IS INITIAL OR notebook-model IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_CONTEXT' detail = 'Choose both environment and model'.
      ENDIF.
      DATA(dimensions) = context( environment = notebook-environment model = notebook-model ).
    ENDIF.
    LOOP AT notebook-inputs ASSIGNING FIELD-SYMBOL(<input>).
      IF <input>-type <> 'member' AND <input>-type <> 'range'. CONTINUE. ENDIF.
      IF notebook-environment IS INITIAL OR notebook-model IS INITIAL OR <input>-dimension IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_CONTEXT' detail = 'Member inputs require environment, model and dimension'.
      ENDIF.
      IF <input>-type = 'member' AND lines( <input>-selected ) > 1 OR lines( <input>-selected ) > 100.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_SELECTION' detail = 'Single member input accepts one ID; ranges accept up to 100 selections'.
      ENDIF.
      DATA(list) = list_members( environment = notebook-environment model = notebook-model
        dimension = <input>-dimension hierarchy = <input>-hierarchy ).
      IF <input>-type = 'range' AND <input>-hierarchy IS INITIAL AND list-hierarchies IS NOT INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_HIERARCHY' detail = 'Choose a hierarchy for range inputs'.
      ENDIF.
      CLEAR: <input>-resolved, <input>-value.
      IF complete = abap_true AND <input>-required = abap_true AND <input>-selected IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_REQUIRED' detail = |Select { <input>-name } before running|.
      ENDIF.
      LOOP AT <input>-selected INTO DATA(id).
        IF NOT line_exists( list-items[ id = id ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Selection is unavailable or unauthorized' status = 403.
        ENDIF.
        IF <input>-type = 'range' AND list-hierarchies IS NOT INITIAL.
          DATA(leaves) = bases( environment = notebook-environment dimension = <input>-dimension hierarchy = <input>-hierarchy member = id is_node = list-items[ id = id ]-is_node ).
          APPEND LINES OF leaves TO <input>-resolved.
        ELSE. APPEND id TO <input>-resolved. ENDIF.
      ENDLOOP.
      SORT <input>-selected. DELETE ADJACENT DUPLICATES FROM <input>-selected.
      SORT <input>-resolved. DELETE ADJACENT DUPLICATES FROM <input>-resolved.
      LOOP AT <input>-resolved INTO id.
        IF NOT line_exists( list-items[ id = id ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'All resolved base members must be authorized' status = 403.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    " Freeze reference IDs and fiscal offsets independently of output periods.
    LOOP AT notebook-inputs ASSIGNING <input>.
      IF <input>-purpose IS NOT INITIAL AND <input>-purpose <> 'reference'.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_PURPOSE' detail = 'Purpose must be blank or reference'.
      ENDIF.
      IF <input>-purpose = 'reference' AND <input>-type <> 'member' AND <input>-type <> 'range'.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INPUT_PURPOSE' detail = 'Reference selections must be member or range inputs'.
      ENDIF.
      CLEAR <input>-fiscal_links.
      IF <input>-lookback_from IS INITIAL. CONTINUE. ENDIF.
      IF <input>-purpose <> 'reference' OR <input>-type <> 'range' OR
         <input>-lookback_steps < 1 OR <input>-lookback_steps > 24.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'REFERENCE_SCOPE' detail = 'Lookbacks require a reference range and 1 to 24 offsets'.
      ENDIF.
      READ TABLE notebook-inputs INTO DATA(output) WITH KEY name = <input>-lookback_from.
      IF sy-subrc <> 0 OR output-purpose = 'reference' OR output-dimension <> <input>-dimension.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'REFERENCE_SCOPE' detail = 'Lookback source must be an output selection of the same dimension'.
      ENDIF.
      DATA(adapter) = NEW zcl_bn_bpc( environment = notebook-environment model = notebook-model dimension = <input>-dimension ).
      DATA(pending) = output-resolved.
      DO <input>-lookback_steps TIMES.
        IF pending IS INITIAL. EXIT. ENDIF.
        DATA(links) = adapter->fiscal_links( pending ).
        APPEND LINES OF links TO <input>-fiscal_links. CLEAR pending.
        LOOP AT links INTO DATA(link).
          IF link-prior IS INITIAL.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FISCAL_METADATA' detail = 'Lookback member has no explicit prior-period link'.
          ENDIF.
          APPEND link-prior TO pending. APPEND link-prior TO <input>-resolved.
        ENDLOOP.
        validate_filters( environment = notebook-environment model = notebook-model
          filters = VALUE #( ( dimension = <input>-dimension members = pending ) ) ).
      ENDDO.
      IF pending IS NOT INITIAL. APPEND LINES OF adapter->fiscal_links( pending ) TO <input>-fiscal_links. ENDIF.
      SORT <input>-resolved. DELETE ADJACENT DUPLICATES FROM <input>-resolved.
      SORT <input>-fiscal_links BY dimension member.
      DELETE ADJACENT DUPLICATES FROM <input>-fiscal_links COMPARING dimension member.
    ENDLOOP.
  ENDMETHOD.
  METHOD validate_frozen.
    IF notebook-environment IS NOT INITIAL.
      DATA(dimensions) = context( environment = notebook-environment model = notebook-model ).
    ENDIF.
    LOOP AT notebook-inputs INTO DATA(input) WHERE type = 'member' OR type = 'range'.
      DATA(list) = list_members( environment = notebook-environment model = notebook-model dimension = input-dimension hierarchy = input-hierarchy ).
      LOOP AT input-selected INTO DATA(id).
        IF NOT line_exists( list-items[ id = id ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Frozen selection is no longer authorized' status = 403.
        ENDIF.
      ENDLOOP.
      LOOP AT input-resolved INTO id.
        IF NOT line_exists( list-items[ id = id ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_AUTH' detail = 'Frozen base member is no longer authorized' status = 403.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
  METHOD current_view.
    LOOP AT inputs INTO DATA(input) WHERE purpose <> 'reference' AND ( type = 'member' OR type = 'range' ).
      IF input-resolved IS INITIAL. CONTINUE. ENDIF.
      READ TABLE result ASSIGNING FIELD-SYMBOL(<cv>) WITH KEY dimension = input-dimension.
      IF sy-subrc <> 0.
        INSERT VALUE #( dimension = input-dimension dim_upper_case = to_upper( input-dimension )
          user_specified = abap_true ) INTO TABLE result ASSIGNING <cv>.
      ENDIF.
      LOOP AT input-resolved INTO DATA(id). APPEND CONV uj_dim_member( id ) TO <cv>-member. ENDLOOP.
      SORT <cv>-member. DELETE ADJACENT DUPLICATES FROM <cv>-member.
    ENDLOOP.
  ENDMETHOD.
  METHOD validate_scope.
    DATA(available) = context( environment = environment model = model ).
    DATA filters TYPE tt_filters.
    LOOP AT scope INTO DATA(view).
      IF NOT line_exists( available[ id = view-dimension ] ) OR
         line_exists( filters[ dimension = view-dimension ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_CV' detail = 'Unknown or duplicate current-view dimension'.
      ENDIF.
      DATA(filter) = VALUE ty_filter( dimension = view-dimension ).
      LOOP AT view-member INTO DATA(id). APPEND CONV string( id ) TO filter-members. ENDLOOP.
      APPEND filter TO filters.
    ENDLOOP.
    validate_filters( environment = environment model = model filters = filters ).
  ENDMETHOD.
  METHOD scoped_view.
    result = current_view( inputs ).
    LOOP AT scope INTO DATA(view).
      READ TABLE result ASSIGNING FIELD-SYMBOL(<cv>) WITH KEY dimension = view-dimension.
      IF sy-subrc <> 0.
        view-dim_upper_case = to_upper( view-dimension ).
        INSERT view INTO TABLE result. CONTINUE.
      ENDIF.
      LOOP AT <cv>-member INTO DATA(id).
        IF NOT line_exists( view-member[ table_line = id ] ). DELETE <cv>-member WHERE table_line = id. ENDIF.
      ENDLOOP.
      IF <cv>-member IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_CV' detail = 'Notebook selection conflicts with the caller current view'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD script_parameters.
    LOOP AT inputs INTO DATA(input).
      DATA value TYPE string.
      value = input-value.
      IF input-type = 'member' OR input-type = 'range'.
        CLEAR value.
        LOOP AT input-resolved INTO DATA(id).
          IF value IS NOT INITIAL. value = value && ','. ENDIF.
          value = value && id.
        ENDLOOP.
      ENDIF.
      INSERT VALUE #( hashkey = input-name hashvalue = value ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
