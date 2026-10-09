" Method: group
" Combine billed and unbilled revenue
" Complete inputs come from the preceding method cells.

DATA sap_revenues TYPE REF TO zcl_bn_dem_model.
DATA(ref_sap_revenues) = io->read_dataset( dependency = 'step_02' name = 'SAP_REVENUES' ).
FIELD-SYMBOLS <t_sap_revenues> TYPE STANDARD TABLE.
ASSIGN ref_sap_revenues->* TO <t_sap_revenues>.
sap_revenues = NEW #( environment = io model_data = <t_sap_revenues> compressed = abap_false ).
DATA sap_revenues_consol TYPE REF TO zcl_bn_dem_model.

io->check_budget( ).
DO 1 TIMES.
sap_revenues_consol = sap_revenues->copy( )->group( include_dimensions = abap_false group_by = VALUE #( ( 'DEMREVID_KFS' ) ) ).
ENDDO.
IF sap_revenues_consol IS BOUND.
io->check_rows( lines( sap_revenues_consol->model_data ) ).
io->publish_dataset( name = 'SAP_REVENUES_CONSOL' rows = sap_revenues_consol->model_data ).
ENDIF.
IF sap_revenues_consol IS BOUND.
" Complete control totals: retain key figures/audit trails so unlike measures are not mixed.
DATA(control_totals) = sap_revenues_consol->copy( )->group( VALUE #(
 ( 'CATEGORY' ) ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'AUDITTRAIL' ) ( 'DEMREVID_KFS' ) ) ).
io->emit_table( name = 'CONTROL_TOTALS' rows = control_totals->model_data ).
ENDIF.
io->check_budget( ).
