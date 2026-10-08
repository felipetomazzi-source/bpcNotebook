TYPES: BEGIN OF ty_step,
         step_id TYPE string, method_name TYPE string, status TYPE string,
       END OF ty_step.
DATA steps TYPE STANDARD TABLE OF ty_step WITH DEFAULT KEY.
APPEND VALUE #( step_id = 'INITIALISE' method_name = 'initialise' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'ENRICH_REVENUES' method_name = 'assign_new_fields_rev' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'CONSOLIDATE' method_name = 'group' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'LOCATION_ALLOC_METHOD' method_name = 'calc_location_alloc_method' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'LOCATION_ALLOC_RATIOS' method_name = 'calc_location_alloc_ratios' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'ALLOC_RSP_BILLED_DATA' method_name = 'calc_alloc_rsp_billed_data' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'REMAINING_RSP_BILLING' method_name = 'calc_remaining_rsp_billing' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'RSP_NOT_BILLED_LOCATION' method_name = 'calc_rsp_not_billed_location' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'FFLAS_GROUPING' method_name = 'calc_fflas_grouping' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'PQ_ID_FFLAS_REVENUE' method_name = 'calc_pq_id_fflas_revenue' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'PQ_FFLAS_RATIO' method_name = 'calc_pq_fflas_ratio' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'SUPPLIER_ALLOC_METHOD' method_name = 'calc_supplier_alloc_method' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'SUPPLIER_ALLOC_RATIOS' method_name = 'calc_supplier_alloc_ratios' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'ALLOC_ID_REV_SUPPLIER' method_name = 'calc_alloc_id_rev_supplier' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'PRICE_MATERIAL_LEVEL' method_name = 'calc_price_material_level' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'HSNS_REV_ALLOC' method_name = 'calc_hsns_rev_alloc' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'FFLAS_RATIOS_BY_MATERIAL' method_name = 'calc_fflas_ratios_by_material' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'TRANSPOSE_REVENUES' method_name = 'transpose_revenues' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'TRANSPOSE_PRICES' method_name = 'transpose_prices' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
APPEND VALUE #( step_id = 'TRANSPOSE_CONNECTIONS' method_name = 'transpose_connections' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.
io->emit_table( name = 'CONVERSION_STATUS' rows = steps ).
DATA(counts) = io->read( 'selected_facts' ).
io->emit( counts ).
io->message( 'No allocation output: grouped transformations and lookback contract still require conversion' ).