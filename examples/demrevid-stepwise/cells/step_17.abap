" Calculate material FFLAS ratios and skipped flags
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
DATA(ref_new_data) = io->read_dataset( dependency = 'step_16' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA sap_revenues TYPE REF TO zcl_bn_dem_model.
DATA(ref_sap_revenues) = io->read_dataset( dependency = 'step_02' name = 'SAP_REVENUES' ).
FIELD-SYMBOLS <t_sap_revenues> TYPE STANDARD TABLE.
ASSIGN ref_sap_revenues->* TO <t_sap_revenues>.
sap_revenues = NEW #( environment = io model_data = <t_sap_revenues> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
DATA fflas_ratios TYPE REF TO zcl_bn_dem_model.
fflas_ratios = new zcl_bn_dem_model( environment = env ).

    " 1. Base revenue = total SAP Actuals grouped by Category/Time/Account/Matconn, re-tagged
    "    with the audittrail used by this calculation and the FFLAS-ratio-by-Material key figure.
    data(base_revenues) = sap_revenues->copy( )->group( value #(
        ( 'CATEGORY' ) ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'MAT_GROUP_ID' ) ) )->replaces( value #(
            ( dimension = 'AUDITTRAIL' replace_with = audit_dnrid_calc )
            ( dimension = 'DEMREVID_KFS' replace_with = kf_fflas_ratios_material ) )
                 ).
    io->emit_table( name = 'RATIO_BASE_BEFORE_EXCLUSIONS' rows = base_revenues->model_data ).
    " 2. Exclude Material Groups flagged to skip the FFLAS ratio calculation (parameter FFLASMATGROUPSID).
    "    Before excluding them, keep one flag record per Time/Account/Matconn so DEMREV knows these
    "    materials were skipped and can post their fallback allocation separately (SSNG-3218).
    data(skipped_materials) = new zcl_bn_dem_model( environment = env ).
    if lines( skip_fflas_ratio_mat_group_id ) <> 0.
      loop at base_revenues->model_data into data(_skipped_material)
          where mat_group_id in skip_fflas_ratio_mat_group_id.
        clear _skipped_material-mat_group_id.
        _skipped_material-demrevid_kfs = kf_fflas_ratio_skipped.
        _skipped_material-fflas = fflas_na.
        _skipped_material-signeddata = 1.
        " One flag per Time/Account/Matconn, even if it has several revenue rows.
        if not line_exists( skipped_materials->model_data[
                              time    = _skipped_material-time
                              account = _skipped_material-account
                              matconn = _skipped_material-matconn ] ).
          skipped_materials->append( _skipped_material ).
        endif.
      endloop.

      delete base_revenues->model_data where mat_group_id in skip_fflas_ratio_mat_group_id.
    endif.
    io->emit_table( name = 'SKIPPED_MATERIAL_FLAGS' rows = skipped_materials->model_data ).
    io->emit_table( name = 'RATIO_BASE_AFTER_EXCLUSIONS' rows = base_revenues->model_data ).
    " No need of Mat. Group anymore.
    base_revenues->group( include_dimensions = abap_false group_by = value #( ( 'MAT_GROUP_ID' ) ) ).

    " 3. FFLAS revenue = Allocated Revenues (DEMREVID023) grouped by the same key plus FFLAS and
    "    MAT_GROUP_ID, so the share of the base revenue attributable to each FFLAS value can be computed.
    data(fflas_rev) = new_data->copy( value #(
            ( dimension = 'DEMREVID_KFS' low = kf_fflas_revenue ) ) )->group( value #(
               (        'CATEGORY' ) (       'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'FFLAS' ) ( 'MAT_GROUP_ID' ) ) )->replaces( value #(
            ( dimension = 'AUDITTRAIL' replace_with = audit_dnrid_calc )
            ( dimension = 'DEMREVID_KFS' replace_with = kf_fflas_ratios_material ) ) ).
    io->emit_table( name = 'FFLAS_REVENUE_NUMERATORS' rows = fflas_rev->model_data ).
    " 4. For each base revenue record with a non-zero amount, compute the ratio of every matching
    "    FFLAS revenue record to the base amount, and keep a running remainder (non_fflas_rev).
    loop at base_revenues->model_data into data(_base_rev)
        where signeddata is not initial.
      data(non_fflas_rev) = _base_rev-signeddata.
      loop at fflas_rev->model_data into data(_fflas_rev)
        where time eq _base_rev-time and
                   account eq _base_rev-account and
                   matconn eq _base_rev-matconn.
        " Track how much of the base revenue is still unaccounted for by an explicit FFLAS ratio.
        subtract _fflas_rev-signeddata from non_fflas_rev.
        " Ratio for this FFLAS value = FFLAS revenue / total (base) revenue.
        _fflas_rev-signeddata =  _fflas_rev-signeddata / _base_rev-signeddata.
        fflas_ratios->append( _fflas_rev ).
      endloop.
      " 5. Whatever remains unaccounted-for is booked to the synthetic Non-FFLAS ratio (FFLASNON),
      "    ensuring the FFLAS ratios for this Time/Account/Matconn always sum to 1.
      if non_fflas_rev is not initial.
        _base_rev-signeddata =  non_fflas_rev / _base_rev-signeddata.
        _base_rev-fflas = fflas_non.
        fflas_ratios->collect( _base_rev ).
      endif.
    endloop.

    io->emit_table( name = 'RATIOS_BEFORE_ROUNDING' rows = fflas_ratios->model_data ).
    " 6. Rounding correction: due to floating-point precision in get_ratio / division,
    "    the sum of ratios for a given Time/Account/Matconn may not be exactly 1.
    "    For each combination where the total differs from 1, the discrepancy is added
    "    to the first ratio row found (via binary search). This avoids incorrectly
    "    creating or inflating a FFLASNON row when one doesn't logically belong.
    data(fflas_ratios_cons) = fflas_ratios->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( 'FFLAS' ) ( 'MAT_GROUP_ID' ) ) )->filter( value #(
            ( dimension = 'SIGNEDDATA' option = 'NE' low = 1 ) ) ).
    sort fflas_ratios->model_data by time account matconn.
    loop at fflas_ratios_cons->model_data into data(_fflas_ratios_cons).
      read table fflas_ratios->model_data assigning field-symbol(<_fflas_ratios>)
          with key time = _fflas_ratios_cons-time
                   account = _fflas_ratios_cons-account
                   matconn = _fflas_ratios_cons-matconn
                   binary search.
      if sy-subrc is initial.
        data(balance_ratio) = conv uj_signeddata( 1 - _fflas_ratios_cons-signeddata ).
        add balance_ratio to <_fflas_ratios>-signeddata.
      endif.
    endloop.

    " 7. Add the skipped-material flags (step 2) after the rounding correction, so they are not
    "    mixed into the ratio balancing above.
    fflas_ratios->append( skipped_materials ).
    io->emit_table( name = 'RATIOS_AND_FLAGS' rows = fflas_ratios->model_data ).
new_data->append( fflas_ratios ).
ENDDO.
IF new_data IS BOUND.
io->check_rows( lines( new_data->model_data ) ).
io->publish_dataset( name = 'NEW_DATA' rows = new_data->model_data ).
io->emit_table( name = 'NEW_DATA' rows = new_data->model_data ).
ENDIF.
io->check_budget( ).
