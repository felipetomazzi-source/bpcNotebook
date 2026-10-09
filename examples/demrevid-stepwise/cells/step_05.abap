" Method: calc_location_alloc_ratios
" Resolve geography percentages
" Complete inputs come from the preceding method cells.
constants kf_loc_split_index type uj_dim_member value 'DEMREVID009' ##NO_TEXT.
constants kf_ratios_for_split type uj_dim_member value 'DEMREVID015' ##NO_TEXT.
TYPES rev_split_method TYPE i.
CONSTANTS rsp_billing_material TYPE i VALUE 1.
CONSTANTS rsp_billing_gl TYPE i VALUE 2.
CONSTANTS cal_gl TYPE i VALUE 3.
CONSTANTS cal_reg_split TYPE i VALUE 4.
DATA(env) = io.
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
ENDIF.
IF new_data IS BOUND.
io->check_rows( lines( new_data->model_data ) ).
io->publish_dataset( name = 'NEW_DATA' rows = new_data->model_data ).
ENDIF.
IF new_data IS BOUND.
" Complete control totals: retain key figures/audit trails so unlike measures are not mixed.
DATA(control_totals) = new_data->copy( )->group( VALUE #(
 ( 'CATEGORY' ) ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'AUDITTRAIL' ) ( 'DEMREVID_KFS' ) ) ).
io->emit_table( name = 'CONTROL_TOTALS' rows = control_totals->model_data ).
ENDIF.
io->check_budget( ).
