" Method: calc_price_material_level
" Attach SAP prices to materials
" Complete inputs come from the preceding method cells.
constants sap_price type uj_dim_member value 'DEMREVID002' ##NO_TEXT.
DATA input_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_input_data) = io->read_dataset( dependency = 'step_01' name = 'INPUT_DATA' ).
FIELD-SYMBOLS <t_input_data> TYPE STANDARD TABLE.
ASSIGN ref_input_data->* TO <t_input_data>.
input_data = NEW #( environment = io model_data = <t_input_data> compressed = abap_false ).
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_14' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA sap_revenues_consol TYPE REF TO zcl_bn_dem_model.
DATA(ref_sap_revenues_consol) = io->read_dataset( dependency = 'step_03' name = 'SAP_REVENUES_CONSOL' ).
FIELD-SYMBOLS <t_sap_revenues_consol> TYPE STANDARD TABLE.
ASSIGN ref_sap_revenues_consol->* TO <t_sap_revenues_consol>.
sap_revenues_consol = NEW #( environment = io model_data = <t_sap_revenues_consol> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
data(mat_price) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = sap_price ) ) )->sort( value #(
            ( 'TIME' ) ( 'MATCONN' ) ) )->model_data.
    loop at sap_revenues_consol->model_data into data(_revenues).
      read table mat_price into data(_mat_price)
          with key time = _revenues-time
                         matconn = _revenues-matconn
                         binary search.
      if sy-subrc is initial.
        _revenues-demrevid_kfs = _mat_price-demrevid_kfs.
        _revenues-signeddata = _mat_price-signeddata.
        new_data->append( _revenues ).
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
