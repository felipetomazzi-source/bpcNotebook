class zcl_bn_transform definition
  public
  abstract
  create public .

  public section.

    interfaces zif_bpc_model .

    methods constructor
      importing
        !environment type ref to zcl_bn_context
        !model_data  type any table optional .

    methods get_environment
      returning
        value(environment) type ref to zcl_bn_context .
  protected section.

  private section.

    types: begin of z_s_dim_member,
             dimension type uj_dim_name,
             member    type uj_dim_member,
           end of z_s_dim_member,
           begin of z_s_dim_obj,
             dim_name type uj_dim_name,
             dim_obj  type ref to zcl_bn_dimension,
           end of z_s_dim_obj.

    data environment type ref to zcl_bn_context.
    data model_data_ref type ref to data.
endclass.



class zcl_bn_transform implementation.


  method get_environment.
 TRY.

    environment = me->environment.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~replace.
 TRY.

    if filters is initial.
      loop at model_data assigning field-symbol(<_model_data>).
        assign component dimension of structure <_model_data> to field-symbol(<dim_value>).
        if attribute is not initial.
          data(dim_obj) = NEW zcl_bn_dimension( io = environment name = dimension ).
          <dim_value> = dim_obj->get_att_value( member = <dim_value> attribute = attribute ).
        else.
          <dim_value> = replace_with.
        endif.
      endloop.
    else.

      data(dim_ranges) = me->zif_bpc_model~get_dim_ranges( filters  ).
      loop at model_data assigning <_model_data>.
        data(search_filter) = abap_true.
        loop at dim_ranges into data(_dim_ranges).
          assign component _dim_ranges-dimension of structure <_model_data> to <dim_value>.
          if <dim_value> not in _dim_ranges-ranges.
            search_filter = abap_false.
          endif.
        endloop.
        if search_filter eq abap_true.
          assign component dimension of structure <_model_data> to <dim_value>.
          <dim_value> = replace_with.
        endif.
      endloop.
    endif.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~subtract.
 TRY.

    if subtract_by is not initial.
      loop at model_data assigning field-symbol(<_model_data>).
        assign component 'SIGNEDDATA' of structure <_model_data> to field-symbol(<signeddata>).
        subtract subtract_by from <signeddata>.
      endloop.
    else.

      " Multiply the subtract_data internal table by -1.
      zif_bpc_model~multiply(
          exporting
              multiplier = -1
              changing
           model_data = subtract_data ).

      " Credits the negative figures found previously
      " with the current model data.
      zif_bpc_model~collect(
        exporting
          collect_data = subtract_data
        changing
          model_data     = model_data ).
    endif.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~fill_gaps.
 TRY.

    data(table_header) =  cast cl_abap_tabledescr( cl_abap_tabledescr=>describe_by_data( model_data ) )->key.
    loop at model_data assigning field-symbol(<_model_data>).
      loop at table_header into data(_table_header).
        if _table_header-name eq 'SIGNEDDATA' or _table_header-name eq 'NO_DELTA'  or _table_header-name eq 'SCOMMENT'.
          continue.
        endif.

        assign component _table_header-name of structure <_model_data> to field-symbol(<member>).

        " Assumes the "not assigned" members consists of the name of the dimension + the sufix _NA.
        if <member> is initial.
          <member> = _table_header-name && '_NA'.

          " Some dimensions don't follow the rule of <dimension name> + '_NA' for the non-assigned members.
          " Hence, this condition:
          if _table_header-name eq 'ESA_GEO'.
            <member> = 'ESA_NA'.
          endif.

          if _table_header-name eq 'SHARING_FACTOR'.
            <member> = 'SF_NA'.
          endif.

          if _table_header-name eq 'PRODUCT_BUNDLE'.
            <member> = 'PB_NA'.
          endif.

          if _table_header-name eq 'GEO_DRIVERS'.
            <member> = 'GDRVS_NA'.
          endif.

          if _table_header-name eq 'BBM_CATEGORY'.
            <member> = 'BBM_NA'.
          endif.

          if _table_header-name eq 'BBM_OPEX'.
            <member> = 'BBM_NA'.
          endif.

          if _table_header-name eq 'FORECAST_TYPE'.
            <member> = 'FT_NA'.
          endif.

          if _table_header-name eq 'INFLATION_TYPES'.
            <member> = 'INFLTY_NA'.
          endif.

          if _table_header-name eq 'DECISION_PACKET'.
            <member> = 'DP_NA'.
          endif.
        endif.

      endloop.
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~append.
 TRY.


    data _ref_data type ref to data.

    field-symbols:
      <model_data>      type standard table,
      <_new_model_data> type any.

    describe field append_data type data(type) components data(components).

    if type eq 'h'. " Internal table.

      assign append_data to <model_data>.
      environment->check_rows( lines( model_data ) + lines( <model_data> ) ).
      append lines of <model_data> to model_data.
      return.
    endif.

    if type eq 'v' or type eq 'u'. " Structure.
      environment->check_rows( lines( model_data ) + 1 ).
      append append_data to model_data.
      return.
    endif.

    if type eq 'r'. " Object.
      data model_obj type ref to zcl_bn_transform.
      model_obj = append_data.
      assign model_obj->model_data_ref->* to <model_data>.

      create data _ref_data like line of model_data.
      assign _ref_data->* to <_new_model_data>.

      environment->check_rows( lines( model_data ) + lines( <model_data> ) ).
      loop at <model_data> assigning field-symbol(<_model_data>).
        move-corresponding <_model_data> to <_new_model_data>.
        append <_new_model_data> to model_data.
      endloop.
    endif.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~allocate.
 TRY.

    " Variable and pointers declaration.
    data filters     type zbpc_t_sel.
    data alloc_data_ref type ref to data.
    data new_model_ref type ref to data.
    data _new_model_ref type ref to data.

    field-symbols <alloc_data> type standard table.
    field-symbols <new_model_data> type standard table.
    field-symbols <_new_model_data> type any.

    " Initialise variables.
    cast zif_bpc_model_data( alloc_data )->get_data(
      importing
        model_data_ref = alloc_data_ref ).

    assign alloc_data_ref->* to <alloc_data>.

    create data new_model_ref like <alloc_data>.
    assign new_model_ref->* to <new_model_data>.

    create data _new_model_ref like line of <alloc_data>.
    assign _new_model_ref->* to <_new_model_data>.

    " Performs allocation.
    loop at model_data assigning field-symbol(<_model_data>).
      data(_where) = ||.
      loop at read_by into data(_read_by).
        assign component _read_by of structure <_model_data> to field-symbol(<_alloc_dim_value>).
        if _where is initial.
          _where = _read_by && | EQ '| && <_alloc_dim_value> && |'|.
          continue.
        endif.
        _where = _where && | AND | && _read_by && | EQ '| && <_alloc_dim_value> && |'|.
      endloop.

      data(is_record_found) = abap_false.
      loop at <alloc_data> assigning field-symbol(<_alloc_data>)
          where (_where).
        is_record_found = abap_true.
        <_new_model_data> = <_model_data>.

        loop at allocate_by into data(_allocate_by).
          assign component _allocate_by of structure <_alloc_data> to <_alloc_dim_value>.
          assign component _allocate_by of structure <_new_model_data> to field-symbol(<dim_value>).
          <dim_value> = <_alloc_dim_value>.
        endloop.

        assign component 'SIGNEDDATA' of structure <_alloc_data> to field-symbol(<_alloc_signeddata>).
        assign component 'SIGNEDDATA' of structure <_new_model_data> to field-symbol(<_signeddata>).

        multiply <_signeddata> by <_alloc_signeddata>.

        append <_new_model_data> to <new_model_data>.
      endloop.

      if is_record_found = abap_true.
        delete model_data.
      endif.
    endloop.

    append lines of <new_model_data> to model_data.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  METHOD zif_bpc_model~read_comments.
    RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = 'UNSUPPORTED_IO' detail = 'Allocation kernel does not provide legacy I/O'.
  ENDMETHOD.


  METHOD zif_bpc_model~mass_delete_comments.
    RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = 'UNSUPPORTED_IO' detail = 'Allocation kernel does not provide legacy I/O'.
  ENDMETHOD.


  method zif_bpc_model~collect.
 TRY.


    field-symbols <model_data> type standard table.

    describe field collect_data type data(type) components data(components).

    if type eq 'h'. " Internal table.

      assign collect_data to <model_data>.
      loop at <model_data> assigning field-symbol(<_model_data>).
        collect <_model_data> into model_data.
      endloop.

      zif_bpc_model~sort(
        exporting
            sort_by = collect_by
        changing
            model_data = model_data ).

      return.
    endif.

    if type eq 'u'. " Structure.
      collect collect_data into model_data.
      return.
    endif.

    if type eq 'r'. " Object.
      data(model_obj) = cast zif_bpc_model_data( collect_data ).
      data model_data_ref type ref to data.
      model_obj->get_data(
        importing
          model_data_ref = model_data_ref ).

      assign model_data_ref->* to <model_data>.

      loop at <model_data> assigning <_model_data>.
        collect <_model_data> into model_data.
      endloop.

      zif_bpc_model~sort(
        exporting
            sort_by = collect_by
        changing
            model_data = model_data ).
      return.
    endif.

    field-symbols <new_data> type standard table.
    field-symbols <_new_data> type any.
    data ref_model_data type ref to data.
    data _ref_model_data type ref to data.

    create data ref_model_data like model_data.
    assign ref_model_data->* to <new_data>.

    if collect_by is initial.
      loop at model_data assigning <_model_data>.
        collect <_model_data> into <new_data>.
      endloop.
      model_data = <new_data>.
      return.
    endif.

    loop at model_data assigning <_model_data>.

      create data _ref_model_data like line of model_data.

      assign _ref_model_data->* to <_new_data>.
      if include_dimensions eq abap_true.
        assign component 'SIGNEDDATA' of structure <_model_data> to field-symbol(<model_signeddata>).
        assign component 'SIGNEDDATA' of structure <_new_data> to field-symbol(<new_model_signeddata>).
        <new_model_signeddata> = <model_signeddata>.
        loop at collect_by into data(_collect_by).
          assign component _collect_by of structure <_model_data> to field-symbol(<dim_value>).
          assign component _collect_by of structure <_new_data> to field-symbol(<new_dim_value>).
          <new_dim_value> = <dim_value>.
        endloop.
      else.
        move-corresponding <_model_data> to <_new_data>.

        loop at collect_by into _collect_by.
          assign component _collect_by of structure <_new_data> to <new_dim_value>.
          clear <new_dim_value>.
        endloop.
      endif.

      collect <_new_data> into <new_data>.

    endloop.

    model_data = <new_data>.

    zif_bpc_model~fill_gaps(
      changing
        model_data = model_data  ).

    zif_bpc_model~sort(
        exporting
            sort_by = collect_by
        changing
            model_data = model_data ).


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method constructor.
 TRY.

    IF environment IS NOT BOUND. RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = 'CONTEXT' detail = 'Frozen notebook context required'. ENDIF.
    me->environment = environment. GET REFERENCE OF model_data INTO me->model_data_ref.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~compress.
 TRY.

    delete model_data where ('SIGNEDDATA IS INITIAL').

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~delete.
 TRY.

    data(dim_filter_ranges) = zif_bpc_model~get_dim_ranges( filters ).

    loop at model_data assigning field-symbol(<_model_data>).
      data(to_be_deleted) = abap_true.
      loop at dim_filter_ranges into data(_dim_filter_ranges).

        assign component _dim_filter_ranges-dimension of structure <_model_data> to field-symbol(<_dim_value>).

        if <_dim_value> not in _dim_filter_ranges-ranges.
          to_be_deleted = abap_false.
        endif.

      endloop.

      if to_be_deleted eq abap_true.
        delete model_data.
      endif.
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~offset_time.
 TRY.

    loop at model_data assigning field-symbol(<_model_data>).
      assign component time_dim_name of structure <_model_data> to field-symbol(<_time_member>).
      <_time_member> = environment->offset_period( member = <_time_member> offset_by = offset_by ).
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~abs.
 TRY.

    loop at model_data assigning field-symbol(<_model_data>).
      assign component 'SIGNEDDATA' of structure <_model_data> to field-symbol(<signeddata>).
      <signeddata> = abs( <signeddata> ).
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~diff.
 TRY.

    data filter_aux type zbpc_t_sel.
    field-symbols: <_found_record> type any.

    data data_ref type ref to data.
    create data data_ref like line of compare_model.
    assign data_ref->* to <_found_record>.

    loop at compare_by into data(_compare_by).
      append value zbpc_s_sel( dimension = _compare_by  ) to filter_aux.
    endloop.

    zif_bpc_model~sort(
      exporting
        sort_by    = compare_by
      changing
        model_data = compare_model ).

    loop at model_data assigning field-symbol(<_model_data>).
      loop at filter_aux assigning field-symbol(<_filter_aux>).
        assign component <_filter_aux>-dimension of structure <_model_data> to field-symbol(<_dim_value>).
        <_filter_aux>-low = <_dim_value>.
      endloop.

      zif_bpc_model~read(
        exporting
          filters       = filter_aux
          model_data    = compare_model
        importing
          _model_data   = <_found_record> ).

      if <_found_record> is not initial.
        delete model_data.
      endif.
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~filter.
 TRY.


    " Define the structure type of the return internal table.
    data ref_data type ref to data.
    field-symbols <_new_model_data> type any.
    create data ref_data like line of new_data.
    assign ref_data->* to <_new_model_data>.

    data(dim_filter_ranges) = zif_bpc_model~get_dim_ranges( filters ).

    " Ranges to be used in the dynamic WHERE statement.
    try.
        data(range_1) =  dim_filter_ranges[ 1 ]-ranges.
        data(range_2) =  dim_filter_ranges[ 2 ]-ranges.
        data(range_3) =  dim_filter_ranges[ 3 ]-ranges.
        data(range_4) =  dim_filter_ranges[ 4 ]-ranges.
        data(range_5) =  dim_filter_ranges[ 5 ]-ranges.
        data(range_6) =  dim_filter_ranges[ 6 ]-ranges.
        data(range_7) =  dim_filter_ranges[ 7 ]-ranges.
        data(range_8) =  dim_filter_ranges[ 8 ]-ranges.
        data(range_9) =  dim_filter_ranges[ 9 ]-ranges.
        data(range_10) =  dim_filter_ranges[ 10 ]-ranges.
        data(range_11) =  dim_filter_ranges[ 11 ]-ranges.
        data(range_12) =  dim_filter_ranges[ 12 ]-ranges.
        data(range_13) =  dim_filter_ranges[ 13 ]-ranges.
        data(range_14) =  dim_filter_ranges[ 14 ]-ranges.
        data(range_15) =  dim_filter_ranges[ 15 ]-ranges.
        data(range_16) =  dim_filter_ranges[ 16 ]-ranges.
        data(range_17) =  dim_filter_ranges[ 17 ]-ranges.
        data(range_18) =  dim_filter_ranges[ 18 ]-ranges.
        data(range_19) =  dim_filter_ranges[ 19 ]-ranges.
        data(range_20) =  dim_filter_ranges[ 20 ]-ranges.
      catch cx_sy_itab_line_not_found.
    endtry.

    data _where type string.
    loop at dim_filter_ranges assigning field-symbol(<_dim_filter_ranges>).
      if _where is not initial.
        _where = _where && | AND |.
      endif.
      if lines( <_dim_filter_ranges>-ranges ) eq 1.
        case <_dim_filter_ranges>-ranges[ 1 ]-sign &&
               <_dim_filter_ranges>-ranges[ 1 ]-option.
          when 'IEQ'.
            _where = _where && <_dim_filter_ranges>-dimension && | EQ '| && <_dim_filter_ranges>-ranges[ 1 ]-low && |'|.
          when 'INE'.
            _where = _where && <_dim_filter_ranges>-dimension && | NE '| && <_dim_filter_ranges>-ranges[ 1 ]-low && |'|.
          when 'EEQ'.
            _where = _where && <_dim_filter_ranges>-dimension && | NE '| && <_dim_filter_ranges>-ranges[ 1 ]-low && |'|.
          when 'ENE'.
            _where = _where && <_dim_filter_ranges>-dimension && | EQ '| && <_dim_filter_ranges>-ranges[ 1 ]-low && |'|.
          when 'IBT'.
            _where = _where && <_dim_filter_ranges>-dimension && | BETWEEN | && |'| && <_dim_filter_ranges>-ranges[ 1 ]-low && |' AND '| &&  <_dim_filter_ranges>-ranges[ 1 ]-high && |'|.
          when others.
            _where = _where && <_dim_filter_ranges>-dimension && | IN RANGE_| && sy-tabix.
        endcase.
      else.
*        if <_dim_filter_ranges>-ranges[ 1 ]-option eq 'NE'.
*          _where = _where && <_dim_filter_ranges>-dimension && | NOT IN RANGE_| && sy-tabix.
*        else.
        _where = _where && <_dim_filter_ranges>-dimension && | IN RANGE_| && sy-tabix.
*        endif.
      endif.
    endloop.

    check _where is not initial.
    loop at model_data assigning field-symbol(<_model_data>)
        where (_where).
*      data(_to_be_filtered) = abap_true.
*      loop at dim_filter_ranges into data(_dim_filter_ranges).
*
*        assign component _dim_filter_ranges-dimension of structure <_model_data> to field-symbol(<_dim_value>).
*
*        if <_dim_value> not in _dim_filter_ranges-ranges.
*          _to_be_filtered = abap_false.
*          " No need to continue checking
*          " this line since one of the conditions is false.
*          continue.
*        endif.
*
*      endloop.
*
*      if _to_be_filtered eq abap_true.
      move-corresponding <_model_data> to <_new_model_data>.
      append <_new_model_data> to new_data.
*      endif.
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~get_data.
 TRY.

    if filters is not initial.
      clear new_data.
      zif_bpc_model~filter(
        exporting
          filters    = filters
          model_data = model_data
        importing
          new_data = new_data
      ).
    else.
      new_data = model_data.
    endif.


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~read_transactional_data.
 TRY.

    DATA(ranges) = zif_bpc_model~get_dim_ranges( filters ).
    DATA requested TYPE zcl_bn_bpc=>tt_filters.
    LOOP AT ranges INTO DATA(range).
      DATA(filter) = VALUE zcl_bn_bpc=>ty_filter( dimension = range-dimension ).
      DATA(dim) = environment->bpc_dimension( CONV string( range-dimension ) ).
      DATA(ref) = dim->member_data( ). FIELD-SYMBOLS <members> TYPE STANDARD TABLE. ASSIGN ref->* TO <members>.
      " RSDRI facts contain base members. Exclusion ranges must not introduce hierarchy nodes.
      DATA node_ids TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
      CLEAR node_ids.
      DATA(hierarchies) = dim->hierarchies( ).
      FIELD-SYMBOLS <property> TYPE any.
      LOOP AT <members> ASSIGNING FIELD-SYMBOL(<member>).
        ASSIGN COMPONENT 'ID' OF STRUCTURE <member> TO FIELD-SYMBOL(<id>).
        UNASSIGN <property>. ASSIGN COMPONENT 'CALC' OF STRUCTURE <member> TO <property>.
        IF <property> IS ASSIGNED AND <property> = 'Y'. INSERT CONV string( <id> ) INTO TABLE node_ids. ENDIF.
        LOOP AT hierarchies INTO DATA(hierarchy).
          UNASSIGN <property>. ASSIGN COMPONENT hierarchy OF STRUCTURE <member> TO <property>.
          IF <property> IS ASSIGNED AND <property> IS NOT INITIAL. INSERT CONV string( <property> ) INTO TABLE node_ids. ENDIF.
        ENDLOOP.
      ENDLOOP.
      LOOP AT <members> ASSIGNING <member>.
        ASSIGN COMPONENT 'ID' OF STRUCTURE <member> TO <id>.
        IF line_exists( node_ids[ table_line = CONV string( <id> ) ] ). CONTINUE. ENDIF.
        IF <id> IN range-ranges. APPEND CONV string( <id> ) TO filter-members. ENDIF.
      ENDLOOP.
      IF filter-members IS INITIAL. CLEAR model_data. RETURN. ENDIF.
      APPEND filter TO requested.
    ENDLOOP.
    DATA(model_adapter) = environment->reference_model( CONV string( model ) ).
    DATA(maximum) = CONV i( environment->input( 'READ_LIMIT' ) ).
    DATA(data) = model_adapter->read_data( filters = requested max_rows = maximum ).
    FIELD-SYMBOLS <facts> TYPE STANDARD TABLE. ASSIGN data->* TO <facts>.
    zif_bpc_model~set_data( EXPORTING new_model_data = <facts> CHANGING model_data = model_data ).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~get_dim_ranges.
 TRY.

    " Existing dimensions in filters.
    data(dimensions) = filters.
    sort dimensions by dimension.
    delete adjacent duplicates from dimensions comparing dimension.

    data _dim_ranges like line of dim_ranges.
    data _range type uj0_s_range.

    loop at dimensions into data(_dimensions).
      DATA dim_obj TYPE REF TO zcl_bn_dimension.
      CLEAR dim_obj.

      clear: _dim_ranges, _range.
      _dim_ranges-dimension = _dimensions-dimension.

      loop at filters into data(_filter)
        where dimension eq _dimensions-dimension.
        _filter-sign = cond #( when _filter-sign is initial then 'I' else _filter-sign ).
        _filter-option = cond #( when _filter-option is initial then 'EQ' else _filter-option ).

        if _filter-hier_name is not initial.
          dim_obj = NEW zcl_bn_dimension( io = environment name = _dimensions-dimension ).
          append lines of dim_obj->get_children_range(
              dimension = _dimensions-dimension
              i_hier_name   = _filter-hier_name
              i_parent_mbr  = conv uj_dim_member( _filter-low )
              sign          = _filter-sign
              option        = _filter-option ) to _dim_ranges-ranges.
        elseif _filter-attribute is not initial.
          dim_obj = NEW zcl_bn_dimension( io = environment name = _dimensions-dimension ).
          append lines of dim_obj->get_range_by_attribute(
                        attribute     = _filter-attribute
                        value         = _filter-low
                        sign          = _filter-sign
                        option        = _filter-option ) to _dim_ranges-ranges.
        elseif _filter-in is not initial.
          append lines of _filter-in to _dim_ranges-ranges.
        else.
          move-corresponding _filter to _range.
          append _range to _dim_ranges-ranges.
        endif.

      endloop.

      append _dim_ranges to dim_ranges.

    endloop.
    sort dim_ranges by dimension.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~group.
 TRY.


    field-symbols <model_data> type standard table.
    field-symbols <_model_data> type any.
    field-symbols <new_data> type standard table.
    field-symbols <_new_data> type any.

    data ref_model_data type ref to data.
    data _ref_model_data type ref to data.

    create data ref_model_data like model_data.
    assign ref_model_data->* to <new_data>.

    if group_by is initial.
      loop at model_data assigning <_model_data>.
        collect <_model_data> into <new_data>.
      endloop.
      model_data = <new_data>.
      return.
    endif.

    loop at model_data assigning <_model_data>.

      create data _ref_model_data like line of model_data.

      assign _ref_model_data->* to <_new_data>.
      if include_dimensions eq abap_true.
        assign component 'SIGNEDDATA' of structure <_model_data> to field-symbol(<model_signeddata>).
        assign component 'SIGNEDDATA' of structure <_new_data> to field-symbol(<new_model_signeddata>).
        <new_model_signeddata> = <model_signeddata>.
        loop at group_by into data(_group_by).
          assign component _group_by of structure <_model_data> to field-symbol(<dim_value>).
          assign component _group_by of structure <_new_data> to field-symbol(<new_dim_value>).
          <new_dim_value> = <dim_value>.
        endloop.
      else.
        move-corresponding <_model_data> to <_new_data>.

        loop at group_by into _group_by.
          assign component _group_by of structure <_new_data> to <new_dim_value>.
          clear <new_dim_value>.
        endloop.
      endif.

      collect <_new_data> into <new_data>.

    endloop.

    model_data = <new_data>.

    zif_bpc_model~fill_gaps(
      changing
        model_data = model_data  ).

    zif_bpc_model~sort(
        exporting
            sort_by = group_by
        changing
            model_data = model_data ).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~phase_halfyear_period.
 TRY.


    field-symbols <model_data> type standard table.
    field-symbols <new_model_data> type standard table.
    field-symbols <_new_model_data> type any.

    data model_data_ref type ref to data.
    data new_model_ref type ref to data.
    data _new_model_ref type ref to data.

    cast zif_bpc_model_data( model )->get_data(
      importing
        model_data_ref = model_data_ref ).

    assign model_data_ref->* to <model_data>.

    create data new_model_ref like <model_data>.
    assign new_model_ref->* to <new_model_data>.

    create data _new_model_ref like line of <model_data>.
    assign _new_model_ref->* to <_new_model_data>.

    data(del_stmt) = |NOT ( TIME CS '006' OR TIME CS '012' )|.
    delete <model_data> where (del_stmt).

    loop at <model_data> assigning field-symbol(<_model_data>).
      move-corresponding <_model_data> to <_new_model_data>.
      assign component 'TIME' of structure <_model_data> to field-symbol(<time>).
      assign component 'TIME' of structure <_new_model_data> to field-symbol(<_new_time>).

      do 5 times.
        data(period) = environment->offset_period( offset_by = -1 member = <_new_time> ).
        <_new_time> = period.
        append <_new_model_data> to <new_model_data>.
      enddo.
    endloop.

    append lines of <new_model_data> to <model_data>.


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~divide.
 TRY.


    if divide_by is not initial.
      loop at model_data assigning field-symbol(<_model_data>).
        assign component 'SIGNEDDATA' of structure <_model_data> to field-symbol(<_model_signeddata>).
        divide <_model_signeddata> by divide_by.
      endloop.
      return.
    endif.

    data: filters     type zbpc_t_sel, filters_aux type zbpc_t_sel.
    field-symbols: <_divide_data> type any, <divider> type uj_signeddata.

    data _divide_data type ref to data.
    create data _divide_data like line of divide_data.
    assign _divide_data->* to <_divide_data>.

    loop at model_data assigning <_model_data>.
      clear filters_aux.
      loop at read_dimensions into data(_read_dimensions).
        assign component _read_dimensions of structure <_model_data> to field-symbol(<dim_value>).
        append value zbpc_s_sel( dimension = _read_dimensions low =  <dim_value> ) to filters_aux.
      endloop.

      if filters ne filters_aux.
        filters = filters_aux.
        me->zif_bpc_model~read(
          exporting
            filters     = filters
            binary_search      = binary_search
            model_data  = divide_data
          importing
            _model_data = <_divide_data> ).

        assign component 'SIGNEDDATA' of structure <_divide_data> to <divider>.
        data(divider) = <divider>.
      endif.

      assign component 'SIGNEDDATA' of structure <_model_data> to <_model_signeddata>.
      try.
          data(signedata_aux) = conv f( <_model_signeddata> ).
          divide signedata_aux by <divider>.
          <_model_signeddata> = signedata_aux.
        catch cx_sy_zerodivide.
      endtry.
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~average_by_halfyear.
 TRY.


    field-symbols <model_data> type standard table.
    data model_data_ref type ref to data.
    model->get_data(
      importing
        model_data_ref = model_data_ref ).
    assign model_data_ref->* to <model_data>.

    field-symbols <model_data_aux> type standard table.
    data ref_model_data type ref to data.
    create data ref_model_data like <model_data>.
    assign ref_model_data->* to <model_data_aux>.

    <model_data_aux> = <model_data>.

    zif_bpc_model~offset_time(
        exporting
            offset_by = 6
        changing
            model_data = <model_data_aux> ).

    zif_bpc_model~collect(
      exporting
        collect_data       = <model_data_aux>
      changing
        model_data         = <model_data> ).

    zif_bpc_model~divide(
      exporting
        divide_by = 2
      changing
        model_data      = <model_data> ).

    field-symbols <_model_data_aux> type any.
    data _ref_model_data type ref to data.
    create data _ref_model_data like line of <model_data>.
    assign _ref_model_data->* to <_model_data_aux>.

    clear <model_data_aux>.
    loop at <model_data> assigning field-symbol(<_model_data>).
      <_model_data_aux> = <_model_data>.
      assign component zif_bpc_dimension_list=>time of structure <_model_data_aux> to field-symbol(<_time>).

      if not ( <_time> cs '006' or <_time> cs '012' ).
        delete <model_data>.
        continue.
      endif.

      do 5 times.
        <_time> = environment->offset_period(
            member = <_time> offset_by = -1 ).
        append <_model_data_aux> to <model_data_aux>.
      enddo.
    endloop.
    append lines of <model_data_aux> to <model_data>.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  METHOD zif_bpc_model~save_comments.
    RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = 'UNSUPPORTED_IO' detail = 'Allocation kernel does not provide legacy I/O'.
  ENDMETHOD.


  method zif_bpc_model~read.
 TRY.

    clear _model_data.
    data:
      dim_member_01 type z_s_dim_member,
      dim_member_02 type z_s_dim_member,
      dim_member_03 type z_s_dim_member,
      dim_member_04 type z_s_dim_member,
      dim_member_05 type z_s_dim_member,
      dim_member_06 type z_s_dim_member,
      dim_member_07 type z_s_dim_member,
      dim_member_08 type z_s_dim_member,
      dim_member_09 type z_s_dim_member,
      dim_member_10 type z_s_dim_member,
      dim_member_11 type z_s_dim_member,
      dim_member_12 type z_s_dim_member,
      dim_member_13 type z_s_dim_member,
      dim_member_14 type z_s_dim_member,
      dim_member_15 type z_s_dim_member.

    " Maps the dimension and the member to be filtered in the READ.
    loop at filters into data(_filters).
      case sy-tabix.
        when 1.
          dim_member_01-dimension = _filters-dimension.
          dim_member_01-member = _filters-low.
        when 2.
          dim_member_02-dimension = _filters-dimension.
          dim_member_02-member = _filters-low..
        when 3.
          dim_member_03-dimension = _filters-dimension.
          dim_member_03-member = _filters-low..
        when 4.
          dim_member_04-dimension = _filters-dimension.
          dim_member_04-member = _filters-low..
        when 5.
          dim_member_05-dimension = _filters-dimension.
          dim_member_05-member = _filters-low..
        when 6.
          dim_member_06-dimension = _filters-dimension.
          dim_member_06-member = _filters-low..
        when 7.
          dim_member_07-dimension = _filters-dimension.
          dim_member_07-member = _filters-low..
        when 8.
          dim_member_08-dimension = _filters-dimension.
          dim_member_08-member = _filters-low..
        when 9.
          dim_member_09-dimension = _filters-dimension.
          dim_member_09-member = _filters-low..
        when 10.
          dim_member_10-dimension = _filters-dimension.
          dim_member_10-member = _filters-low..
        when 11.
          dim_member_11-dimension = _filters-dimension.
          dim_member_11-member = _filters-low..
        when 12.
          dim_member_12-dimension = _filters-dimension.
          dim_member_12-member = _filters-low..
        when 13.
          dim_member_13-dimension = _filters-dimension.
          dim_member_13-member = _filters-low..
        when 14.
          dim_member_14-dimension = _filters-dimension.
          dim_member_14-member = _filters-low..
        when 15.
          dim_member_15-dimension = _filters-dimension.
          dim_member_15-member = _filters-low..

      endcase.
    endloop.

    if binary_search eq abap_true.
      read table model_data assigning field-symbol(<_model_data>)
             with key (dim_member_01-dimension) = dim_member_01-member
                      (dim_member_02-dimension) = dim_member_02-member
                      (dim_member_03-dimension) = dim_member_03-member
                      (dim_member_04-dimension) = dim_member_04-member
                      (dim_member_05-dimension) = dim_member_05-member
                      (dim_member_06-dimension) = dim_member_06-member
                      (dim_member_07-dimension) = dim_member_07-member
                      (dim_member_08-dimension) = dim_member_08-member
                      (dim_member_09-dimension) = dim_member_09-member
                      (dim_member_10-dimension) = dim_member_10-member
                      (dim_member_11-dimension) = dim_member_11-member
                      (dim_member_12-dimension) = dim_member_12-member
                      (dim_member_13-dimension) = dim_member_13-member
                      (dim_member_14-dimension) = dim_member_14-member
                      (dim_member_15-dimension) = dim_member_15-member
                      binary search.
      if sy-subrc is initial.
        move-corresponding <_model_data> to _model_data.
      endif.
    else.
      read table model_data assigning <_model_data>
             with key (dim_member_01-dimension) = dim_member_01-member
                      (dim_member_02-dimension) = dim_member_02-member
                      (dim_member_03-dimension) = dim_member_03-member
                      (dim_member_04-dimension) = dim_member_04-member
                      (dim_member_05-dimension) = dim_member_05-member
                      (dim_member_06-dimension) = dim_member_06-member
                      (dim_member_07-dimension) = dim_member_07-member
                      (dim_member_08-dimension) = dim_member_08-member
                      (dim_member_09-dimension) = dim_member_09-member
                      (dim_member_10-dimension) = dim_member_10-member
                      (dim_member_11-dimension) = dim_member_11-member
                      (dim_member_12-dimension) = dim_member_12-member
                      (dim_member_13-dimension) = dim_member_13-member
                      (dim_member_14-dimension) = dim_member_14-member
                      (dim_member_15-dimension) = dim_member_15-member.
      if sy-subrc is initial.
        move-corresponding <_model_data> to _model_data.
      endif.
    endif.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~average_by_period.
 TRY.


    field-symbols <model_data> type standard table.
    data model_data_ref type ref to data.
    model->get_data(
      importing
        model_data_ref = model_data_ref ).
    assign model_data_ref->* to <model_data>.

    field-symbols <offset_data> type standard table.
    data ref_model_data type ref to data.
    create data ref_model_data like <model_data>.
    assign ref_model_data->* to <offset_data>.

    <offset_data> = <model_data>.

    zif_bpc_model~offset_time(
        exporting
            offset_by = 1
        changing
            model_data = <offset_data> ).

    zif_bpc_model~collect(
      exporting
        collect_data       = <offset_data>
      changing
        model_data         = <model_data> ).

    zif_bpc_model~divide(
      exporting
        divide_by = 2
      changing
        model_data      = <model_data> ).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~multiply.
 TRY.


    if multiplier is not initial.
      loop at model_data assigning field-symbol(<_model_data>).
        assign component 'SIGNEDDATA' of structure <_model_data> to field-symbol(<_model_signeddata>).
        multiply <_model_signeddata> by multiplier.
      endloop.
    else.

      data: filters     type zbpc_t_sel, filters_aux type zbpc_t_sel.
      field-symbols: <_multiply_data> type any, <multiplier> type uj_signeddata.
      data _multiply_data type ref to data.
      create data _multiply_data like line of multiply_data.
      assign _multiply_data->* to <_multiply_data>.

      loop at model_data assigning <_model_data>.
        clear filters_aux.
        loop at read_dimensions into data(_read_dimensions).
          assign component _read_dimensions of structure <_model_data> to field-symbol(<dim_value>).
          append value zbpc_s_sel( dimension = _read_dimensions low =  <dim_value> ) to filters_aux.
        endloop.

        if filters ne filters_aux.
          filters = filters_aux.
          me->zif_bpc_model~read(
            exporting
              filters     = filters
              binary_search      = binary_search
              model_data  = multiply_data
            importing
              _model_data = <_multiply_data> ).

          assign component 'SIGNEDDATA' of structure <_multiply_data> to <multiplier>.
          data(read_multiplier) = <multiplier>.
        endif.

        assign component 'SIGNEDDATA' of structure <_model_data> to <_model_signeddata>.
        multiply <_model_signeddata> by read_multiplier.
      endloop.
    endif.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~write_transactional_data.
 TRY.

    RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = 'UNSUPPORTED_IO' detail = 'Allocation kernel does not provide legacy I/O'.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~set_data.
 TRY.


    environment->check_rows( lines( model_data ) + lines( new_model_data ) ).
    check new_model_data is not initial.

    if filters is not initial.
      me->zif_bpc_model~filter(
        exporting
          filters    = filters
          model_data = new_model_data
        importing
          new_data = model_data
      ).
    else.
      data ref_data type ref to data.
      field-symbols <_model_data> type any.
      create data ref_data like line of model_data.
      assign ref_data->* to <_model_data>.
      loop at new_model_data assigning field-symbol(<_data>).
        move-corresponding <_data> to <_model_data>.
        append <_model_data> to model_data.
      endloop.
    endif.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~sort.
 TRY.

    data:
      dim_01 type uj_dim_name,
      dim_02 type uj_dim_name,
      dim_03 type uj_dim_name,
      dim_04 type uj_dim_name,
      dim_05 type uj_dim_name,
      dim_06 type uj_dim_name,
      dim_07 type uj_dim_name,
      dim_08 type uj_dim_name,
      dim_09 type uj_dim_name,
      dim_10 type uj_dim_name,
      dim_11 type uj_dim_name,
      dim_12 type uj_dim_name,
      dim_13 type uj_dim_name,
      dim_14 type uj_dim_name,
      dim_15 type uj_dim_name,
      dim_16 type uj_dim_name,
      dim_17 type uj_dim_name,
      dim_18 type uj_dim_name,
      dim_19 type uj_dim_name,
      dim_20 type uj_dim_name.

    loop at sort_by into data(_sort_by).
      case sy-tabix.
        when 1.
          dim_01 = _sort_by.
        when 2.
          dim_02 = _sort_by.
        when 3.
          dim_03 = _sort_by.
        when 4.
          dim_04 = _sort_by.
        when 5.
          dim_05 = _sort_by.
        when 6.
          dim_06 = _sort_by.
        when 7.
          dim_07 = _sort_by.
        when 8.
          dim_08 = _sort_by.
        when 9.
          dim_09 = _sort_by.
        when 10.
          dim_10 = _sort_by.
        when 11.
          dim_11 = _sort_by.
        when 12.
          dim_12 = _sort_by.
        when 13.
          dim_13 = _sort_by.
        when 14.
          dim_14 = _sort_by.
        when 15.
          dim_15 = _sort_by.
        when 16.
          dim_16 = _sort_by.
        when 17.
          dim_17 = _sort_by.
        when 18.
          dim_18 = _sort_by.
        when 19.
          dim_19 = _sort_by.
        when 20.
          dim_20 = _sort_by.
      endcase.
    endloop.

    sort model_data by (dim_01) (dim_02) (dim_03) (dim_04) (dim_05) (dim_06)
         (dim_07) (dim_08) (dim_09) (dim_10) (dim_11) (dim_12) (dim_13) (dim_14) (dim_15)
         (dim_16) (dim_17) (dim_18) (dim_19) (dim_20).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~replaces.
 TRY.

    loop at replaces_sel into data(_replaces_sel).
      zif_bpc_model~replace(
        exporting
          filters = _replaces_sel-filters
          dimension    = _replaces_sel-dimension
          replace_with = _replaces_sel-replace_with
          attribute = _replaces_sel-replace_with_attribute
        changing
          model_data   = model_data ).
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~get_ratio.
 TRY.


    field-symbols: <aggregated_model> type standard table.
    field-symbols: <ratio_totals> type standard table.
    data data_ref type ref to data.
    data totals_ref type ref to data.

    create data data_ref like model_data.
    assign data_ref->* to <aggregated_model>.

    <aggregated_model> = model_data.

    zif_bpc_model~collect(
      exporting
        collect_by         = compare_by
      changing
        model_data         = <aggregated_model> ).

    zif_bpc_model~sort(
          exporting
            sort_by     = compare_by
          changing
            model_data      = <aggregated_model> ).

    zif_bpc_model~divide(
      exporting
        divide_data     = <aggregated_model>
        read_dimensions = compare_by
      changing
        model_data      = model_data ).

    " Balance ratios to exactly 1 per group.
    " After division, uj_signeddata (7 decimal places) may truncate ratios so they
    " don't sum to exactly 1. Re-collect by compare_by to find the sum per group,
    " then adjust the first row in each unbalanced group.
    create data totals_ref like model_data.
    assign totals_ref->* to <ratio_totals>.
    <ratio_totals> = model_data.

    zif_bpc_model~collect(
      exporting
        collect_by = compare_by
      changing
        model_data = <ratio_totals> ).

    zif_bpc_model~sort(
      exporting
        sort_by = compare_by
      changing
        model_data = model_data ).

    field-symbols <_total> type any.
    field-symbols <_ratio_row> type any.
    field-symbols <total_signed> type uj_signeddata.
    field-symbols <ratio_signed> type uj_signeddata.
    field-symbols <total_dim> type any.
    field-symbols <row_dim> type any.

    loop at <ratio_totals> assigning <_total>.
      assign component 'SIGNEDDATA' of structure <_total> to <total_signed>.
      check <total_signed> ne 1 and <total_signed> is not initial.
      " Find the first matching row in model_data for this group.
      loop at model_data assigning <_ratio_row>.
        data(is_match) = abap_true.
        is_match = abap_true.
        loop at compare_by into data(_dim).
          assign component _dim of structure <_total> to <total_dim>.
          assign component _dim of structure <_ratio_row> to <row_dim>.
          if <row_dim> ne <total_dim>.
            is_match = abap_false.
            exit.
          endif.
        endloop.
        if is_match = abap_true.
          assign component 'SIGNEDDATA' of structure <_ratio_row> to <ratio_signed>.
          <ratio_signed> = <ratio_signed> + ( 1 - <total_signed> ).
          exit.
        endif.
      endloop.
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~add.
 TRY.

    loop at model_data assigning field-symbol(<_model_data>).
      assign component 'SIGNEDDATA' of structure <_model_data> to field-symbol(<signeddata>).
      add add_by to <signeddata>.
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~compare_delta.
 TRY.


    data:
      dim_member_01 type z_s_dim_member,
      dim_member_02 type z_s_dim_member,
      dim_member_03 type z_s_dim_member,
      dim_member_04 type z_s_dim_member,
      dim_member_05 type z_s_dim_member,
      dim_member_06 type z_s_dim_member,
      dim_member_07 type z_s_dim_member,
      dim_member_08 type z_s_dim_member,
      dim_member_09 type z_s_dim_member,
      dim_member_10 type z_s_dim_member,
      dim_member_11 type z_s_dim_member,
      dim_member_12 type z_s_dim_member,
      dim_member_13 type z_s_dim_member,
      dim_member_14 type z_s_dim_member,
      dim_member_15 type z_s_dim_member,
      dim_member_16 type z_s_dim_member,
      dim_member_17 type z_s_dim_member,
      dim_member_18 type z_s_dim_member,
      dim_member_19 type z_s_dim_member,
      dim_member_20 type z_s_dim_member.

    zif_bpc_model~sort(
        exporting
            sort_by = compare_by
        changing
            model_data = model_data_compare ).

    loop at model_data assigning field-symbol(<_model_data>).

      clear: dim_member_01, dim_member_02, dim_member_03, dim_member_04, dim_member_05,
        dim_member_06, dim_member_07, dim_member_08, dim_member_09, dim_member_10,
        dim_member_11, dim_member_12, dim_member_13, dim_member_14, dim_member_15,
        dim_member_16, dim_member_17, dim_member_18, dim_member_19, dim_member_20.

      loop at compare_by into data(_compare_by).
        assign component _compare_by of structure <_model_data> to field-symbol(<dim_value>).
        case sy-tabix.
          when 1.
            dim_member_01-dimension = _compare_by.
            dim_member_01-member = <dim_value>.
          when 2.
            dim_member_02-dimension = _compare_by.
            dim_member_02-member = <dim_value>.
          when 3.
            dim_member_03-dimension = _compare_by.
            dim_member_03-member = <dim_value>.
          when 4.
            dim_member_04-dimension = _compare_by.
            dim_member_04-member = <dim_value>.
          when 5.
            dim_member_05-dimension = _compare_by.
            dim_member_05-member = <dim_value>.
          when 6.
            dim_member_06-dimension = _compare_by.
            dim_member_06-member = <dim_value>.
          when 7.
            dim_member_07-dimension = _compare_by.
            dim_member_07-member = <dim_value>.
          when 8.
            dim_member_08-dimension = _compare_by.
            dim_member_08-member = <dim_value>.
          when 9.
            dim_member_09-dimension = _compare_by.
            dim_member_09-member = <dim_value>.
          when 10.
            dim_member_10-dimension = _compare_by.
            dim_member_10-member = <dim_value>.
          when 11.
            dim_member_11-dimension = _compare_by.
            dim_member_11-member = <dim_value>.
          when 12.
            dim_member_12-dimension = _compare_by.
            dim_member_12-member = <dim_value>.
          when 13.
            dim_member_13-dimension = _compare_by.
            dim_member_13-member = <dim_value>.
          when 14.
            dim_member_14-dimension = _compare_by.
            dim_member_14-member = <dim_value>.
          when 15.
            dim_member_15-dimension = _compare_by.
            dim_member_15-member = <dim_value>.
          when 16.
            dim_member_16-dimension = _compare_by.
            dim_member_16-member = <dim_value>.
          when 17.
            dim_member_17-dimension = _compare_by.
            dim_member_17-member = <dim_value>.
          when 18.
            dim_member_18-dimension = _compare_by.
            dim_member_18-member = <dim_value>.
          when 19.
            dim_member_19-dimension = _compare_by.
            dim_member_19-member = <dim_value>.
          when 20.
            dim_member_20-dimension = _compare_by.
            dim_member_20-member = <dim_value>.

        endcase.
      endloop.

      read table model_data_compare assigning field-symbol(<_model_compare>)
           with key (dim_member_01-dimension) = dim_member_01-member
                    (dim_member_02-dimension) = dim_member_02-member
                    (dim_member_03-dimension) = dim_member_03-member
                    (dim_member_04-dimension) = dim_member_04-member
                    (dim_member_05-dimension) = dim_member_05-member
                    (dim_member_06-dimension) = dim_member_06-member
                    (dim_member_07-dimension) = dim_member_07-member
                    (dim_member_08-dimension) = dim_member_08-member
                    (dim_member_09-dimension) = dim_member_09-member
                    (dim_member_10-dimension) = dim_member_10-member
                    (dim_member_11-dimension) = dim_member_11-member
                    (dim_member_12-dimension) = dim_member_12-member
                    (dim_member_13-dimension) = dim_member_13-member
                    (dim_member_14-dimension) = dim_member_14-member
                    (dim_member_15-dimension) = dim_member_15-member
                    (dim_member_16-dimension) = dim_member_16-member
                    (dim_member_17-dimension) = dim_member_17-member
                    (dim_member_18-dimension) = dim_member_18-member
                    (dim_member_19-dimension) = dim_member_19-member
                    (dim_member_20-dimension) = dim_member_20-member
                    binary search.

      if sy-subrc is initial.
        assign component 'SIGNEDDATA' of structure <_model_data> to field-symbol(<_model_value>).
        assign component 'SIGNEDDATA' of structure <_model_compare> to field-symbol(<_model_comp_value>).

        if <_model_comp_value> eq <_model_value>.
          delete model_data.
        endif.

        assign component 'NO_DELTA' of structure <_model_compare> to field-symbol(<_no_delta>).
        <_no_delta> = abap_true.
      else.
        assign component 'SIGNEDDATA' of structure <_model_data> to <_model_value>.
        if <_model_value> is initial.
          " If it's a new record (not present in the comparing model) but signeddata is 0,
          " then delete it from the model_data.
          delete model_data.
        endif.
      endif.
    endloop.

    data ref_data type ref to data.
    field-symbols <_data> type any.
    create data ref_data like line of model_data.
    assign ref_data->* to <_data>.
    loop at model_data_compare assigning <_model_compare>
        where ('NO_DELTA EQ ABAP_FALSE').
      move-corresponding <_model_compare> to <_data>.

      assign component 'SIGNEDDATA' of structure <_data> to <_model_value>.
      clear <_model_value>.
      append <_data> to model_data.
    endloop.


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method zif_bpc_model~get_dimmem_range.
 TRY.

    loop at model_data assigning field-symbol(<_model_data>).
      assign component dimension of structure <_model_data> to field-symbol(<_dimmem>).
      append value ujw_s_dimmem_range( option = option sign = sign low = <_dimmem> ) to range.
    endloop.
    sort range. delete adjacent duplicates from range.

    " Append dummy value to prevents issues
    " when using this range in filters.
    if range is initial.
      append value #( sign = sign option = option low = '' ) to range.
    endif.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.
endclass.
