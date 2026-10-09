" Method: calc_rsp_not_billed_location
" Allocate unbilled revenue by geography
" Complete inputs come from the preceding method cells.
constants kf_rsp_not_billed type uj_dim_member value 'DEMREVID007' ##NO_TEXT.
constants kf_rsp_not_billed_loc type uj_dim_member value 'DEMREVID018' ##NO_TEXT.
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_07' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA sap_revenues TYPE REF TO zcl_bn_dem_model.
DATA(ref_sap_revenues) = io->read_dataset( dependency = 'step_02' name = 'SAP_REVENUES' ).
FIELD-SYMBOLS <t_sap_revenues> TYPE STANDARD TABLE.
ASSIGN ref_sap_revenues->* TO <t_sap_revenues>.
sap_revenues = NEW #( environment = io model_data = <t_sap_revenues> compressed = abap_false ).
DATA rsp_split_ratios TYPE REF TO zcl_bn_dem_model.
DATA(ref_rsp_split_ratios) = io->read_dataset( dependency = 'step_05' name = 'RSP_SPLIT_RATIOS' ).
FIELD-SYMBOLS <t_rsp_split_ratios> TYPE STANDARD TABLE.
ASSIGN ref_rsp_split_ratios->* TO <t_rsp_split_ratios>.
rsp_split_ratios = NEW #( environment = io model_data = <t_rsp_split_ratios> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
loop at sap_revenues->model_data into data(_not_billed_rsp)
            where demrevid_kfs eq kf_rsp_not_billed.
      if _not_billed_rsp-signeddata is not initial.
        loop at rsp_split_ratios->model_data into data(_rsp_split_ratios)
            where matconn eq _not_billed_rsp-matconn and
                        account eq _not_billed_rsp-account and
                        time eq _not_billed_rsp-time.
          data(_new_data) = _not_billed_rsp.
          _new_data-demrevid_kfs = kf_rsp_not_billed_loc.
          _new_data-geo_drivers = _rsp_split_ratios-geo_drivers.
          multiply _new_data-signeddata by _rsp_split_ratios-signeddata.
          new_data->append( _new_data ).
        endloop.
      endif.
    endloop.
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
