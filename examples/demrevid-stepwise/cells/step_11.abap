" Method: calc_pq_fflas_ratio
" Calculate the PQ share
" Complete inputs come from the preceding method cells.
constants kf_fflas_revenue type uj_dim_member value 'DEMREVID023' ##NO_TEXT.
constants kf_pq_fflas_pct type uj_dim_member value 'DEMREVID025' ##NO_TEXT.
constants fflas_pq type uj_dim_member value 'FFLASPQ' ##NO_TEXT.
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_10' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
DATA stage_result TYPE REF TO zcl_bn_dem_model.
data(fflas_revenues) = new_data->copy( value #(
                  ( dimension = 'DEMREVID_KFS' low     = kf_fflas_revenue  )
      ) ).

    " Consolidate the FFLAS revenues - remove Geography and FFLAS to get total per Time/Account/Matconn.
    data(fflas_rev_consolidated) = fflas_revenues->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( 'GEO_DRIVERS' ) ( 'FFLAS' ) ) )->sort( value #(
                            ( 'TIME' )        ( 'ACCOUNT' ) ( 'MATCONN' ) ) ).

    " Filter to PQ FFLAS only and consolidate by Time/Account/Matconn.
    data(pq_fflas_rev) = fflas_revenues->copy( value #(
        ( dimension               = 'FFLAS' low = fflas_pq ) ) )->group(
            include_dimensions = abap_false
            group_by = value #( ( 'GEO_DRIVERS' ) ) )->sort( value #(
                                ( 'TIME' ) (    'ACCOUNT' ) ( 'MATCONN' ) ) ).

    " PQ FFLAS ratio = PQ FFLAS Revenue / Total Revenue (per Time/Account/Matconn).
    pq_fflas_rev->divide(
      divide_data     = fflas_rev_consolidated->model_data
      read_dimensions = value #(
          ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ) )->replace( dimension = 'DEMREVID_KFS' replace_with = kf_pq_fflas_pct ).

    stage_result = pq_fflas_rev.
new_data->append( stage_result ).
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
