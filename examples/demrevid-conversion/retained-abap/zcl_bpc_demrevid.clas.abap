class zcl_bpc_demrevid definition
  public
  inheriting from zcl_bpc_model
  final
  create public .

  public section.

    interfaces zif_bpc_model_data.

    types:
      begin of struct,
        account          type uj_dim_member,
        audittrail       type uj_dim_member,
        category         type uj_dim_member,
        costcentre       type uj_dim_member,
        demrevid_kfs     type uj_dim_member,
        fflas            type uj_dim_member,
        fflas_subset     type uj_dim_member,
        matconn          type uj_dim_member,
        time             type uj_dim_member,
        product_type     type uj_dim_member,
        geo_drivers      type uj_dim_member,
        doc_typ          type uj_dim_member,
        conn_reg_split   type uj_dim_member,
        lfc_win_supplier type uj_dim_member,
        mat_group_id     type uj_dim_member,
        reg_fflas_serv   type uj_dim_member,
        ufb_dr_id        type uj_dim_member,
        matremap         type uj_dim_member,
        rsp_service_id   type uj_dim_member,
        rev_id_group     type uj_dim_member,
        signeddata       type uj_signeddata,
      end of struct .
    types:
      tabl type table of struct with default key .

    types:
      begin of struct_cmt,
        account          type uj_dim_member,
        audittrail       type uj_dim_member,
        category         type uj_dim_member,
        costcentre       type uj_dim_member,
        demrevid_kfs     type uj_dim_member,
        fflas            type uj_dim_member,
        fflas_subset     type uj_dim_member,
        matconn          type uj_dim_member,
        time             type uj_dim_member,
        product_type     type uj_dim_member,
        geo_drivers      type uj_dim_member,
        doc_typ          type uj_dim_member,
        conn_reg_split   type uj_dim_member,
        lfc_win_supplier type uj_dim_member,
        mat_group_id     type uj_dim_member,
        reg_fflas_serv   type uj_dim_member,
        ufb_dr_id        type uj_dim_member,
        matremap         type uj_dim_member,
        rsp_service_id   type uj_dim_member,
        rev_id_group     type uj_dim_member,
        scomment         type c length 350,
      end of struct_cmt .
    types:
      tabl_cmt type standard table of struct_cmt with default key.

    data model_data type tabl .
    data model_cmts type tabl_cmt .

    methods abs
      returning
        value(model) type ref to zcl_bpc_demrevid .
    methods add
      importing
        !add_by      type uj_signeddata
      returning
        value(model) type ref to zcl_bpc_demrevid .
    methods append
      importing
        !append_data type any
      returning
        value(model) type ref to zcl_bpc_demrevid .
    methods average_by_halfyear
      returning
        value(model) type ref to zcl_bpc_demrevid .
    methods average_by_period
      returning
        value(model) type ref to zcl_bpc_demrevid .
    methods collect
      importing
        !collect_data       type any optional
        value(collect_by)   type uja_t_dim_list optional
        !include_dimensions type uj_sign default abap_true
          preferred parameter collect_data
      returning
        value(model)        type ref to zcl_bpc_demrevid .
    methods compare_delta
      importing
        !model_compare    type ref to zcl_bpc_demrevid
        value(compare_by) type uja_t_dim_list optional
      returning
        value(model)      type ref to zcl_bpc_demrevid .
    methods compress .
    methods constructor
      importing
        !environment type ref to zcl_bpc_ch_planning optional
        !filters     type zbpc_t_sel optional
        !model_data  type standard table optional
        !compressed  type abap_bool default abap_true .
    methods allocate
      importing
        !alloc_data  type ref to zcl_bpc_demrevid
        !allocate_by type uja_t_dim_list
        !read_by     type uja_t_dim_list
      returning
        value(model) type ref to zcl_bpc_demrevid .
    methods copy
      importing
        !filters         type zbpc_t_sel optional
      returning
        value(new_model) type ref to zcl_bpc_demrevid .
    methods delete
      importing
        !filters     type zbpc_t_sel
      returning
        value(model) type ref to zcl_bpc_demrevid .
    methods diff
      importing
        value(compare_model) type standard table
        !compare_by          type uja_t_dim_list
      returning
        value(model)         type ref to zcl_bpc_demrevid .
    methods divide
      importing
        !divide_data     type standard table optional
        !read_dimensions type uja_t_dim_list optional
        !divider         type uj_signeddata optional
        !binary          type abap_bool default abap_true
      returning
        value(model)     type ref to zcl_bpc_demrevid .
    methods fill_gaps
      returning
        value(model) type ref to zcl_bpc_demrevid .
    methods filter
      importing
        !filters     type zbpc_t_sel
      returning
        value(model) type ref to zcl_bpc_demrevid .
    methods get_data
      importing
        !filters          type zbpc_t_sel optional
      returning
        value(model_data) type tabl .
    methods get_dimmem_range
      importing
        !dimension   type uj_dim_name
        !sign        type rssign default 'I'
        !option      type rsoption default 'EQ'
      returning
        value(range) type ujw_t_dimmem_range .
    methods get_ratio
      importing
        !compare_by  type uja_t_dim_list
      returning
        value(model) type ref to zcl_bpc_demrevid .
    methods group
      importing
        value(group_by)     type uja_t_dim_list optional
        !include_dimensions type uj_sign default abap_true
          preferred parameter group_by
      returning
        value(model)        type ref to zcl_bpc_demrevid .
    methods multiply
      importing
        !multiply_data   type standard table optional
        !read_dimensions type uja_t_dim_list optional
        !multiplier      type uj_signeddata optional
        !binary          type abap_bool default abap_true
      returning
        value(model)     type ref to zcl_bpc_demrevid .
    methods offset_time
      importing
        !offset_by     type i
        !time_dim_name type uj_dim_name default 'TIME'
      returning
        value(model)   type ref to zcl_bpc_demrevid .
    methods read
      importing
        !filters           type zbpc_t_sel
        !binary            type abap_bool default abap_true
      returning
        value(_model_data) type struct .
    methods replace
      importing
        !filters                type zbpc_t_sel optional
        !dimension              type uj_dim_name
        !replace_with           type uj_dim_member optional
        !replace_with_attribute type uj_attr_name optional
      returning
        value(model)            type ref to zcl_bpc_demrevid .
    methods replaces
      importing
        !replaces_sel type zif_bpc_model~replaces_tabl
      returning
        value(model)  type ref to zcl_bpc_demrevid .
    methods set_data
      importing
        !filters    type zbpc_t_sel optional
        !model_data type standard table .
    methods sort
      importing
        value(sort_by) type uja_t_dim_list
      returning
        value(model)   type ref to zcl_bpc_demrevid .
    methods subtract
      importing
        !subtract_data type tabl optional
        !subtract_by   type uj_signeddata optional
      returning
        value(model)   type ref to zcl_bpc_demrevid .
    methods phase_halfyear_period
      returning
        value(model) type ref to zcl_bpc_demrevid.
    methods write_data .
    methods read_comments
      importing
        !dimlist     type ujc_t_cmt_dimlist
      returning
        value(model) type ref to zcl_bpc_demrevid .
  protected section.

  private section.

    constants _model_name type uj_appl_id value 'DEMREVID'.
endclass.



class zcl_bpc_demrevid implementation.


  method abs.
    me->zif_bpc_model~abs( changing model_data = model_data ).
    model = me.
  endmethod.


  method add.
    zif_bpc_model~add(
      exporting
        add_by     = add_by
      changing
        model_data = me->model_data ).
    model = me.
  endmethod.


  method append.
    zif_bpc_model~append(
      exporting
        append_data = append_data
      changing
        model_data  = model_data ).
    model = me.
  endmethod.


  method average_by_halfyear.
    zif_bpc_model~average_by_halfyear( me ).
    model = me.
  endmethod.


  method average_by_period.
    zif_bpc_model~average_by_period( me ).
    model = me.
  endmethod.


  method collect.
    zif_bpc_model~collect(
      exporting
        collect_data       = collect_data
        collect_by         = collect_by
        include_dimensions = include_dimensions
      changing
        model_data         = model_data ).
    model = me.
  endmethod.


  method compare_delta.

    sort model_compare->model_data by account audittrail category conn_reg_split costcentre
        demrevid_kfs doc_typ fflas fflas_subset geo_drivers lfc_win_supplier matconn matremap
            mat_group_id product_type reg_fflas_serv rev_id_group rsp_service_id time ufb_dr_id.

    loop at me->model_data into data(_model_data).
      read table model_compare->model_data assigning field-symbol(<_model_compare>) with key
        account = _model_data-account
        audittrail = _model_data-audittrail
        category = _model_data-category
        conn_reg_split = _model_data-conn_reg_split
        costcentre = _model_data-costcentre
        demrevid_kfs = _model_data-demrevid_kfs
        doc_typ = _model_data-doc_typ
        fflas = _model_data-fflas
        fflas_subset = _model_data-fflas_subset
        geo_drivers = _model_data-geo_drivers
        lfc_win_supplier = _model_data-lfc_win_supplier
        matconn = _model_data-matconn
        matremap = _model_data-matremap
        mat_group_id = _model_data-mat_group_id
        product_type = _model_data-product_type
        reg_fflas_serv = _model_data-reg_fflas_serv
        rev_id_group = _model_data-rev_id_group
        rsp_service_id = _model_data-rsp_service_id
        time = _model_data-time
        ufb_dr_id = _model_data-ufb_dr_id
                   binary search.
      if sy-subrc is initial.
        if <_model_compare>-signeddata eq _model_data-signeddata.
          delete me->model_data.
        endif.
        clear <_model_compare>-signeddata.
      endif.
    endloop.

    delete model_compare->model_data where signeddata is initial.
    loop at model_compare->model_data into data(_model_compare).
      clear _model_compare-signeddata.
      append _model_compare to me->model_data.
    endloop.

    model = me.
  endmethod.


  method compress.
    zif_bpc_model~compress(
      changing
        model_data = model_data ).
  endmethod.


  method constructor.
    super->constructor(
      environment = environment
      model_data  = me->model_data ).

    " If internal table model_data
    " is being passed as a parameter in the constructor,
    " assigns it to the property model_data of the object.
    if model_data is not initial.
      me->set_data(
        exporting
          filters    = filters
          model_data = model_data ).
    else.
      " Otherwise, if no data
      " is being passed as argument,
      " but the filter is. assumes
      " the data needs to be retrieved from the DB.
      if filters is not initial.
        me->zif_bpc_model~read_transactional_data(
          exporting
            model      = _model_name
            filters    = filters
          changing
            model_data = me->model_data ).
      endif.
    endif.

    if compressed eq abap_true.
      me->compress( ).
    endif.
  endmethod.


  method allocate.
    zif_bpc_model~allocate(
      exporting
        alloc_data  = alloc_data
        read_by     = read_by
        allocate_by = allocate_by
      changing
        model_data  = model_data ).
    model = me.
  endmethod.


  method copy.
    new_model = new zcl_bpc_demrevid( environment = get_environment( ) ).
    new_model->model_data = me->get_data( filters ).
  endmethod.


  method delete.
    zif_bpc_model~delete(
      exporting
        filters    = filters
      changing
        model_data = model_data ).
    model = me.
  endmethod.


  method diff.
    zif_bpc_model~diff(
      exporting
        compare_model = compare_model
        compare_by    = compare_by
      changing
        model_data    = model_data ).
    model = me.
  endmethod.


  method divide.
    me->zif_bpc_model~divide(
      exporting
        divide_data     = divide_data
        read_dimensions = read_dimensions
        divide_by       = divider
        binary_search   = binary
      changing
        model_data      = model_data
    ).
    model = me.
  endmethod.


  method fill_gaps.
    zif_bpc_model~fill_gaps( changing model_data = model_data ).
    model = me.
  endmethod.


  method filter.
    data new_data like me->model_data.
    zif_bpc_model~filter(
      exporting
        filters    = filters
        model_data = me->model_data
      importing
        new_data   = new_data ).
    me->model_data = new_data.
    model = me.
  endmethod.


  method get_data.
    zif_bpc_model~get_data(
      exporting
        filters    = filters
        model_data = me->model_data
      importing
        new_data   = model_data ).
  endmethod.


  method get_dimmem_range.
    range = zif_bpc_model~get_dimmem_range(
      exporting
        model_data = model_data
        dimension  = dimension
        sign       = sign
        option     = option ).
  endmethod.


  method get_ratio.
    zif_bpc_model~get_ratio(
      exporting
        compare_by = compare_by
      changing
        model_data = model_data ).

    model = me.
  endmethod.


  method group.
    zif_bpc_model~group(
      exporting
        group_by           = group_by
        include_dimensions = include_dimensions
      changing
        model_data         = model_data ).

    model = me.
  endmethod.


  method multiply.
    me->zif_bpc_model~multiply(
      exporting
        multiply_data   = multiply_data
        read_dimensions = read_dimensions
        multiplier      = multiplier
        binary_search   = binary
      changing
        model_data      = model_data
    ).
    model = me.
  endmethod.


  method offset_time.
    zif_bpc_model~offset_time(
      exporting
        offset_by     = offset_by
        time_dim_name = 'TIME'
      changing
        model_data    = model_data ).

    model = me.
  endmethod.


  method read.
    zif_bpc_model~read(
      exporting
        filters       = filters
        binary_search = binary
        model_data    = model_data
      importing
        _model_data   = _model_data ).
  endmethod.


  method replace.
    zif_bpc_model~replace(
      exporting
        filters      = filters
        dimension    = dimension
        replace_with = replace_with
        attribute    = replace_with_attribute
      changing
        model_data   = model_data ).
    model = me.
  endmethod.


  method replaces.
    zif_bpc_model~replaces(
      exporting
        replaces_sel = replaces_sel
      changing
        model_data   = model_data ).
    model = me.
  endmethod.


  method set_data.
    zif_bpc_model~set_data(
      exporting
        filters        = filters
        new_model_data = model_data
      changing
        model_data     = me->model_data ).
  endmethod.


  method sort.
    zif_bpc_model~sort(
      exporting
        sort_by    = sort_by
      changing
        model_data = model_data ).
    model = me.
  endmethod.


  method subtract.
    zif_bpc_model~subtract(
      exporting
        subtract_data = subtract_data
        subtract_by   = subtract_by
      changing
        model_data    = me->model_data ).
    model = me.
  endmethod.


  method write_data.
    zif_bpc_model~write_transactional_data( model = _model_name model_data = model_data ).
  endmethod.


  method phase_halfyear_period.
    zif_bpc_model~phase_halfyear_period( model = me ).
    model = me.
  endmethod.


  method zif_bpc_model_data~get_data.
    get reference of me->model_data into model_data_ref.
  endmethod.


  method read_comments.
    zif_bpc_model~read_comments(
      exporting
        model      = _model_name
        dimlist    = dimlist
      changing
        model_cmts = model_cmts ).
    model = me.
  endmethod.
endclass.
