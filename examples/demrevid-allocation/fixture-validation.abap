" Nonposting fixture; real member IDs are validated against SAP authorization.
DATA(seed_adapter) = NEW zcl_bn_bpc( environment = CONV string( io->environment ) model = CONV string( io->model ) ).
DATA(seed_ref) = seed_adapter->read_data( filters = VALUE #(
 ( dimension = 'CATEGORY' members = VALUE #( ( CONV string( 'Actual' ) ) ) )
 ( dimension = 'TIME' members = VALUE #( ( CONV string( '2027.006' ) ) ) ) ) max_rows = 10000 ).
FIELD-SYMBOLS <seed> TYPE STANDARD TABLE. ASSIGN seed_ref->* TO <seed>.
IF <seed> IS INITIAL. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_SEED' detail = 'Authorized native metadata seed unavailable'. ENDIF.
READ TABLE <seed> ASSIGNING FIELD-SYMBOL(<seed_row>) INDEX 1.
DATA(base) = CORRESPONDING zcl_bn_dem_model=>struct( <seed_row> ).
base-category = io->member( 'CATEGORY' ).
DATA(periods) = io->range( 'TIME' ).
IF lines( periods ) <> 1. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_PERIOD' detail = 'Select one output period for this fixture'. ENDIF.
base-time = periods[ 1 ]. base-product_type = 'PRODUCT_TYPE_001'.
base-mat_group_id = 'MATGROUPID038'. base-fflas = 'FFLAS_NA'.
base-fflas_subset = 'FFLASSUB001'. base-lfc_win_supplier = 'LFCWIN001'.
base-audittrail = 'DEMREVID_SAP'. base-demrevid_kfs = 'DEMREVID006'. base-signeddata = '100.0000001'.
DATA fixtures TYPE zcl_bn_dem_model=>tabl. APPEND base TO fixtures.
DATA(row) = base. row-demrevid_kfs = 'DEMREVID007'. row-signeddata = '-10'. APPEND row TO fixtures.
row = base. row-audittrail = 'DEMREVID_RSP_BILLING'. row-demrevid_kfs = 'DEMREVID010'.
row-geo_drivers = 'GDRVS_002'. row-signeddata = '0.3333333'. APPEND row TO fixtures.
row-geo_drivers = 'GDRVS_003'. row-signeddata = '0.6666667'. APPEND row TO fixtures.
row = base. row-audittrail = 'DEMREVID_RSP_BILLING'. row-demrevid_kfs = 'DEMREVID005'.
row-geo_drivers = 'GDRVS_002'. row-signeddata = 20. APPEND row TO fixtures.
row = base. row-audittrail = 'DEMREVID_MANUAL'. row-demrevid_kfs = 'DEMREVID029'.
row-lfc_win_supplier = 'LFCWIN001'. row-signeddata = '0.3333333'. APPEND row TO fixtures.
row-lfc_win_supplier = 'LFCWIN002'. row-signeddata = '0.6666667'. APPEND row TO fixtures.
row = base. row-audittrail = 'DEMREVID_MAT_FFLAS_MAPPING'. row-demrevid_kfs = 'DEMREVID021'. row-account = 'ACCOUNT_NA'. row-fflas = 'FFLASPQ'. row-signeddata = 1. APPEND row TO fixtures.
row = base. row-audittrail = 'DEMREVID_MAT_MONTH_FFLAS'. row-demrevid_kfs = 'DEMREVID022'. row-account = 'ACCOUNT_NA'. row-fflas = 'FFLASPQ'. row-signeddata = '0.6666667'. APPEND row TO fixtures.
row-fflas = 'FFLASID'. row-signeddata = '0.3333333'. APPEND row TO fixtures.
row = base. row-audittrail = 'DEMREVID_CALC'. row-demrevid_kfs = 'DEMREVID047'. row-fflas = 'FFLASNON'. row-signeddata = '0.5'. APPEND row TO fixtures.
DATA(scenario) = io->input( 'FIXTURE_CASE' ).
CASE scenario.
 WHEN 'carry'.
  row = base. row-audittrail = 'DEMREVID_MONTH_CAL_CONN'. row-demrevid_kfs = 'DEMREVID039'. row-fflas = 'FFLASPQ'. row-signeddata = 12. APPEND row TO fixtures.
  row-time = io->offset_period( member = base-time offset_by = -1 ). row-signeddata = 8. APPEND row TO fixtures.
  row-audittrail = 'DEMREVID_CALC'. row-demrevid_kfs = 'DEMREVID041'. row-signeddata = 7. APPEND row TO fixtures.
 WHEN 'fallback'.
  DELETE fixtures WHERE demrevid_kfs = 'DEMREVID010' OR demrevid_kfs = 'DEMREVID029'.
  row = base. row-audittrail = 'DEMREVID_MANUAL'. row-demrevid_kfs = 'DEMREVID012'. row-geo_drivers = 'GDRVS_002'. row-signeddata = 1. APPEND row TO fixtures.
  row = base. row-audittrail = 'DEMREVID_MANUAL'. row-demrevid_kfs = 'DEMREVID030'. row-signeddata = 1. APPEND row TO fixtures.
 WHEN 'rounding'.
  LOOP AT fixtures ASSIGNING FIELD-SYMBOL(<fixture>).
   CASE <fixture>-demrevid_kfs. WHEN 'DEMREVID006'. <fixture>-signeddata = 3. WHEN 'DEMREVID007'. <fixture>-signeddata = 1. ENDCASE.
  ENDLOOP.
 WHEN 'negative'.
  LOOP AT fixtures ASSIGNING <fixture> WHERE demrevid_kfs = 'DEMREVID006' OR demrevid_kfs = 'DEMREVID007'.
   <fixture>-signeddata = - <fixture>-signeddata.
  ENDLOOP.
 WHEN 'hsns'.
  LOOP AT fixtures ASSIGNING <fixture> WHERE demrevid_kfs <> 'DEMREVID021' AND demrevid_kfs <> 'DEMREVID022'.
   <fixture>-account = '001054200'.
  ENDLOOP.
  row = base. row-account = '001054200'. row-audittrail = 'DEMREVID_HSNS_PREM_REV'. row-demrevid_kfs = 'DEMREVID045'.
  row-fflas = 'FFLASID'. row-lfc_win_supplier = 'LFCWIN003'. row-signeddata = 60. APPEND row TO fixtures.
  row-fflas = 'FFLASPQ'. row-lfc_win_supplier = 'LFC_WIN_SUPPLIER_NA'. row-signeddata = 40. APPEND row TO fixtures.
  row-product_type = 'PRODUCT_TYPE_004'. row-signeddata = 10. APPEND row TO fixtures.
 WHEN 'standard'.
 WHEN OTHERS. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_CASE' detail = 'Use standard, carry, fallback, rounding, negative or hsns'.
ENDCASE.
DATA fixture_ref TYPE REF TO data. GET REFERENCE OF fixtures INTO fixture_ref.
io->enable_fixtures( VALUE #( ( environment = io->environment model = io->model rows = fixture_ref ) ) ).
zcl_bn_dem_validation=>execute( io ).
