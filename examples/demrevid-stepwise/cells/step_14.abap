" Method: calc_alloc_id_rev_supplier
" Allocate ID-only revenue by supplier
" Complete inputs come from the preceding method cells.
constants kf_fflas_revenue type uj_dim_member value 'DEMREVID023' ##NO_TEXT.
constants fflas_id type uj_dim_member value 'FFLASID' ##NO_TEXT.
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_13' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA supplier_ratios TYPE REF TO zcl_bn_dem_model.
DATA(ref_supplier_ratios) = io->read_dataset( dependency = 'step_13' name = 'SUPPLIER_RATIOS' ).
FIELD-SYMBOLS <t_supplier_ratios> TYPE STANDARD TABLE.
ASSIGN ref_supplier_ratios->* TO <t_supplier_ratios>.
supplier_ratios = NEW #( environment = io model_data = <t_supplier_ratios> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
data id_fflas_by_supplier like new_data->model_data.
    loop at new_data->model_data into data(_id_only_rev)
        where demrevid_kfs eq kf_fflas_revenue and
                  fflas eq fflas_id.
      read table supplier_ratios->model_data transporting no fields
          with key time = _id_only_rev-time
                       account = _id_only_rev-account
                       matconn = _id_only_rev-matconn
                       binary search.
      if sy-subrc is not initial.
        continue.
      endif.

      delete new_data->model_data.
      loop at supplier_ratios->model_data into data(_supplier_ratios)
        where time eq _id_only_rev-time and
                   account eq _id_only_rev-account and
                   matconn eq _id_only_rev-matconn.
        data(_new_data) = _id_only_rev.
        _new_data-signeddata = _id_only_rev-signeddata * _supplier_ratios-signeddata.
        _new_data-lfc_win_supplier = _supplier_ratios-lfc_win_supplier.
        append _new_data to id_fflas_by_supplier.
      endloop.
    endloop.

    new_data->append( id_fflas_by_supplier ).
ENDDO.
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
