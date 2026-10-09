" Resolve geography percentages
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
IF io->input( 'FFLASMATGROUPS' ) = 'false'. CLEAR skip_fflas_ratio_mat_group_id. ENDIF.
DATA(product_type_dim) = NEW zcl_bn_dimension( io = io name = 'PRODUCT_TYPE' ).
DATA(mat_group_id_dim) = NEW zcl_bn_dimension( io = io name = 'MAT_GROUP_ID' ).
DATA(matconn_dim) = NEW zcl_bn_dimension( io = io name = 'MATCONN' ).
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_04' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA conn_reg_split TYPE REF TO zcl_bn_dem_model.
DATA(ref_conn_reg_split) = io->read_dataset( dependency = 'step_01' name = 'CONN_REG_SPLIT' ).
FIELD-SYMBOLS <t_conn_reg_split> TYPE STANDARD TABLE.
ASSIGN ref_conn_reg_split->* TO <t_conn_reg_split>.
conn_reg_split = NEW #( environment = io model_data = <t_conn_reg_split> compressed = abap_false ).
DATA rsp_location_material_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_rsp_location_material_ra) = io->read_dataset( dependency = 'step_01' name = 'RSP_LOCATION_MATERIAL_RATIO' ).
FIELD-SYMBOLS <t_rsp_location_material_rat> TYPE STANDARD TABLE.
ASSIGN ref_rsp_location_material_ra->* TO <t_rsp_location_material_rat>.
rsp_location_material_ratio = NEW #( environment = io model_data = <t_rsp_location_material_rat> compressed = abap_false ).
DATA rsp_location_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_rsp_location_gl_ratio) = io->read_dataset( dependency = 'step_01' name = 'RSP_LOCATION_GL_RATIO' ).
FIELD-SYMBOLS <t_rsp_location_gl_ratio> TYPE STANDARD TABLE.
ASSIGN ref_rsp_location_gl_ratio->* TO <t_rsp_location_gl_ratio>.
rsp_location_gl_ratio = NEW #( environment = io model_data = <t_rsp_location_gl_ratio> compressed = abap_false ).
DATA cal_location_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_cal_location_gl_ratio) = io->read_dataset( dependency = 'step_01' name = 'CAL_LOCATION_GL_RATIO' ).
FIELD-SYMBOLS <t_cal_location_gl_ratio> TYPE STANDARD TABLE.
ASSIGN ref_cal_location_gl_ratio->* TO <t_cal_location_gl_ratio>.
cal_location_gl_ratio = NEW #( environment = io model_data = <t_cal_location_gl_ratio> compressed = abap_false ).
DATA cal_location_conn_seg_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_cal_location_conn_seg_ra) = io->read_dataset( dependency = 'step_01' name = 'CAL_LOCATION_CONN_SEG_RATIO' ).
FIELD-SYMBOLS <t_cal_location_conn_seg_rat> TYPE STANDARD TABLE.
ASSIGN ref_cal_location_conn_seg_ra->* TO <t_cal_location_conn_seg_rat>.
cal_location_conn_seg_ratio = NEW #( environment = io model_data = <t_cal_location_conn_seg_rat> compressed = abap_false ).
DATA rsp_split_ratios TYPE REF TO zcl_bn_dem_model.

io->check_budget( ).
DO 1 TIMES.
rsp_split_ratios = new #( environment = env ).
    loop at new_data->model_data into data(_new_data)
        where demrevid_kfs eq kf_loc_split_index.
      _new_data-demrevid_kfs = kf_ratios_for_split.
      data(method_enum) = conv rev_split_method( conv i( _new_data-signeddata ) ).
      case method_enum.
        when rsp_billing_material.
          " Use the overwritten RSP Billing Ratio if available.
          read table rsp_location_material_ratio->model_data
            transporting no fields
                with key time = _new_data-time
                         matconn = _new_data-matconn
                         audittrail = 'DEMREVID_LOC_RATIO_OVERWRITE'.
          if sy-subrc is initial.
            loop at rsp_location_material_ratio->model_data into data(_rsp_billing_material_ratio)
                  where time eq _new_data-time and
                             matconn eq _new_data-matconn and
                             audittrail eq 'DEMREVID_LOC_RATIO_OVERWRITE'.
              _new_data-geo_drivers = _rsp_billing_material_ratio-geo_drivers.
              _new_data-signeddata = _rsp_billing_material_ratio-signeddata.
              rsp_split_ratios->append( _new_data ).
            endloop.
          else.
            loop at rsp_location_material_ratio->model_data into _rsp_billing_material_ratio
                    where time eq _new_data-time and
                               matconn eq _new_data-matconn and
                               audittrail eq 'DEMREVID_RSP_BILLING'.
              _new_data-geo_drivers = _rsp_billing_material_ratio-geo_drivers.
              _new_data-signeddata = _rsp_billing_material_ratio-signeddata.
              rsp_split_ratios->append( _new_data ).
            endloop.
          endif.
        when rsp_billing_gl.
          loop at rsp_location_gl_ratio->model_data into data(_rsp_billing_gl_ratio)
                where account eq _new_data-account and
                            time eq _new_data-time.
            _new_data-geo_drivers = _rsp_billing_gl_ratio-geo_drivers.
            _new_data-signeddata = _rsp_billing_gl_ratio-signeddata.
            rsp_split_ratios->append( _new_data ).
          endloop.
        when cal_gl.
          loop at cal_location_gl_ratio->model_data into data(_cal_gl_ratio)
                where account eq _new_data-account and
                            time eq _new_data-time.
            _new_data-geo_drivers = _cal_gl_ratio-geo_drivers.
            _new_data-signeddata = _cal_gl_ratio-signeddata.
            rsp_split_ratios->append( _new_data ).
          endloop.
        when cal_reg_split.
          loop at cal_location_conn_seg_ratio->model_data into data(_cal_conn_seg_ratio)
                where conn_reg_split eq _new_data-conn_reg_split and
                            time eq _new_data-time.
            _new_data-geo_drivers = _cal_conn_seg_ratio-geo_drivers.
            _new_data-signeddata = _cal_conn_seg_ratio-signeddata.
            rsp_split_ratios->append( _new_data ).
          endloop.
      endcase.
    endloop.
    new_data->append( rsp_split_ratios ).
ENDDO.
IF rsp_split_ratios IS BOUND.
io->check_rows( lines( rsp_split_ratios->model_data ) ).
io->publish_dataset( name = 'RSP_SPLIT_RATIOS' rows = rsp_split_ratios->model_data ).
io->emit_table( name = 'RSP_SPLIT_RATIOS' rows = rsp_split_ratios->model_data ).
ENDIF.
IF new_data IS BOUND.
io->check_rows( lines( new_data->model_data ) ).
io->publish_dataset( name = 'NEW_DATA' rows = new_data->model_data ).
io->emit_table( name = 'NEW_DATA' rows = new_data->model_data ).
ENDIF.
io->check_budget( ).
