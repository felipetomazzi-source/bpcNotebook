" Method: calc_pq_id_fflas_revenue
" Split revenue into PQ, ID-only and non-FFLAS
" Complete inputs come from the preceding method cells.
constants kf_rsp_bill_with_loc type uj_dim_member value 'DEMREVID016' ##NO_TEXT.
constants kf_rsp_not_billed_loc type uj_dim_member value 'DEMREVID018' ##NO_TEXT.
constants kf_fflas_monthly_pct type uj_dim_member value 'DEMREVID022' ##NO_TEXT.
constants kf_fflas_revenue type uj_dim_member value 'DEMREVID023' ##NO_TEXT.
constants geo_lfc type uj_dim_member value 'GDRVS_001' ##NO_TEXT.
constants geo_ronz type uj_dim_member value 'GDRVS_002' ##NO_TEXT.
constants geo_ufb type uj_dim_member value 'GDRVS_003' ##NO_TEXT.
constants fflas_id type uj_dim_member value 'FFLASID' ##NO_TEXT.
constants fflas_non type uj_dim_member value 'FFLASNON' ##NO_TEXT.
constants fflas_pq type uj_dim_member value 'FFLASPQ' ##NO_TEXT.
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_09' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
DATA stage_result TYPE REF TO zcl_bn_dem_model.
" Retrieve the Revenues (both RSP Billend and Accrual) allocated by Geographies (Location).
    " Also assign the FFLAS type depending on the Geography.
    data(rev_by_location) = new_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' option       = 'BT'      low     = kf_rsp_bill_with_loc high = kf_rsp_not_billed_loc )
    ) )->replaces( value #(
                ( dimension = 'DEMREVID_KFS' replace_with = kf_fflas_revenue )
                ( dimension = 'FFLAS'        replace_with = fflas_pq filters = value #( ( dimension = 'GEO_DRIVERS' option = 'BT' low = geo_ronz high = geo_ufb ) ) )
                ( dimension = 'FFLAS'        replace_with = fflas_id filters = value #( ( dimension = 'GEO_DRIVERS' low    = geo_lfc ) ) )
    ) )->group( ).

    " Manual Input - FFLAS ratio by Material/Account.
    data(fflas_alloc_ratio) = new_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_fflas_monthly_pct ) ) )->sort( value #(
            (       'TIME' ) (           'ACCOUNT' ) ( 'MATCONN' ) ) ).

    " Apply FFLAS ratio in the Revenue allocated by Geography.
    data(rev_alloc_by_fflas) = rev_by_location->copy( )->multiply(
      multiply_data = fflas_alloc_ratio->model_data
      read_dimensions = value #( ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ) ).
    delete rev_alloc_by_fflas->model_data where signeddata is initial.

    " If revenues aren't fully allocated by the FFLAS ratio (i.e. the ratio < 100%),
    " the unallocated balance is assigned to Non-FFLAS. This is computed as:
    " balance = total revenue by location - sum of FFLAS-allocated revenue (per Time/Account/Matconn/Geo).
    data(alloc_by_geo) = rev_alloc_by_fflas->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( 'FFLAS' ) ) )->sort( value #(
            ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'GEO_DRIVERS' ) ) ).
    data(non_fflas_balance) = rev_by_location->copy( )->sort( value #(
            ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'GEO_DRIVERS' ) ) ).
    loop at non_fflas_balance->model_data assigning field-symbol(<_non_fflas>).
      read table alloc_by_geo->model_data into data(_alloc_row)
          with key time = <_non_fflas>-time
                   account = <_non_fflas>-account
                   matconn = <_non_fflas>-matconn
                   geo_drivers = <_non_fflas>-geo_drivers
                   binary search.
      if sy-subrc is initial.
        <_non_fflas>-signeddata = <_non_fflas>-signeddata - _alloc_row-signeddata.
      endif.
      <_non_fflas>-fflas = fflas_non.
    endloop.
    delete non_fflas_balance->model_data where signeddata is initial.

    " Build the result: allocated FFLAS revenue + non-FFLAS balance.
    stage_result = rev_alloc_by_fflas.
    stage_result->append( non_fflas_balance ).
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
