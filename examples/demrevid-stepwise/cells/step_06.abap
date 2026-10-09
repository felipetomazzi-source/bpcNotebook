" Method: calc_alloc_rsp_billed_data
" Recognize billing already split by geography
" Complete inputs come from the preceding method cells.
constants kf_prod_type_mapping type uj_dim_member value 'DEMREVID014' ##NO_TEXT.
constants kf_rsp_bill_with_loc type uj_dim_member value 'DEMREVID016' ##NO_TEXT.
constants kf_rsp_bill_prod_type type uj_dim_member value 'DEMREVID019' ##NO_TEXT.
constants kf_reg_fflas_serv_mapping type uj_dim_member value 'DEMREVID037' ##NO_TEXT.
constants mat_remapping type uj_dim_member value 'DEMREVID036' ##NO_TEXT.
constants audit_dnrid_calc type uj_dim_member value 'DEMREVID_CALC' ##NO_TEXT.

DATA(env) = io.

DATA(mat_group_id_dim) = NEW zcl_bn_dimension( io = io name = 'MAT_GROUP_ID' ).
DATA(matconn_dim) = NEW zcl_bn_dimension( io = io name = 'MATCONN' ).
DATA input_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_input_data) = io->read_dataset( dependency = 'step_01' name = 'INPUT_DATA' ).
FIELD-SYMBOLS <t_input_data> TYPE STANDARD TABLE.
ASSIGN ref_input_data->* TO <t_input_data>.
input_data = NEW #( environment = io model_data = <t_input_data> compressed = abap_false ).
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_05' name = 'NEW_DATA' ).
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

io->check_budget( ).
DO 1 TIMES.
data(rsp_billing_with_split)  =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS'  low = kf_rsp_bill_prod_type )
                ( dimension = 'DOC_TYP'  low = 'RS' )
                ( dimension = 'DOC_TYP'  low = 'AD' )
                ( dimension = 'DOC_TYP'  low = 'AC' )
                " Excludes TBD and N/A UFB Reporting categories
                " to prevent unexpected results.
                ( dimension = 'UFB_DR_ID' sign = 'E' low = 'UFBDRID006' ) " TBD
                ( dimension = 'UFB_DR_ID' sign = 'E' low = 'UFB_DR_ID_NA' )
                    ) )->group(
                        include_dimensions = abap_false
                        group_by = value #(
                            ( 'DOC_TYP' ) ( 'UFB_DR_ID' ) ( 'LFC_WIN_SUPPLIER' )  ) )->replaces( value #(
                                ( dimension = 'DEMREVID_KFS' replace_with = kf_rsp_bill_with_loc )
                                ( dimension = 'AUDITTRAIL' replace_with = audit_dnrid_calc )
                                     ) ).

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

    loop at rsp_billing_with_split->model_data assigning field-symbol(<_model_ref_e1>).

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
    new_data->append( rsp_billing_with_split ).
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
