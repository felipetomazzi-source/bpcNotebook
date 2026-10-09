" Load revenues and allocation drivers
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
DATA it_param TYPE ujk_t_script_logic_hashtable. it_param = parameters.
DATA(current_view) = io->current_view( ).
DATA time TYPE ujw_t_dimmem_range.
DATA input_data TYPE REF TO zcl_bn_dem_model.
DATA output_data TYPE REF TO zcl_bn_dem_model.
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA conn_reg_split TYPE REF TO zcl_bn_dem_model.
DATA l1_l2_mapping TYPE REF TO zcl_bn_dem_model.
DATA rsp_location_material_ratio TYPE REF TO zcl_bn_dem_model.
DATA rsp_location_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA rsp_supplier_material_ratio TYPE REF TO zcl_bn_dem_model.
DATA cal_location_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA cal_location_conn_seg_ratio TYPE REF TO zcl_bn_dem_model.
DATA sap_revenues TYPE REF TO zcl_bn_dem_model.
DATA rsp_supplier_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA cal_supplier_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA cal_supplier_conn_seg_ratio TYPE REF TO zcl_bn_dem_model.
DATA mat_group_mapping TYPE REF TO zcl_bn_dem_model.

io->check_budget( ).
DO 1 TIMES.
param = new #( it_param ).

    " Parse the BPC current view and resolve the Category and Time range for this run.
    data(cv_obj) = new zcl_bpc_current_view( current_view ).
    category = current_view[ dimension = 'CATEGORY' ]-member[ 1 ].
    time = cv_obj->get_dimmem_range( 'TIME' ).

    if param->get_value( 'DEBUG' ) = 'ON'.
      cl_ujk_logger=>log( |Selected Category: | ).
      cl_ujk_logger=>log( category ).
    endif.

    " Instantiate the BPC environment handle and its dependent dimension helpers.
    IF env IS NOT BOUND. RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = 'CONTEXT' detail = 'Use execute with a frozen context'. ENDIF.
    product_type_dim = NEW #( io = env name = 'PRODUCT_TYPE' ).
    mat_group_id_dim = NEW #( io = env name = 'MAT_GROUP_ID' ).
    matconn_dim = NEW #( io = env name = 'MATCONN' ).

    " Base DEMREVID data set (Time/Category filtered), used to derive the INPUT/OUTPUT/NEW views below.
    data(demrevid_data) =
      new zcl_bn_dem_model(
        environment = env
        filters = value #(
          ( dimension = 'TIME'     in = time )
          ( dimension = 'TIME'     low = 'TIME_NA' )
          ( dimension = 'CATEGORY' low = category )
    ) ).

    " Read data from BPC Models.
    input_data = demrevid_data->copy( value #( ( dimension = 'AUDITTRAIL' hier_name = 'PARENTH1' low = 'DEMREVID_INPUT' ) ) ).
    output_data = demrevid_data->copy( value #( ( dimension = 'AUDITTRAIL' hier_name = 'PARENTH1' low = 'DEMREVID_OUTPUT' ) ) ).
    new_data = new zcl_bn_dem_model( environment = env ).

    " Initialise objects used in calculation.
    " Load and pre-sort every reference data set required by the allocation/ratio methods below.
    sap_revenues =
        input_data->copy( value #(
            ( dimension = 'DEMREVID_KFS' hier_name = 'PARENTH1' low = kf_sap_revenues ) ) )->group(
                include_dimensions = abap_false
               group_by =  value #(  ( 'COSTCENTRE' ) ( 'DOC_TYP' ) ( 'AUDITTRAIL' )  ) )->replace(
                    dimension = 'AUDITTRAIL' replace_with = audit_dnrid_calc ).

    conn_reg_split =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_conn_region_mapping ) ) )->sort( value #(
                    (       'TIME' ) (           'ACCOUNT' ) ) ).

    l1_l2_mapping =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_l1_l2_mapping ) ) )->sort( value #(
                    (       'TIME' ) (           'ACCOUNT' ) ) ).

    mat_group_mapping =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_mat_group_mapping ) ) )->sort( value #(
                    (       'TIME' ) (           'MATCONN' ) ( 'ACCOUNT' ) ) ).

    rsp_location_material_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_rsp_loc_ratio_mat )
    ) )->sort( value #(
                     (      'TIME' ) (           'MATCONN' ) ) ).

    rsp_location_gl_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_rsp_loc_ratio_gl ) ) )->sort( value #(
                     (      'TIME' ) (           'ACCOUNT' ) ) ).

    cal_location_gl_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_cal_loc_ratio_gl ) ) )->sort( value #(
                    (       'TIME' ) (           'ACCOUNT' ) ) ).

    cal_location_conn_seg_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_cal_loc_ratio_conn_reg ) ) )->sort( value #(
                   (        'TIME' ) (           'CONN_REG_SPLIT' ) ) ).

    rsp_supplier_material_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_rsp_supplier_ratio_mat ) ) )->sort( value #(
                    (       'TIME' ) (           'ACCOUNT' ) ( 'MATCONN' ) ) ).

    rsp_supplier_gl_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_rsp_supplier_ratio_gl ) ) )->sort( value #(
                    (       'ACCOUNT' ) (        'TIME' ) ) ).

    cal_supplier_gl_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_cal_supplier_ratio_gl ) ) )->sort( value #(
                    (       'ACCOUNT' ) (        'TIME' ) ) ).

    cal_supplier_conn_seg_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_cal_supplier_ratio_conn_reg ) ) )->sort( value #(
                    (       'CONN_REG_SPLIT' ) ( 'TIME' ) ) ).

    " Contains list of Material Groups that will have its FFLAS Ratio Calculation skipped.
    data(skip_fflas_ratio_mat_group) = param->get_dimmem_range( 'FFLASMATGROUPS' ).
    skip_fflas_ratio_mat_group_id = param->get_dimmem_range( 'FFLASMATGROUPSID').
    loop at skip_fflas_ratio_mat_group_id into data(_skip_fflas_ratio_mat_group_id).
      read table skip_fflas_ratio_mat_group into data(_skip_fflas_ratio_mat_group)
          index sy-tabix.
      if sy-subrc is not initial or _skip_fflas_ratio_mat_group-low eq 0.
        delete skip_fflas_ratio_mat_group_id.
      endif.
    endloop.
ENDDO.
IF input_data IS BOUND.
io->check_rows( lines( input_data->model_data ) ).
io->publish_dataset( name = 'INPUT_DATA' rows = input_data->model_data ).
io->emit_table( name = 'INPUT_DATA' rows = input_data->model_data max_rows = preview_rows ).
ENDIF.
IF output_data IS BOUND.
io->check_rows( lines( output_data->model_data ) ).
io->publish_dataset( name = 'OUTPUT_DATA' rows = output_data->model_data ).
io->emit_table( name = 'OUTPUT_DATA' rows = output_data->model_data max_rows = preview_rows ).
ENDIF.
IF new_data IS BOUND.
io->check_rows( lines( new_data->model_data ) ).
io->publish_dataset( name = 'NEW_DATA' rows = new_data->model_data ).
io->emit_table( name = 'NEW_DATA' rows = new_data->model_data max_rows = preview_rows ).
ENDIF.
IF sap_revenues IS BOUND.
io->check_rows( lines( sap_revenues->model_data ) ).
io->publish_dataset( name = 'SAP_REVENUES' rows = sap_revenues->model_data ).
io->emit_table( name = 'SAP_REVENUES' rows = sap_revenues->model_data max_rows = preview_rows ).
ENDIF.
IF conn_reg_split IS BOUND.
io->check_rows( lines( conn_reg_split->model_data ) ).
io->publish_dataset( name = 'CONN_REG_SPLIT' rows = conn_reg_split->model_data ).
io->emit_table( name = 'CONN_REG_SPLIT' rows = conn_reg_split->model_data max_rows = preview_rows ).
ENDIF.
IF l1_l2_mapping IS BOUND.
io->check_rows( lines( l1_l2_mapping->model_data ) ).
io->publish_dataset( name = 'L1_L2_MAPPING' rows = l1_l2_mapping->model_data ).
io->emit_table( name = 'L1_L2_MAPPING' rows = l1_l2_mapping->model_data max_rows = preview_rows ).
ENDIF.
IF mat_group_mapping IS BOUND.
io->check_rows( lines( mat_group_mapping->model_data ) ).
io->publish_dataset( name = 'MAT_GROUP_MAPPING' rows = mat_group_mapping->model_data ).
io->emit_table( name = 'MAT_GROUP_MAPPING' rows = mat_group_mapping->model_data max_rows = preview_rows ).
ENDIF.
IF rsp_location_material_ratio IS BOUND.
io->check_rows( lines( rsp_location_material_ratio->model_data ) ).
io->publish_dataset( name = 'RSP_LOCATION_MATERIAL_RATIO' rows = rsp_location_material_ratio->model_data ).
io->emit_table( name = 'RSP_LOCATION_MATERIAL_RATIO' rows = rsp_location_material_ratio->model_data max_rows = preview_rows ).
ENDIF.
IF rsp_location_gl_ratio IS BOUND.
io->check_rows( lines( rsp_location_gl_ratio->model_data ) ).
io->publish_dataset( name = 'RSP_LOCATION_GL_RATIO' rows = rsp_location_gl_ratio->model_data ).
io->emit_table( name = 'RSP_LOCATION_GL_RATIO' rows = rsp_location_gl_ratio->model_data max_rows = preview_rows ).
ENDIF.
IF cal_location_gl_ratio IS BOUND.
io->check_rows( lines( cal_location_gl_ratio->model_data ) ).
io->publish_dataset( name = 'CAL_LOCATION_GL_RATIO' rows = cal_location_gl_ratio->model_data ).
io->emit_table( name = 'CAL_LOCATION_GL_RATIO' rows = cal_location_gl_ratio->model_data max_rows = preview_rows ).
ENDIF.
IF cal_location_conn_seg_ratio IS BOUND.
io->check_rows( lines( cal_location_conn_seg_ratio->model_data ) ).
io->publish_dataset( name = 'CAL_LOCATION_CONN_SEG_RATIO' rows = cal_location_conn_seg_ratio->model_data ).
io->emit_table( name = 'CAL_LOCATION_CONN_SEG_RATIO' rows = cal_location_conn_seg_ratio->model_data max_rows = preview_rows ).
ENDIF.
IF rsp_supplier_material_ratio IS BOUND.
io->check_rows( lines( rsp_supplier_material_ratio->model_data ) ).
io->publish_dataset( name = 'RSP_SUPPLIER_MATERIAL_RATIO' rows = rsp_supplier_material_ratio->model_data ).
io->emit_table( name = 'RSP_SUPPLIER_MATERIAL_RATIO' rows = rsp_supplier_material_ratio->model_data max_rows = preview_rows ).
ENDIF.
IF rsp_supplier_gl_ratio IS BOUND.
io->check_rows( lines( rsp_supplier_gl_ratio->model_data ) ).
io->publish_dataset( name = 'RSP_SUPPLIER_GL_RATIO' rows = rsp_supplier_gl_ratio->model_data ).
io->emit_table( name = 'RSP_SUPPLIER_GL_RATIO' rows = rsp_supplier_gl_ratio->model_data max_rows = preview_rows ).
ENDIF.
IF cal_supplier_gl_ratio IS BOUND.
io->check_rows( lines( cal_supplier_gl_ratio->model_data ) ).
io->publish_dataset( name = 'CAL_SUPPLIER_GL_RATIO' rows = cal_supplier_gl_ratio->model_data ).
io->emit_table( name = 'CAL_SUPPLIER_GL_RATIO' rows = cal_supplier_gl_ratio->model_data max_rows = preview_rows ).
ENDIF.
IF cal_supplier_conn_seg_ratio IS BOUND.
io->check_rows( lines( cal_supplier_conn_seg_ratio->model_data ) ).
io->publish_dataset( name = 'CAL_SUPPLIER_CONN_SEG_RATIO' rows = cal_supplier_conn_seg_ratio->model_data ).
io->emit_table( name = 'CAL_SUPPLIER_CONN_SEG_RATIO' rows = cal_supplier_conn_seg_ratio->model_data max_rows = preview_rows ).
ENDIF.
io->check_budget( ).
