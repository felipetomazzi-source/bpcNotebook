"! <p class="shorttext synchronized" lang="en">DEMREVID - Allocate Revenues (Actuals)</p>
"! BPC "Script Logic" custom logic (BAdI) class for the DEMREVID model (Demand/Revenue by ID,
"! also referred to as "D&R ID" / Schedule 7).
"! <br/><br/>
"! Business purpose: takes the SAP Actuals revenues posted for the current Category/Time
"! and allocates (splits) them across the various reporting dimensions used by DEMREVID, namely:
"! <ul>
"! <li>Geography / Location (RSP Billing vs. CAL based allocation, see calc_location_alloc_*)</li>
"! <li>Supplier / LFC Winning Supplier (see calc_supplier_alloc_*)</li>
"! <li>FFLAS grouping and FFLAS Subset (PQ/ID-Only/Non-FFLAS split, see calc_fflas_*)</li>
"! <li>HSNS Premium re-allocation (see calc_hsns_rev_alloc / calc_fflas_ratios_hsns)</li>
"! </ul>
"! The class also derives the FFLAS ratios (percentage of revenue that is FFLAS vs. non-FFLAS by
"! Material/Account) that other BPC models - most notably DEMREV - reuse as an allocation driver.
"! This is produced by calc_fflas_ratios_by_material, the most business-critical method in this
"! class.
"! <br/><br/>
"! Entry point: EXECUTE receives the notebook context and keeps full working tables in SAP memory.
"! ZCL_BN_TRANSFORM and ZCL_BN_DIMENSION use authorized generic BPC reads and stored metadata.
"! ZCL_BPC_PARAM and ZCL_BPC_CURRENT_VIEW retain the original parameter/current-view semantics.
"! Preview emission is separate from the explicitly published FINAL_DELTA replacement change-set.
"! The NOTEBOOK handler validates/converts CT_DATA and leaves transaction ownership with its caller.
class zcl_bn_dem_alloc definition public
  final
  create public .


  public section.

    " Standard BPC BAdI marker interface implemented by every custom logic class (no methods of its own).
    interfaces if_badi_interface .
    " SAP BPC "UJ Custom Logic" framework interface. Provides the init/execute/cleanup
    " hooks invoked by the BPC Script Logic engine when this logic script (BAdI implementation) runs.
    interfaces if_uj_custom_logic .

    " Notebook contract: typed snapshots, no console/UI dependency.
    types: begin of step_info,
             id type string,
             label type string,
             method_name type string,
           end of step_info,
           step_list type standard table of step_info with empty key,
           begin of snapshot,
             step_id type string,
             dataset type string,
             elapsed_us type i,
             row_count type i,
             truncated type abap_bool,
             rows type zcl_bn_dem_model=>tabl,
           end of snapshot,
           snapshot_list type standard table of snapshot with empty key,
           begin of inspection_result,
             completed_step type string,
             error type string,
             snapshots type snapshot_list,
             output_rows type zcl_bn_dem_model=>tabl,
             output_row_count type i,
             output_truncated type abap_bool,
           end of inspection_result.
    CLASS-METHODS execute IMPORTING io TYPE REF TO zcl_bn_context stop_after TYPE string DEFAULT '' RAISING zcx_bn.
    class-methods get_steps returning value(result) type step_list.
    " Always uses a fresh engine; reruns prerequisites; never returns data to BPC.
    methods inspect_until
      importing it_param type ujk_t_script_logic_hashtable
                current_view type ujk_t_cv
                stop_after type string optional
                row_limit type i default 200
      returning value(result) type inspection_result.

  protected section.
  private section.

    data inspection type inspection_result.
    data capture_enabled type abap_bool.
    data capture_limit type i.
    data active_step type string.
    data step_started type i.
    methods calculate
      importing it_param type ujk_t_script_logic_hashtable
                current_view type ujk_t_cv
                stop_after type string optional.
    methods capture
      importing dataset type string
                model type ref to zcl_bn_dem_model.

    " -----------------------------------------------------------------------
    " Key Figure constants (DEMREVID_KFS dimension members)
    " -----------------------------------------------------------------------
    "! <p class="shorttext synchronized" lang="en">SAP Revenues</p>
    constants kf_sap_revenues type uj_dim_member value 'DEMREVID004' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">SAP Revenues RSP Not Billed</p>
    constants kf_rsp_not_billed type uj_dim_member value 'DEMREVID007' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Connection Region Mapping Flag</p>
    constants kf_conn_region_mapping type uj_dim_member value 'DEMREVID008' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">RSP Not Billed Location Split Index</p>
    constants kf_loc_split_index type uj_dim_member value 'DEMREVID009' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">RSP Location Ratio by Material (%)</p>
    constants kf_rsp_loc_ratio_mat type uj_dim_member value 'DEMREVID010' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">RSP Location Ratio by G/L</p>
    constants kf_rsp_loc_ratio_gl type uj_dim_member value 'DEMREVID011' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">CAL Location Ratio by G/L</p>
    constants kf_cal_loc_ratio_gl type uj_dim_member value 'DEMREVID012' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">CAL Location Ratio by Conn. Region</p>
    constants kf_cal_loc_ratio_conn_reg type uj_dim_member value 'DEMREVID013' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Product Type Mapping Flag</p>
    constants kf_prod_type_mapping type uj_dim_member value 'DEMREVID014' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Ratios used For Split</p>
    constants kf_ratios_for_split type uj_dim_member value 'DEMREVID015' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">RSP Billing with location Split</p>
    constants kf_rsp_bill_with_loc type uj_dim_member value 'DEMREVID016' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">RSP Billing without Location Split</p>
    constants kf_rsp_bill_no_loc type uj_dim_member value 'DEMREVID017' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">RSP Not Billed with Location</p>
    constants kf_rsp_not_billed_loc type uj_dim_member value 'DEMREVID018' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">RSP Billing W/ Product Type</p>
    constants kf_rsp_bill_prod_type type uj_dim_member value 'DEMREVID019' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Material FFLAS Grouping</p>
    constants kf_fflas_grouping type uj_dim_member value 'DEMREVID021' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Monthly FFLAS (%)</p>
    constants kf_fflas_monthly_pct type uj_dim_member value 'DEMREVID022' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">FFLAS Revenue ($)</p>
    constants kf_fflas_revenue type uj_dim_member value 'DEMREVID023' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">PQ FFLAS (%)</p>
    constants kf_pq_fflas_pct type uj_dim_member value 'DEMREVID025' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Layer 1/2 Mapping</p>
    constants kf_l1_l2_mapping type uj_dim_member value 'DEMREVID027' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">LFC Area Location Split Index</p>
    constants kf_supplier_split_index type uj_dim_member value 'DEMREVID028' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">RSP Supplier Ratio by Material</p>
    constants kf_rsp_supplier_ratio_mat type uj_dim_member value 'DEMREVID029' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">RSP Supplier Ratio by G/L Account</p>
    constants kf_rsp_supplier_ratio_gl type uj_dim_member value 'DEMREVID030' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">CAL Supplier Ratio by Conn. Region</p>
    constants kf_cal_supplier_ratio_conn_reg type uj_dim_member value 'DEMREVID031' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">CAL Supplier Ratio by G/L Account</p>
    constants kf_cal_supplier_ratio_gl type uj_dim_member value 'DEMREVID032' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Supplier Split Ratio</p>
    constants kf_supplier_split_ratio type uj_dim_member value 'DEMREVID033' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Hidden Material Group in Final Output</p>
    constants kf_hidden_mat_group type uj_dim_member value 'DEMREVID034' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Material Group Mapping</p>
    constants kf_mat_group_mapping type uj_dim_member value 'DEMREVID035' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Regulated FFLAS Service Level Mapping</p>
    constants kf_reg_fflas_serv_mapping type uj_dim_member value 'DEMREVID037' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Allocated Revenues (Summary)</p>
    constants kf_alloc_rev_summary type uj_dim_member value 'DEMREVID038' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Monthly CAL Conn.</p>
    constants kf_monthly_cal_conn type uj_dim_member value 'DEMREVID039' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Number of Connections (Opening)</p>
    constants kf_conn_opening type uj_dim_member value 'DEMREVID040' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Number of Connections (Closing)</p>
    constants kf_conn_closing type uj_dim_member value 'DEMREVID041' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Hidden Connections in Final Output</p>
    constants kf_hidden_conn type uj_dim_member value 'DEMREVID043' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">HSNS Premium Revenue (Upload)</p>
    constants kf_hsns_premium_upload type uj_dim_member value 'DEMREVID045' ##NO_TEXT.

    " -----------------------------------------------------------------------
    " Geo Driver constants (GEO_DRIVERS dimension members)
    " -----------------------------------------------------------------------
    "! <p class="shorttext synchronized" lang="en">LFC</p>
    constants geo_lfc type uj_dim_member value 'GDRVS_001' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">RONZ</p>
    constants geo_ronz type uj_dim_member value 'GDRVS_002' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">UFB</p>
    constants geo_ufb type uj_dim_member value 'GDRVS_003' ##NO_TEXT.

    " -----------------------------------------------------------------------
    " FFLAS dimension member constants
    " -----------------------------------------------------------------------
    "! <p class="shorttext synchronized" lang="en">ID-only FFLAS</p>
    constants fflas_id type uj_dim_member value 'FFLASID' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Non-FFLAS</p>
    constants fflas_non type uj_dim_member value 'FFLASNON' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">PQ FFLAS</p>
    constants fflas_pq type uj_dim_member value 'FFLASPQ' ##NO_TEXT.

    " -----------------------------------------------------------------------
    " Dimension member constants (Product Type, UFB DR ID, Audittrail)
    " -----------------------------------------------------------------------
    "! <p class="shorttext synchronized" lang="en">Product Type: Access/Rental</p>
    constants access_rental type uj_dim_member value 'PRODUCT_TYPE_001' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Product Type: Bandwidth</p>
    constants bandwidth type uj_dim_member value 'PRODUCT_TYPE_004' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">UFB DR ID: Other LFC UFB 1</p>
    constants other_lfc_ufb_1 type uj_dim_member value 'UFBDRID003' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">UFB DR ID: Other LFC UFB 2</p>
    constants other_lfc_ufb_2 type uj_dim_member value 'UFBDRID004' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">List Connection Charge</p>
    constants conn_price_kf type uj_dim_member value 'DEMREVID044' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">List Monthly Charge</p>
    constants access_price_kf type uj_dim_member value 'DEMREVID042' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">SAP Revenues RSP Billed</p>
    constants rsp_billing type uj_dim_member value 'DEMREVID006' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">SAP Revenues RSP Not Billed</p>
    constants accrual type uj_dim_member value 'DEMREVID007' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">FFLAS Revenue ($)</p>
    constants rev_alloc_fflas type uj_dim_member value 'DEMREVID023' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">SAP Price</p>
    constants sap_price type uj_dim_member value 'DEMREVID002' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Material Remapping</p>
    constants mat_remapping type uj_dim_member value 'DEMREVID036' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Additional Connections (Input)</p>
    constants kf_add_conn_mat_group type uj_dim_member value 'DEMREVID046' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Additional Connection by Mat. Group (Output)</p>
    constants kf_output_add_conn_mat_group type uj_dim_member value 'DEMREVID049' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">FFLAS Ratios by Material</p>
    constants kf_fflas_ratios_material type uj_dim_member value 'DEMREVID047' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">FFLAS Ratio Skipped Flag by Material</p>
    "! Flags Time/Account/Matconn combinations whose Material Group was excluded from the
    "! FFLAS ratio calculation (FFLASMATGROUPSID). Pushed to DEMREV as DEMREV123 (SSNG-3218).
    constants kf_fflas_ratio_skipped type uj_dim_member value 'DEMREVID052' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">FFLAS Not Assigned</p>
    constants fflas_na type uj_dim_member value 'FFLAS_NA' ##NO_TEXT.
    "! <p class="shorttext synchronized" lang="en">Audittrail: DEMREVID Calculation</p>
    constants audit_dnrid_calc type uj_dim_member value 'DEMREVID_CALC' ##NO_TEXT.

    " -----------------------------------------------------------------------
    " Enumerations
    " -----------------------------------------------------------------------
    types: begin of enum rev_split_method,
             _                    value is initial,
             rsp_billing_material value 1,
             rsp_billing_gl       value 2,
             cal_gl               value 3,
             cal_reg_split        value 4,
             not_found            value 5,
             rsp_billing_supplier value 6,
           end of enum rev_split_method,

           begin of enum rev_split_type,
             location,
             supplier,
           end of enum rev_split_type.

    "! <p class="shorttext synchronized" lang="en">Prepare working data for the calculation run</p>
    "! Reads the Script Logic parameters and current view, resolves the BPC environment/category/time
    "! context, and loads and pre-sorts every reference data set (ratios, mappings, SAP revenues, etc.)
    "! used by the remaining methods in this class. Must run first; called once from
    "! if_uj_custom_logic~execute.
    methods initialise
      importing
        !it_param     type ujk_t_script_logic_hashtable
        !current_view type ujk_t_cv.
    " Working attributes / instance data used across the calculation methods below.
    " Most zcl_bn_dem_model-typed attributes are lightweight in-memory views over model data
    " (see zcl_bn_dem_model), each holding one specific input, ratio, or intermediate result set.
    data:
      " Script Logic parameters (e.g. DEBUG, FFLASMATGROUPS, FFLASMATGROUPSID, HSNS_REALLOC_LOCATIONS).
      param                         type ref to zcl_bpc_param,

      " Current CATEGORY member selected in the BPC current view.
      category                      type uj_dim_member,
      " Current TIME range selected in the BPC current view (includes TIME_NA).
      time                          type ujw_t_dimmem_range,
      " BPC environment/connection handle shared by this class and the dimension helper objects below.
      env                           type ref to zcl_bn_context,
      " Helper for PRODUCT_TYPE dimension member/property lookups (e.g. REV_ID_GROUP, children of ACCESS).
      product_type_dim              type ref to zcl_bn_dimension,
      " Helper for MAT_GROUP_ID dimension member/property lookups (e.g. REV_ID_GROUP overwrite).
      mat_group_id_dim              type ref to zcl_bn_dimension,
      " Raw DEMREVID_INPUT audit trail data (all input key figures/mappings for the current selection).
      input_data                    type ref to zcl_bn_dem_model,
      " Previously stored DEMREVID_OUTPUT data, used as the "before" side of the delta comparison.
      output_data                   type ref to zcl_bn_dem_model,
      " Accumulator for every record calculated in this run; written back to BPC at the end of execute( ).
      new_data                      type ref to zcl_bn_dem_model,
      " Connection Region Split mapping (DEMREVID008), keyed by Time/Account.
      conn_reg_split                type ref to zcl_bn_dem_model,
      " L1/L2 FFLAS Subset mapping (DEMREVID027), keyed by Time/Account.
      l1_l2_mapping                 type ref to zcl_bn_dem_model,
      " RSP Billing ratio by Material for Location allocation (DEMREVID010).
      rsp_location_material_ratio   type ref to zcl_bn_dem_model,
      " RSP Billing ratio by G/L (Account) for Location allocation (DEMREVID011).
      rsp_location_gl_ratio         type ref to zcl_bn_dem_model,
      " RSP Billing ratio by Material for Supplier allocation (DEMREVID029).
      rsp_supplier_material_ratio   type ref to zcl_bn_dem_model,
      " CAL ratio by G/L (Account) for Location allocation (DEMREVID012).
      cal_location_gl_ratio         type ref to zcl_bn_dem_model,
      " CAL ratio by Connection Region Split for Location allocation (DEMREVID013).
      cal_location_conn_seg_ratio   type ref to zcl_bn_dem_model,
      " SAP Actuals revenues loaded for the current selection, grouped/re-tagged for this calculation (DEMREVID004).
      sap_revenues                  type ref to zcl_bn_dem_model,
      " Chosen Location allocation ratio per Time/Account/Matconn, resolved from the ratio sources above (DEMREVID015).
      rsp_split_ratios              type ref to zcl_bn_dem_model,
      " FFLAS monthly ratio (%) by Material, read from the FFLAS grouping input (DEMREVID022).
      fflas_month_ratio             type ref to zcl_bn_dem_model,
      " SAP revenues consolidated (Billed + Not Billed), grouping out Cost Centre/Doc Type/Audittrail.
      sap_revenues_consol           type ref to zcl_bn_dem_model,
      " RSP Billing ratio by G/L (Account) for Supplier allocation (DEMREVID030).
      rsp_supplier_gl_ratio         type ref to zcl_bn_dem_model,
      " CAL ratio by G/L (Account) for Supplier allocation (DEMREVID032).
      cal_supplier_gl_ratio         type ref to zcl_bn_dem_model,
      " CAL ratio by Connection Region Split for Supplier allocation (DEMREVID031).
      cal_supplier_conn_seg_ratio   type ref to zcl_bn_dem_model,
      " Chosen Supplier allocation ratio per Time/Account/Matconn, resolved from the ratio sources above (DEMREVID033).
      supplier_ratios               type ref to zcl_bn_dem_model,
      " Material Group mapping, used to derive MAT_GROUP_ID from the (remapped) Material or Account (DEMREVID035).
      mat_group_mapping             type ref to zcl_bn_dem_model,
      " Transposed Allocated Revenues (DEMREVID038), used as the basis for connection and price transposition.
      transposed_revenues           type ref to zcl_bn_dem_model,
      " Helper for MATCONN (material connection) dimension member/property lookups (e.g. PRODUCT_TYPE).
      matconn_dim                   type ref to zcl_bn_dimension,
      " Material Groups (by MAT_GROUP_ID) for which the FFLAS ratio calculation must be skipped.
      skip_fflas_ratio_mat_group_id type ujw_t_dimmem_range.

    "! <p class="shorttext synchronized" lang="en">Calculate Rev. Split Methodology</p>
    "! Four available options:
    "! <ul>
    "! <li>RSP BIlling Material : Uses the ratio by Material found in the RSP Billing data</li>
    "! <li>RSP BIlling G/L : Uses the ratio by G/L found in the RSP Billing data</li>
    "! <li>Connection Region by G/L: Uses the ratio by G/L found in the CAL Data</li>
    "! <li>Connection Region by Connection Split: Uses the ratio by Connection Split found in the CAL Data</li>
    "! </ul>
    "! <p>Note: ratio_type and the return value use fixed values (LOCATION, SUPPLIER /
    "! RSP_BILLING_MATERIAL, RSP_BILLING_GL, CAL_GL, CAL_REG_SPLIT, NOT_FOUND) defined as ABAP
    "! enumerated values on the underlying data elements REV_SPLIT_TYPE / REV_SPLIT_METHOD in the
    "! ABAP Dictionary, not in this class - see note on additional dependencies.</p>
    methods get_rev_split_method
      importing
        ratio_type             type rev_split_type
        _sap_revenue           type zcl_bn_dem_model=>struct
      returning
        value(rev_split_index) type rev_split_method.
    "! Determines which allocation methodology will be used when allocating Revenues not Billed to RSP by Location (Geography)
    methods calc_location_alloc_method.
    "! <p class="shorttext synchronized" lang="en">Resolve the Location allocation ratio</p>
    "! For every record produced by calc_location_alloc_method (DEMREVID009), looks up the matching
    "! ratio in the ratio source selected for that record (RSP Billing by Material/G-L, or CAL by
    "! G-L/Connection Region Split) and stores the resolved Geography driver and ratio as DEMREVID015
    "! in rsp_split_ratios.
    methods calc_location_alloc_ratios.
    "! <p class="shorttext synchronized" lang="en">Allocate RSP-Billed revenues by Location</p>
    "! Consolidates the RSP-Billed revenue (Doc Type RS/AD/AC, excluding TBD and N/A UFB Reporting
    "! categories) and stores it, already split by Geography/Location, as DEMREVID016.
    methods calc_alloc_rsp_billed_data.
    "! <p class="shorttext synchronized" lang="en">Allocate the RSP Billing remainder by Location</p>
    "! Subtracts the RSP-Billed revenue (DEMREVID016) from the total RSP Billing revenue and
    "! allocates whatever remains using the Location ratios in rsp_split_ratios, storing the result
    "! as DEMREVID017.
    methods calc_remaining_rsp_billing.
    "! <p class="shorttext synchronized" lang="en">Allocate Revenues Not Billed to RSP by Location</p>
    "! Applies the Location ratios in rsp_split_ratios to the "RSP Not Billed" revenue (DEMREVID007),
    "! producing DEMREVID018.
    methods calc_rsp_not_billed_location.
    "! <p class="shorttext synchronized" lang="en">Assign FFLAS Grouping and Monthly Ratio</p>
    "! For each consolidated SAP revenue record, looks up the FFLAS Grouping (DEMREVID021) and FFLAS
    "! Monthly Ratio % (DEMREVID022), first by Material and, if not found, by Account.
    methods calc_fflas_grouping.

    "! Calculate PQ FFLAS Revenues <br/>
    "! 1. Consolidate Billing Revenues:
    "! <ul>
    "! <li> RPS Billing w/ Location [DEMREVID016] </li>
    "! <li> Remaining RSP Billing w/ location [DEMREVID017] </li>
    "! <li> RSP Not Billed w/ location [DEMREVID018] </li>
    "! </ul>
    "! 2. Filter consolidated revenues where Geographic Driver (Location) is UFB Chorus or RONZ <br/><br/>
    "! 3. Multiply the result of step 2 by the FFLAS Ratio (%) [DEMREVID022] <br/><br/>
    "! 4. Filter consolidated revenues where Geographic Driver (Location) is LFC <br/><br/>
    "! 5. Multiply the result of step 4 by the FFLAS Ratio (%) [DEMREVID022] <br/><br/>
    methods calc_pq_id_fflas_revenue
      returning
        value(result) type ref to zcl_bn_dem_model.
    "! <p class="shorttext synchronized" lang="en">Calculate PQ FFLAS ratio (%)</p>
    "! Computes the ratio of PQ FFLAS revenue to total revenue (per Time/Account/Matconn)
    "! from the allocated FFLAS revenues produced by calc_pq_id_fflas_revenue.
    "! @parameter fflas_revenues | Allocated FFLAS revenues (output of calc_pq_id_fflas_revenue).
    "! @parameter result | PQ FFLAS ratio (%) records, tagged with key figure kf_pq_fflas_pct.
    methods calc_pq_fflas_ratio
      returning
        value(result) type ref to zcl_bn_dem_model.
    "! Assign Connection Region Split and FFLAS Subset (L1/L2 FFLAS) to Model Data
    "! <p>Also derives PRODUCT_TYPE (via overwrite or MATCONN default), REV_ID_GROUP (via
    "! PRODUCT_TYPE or MAT_GROUP_ID override), MATCONN remap (MATREMAP), MAT_GROUP_ID and
    "! REG_FFLAS_SERV.</p>
    "! @parameter model_ref | Model instance whose records will be enriched in place.
    methods assign_new_fields_rev
      importing
        model_ref type ref to zcl_bn_dem_model.
    "! The supplier allocation ratio will be used to allocate LFC
    "! revenues
    methods calc_supplier_alloc_method.
    "! <p class="shorttext synchronized" lang="en">Resolve the Supplier allocation ratio</p>
    "! Mirrors calc_location_alloc_ratios but for the Supplier (LFC Winning Supplier) dimension:
    "! resolves the ratio chosen in DEMREVID028 and stores it, together with the LFC_WIN_SUPPLIER
    "! member, as DEMREVID033 in supplier_ratios.
    methods calc_supplier_alloc_ratios.
    "! <p class="shorttext synchronized" lang="en">Allocate ID-Only revenues by Supplier</p>
    "! Applies the Supplier ratios in supplier_ratios to the ID-Only Allocated Revenues
    "! (DEMREVID023/FFLASID), splitting each record across the matching LFC_WIN_SUPPLIER members.
    methods calc_alloc_id_rev_supplier.
    "! <p class="shorttext synchronized" lang="en">Assign SAP price at Material level</p>
    "! Copies the SAP price key figure onto the consolidated revenue records, matched by Time/Matconn.
    methods calc_price_material_level.
    "! <p class="shorttext synchronized" lang="en">Re-allocate HSNS Premium revenues</p>
    "! HSNS Premium (Account 001054200, Access/Rental and Bandwidth product types) is credited out of
    "! the standard Allocated Revenue and re-derived from RSP Billing (CDW flat-file) and SAP Accrual
    "! data, re-allocating Bandwidth using the Access/Rental material group and applying
    "! Location/Supplier/FFLAS ratios weighted by RSP Billing revenue.
    "! <p>The SAP Accrual is split across FFLAS (PQ / ID-Only) and Location using the RSP Billing
    "! ratio at two granularities: first by Material (MATCONN), and only when the material has no
    "! RSP Billing of its own does it fall back to the coarser Material Group ratio. This keeps an
    "! Accrual that is 100% ID-Only at material level from leaking into PQ-FFLAS via the blended
    "! material-group ratio.</p>
    methods calc_hsns_rev_alloc.
    "! Transpose the data allowing the drill down between all dimensions.
    methods transpose_revenues.
    "! <p class="shorttext synchronized" lang="en">Transpose Connections (opening/closing balances)</p>
    "! Builds the current and prior period CAL connection counts, carries forward closing balances
    "! into opening balances when there is no revenue in the current period, and adds the
    "! "additional connections by Material Group" adjustment key figures.
    methods transpose_connections.
    "! Transpose the prices for each product in the Summary reports (PQ and ID-Only).
    "! There are two types of prices:
    "! <ul>
    "! <li>Connection Price - related the the One-Off product</li>
    "! <li>Monthly Price - related to the Access products</li>
    "! </ul>
    methods transpose_prices.
    "!<p>Calculate FFLAS Ratios by Material</p>
    "! The FFLAS ratios for Schedule 24 will be used to allocate the Actuals in Schedule 7 (D&R ID)
    "! <p>For every Time/Account/Matconn combination, computes the share of total SAP revenue
    "! (sap_revenues, i.e. base_revenues) that corresponds to each FFLAS value found in the
    "! Allocated Revenues (DEMREVID023, grouped by Category/Time/Account/Matconn/FFLAS/MAT_GROUP_ID).
    "! The ratio for each FFLAS is fflas_rev / base_rev; any remainder (revenue not covered by an
    "! explicit FFLAS ratio) is assigned to the synthetic FFLAS value FFLASNON so that the ratios
    "! for a given Time/Account/Matconn always sum to 1.</p>
    "! <p>Material Groups listed in skip_fflas_ratio_mat_group_id (Script Logic parameter
    "! FFLASMATGROUPSID) are excluded from the base revenue before the ratios are computed, so no
    "! FFLAS ratio is produced for them. Instead, each skipped Time/Account/Matconn is flagged
    "! (value 1, FFLAS_NA) in kf_fflas_ratio_skipped, so DEMREV can post its fallback allocation
    "! for those materials to a separate key figure (SSNG-3218).</p>
    "! <p>Result key figure: the macro constant kf_fflas_ratios_material (audittrail
    "! audit_dnrid_calc), appended to new_data. These are the ratios consumed by the DEMREV model
    "! to allocate its own Actuals.</p>
    methods calc_fflas_ratios_by_material
      returning
        value(fflas_ratios) type ref to zcl_bn_dem_model.



endclass.



class zcl_bn_dem_alloc implementation.


  method if_uj_custom_logic~cleanup.
 TRY.


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method if_uj_custom_logic~execute.
 TRY.

    RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = 'NOTEBOOK_ONLY' detail = 'Use the pinned NOTEBOOK handler'.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  METHOD execute.
 TRY.

    IF io->environment <> 'CH_PLANNING' OR io->model <> 'DEMREVID'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'ALLOCATION_CONTEXT' detail = 'DEMREVID003 requires CH_PLANNING / DEMREVID'.
    ENDIF.
    DATA(engine) = NEW zcl_bn_dem_alloc( ). engine->env = io.
    engine->capture_enabled = abap_true. engine->capture_limit = CONV i( io->input( 'PREVIEW_ROWS' ) ).
    IF engine->capture_limit < 1 OR engine->capture_limit > 5000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PREVIEW_LIMIT' detail = 'Preview rows must be 1 to 5000'.
    ENDIF.
    DATA(steps) = get_steps( ).
    IF stop_after IS NOT INITIAL AND NOT line_exists( steps[ id = stop_after ] ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'STEP' detail = 'Unknown allocation stop boundary'.
    ENDIF.
    DATA(parameters) = io->script_parameters( ).
    READ TABLE parameters ASSIGNING FIELD-SYMBOL(<flag>) WITH KEY hashkey = 'FFLASMATGROUPS'.
    IF sy-subrc = 0.
      CASE <flag>-hashvalue.
        WHEN 'true'. <flag>-hashvalue = '1'.
        WHEN 'false'. <flag>-hashvalue = '0'.
      ENDCASE.
    ENDIF.
    READ TABLE parameters ASSIGNING <flag> WITH KEY hashkey = 'DEBUG'.
    IF sy-subrc = 0.
      CASE <flag>-hashvalue.
        WHEN 'true'. <flag>-hashvalue = 'ON'.
        WHEN 'false'. <flag>-hashvalue = 'OFF'.
      ENDCASE.
    ENDIF.
    engine->calculate( it_param = parameters current_view = io->current_view( ) stop_after = stop_after ).
    IF stop_after IS NOT INITIAL. RETURN. ENDIF.
    io->emit_table( name = 'FINAL_REPLACEMENT' rows = engine->new_data->model_data ).
    " Retain the original compare_delta handling, including old-only records.
    engine->new_data->compare_delta( engine->output_data ).
    io->allocation_result( name = 'FINAL_DELTA' rows = engine->new_data->model_data kind = 'delta' ).
    io->emit_table( name = 'FINAL_DELTA' rows = engine->new_data->model_data ).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  ENDMETHOD.
  method get_steps.
 TRY.

    result = value #(
      ( id = 'INITIALISE' label = 'Load inputs' method_name = 'initialise' )
      ( id = 'ENRICH_REVENUES' label = 'Derive revenue dimensions' method_name = 'assign_new_fields_rev' )
      ( id = 'CONSOLIDATE' label = 'Consolidate revenues' method_name = 'group' )
      ( id = 'LOCATION_ALLOC_METHOD' label = 'Calc location alloc method' method_name = 'calc_location_alloc_method' )
      ( id = 'LOCATION_ALLOC_RATIOS' label = 'Calc location alloc ratios' method_name = 'calc_location_alloc_ratios' )
      ( id = 'ALLOC_RSP_BILLED_DATA' label = 'Calc alloc rsp billed data' method_name = 'calc_alloc_rsp_billed_data' )
      ( id = 'REMAINING_RSP_BILLING' label = 'Calc remaining rsp billing' method_name = 'calc_remaining_rsp_billing' )
      ( id = 'RSP_NOT_BILLED_LOCATION' label = 'Calc rsp not billed location' method_name = 'calc_rsp_not_billed_location' )
      ( id = 'FFLAS_GROUPING' label = 'Calc fflas grouping' method_name = 'calc_fflas_grouping' )
      ( id = 'PQ_ID_FFLAS_REVENUE' label = 'Calc pq id fflas revenue' method_name = 'calc_pq_id_fflas_revenue' )
      ( id = 'PQ_FFLAS_RATIO' label = 'Calc pq fflas ratio' method_name = 'calc_pq_fflas_ratio' )
      ( id = 'SUPPLIER_ALLOC_METHOD' label = 'Calc supplier alloc method' method_name = 'calc_supplier_alloc_method' )
      ( id = 'SUPPLIER_ALLOC_RATIOS' label = 'Calc supplier alloc ratios' method_name = 'calc_supplier_alloc_ratios' )
      ( id = 'ALLOC_ID_REV_SUPPLIER' label = 'Calc alloc id rev supplier' method_name = 'calc_alloc_id_rev_supplier' )
      ( id = 'PRICE_MATERIAL_LEVEL' label = 'Calc price material level' method_name = 'calc_price_material_level' )
      ( id = 'HSNS_REV_ALLOC' label = 'Calc hsns rev alloc' method_name = 'calc_hsns_rev_alloc' )
      ( id = 'FFLAS_RATIOS_BY_MATERIAL' label = 'Calc fflas ratios by material' method_name = 'calc_fflas_ratios_by_material' )
      ( id = 'TRANSPOSE_REVENUES' label = 'Transpose revenues' method_name = 'transpose_revenues' )
      ( id = 'TRANSPOSE_PRICES' label = 'Transpose prices' method_name = 'transpose_prices' )
      ( id = 'TRANSPOSE_CONNECTIONS' label = 'Transpose connections' method_name = 'transpose_connections' )
    ).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.

  method inspect_until.
 TRY.

    RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = 'NOTEBOOK_ONLY' detail = 'Use execute and STOP_AFTER with a frozen context'.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.

  method capture.
 TRY.

    IF capture_enabled = abap_false OR model IS NOT BOUND OR env IS NOT BOUND. RETURN. ENDIF.
    env->check_rows( lines( model->model_data ) ).
    env->check_budget( ).
    GET RUN TIME FIELD DATA(finished).
    DATA rows TYPE zcl_bn_dem_model=>tabl.
    LOOP AT model->model_data INTO DATA(row) TO capture_limit. APPEND row TO rows. ENDLOOP.
    env->emit_table( name = active_step && '/' && dataset rows = rows
      total_count = lines( model->model_data ) elapsed_us = finished - step_started ).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.

  method calculate.
 TRY.

    active_step = 'INITIALISE'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #( ( CONV string( 'GENERIC_MODEL_READS' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    initialise( it_param = it_param current_view = current_view ).
    capture( dataset = 'INPUT_DATA' model = input_data ).
    capture( dataset = 'SAP_REVENUES' model = sap_revenues ).
    capture( dataset = 'OUTPUT_DATA' model = output_data ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF conn_reg_split IS BOUND. capture( dataset = 'CONN_REG_SPLIT' model = conn_reg_split ). ENDIF.
    IF l1_l2_mapping IS BOUND. capture( dataset = 'L1_L2_MAPPING' model = l1_l2_mapping ). ENDIF.
    IF rsp_location_material_ratio IS BOUND. capture( dataset = 'RSP_LOCATION_MATERIAL_RATIO' model = rsp_location_material_ratio ). ENDIF.
    IF rsp_location_gl_ratio IS BOUND. capture( dataset = 'RSP_LOCATION_GL_RATIO' model = rsp_location_gl_ratio ). ENDIF.
    IF rsp_supplier_material_ratio IS BOUND. capture( dataset = 'RSP_SUPPLIER_MATERIAL_RATIO' model = rsp_supplier_material_ratio ). ENDIF.
    IF cal_location_gl_ratio IS BOUND. capture( dataset = 'CAL_LOCATION_GL_RATIO' model = cal_location_gl_ratio ). ENDIF.
    IF cal_location_conn_seg_ratio IS BOUND. capture( dataset = 'CAL_LOCATION_CONN_SEG_RATIO' model = cal_location_conn_seg_ratio ). ENDIF.
    IF rsp_supplier_gl_ratio IS BOUND. capture( dataset = 'RSP_SUPPLIER_GL_RATIO' model = rsp_supplier_gl_ratio ). ENDIF.
    IF cal_supplier_gl_ratio IS BOUND. capture( dataset = 'CAL_SUPPLIER_GL_RATIO' model = cal_supplier_gl_ratio ). ENDIF.
    IF cal_supplier_conn_seg_ratio IS BOUND. capture( dataset = 'CAL_SUPPLIER_CONN_SEG_RATIO' model = cal_supplier_conn_seg_ratio ). ENDIF.
    IF mat_group_mapping IS BOUND. capture( dataset = 'MAT_GROUP_MAPPING' model = mat_group_mapping ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'ENRICH_REVENUES'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'INITIALISE/SAP_REVENUES' ) )
        ( CONV string( 'INITIALISE/NEW_DATA' ) )
        ( CONV string( 'INITIALISE/INPUT_DATA' ) )
        ( CONV string( 'INITIALISE/CONN_REG_SPLIT' ) )
        ( CONV string( 'INITIALISE/L1_L2_MAPPING' ) )
        ( CONV string( 'INITIALISE/MAT_GROUP_MAPPING' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    assign_new_fields_rev( sap_revenues ).
    new_data->append( sap_revenues ).
    capture( dataset = 'SAP_REVENUES' model = sap_revenues ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF input_data IS BOUND. capture( dataset = 'INPUT_DATA' model = input_data ). ENDIF.
    IF conn_reg_split IS BOUND. capture( dataset = 'CONN_REG_SPLIT' model = conn_reg_split ). ENDIF.
    IF l1_l2_mapping IS BOUND. capture( dataset = 'L1_L2_MAPPING' model = l1_l2_mapping ). ENDIF.
    IF mat_group_mapping IS BOUND. capture( dataset = 'MAT_GROUP_MAPPING' model = mat_group_mapping ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'CONSOLIDATE'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'ENRICH_REVENUES/NEW_DATA' ) )
        ( CONV string( 'ENRICH_REVENUES/SAP_REVENUES' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    sap_revenues_consol = sap_revenues->copy( )->group(
      include_dimensions = abap_false group_by = value #( ( 'DEMREVID_KFS' ) ) ).
    capture( dataset = 'SAP_REVENUES_CONSOL' model = sap_revenues_consol ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF sap_revenues IS BOUND. capture( dataset = 'SAP_REVENUES' model = sap_revenues ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'LOCATION_ALLOC_METHOD'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'CONSOLIDATE/NEW_DATA' ) )
        ( CONV string( 'ENRICH_REVENUES/CONN_REG_SPLIT' ) )
        ( CONV string( 'CONSOLIDATE/SAP_REVENUES_CONSOL' ) )
        ( CONV string( 'INITIALISE/RSP_LOCATION_MATERIAL_RATIO' ) )
        ( CONV string( 'INITIALISE/RSP_LOCATION_GL_RATIO' ) )
        ( CONV string( 'INITIALISE/RSP_SUPPLIER_MATERIAL_RATIO' ) )
        ( CONV string( 'INITIALISE/CAL_LOCATION_GL_RATIO' ) )
        ( CONV string( 'INITIALISE/CAL_LOCATION_CONN_SEG_RATIO' ) )
        ( CONV string( 'INITIALISE/RSP_SUPPLIER_GL_RATIO' ) )
        ( CONV string( 'INITIALISE/CAL_SUPPLIER_GL_RATIO' ) )
        ( CONV string( 'INITIALISE/CAL_SUPPLIER_CONN_SEG_RATIO' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_location_alloc_method( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF conn_reg_split IS BOUND. capture( dataset = 'CONN_REG_SPLIT' model = conn_reg_split ). ENDIF.
    IF sap_revenues_consol IS BOUND. capture( dataset = 'SAP_REVENUES_CONSOL' model = sap_revenues_consol ). ENDIF.
    IF rsp_location_material_ratio IS BOUND. capture( dataset = 'RSP_LOCATION_MATERIAL_RATIO' model = rsp_location_material_ratio ). ENDIF.
    IF rsp_location_gl_ratio IS BOUND. capture( dataset = 'RSP_LOCATION_GL_RATIO' model = rsp_location_gl_ratio ). ENDIF.
    IF rsp_supplier_material_ratio IS BOUND. capture( dataset = 'RSP_SUPPLIER_MATERIAL_RATIO' model = rsp_supplier_material_ratio ). ENDIF.
    IF cal_location_gl_ratio IS BOUND. capture( dataset = 'CAL_LOCATION_GL_RATIO' model = cal_location_gl_ratio ). ENDIF.
    IF cal_location_conn_seg_ratio IS BOUND. capture( dataset = 'CAL_LOCATION_CONN_SEG_RATIO' model = cal_location_conn_seg_ratio ). ENDIF.
    IF rsp_supplier_gl_ratio IS BOUND. capture( dataset = 'RSP_SUPPLIER_GL_RATIO' model = rsp_supplier_gl_ratio ). ENDIF.
    IF cal_supplier_gl_ratio IS BOUND. capture( dataset = 'CAL_SUPPLIER_GL_RATIO' model = cal_supplier_gl_ratio ). ENDIF.
    IF cal_supplier_conn_seg_ratio IS BOUND. capture( dataset = 'CAL_SUPPLIER_CONN_SEG_RATIO' model = cal_supplier_conn_seg_ratio ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'LOCATION_ALLOC_RATIOS'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'LOCATION_ALLOC_METHOD/NEW_DATA' ) )
        ( CONV string( 'LOCATION_ALLOC_METHOD/CONN_REG_SPLIT' ) )
        ( CONV string( 'LOCATION_ALLOC_METHOD/RSP_LOCATION_MATERIAL_RATIO' ) )
        ( CONV string( 'LOCATION_ALLOC_METHOD/RSP_LOCATION_GL_RATIO' ) )
        ( CONV string( 'LOCATION_ALLOC_METHOD/CAL_LOCATION_GL_RATIO' ) )
        ( CONV string( 'LOCATION_ALLOC_METHOD/CAL_LOCATION_CONN_SEG_RATIO' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_location_alloc_ratios( ).
    capture( dataset = 'RSP_SPLIT_RATIOS' model = rsp_split_ratios ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF conn_reg_split IS BOUND. capture( dataset = 'CONN_REG_SPLIT' model = conn_reg_split ). ENDIF.
    IF rsp_location_material_ratio IS BOUND. capture( dataset = 'RSP_LOCATION_MATERIAL_RATIO' model = rsp_location_material_ratio ). ENDIF.
    IF rsp_location_gl_ratio IS BOUND. capture( dataset = 'RSP_LOCATION_GL_RATIO' model = rsp_location_gl_ratio ). ENDIF.
    IF cal_location_gl_ratio IS BOUND. capture( dataset = 'CAL_LOCATION_GL_RATIO' model = cal_location_gl_ratio ). ENDIF.
    IF cal_location_conn_seg_ratio IS BOUND. capture( dataset = 'CAL_LOCATION_CONN_SEG_RATIO' model = cal_location_conn_seg_ratio ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'ALLOC_RSP_BILLED_DATA'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'LOCATION_ALLOC_RATIOS/NEW_DATA' ) )
        ( CONV string( 'ENRICH_REVENUES/INPUT_DATA' ) )
        ( CONV string( 'LOCATION_ALLOC_RATIOS/CONN_REG_SPLIT' ) )
        ( CONV string( 'ENRICH_REVENUES/L1_L2_MAPPING' ) )
        ( CONV string( 'ENRICH_REVENUES/MAT_GROUP_MAPPING' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_alloc_rsp_billed_data( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF input_data IS BOUND. capture( dataset = 'INPUT_DATA' model = input_data ). ENDIF.
    IF conn_reg_split IS BOUND. capture( dataset = 'CONN_REG_SPLIT' model = conn_reg_split ). ENDIF.
    IF l1_l2_mapping IS BOUND. capture( dataset = 'L1_L2_MAPPING' model = l1_l2_mapping ). ENDIF.
    IF mat_group_mapping IS BOUND. capture( dataset = 'MAT_GROUP_MAPPING' model = mat_group_mapping ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'REMAINING_RSP_BILLING'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'ALLOC_RSP_BILLED_DATA/NEW_DATA' ) )
        ( CONV string( 'CONSOLIDATE/SAP_REVENUES' ) )
        ( CONV string( 'LOCATION_ALLOC_RATIOS/RSP_SPLIT_RATIOS' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_remaining_rsp_billing( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF sap_revenues IS BOUND. capture( dataset = 'SAP_REVENUES' model = sap_revenues ). ENDIF.
    IF rsp_split_ratios IS BOUND. capture( dataset = 'RSP_SPLIT_RATIOS' model = rsp_split_ratios ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'RSP_NOT_BILLED_LOCATION'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'REMAINING_RSP_BILLING/NEW_DATA' ) )
        ( CONV string( 'REMAINING_RSP_BILLING/SAP_REVENUES' ) )
        ( CONV string( 'REMAINING_RSP_BILLING/RSP_SPLIT_RATIOS' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_rsp_not_billed_location( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF sap_revenues IS BOUND. capture( dataset = 'SAP_REVENUES' model = sap_revenues ). ENDIF.
    IF rsp_split_ratios IS BOUND. capture( dataset = 'RSP_SPLIT_RATIOS' model = rsp_split_ratios ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'FFLAS_GROUPING'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'RSP_NOT_BILLED_LOCATION/NEW_DATA' ) )
        ( CONV string( 'ALLOC_RSP_BILLED_DATA/INPUT_DATA' ) )
        ( CONV string( 'LOCATION_ALLOC_METHOD/SAP_REVENUES_CONSOL' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_fflas_grouping( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF input_data IS BOUND. capture( dataset = 'INPUT_DATA' model = input_data ). ENDIF.
    IF fflas_month_ratio IS BOUND. capture( dataset = 'FFLAS_MONTH_RATIO' model = fflas_month_ratio ). ENDIF.
    IF sap_revenues_consol IS BOUND. capture( dataset = 'SAP_REVENUES_CONSOL' model = sap_revenues_consol ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'PQ_ID_FFLAS_REVENUE'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'FFLAS_GROUPING/NEW_DATA' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    new_data->append( calc_pq_id_fflas_revenue( ) ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'PQ_FFLAS_RATIO'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'PQ_ID_FFLAS_REVENUE/NEW_DATA' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    new_data->append( calc_pq_fflas_ratio( ) ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'SUPPLIER_ALLOC_METHOD'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'PQ_FFLAS_RATIO/NEW_DATA' ) )
        ( CONV string( 'FFLAS_GROUPING/SAP_REVENUES_CONSOL' ) )
        ( CONV string( 'ALLOC_RSP_BILLED_DATA/CONN_REG_SPLIT' ) )
        ( CONV string( 'LOCATION_ALLOC_RATIOS/RSP_LOCATION_MATERIAL_RATIO' ) )
        ( CONV string( 'LOCATION_ALLOC_RATIOS/RSP_LOCATION_GL_RATIO' ) )
        ( CONV string( 'LOCATION_ALLOC_METHOD/RSP_SUPPLIER_MATERIAL_RATIO' ) )
        ( CONV string( 'LOCATION_ALLOC_RATIOS/CAL_LOCATION_GL_RATIO' ) )
        ( CONV string( 'LOCATION_ALLOC_RATIOS/CAL_LOCATION_CONN_SEG_RATIO' ) )
        ( CONV string( 'LOCATION_ALLOC_METHOD/RSP_SUPPLIER_GL_RATIO' ) )
        ( CONV string( 'LOCATION_ALLOC_METHOD/CAL_SUPPLIER_GL_RATIO' ) )
        ( CONV string( 'LOCATION_ALLOC_METHOD/CAL_SUPPLIER_CONN_SEG_RATIO' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_supplier_alloc_method( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF sap_revenues_consol IS BOUND. capture( dataset = 'SAP_REVENUES_CONSOL' model = sap_revenues_consol ). ENDIF.
    IF conn_reg_split IS BOUND. capture( dataset = 'CONN_REG_SPLIT' model = conn_reg_split ). ENDIF.
    IF rsp_location_material_ratio IS BOUND. capture( dataset = 'RSP_LOCATION_MATERIAL_RATIO' model = rsp_location_material_ratio ). ENDIF.
    IF rsp_location_gl_ratio IS BOUND. capture( dataset = 'RSP_LOCATION_GL_RATIO' model = rsp_location_gl_ratio ). ENDIF.
    IF rsp_supplier_material_ratio IS BOUND. capture( dataset = 'RSP_SUPPLIER_MATERIAL_RATIO' model = rsp_supplier_material_ratio ). ENDIF.
    IF cal_location_gl_ratio IS BOUND. capture( dataset = 'CAL_LOCATION_GL_RATIO' model = cal_location_gl_ratio ). ENDIF.
    IF cal_location_conn_seg_ratio IS BOUND. capture( dataset = 'CAL_LOCATION_CONN_SEG_RATIO' model = cal_location_conn_seg_ratio ). ENDIF.
    IF rsp_supplier_gl_ratio IS BOUND. capture( dataset = 'RSP_SUPPLIER_GL_RATIO' model = rsp_supplier_gl_ratio ). ENDIF.
    IF cal_supplier_gl_ratio IS BOUND. capture( dataset = 'CAL_SUPPLIER_GL_RATIO' model = cal_supplier_gl_ratio ). ENDIF.
    IF cal_supplier_conn_seg_ratio IS BOUND. capture( dataset = 'CAL_SUPPLIER_CONN_SEG_RATIO' model = cal_supplier_conn_seg_ratio ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'SUPPLIER_ALLOC_RATIOS'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'SUPPLIER_ALLOC_METHOD/NEW_DATA' ) )
        ( CONV string( 'SUPPLIER_ALLOC_METHOD/CONN_REG_SPLIT' ) )
        ( CONV string( 'SUPPLIER_ALLOC_METHOD/RSP_SUPPLIER_MATERIAL_RATIO' ) )
        ( CONV string( 'SUPPLIER_ALLOC_METHOD/RSP_SUPPLIER_GL_RATIO' ) )
        ( CONV string( 'SUPPLIER_ALLOC_METHOD/CAL_SUPPLIER_GL_RATIO' ) )
        ( CONV string( 'SUPPLIER_ALLOC_METHOD/CAL_SUPPLIER_CONN_SEG_RATIO' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_supplier_alloc_ratios( ).
    capture( dataset = 'SUPPLIER_RATIOS' model = supplier_ratios ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF conn_reg_split IS BOUND. capture( dataset = 'CONN_REG_SPLIT' model = conn_reg_split ). ENDIF.
    IF rsp_supplier_material_ratio IS BOUND. capture( dataset = 'RSP_SUPPLIER_MATERIAL_RATIO' model = rsp_supplier_material_ratio ). ENDIF.
    IF rsp_supplier_gl_ratio IS BOUND. capture( dataset = 'RSP_SUPPLIER_GL_RATIO' model = rsp_supplier_gl_ratio ). ENDIF.
    IF cal_supplier_gl_ratio IS BOUND. capture( dataset = 'CAL_SUPPLIER_GL_RATIO' model = cal_supplier_gl_ratio ). ENDIF.
    IF cal_supplier_conn_seg_ratio IS BOUND. capture( dataset = 'CAL_SUPPLIER_CONN_SEG_RATIO' model = cal_supplier_conn_seg_ratio ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'ALLOC_ID_REV_SUPPLIER'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'SUPPLIER_ALLOC_RATIOS/NEW_DATA' ) )
        ( CONV string( 'SUPPLIER_ALLOC_RATIOS/SUPPLIER_RATIOS' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_alloc_id_rev_supplier( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF supplier_ratios IS BOUND. capture( dataset = 'SUPPLIER_RATIOS' model = supplier_ratios ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'PRICE_MATERIAL_LEVEL'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'ALLOC_ID_REV_SUPPLIER/NEW_DATA' ) )
        ( CONV string( 'FFLAS_GROUPING/INPUT_DATA' ) )
        ( CONV string( 'SUPPLIER_ALLOC_METHOD/SAP_REVENUES_CONSOL' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_price_material_level( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF input_data IS BOUND. capture( dataset = 'INPUT_DATA' model = input_data ). ENDIF.
    IF sap_revenues_consol IS BOUND. capture( dataset = 'SAP_REVENUES_CONSOL' model = sap_revenues_consol ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'HSNS_REV_ALLOC'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'PRICE_MATERIAL_LEVEL/NEW_DATA' ) )
        ( CONV string( 'PRICE_MATERIAL_LEVEL/INPUT_DATA' ) )
        ( CONV string( 'RSP_NOT_BILLED_LOCATION/SAP_REVENUES' ) )
        ( CONV string( 'SUPPLIER_ALLOC_RATIOS/CONN_REG_SPLIT' ) )
        ( CONV string( 'ALLOC_RSP_BILLED_DATA/L1_L2_MAPPING' ) )
        ( CONV string( 'ALLOC_RSP_BILLED_DATA/MAT_GROUP_MAPPING' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    calc_hsns_rev_alloc( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF input_data IS BOUND. capture( dataset = 'INPUT_DATA' model = input_data ). ENDIF.
    IF sap_revenues IS BOUND. capture( dataset = 'SAP_REVENUES' model = sap_revenues ). ENDIF.
    IF conn_reg_split IS BOUND. capture( dataset = 'CONN_REG_SPLIT' model = conn_reg_split ). ENDIF.
    IF l1_l2_mapping IS BOUND. capture( dataset = 'L1_L2_MAPPING' model = l1_l2_mapping ). ENDIF.
    IF mat_group_mapping IS BOUND. capture( dataset = 'MAT_GROUP_MAPPING' model = mat_group_mapping ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'FFLAS_RATIOS_BY_MATERIAL'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'HSNS_REV_ALLOC/NEW_DATA' ) )
        ( CONV string( 'HSNS_REV_ALLOC/SAP_REVENUES' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    new_data->append( calc_fflas_ratios_by_material( ) ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF sap_revenues IS BOUND. capture( dataset = 'SAP_REVENUES' model = sap_revenues ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'TRANSPOSE_REVENUES'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'FFLAS_RATIOS_BY_MATERIAL/NEW_DATA' ) )
        ( CONV string( 'HSNS_REV_ALLOC/INPUT_DATA' ) )
        ( CONV string( 'HSNS_REV_ALLOC/CONN_REG_SPLIT' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    transpose_revenues( ).
    capture( dataset = 'TRANSPOSED_REVENUES' model = transposed_revenues ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF input_data IS BOUND. capture( dataset = 'INPUT_DATA' model = input_data ). ENDIF.
    IF conn_reg_split IS BOUND. capture( dataset = 'CONN_REG_SPLIT' model = conn_reg_split ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'TRANSPOSE_PRICES'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'TRANSPOSE_REVENUES/NEW_DATA' ) )
        ( CONV string( 'TRANSPOSE_REVENUES/INPUT_DATA' ) )
        ( CONV string( 'TRANSPOSE_REVENUES/TRANSPOSED_REVENUES' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    transpose_prices( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF input_data IS BOUND. capture( dataset = 'INPUT_DATA' model = input_data ). ENDIF.
    IF transposed_revenues IS BOUND. capture( dataset = 'TRANSPOSED_REVENUES' model = transposed_revenues ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.

    active_step = 'TRANSPOSE_CONNECTIONS'.
    env->checkpoint( name = active_step state = 'running'
      inputs = VALUE #(
        ( CONV string( 'TRANSPOSE_PRICES/NEW_DATA' ) )
        ( CONV string( 'TRANSPOSE_PRICES/INPUT_DATA' ) )
        ( CONV string( 'TRANSPOSE_PRICES/TRANSPOSED_REVENUES' ) )
        ( CONV string( 'TRANSPOSE_REVENUES/CONN_REG_SPLIT' ) )
        ( CONV string( 'HSNS_REV_ALLOC/L1_L2_MAPPING' ) )
        ( CONV string( 'HSNS_REV_ALLOC/MAT_GROUP_MAPPING' ) ) ) ).
    if capture_enabled = abap_true.
      get run time field step_started.
    endif.
    transpose_connections( ).
    capture( dataset = 'NEW_DATA' model = new_data ).
    IF input_data IS BOUND. capture( dataset = 'INPUT_DATA' model = input_data ). ENDIF.
    IF transposed_revenues IS BOUND. capture( dataset = 'TRANSPOSED_REVENUES' model = transposed_revenues ). ENDIF.
    IF conn_reg_split IS BOUND. capture( dataset = 'CONN_REG_SPLIT' model = conn_reg_split ). ENDIF.
    IF l1_l2_mapping IS BOUND. capture( dataset = 'L1_L2_MAPPING' model = l1_l2_mapping ). ENDIF.
    IF mat_group_mapping IS BOUND. capture( dataset = 'MAT_GROUP_MAPPING' model = mat_group_mapping ). ENDIF.
    inspection-completed_step = active_step.
    env->checkpoint( name = active_step state = 'succeeded' ).
    if stop_after = active_step.
      return.
    endif.


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.

  method initialise.
 TRY.

    param = new #( it_param ).

    " Parse the BPC current view and resolve the Category and Time range for this run.
    data(cv_obj) = new zcl_bpc_current_view( current_view ).
    category = current_view[ dimension = 'CATEGORY' ]-member[ 1 ].
    time = cv_obj->get_dimmem_range( 'TIME' ).

    if param->get_value( 'DEBUG' ) = 'ON'.
      cl_ujk_logger=>log( |Selected Category: | ).
      cl_ujk_logger=>log( category ).
    endif.

    " Instantiate the BPC environment handle and its dependent dimension helpers.
    IF env IS NOT BOUND. RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = 'CONTEXT' detail = 'Use execute with a frozen context'. ENDIF.
    product_type_dim = NEW #( io = env name = 'PRODUCT_TYPE' ).
    mat_group_id_dim = NEW #( io = env name = 'MAT_GROUP_ID' ).
    matconn_dim = NEW #( io = env name = 'MATCONN' ).

    " Base DEMREVID data set (Time/Category filtered), used to derive the INPUT/OUTPUT/NEW views below.
    data(demrevid_data) =
      new zcl_bn_dem_model(
        environment = env
        filters = value #(
          ( dimension = 'TIME'     in = time )
          ( dimension = 'TIME'     low = 'TIME_NA' )
          ( dimension = 'CATEGORY' low = category )
    ) ).

    " Read data from BPC Models.
    input_data = demrevid_data->copy( value #( ( dimension = 'AUDITTRAIL' hier_name = 'PARENTH1' low = 'DEMREVID_INPUT' ) ) ).
    output_data = demrevid_data->copy( value #( ( dimension = 'AUDITTRAIL' hier_name = 'PARENTH1' low = 'DEMREVID_OUTPUT' ) ) ).
    new_data = new zcl_bn_dem_model( environment = env ).

    " Initialise objects used in calculation.
    " Load and pre-sort every reference data set required by the allocation/ratio methods below.
    sap_revenues =
        input_data->copy( value #(
            ( dimension = 'DEMREVID_KFS' hier_name = 'PARENTH1' low = kf_sap_revenues ) ) )->group(
                include_dimensions = abap_false
               group_by =  value #(  ( 'COSTCENTRE' ) ( 'DOC_TYP' ) ( 'AUDITTRAIL' )  ) )->replace(
                    dimension = 'AUDITTRAIL' replace_with = audit_dnrid_calc ).

    conn_reg_split =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_conn_region_mapping ) ) )->sort( value #(
                    (       'TIME' ) (           'ACCOUNT' ) ) ).

    l1_l2_mapping =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_l1_l2_mapping ) ) )->sort( value #(
                    (       'TIME' ) (           'ACCOUNT' ) ) ).

    mat_group_mapping =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_mat_group_mapping ) ) )->sort( value #(
                    (       'TIME' ) (           'MATCONN' ) ( 'ACCOUNT' ) ) ).

    rsp_location_material_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_rsp_loc_ratio_mat )
    ) )->sort( value #(
                     (      'TIME' ) (           'MATCONN' ) ) ).

    rsp_location_gl_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_rsp_loc_ratio_gl ) ) )->sort( value #(
                     (      'TIME' ) (           'ACCOUNT' ) ) ).

    cal_location_gl_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_cal_loc_ratio_gl ) ) )->sort( value #(
                    (       'TIME' ) (           'ACCOUNT' ) ) ).

    cal_location_conn_seg_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_cal_loc_ratio_conn_reg ) ) )->sort( value #(
                   (        'TIME' ) (           'CONN_REG_SPLIT' ) ) ).

    rsp_supplier_material_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_rsp_supplier_ratio_mat ) ) )->sort( value #(
                    (       'TIME' ) (           'ACCOUNT' ) ( 'MATCONN' ) ) ).

    rsp_supplier_gl_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_rsp_supplier_ratio_gl ) ) )->sort( value #(
                    (       'ACCOUNT' ) (        'TIME' ) ) ).

    cal_supplier_gl_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_cal_supplier_ratio_gl ) ) )->sort( value #(
                    (       'ACCOUNT' ) (        'TIME' ) ) ).

    cal_supplier_conn_seg_ratio =
            input_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' low = kf_cal_supplier_ratio_conn_reg ) ) )->sort( value #(
                    (       'CONN_REG_SPLIT' ) ( 'TIME' ) ) ).

    " Contains list of Material Groups that will have its FFLAS Ratio Calculation skipped.
    data(skip_fflas_ratio_mat_group) = param->get_dimmem_range( 'FFLASMATGROUPS' ).
    skip_fflas_ratio_mat_group_id = param->get_dimmem_range( 'FFLASMATGROUPSID').
    loop at skip_fflas_ratio_mat_group_id into data(_skip_fflas_ratio_mat_group_id).
      read table skip_fflas_ratio_mat_group into data(_skip_fflas_ratio_mat_group)
          index sy-tabix.
      if sy-subrc is not initial or _skip_fflas_ratio_mat_group-low eq 0.
        delete skip_fflas_ratio_mat_group_id.
      endif.
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method if_uj_custom_logic~init.
 TRY.


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.

  method get_rev_split_method.
 TRY.


    case ratio_type.
      when location.
        " If a ratio by material has been found in the RSP Billing data
        " then use it for the allocation.
        read table rsp_location_material_ratio->model_data
            transporting no fields
                with key time = _sap_revenue-time
                               matconn = _sap_revenue-matconn
                               binary search.
        if sy-subrc is initial.
          rev_split_index = rsp_billing_material.
          return.
        endif.

        " If a ratio by G/L has been found in the RSP Billing data
        " then use it for the allocation.
        read table rsp_location_gl_ratio->model_data
            transporting no fields
                with key time = _sap_revenue-time
                               account = _sap_revenue-account
                               binary search.
        if sy-subrc is initial.
          rev_split_index = rsp_billing_gl.
          return.
        endif.

        " If a ratio by G/L has been found in the CAL Data
        " then use it for the allocation.
        read table cal_location_gl_ratio->model_data
            transporting no fields
                with key time = _sap_revenue-time
                               account = _sap_revenue-account
                               binary search.
        if sy-subrc is initial.
          rev_split_index = cal_gl.
          return.
        endif.

        " If a ratio by G/L has been found in the CAL Data
        " then use it for the allocation.
        read table cal_location_conn_seg_ratio->model_data
            transporting no fields
                with key time = _sap_revenue-time
                               conn_reg_split = _sap_revenue-conn_reg_split
                               binary search.
        if sy-subrc is initial.
          rev_split_index = cal_reg_split.
          return.
        endif.
      when supplier.
        " If a ratio by material has been found in the RSP Billing data
        " then use it for the allocation.
        read table rsp_supplier_material_ratio->model_data
            transporting no fields
                with key time = _sap_revenue-time
                               account = _sap_revenue-account
                               matconn = _sap_revenue-matconn
                               binary search.
        if sy-subrc is initial.
          rev_split_index = rsp_billing_material.
          return.
        endif.

        " If a ratio by G/L has been found in the RSP Billing data
        " then use it for the allocation.
        read table rsp_supplier_gl_ratio->model_data
            transporting no fields
                with key time = _sap_revenue-time
                               account = _sap_revenue-account
                               binary search.
        if sy-subrc is initial.
          rev_split_index = rsp_billing_gl.
          return.
        endif.

        " If a ratio by G/L has been found in the CAL Data
        " then use it for the allocation.
        read table cal_supplier_gl_ratio->model_data
            transporting no fields
                with key time = _sap_revenue-time
                               account = _sap_revenue-account
                               binary search.
        if sy-subrc is initial.
          rev_split_index = cal_gl.
          return.
        endif.

        " If a ratio by G/L has been found in the CAL Data
        " then use it for the allocation.
        read table cal_supplier_conn_seg_ratio->model_data
            transporting no fields
                with key time = _sap_revenue-time
                               conn_reg_split = _sap_revenue-conn_reg_split
                               binary search.
        if sy-subrc is initial.
          rev_split_index = cal_reg_split.
          return.
        endif.
    endcase.

    " If not methodology is found,
    " then fallsback to NOT_FOUND.
    rev_split_index = not_found.


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_location_alloc_method.
 TRY.

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
      _new_data-signeddata = conv i( get_rev_split_method( ratio_type = location _sap_revenue = _new_data ) ).
      " Append the result to the calculation output.
      new_data->append( _new_data ).
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_location_alloc_ratios.
 TRY.

    rsp_split_ratios = new #( environment = env ).
    loop at new_data->model_data into data(_new_data)
        where demrevid_kfs eq kf_loc_split_index.
      _new_data-demrevid_kfs = kf_ratios_for_split.
      data(method_enum) = conv rev_split_method( conv i( _new_data-signeddata ) ).
      case method_enum.
        when rsp_billing_material.
          " Use the overwritten RSP Billing Ratio if available.
          read table rsp_location_material_ratio->model_data
            transporting no fields
                with key time = _new_data-time
                         matconn = _new_data-matconn
                         audittrail = 'DEMREVID_LOC_RATIO_OVERWRITE'.
          if sy-subrc is initial.
            loop at rsp_location_material_ratio->model_data into data(_rsp_billing_material_ratio)
                  where time eq _new_data-time and
                             matconn eq _new_data-matconn and
                             audittrail eq 'DEMREVID_LOC_RATIO_OVERWRITE'.
              _new_data-geo_drivers = _rsp_billing_material_ratio-geo_drivers.
              _new_data-signeddata = _rsp_billing_material_ratio-signeddata.
              rsp_split_ratios->append( _new_data ).
            endloop.
          else.
            loop at rsp_location_material_ratio->model_data into _rsp_billing_material_ratio
                    where time eq _new_data-time and
                               matconn eq _new_data-matconn and
                               audittrail eq 'DEMREVID_RSP_BILLING'.
              _new_data-geo_drivers = _rsp_billing_material_ratio-geo_drivers.
              _new_data-signeddata = _rsp_billing_material_ratio-signeddata.
              rsp_split_ratios->append( _new_data ).
            endloop.
          endif.
        when rsp_billing_gl.
          loop at rsp_location_gl_ratio->model_data into data(_rsp_billing_gl_ratio)
                where account eq _new_data-account and
                            time eq _new_data-time.
            _new_data-geo_drivers = _rsp_billing_gl_ratio-geo_drivers.
            _new_data-signeddata = _rsp_billing_gl_ratio-signeddata.
            rsp_split_ratios->append( _new_data ).
          endloop.
        when cal_gl.
          loop at cal_location_gl_ratio->model_data into data(_cal_gl_ratio)
                where account eq _new_data-account and
                            time eq _new_data-time.
            _new_data-geo_drivers = _cal_gl_ratio-geo_drivers.
            _new_data-signeddata = _cal_gl_ratio-signeddata.
            rsp_split_ratios->append( _new_data ).
          endloop.
        when cal_reg_split.
          loop at cal_location_conn_seg_ratio->model_data into data(_cal_conn_seg_ratio)
                where conn_reg_split eq _new_data-conn_reg_split and
                            time eq _new_data-time.
            _new_data-geo_drivers = _cal_conn_seg_ratio-geo_drivers.
            _new_data-signeddata = _cal_conn_seg_ratio-signeddata.
            rsp_split_ratios->append( _new_data ).
          endloop.
      endcase.
    endloop.
    new_data->append( rsp_split_ratios ).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_alloc_rsp_billed_data.
 TRY.

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

    assign_new_fields_rev( rsp_billing_with_split ).
    new_data->append( rsp_billing_with_split ).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_remaining_rsp_billing.
 TRY.

    data(rsp_billing_with_split) =
        new_data->copy( value #(
            ( dimension               = 'DEMREVID_KFS' low = kf_rsp_bill_with_loc ) ) )->group(
                include_dimensions = abap_false
                group_by = value #( ( 'GEO_DRIVERS' ) ) )->sort( value #(
                                    ( 'TIME' ) (           'ACCOUNT' ) ( 'MATCONN' ) ) ).

    loop at sap_revenues->model_data into data(_remaining_rev)
        where demrevid_kfs eq rsp_billing.
      read table rsp_billing_with_split->model_data
          into data(_rsp_billing_with_split)
              with key
                  time = _remaining_rev-time
                  account = _remaining_rev-account
                  matconn = _remaining_rev-matconn
                  binary search.
      if sy-subrc is initial.
        subtract _rsp_billing_with_split-signeddata from _remaining_rev-signeddata.
      endif.

      if _remaining_rev-signeddata is not initial.
        loop at rsp_split_ratios->model_data into data(_rsp_split_ratios)
            where matconn eq _remaining_rev-matconn and
                        account eq _remaining_rev-account and
                        time eq _remaining_rev-time.
          data(_new_data) = _remaining_rev.
          _new_data-demrevid_kfs = kf_rsp_bill_no_loc.
          _new_data-geo_drivers = _rsp_split_ratios-geo_drivers.
          multiply _new_data-signeddata by _rsp_split_ratios-signeddata.
          new_data->append( _new_data ).
        endloop.
      endif.
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_rsp_not_billed_location.
 TRY.

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

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_fflas_grouping.
 TRY.


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

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.





  method calc_pq_id_fflas_revenue.
 TRY.


    " Retrieve the Revenues (both RSP Billend and Accrual) allocated by Geographies (Location).
    " Also assign the FFLAS type depending on the Geography.
    data(rev_by_location) = new_data->copy( value #(
                ( dimension = 'DEMREVID_KFS' option       = 'BT'      low     = kf_rsp_bill_with_loc high = kf_rsp_not_billed_loc )
    ) )->replaces( value #(
                ( dimension = 'DEMREVID_KFS' replace_with = kf_fflas_revenue )
                ( dimension = 'FFLAS'        replace_with = fflas_pq filters = value #( ( dimension = 'GEO_DRIVERS' option = 'BT' low = geo_ronz high = geo_ufb ) ) )
                ( dimension = 'FFLAS'        replace_with = fflas_id filters = value #( ( dimension = 'GEO_DRIVERS' low    = geo_lfc ) ) )
    ) )->group( ).

    " Manual Input - FFLAS ratio by Material/Account.
    data(fflas_alloc_ratio) = new_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_fflas_monthly_pct ) ) )->sort( value #(
            (       'TIME' ) (           'ACCOUNT' ) ( 'MATCONN' ) ) ).

    " Apply FFLAS ratio in the Revenue allocated by Geography.
    data(rev_alloc_by_fflas) = rev_by_location->copy( )->multiply(
      multiply_data = fflas_alloc_ratio->model_data
      read_dimensions = value #( ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ) ).
    delete rev_alloc_by_fflas->model_data where signeddata is initial.

    " If revenues aren't fully allocated by the FFLAS ratio (i.e. the ratio < 100%),
    " the unallocated balance is assigned to Non-FFLAS. This is computed as:
    " balance = total revenue by location - sum of FFLAS-allocated revenue (per Time/Account/Matconn/Geo).
    data(alloc_by_geo) = rev_alloc_by_fflas->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( 'FFLAS' ) ) )->sort( value #(
            ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'GEO_DRIVERS' ) ) ).
    data(non_fflas_balance) = rev_by_location->copy( )->sort( value #(
            ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'GEO_DRIVERS' ) ) ).
    loop at non_fflas_balance->model_data assigning field-symbol(<_non_fflas>).
      read table alloc_by_geo->model_data into data(_alloc_row)
          with key time = <_non_fflas>-time
                   account = <_non_fflas>-account
                   matconn = <_non_fflas>-matconn
                   geo_drivers = <_non_fflas>-geo_drivers
                   binary search.
      if sy-subrc is initial.
        <_non_fflas>-signeddata = <_non_fflas>-signeddata - _alloc_row-signeddata.
      endif.
      <_non_fflas>-fflas = fflas_non.
    endloop.
    delete non_fflas_balance->model_data where signeddata is initial.

    " Build the result: allocated FFLAS revenue + non-FFLAS balance.
    result = rev_alloc_by_fflas.
    result->append( non_fflas_balance ).


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_pq_fflas_ratio.
 TRY.


    data(fflas_revenues) = new_data->copy( value #(
                  ( dimension = 'DEMREVID_KFS' low     = kf_fflas_revenue  )
      ) ).

    " Consolidate the FFLAS revenues - remove Geography and FFLAS to get total per Time/Account/Matconn.
    data(fflas_rev_consolidated) = fflas_revenues->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( 'GEO_DRIVERS' ) ( 'FFLAS' ) ) )->sort( value #(
                            ( 'TIME' )        ( 'ACCOUNT' ) ( 'MATCONN' ) ) ).

    " Filter to PQ FFLAS only and consolidate by Time/Account/Matconn.
    data(pq_fflas_rev) = fflas_revenues->copy( value #(
        ( dimension               = 'FFLAS' low = fflas_pq ) ) )->group(
            include_dimensions = abap_false
            group_by = value #( ( 'GEO_DRIVERS' ) ) )->sort( value #(
                                ( 'TIME' ) (    'ACCOUNT' ) ( 'MATCONN' ) ) ).

    " PQ FFLAS ratio = PQ FFLAS Revenue / Total Revenue (per Time/Account/Matconn).
    pq_fflas_rev->divide(
      divide_data     = fflas_rev_consolidated->model_data
      read_dimensions = value #(
          ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ) )->replace( dimension = 'DEMREVID_KFS' replace_with = kf_pq_fflas_pct ).

    result = pq_fflas_rev.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method assign_new_fields_rev.
 TRY.


    data(mat_remapping) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = mat_remapping ) ) )->sort( value #(
            ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ) )->model_data.

    data(reg_fflas_service) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_reg_fflas_serv_mapping ) ) )->sort( value #(
            (       'TIME' ) (           'MATCONN' ) ( 'MAT_GROUP_ID' ) ) )->model_data.

    data(prod_type_overwrite) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_prod_type_mapping ) ) )->sort( value #(
            (       'TIME' ) (           'MATCONN' ) ) )->model_data.

    data(prod_type_dim) = NEW zcl_bn_dimension( io = env name = 'PRODUCT_TYPE' ).

    loop at model_ref->model_data assigning field-symbol(<_model_ref>).

      read table prod_type_overwrite into data(_prod_type_overwrite)
          with key time = <_model_ref>-time
                       matconn = <_model_ref>-matconn
                       binary search.
      if sy-subrc is initial.
        <_model_ref>-product_type =
            cond #(
                when prod_type_dim->get_member_by_index( _prod_type_overwrite-signeddata ) is not initial then prod_type_dim->get_member_by_index( _prod_type_overwrite-signeddata )
                    else _prod_type_overwrite-product_type ) .
      endif.

      <_model_ref>-rev_id_group = prod_type_dim->get_member( <_model_ref>-product_type )-rev_id_group.

      read table conn_reg_split->model_data
          into data(_conn_reg_split) with key
            time = <_model_ref>-time
            account = <_model_ref>-account
                binary search.
      if sy-subrc is initial.
        <_model_ref>-conn_reg_split = _conn_reg_split-conn_reg_split.
      endif.

      read table l1_l2_mapping->model_data
          into data(_l1_l2_mapping) with key
            time = <_model_ref>-time
            account = <_model_ref>-account
                binary search.
      if sy-subrc is initial.
        <_model_ref>-fflas_subset = _l1_l2_mapping-fflas_subset.
      endif.

      read table mat_remapping
          into data(_mat_remapping) with key
            time = <_model_ref>-time
            account = <_model_ref>-account
            matconn = <_model_ref>-matconn
                binary search.
      if sy-subrc is initial.
        <_model_ref>-matremap = _mat_remapping-matremap.
      else.
        read table mat_remapping
           into _mat_remapping with key
             time = <_model_ref>-time
             account = 'ACCOUNT_NA'
             matconn = <_model_ref>-matconn
                 binary search.
        if sy-subrc is initial.
          <_model_ref>-matremap = _mat_remapping-matremap.
        else.
          <_model_ref>-matremap = cond #(
              when <_model_ref>-matconn eq 'MATCONN_NA' then 'MATREMAP_NA'
                  else <_model_ref>-matconn ).
        endif.
      endif.

      if <_model_ref>-product_type eq 'PRODUCT_TYPE_NA' and
            <_model_ref>-matremap ne 'MATREMAP_NA'.
        <_model_ref>-product_type = matconn_dim->get_member( <_model_ref>-matremap )-product_type.
      endif.

      if <_model_ref>-matremap ne 'MATREMAP_NA'.
        " Look for the Material Group  using the Remapped material.
        " If nothing is found, then look for the Mat. Group by Account.
        read table mat_group_mapping->model_data
          into data(_mat_group_mapping)
              with key time = <_model_ref>-time
                          matconn = <_model_ref>-matremap
                          account = 'ACCOUNT_NA'
                          binary search.
        if sy-subrc is initial.
          <_model_ref>-mat_group_id = _mat_group_mapping-mat_group_id.
        endif.
      else.
        read table mat_group_mapping->model_data
              into _mat_group_mapping
                  with key time = <_model_ref>-time
                              matconn = 'MATCONN_NA'
                              account = <_model_ref>-account
                              binary search.
        if sy-subrc is initial.
          <_model_ref>-mat_group_id = _mat_group_mapping-mat_group_id.
        endif.
      endif.

      " If the property REV_ID_GROUP of dimension
      " MAT_GROUP_ID is not blank, then use it instead of the overwrite from
      " the previous step.
      <_model_ref>-rev_id_group = cond #(
        when mat_group_id_dim->get_member( <_model_ref>-mat_group_id )-rev_id_group is initial
            then <_model_ref>-rev_id_group
                else mat_group_id_dim->get_member( <_model_ref>-mat_group_id )-rev_id_group ).

      " Search for the Reg. FFLAS Service level using the Material Group.
      read table reg_fflas_service
          into data(_reg_fflas_service) with key
            time = <_model_ref>-time
            matconn = 'MATCONN_NA'
            mat_group_id = <_model_ref>-mat_group_id
                binary search.
      if sy-subrc is initial.
        <_model_ref>-reg_fflas_serv = _reg_fflas_service-reg_fflas_serv.
      else.

        " If it can't be found by material, then user the Remapped Material.
        read table reg_fflas_service
            into _reg_fflas_service  with key
              time = <_model_ref>-time
              matconn = <_model_ref>-matremap
                  binary search.
        if sy-subrc is initial.
          <_model_ref>-reg_fflas_serv = _reg_fflas_service-reg_fflas_serv.
        endif.
      endif.
    endloop.


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_supplier_alloc_method.
 TRY.

    loop at sap_revenues_consol->model_data into data(_sap_revenue).
      data(_new_data) = _sap_revenue.
      _new_data-demrevid_kfs = kf_supplier_split_index.
      _new_data-signeddata = conv i( get_rev_split_method( ratio_type = supplier _sap_revenue = _new_data ) ).
      new_data->append( _new_data ).
    endloop.

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_supplier_alloc_ratios.
 TRY.

    supplier_ratios = new zcl_bn_dem_model( environment = env ).
    loop at new_data->model_data into data(_supplier_split_method)
        where demrevid_kfs eq kf_supplier_split_index.
      _supplier_split_method-demrevid_kfs = kf_supplier_split_ratio.
      data(method_enum) = conv rev_split_method( conv i( _supplier_split_method-signeddata ) ).
      case method_enum.
        when rsp_billing_material.
          loop at rsp_supplier_material_ratio->model_data into data(_rsp_supplier_material_ratio)
                where time eq _supplier_split_method-time and
                            account eq _supplier_split_method-account and
                            matconn eq _supplier_split_method-matconn.
            _supplier_split_method-lfc_win_supplier = _rsp_supplier_material_ratio-lfc_win_supplier.
            _supplier_split_method-signeddata = _rsp_supplier_material_ratio-signeddata.
            supplier_ratios->append( _supplier_split_method ).
          endloop.
        when rsp_billing_gl.
          loop at rsp_supplier_gl_ratio->model_data into data(_rsp_supplier_gl_ratio)
                where account eq _supplier_split_method-account and
                            time eq _supplier_split_method-time.
            _supplier_split_method-lfc_win_supplier = _rsp_supplier_gl_ratio-lfc_win_supplier.
            _supplier_split_method-signeddata = _rsp_supplier_gl_ratio-signeddata.
            supplier_ratios->append( _supplier_split_method ).
          endloop.
        when cal_gl.
          loop at cal_supplier_gl_ratio->model_data into data(_cal_supplier_gl_ratio)
                where account eq _supplier_split_method-account and
                            time eq _supplier_split_method-time.
            _supplier_split_method-lfc_win_supplier = _cal_supplier_gl_ratio-lfc_win_supplier.
            _supplier_split_method-signeddata = _cal_supplier_gl_ratio-signeddata.
            supplier_ratios->append( _supplier_split_method ).
          endloop.
        when cal_reg_split.
          loop at cal_supplier_conn_seg_ratio->model_data into data(_cal_supplier_conn_seg_ratio)
                where conn_reg_split eq _supplier_split_method-conn_reg_split and
                            time eq _supplier_split_method-time.
            _supplier_split_method-lfc_win_supplier = _cal_supplier_conn_seg_ratio-lfc_win_supplier.
            _supplier_split_method-signeddata = _cal_supplier_conn_seg_ratio-signeddata.
            supplier_ratios->append( _supplier_split_method ).
          endloop.
      endcase.
    endloop.
    supplier_ratios->sort( value #( ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ) ).
    new_data->append( supplier_ratios ).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_alloc_id_rev_supplier.
 TRY.

    data id_fflas_by_supplier like new_data->model_data.
    loop at new_data->model_data into data(_id_only_rev)
        where demrevid_kfs eq kf_fflas_revenue and
                  fflas eq fflas_id.
      read table supplier_ratios->model_data transporting no fields
          with key time = _id_only_rev-time
                       account = _id_only_rev-account
                       matconn = _id_only_rev-matconn
                       binary search.
      if sy-subrc is not initial.
        continue.
      endif.

      delete new_data->model_data.
      loop at supplier_ratios->model_data into data(_supplier_ratios)
        where time eq _id_only_rev-time and
                   account eq _id_only_rev-account and
                   matconn eq _id_only_rev-matconn.
        data(_new_data) = _id_only_rev.
        _new_data-signeddata = _id_only_rev-signeddata * _supplier_ratios-signeddata.
        _new_data-lfc_win_supplier = _supplier_ratios-lfc_win_supplier.
        append _new_data to id_fflas_by_supplier.
      endloop.
    endloop.

    new_data->append( id_fflas_by_supplier ).

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_price_material_level.
 TRY.

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

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method transpose_revenues.
 TRY.


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


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.



  method calc_hsns_rev_alloc.
 TRY.


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
    assign_new_fields_rev( hsns_premium_rsp_bill ).
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

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method transpose_connections.
 TRY.

    " CAL connections for current period.
    data(current_period_conn) = input_data->copy( value #(
        ( dimension = 'DEMREVID_KFS' low = kf_monthly_cal_conn )
        " Bandwidth connections won't be considered.
        ( dimension = 'PRODUCT_TYPE'  sign = 'E' low = bandwidth  ) ) )->replace(
                dimension  = 'LFC_WIN_SUPPLIER'
                replace_with = 'LFC_WIN_SUPPLIER_NA'
                filters = value #( ( dimension = 'FFLAS' low = fflas_pq ) ) )->group( ).
    check current_period_conn->model_data is not initial.

    assign_new_fields_rev( current_period_conn ).

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
    data(prior_period_conn) = new zcl_bn_dem_model(
        environment = env
        filters = value #(
            ( dimension = 'DEMREVID_KFS' low = kf_monthly_cal_conn )
            ( dimension = 'TIME' low = prior_period )
            ( dimension = 'CATEGORY' low = category )
            ( dimension = 'PRODUCT_TYPE'  sign = 'E' low = bandwidth  )
                ) )->offset_time( offset_by = 1 )->replace(
                dimension  = 'LFC_WIN_SUPPLIER'
                replace_with = 'LFC_WIN_SUPPLIER_NA'
                filters = value #( ( dimension = 'FFLAS' low = fflas_pq ) ) )->group( ).

    assign_new_fields_rev( prior_period_conn ).
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
    data(prior_closing_bal) = new zcl_bn_dem_model(
        environment = env
        filters = value #(
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

    data(add_conn_prior_per) = new zcl_bn_dem_model(
        environment = env
        filters = value #(
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


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method transpose_prices.
 TRY.

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

 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.


  method calc_fflas_ratios_by_material.
 TRY.


    fflas_ratios = new zcl_bn_dem_model( environment = env ).

    " 1. Base revenue = total SAP Actuals grouped by Category/Time/Account/Matconn, re-tagged
    "    with the audittrail used by this calculation and the FFLAS-ratio-by-Material key figure.
    data(base_revenues) = sap_revenues->copy( )->group( value #(
        ( 'CATEGORY' ) ( 'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'MAT_GROUP_ID' ) ) )->replaces( value #(
            ( dimension = 'AUDITTRAIL' replace_with = audit_dnrid_calc )
            ( dimension = 'DEMREVID_KFS' replace_with = kf_fflas_ratios_material ) )
                 ).
    capture( dataset = 'RATIO_BASE_BEFORE_EXCLUSIONS' model = base_revenues ).
    " 2. Exclude Material Groups flagged to skip the FFLAS ratio calculation (parameter FFLASMATGROUPSID).
    "    Before excluding them, keep one flag record per Time/Account/Matconn so DEMREV knows these
    "    materials were skipped and can post their fallback allocation separately (SSNG-3218).
    data(skipped_materials) = new zcl_bn_dem_model( environment = env ).
    if lines( skip_fflas_ratio_mat_group_id ) <> 0.
      loop at base_revenues->model_data into data(_skipped_material)
          where mat_group_id in skip_fflas_ratio_mat_group_id.
        clear _skipped_material-mat_group_id.
        _skipped_material-demrevid_kfs = kf_fflas_ratio_skipped.
        _skipped_material-fflas = fflas_na.
        _skipped_material-signeddata = 1.
        " One flag per Time/Account/Matconn, even if it has several revenue rows.
        if not line_exists( skipped_materials->model_data[
                              time    = _skipped_material-time
                              account = _skipped_material-account
                              matconn = _skipped_material-matconn ] ).
          skipped_materials->append( _skipped_material ).
        endif.
      endloop.

      delete base_revenues->model_data where mat_group_id in skip_fflas_ratio_mat_group_id.
    endif.
    capture( dataset = 'SKIPPED_MATERIAL_FLAGS' model = skipped_materials ).
    capture( dataset = 'RATIO_BASE_AFTER_EXCLUSIONS' model = base_revenues ).
    " No need of Mat. Group anymore.
    base_revenues->group( include_dimensions = abap_false group_by = value #( ( 'MAT_GROUP_ID' ) ) ).

    " 3. FFLAS revenue = Allocated Revenues (DEMREVID023) grouped by the same key plus FFLAS and
    "    MAT_GROUP_ID, so the share of the base revenue attributable to each FFLAS value can be computed.
    data(fflas_rev) = new_data->copy( value #(
            ( dimension = 'DEMREVID_KFS' low = kf_fflas_revenue ) ) )->group( value #(
               (        'CATEGORY' ) (       'TIME' ) ( 'ACCOUNT' ) ( 'MATCONN' ) ( 'FFLAS' ) ( 'MAT_GROUP_ID' ) ) )->replaces( value #(
            ( dimension = 'AUDITTRAIL' replace_with = audit_dnrid_calc )
            ( dimension = 'DEMREVID_KFS' replace_with = kf_fflas_ratios_material ) ) ).
    capture( dataset = 'FFLAS_REVENUE_NUMERATORS' model = fflas_rev ).
    " 4. For each base revenue record with a non-zero amount, compute the ratio of every matching
    "    FFLAS revenue record to the base amount, and keep a running remainder (non_fflas_rev).
    loop at base_revenues->model_data into data(_base_rev)
        where signeddata is not initial.
      data(non_fflas_rev) = _base_rev-signeddata.
      loop at fflas_rev->model_data into data(_fflas_rev)
        where time eq _base_rev-time and
                   account eq _base_rev-account and
                   matconn eq _base_rev-matconn.
        " Track how much of the base revenue is still unaccounted for by an explicit FFLAS ratio.
        subtract _fflas_rev-signeddata from non_fflas_rev.
        " Ratio for this FFLAS value = FFLAS revenue / total (base) revenue.
        _fflas_rev-signeddata =  _fflas_rev-signeddata / _base_rev-signeddata.
        fflas_ratios->append( _fflas_rev ).
      endloop.
      " 5. Whatever remains unaccounted-for is booked to the synthetic Non-FFLAS ratio (FFLASNON),
      "    ensuring the FFLAS ratios for this Time/Account/Matconn always sum to 1.
      if non_fflas_rev is not initial.
        _base_rev-signeddata =  non_fflas_rev / _base_rev-signeddata.
        _base_rev-fflas = fflas_non.
        fflas_ratios->collect( _base_rev ).
      endif.
    endloop.

    capture( dataset = 'RATIOS_BEFORE_ROUNDING' model = fflas_ratios ).
    " 6. Rounding correction: due to floating-point precision in get_ratio / division,
    "    the sum of ratios for a given Time/Account/Matconn may not be exactly 1.
    "    For each combination where the total differs from 1, the discrepancy is added
    "    to the first ratio row found (via binary search). This avoids incorrectly
    "    creating or inflating a FFLASNON row when one doesn't logically belong.
    data(fflas_ratios_cons) = fflas_ratios->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( 'FFLAS' ) ( 'MAT_GROUP_ID' ) ) )->filter( value #(
            ( dimension = 'SIGNEDDATA' option = 'NE' low = 1 ) ) ).
    sort fflas_ratios->model_data by time account matconn.
    loop at fflas_ratios_cons->model_data into data(_fflas_ratios_cons).
      read table fflas_ratios->model_data assigning field-symbol(<_fflas_ratios>)
          with key time = _fflas_ratios_cons-time
                   account = _fflas_ratios_cons-account
                   matconn = _fflas_ratios_cons-matconn
                   binary search.
      if sy-subrc is initial.
        data(balance_ratio) = conv uj_signeddata( 1 - _fflas_ratios_cons-signeddata ).
        add balance_ratio to <_fflas_ratios>-signeddata.
      endif.
    endloop.

    " 7. Add the skipped-material flags (step 2) after the rounding correction, so they are not
    "    mixed into the ratio balancing above.
    fflas_ratios->append( skipped_materials ).
    capture( dataset = 'RATIOS_AND_FLAGS' model = fflas_ratios ).


 CATCH zcx_bn INTO DATA(notebook_error).
 RAISE EXCEPTION TYPE zcx_bn_engine EXPORTING code = notebook_error->code detail = notebook_error->detail.
 ENDTRY.
  endmethod.









endclass.

