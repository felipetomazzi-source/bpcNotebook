" Method: transpose_connections
" Calculate opening and closing connections
" Complete inputs come from the preceding method cells.
constants kf_prod_type_mapping type uj_dim_member value 'DEMREVID014' ##NO_TEXT.
constants kf_reg_fflas_serv_mapping type uj_dim_member value 'DEMREVID037' ##NO_TEXT.
constants kf_monthly_cal_conn type uj_dim_member value 'DEMREVID039' ##NO_TEXT.
constants kf_conn_opening type uj_dim_member value 'DEMREVID040' ##NO_TEXT.
constants kf_conn_closing type uj_dim_member value 'DEMREVID041' ##NO_TEXT.
constants kf_hidden_conn type uj_dim_member value 'DEMREVID043' ##NO_TEXT.
constants fflas_pq type uj_dim_member value 'FFLASPQ' ##NO_TEXT.
constants bandwidth type uj_dim_member value 'PRODUCT_TYPE_004' ##NO_TEXT.
constants mat_remapping type uj_dim_member value 'DEMREVID036' ##NO_TEXT.
constants kf_add_conn_mat_group type uj_dim_member value 'DEMREVID046' ##NO_TEXT.
constants kf_output_add_conn_mat_group type uj_dim_member value 'DEMREVID049' ##NO_TEXT.

DATA(env) = io.

DATA(category) = io->member( 'CATEGORY' ).

DATA(mat_group_id_dim) = NEW zcl_bn_dimension( io = io name = 'MAT_GROUP_ID' ).
DATA(matconn_dim) = NEW zcl_bn_dimension( io = io name = 'MATCONN' ).
DATA input_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_input_data) = io->read_dataset( dependency = 'step_01' name = 'INPUT_DATA' ).
FIELD-SYMBOLS <t_input_data> TYPE STANDARD TABLE.
ASSIGN ref_input_data->* TO <t_input_data>.
input_data = NEW #( environment = io model_data = <t_input_data> compressed = abap_false ).
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_19' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA conn_reg_split TYPE REF TO zcl_bn_dem_model.
DATA(ref_conn_reg_split) = io->read_dataset( dependency = 'step_01' name = 'CONN_REG_SPLIT' ).
FIELD-SYMBOLS <t_conn_reg_split> TYPE STANDARD TABLE.
ASSIGN ref_conn_reg_split->* TO <t_conn_reg_split>.
conn_reg_split = NEW #( environment = io model_data = <t_conn_reg_split> compressed = abap_false ).
DATA l1_l2_mapping TYPE REF TO zcl_bn_dem_model.
DATA(ref_l1_l2_mapping) = io->read_dataset( dependency = 'step_01' name = 'L1_L2_MAPPING' ).
FIELD-SYMBOLS <t_l1_l2_mapping> TYPE STANDARD TABLE.
ASSIGN ref_l1_l2_mapping->* TO <t_l1_l2_mapping>.
l1_l2_mapping = NEW #( environment = io model_data = <t_l1_l2_mapping> compressed = abap_false ).
DATA mat_group_mapping TYPE REF TO zcl_bn_dem_model.
DATA(ref_mat_group_mapping) = io->read_dataset( dependency = 'step_01' name = 'MAT_GROUP_MAPPING' ).
FIELD-SYMBOLS <t_mat_group_mapping> TYPE STANDARD TABLE.
ASSIGN ref_mat_group_mapping->* TO <t_mat_group_mapping>.
mat_group_mapping = NEW #( environment = io model_data = <t_mat_group_mapping> compressed = abap_false ).
DATA transposed_revenues TYPE REF TO zcl_bn_dem_model.
DATA(ref_transposed_revenues) = io->read_dataset( dependency = 'step_18' name = 'TRANSPOSED_REVENUES' ).
FIELD-SYMBOLS <t_transposed_revenues> TYPE STANDARD TABLE.
ASSIGN ref_transposed_revenues->* TO <t_transposed_revenues>.
transposed_revenues = NEW #( environment = io model_data = <t_transposed_revenues> compressed = abap_false ).
DATA complete_source_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_complete_source_data) = io->read_dataset( dependency = 'step_01' name = 'COMPLETE_SOURCE_DATA' ).
FIELD-SYMBOLS <t_complete_source_data> TYPE STANDARD TABLE.
ASSIGN ref_complete_source_data->* TO <t_complete_source_data>.
complete_source_data = NEW #( environment = io model_data = <t_complete_source_data> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
" CAL connections for current period.
    data(current_period_conn) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_monthly_cal_conn )
        " Bandwidth connections won't be considered.
        ( dimension = 'PRODUCT_TYPE'  sign = 'E' low = bandwidth  ) ) )->replace(
                dimension  = 'LFC_WIN_SUPPLIER'
                replace_with = 'LFC_WIN_SUPPLIER_NA'
                filters = value #( ( dimension = 'FFLAS' low = fflas_pq ) ) )->group( ).
    check current_period_conn->model_data is not initial.

    " Visible mapping precedence, expanded here rather than called in an engine.
data(mat_remapping_e1) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = mat_remapping ) ) )->sort( value #(
            ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ) )->model_data.

    data(reg_fflas_service_e1) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_reg_fflas_serv_mapping ) ) )->sort( value #(
            (       'TIME' ) (           'MATCONN' ) ( 'MAT_GROUP_ID' ) ) )->model_data.

    data(prod_type_overwrite_e1) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_prod_type_mapping ) ) )->sort( value #(
            (       'TIME' ) (           'MATCONN' ) ) )->model_data.

    data(prod_type_dim_e1) = NEW zcl_bn_dimension( io = env name = 'PRODUCT_TYPE' ).

    loop at current_period_conn->model_data assigning field-symbol(<_model_ref_e1>).

      read table prod_type_overwrite_e1 into data(_prod_type_overwrite_e1)
          with key time = <_model_ref_e1>-time
                       matconn = <_model_ref_e1>-matconn
                       binary search.
      if sy-subrc is initial.
        <_model_ref_e1>-product_type =
            cond #(
                when prod_type_dim_e1->get_member_by_index( _prod_type_overwrite_e1-signeddata ) is not initial then prod_type_dim_e1->get_member_by_index( _prod_type_overwrite_e1-signeddata )
                    else _prod_type_overwrite_e1-product_type ) .
      endif.

      <_model_ref_e1>-rev_id_group = prod_type_dim_e1->get_member( <_model_ref_e1>-product_type )-rev_id_group.

      read table conn_reg_split->model_data
          into data(_conn_reg_split_e1) with key
            time = <_model_ref_e1>-time
            account = <_model_ref_e1>-account
                binary search.
      if sy-subrc is initial.
        <_model_ref_e1>-conn_reg_split = _conn_reg_split_e1-conn_reg_split.
      endif.

      read table l1_l2_mapping->model_data
          into data(_l1_l2_mapping_e1) with key
            time = <_model_ref_e1>-time
            account = <_model_ref_e1>-account
                binary search.
      if sy-subrc is initial.
        <_model_ref_e1>-fflas_subset = _l1_l2_mapping_e1-fflas_subset.
      endif.

      read table mat_remapping_e1
          into data(_mat_remapping_e1) with key
            time = <_model_ref_e1>-time
            account = <_model_ref_e1>-account
            matconn = <_model_ref_e1>-matconn
                binary search.
      if sy-subrc is initial.
        <_model_ref_e1>-matremap = _mat_remapping_e1-matremap.
      else.
        read table mat_remapping_e1
           into _mat_remapping_e1 with key
             time = <_model_ref_e1>-time
             account = 'ACCOUNT_NA'
             matconn = <_model_ref_e1>-matconn
                 binary search.
        if sy-subrc is initial.
          <_model_ref_e1>-matremap = _mat_remapping_e1-matremap.
        else.
          <_model_ref_e1>-matremap = cond #(
              when <_model_ref_e1>-matconn eq 'MATCONN_NA' then 'MATREMAP_NA'
                  else <_model_ref_e1>-matconn ).
        endif.
      endif.

      if <_model_ref_e1>-product_type eq 'PRODUCT_TYPE_NA' and
            <_model_ref_e1>-matremap ne 'MATREMAP_NA'.
        <_model_ref_e1>-product_type = matconn_dim->get_member( <_model_ref_e1>-matremap )-product_type.
      endif.

      if <_model_ref_e1>-matremap ne 'MATREMAP_NA'.
        " Look for the Material Group  using the Remapped material.
        " If nothing is found, then look for the Mat. Group by Account.
        read table mat_group_mapping->model_data
          into data(_mat_group_mapping_e1)
              with key time = <_model_ref_e1>-time
                          matconn = <_model_ref_e1>-matremap
                          account = 'ACCOUNT_NA'
                          binary search.
        if sy-subrc is initial.
          <_model_ref_e1>-mat_group_id = _mat_group_mapping_e1-mat_group_id.
        endif.
      else.
        read table mat_group_mapping->model_data
              into _mat_group_mapping_e1
                  with key time = <_model_ref_e1>-time
                              matconn = 'MATCONN_NA'
                              account = <_model_ref_e1>-account
                              binary search.
        if sy-subrc is initial.
          <_model_ref_e1>-mat_group_id = _mat_group_mapping_e1-mat_group_id.
        endif.
      endif.

      " If the property REV_ID_GROUP of dimension
      " MAT_GROUP_ID is not blank, then use it instead of the overwrite from
      " the previous step.
      <_model_ref_e1>-rev_id_group = cond #(
        when mat_group_id_dim->get_member( <_model_ref_e1>-mat_group_id )-rev_id_group is initial
            then <_model_ref_e1>-rev_id_group
                else mat_group_id_dim->get_member( <_model_ref_e1>-mat_group_id )-rev_id_group ).

      " Search for the Reg. FFLAS Service level using the Material Group.
      read table reg_fflas_service_e1
          into data(_reg_fflas_service_e1) with key
            time = <_model_ref_e1>-time
            matconn = 'MATCONN_NA'
            mat_group_id = <_model_ref_e1>-mat_group_id
                binary search.
      if sy-subrc is initial.
        <_model_ref_e1>-reg_fflas_serv = _reg_fflas_service_e1-reg_fflas_serv.
      else.

        " If it can't be found by material, then user the Remapped Material.
        read table reg_fflas_service_e1
            into _reg_fflas_service_e1  with key
              time = <_model_ref_e1>-time
              matconn = <_model_ref_e1>-matremap
                  binary search.
        if sy-subrc is initial.
          <_model_ref_e1>-reg_fflas_serv = _reg_fflas_service_e1-reg_fflas_serv.
        endif.
      endif.
    endloop.

    current_period_conn->replace(
        dimension = 'MATREMAP'
        replace_with = 'MATREMAP_NA'
        filters = value #( ( dimension = 'MAT_GROUP_ID' sign = 'E' low  = 'MAT_GROUP_ID_NA' ) ) )->group( value #(
            (                          'TIME' ) (            'FFLAS' ) ( 'MATREMAP' ) ( 'MAT_GROUP_ID' ) ( 'LFC_WIN_SUPPLIER' ) ) ).

    " Get the prior period.
    data(offset_periods) = current_period_conn->copy( )->group( value #( ( 'TIME' ) ) )->offset_time( -1 )->model_data.
    sort offset_periods by time descending.
    data(prior_period) = offset_periods[ 1 ]-time.
    " CAL connections for prior period.
    data(prior_period_conn) = complete_source_data->copy( value #(
            ( dimension = 'DEMREVID_KFS' low = kf_monthly_cal_conn )
            ( dimension = 'TIME' low = prior_period )
            ( dimension = 'CATEGORY' low = category )
            ( dimension = 'PRODUCT_TYPE'  sign = 'E' low = bandwidth  )
                ) )->offset_time( offset_by = 1 )->replace(
                dimension  = 'LFC_WIN_SUPPLIER'
                replace_with = 'LFC_WIN_SUPPLIER_NA'
                filters = value #( ( dimension = 'FFLAS' low = fflas_pq ) ) )->group( ).

    " Visible mapping precedence, expanded here rather than called in an engine.
data(mat_remapping_e2) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = mat_remapping ) ) )->sort( value #(
            ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ) )->model_data.

    data(reg_fflas_service_e2) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_reg_fflas_serv_mapping ) ) )->sort( value #(
            (       'TIME' ) (           'MATCONN' ) ( 'MAT_GROUP_ID' ) ) )->model_data.

    data(prod_type_overwrite_e2) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_prod_type_mapping ) ) )->sort( value #(
            (       'TIME' ) (           'MATCONN' ) ) )->model_data.

    data(prod_type_dim_e2) = NEW zcl_bn_dimension( io = env name = 'PRODUCT_TYPE' ).

    loop at prior_period_conn->model_data assigning field-symbol(<_model_ref_e2>).

      read table prod_type_overwrite_e2 into data(_prod_type_overwrite_e2)
          with key time = <_model_ref_e2>-time
                       matconn = <_model_ref_e2>-matconn
                       binary search.
      if sy-subrc is initial.
        <_model_ref_e2>-product_type =
            cond #(
                when prod_type_dim_e2->get_member_by_index( _prod_type_overwrite_e2-signeddata ) is not initial then prod_type_dim_e2->get_member_by_index( _prod_type_overwrite_e2-signeddata )
                    else _prod_type_overwrite_e2-product_type ) .
      endif.

      <_model_ref_e2>-rev_id_group = prod_type_dim_e2->get_member( <_model_ref_e2>-product_type )-rev_id_group.

      read table conn_reg_split->model_data
          into data(_conn_reg_split_e2) with key
            time = <_model_ref_e2>-time
            account = <_model_ref_e2>-account
                binary search.
      if sy-subrc is initial.
        <_model_ref_e2>-conn_reg_split = _conn_reg_split_e2-conn_reg_split.
      endif.

      read table l1_l2_mapping->model_data
          into data(_l1_l2_mapping_e2) with key
            time = <_model_ref_e2>-time
            account = <_model_ref_e2>-account
                binary search.
      if sy-subrc is initial.
        <_model_ref_e2>-fflas_subset = _l1_l2_mapping_e2-fflas_subset.
      endif.

      read table mat_remapping_e2
          into data(_mat_remapping_e2) with key
            time = <_model_ref_e2>-time
            account = <_model_ref_e2>-account
            matconn = <_model_ref_e2>-matconn
                binary search.
      if sy-subrc is initial.
        <_model_ref_e2>-matremap = _mat_remapping_e2-matremap.
      else.
        read table mat_remapping_e2
           into _mat_remapping_e2 with key
             time = <_model_ref_e2>-time
             account = 'ACCOUNT_NA'
             matconn = <_model_ref_e2>-matconn
                 binary search.
        if sy-subrc is initial.
          <_model_ref_e2>-matremap = _mat_remapping_e2-matremap.
        else.
          <_model_ref_e2>-matremap = cond #(
              when <_model_ref_e2>-matconn eq 'MATCONN_NA' then 'MATREMAP_NA'
                  else <_model_ref_e2>-matconn ).
        endif.
      endif.

      if <_model_ref_e2>-product_type eq 'PRODUCT_TYPE_NA' and
            <_model_ref_e2>-matremap ne 'MATREMAP_NA'.
        <_model_ref_e2>-product_type = matconn_dim->get_member( <_model_ref_e2>-matremap )-product_type.
      endif.

      if <_model_ref_e2>-matremap ne 'MATREMAP_NA'.
        " Look for the Material Group  using the Remapped material.
        " If nothing is found, then look for the Mat. Group by Account.
        read table mat_group_mapping->model_data
          into data(_mat_group_mapping_e2)
              with key time = <_model_ref_e2>-time
                          matconn = <_model_ref_e2>-matremap
                          account = 'ACCOUNT_NA'
                          binary search.
        if sy-subrc is initial.
          <_model_ref_e2>-mat_group_id = _mat_group_mapping_e2-mat_group_id.
        endif.
      else.
        read table mat_group_mapping->model_data
              into _mat_group_mapping_e2
                  with key time = <_model_ref_e2>-time
                              matconn = 'MATCONN_NA'
                              account = <_model_ref_e2>-account
                              binary search.
        if sy-subrc is initial.
          <_model_ref_e2>-mat_group_id = _mat_group_mapping_e2-mat_group_id.
        endif.
      endif.

      " If the property REV_ID_GROUP of dimension
      " MAT_GROUP_ID is not blank, then use it instead of the overwrite from
      " the previous step.
      <_model_ref_e2>-rev_id_group = cond #(
        when mat_group_id_dim->get_member( <_model_ref_e2>-mat_group_id )-rev_id_group is initial
            then <_model_ref_e2>-rev_id_group
                else mat_group_id_dim->get_member( <_model_ref_e2>-mat_group_id )-rev_id_group ).

      " Search for the Reg. FFLAS Service level using the Material Group.
      read table reg_fflas_service_e2
          into data(_reg_fflas_service_e2) with key
            time = <_model_ref_e2>-time
            matconn = 'MATCONN_NA'
            mat_group_id = <_model_ref_e2>-mat_group_id
                binary search.
      if sy-subrc is initial.
        <_model_ref_e2>-reg_fflas_serv = _reg_fflas_service_e2-reg_fflas_serv.
      else.

        " If it can't be found by material, then user the Remapped Material.
        read table reg_fflas_service_e2
            into _reg_fflas_service_e2  with key
              time = <_model_ref_e2>-time
              matconn = <_model_ref_e2>-matremap
                  binary search.
        if sy-subrc is initial.
          <_model_ref_e2>-reg_fflas_serv = _reg_fflas_service_e2-reg_fflas_serv.
        endif.
      endif.
    endloop.
    prior_period_conn->replace(
        dimension = 'MATREMAP'
        replace_with = 'MATREMAP_NA'
        filters = value #( ( dimension = 'MAT_GROUP_ID' sign = 'E' low  = 'MAT_GROUP_ID_NA' ) ) )->group( value #(
            (                          'TIME' ) (            'FFLAS' ) ( 'MATREMAP' ) ( 'MAT_GROUP_ID' ) ( 'LFC_WIN_SUPPLIER' ) ) ).
    prior_period_conn->append( current_period_conn->copy( )->offset_time( 1 ) ).

    " Which Material Groups need to hide its Connections in the
    " final output.
    data(hidden_conn_mat_group) = input_data->copy( value #(
            ( dimension   = 'DEMREVID_KFS' low = kf_hidden_conn )
    ) )->sort( value #( ( 'TIME' ) (           'MAT_GROUP_ID' ) ) ).

    " Remove the product type to avoid duplicates.
    transposed_revenues->group( include_dimensions = abap_false
                                group_by           = value #( ( 'PRODUCT_TYPE' ) ) )->replace(
                                dimension = 'MATREMAP'
                                replace_with = 'MATREMAP_NA'
                                filters = value #( ( dimension  = 'MAT_GROUP_ID' sign = 'E' low = 'MAT_GROUP_ID_NA' ) ) )->group( ).

    data(transposed_conn) = new zcl_bn_dem_model( environment = env ).
    loop at transposed_revenues->model_data into data(_transposed_conn).

      if hidden_conn_mat_group->read( value #(
          ( dimension = 'TIME'         low = _transposed_conn-time )
          ( dimension = 'MAT_GROUP_ID' low = _transposed_conn-mat_group_id )
      ) )-signeddata eq 1.
        continue.
      endif.

      " Read current number of connections.
      read table current_period_conn->model_data
          into data(_current_period_conn)
              with key time = _transposed_conn-time
                          fflas = _transposed_conn-fflas
                          matremap = _transposed_conn-matremap
                          mat_group_id = _transposed_conn-mat_group_id
                          lfc_win_supplier = _transposed_conn-lfc_win_supplier.
      if sy-subrc is initial.
        _transposed_conn-signeddata = _current_period_conn-signeddata.
        _transposed_conn-demrevid_kfs = kf_conn_closing.
        transposed_conn->append( _transposed_conn ).
      endif.

      " Read the prior number of connections.
      read table prior_period_conn->model_data
          assigning field-symbol(<_prior_period_conn>)
              with key time = _transposed_conn-time
                          fflas = _transposed_conn-fflas
                          matremap = _transposed_conn-matremap
                          mat_group_id = _transposed_conn-mat_group_id
                          lfc_win_supplier = _transposed_conn-lfc_win_supplier.
      if sy-subrc is initial.
        _transposed_conn-signeddata = <_prior_period_conn>-signeddata.
        _transposed_conn-demrevid_kfs = kf_conn_opening.
        transposed_conn->append( _transposed_conn ).
        clear <_prior_period_conn>-signeddata.
      endif.
    endloop.

    " If the current period has no revenues, no records would normally be created for the final report.
    " To prevent this, we iterate over [prior_period_conn], which holds the closing balances of materials without revenue.
    " The previous period’s closing balance is copied into the current period’s opening balance, while the closing balance
    " for the current period is retrieved as usual.
    delete prior_period_conn->model_data where signeddata is initial.
    sort prior_period_conn->model_data by time fflas matremap mat_group_id lfc_win_supplier.
    " Get prior closing balance.
    data(prior_closing_bal) = complete_source_data->copy( value #(
            ( dimension = 'DEMREVID_KFS' low = kf_conn_closing )
            ( dimension = 'TIME'         low = prior_period )
            ( dimension = 'CATEGORY'     low = category ) ) )->offset_time( offset_by = 1 )->replace(
                dimension = 'DEMREVID_KFS' replace_with = kf_conn_opening ).
    loop at prior_closing_bal->model_data into data(_prior_closing_bal).

      " If the number of connections from the previous period is not found in
      " the internal table, it indicates that its closing balance has already
      " been successfully carried over to the opening balance of the current period.
      " Therefore, we no longer need to track that connection."
      read table prior_period_conn->model_data
        transporting no fields
            with key time = _prior_closing_bal-time
                        fflas = _prior_closing_bal-fflas
                        matremap = _prior_closing_bal-matremap
                        mat_group_id = _prior_closing_bal-mat_group_id
                        lfc_win_supplier = _prior_closing_bal-lfc_win_supplier
                        binary search.
      if sy-subrc is not initial.
        continue.
      endif.
      transposed_conn->append( _prior_closing_bal ).

      " Read current number of connections.
      read table current_period_conn->model_data
          into _current_period_conn
              with key time = _prior_closing_bal-time
                          fflas = _prior_closing_bal-fflas
                          matremap = _prior_closing_bal-matremap
                          mat_group_id = _prior_closing_bal-mat_group_id
                          lfc_win_supplier = _prior_closing_bal-lfc_win_supplier.
      if sy-subrc is initial.
        _prior_closing_bal-signeddata = _current_period_conn-signeddata.
        _prior_closing_bal-demrevid_kfs = kf_conn_closing.
        transposed_conn->append( _prior_closing_bal ).
      endif.
    endloop.

    data(add_conn_current_per) = input_data->copy( value #(
        ( dimension       = 'DEMREVID_KFS' low = kf_add_conn_mat_group )
    ) )->sort( value #( ( 'TIME' ) ( 'FFLAS' ) ( 'MAT_GROUP_ID' ) ) ).

    data(add_conn_prior_per) = complete_source_data->copy( value #(
            ( dimension                                 = 'DEMREVID_KFS' low = kf_add_conn_mat_group )
            ( dimension                                 = 'TIME'         low = prior_period )
            ( dimension                                 = 'CATEGORY'     low = category )
    ) )->offset_time( offset_by = 1 )->sort( value #( ( 'TIME' ) (           'FFLAS' ) ( 'MAT_GROUP_ID' ) ) ).

    data add_conn_final_output like transposed_conn->model_data.
    loop at transposed_conn->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( 'PRODUCT_TYPE' ) ) )->model_data into data(_current_conn).

      case _current_conn-demrevid_kfs.
        when kf_conn_closing.
          _current_conn-signeddata = add_conn_current_per->read( value #(
            ( dimension = 'TIME'         low = _current_conn-time )
            ( dimension = 'FFLAS'        low = _current_conn-fflas )
            ( dimension = 'MAT_GROUP_ID' low = _current_conn-mat_group_id )
          ) )-signeddata.
          if  _current_conn-signeddata is not initial.
            append _current_conn to add_conn_final_output.

            data(_add_conn_final_output) = _current_conn.
            _add_conn_final_output-demrevid_kfs = kf_output_add_conn_mat_group.
            append _add_conn_final_output to add_conn_final_output.
          endif.
        when kf_conn_opening.
          _current_conn-signeddata = add_conn_prior_per->read( value #(
            ( dimension = 'TIME'         low = _current_conn-time )
            ( dimension = 'FFLAS'        low = _current_conn-fflas )
            ( dimension = 'MAT_GROUP_ID' low = _current_conn-mat_group_id )
          ) )-signeddata.
          if  _current_conn-signeddata is not initial.
            append _current_conn to add_conn_final_output.
          endif.
      endcase.
    endloop.
    transposed_conn->collect( add_conn_final_output ).

    new_data->append( transposed_conn ).
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
