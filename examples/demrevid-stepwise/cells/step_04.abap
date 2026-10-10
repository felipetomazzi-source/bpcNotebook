" Method: calc_location_alloc_method
" Choose the geography driver
" Complete inputs come from the preceding method cells.
constants kf_loc_split_index type uj_dim_member value 'DEMREVID009' ##NO_TEXT.
TYPES rev_split_method TYPE i.
CONSTANTS rsp_billing_material TYPE i VALUE 1.
CONSTANTS rsp_billing_gl TYPE i VALUE 2.
CONSTANTS cal_gl TYPE i VALUE 3.
CONSTANTS cal_reg_split TYPE i VALUE 4.
CONSTANTS not_found TYPE i VALUE 5.
CONSTANTS location TYPE i VALUE 0.
CONSTANTS supplier TYPE i VALUE 1.
DATA new_data TYPE REF TO zcl_bn_dem_model.
DATA(ref_new_data) = io->read_dataset( dependency = 'step_02' name = 'NEW_DATA' ).
FIELD-SYMBOLS <t_new_data> TYPE STANDARD TABLE.
ASSIGN ref_new_data->* TO <t_new_data>.
new_data = NEW #( environment = io model_data = <t_new_data> compressed = abap_false ).
DATA conn_reg_split TYPE REF TO zcl_bn_dem_model.
DATA(ref_conn_reg_split) = io->read_dataset( dependency = 'step_01' name = 'CONN_REG_SPLIT' ).
FIELD-SYMBOLS <t_conn_reg_split> TYPE STANDARD TABLE.
ASSIGN ref_conn_reg_split->* TO <t_conn_reg_split>.
conn_reg_split = NEW #( environment = io model_data = <t_conn_reg_split> compressed = abap_false ).
DATA rsp_location_material_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_rsp_location_material_ra) = io->read_dataset( dependency = 'step_01' name = 'RSP_LOCATION_MATERIAL_RATIO' ).
FIELD-SYMBOLS <t_rsp_location_material_rat> TYPE STANDARD TABLE.
ASSIGN ref_rsp_location_material_ra->* TO <t_rsp_location_material_rat>.
rsp_location_material_ratio = NEW #( environment = io model_data = <t_rsp_location_material_rat> compressed = abap_false ).
DATA rsp_location_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_rsp_location_gl_ratio) = io->read_dataset( dependency = 'step_01' name = 'RSP_LOCATION_GL_RATIO' ).
FIELD-SYMBOLS <t_rsp_location_gl_ratio> TYPE STANDARD TABLE.
ASSIGN ref_rsp_location_gl_ratio->* TO <t_rsp_location_gl_ratio>.
rsp_location_gl_ratio = NEW #( environment = io model_data = <t_rsp_location_gl_ratio> compressed = abap_false ).
DATA rsp_supplier_material_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_rsp_supplier_material_ra) = io->read_dataset( dependency = 'step_01' name = 'RSP_SUPPLIER_MATERIAL_RATIO' ).
FIELD-SYMBOLS <t_rsp_supplier_material_rat> TYPE STANDARD TABLE.
ASSIGN ref_rsp_supplier_material_ra->* TO <t_rsp_supplier_material_rat>.
rsp_supplier_material_ratio = NEW #( environment = io model_data = <t_rsp_supplier_material_rat> compressed = abap_false ).
DATA cal_location_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_cal_location_gl_ratio) = io->read_dataset( dependency = 'step_01' name = 'CAL_LOCATION_GL_RATIO' ).
FIELD-SYMBOLS <t_cal_location_gl_ratio> TYPE STANDARD TABLE.
ASSIGN ref_cal_location_gl_ratio->* TO <t_cal_location_gl_ratio>.
cal_location_gl_ratio = NEW #( environment = io model_data = <t_cal_location_gl_ratio> compressed = abap_false ).
DATA cal_location_conn_seg_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_cal_location_conn_seg_ra) = io->read_dataset( dependency = 'step_01' name = 'CAL_LOCATION_CONN_SEG_RATIO' ).
FIELD-SYMBOLS <t_cal_location_conn_seg_rat> TYPE STANDARD TABLE.
ASSIGN ref_cal_location_conn_seg_ra->* TO <t_cal_location_conn_seg_rat>.
cal_location_conn_seg_ratio = NEW #( environment = io model_data = <t_cal_location_conn_seg_rat> compressed = abap_false ).
DATA sap_revenues_consol TYPE REF TO zcl_bn_dem_model.
DATA(ref_sap_revenues_consol) = io->read_dataset( dependency = 'step_03' name = 'SAP_REVENUES_CONSOL' ).
FIELD-SYMBOLS <t_sap_revenues_consol> TYPE STANDARD TABLE.
ASSIGN ref_sap_revenues_consol->* TO <t_sap_revenues_consol>.
sap_revenues_consol = NEW #( environment = io model_data = <t_sap_revenues_consol> compressed = abap_false ).
DATA rsp_supplier_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_rsp_supplier_gl_ratio) = io->read_dataset( dependency = 'step_01' name = 'RSP_SUPPLIER_GL_RATIO' ).
FIELD-SYMBOLS <t_rsp_supplier_gl_ratio> TYPE STANDARD TABLE.
ASSIGN ref_rsp_supplier_gl_ratio->* TO <t_rsp_supplier_gl_ratio>.
rsp_supplier_gl_ratio = NEW #( environment = io model_data = <t_rsp_supplier_gl_ratio> compressed = abap_false ).
DATA cal_supplier_gl_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_cal_supplier_gl_ratio) = io->read_dataset( dependency = 'step_01' name = 'CAL_SUPPLIER_GL_RATIO' ).
FIELD-SYMBOLS <t_cal_supplier_gl_ratio> TYPE STANDARD TABLE.
ASSIGN ref_cal_supplier_gl_ratio->* TO <t_cal_supplier_gl_ratio>.
cal_supplier_gl_ratio = NEW #( environment = io model_data = <t_cal_supplier_gl_ratio> compressed = abap_false ).
DATA cal_supplier_conn_seg_ratio TYPE REF TO zcl_bn_dem_model.
DATA(ref_cal_supplier_conn_seg_ra) = io->read_dataset( dependency = 'step_01' name = 'CAL_SUPPLIER_CONN_SEG_RATIO' ).
FIELD-SYMBOLS <t_cal_supplier_conn_seg_rat> TYPE STANDARD TABLE.
ASSIGN ref_cal_supplier_conn_seg_ra->* TO <t_cal_supplier_conn_seg_rat>.
cal_supplier_conn_seg_ratio = NEW #( environment = io model_data = <t_cal_supplier_conn_seg_rat> compressed = abap_false ).

io->check_budget( ).
DO 1 TIMES.
" Purpose: For each consolidated SAP revenue record, determine which ratio methodology
    " will be used to allocate that revenue by Location (Geography). The chosen methodology
    " is stored as an integer in SIGNEDDATA under key figure DEMREVID009.
    "
    " The waterfall logic inside get_rev_split_method (called with ratio_type = LOCATION)
    " evaluates the following sources in priority order:
    "   1. RSP Billing by Material  - most granular, matched by Time + Matconn
    "   2. RSP Billing by G/L       - matched by Time + Account
    "   3. CAL by G/L               - matched by Time + Account
    "   4. CAL by Connection Region Split - least granular, matched by Time + Conn_Reg_Split
    "   5. NOT_FOUND                - fallback when no ratio source has data
    "
    " The result (DEMREVID009) is consumed by calc_location_alloc_ratios, which resolves
    " the actual ratio values from the chosen source and stores them as DEMREVID015.
    loop at sap_revenues_consol->model_data into data(_sap_revenue).
      " Copy the consolidated revenue record as the basis for the output row.
      data(_new_data) = _sap_revenue.
      " Tag the output row with key figure DEMREVID009 (Location Allocation Method).
      _new_data-demrevid_kfs = kf_loc_split_index.
      " Resolve which ratio source (methodology) applies to this revenue record
      " and store the method index as an integer in SIGNEDDATA.
      DATA chosen_method TYPE rev_split_method.
DO 1 TIMES.
case location.
      when location.
        " If a ratio by material has been found in the RSP Billing data
        " then use it for the allocation.
        read table rsp_location_material_ratio->model_data
            transporting no fields
                with key time = _new_data-time
                               matconn = _new_data-matconn
                               binary search.
        if sy-subrc is initial.
          chosen_method = rsp_billing_material.
          EXIT.
        endif.

        " If a ratio by G/L has been found in the RSP Billing data
        " then use it for the allocation.
        read table rsp_location_gl_ratio->model_data
            transporting no fields
                with key time = _new_data-time
                               account = _new_data-account
                               binary search.
        if sy-subrc is initial.
          chosen_method = rsp_billing_gl.
          EXIT.
        endif.

        " If a ratio by G/L has been found in the CAL Data
        " then use it for the allocation.
        read table cal_location_gl_ratio->model_data
            transporting no fields
                with key time = _new_data-time
                               account = _new_data-account
                               binary search.
        if sy-subrc is initial.
          chosen_method = cal_gl.
          EXIT.
        endif.

        " If a ratio by G/L has been found in the CAL Data
        " then use it for the allocation.
        read table cal_location_conn_seg_ratio->model_data
            transporting no fields
                with key time = _new_data-time
                               conn_reg_split = _new_data-conn_reg_split
                               binary search.
        if sy-subrc is initial.
          chosen_method = cal_reg_split.
          EXIT.
        endif.
      when supplier.
        " If a ratio by material has been found in the RSP Billing data
        " then use it for the allocation.
        read table rsp_supplier_material_ratio->model_data
            transporting no fields
                with key time = _new_data-time
                               account = _new_data-account
                               matconn = _new_data-matconn
                               binary search.
        if sy-subrc is initial.
          chosen_method = rsp_billing_material.
          EXIT.
        endif.

        " If a ratio by G/L has been found in the RSP Billing data
        " then use it for the allocation.
        read table rsp_supplier_gl_ratio->model_data
            transporting no fields
                with key time = _new_data-time
                               account = _new_data-account
                               binary search.
        if sy-subrc is initial.
          chosen_method = rsp_billing_gl.
          EXIT.
        endif.

        " If a ratio by G/L has been found in the CAL Data
        " then use it for the allocation.
        read table cal_supplier_gl_ratio->model_data
            transporting no fields
                with key time = _new_data-time
                               account = _new_data-account
                               binary search.
        if sy-subrc is initial.
          chosen_method = cal_gl.
          EXIT.
        endif.

        " If a ratio by G/L has been found in the CAL Data
        " then use it for the allocation.
        read table cal_supplier_conn_seg_ratio->model_data
            transporting no fields
                with key time = _new_data-time
                               conn_reg_split = _new_data-conn_reg_split
                               binary search.
        if sy-subrc is initial.
          chosen_method = cal_reg_split.
          EXIT.
        endif.
    endcase.

    " If not methodology is found,
    " then fallsback to NOT_FOUND.
    chosen_method = not_found.
ENDDO.
_new_data-signeddata = CONV i( chosen_method ).
      " Append the result to the calculation output.
      new_data->append( _new_data ).
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
