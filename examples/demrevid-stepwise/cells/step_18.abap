" Method: transpose_revenues
" Prepare the revenue reporting layout
" Complete inputs come from the preceding method cells.
constants kf_fflas_revenue type uj_dim_member value 'DEMREVID023' ##NO_TEXT.
constants kf_hidden_mat_group type uj_dim_member value 'DEMREVID034' ##NO_TEXT.
constants kf_alloc_rev_summary type uj_dim_member value 'DEMREVID038' ##NO_TEXT.
constants fflas_pq type uj_dim_member value 'FFLASPQ' ##NO_TEXT.
constants audit_dnrid_calc type uj_dim_member value 'DEMREVID_CALC' ##NO_TEXT.
DATA input_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_input_data) = io->read_dataset( dependency = 'step_01' name = 'INPUT_DATA' ).
FIELD-SYMBOLS <t_input_data> TYPE STANDARD TABLE.
ASSIGN ref_input_data->* TO <t_input_data>.
input_data = NEW #( environment = io model_data = <t_input_data> compressed = abap_false ).
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_17' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA transposed_revenues TYPE REF TO zcl_bn_dem_model.

io->check_budget( ).
DO 1 TIMES.
" Transpose PQ and ID-Only FFLAS Revenues to facilitate report.
    transposed_revenues = new_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_fflas_revenue ) " Allocated Revenues
            ) )->group(
                include_dimensions = abap_false
                group_by = value #( ( 'ACCOUNT' ) ( 'AUDITTRAIL' ) ( 'GEO_DRIVERS' ) ( 'CONN_REG_SPLIT' ) ( 'RSP_SERVICE_ID' ) ( 'REV_ID_GROUP' ) ( 'MATCONN' ) ) )->replaces( value #(
                        ( dimension = 'DEMREVID_KFS' replace_with = kf_alloc_rev_summary )
                        ( dimension = 'AUDITTRAIL' replace_with = audit_dnrid_calc )
                        ( dimension  = 'LFC_WIN_SUPPLIER' replace_with = 'LFC_WIN_SUPPLIER_NA' filters = value #( ( dimension = 'FFLAS' low = fflas_pq ) ) )
                             ) )->group( ).

    data(transp_rev_aux) = transposed_revenues->copy(  ).
    transp_rev_aux->replace(
        dimension = 'MATREMAP'
        replace_with = 'MATREMAP_NA'
        filters = value #( ( dimension = 'MAT_GROUP_ID' sign = 'E' low = 'MAT_GROUP_ID_NA' ) ) )->group( ).

    data(hidden_mat_group) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_hidden_mat_group )
             ) )->get_dimmem_range( 'MAT_GROUP_ID' ).

    transp_rev_aux->delete( value #( ( dimension = 'MAT_GROUP_ID' in = hidden_mat_group ) ) ).

    new_data->append( transp_rev_aux ).
ENDDO.
IF new_data IS BOUND.
io->check_rows( lines( new_data->model_data ) ).
io->publish_dataset( name = 'NEW_DATA' rows = new_data->model_data ).
ENDIF.
IF transposed_revenues IS BOUND.
io->check_rows( lines( transposed_revenues->model_data ) ).
io->publish_dataset( name = 'TRANSPOSED_REVENUES' rows = transposed_revenues->model_data ).
ENDIF.
IF new_data IS BOUND.
" Complete control totals: retain key figures/audit trails so unlike measures are not mixed.
DATA(control_totals) = new_data->copy( )->group( VALUE #(
 ( 'CATEGORY' ) ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'AUDITTRAIL' ) ( 'DEMREVID_KFS' ) ) ).
io->emit_table( name = 'CONTROL_TOTALS' rows = control_totals->model_data ).
ENDIF.
io->check_budget( ).
