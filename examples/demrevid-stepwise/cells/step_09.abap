" Choose FFLAS mapping and monthly percentages
" Calculation is inline. Full dependencies are independent of display previews.
constants kf_sap_revenues type uj_dim_member value 'DEMREVID004' ##NO_TEXT.
constants kf_rsp_not_billed type uj_dim_member value 'DEMREVID007' ##NO_TEXT.
constants kf_conn_region_mapping type uj_dim_member value 'DEMREVID008' ##NO_TEXT.
constants kf_loc_split_index type uj_dim_member value 'DEMREVID009' ##NO_TEXT.
constants kf_rsp_loc_ratio_mat type uj_dim_member value 'DEMREVID010' ##NO_TEXT.
constants kf_rsp_loc_ratio_gl type uj_dim_member value 'DEMREVID011' ##NO_TEXT.
constants kf_cal_loc_ratio_gl type uj_dim_member value 'DEMREVID012' ##NO_TEXT.
constants kf_cal_loc_ratio_conn_reg type uj_dim_member value 'DEMREVID013' ##NO_TEXT.
constants kf_prod_type_mapping type uj_dim_member value 'DEMREVID014' ##NO_TEXT.
constants kf_ratios_for_split type uj_dim_member value 'DEMREVID015' ##NO_TEXT.
constants kf_rsp_bill_with_loc type uj_dim_member value 'DEMREVID016' ##NO_TEXT.
constants kf_rsp_bill_no_loc type uj_dim_member value 'DEMREVID017' ##NO_TEXT.
constants kf_rsp_not_billed_loc type uj_dim_member value 'DEMREVID018' ##NO_TEXT.
constants kf_rsp_bill_prod_type type uj_dim_member value 'DEMREVID019' ##NO_TEXT.
constants kf_fflas_grouping type uj_dim_member value 'DEMREVID021' ##NO_TEXT.
constants kf_fflas_monthly_pct type uj_dim_member value 'DEMREVID022' ##NO_TEXT.
constants kf_fflas_revenue type uj_dim_member value 'DEMREVID023' ##NO_TEXT.
constants kf_pq_fflas_pct type uj_dim_member value 'DEMREVID025' ##NO_TEXT.
constants kf_l1_l2_mapping type uj_dim_member value 'DEMREVID027' ##NO_TEXT.
constants kf_supplier_split_index type uj_dim_member value 'DEMREVID028' ##NO_TEXT.
constants kf_rsp_supplier_ratio_mat type uj_dim_member value 'DEMREVID029' ##NO_TEXT.
constants kf_rsp_supplier_ratio_gl type uj_dim_member value 'DEMREVID030' ##NO_TEXT.
constants kf_cal_supplier_ratio_conn_reg type uj_dim_member value 'DEMREVID031' ##NO_TEXT.
constants kf_cal_supplier_ratio_gl type uj_dim_member value 'DEMREVID032' ##NO_TEXT.
constants kf_supplier_split_ratio type uj_dim_member value 'DEMREVID033' ##NO_TEXT.
constants kf_hidden_mat_group type uj_dim_member value 'DEMREVID034' ##NO_TEXT.
constants kf_mat_group_mapping type uj_dim_member value 'DEMREVID035' ##NO_TEXT.
constants kf_reg_fflas_serv_mapping type uj_dim_member value 'DEMREVID037' ##NO_TEXT.
constants kf_alloc_rev_summary type uj_dim_member value 'DEMREVID038' ##NO_TEXT.
constants kf_monthly_cal_conn type uj_dim_member value 'DEMREVID039' ##NO_TEXT.
constants kf_conn_opening type uj_dim_member value 'DEMREVID040' ##NO_TEXT.
constants kf_conn_closing type uj_dim_member value 'DEMREVID041' ##NO_TEXT.
constants kf_hidden_conn type uj_dim_member value 'DEMREVID043' ##NO_TEXT.
constants kf_hsns_premium_upload type uj_dim_member value 'DEMREVID045' ##NO_TEXT.
constants geo_lfc type uj_dim_member value 'GDRVS_001' ##NO_TEXT.
constants geo_ronz type uj_dim_member value 'GDRVS_002' ##NO_TEXT.
constants geo_ufb type uj_dim_member value 'GDRVS_003' ##NO_TEXT.
constants fflas_id type uj_dim_member value 'FFLASID' ##NO_TEXT.
constants fflas_non type uj_dim_member value 'FFLASNON' ##NO_TEXT.
constants fflas_pq type uj_dim_member value 'FFLASPQ' ##NO_TEXT.
constants access_rental type uj_dim_member value 'PRODUCT_TYPE_001' ##NO_TEXT.
constants bandwidth type uj_dim_member value 'PRODUCT_TYPE_004' ##NO_TEXT.
constants other_lfc_ufb_1 type uj_dim_member value 'UFBDRID003' ##NO_TEXT.
constants other_lfc_ufb_2 type uj_dim_member value 'UFBDRID004' ##NO_TEXT.
constants conn_price_kf type uj_dim_member value 'DEMREVID044' ##NO_TEXT.
constants access_price_kf type uj_dim_member value 'DEMREVID042' ##NO_TEXT.
constants rsp_billing type uj_dim_member value 'DEMREVID006' ##NO_TEXT.
constants accrual type uj_dim_member value 'DEMREVID007' ##NO_TEXT.
constants rev_alloc_fflas type uj_dim_member value 'DEMREVID023' ##NO_TEXT.
constants sap_price type uj_dim_member value 'DEMREVID002' ##NO_TEXT.
constants mat_remapping type uj_dim_member value 'DEMREVID036' ##NO_TEXT.
constants kf_add_conn_mat_group type uj_dim_member value 'DEMREVID046' ##NO_TEXT.
constants kf_output_add_conn_mat_group type uj_dim_member value 'DEMREVID049' ##NO_TEXT.
constants kf_fflas_ratios_material type uj_dim_member value 'DEMREVID047' ##NO_TEXT.
constants kf_fflas_ratio_skipped type uj_dim_member value 'DEMREVID052' ##NO_TEXT.
constants fflas_na type uj_dim_member value 'FFLAS_NA' ##NO_TEXT.
constants audit_dnrid_calc type uj_dim_member value 'DEMREVID_CALC' ##NO_TEXT.
    types: begin of enum rev_split_method,
             _                    value is initial,
             rsp_billing_material value 1,
             rsp_billing_gl       value 2,
             cal_gl               value 3,
             cal_reg_split        value 4,
             not_found            value 5,
             rsp_billing_supplier value 6,
           end of enum rev_split_method,

           begin of enum rev_split_type,
             location,
             supplier,
           end of enum rev_split_type.
DATA(env) = io.
DATA(preview_rows) = CONV i( io->input( 'PREVIEW_ROWS' ) ).
DATA(category) = io->member( 'CATEGORY' ).
DATA(parameters) = io->script_parameters( ).
READ TABLE parameters ASSIGNING FIELD-SYMBOL(<flag>) WITH KEY hashkey = 'FFLASMATGROUPS'.
IF sy-subrc = 0.
CASE <flag>-hashvalue. WHEN 'true'. <flag>-hashvalue = '1'. WHEN 'false'. <flag>-hashvalue = '0'. ENDCASE.
ENDIF.
DATA(param) = NEW zcl_bpc_param( parameters ).
DATA(skip_fflas_ratio_mat_group_id) = param->get_dimmem_range( 'FFLASMATGROUPSID' ).
DATA(nb_skip_flags) = param->get_dimmem_range( 'FFLASMATGROUPS' ).
LOOP AT skip_fflas_ratio_mat_group_id INTO DATA(nb_skip_id).
 READ TABLE nb_skip_flags INTO DATA(nb_skip_flag) INDEX sy-tabix.
 IF sy-subrc <> 0 OR nb_skip_flag-low = 0. DELETE skip_fflas_ratio_mat_group_id. ENDIF.
ENDLOOP.
DATA(product_type_dim) = NEW zcl_bn_dimension( io = io name = 'PRODUCT_TYPE' ).
DATA(mat_group_id_dim) = NEW zcl_bn_dimension( io = io name = 'MAT_GROUP_ID' ).
DATA(matconn_dim) = NEW zcl_bn_dimension( io = io name = 'MATCONN' ).
DATA input_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_input_data) = io->read_dataset( dependency = 'step_01' name = 'INPUT_DATA' ).
FIELD-SYMBOLS <t_input_data> TYPE STANDARD TABLE.
ASSIGN ref_input_data->* TO <t_input_data>.
input_data = NEW #( environment = io model_data = <t_input_data> compressed = abap_false ).
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_08' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA fflas_month_ratio TYPE REF TO zcl_bn_dem_model.
DATA sap_revenues_consol TYPE REF TO zcl_bn_dem_model.
DATA(ref_sap_revenues_consol) = io->read_dataset( dependency = 'step_03' name = 'SAP_REVENUES_CONSOL' ).
FIELD-SYMBOLS <t_sap_revenues_consol> TYPE STANDARD TABLE.
ASSIGN ref_sap_revenues_consol->* TO <t_sap_revenues_consol>.
sap_revenues_consol = NEW #( environment = io model_data = <t_sap_revenues_consol> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
fflas_month_ratio = new #( environment = env ).
    data(fflas_grouping) = input_data->copy( value #(
        ( dimension       = 'DEMREVID_KFS' low = kf_fflas_grouping )
        ( dimension       = 'DEMREVID_KFS' low = kf_fflas_monthly_pct )
    ) )->sort( value #( ( 'MATCONN' ) (        'ACCOUNT' ) ( 'DEMREVID_KFS' ) ( 'TIME' ) ) ).

    loop at sap_revenues_consol->model_data into data(_sap_revenue).

      " Look for the FFLAS Grouping
      " by Material.
      read table fflas_grouping->model_data
        into data(_fflas_grouping)
          with key matconn = _sap_revenue-matconn
                        account = 'ACCOUNT_NA'
                        demrevid_kfs = kf_fflas_grouping
                        time = _sap_revenue-time
                        binary search.
      if sy-subrc is initial.
        data(_new_data) = _sap_revenue.
        _new_data-demrevid_kfs = _fflas_grouping-demrevid_kfs.
        _new_data-signeddata = _fflas_grouping-signeddata.
        new_data->append( _new_data ).

        " Look for the FFLAS Monthly Ratio(%)
        " by Material.
        read table fflas_grouping->model_data
          into data(_fflas_month_ratio)
            with key matconn = _sap_revenue-matconn
                          account = 'ACCOUNT_NA'
                          demrevid_kfs = kf_fflas_monthly_pct
                          time = _sap_revenue-time
                          binary search.
        if sy-subrc is initial.
          _new_data = _sap_revenue.
          _new_data-demrevid_kfs = _fflas_month_ratio-demrevid_kfs.
          _new_data-signeddata = _fflas_month_ratio-signeddata.
          new_data->append( _new_data ).

          fflas_month_ratio->append( _new_data ).
        endif.
      else.
        " If it can't be found by material,
        " look by Account.
        read table fflas_grouping->model_data
          into _fflas_grouping
            with key matconn = 'MATCONN_NA'
                          account = _sap_revenue-account
                          demrevid_kfs = kf_fflas_grouping
                          time = _sap_revenue-time
                          binary search.
        if sy-subrc is initial.
          _new_data = _sap_revenue.
          _new_data-demrevid_kfs = _fflas_grouping-demrevid_kfs.
          _new_data-signeddata = _fflas_grouping-signeddata.
          new_data->append( _new_data ).

          " If it can't be found by material,
          " look by Account.
          read table fflas_grouping->model_data
            into _fflas_month_ratio
              with key matconn = 'MATCONN_NA'
                             account = _sap_revenue-account
                            demrevid_kfs = kf_fflas_monthly_pct
                            time = _sap_revenue-time
                            binary search.
          if sy-subrc is initial.
            _new_data = _sap_revenue.
            _new_data-demrevid_kfs = _fflas_month_ratio-demrevid_kfs.
            _new_data-signeddata = _fflas_month_ratio-signeddata.
            new_data->append( _new_data ).
            fflas_month_ratio->append( _new_data ).
          endif.
        endif.
      endif.

    endloop.
ENDDO.
IF new_data IS BOUND.
io->check_rows( lines( new_data->model_data ) ).
io->publish_dataset( name = 'NEW_DATA' rows = new_data->model_data ).
io->emit_table( name = 'NEW_DATA' rows = new_data->model_data ).
ENDIF.
IF fflas_month_ratio IS BOUND.
io->check_rows( lines( fflas_month_ratio->model_data ) ).
io->publish_dataset( name = 'FFLAS_MONTH_RATIO' rows = fflas_month_ratio->model_data ).
io->emit_table( name = 'FFLAS_MONTH_RATIO' rows = fflas_month_ratio->model_data ).
ENDIF.
io->check_budget( ).
