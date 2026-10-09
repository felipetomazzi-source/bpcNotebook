" Method: initialise
" Load revenues and allocation drivers
" Complete inputs come from the preceding method cells.
constants kf_sap_revenues type uj_dim_member value 'DEMREVID004' ##NO_TEXT.
constants kf_conn_region_mapping type uj_dim_member value 'DEMREVID008' ##NO_TEXT.
constants kf_rsp_loc_ratio_mat type uj_dim_member value 'DEMREVID010' ##NO_TEXT.
constants kf_rsp_loc_ratio_gl type uj_dim_member value 'DEMREVID011' ##NO_TEXT.
constants kf_cal_loc_ratio_gl type uj_dim_member value 'DEMREVID012' ##NO_TEXT.
constants kf_cal_loc_ratio_conn_reg type uj_dim_member value 'DEMREVID013' ##NO_TEXT.
constants kf_l1_l2_mapping type uj_dim_member value 'DEMREVID027' ##NO_TEXT.
constants kf_rsp_supplier_ratio_mat type uj_dim_member value 'DEMREVID029' ##NO_TEXT.
constants kf_rsp_supplier_ratio_gl type uj_dim_member value 'DEMREVID030' ##NO_TEXT.
constants kf_cal_supplier_ratio_conn_reg type uj_dim_member value 'DEMREVID031' ##NO_TEXT.
constants kf_cal_supplier_ratio_gl type uj_dim_member value 'DEMREVID032' ##NO_TEXT.
constants kf_mat_group_mapping type uj_dim_member value 'DEMREVID035' ##NO_TEXT.
constants audit_dnrid_calc type uj_dim_member value 'DEMREVID_CALC' ##NO_TEXT.

DATA(env) = io.

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
DATA product_type_dim TYPE REF TO zcl_bn_dimension.
DATA mat_group_id_dim TYPE REF TO zcl_bn_dimension.
DATA matconn_dim TYPE REF TO zcl_bn_dimension.
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
DATA complete_source_data TYPE REF TO zcl_bn_dem_model.

io->check_budget( ).
DO 1 TIMES.
DATA(source_adapter) = io->reference_model( ).
DATA(source_ref) = source_adapter->read_data( max_rows = CONV i( io->input( 'READ_LIMIT' ) ) ).
FIELD-SYMBOLS <source_facts> TYPE STANDARD TABLE.
ASSIGN source_ref->* TO <source_facts>.
complete_source_data = NEW #( environment = io model_data = <source_facts> compressed = abap_false ).
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
      complete_source_data->copy( value #(
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
IF complete_source_data IS BOUND.
io->check_rows( lines( complete_source_data->model_data ) ).
io->publish_dataset( name = 'COMPLETE_SOURCE_DATA' rows = complete_source_data->model_data ).
ENDIF.
IF input_data IS BOUND.
io->check_rows( lines( input_data->model_data ) ).
io->publish_dataset( name = 'INPUT_DATA' rows = input_data->model_data ).
ENDIF.
IF output_data IS BOUND.
io->check_rows( lines( output_data->model_data ) ).
io->publish_dataset( name = 'OUTPUT_DATA' rows = output_data->model_data ).
ENDIF.
IF new_data IS BOUND.
io->check_rows( lines( new_data->model_data ) ).
io->publish_dataset( name = 'NEW_DATA' rows = new_data->model_data ).
ENDIF.
IF sap_revenues IS BOUND.
io->check_rows( lines( sap_revenues->model_data ) ).
io->publish_dataset( name = 'SAP_REVENUES' rows = sap_revenues->model_data ).
ENDIF.
IF conn_reg_split IS BOUND.
io->check_rows( lines( conn_reg_split->model_data ) ).
io->publish_dataset( name = 'CONN_REG_SPLIT' rows = conn_reg_split->model_data ).
ENDIF.
IF l1_l2_mapping IS BOUND.
io->check_rows( lines( l1_l2_mapping->model_data ) ).
io->publish_dataset( name = 'L1_L2_MAPPING' rows = l1_l2_mapping->model_data ).
ENDIF.
IF mat_group_mapping IS BOUND.
io->check_rows( lines( mat_group_mapping->model_data ) ).
io->publish_dataset( name = 'MAT_GROUP_MAPPING' rows = mat_group_mapping->model_data ).
ENDIF.
IF rsp_location_material_ratio IS BOUND.
io->check_rows( lines( rsp_location_material_ratio->model_data ) ).
io->publish_dataset( name = 'RSP_LOCATION_MATERIAL_RATIO' rows = rsp_location_material_ratio->model_data ).
ENDIF.
IF rsp_location_gl_ratio IS BOUND.
io->check_rows( lines( rsp_location_gl_ratio->model_data ) ).
io->publish_dataset( name = 'RSP_LOCATION_GL_RATIO' rows = rsp_location_gl_ratio->model_data ).
ENDIF.
IF cal_location_gl_ratio IS BOUND.
io->check_rows( lines( cal_location_gl_ratio->model_data ) ).
io->publish_dataset( name = 'CAL_LOCATION_GL_RATIO' rows = cal_location_gl_ratio->model_data ).
ENDIF.
IF cal_location_conn_seg_ratio IS BOUND.
io->check_rows( lines( cal_location_conn_seg_ratio->model_data ) ).
io->publish_dataset( name = 'CAL_LOCATION_CONN_SEG_RATIO' rows = cal_location_conn_seg_ratio->model_data ).
ENDIF.
IF rsp_supplier_material_ratio IS BOUND.
io->check_rows( lines( rsp_supplier_material_ratio->model_data ) ).
io->publish_dataset( name = 'RSP_SUPPLIER_MATERIAL_RATIO' rows = rsp_supplier_material_ratio->model_data ).
ENDIF.
IF rsp_supplier_gl_ratio IS BOUND.
io->check_rows( lines( rsp_supplier_gl_ratio->model_data ) ).
io->publish_dataset( name = 'RSP_SUPPLIER_GL_RATIO' rows = rsp_supplier_gl_ratio->model_data ).
ENDIF.
IF cal_supplier_gl_ratio IS BOUND.
io->check_rows( lines( cal_supplier_gl_ratio->model_data ) ).
io->publish_dataset( name = 'CAL_SUPPLIER_GL_RATIO' rows = cal_supplier_gl_ratio->model_data ).
ENDIF.
IF cal_supplier_conn_seg_ratio IS BOUND.
io->check_rows( lines( cal_supplier_conn_seg_ratio->model_data ) ).
io->publish_dataset( name = 'CAL_SUPPLIER_CONN_SEG_RATIO' rows = cal_supplier_conn_seg_ratio->model_data ).
ENDIF.
IF sap_revenues IS BOUND.
" Complete control totals: retain key figures/audit trails so unlike measures are not mixed.
DATA(control_totals) = sap_revenues->copy( )->group( VALUE #(
 ( 'CATEGORY' ) ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'AUDITTRAIL' ) ( 'DEMREVID_KFS' ) ) ).
io->emit_table( name = 'CONTROL_TOTALS' rows = control_totals->model_data ).
ENDIF.
io->check_budget( ).
