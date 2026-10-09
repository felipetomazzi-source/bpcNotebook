" Method: transpose_prices
" Prepare the price reporting layout
" Complete inputs come from the preceding method cells.
constants conn_price_kf type uj_dim_member value 'DEMREVID044' ##NO_TEXT.
constants access_price_kf type uj_dim_member value 'DEMREVID042' ##NO_TEXT.
constants sap_price type uj_dim_member value 'DEMREVID002' ##NO_TEXT.
constants mat_remapping type uj_dim_member value 'DEMREVID036' ##NO_TEXT.

DATA(env) = io.

DATA(product_type_dim) = NEW zcl_bn_dimension( io = io name = 'PRODUCT_TYPE' ).
DATA input_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_input_data) = io->read_dataset( dependency = 'step_01' name = 'INPUT_DATA' ).
FIELD-SYMBOLS <t_input_data> TYPE STANDARD TABLE.
ASSIGN ref_input_data->* TO <t_input_data>.
input_data = NEW #( environment = io model_data = <t_input_data> compressed = abap_false ).
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_18' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA transposed_revenues TYPE REF TO zcl_bn_dem_model.
DATA(ref_transposed_revenues) = io->read_dataset( dependency = 'step_18' name = 'TRANSPOSED_REVENUES' ).
FIELD-SYMBOLS <t_transposed_revenues> TYPE STANDARD TABLE.
ASSIGN ref_transposed_revenues->* TO <t_transposed_revenues>.
transposed_revenues = NEW #( environment = io model_data = <t_transposed_revenues> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
data(prices) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = sap_price ) ) )->sort( value #(
            ( 'TIME' ) ( 'MATCONN' ) ) ).

    data(one_off_mapping) = input_data->copy( value #(
    ( dimension = 'DEMREVID_KFS' low = mat_remapping ) ) )->sort( value #(
        ( 'TIME' )  ( 'MATREMAP' ) ) ).

    data(conn_prices) = new zcl_bn_dem_model( environment = env ).
    data(access_products) = product_type_dim->get_children_range( 'PRODUCT_TYPE_ACCESS' ).
    loop at transposed_revenues->model_data into data(_access_revenues)
        where product_type in access_products.
      data(one_off_product) = one_off_mapping->read( value #(
          ( dimension = 'TIME'     low = _access_revenues-time )
          ( dimension = 'MATREMAP' low = _access_revenues-matremap )
      ) )-matconn.
      if one_off_product is not initial.
        data(conn_price) = prices->read( value #(
          ( dimension = 'TIME'    low = _access_revenues-time )
          ( dimension = 'MATCONN' low = one_off_product )
        ) )-signeddata.

        _access_revenues-demrevid_kfs = conn_price_kf.
        _access_revenues-signeddata = conn_price.
        conn_prices->append( _access_revenues ).
        conn_prices->append( _access_revenues ).
      endif.

      data(access_price) = prices->read( value #(
        ( dimension = 'TIME'    low = _access_revenues-time )
        ( dimension = 'MATCONN' low = _access_revenues-matremap )
      ) )-signeddata.

      _access_revenues-demrevid_kfs = access_price_kf.
      _access_revenues-signeddata = access_price.
      conn_prices->append( _access_revenues ).

    endloop.

    conn_prices->replaces( value #(
                (
                dimension    = 'MATREMAP'
                replace_with = 'MATREMAP_NA'
                filters      = value #( ( dimension = 'MAT_GROUP_ID' sign = 'E' low = 'MAT_GROUP_ID_NA' ) ) )
    ) ).
    sort conn_prices->model_data by time fflas demrevid_kfs matremap mat_group_id signeddata descending.
    delete adjacent duplicates from conn_prices->model_data comparing time fflas demrevid_kfs matremap mat_group_id.

    new_data->append( conn_prices ).
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
