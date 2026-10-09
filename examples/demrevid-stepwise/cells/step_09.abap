" Method: calc_fflas_grouping
" Choose FFLAS mapping and monthly percentages
" Complete inputs come from the preceding method cells.
constants kf_fflas_grouping type uj_dim_member value 'DEMREVID021' ##NO_TEXT.
constants kf_fflas_monthly_pct type uj_dim_member value 'DEMREVID022' ##NO_TEXT.

DATA(env) = io.
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
ENDIF.
IF fflas_month_ratio IS BOUND.
io->check_rows( lines( fflas_month_ratio->model_data ) ).
io->publish_dataset( name = 'FFLAS_MONTH_RATIO' rows = fflas_month_ratio->model_data ).
ENDIF.
IF new_data IS BOUND.
" Complete control totals: retain key figures/audit trails so unlike measures are not mixed.
DATA(control_totals) = new_data->copy( )->group( VALUE #(
 ( 'CATEGORY' ) ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'AUDITTRAIL' ) ( 'DEMREVID_KFS' ) ) ).
io->emit_table( name = 'CONTROL_TOTALS' rows = control_totals->model_data ).
ENDIF.
io->check_budget( ).
