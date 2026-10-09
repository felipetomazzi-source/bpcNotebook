" Method: calc_supplier_alloc_ratios
" Resolve supplier percentages
" Complete inputs come from the preceding method cells.
constants kf_supplier_split_index type uj_dim_member value 'DEMREVID028' ##NO_TEXT.
constants kf_supplier_split_ratio type uj_dim_member value 'DEMREVID033' ##NO_TEXT.
TYPES rev_split_method TYPE i.
CONSTANTS rsp_billing_material TYPE i VALUE 1.
CONSTANTS rsp_billing_gl TYPE i VALUE 2.
CONSTANTS cal_gl TYPE i VALUE 3.
CONSTANTS cal_reg_split TYPE i VALUE 4.
DATA(env) = io.
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_12' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA conn_reg_split TYPE REF TO zcl_bn_dem_model.
DATA(ref_conn_reg_split) = io->read_dataset( dependency = 'step_01' name = 'CONN_REG_SPLIT' ).
FIELD-SYMBOLS <t_conn_reg_split> TYPE STANDARD TABLE.
ASSIGN ref_conn_reg_split->* TO <t_conn_reg_split>.
conn_reg_split = NEW #( environment = io model_data = <t_conn_reg_split> compressed = abap_false ).
DATA rsp_supplier_material_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_rsp_supplier_material_ra) = io->read_dataset( dependency = 'step_01' name = 'RSP_SUPPLIER_MATERIAL_RATIO' ).
FIELD-SYMBOLS <t_rsp_supplier_material_rat> TYPE STANDARD TABLE.
ASSIGN ref_rsp_supplier_material_ra->* TO <t_rsp_supplier_material_rat>.
rsp_supplier_material_ratio = NEW #( environment = io model_data = <t_rsp_supplier_material_rat> compressed = abap_false ).
DATA rsp_supplier_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_rsp_supplier_gl_ratio) = io->read_dataset( dependency = 'step_01' name = 'RSP_SUPPLIER_GL_RATIO' ).
FIELD-SYMBOLS <t_rsp_supplier_gl_ratio> TYPE STANDARD TABLE.
ASSIGN ref_rsp_supplier_gl_ratio->* TO <t_rsp_supplier_gl_ratio>.
rsp_supplier_gl_ratio = NEW #( environment = io model_data = <t_rsp_supplier_gl_ratio> compressed = abap_false ).
DATA cal_supplier_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_cal_supplier_gl_ratio) = io->read_dataset( dependency = 'step_01' name = 'CAL_SUPPLIER_GL_RATIO' ).
FIELD-SYMBOLS <t_cal_supplier_gl_ratio> TYPE STANDARD TABLE.
ASSIGN ref_cal_supplier_gl_ratio->* TO <t_cal_supplier_gl_ratio>.
cal_supplier_gl_ratio = NEW #( environment = io model_data = <t_cal_supplier_gl_ratio> compressed = abap_false ).
DATA cal_supplier_conn_seg_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_cal_supplier_conn_seg_ra) = io->read_dataset( dependency = 'step_01' name = 'CAL_SUPPLIER_CONN_SEG_RATIO' ).
FIELD-SYMBOLS <t_cal_supplier_conn_seg_rat> TYPE STANDARD TABLE.
ASSIGN ref_cal_supplier_conn_seg_ra->* TO <t_cal_supplier_conn_seg_rat>.
cal_supplier_conn_seg_ratio = NEW #( environment = io model_data = <t_cal_supplier_conn_seg_rat> compressed = abap_false ).
DATA supplier_ratios TYPE REF TO zcl_bn_dem_model.

io->check_budget( ).
DO 1 TIMES.
supplier_ratios = new zcl_bn_dem_model( environment = env ).
    loop at new_data->model_data into data(_supplier_split_method)
        where demrevid_kfs eq kf_supplier_split_index.
      _supplier_split_method-demrevid_kfs = kf_supplier_split_ratio.
      data(method_enum) = conv rev_split_method( conv i( _supplier_split_method-signeddata ) ).
      case method_enum.
        when rsp_billing_material.
          loop at rsp_supplier_material_ratio->model_data into data(_rsp_supplier_material_ratio)
                where time eq _supplier_split_method-time and
                            account eq _supplier_split_method-account and
                            matconn eq _supplier_split_method-matconn.
            _supplier_split_method-lfc_win_supplier = _rsp_supplier_material_ratio-lfc_win_supplier.
            _supplier_split_method-signeddata = _rsp_supplier_material_ratio-signeddata.
            supplier_ratios->append( _supplier_split_method ).
          endloop.
        when rsp_billing_gl.
          loop at rsp_supplier_gl_ratio->model_data into data(_rsp_supplier_gl_ratio)
                where account eq _supplier_split_method-account and
                            time eq _supplier_split_method-time.
            _supplier_split_method-lfc_win_supplier = _rsp_supplier_gl_ratio-lfc_win_supplier.
            _supplier_split_method-signeddata = _rsp_supplier_gl_ratio-signeddata.
            supplier_ratios->append( _supplier_split_method ).
          endloop.
        when cal_gl.
          loop at cal_supplier_gl_ratio->model_data into data(_cal_supplier_gl_ratio)
                where account eq _supplier_split_method-account and
                            time eq _supplier_split_method-time.
            _supplier_split_method-lfc_win_supplier = _cal_supplier_gl_ratio-lfc_win_supplier.
            _supplier_split_method-signeddata = _cal_supplier_gl_ratio-signeddata.
            supplier_ratios->append( _supplier_split_method ).
          endloop.
        when cal_reg_split.
          loop at cal_supplier_conn_seg_ratio->model_data into data(_cal_supplier_conn_seg_ratio)
                where conn_reg_split eq _supplier_split_method-conn_reg_split and
                            time eq _supplier_split_method-time.
            _supplier_split_method-lfc_win_supplier = _cal_supplier_conn_seg_ratio-lfc_win_supplier.
            _supplier_split_method-signeddata = _cal_supplier_conn_seg_ratio-signeddata.
            supplier_ratios->append( _supplier_split_method ).
          endloop.
      endcase.
    endloop.
    supplier_ratios->sort( value #( ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ) ).
    new_data->append( supplier_ratios ).
ENDDO.
IF new_data IS BOUND.
io->check_rows( lines( new_data->model_data ) ).
io->publish_dataset( name = 'NEW_DATA' rows = new_data->model_data ).
ENDIF.
IF supplier_ratios IS BOUND.
io->check_rows( lines( supplier_ratios->model_data ) ).
io->publish_dataset( name = 'SUPPLIER_RATIOS' rows = supplier_ratios->model_data ).
ENDIF.
IF new_data IS BOUND.
" Complete control totals: retain key figures/audit trails so unlike measures are not mixed.
DATA(control_totals) = new_data->copy( )->group( VALUE #(
 ( 'CATEGORY' ) ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'AUDITTRAIL' ) ( 'DEMREVID_KFS' ) ) ).
io->emit_table( name = 'CONTROL_TOTALS' rows = control_totals->model_data ).
ENDIF.
io->check_budget( ).
