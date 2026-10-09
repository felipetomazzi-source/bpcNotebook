" Method: calc_hsns_rev_alloc
" Reallocate HSNS premium revenue
" Complete inputs come from the preceding method cells.
constants kf_prod_type_mapping type uj_dim_member value 'DEMREVID014' ##NO_TEXT.
constants kf_fflas_revenue type uj_dim_member value 'DEMREVID023' ##NO_TEXT.
constants kf_reg_fflas_serv_mapping type uj_dim_member value 'DEMREVID037' ##NO_TEXT.
constants kf_hsns_premium_upload type uj_dim_member value 'DEMREVID045' ##NO_TEXT.
constants fflas_id type uj_dim_member value 'FFLASID' ##NO_TEXT.
constants access_rental type uj_dim_member value 'PRODUCT_TYPE_001' ##NO_TEXT.
constants bandwidth type uj_dim_member value 'PRODUCT_TYPE_004' ##NO_TEXT.
constants rsp_billing type uj_dim_member value 'DEMREVID006' ##NO_TEXT.
constants accrual type uj_dim_member value 'DEMREVID007' ##NO_TEXT.
constants mat_remapping type uj_dim_member value 'DEMREVID036' ##NO_TEXT.

DATA(env) = io.

DATA(parameters) = io->script_parameters( ).
READ TABLE parameters ASSIGNING FIELD-SYMBOL(<flag>) WITH KEY hashkey = 'FFLASMATGROUPS'.
IF sy-subrc = 0.
CASE <flag>-hashvalue. WHEN 'true'. <flag>-hashvalue = '1'. WHEN 'false'. <flag>-hashvalue = '0'. ENDCASE.
ENDIF.
DATA(param) = NEW zcl_bpc_param( parameters ).

DATA(mat_group_id_dim) = NEW zcl_bn_dimension( io = io name = 'MAT_GROUP_ID' ).
DATA(matconn_dim) = NEW zcl_bn_dimension( io = io name = 'MATCONN' ).
DATA input_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_input_data) = io->read_dataset( dependency = 'step_01' name = 'INPUT_DATA' ).
FIELD-SYMBOLS <t_input_data> TYPE STANDARD TABLE.
ASSIGN ref_input_data->* TO <t_input_data>.
input_data = NEW #( environment = io model_data = <t_input_data> compressed = abap_false ).
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_15' name = 'NEW_DATA' ).
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
DATA sap_revenues TYPE REF TO zcl_bn_dem_model.
DATA(ref_sap_revenues) = io->read_dataset( dependency = 'step_02' name = 'SAP_REVENUES' ).
FIELD-SYMBOLS <t_sap_revenues> TYPE STANDARD TABLE.
ASSIGN ref_sap_revenues->* TO <t_sap_revenues>.
sap_revenues = NEW #( environment = io model_data = <t_sap_revenues> compressed = abap_false ).
DATA mat_group_mapping TYPE REF TO zcl_bn_dem_model.
DATA(ref_mat_group_mapping) = io->read_dataset( dependency = 'step_01' name = 'MAT_GROUP_MAPPING' ).
FIELD-SYMBOLS <t_mat_group_mapping> TYPE STANDARD TABLE.
ASSIGN ref_mat_group_mapping->* TO <t_mat_group_mapping>.
mat_group_mapping = NEW #( environment = io model_data = <t_mat_group_mapping> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
" Credit the Allocated Revenues for HSNS Premium.
    data(hsns_prem_fflas_credit) = new_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_fflas_revenue )
        ( dimension = 'ACCOUNT' low = '001054200'  )
        ( dimension = 'PRODUCT_TYPE' low =  access_rental  )
        ( dimension = 'PRODUCT_TYPE' low = bandwidth  )
             ) )->replace( dimension = 'AUDITTRAIL' replace_with = 'DEMREVID_CALC_HSNS_CREDIT' )->multiply( multiplier = -1 ).
    new_data->append( hsns_prem_fflas_credit ).

    " The "new" RSP Billed for HSNS Premium Revenues data comes from flat-files (CDW data)
    data(hsns_premium_rsp_bill) =
         input_data->copy( value #(
            ( dimension = 'DEMREVID_KFS' low = kf_hsns_premium_upload  ) ) )->replaces( value #(
                ( dimension = 'AUDITTRAIL' replace_with = 'DEMREVID_CALC_HSNS' )
                ( dimension = 'DEMREVID_KFS' replace_with = rsp_billing )  ) )->group(
                    include_dimensions = abap_false
                    group_by = value #( ( 'UFB_DR_ID' ) ) ).
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

    loop at hsns_premium_rsp_bill->model_data assigning field-symbol(<_model_ref_e1>).

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
    sort hsns_premium_rsp_bill->model_data by time rsp_service_id product_type fflas.

    " Reassign the Material Group for Bandwidth Products by looking at the material
    " group for the Access/Rental product in the same service ID.
    loop at hsns_premium_rsp_bill->model_data assigning field-symbol(<bandwidth_revenue>)
        where product_type eq bandwidth.
      read table hsns_premium_rsp_bill->model_data
          into data(_access_revenue)
              with key  time = <bandwidth_revenue>-time
                        rsp_service_id = <bandwidth_revenue>-rsp_service_id
                        product_type = access_rental
                        fflas = <bandwidth_revenue>-fflas.
      if sy-subrc is initial.
        <bandwidth_revenue>-mat_group_id = _access_revenue-mat_group_id.
        <bandwidth_revenue>-rsp_service_id = 'RSP_SERVICE_ID_NA'.
      endif.
    endloop.
    new_data->append( hsns_premium_rsp_bill->group( ) ).

    data(hsns_fflas_allocation) =  hsns_premium_rsp_bill->copy( )->replaces( value #(
        ( dimension = 'DEMREVID_KFS'    replace_with = kf_fflas_revenue )  ) )->group( ).

    " Only consider the following Locations (LFC_WIN_SUPPLIER) when calculating the
    " HSNS Revenue Reallocation for ID-Only: Enable Services, North Power, UltraFast Fibre
    " This can be configured in Logic Script ALLOC_REVENUES.LGF.
    data(locations_for_hsns_realloc) = param->get_dimmem_range( sign = 'E' parameter = 'HSNS_REALLOC_LOCATIONS' ).
    hsns_premium_rsp_bill->delete( value #(
        ( dimension = 'FFLAS'            low = fflas_id )
        ( dimension = 'LFC_WIN_SUPPLIER' in  = locations_for_hsns_realloc ) ) ).

    " Find the allocation ratio using the RSP Billing Revenue as reference.
    " Two ratios with different granularities are derived from the same filtered
    " RSP Billing data:
    "   * material_fflas_ratio  - by Time + Material (MATCONN), the finer split.
    "   * mat_group_fflas_ratio - by Time + Material Group, the coarser fallback.
    " When allocating an Accrual we prefer the material-level ratio (which reflects
    " that specific material's own PQ/ID-Only/Location split from RSP Billing) and
    " only fall back to the material-group ratio when the material has no RSP Billing
    " of its own. This prevents an Accrual that is 100% ID-Only at material level
    " (e.g. material 112529, whose RSP Billing is fully LFC) from leaking into
    " PQ-FFLAS just because other materials in the same group carry a PQ share.
    data(material_fflas_ratio) =
        hsns_premium_rsp_bill->copy( )->group( value #(
            ( 'TIME' ) ( 'MATCONN' ) ( 'FFLAS' ) ( 'LFC_WIN_SUPPLIER' ) ) )->get_ratio( value #( ( 'TIME' ) ( 'MATCONN' ) ) )->model_data.

    data(mat_group_fflas_ratio) =
        hsns_premium_rsp_bill->copy( )->group( value #(
            ( 'TIME' ) ( 'MAT_GROUP_ID' ) ( 'FFLAS' ) ( 'LFC_WIN_SUPPLIER' ) ) )->get_ratio( value #( ( 'TIME' ) ( 'MAT_GROUP_ID' ) ) )->model_data.

    " Gets the HSNS Revenue that comes from SAP (Both Billed and Not Billed (Accrual).
    data(hsns_premium_accrual) = sap_revenues->copy( value #(
            ( dimension = 'ACCOUNT' low = '001054200'  )
            ( dimension = 'PRODUCT_TYPE' low =  access_rental  )
            ( dimension = 'PRODUCT_TYPE' low = bandwidth  )
            ( dimension = 'DEMREVID_KFS' low = accrual  )
                 ) )->replace( dimension = 'AUDITTRAIL' replace_with = 'DEMREVID_CALC_HSNS' ).

    " Allocate Accruals (from SAP) between PQ/ID and Location.
    data(new_accrual_allocation) = new zcl_bn_dem_model( environment = env ).
    loop at hsns_premium_accrual->model_data into data(_hsns_premium_accrual).
      data(_new_accrual_revenue) = _hsns_premium_accrual.

      " Prefer the material-level (MATCONN) ratio; only if this material has no
      " RSP Billing of its own do we fall back to the material-group ratio.
      read table material_fflas_ratio transporting no fields
          with key time = _hsns_premium_accrual-time
                   matconn = _hsns_premium_accrual-matconn.
      if sy-subrc is initial.
        loop at material_fflas_ratio into data(_material_fflas_ratio)
          where time eq _hsns_premium_accrual-time and
                    matconn = _hsns_premium_accrual-matconn.
          _new_accrual_revenue-lfc_win_supplier = _material_fflas_ratio-lfc_win_supplier.
          _new_accrual_revenue-fflas = _material_fflas_ratio-fflas.
          _new_accrual_revenue-signeddata = _hsns_premium_accrual-signeddata * _material_fflas_ratio-signeddata.
          new_accrual_allocation->append( _new_accrual_revenue ).
        endloop.
      else.
        loop at mat_group_fflas_ratio into data(_mat_group_fflas_ratio)
          where time eq _hsns_premium_accrual-time and
                    mat_group_id = _hsns_premium_accrual-mat_group_id.
          _new_accrual_revenue-lfc_win_supplier = _mat_group_fflas_ratio-lfc_win_supplier.
          _new_accrual_revenue-fflas = _mat_group_fflas_ratio-fflas.
          _new_accrual_revenue-signeddata = _hsns_premium_accrual-signeddata * _mat_group_fflas_ratio-signeddata.
          new_accrual_allocation->append( _new_accrual_revenue ).
        endloop.
      endif.
    endloop.
    new_data->append( new_accrual_allocation ).

    hsns_fflas_allocation->append( new_accrual_allocation )->replace( dimension = 'DEMREVID_KFS' replace_with = kf_fflas_revenue )->group( ).
    new_data->append( hsns_fflas_allocation ).
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
