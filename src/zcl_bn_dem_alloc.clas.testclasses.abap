*&---------------------------------------------------------------------*
*& ABAP Unit test classes for zcl_bn_dem_alloc
*&---------------------------------------------------------------------*
*& WHERE THIS GOES:
*&  This is NOT part of the class's Definition/Implementation source.
*&  In SE24/SE80 it is a separate include reached via
*&      Goto > Local Definitions/Test Classes  (or the "Test Classes" tab).
*&  In ADT (Eclipse) it is the "Test Classes" tab of the class editor.
*&  Pasting this there does not change the class's production code at all -
*&  it lives in its own include and is only active for ABAP Unit runs.
*&
*& HOW TO RUN:
*&  ADT       : place cursor in the class, press Ctrl+Shift+F10
*&              (or Run As > ABAP Unit Test).
*&  SE24/SE80 : the flask/"Test" toolbar button, or
*&              Program/Class menu > Test > Unit Test (Ctrl+Shift+F10 there too).
*&  Either way, the framework finds every "FOR TESTING" method in every
*&  "FOR TESTING" class in the program and reports pass/fail per method.
*&---------------------------------------------------------------------*


*&---------------------------------------------------------------------*
*& LOCAL FRIENDS
*&---------------------------------------------------------------------*
* zcl_bn_dem_alloc is FINAL and every calculation method is
* PRIVATE, which is correct for production code but means a normal
* "outside" test class could not call CALC_FFLAS_RATIOS_BY_MATERIAL or
* set SAP_REVENUES/NEW_DATA directly. Declaring the test class a
* "local friend" grants it that white-box access WITHOUT changing the
* visibility of anything in the production class - the statement below
* only has effect inside this test include.
* LTC_FFLAS_RATIO_TEST is only fully defined further down in this same
* include, but LOCAL FRIENDS below needs to reference it now - so ABAP
* requires a forward declaration first.
class ltc_fflas_ratio_test definition deferred.
class ltc_pq_id_fflas_revenue_test definition deferred.
class ltc_pq_fflas_ratio_test definition deferred.
class zcl_bn_dem_alloc definition local friends
    ltc_fflas_ratio_test
    ltc_pq_id_fflas_revenue_test
    ltc_pq_fflas_ratio_test.


*&---------------------------------------------------------------------*
*& Test class for CALC_FFLAS_RATIOS_BY_MATERIAL
*&---------------------------------------------------------------------*
* Why this method, and not the others: CALC_FFLAS_RATIOS_BY_MATERIAL is
* one of the few methods in this class whose logic does not depend on a
* live BPC connection. It only reads/writes SAP_REVENUES, NEW_DATA and
* SKIP_FFLAS_RATIO_MAT_GROUP_ID - three private attributes we can set
* directly with fabricated data because zcl_bn_dem_model's constructor
* accepts a MODEL_DATA table straight into memory (see its CONSTRUCTOR:
* if MODEL_DATA is passed, it just calls SET_DATA - it does not go near
* the database or the BPC environment unless FILTERS is passed without
* MODEL_DATA). That makes it possible to test this method in complete
* isolation, with DURATION SHORT / RISK LEVEL HARMLESS.
*
* These are nonempty in-memory business tests. Full allocation equivalence
* still requires representative authorized facts and a comparison with the
* original calculation. The port uses the generic notebook context.
class ltc_fflas_ratio_test definition for testing
  duration short
  risk level harmless.

  private section.
    data cut type ref to zcl_bn_dem_alloc.  "class under test

    methods setup.

    methods ratio_and_remainder_sum_to_1  for testing.
    methods single_fflas_covers_all_rev   for testing.
    methods zero_revenue_row_is_ignored   for testing.
    methods material_group_skip_list      for testing.
    methods skipped_material_is_flagged   for testing.
    methods no_matching_fflas_breakdown   for testing.
    methods rounding_existing_row for testing.
    methods suppression_disabled for testing.

endclass.


class ltc_fflas_ratio_test implementation.

  method setup.
    " No importing parameters needed - the class has no explicit
    " constructor, so this just gives every test a fresh instance with
    " every attribute initial. No BPC connection is opened.
    create object cut.
    cut->env = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'unit' ).
  endmethod.


  method rounding_existing_row.
    cut->capture_enabled = abap_true. cut->capture_limit = 100. cut->active_step = 'TEST'.
    cut->sap_revenues = NEW zcl_bn_dem_model( environment = cut->env model_data = VALUE zcl_bn_dem_model=>tabl(
      ( time = 'FISCAL_A' account = 'ACC' matconn = 'MAT' signeddata = 3 ) ) ).
    cut->new_data = NEW zcl_bn_dem_model( environment = cut->env model_data = VALUE zcl_bn_dem_model=>tabl(
      ( time = 'FISCAL_A' account = 'ACC' matconn = 'MAT' fflas = 'A' demrevid_kfs = 'DEMREVID023' signeddata = 1 )
      ( time = 'FISCAL_A' account = 'ACC' matconn = 'MAT' fflas = 'B' demrevid_kfs = 'DEMREVID023' signeddata = 1 )
      ( time = 'FISCAL_A' account = 'ACC' matconn = 'MAT' fflas = 'C' demrevid_kfs = 'DEMREVID023' signeddata = 1 ) ) ).
    DATA(result) = cut->calc_fflas_ratios_by_material( ).
    cl_abap_unit_assert=>assert_equals( act = lines( result->model_data ) exp = 3 ).
    DATA(one_third) = CONV uj_signeddata( 1 / 3 ).
    DATA(corrected) = CONV uj_signeddata( 1 - 2 * one_third ).
    cl_abap_unit_assert=>assert_equals( act = result->model_data[ fflas = 'A' ]-signeddata exp = corrected ).
    cl_abap_unit_assert=>assert_equals( act = result->model_data[ fflas = 'B' ]-signeddata exp = one_third ).
    cl_abap_unit_assert=>assert_equals( act = result->model_data[ fflas = 'C' ]-signeddata exp = one_third ).
    DATA(before) = cut->env->tables[ name = 'TEST/RATIOS_BEFORE_ROUNDING' ].
    cl_abap_unit_assert=>assert_equals( act = before-total_count exp = 3 ).
  endmethod.
  method suppression_disabled.
    CLEAR cut->skip_fflas_ratio_mat_group_id.
    cut->sap_revenues = NEW zcl_bn_dem_model( environment = cut->env model_data = VALUE zcl_bn_dem_model=>tabl(
      ( time = 'FISCAL_A' account = 'ACC' matconn = 'MAT' mat_group_id = 'MG_SKIP' signeddata = 10 ) ) ).
    cut->new_data = NEW zcl_bn_dem_model( environment = cut->env model_data = VALUE zcl_bn_dem_model=>tabl(
      ( time = 'FISCAL_A' account = 'ACC' matconn = 'MAT' mat_group_id = 'MG_SKIP'
        fflas = 'FFLASPQ' demrevid_kfs = 'DEMREVID023' signeddata = 10 ) ) ).
    DATA(result) = cut->calc_fflas_ratios_by_material( ).
    cl_abap_unit_assert=>assert_equals( act = lines( result->model_data ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result->model_data[ 1 ]-demrevid_kfs exp = 'DEMREVID047' ).
    cl_abap_unit_assert=>assert_equals( act = result->model_data[ 1 ]-signeddata exp = CONV uj_signeddata( 1 ) ).
  endmethod.
  method ratio_and_remainder_sum_to_1.
    " Given: SAP revenue of 100 for one Time/Account/Matconn ...
    cut->sap_revenues = new zcl_bn_dem_model( environment = cut->env
        model_data = value zcl_bn_dem_model=>tabl(
            ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' mat_group_id = 'MG1' demrevid_kfs = 'DEMREVID004' signeddata = 100 ) ) ).
    " ... of which the Allocated Revenues (DEMREVID023) explain 60 as
    " FFLASPQ and 25 as FFLASID, leaving 15 unexplained.
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' demrevid_kfs = 'DEMREVID023' matconn = 'MAT1' fflas = 'FFLASPQ' mat_group_id = 'MG1' signeddata = 60 )
        ( time = '2026.001' account = 'ACC1' demrevid_kfs = 'DEMREVID023' matconn = 'MAT1' fflas = 'FFLASID' mat_group_id = 'MG1' signeddata = 25 ) ) ).
    " When
    data(fflas_ratios) = cut->calc_fflas_ratios_by_material( ).
    " Then: exactly 3 new rows were appended to NEW_DATA (the 2 seed
    " rows are still tagged DEMREVID023, the new ones are not).
    data ratios type zcl_bn_dem_model=>tabl.
    loop at fflas_ratios->model_data into data(row) where demrevid_kfs <> 'DEMREVID023'.
      append row to ratios.
    endloop.
    cl_abap_unit_assert=>assert_equals(
      act = lines( ratios ) exp = 3 msg = 'Expected one ratio row per FFLAS value plus FFLASNON' ).
    read table ratios with key fflas = 'FFLASPQ' into data(pq_ratio).
    cl_abap_unit_assert=>assert_subrc( msg = 'FFLASPQ ratio row missing' ).
    cl_abap_unit_assert=>assert_equals(
      act = pq_ratio-signeddata exp = '0.6' msg = 'FFLASPQ ratio should be 60 / 100' ).
    read table ratios with key fflas = 'FFLASID' into data(id_ratio).
    cl_abap_unit_assert=>assert_subrc( msg = 'FFLASID ratio row missing' ).
    cl_abap_unit_assert=>assert_equals(
      act = id_ratio-signeddata exp = '0.25' msg = 'FFLASID ratio should be 25 / 100' ).
    read table ratios with key fflas = 'FFLASNON' into data(non_ratio).
    cl_abap_unit_assert=>assert_subrc( msg = 'FFLASNON remainder row missing' ).
    cl_abap_unit_assert=>assert_equals(
      act = non_ratio-signeddata exp = '0.15' msg = 'Remainder should be (100 - 60 - 25) / 100' ).
  endmethod.


  method single_fflas_covers_all_rev.
    " Given: the Allocated Revenue for one FFLAS value already equals
    " the full base revenue (nothing left unexplained).
    cut->sap_revenues = new zcl_bn_dem_model( environment = cut->env
        model_data = value zcl_bn_dem_model=>tabl(
            ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' demrevid_kfs = 'DEMREVID004' signeddata = 100 ) ) ).
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' demrevid_kfs = 'DEMREVID023' matconn = 'MAT1' fflas = 'FFLASPQ' mat_group_id = 'MG1' signeddata = 100 ) ) ).
    " When
    cut->calc_fflas_ratios_by_material( ).
    " Then: no FFLASNON row should have been created, because the
    " remainder (NON_FFLAS_REV) is exactly zero and the method only
    " appends a FFLASNON row "if non_fflas_rev is not initial".
    data(non_row_count) = 0.
    loop at cut->new_data->model_data into data(row)
        where demrevid_kfs <> 'DEMREVID023' and fflas = 'FFLASNON'.
      non_row_count = non_row_count + 1.
    endloop.
    cl_abap_unit_assert=>assert_equals(
      act = non_row_count exp = 0
      msg = 'No FFLASNON row expected when FFLAS revenue fully explains the base revenue' ).
  endmethod.


  method zero_revenue_row_is_ignored.
    " Given: a base revenue row whose SIGNEDDATA is zero. Passing
    " COMPRESSED = ABAP_FALSE stops the constructor from silently
    " deleting it (zcl_bn_dem_model's default COMPRESSED = ABAP_TRUE
    " runs COMPRESS, which removes rows "WHERE SIGNEDDATA IS INITIAL" -
    " turning it off here isolates the guard actually inside
    " CALC_FFLAS_RATIOS_BY_MATERIAL: "loop ... where signeddata is not initial").
    cut->sap_revenues = new zcl_bn_dem_model( environment = cut->env
        compressed = abap_false
        model_data = value zcl_bn_dem_model=>tabl(
            ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' demrevid_kfs = 'DEMREVID004' signeddata = 0 ) ) ).
    cut->new_data = new zcl_bn_dem_model( environment = cut->env ).
    " When
    cut->calc_fflas_ratios_by_material( ).
    " Then: nothing was appended at all - dividing by a zero base
    " revenue would be a ZCX_SY_ZERODIVIDE, so this guard matters.
    cl_abap_unit_assert=>assert_equals(
      act = lines( cut->new_data->model_data ) exp = 0
      msg = 'A zero-value base revenue row must not produce any ratio row' ).
  endmethod.


  method material_group_skip_list.
  " Given: FFLASMATGROUPSID (the skip list) contains MG_SKIP, and the
  " revenue for that material group is 100.
  cut->skip_fflas_ratio_mat_group_id = value #(
    ( sign = 'I' option = 'EQ' low = 'MG_SKIP' ) ).
  cut->sap_revenues = new zcl_bn_dem_model( environment = cut->env
      model_data = value zcl_bn_dem_model=>tabl(
          ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' mat_group_id = 'MG_SKIP' demrevid_kfs = 'DEMREVID004' signeddata = 100 ) ) ).
  cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
      ( time = '2026.001' account = 'ACC1' demrevid_kfs = 'DEMREVID023' matconn = 'MAT1' fflas = 'FFLASPQ' mat_group_id = 'MG_SKIP' signeddata = 100 ) ) ).
  " When
  data(fflas_ratios) = cut->calc_fflas_ratios_by_material( ).
  " Then, per the ABAP Doc: no FFLAS ratio should be produced for a
  " Material Group on the skip list. FFLAS_RATIOS now holds only the
  " rows this method itself computed (it no longer writes into
  " NEW_DATA), so we can assert on it directly.
  "
  " NOTE FOR WHOEVER RUNS THIS: ... (unchanged reasoning about the
  " grouping/skip-list behaviour)
  "
  " SSNG-3218: the skipped material now gets a flag row (DEMREVID052),
  " so only the ratio key figure (DEMREVID047) is checked here - see
  " skipped_material_is_flagged for the flag itself.
  data(ratio_count) = 0.
  loop at fflas_ratios->model_data transporting no fields where demrevid_kfs = 'DEMREVID047'.
    ratio_count = ratio_count + 1.
  endloop.
  cl_abap_unit_assert=>assert_equals(
    act = ratio_count exp = 0
    msg = 'Material Groups on the skip list should not receive a FFLAS ratio' ).
endmethod.


  method skipped_material_is_flagged.
    " Given: the skip list contains MG_SKIP. MAT1 belongs to it (100 split
    " over two rows), MAT2 belongs to MG1 and is not skipped.
    cut->skip_fflas_ratio_mat_group_id = value #(
      ( sign = 'I' option = 'EQ' low = 'MG_SKIP' ) ).
    cut->sap_revenues = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' mat_group_id = 'MG_SKIP' demrevid_kfs = 'DEMREVID006' signeddata = 60 )
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' mat_group_id = 'MG_SKIP' demrevid_kfs = 'DEMREVID007' signeddata = 40 )
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT2' mat_group_id = 'MG1'     demrevid_kfs = 'DEMREVID004' signeddata = 50 ) ) ).
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' demrevid_kfs = 'DEMREVID023' matconn = 'MAT2' fflas = 'FFLASPQ' mat_group_id = 'MG1' signeddata = 50 ) ) ).
    " When
    data(fflas_ratios) = cut->calc_fflas_ratios_by_material( ).
    " Then: exactly one flag row, for MAT1 only, with value 1 and FFLAS_NA.
    data flags type zcl_bn_dem_model=>tabl.
    data(ratio_count) = 0.
    loop at fflas_ratios->model_data into data(row).
      case row-demrevid_kfs.
        when 'DEMREVID052'.
          append row to flags.
        when 'DEMREVID047'.
          ratio_count = ratio_count + 1.
      endcase.
    endloop.
    cl_abap_unit_assert=>assert_equals(
      act = lines( flags ) exp = 1 msg = 'Expected one flag row per skipped Time/Account/Matconn' ).
    read table flags into data(flag) index 1.
    cl_abap_unit_assert=>assert_equals( act = flag-matconn    exp = 'MAT1' ).
    cl_abap_unit_assert=>assert_equals( act = flag-account    exp = 'ACC1' ).
    cl_abap_unit_assert=>assert_equals( act = flag-fflas      exp = 'FFLAS_NA' ).
    cl_abap_unit_assert=>assert_equals( act = flag-signeddata exp = '1' msg = 'Flag must be 1, not the summed revenue' ).
    " ... and the non-skipped material still gets its ratio.
    cl_abap_unit_assert=>assert_equals(
      act = ratio_count exp = 1
      msg = 'MAT2 (not skipped) should still receive its FFLAS ratio' ).
  endmethod.


  method no_matching_fflas_breakdown.
    " Given: two base revenues. The first (2026.001/ACC1/MAT1) has a
    " matching FFLAS breakdown; the second (2026.002/ACC2/MAT2) has
    " none at all in NEW_DATA.
    cut->sap_revenues = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' demrevid_kfs = 'DEMREVID004' signeddata = 100 )
        ( time = '2026.002' account = 'ACC2' matconn = 'MAT2' demrevid_kfs = 'DEMREVID004' signeddata = 50 ) ) ).
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' demrevid_kfs = 'DEMREVID023' matconn = 'MAT1' fflas = 'FFLASPQ' mat_group_id = 'MG1' signeddata = 100 ) ) ).
    " When
    data(fflas_ratios) = cut->calc_fflas_ratios_by_material( ).
    " Then: a FFLASNON row is still produced for the second revenue
    " (its remainder is the full 50), and it should carry ITS OWN keys
    " (2026.002/ACC2/MAT2) - not the first revenue's.
    "
    " NOTE FOR WHOEVER RUNS THIS: the loop variable used to build that
    " row is declared as "loop at fflas_rev->model_data into data(_fflas_rev)".
    " An inline DATA(...) declared inside a LOOP is only overwritten
    " when the LOOP actually finds a row; here the inner loop for the
    " second revenue finds none, so on my reading _fflas_rev keeps
    " whatever it held after the FIRST revenue's inner loop (i.e. the
    " FFLASPQ/MG1/2026.001/ACC1/MAT1 row), and only FFLAS and SIGNEDDATA
    " get overwritten before this stale row is appended. If that is
    " right, the FFLASNON row for the second revenue would incorrectly
    " carry TIME/ACCOUNT/MATCONN/MAT_GROUP_ID from the first one - a
    " real data-integrity risk, since it could get summed into the
    " wrong Material/Account entirely. I could not execute ABAP to
    " confirm this, so this assertion is written to state the CORRECT,
    " intended behaviour; if the test fails, it likely confirms the
    " leftover-work-area issue described above rather than a mistake in
    " the test.
    data(non_rows) = value zcl_bn_dem_model=>tabl( ).
    loop at fflas_ratios->model_data into data(row)
        where demrevid_kfs <> 'DEMREVID023' and fflas = 'FFLASNON'.
      append row to non_rows.
    endloop.
    cl_abap_unit_assert=>assert_equals(
      act = lines( non_rows ) exp = 1 msg = 'Expected exactly one FFLASNON row, for the second revenue' ).
    read table non_rows into data(non_row) index 1.
    cl_abap_unit_assert=>assert_equals( act = non_row-time    exp = '2026.002' ).
    cl_abap_unit_assert=>assert_equals( act = non_row-account exp = 'ACC2' ).
    cl_abap_unit_assert=>assert_equals( act = non_row-matconn exp = 'MAT2' ).
    cl_abap_unit_assert=>assert_equals( act = non_row-signeddata exp = '1' msg = '50 unexplained / 50 base = 1' ).
  endmethod.

endclass.


*&---------------------------------------------------------------------*
*& Test class for CALC_PQ_ID_FFLAS_REVENUE
*&---------------------------------------------------------------------*
* This method reads from NEW_DATA (location-allocated revenues tagged
* DEMREVID016-018, and the FFLAS monthly ratio DEMREVID022) and returns
* the FFLAS-allocated revenues (DEMREVID023) plus any Non-FFLAS balance.
* Like CALC_FFLAS_RATIOS_BY_MATERIAL, it only touches in-memory data
* via NEW_DATA, so it can be tested with fabricated model_data.
class ltc_pq_id_fflas_revenue_test definition for testing
  duration short
  risk level harmless.

  private section.
    data cut type ref to zcl_bn_dem_alloc.

    methods setup.

    methods full_alloc_no_non_fflas       for testing.
    methods partial_alloc_non_fflas        for testing.
    methods lfc_tagged_as_id_only         for testing.
    methods ronz_ufb_tagged_as_pq         for testing.

endclass.


class ltc_pq_id_fflas_revenue_test implementation.

  method setup.
    create object cut.
    cut->env = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'unit' ).
  endmethod.


  method full_alloc_no_non_fflas.
    " Given: Revenue of 100 allocated to UFB (geo = GDRVS_003, so PQ),
    " and a FFLAS monthly ratio of 1.0 (100%) for that Time/Account/Matconn.
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' geo_drivers = 'GDRVS_003'
          demrevid_kfs = 'DEMREVID016' signeddata = 100 )
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1'
          demrevid_kfs = 'DEMREVID022' signeddata = 1 ) ) ).
    " When
    data(result) = cut->calc_pq_id_fflas_revenue( ).
    " Then: all revenue is allocated to PQ FFLAS, no Non-FFLAS balance.
    data(non_fflas_count) = 0.
    loop at result->model_data into data(row) where fflas = 'FFLASNON'.
      non_fflas_count = non_fflas_count + 1.
    endloop.
    cl_abap_unit_assert=>assert_equals(
      act = non_fflas_count exp = 0
      msg = 'No FFLASNON expected when ratio is 100%' ).
    " The allocated PQ revenue should equal 100.
    data(pq_total) = conv uj_signeddata( 0 ).
    loop at result->model_data into row where fflas = 'FFLASPQ'.
      pq_total = pq_total + row-signeddata.
    endloop.
    cl_abap_unit_assert=>assert_equals(
      act = pq_total exp = 100
      msg = 'PQ FFLAS revenue should be 100 when ratio is 1.0' ).
  endmethod.


  method partial_alloc_non_fflas.
    " Given: Revenue of 200 allocated to RONZ (geo = GDRVS_002, so PQ),
    " and a FFLAS monthly ratio of 0.8 (80%) for that combination.
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' geo_drivers = 'GDRVS_002'
          demrevid_kfs = 'DEMREVID017' signeddata = 200 )
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1'
          demrevid_kfs = 'DEMREVID022' signeddata = '0.8' ) ) ).
    " When
    data(result) = cut->calc_pq_id_fflas_revenue( ).
    " Then: 160 allocated to PQ FFLAS, 40 as Non-FFLAS balance.
    data(pq_total) = conv uj_signeddata( 0 ).
    data(non_total) = conv uj_signeddata( 0 ).
    loop at result->model_data into data(row).
      case row-fflas.
        when 'FFLASPQ'.
          pq_total = pq_total + row-signeddata.
        when 'FFLASNON'.
          non_total = non_total + row-signeddata.
      endcase.
    endloop.
    cl_abap_unit_assert=>assert_equals(
      act = pq_total exp = 160
      msg = 'PQ FFLAS should be 200 * 0.8 = 160' ).
    cl_abap_unit_assert=>assert_equals(
      act = non_total exp = 40
      msg = 'Non-FFLAS balance should be 200 - 160 = 40' ).
  endmethod.


  method lfc_tagged_as_id_only.
    " Given: Revenue allocated to LFC geography (GDRVS_001).
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' geo_drivers = 'GDRVS_001'
          demrevid_kfs = 'DEMREVID018' signeddata = 50 )
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1'
          demrevid_kfs = 'DEMREVID022' signeddata = 1 ) ) ).
    " When
    data(result) = cut->calc_pq_id_fflas_revenue( ).
    " Then: LFC revenue should be tagged as FFLASID (ID-Only), not FFLASPQ.
    read table result->model_data into data(row) with key fflas = 'FFLASID'.
    cl_abap_unit_assert=>assert_subrc( msg = 'FFLASID row expected for LFC geography' ).
    cl_abap_unit_assert=>assert_equals( act = row-signeddata exp = 50 ).
    " No PQ rows.
    data(pq_count) = 0.
    loop at result->model_data into row where fflas = 'FFLASPQ'.
      pq_count = pq_count + 1.
    endloop.
    cl_abap_unit_assert=>assert_equals(
      act = pq_count exp = 0
      msg = 'No PQ FFLAS expected for LFC geography' ).
  endmethod.


  method ronz_ufb_tagged_as_pq.
    " Given: Revenues for both RONZ (GDRVS_002) and UFB (GDRVS_003).
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' geo_drivers = 'GDRVS_002'
          demrevid_kfs = 'DEMREVID016' signeddata = 30 )
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' geo_drivers = 'GDRVS_003'
          demrevid_kfs = 'DEMREVID016' signeddata = 70 )
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1'
          demrevid_kfs = 'DEMREVID022' signeddata = 1 ) ) ).
    " When
    data(result) = cut->calc_pq_id_fflas_revenue( ).
    " Then: both RONZ and UFB should be tagged as FFLASPQ.
    data(pq_total) = conv uj_signeddata( 0 ).
    loop at result->model_data into data(row) where fflas = 'FFLASPQ'.
      pq_total = pq_total + row-signeddata.
    endloop.
    cl_abap_unit_assert=>assert_equals(
      act = pq_total exp = 100
      msg = 'Both RONZ and UFB should sum to 100 under FFLASPQ' ).
  endmethod.

endclass.


*&---------------------------------------------------------------------*
*& Test class for CALC_PQ_FFLAS_RATIO
*&---------------------------------------------------------------------*
* This method reads FFLAS revenues (DEMREVID023) from NEW_DATA,
* consolidates them, and computes the PQ FFLAS share as a percentage.
* Testable by populating NEW_DATA with fabricated DEMREVID023 records.
class ltc_pq_fflas_ratio_test definition for testing
  duration short
  risk level harmless.

  private section.
    data cut type ref to zcl_bn_dem_alloc.

    methods setup.

    methods all_pq_ratio_is_1             for testing.
    methods mixed_pq_and_id_ratio         for testing.
    methods all_id_ratio_is_0             for testing.

endclass.


class ltc_pq_fflas_ratio_test implementation.

  method setup.
    create object cut.
    cut->env = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'unit' ).
  endmethod.


  method all_pq_ratio_is_1.
    " Given: All FFLAS revenue is PQ (no ID-Only or Non-FFLAS).
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' fflas = 'FFLASPQ'
          geo_drivers = 'GDRVS_003' demrevid_kfs = 'DEMREVID023' signeddata = 100 ) ) ).
    " When
    data(result) = cut->calc_pq_fflas_ratio( ).
    " Then: PQ ratio should be 1 (100%).
    cl_abap_unit_assert=>assert_equals(
      act = lines( result->model_data ) exp = 1
      msg = 'Expected exactly one ratio row' ).
    read table result->model_data into data(row) index 1.
    cl_abap_unit_assert=>assert_equals(
      act = row-signeddata exp = 1
      msg = 'PQ ratio should be 1 when all revenue is PQ' ).
    cl_abap_unit_assert=>assert_equals(
      act = row-demrevid_kfs exp = 'DEMREVID025'
      msg = 'Output key figure should be DEMREVID025 (PQ FFLAS %)' ).
  endmethod.


  method mixed_pq_and_id_ratio.
    " Given: 60 PQ + 40 ID-Only = 100 total for same Time/Account/Matconn.
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' fflas = 'FFLASPQ'
          geo_drivers = 'GDRVS_003' demrevid_kfs = 'DEMREVID023' signeddata = 60 )
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' fflas = 'FFLASID'
          geo_drivers = 'GDRVS_001' demrevid_kfs = 'DEMREVID023' signeddata = 40 ) ) ).
    " When
    data(result) = cut->calc_pq_fflas_ratio( ).
    " Then: PQ ratio = 60 / 100 = 0.6.
    read table result->model_data into data(row) index 1.
    cl_abap_unit_assert=>assert_equals(
      act = row-signeddata exp = '0.6'
      msg = 'PQ ratio should be 60 / 100 = 0.6' ).
  endmethod.


  method all_id_ratio_is_0.
    " Given: All FFLAS revenue is ID-Only (no PQ).
    cut->new_data = new zcl_bn_dem_model( environment = cut->env model_data = value zcl_bn_dem_model=>tabl(
        ( time = '2026.001' account = 'ACC1' matconn = 'MAT1' fflas = 'FFLASID'
          geo_drivers = 'GDRVS_001' demrevid_kfs = 'DEMREVID023' signeddata = 100 ) ) ).
    " When
    data(result) = cut->calc_pq_fflas_ratio( ).
    " Then: no PQ revenue exists, so no ratio row should be produced
    " (the divide would find no PQ rows to create a ratio from).
    cl_abap_unit_assert=>assert_equals(
      act = lines( result->model_data ) exp = 0
      msg = 'No ratio row expected when there is no PQ FFLAS revenue' ).
  endmethod.

endclass.


*&---------------------------------------------------------------------*
*& What is NOT covered here, and why
*&---------------------------------------------------------------------*
* INITIALISE and IF_UJ_CUSTOM_LOGIC~EXECUTE both do things a unit test
* should not do: INITIALISE creates a real ZCL_BPC_CH_PLANNING
* environment ("env = new zcl_bpc_ch_planning( )."), reads live Script
* Logic parameters via ZCL_BPC_PARAM, and pulls live model data via
* zcl_bn_dem_model's FILTERS-based constructor. None of those classes
* are injected (they are all created with NEW right inside the method),
* so there is no seam to substitute a test double without changing the
* production code.
*
* If full coverage of INITIALISE/EXECUTE is ever wanted, the usual ABAP
* paths are:
*   1. Integration tests instead of unit tests: mark them
*      DURATION LONG / RISK LEVEL DANGEROUS (or CRITICAL) and point them
*      at a real/sandbox BPC environment. These would not run as part of
*      a routine "all unit tests" pass, only deliberately.
*   2. Refactor for dependency injection: change ENV/PARAM/etc. to be
*      passed in (constructor or setter) rather than created with NEW
*      inside the method, so CL_ABAP_TESTDOUBLE (or hand-written fakes)
*      can stand in for them in a real unit test. That is a design
*      change to the production class, not something to do silently
*      alongside a "just add tests" task.
* Either option is a separate piece of work from the tests above.



CLASS ltc_delta_contract DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS replacement_changes FOR TESTING.
ENDCLASS.
CLASS ltc_delta_contract IMPLEMENTATION.
  METHOD replacement_changes.
    DATA(io) = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'test' ).
    DATA(old) = NEW zcl_bn_dem_model( environment = io model_data = VALUE zcl_bn_dem_model=>tabl(
      ( account = 'UNCHANGED' signeddata = 10 ) ( account = 'CHANGED' signeddata = 100 )
      ( account = 'REMOVED' signeddata = -50 ) ( account = 'OLD_ZERO' signeddata = 0 ) ) ).
    DATA(current) = NEW zcl_bn_dem_model( environment = io model_data = VALUE zcl_bn_dem_model=>tabl(
      ( account = 'UNCHANGED' signeddata = 10 ) ( account = 'CHANGED' signeddata = 120 )
      ( account = 'NEW' signeddata = '-9.8765432' ) ) ).
    current->compare_delta( old ).
    cl_abap_unit_assert=>assert_equals( act = lines( current->model_data ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = current->model_data[ account = 'CHANGED' ]-signeddata exp = CONV uj_signeddata( 120 ) ).
    cl_abap_unit_assert=>assert_equals( act = current->model_data[ account = 'REMOVED' ]-signeddata exp = CONV uj_signeddata( 0 ) ).
    cl_abap_unit_assert=>assert_equals( act = current->model_data[ account = 'NEW' ]-signeddata exp = CONV uj_signeddata( '-9.8765432' ) ).
  ENDMETHOD.
ENDCLASS.


class ltc_original_compare definition deferred.
class zcl_bn_dem_alloc definition local friends ltc_original_compare.
" BEGIN ORIGINAL COMPARISON SNAPSHOT
" Customer source 2796a7f, class identity changed only for ABAP Unit isolation.
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
"! Entry point: if_uj_custom_logic~execute orchestrates the full calculation chain
"! (initialise, then Location allocation, then Supplier allocation, then FFLAS grouping/ratios,
"! then transpositions, then delta compare, then write back via zcl_bpc_util=>set_data).
"! <br/><br/>
"! Dependent/related classes (see also zcl_bpc_demrevid, which this class relies on for all
"! model data access, and zcl_bpc_model, its superclass):
"! <ul>
"! <li>zcl_bpc_param - reads Script Logic parameters (e.g. DEBUG, FFLASMATGROUPS)</li>
"! <li>zcl_bpc_current_view - parses the BPC current view (UJK_T_CV) passed into the logic script</li>
"! <li>zcl_bpc_ch_planning - BPC environment/connection handle, shared by the dimension helpers below</li>
"! <li>zcl_bpc_dim_product_type - PRODUCT_TYPE dimension member/property lookups</li>
"! <li>zcl_bpc_dim_mat_group_id - MAT_GROUP_ID dimension member/property lookups</li>
"! <li>zcl_bpc_dim_matconn - MATCONN (material connection) dimension member/property lookups</li>
"! <li>zcl_bpc_util - static utility, used here only to write the result back to BPC (set_data)</li>
"! </ul>
class lcl_original_demrevid definition
  final
  create public .


  public section.

    " Standard BPC BAdI marker interface implemented by every custom logic class (no methods of its own).
    interfaces if_badi_interface .
    " SAP BPC "UJ Custom Logic" framework interface. Provides the init/execute/cleanup
    " hooks invoked by the BPC Script Logic engine when this logic script (BAdI implementation) runs.
    interfaces if_uj_custom_logic .
  protected section.
  private section.
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
    " Most zcl_bpc_demrevid-typed attributes are lightweight in-memory views over model data
    " (see zcl_bpc_demrevid), each holding one specific input, ratio, or intermediate result set.
    data:
      " Script Logic parameters (e.g. DEBUG, FFLASMATGROUPS, FFLASMATGROUPSID, HSNS_REALLOC_LOCATIONS).
      param                         type ref to zcl_bpc_param,

      " Current CATEGORY member selected in the BPC current view.
      category                      type uj_dim_member,
      " Current TIME range selected in the BPC current view (includes TIME_NA).
      time                          type ujw_t_dimmem_range,
      " BPC environment/connection handle shared by this class and the dimension helper objects below.
      env                           type ref to zcl_bpc_ch_planning,
      " Helper for PRODUCT_TYPE dimension member/property lookups (e.g. REV_ID_GROUP, children of ACCESS).
      product_type_dim              type ref to zcl_bpc_dim_product_type,
      " Helper for MAT_GROUP_ID dimension member/property lookups (e.g. REV_ID_GROUP overwrite).
      mat_group_id_dim              type ref to zcl_bpc_dim_mat_group_id,
      " Raw DEMREVID_INPUT audit trail data (all input key figures/mappings for the current selection).
      input_data                    type ref to zcl_bpc_demrevid,
      " Previously stored DEMREVID_OUTPUT data, used as the "before" side of the delta comparison.
      output_data                   type ref to zcl_bpc_demrevid,
      " Accumulator for every record calculated in this run; written back to BPC at the end of execute( ).
      new_data                      type ref to zcl_bpc_demrevid,
      " Connection Region Split mapping (DEMREVID008), keyed by Time/Account.
      conn_reg_split                type ref to zcl_bpc_demrevid,
      " L1/L2 FFLAS Subset mapping (DEMREVID027), keyed by Time/Account.
      l1_l2_mapping                 type ref to zcl_bpc_demrevid,
      " RSP Billing ratio by Material for Location allocation (DEMREVID010).
      rsp_location_material_ratio   type ref to zcl_bpc_demrevid,
      " RSP Billing ratio by G/L (Account) for Location allocation (DEMREVID011).
      rsp_location_gl_ratio         type ref to zcl_bpc_demrevid,
      " RSP Billing ratio by Material for Supplier allocation (DEMREVID029).
      rsp_supplier_material_ratio   type ref to zcl_bpc_demrevid,
      " CAL ratio by G/L (Account) for Location allocation (DEMREVID012).
      cal_location_gl_ratio         type ref to zcl_bpc_demrevid,
      " CAL ratio by Connection Region Split for Location allocation (DEMREVID013).
      cal_location_conn_seg_ratio   type ref to zcl_bpc_demrevid,
      " SAP Actuals revenues loaded for the current selection, grouped/re-tagged for this calculation (DEMREVID004).
      sap_revenues                  type ref to zcl_bpc_demrevid,
      " Chosen Location allocation ratio per Time/Account/Matconn, resolved from the ratio sources above (DEMREVID015).
      rsp_split_ratios              type ref to zcl_bpc_demrevid,
      " FFLAS monthly ratio (%) by Material, read from the FFLAS grouping input (DEMREVID022).
      fflas_month_ratio             type ref to zcl_bpc_demrevid,
      " SAP revenues consolidated (Billed + Not Billed), grouping out Cost Centre/Doc Type/Audittrail.
      sap_revenues_consol           type ref to zcl_bpc_demrevid,
      " RSP Billing ratio by G/L (Account) for Supplier allocation (DEMREVID030).
      rsp_supplier_gl_ratio         type ref to zcl_bpc_demrevid,
      " CAL ratio by G/L (Account) for Supplier allocation (DEMREVID032).
      cal_supplier_gl_ratio         type ref to zcl_bpc_demrevid,
      " CAL ratio by Connection Region Split for Supplier allocation (DEMREVID031).
      cal_supplier_conn_seg_ratio   type ref to zcl_bpc_demrevid,
      " Chosen Supplier allocation ratio per Time/Account/Matconn, resolved from the ratio sources above (DEMREVID033).
      supplier_ratios               type ref to zcl_bpc_demrevid,
      " Material Group mapping, used to derive MAT_GROUP_ID from the (remapped) Material or Account (DEMREVID035).
      mat_group_mapping             type ref to zcl_bpc_demrevid,
      " Transposed Allocated Revenues (DEMREVID038), used as the basis for connection and price transposition.
      transposed_revenues           type ref to zcl_bpc_demrevid,
      " Helper for MATCONN (material connection) dimension member/property lookups (e.g. PRODUCT_TYPE).
      matconn_dim                   type ref to zcl_bpc_dim_matconn,
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
        _sap_revenue           type zcl_bpc_demrevid=>struct
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
        value(result) type ref to zcl_bpc_demrevid.
    "! <p class="shorttext synchronized" lang="en">Calculate PQ FFLAS ratio (%)</p>
    "! Computes the ratio of PQ FFLAS revenue to total revenue (per Time/Account/Matconn)
    "! from the allocated FFLAS revenues produced by calc_pq_id_fflas_revenue.
    "! @parameter fflas_revenues | Allocated FFLAS revenues (output of calc_pq_id_fflas_revenue).
    "! @parameter result | PQ FFLAS ratio (%) records, tagged with key figure kf_pq_fflas_pct.
    methods calc_pq_fflas_ratio
      returning
        value(result) type ref to zcl_bpc_demrevid.
    "! Assign Connection Region Split and FFLAS Subset (L1/L2 FFLAS) to Model Data
    "! <p>Also derives PRODUCT_TYPE (via overwrite or MATCONN default), REV_ID_GROUP (via
    "! PRODUCT_TYPE or MAT_GROUP_ID override), MATCONN remap (MATREMAP), MAT_GROUP_ID and
    "! REG_FFLAS_SERV.</p>
    "! @parameter model_ref | Model instance whose records will be enriched in place.
    methods assign_new_fields_rev
      importing
        model_ref type ref to zcl_bpc_demrevid.
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
        value(fflas_ratios) type ref to zcl_bpc_demrevid.



endclass.



class lcl_original_demrevid definition local friends ltc_original_compare.
class lcl_original_demrevid implementation.


  method if_uj_custom_logic~cleanup.
  endmethod.


  method if_uj_custom_logic~execute.
    initialise( it_param = it_param current_view = it_cv ).

    " Assign derived fields (Connection Region Split, FFLAS Subset, Product Type, Material Group,
    " etc.) to the raw SAP revenues and add them to the result set as-is (unallocated Actuals).
    assign_new_fields_rev( sap_revenues ).
    new_data->append( sap_revenues ).

    " Consolidates Billed and Not Billed data.
    sap_revenues_consol =   sap_revenues->copy(  )->group(
            include_dimensions = abap_false group_by = value #( ( $demrevid_kfs ) ) ).

    " --- Location (Geography) allocation ---
    calc_location_alloc_method( ).
    calc_location_alloc_ratios( ).
    calc_alloc_rsp_billed_data( ).
    calc_remaining_rsp_billing( ).
    calc_rsp_not_billed_location( ).
    calc_fflas_grouping( ).
    new_data->append( calc_pq_id_fflas_revenue( ) ).
    new_data->append( calc_pq_fflas_ratio( ) ).
    " --- Supplier (LFC Winning Supplier) allocation ---
    calc_supplier_alloc_method( ).
    calc_supplier_alloc_ratios( ).
    calc_alloc_id_rev_supplier( ).
    calc_price_material_level( ).
    calc_hsns_rev_alloc( ).
    " --- FFLAS ratio calculation (drives the DEMREV model) ---
    new_data->append( calc_fflas_ratios_by_material( ) ).

    " --- Transpositions for reporting ---
    transpose_revenues(  ).
    transpose_prices( ).
    transpose_connections( ).

    " Compare against the previously stored output to produce a delta and hand the result back to BPC.
    new_data->compare_delta( output_data ).

    zcl_bpc_util=>set_data(
      exporting
        it_data = new_data->model_data
      changing
        ct_data = ct_data
    ).
  endmethod.

  method initialise.
    param = new #( it_param ).

    " Parse the BPC current view and resolve the Category and Time range for this run.
    data(cv_obj) = new zcl_bpc_current_view( current_view ).
    category = current_view[ dimension = $category ]-member[ 1 ].
    time = cv_obj->get_dimmem_range( $time ).

    if param->get_value( 'DEBUG' ) = 'ON'.
      cl_ujk_logger=>log( |Selected Category: | ).
      cl_ujk_logger=>log( category ).
    endif.

    " Instantiate the BPC environment handle and its dependent dimension helpers.
    env = new zcl_bpc_ch_planning( ).
    product_type_dim = new #( env ).
    mat_group_id_dim = new #( env ).
    matconn_dim = new #( env ).

    " Base DEMREVID data set (Time/Category filtered), used to derive the INPUT/OUTPUT/NEW views below.
    data(demrevid_data) =
      new zcl_bpc_demrevid(
        environment = env
        filters = value #(
          ( dimension = $time     in = time )
          ( dimension = $time     low = 'TIME_NA' )
          ( dimension = $category low = category )
    ) ).

    " Read data from BPC Models.
    input_data = demrevid_data->copy( value #( ( dimension = 'AUDITTRAIL' hier_name = 'PARENTH1' low = 'DEMREVID_INPUT' ) ) ).
    output_data = demrevid_data->copy( value #( ( dimension = 'AUDITTRAIL' hier_name = 'PARENTH1' low = 'DEMREVID_OUTPUT' ) ) ).
    new_data = new zcl_bpc_demrevid( environment = env ).

    " Initialise objects used in calculation.
    " Load and pre-sort every reference data set required by the allocation/ratio methods below.
    sap_revenues =
        input_data->copy( value #(
            ( dimension = $demrevid_kfs hier_name = 'PARENTH1' low = kf_sap_revenues ) ) )->group(
                include_dimensions = abap_false
               group_by =  value #(  ( $costcentre ) ( $doc_typ ) ( $audittrail )  ) )->replace(
                    dimension = 'AUDITTRAIL' replace_with = audit_dnrid_calc ).

    conn_reg_split =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_conn_region_mapping ) ) )->sort( value #(
                    (       $time ) (           $account ) ) ).

    l1_l2_mapping =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_l1_l2_mapping ) ) )->sort( value #(
                    (       $time ) (           $account ) ) ).

    mat_group_mapping =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_mat_group_mapping ) ) )->sort( value #(
                    (       $time ) (           $matconn ) ( $account ) ) ).

    rsp_location_material_ratio =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_rsp_loc_ratio_mat )
    ) )->sort( value #(
                     (      $time ) (           $matconn ) ) ).

    rsp_location_gl_ratio =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_rsp_loc_ratio_gl ) ) )->sort( value #(
                     (      $time ) (           $account ) ) ).

    cal_location_gl_ratio =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_cal_loc_ratio_gl ) ) )->sort( value #(
                    (       $time ) (           $account ) ) ).

    cal_location_conn_seg_ratio =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_cal_loc_ratio_conn_reg ) ) )->sort( value #(
                   (        $time ) (           $conn_reg_split ) ) ).

    rsp_supplier_material_ratio =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_rsp_supplier_ratio_mat ) ) )->sort( value #(
                    (       $time ) (           $account ) ( $matconn ) ) ).

    rsp_supplier_gl_ratio =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_rsp_supplier_ratio_gl ) ) )->sort( value #(
                    (       $account ) (        $time ) ) ).

    cal_supplier_gl_ratio =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_cal_supplier_ratio_gl ) ) )->sort( value #(
                    (       $account ) (        $time ) ) ).

    cal_supplier_conn_seg_ratio =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs low = kf_cal_supplier_ratio_conn_reg ) ) )->sort( value #(
                    (       $conn_reg_split ) ( $time ) ) ).

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
  endmethod.


  method if_uj_custom_logic~init.
  endmethod.

  method get_rev_split_method.

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

  endmethod.


  method calc_location_alloc_method.
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
  endmethod.


  method calc_location_alloc_ratios.
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
  endmethod.


  method calc_alloc_rsp_billed_data.
    data(rsp_billing_with_split)  =
            input_data->copy( value #(
                ( dimension = $demrevid_kfs  low = kf_rsp_bill_prod_type )
                ( dimension = $doc_typ  low = 'RS' )
                ( dimension = $doc_typ  low = 'AD' )
                ( dimension = $doc_typ  low = 'AC' )
                " Excludes TBD and N/A UFB Reporting categories
                " to prevent unexpected results.
                ( dimension = $ufb_dr_id sign = 'E' low = 'UFBDRID006' ) " TBD
                ( dimension = $ufb_dr_id sign = 'E' low = 'UFB_DR_ID_NA' )
                    ) )->group(
                        include_dimensions = abap_false
                        group_by = value #(
                            ( $doc_typ ) ( $ufb_dr_id ) ( $lfc_win_supplier )  ) )->replaces( value #(
                                ( dimension = $demrevid_kfs replace_with = kf_rsp_bill_with_loc )
                                ( dimension = 'AUDITTRAIL' replace_with = audit_dnrid_calc )
                                     ) ).

    assign_new_fields_rev( rsp_billing_with_split ).
    new_data->append( rsp_billing_with_split ).
  endmethod.


  method calc_remaining_rsp_billing.
    data(rsp_billing_with_split) =
        new_data->copy( value #(
            ( dimension               = $demrevid_kfs low = kf_rsp_bill_with_loc ) ) )->group(
                include_dimensions = abap_false
                group_by = value #( ( $geo_drivers ) ) )->sort( value #(
                                    ( $time ) (           $account ) ( $matconn ) ) ).

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
  endmethod.


  method calc_rsp_not_billed_location.
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
  endmethod.


  method calc_fflas_grouping.

    fflas_month_ratio = new #( environment = env ).
    data(fflas_grouping) = input_data->copy( value #(
        ( dimension       = $demrevid_kfs low = kf_fflas_grouping )
        ( dimension       = $demrevid_kfs low = kf_fflas_monthly_pct )
    ) )->sort( value #( ( $matconn ) (        $account ) ( $demrevid_kfs ) ( $time ) ) ).

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
  endmethod.





  method calc_pq_id_fflas_revenue.

    " Retrieve the Revenues (both RSP Billend and Accrual) allocated by Geographies (Location).
    " Also assign the FFLAS type depending on the Geography.
    data(rev_by_location) = new_data->copy( value #(
                ( dimension = $demrevid_kfs option       = 'BT'      low     = kf_rsp_bill_with_loc high = kf_rsp_not_billed_loc )
    ) )->replaces( value #(
                ( dimension = $demrevid_kfs replace_with = kf_fflas_revenue )
                ( dimension = $fflas        replace_with = fflas_pq filters = value #( ( dimension = $geo_drivers option = 'BT' low = geo_ronz high = geo_ufb ) ) )
                ( dimension = $fflas        replace_with = fflas_id filters = value #( ( dimension = $geo_drivers low    = geo_lfc ) ) )
    ) )->group( ).

    " Manual Input - FFLAS ratio by Material/Account.
    data(fflas_alloc_ratio) = new_data->copy( value #(
        ( dimension = $demrevid_kfs low = kf_fflas_monthly_pct ) ) )->sort( value #(
            (       $time ) (           $account ) ( $matconn ) ) ).

    " Apply FFLAS ratio in the Revenue allocated by Geography.
    data(rev_alloc_by_fflas) = rev_by_location->copy( )->multiply(
      multiply_data = fflas_alloc_ratio->model_data
      read_dimensions = value #( ( $time ) ( $account ) ( $matconn ) ) ).
    delete rev_alloc_by_fflas->model_data where signeddata is initial.

    " If revenues aren't fully allocated by the FFLAS ratio (i.e. the ratio < 100%),
    " the unallocated balance is assigned to Non-FFLAS. This is computed as:
    " balance = total revenue by location - sum of FFLAS-allocated revenue (per Time/Account/Matconn/Geo).
    data(alloc_by_geo) = rev_alloc_by_fflas->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( $fflas ) ) )->sort( value #(
            ( $time ) ( $account ) ( $matconn ) ( $geo_drivers ) ) ).
    data(non_fflas_balance) = rev_by_location->copy( )->sort( value #(
            ( $time ) ( $account ) ( $matconn ) ( $geo_drivers ) ) ).
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

  endmethod.


  method calc_pq_fflas_ratio.

    data(fflas_revenues) = new_data->copy( value #(
                  ( dimension = $demrevid_kfs low     = kf_fflas_revenue  )
      ) ).

    " Consolidate the FFLAS revenues - remove Geography and FFLAS to get total per Time/Account/Matconn.
    data(fflas_rev_consolidated) = fflas_revenues->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( $geo_drivers ) ( $fflas ) ) )->sort( value #(
                            ( $time )        ( $account ) ( $matconn ) ) ).

    " Filter to PQ FFLAS only and consolidate by Time/Account/Matconn.
    data(pq_fflas_rev) = fflas_revenues->copy( value #(
        ( dimension               = $fflas low = fflas_pq ) ) )->group(
            include_dimensions = abap_false
            group_by = value #( ( $geo_drivers ) ) )->sort( value #(
                                ( $time ) (    $account ) ( $matconn ) ) ).

    " PQ FFLAS ratio = PQ FFLAS Revenue / Total Revenue (per Time/Account/Matconn).
    pq_fflas_rev->divide(
      divide_data     = fflas_rev_consolidated->model_data
      read_dimensions = value #(
          ( $time ) ( $account ) ( $matconn ) ) )->replace( dimension = $demrevid_kfs replace_with = kf_pq_fflas_pct ).

    result = pq_fflas_rev.
  endmethod.


  method assign_new_fields_rev.

    data(mat_remapping) = input_data->copy( value #(
        ( dimension = $demrevid_kfs low = mat_remapping ) ) )->sort( value #(
            ( $time ) ( $account ) ( $matconn ) ) )->model_data.

    data(reg_fflas_service) = input_data->copy( value #(
        ( dimension = $demrevid_kfs low = kf_reg_fflas_serv_mapping ) ) )->sort( value #(
            (       $time ) (           $matconn ) ( $mat_group_id ) ) )->model_data.

    data(prod_type_overwrite) = input_data->copy( value #(
        ( dimension = $demrevid_kfs low = kf_prod_type_mapping ) ) )->sort( value #(
            (       $time ) (           $matconn ) ) )->model_data.

    data(prod_type_dim) = new zcl_bpc_dim_product_type( env ).

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

  endmethod.


  method calc_supplier_alloc_method.
    loop at sap_revenues_consol->model_data into data(_sap_revenue).
      data(_new_data) = _sap_revenue.
      _new_data-demrevid_kfs = kf_supplier_split_index.
      _new_data-signeddata = conv i( get_rev_split_method( ratio_type = supplier _sap_revenue = _new_data ) ).
      new_data->append( _new_data ).
    endloop.
  endmethod.


  method calc_supplier_alloc_ratios.
    supplier_ratios = new zcl_bpc_demrevid( environment = env ).
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
    supplier_ratios->sort( value #( ( $time ) ( $account ) ( $matconn ) ) ).
    new_data->append( supplier_ratios ).
  endmethod.


  method calc_alloc_id_rev_supplier.
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
  endmethod.


  method calc_price_material_level.
    data(mat_price) = input_data->copy( value #(
        ( dimension = $demrevid_kfs low = sap_price ) ) )->sort( value #(
            ( $time ) ( $matconn ) ) )->model_data.
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
  endmethod.


  method transpose_revenues.

    " Transpose PQ and ID-Only FFLAS Revenues to facilitate report.
    transposed_revenues = new_data->copy( value #(
        ( dimension = $demrevid_kfs low = kf_fflas_revenue ) " Allocated Revenues
            ) )->group(
                include_dimensions = abap_false
                group_by = value #( ( $account ) ( $audittrail ) ( $geo_drivers ) ( $conn_reg_split ) ( 'RSP_SERVICE_ID' ) ( 'REV_ID_GROUP' ) ( $matconn ) ) )->replaces( value #(
                        ( dimension = $demrevid_kfs replace_with = kf_alloc_rev_summary )
                        ( dimension = $audittrail replace_with = audit_dnrid_calc )
                        ( dimension  = $lfc_win_supplier replace_with = 'LFC_WIN_SUPPLIER_NA' filters = value #( ( dimension = $fflas low = fflas_pq ) ) )
                             ) )->group( ).

    data(transp_rev_aux) = transposed_revenues->copy(  ).
    transp_rev_aux->replace(
        dimension = $matremap
        replace_with = 'MATREMAP_NA'
        filters = value #( ( dimension = $mat_group_id sign = 'E' low = 'MAT_GROUP_ID_NA' ) ) )->group( ).

    data(hidden_mat_group) = input_data->copy( value #(
        ( dimension = $demrevid_kfs low = kf_hidden_mat_group )
             ) )->get_dimmem_range( $mat_group_id ).

    transp_rev_aux->delete( value #( ( dimension = $mat_group_id in = hidden_mat_group ) ) ).

    new_data->append( transp_rev_aux ).

  endmethod.



  method calc_hsns_rev_alloc.

    " Credit the Allocated Revenues for HSNS Premium.
    data(hsns_prem_fflas_credit) = new_data->copy( value #(
        ( dimension = $demrevid_kfs low = kf_fflas_revenue )
        ( dimension = $account low = '001054200'  )
        ( dimension = $product_type low =  access_rental  )
        ( dimension = $product_type low = bandwidth  )
             ) )->replace( dimension = 'AUDITTRAIL' replace_with = 'DEMREVID_CALC_HSNS_CREDIT' )->multiply( multiplier = -1 ).
    new_data->append( hsns_prem_fflas_credit ).

    " The "new" RSP Billed for HSNS Premium Revenues data comes from flat-files (CDW data)
    data(hsns_premium_rsp_bill) =
         input_data->copy( value #(
            ( dimension = $demrevid_kfs low = kf_hsns_premium_upload  ) ) )->replaces( value #(
                ( dimension = 'AUDITTRAIL' replace_with = 'DEMREVID_CALC_HSNS' )
                ( dimension = $demrevid_kfs replace_with = rsp_billing )  ) )->group(
                    include_dimensions = abap_false
                    group_by = value #( ( $ufb_dr_id ) ) ).
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
        ( dimension = $demrevid_kfs    replace_with = kf_fflas_revenue )  ) )->group( ).

    " Only consider the following Locations (LFC_WIN_SUPPLIER) when calculating the
    " HSNS Revenue Reallocation for ID-Only: Enable Services, North Power, UltraFast Fibre
    " This can be configured in Logic Script ALLOC_REVENUES.LGF.
    data(locations_for_hsns_realloc) = param->get_dimmem_range( sign = 'E' parameter = 'HSNS_REALLOC_LOCATIONS' ).
    hsns_premium_rsp_bill->delete( value #(
        ( dimension = $fflas            low = fflas_id )
        ( dimension = $lfc_win_supplier in  = locations_for_hsns_realloc ) ) ).

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
            ( $time ) ( $matconn ) ( $fflas ) ( $lfc_win_supplier ) ) )->get_ratio( value #( ( $time ) ( $matconn ) ) )->model_data.

    data(mat_group_fflas_ratio) =
        hsns_premium_rsp_bill->copy( )->group( value #(
            ( $time ) ( $mat_group_id ) ( $fflas ) ( $lfc_win_supplier ) ) )->get_ratio( value #( ( $time ) ( $mat_group_id ) ) )->model_data.

    " Gets the HSNS Revenue that comes from SAP (Both Billed and Not Billed (Accrual).
    data(hsns_premium_accrual) = sap_revenues->copy( value #(
            ( dimension = $account low = '001054200'  )
            ( dimension = $product_type low =  access_rental  )
            ( dimension = $product_type low = bandwidth  )
            ( dimension = $demrevid_kfs low = accrual  )
                 ) )->replace( dimension = 'AUDITTRAIL' replace_with = 'DEMREVID_CALC_HSNS' ).

    " Allocate Accruals (from SAP) between PQ/ID and Location.
    data(new_accrual_allocation) = new zcl_bpc_demrevid( environment = env ).
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

    hsns_fflas_allocation->append( new_accrual_allocation )->replace( dimension = $demrevid_kfs replace_with = kf_fflas_revenue )->group( ).
    new_data->append( hsns_fflas_allocation ).
  endmethod.


  method transpose_connections.
    " CAL connections for current period.
    data(current_period_conn) = input_data->copy( value #(
        ( dimension = $demrevid_kfs low = kf_monthly_cal_conn )
        " Bandwidth connections won't be considered.
        ( dimension = $product_type  sign = 'E' low = bandwidth  ) ) )->replace(
                dimension  = $lfc_win_supplier
                replace_with = 'LFC_WIN_SUPPLIER_NA'
                filters = value #( ( dimension = $fflas low = fflas_pq ) ) )->group( ).
    check current_period_conn->model_data is not initial.

    assign_new_fields_rev( current_period_conn ).

    current_period_conn->replace(
        dimension = $matremap
        replace_with = 'MATREMAP_NA'
        filters = value #( ( dimension = $mat_group_id sign = 'E' low  = 'MAT_GROUP_ID_NA' ) ) )->group( value #(
            (                          $time ) (            $fflas ) ( $matremap ) ( $mat_group_id ) ( $lfc_win_supplier ) ) ).

    " Get the prior period.
    data(offset_periods) = current_period_conn->copy( )->group( value #( ( $time ) ) )->offset_time( -1 )->model_data.
    sort offset_periods by time descending.
    data(prior_period) = offset_periods[ 1 ]-time.
    " CAL connections for prior period.
    data(prior_period_conn) = new zcl_bpc_demrevid(
        environment = env
        filters = value #(
            ( dimension = $demrevid_kfs low = kf_monthly_cal_conn )
            ( dimension = $time low = prior_period )
            ( dimension = $category low = category )
            ( dimension = $product_type  sign = 'E' low = bandwidth  )
                ) )->offset_time( offset_by = 1 )->replace(
                dimension  = $lfc_win_supplier
                replace_with = 'LFC_WIN_SUPPLIER_NA'
                filters = value #( ( dimension = $fflas low = fflas_pq ) ) )->group( ).

    assign_new_fields_rev( prior_period_conn ).
    prior_period_conn->replace(
        dimension = $matremap
        replace_with = 'MATREMAP_NA'
        filters = value #( ( dimension = $mat_group_id sign = 'E' low  = 'MAT_GROUP_ID_NA' ) ) )->group( value #(
            (                          $time ) (            $fflas ) ( $matremap ) ( $mat_group_id ) ( $lfc_win_supplier ) ) ).
    prior_period_conn->append( current_period_conn->copy( )->offset_time( 1 ) ).

    " Which Material Groups need to hide its Connections in the
    " final output.
    data(hidden_conn_mat_group) = input_data->copy( value #(
            ( dimension   = $demrevid_kfs low = kf_hidden_conn )
    ) )->sort( value #( ( $time ) (           $mat_group_id ) ) ).

    " Remove the product type to avoid duplicates.
    transposed_revenues->group( include_dimensions = abap_false
                                group_by           = value #( ( $product_type ) ) )->replace(
                                dimension = $matremap
                                replace_with = 'MATREMAP_NA'
                                filters = value #( ( dimension  = $mat_group_id sign = 'E' low = 'MAT_GROUP_ID_NA' ) ) )->group( ).

    data(transposed_conn) = new zcl_bpc_demrevid( environment = env ).
    loop at transposed_revenues->model_data into data(_transposed_conn).

      if hidden_conn_mat_group->read( value #(
          ( dimension = $time         low = _transposed_conn-time )
          ( dimension = $mat_group_id low = _transposed_conn-mat_group_id )
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
    data(prior_closing_bal) = new zcl_bpc_demrevid(
        environment = env
        filters = value #(
            ( dimension = $demrevid_kfs low = kf_conn_closing )
            ( dimension = $time         low = prior_period )
            ( dimension = $category     low = category ) ) )->offset_time( offset_by = 1 )->replace(
                dimension = $demrevid_kfs replace_with = kf_conn_opening ).
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
        ( dimension       = $demrevid_kfs low = kf_add_conn_mat_group )
    ) )->sort( value #( ( $time ) ( $fflas ) ( $mat_group_id ) ) ).

    data(add_conn_prior_per) = new zcl_bpc_demrevid(
        environment = env
        filters = value #(
            ( dimension                                 = $demrevid_kfs low = kf_add_conn_mat_group )
            ( dimension                                 = $time         low = prior_period )
            ( dimension                                 = $category     low = category )
    ) )->offset_time( offset_by = 1 )->sort( value #( ( $time ) (           $fflas ) ( $mat_group_id ) ) ).

    data add_conn_final_output like transposed_conn->model_data.
    loop at transposed_conn->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( $product_type ) ) )->model_data into data(_current_conn).

      case _current_conn-demrevid_kfs.
        when kf_conn_closing.
          _current_conn-signeddata = add_conn_current_per->read( value #(
            ( dimension = $time         low = _current_conn-time )
            ( dimension = $fflas        low = _current_conn-fflas )
            ( dimension = $mat_group_id low = _current_conn-mat_group_id )
          ) )-signeddata.
          if  _current_conn-signeddata is not initial.
            append _current_conn to add_conn_final_output.

            data(_add_conn_final_output) = _current_conn.
            _add_conn_final_output-demrevid_kfs = kf_output_add_conn_mat_group.
            append _add_conn_final_output to add_conn_final_output.
          endif.
        when kf_conn_opening.
          _current_conn-signeddata = add_conn_prior_per->read( value #(
            ( dimension = $time         low = _current_conn-time )
            ( dimension = $fflas        low = _current_conn-fflas )
            ( dimension = $mat_group_id low = _current_conn-mat_group_id )
          ) )-signeddata.
          if  _current_conn-signeddata is not initial.
            append _current_conn to add_conn_final_output.
          endif.
      endcase.
    endloop.
    transposed_conn->collect( add_conn_final_output ).

    new_data->append( transposed_conn ).

  endmethod.


  method transpose_prices.
    data(prices) = input_data->copy( value #(
        ( dimension = $demrevid_kfs low = sap_price ) ) )->sort( value #(
            ( $time ) ( $matconn ) ) ).

    data(one_off_mapping) = input_data->copy( value #(
    ( dimension = $demrevid_kfs low = mat_remapping ) ) )->sort( value #(
        ( $time )  ( $matremap ) ) ).

    data(conn_prices) = new zcl_bpc_demrevid( environment = env ).
    data(access_products) = product_type_dim->get_children_range( 'PRODUCT_TYPE_ACCESS' ).
    loop at transposed_revenues->model_data into data(_access_revenues)
        where product_type in access_products.
      data(one_off_product) = one_off_mapping->read( value #(
          ( dimension = $time     low = _access_revenues-time )
          ( dimension = $matremap low = _access_revenues-matremap )
      ) )-matconn.
      if one_off_product is not initial.
        data(conn_price) = prices->read( value #(
          ( dimension = $time    low = _access_revenues-time )
          ( dimension = $matconn low = one_off_product )
        ) )-signeddata.

        _access_revenues-demrevid_kfs = conn_price_kf.
        _access_revenues-signeddata = conn_price.
        conn_prices->append( _access_revenues ).
        conn_prices->append( _access_revenues ).
      endif.

      data(access_price) = prices->read( value #(
        ( dimension = $time    low = _access_revenues-time )
        ( dimension = $matconn low = _access_revenues-matremap )
      ) )-signeddata.

      _access_revenues-demrevid_kfs = access_price_kf.
      _access_revenues-signeddata = access_price.
      conn_prices->append( _access_revenues ).

    endloop.

    conn_prices->replaces( value #(
                (
                dimension    = $matremap
                replace_with = 'MATREMAP_NA'
                filters      = value #( ( dimension = $mat_group_id sign = 'E' low = 'MAT_GROUP_ID_NA' ) ) )
    ) ).
    sort conn_prices->model_data by time fflas demrevid_kfs matremap mat_group_id signeddata descending.
    delete adjacent duplicates from conn_prices->model_data comparing time fflas demrevid_kfs matremap mat_group_id.

    new_data->append( conn_prices ).
  endmethod.


  method calc_fflas_ratios_by_material.

    fflas_ratios = new zcl_bpc_demrevid( environment = env ).

    " 1. Base revenue = total SAP Actuals grouped by Category/Time/Account/Matconn, re-tagged
    "    with the audittrail used by this calculation and the FFLAS-ratio-by-Material key figure.
    data(base_revenues) = sap_revenues->copy( )->group( value #(
        ( $category ) ( $time ) ( $account ) ( $matconn ) ( $mat_group_id ) ) )->replaces( value #(
            ( dimension = $audittrail replace_with = audit_dnrid_calc )
            ( dimension = $demrevid_kfs replace_with = kf_fflas_ratios_material ) )
                 ).
    " 2. Exclude Material Groups flagged to skip the FFLAS ratio calculation (parameter FFLASMATGROUPSID).
    "    Before excluding them, keep one flag record per Time/Account/Matconn so DEMREV knows these
    "    materials were skipped and can post their fallback allocation separately (SSNG-3218).
    data(skipped_materials) = new zcl_bpc_demrevid( environment = env ).
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
    " No need of Mat. Group anymore.
    base_revenues->group( include_dimensions = abap_false group_by = value #( ( $mat_group_id ) ) ).

    " 3. FFLAS revenue = Allocated Revenues (DEMREVID023) grouped by the same key plus FFLAS and
    "    MAT_GROUP_ID, so the share of the base revenue attributable to each FFLAS value can be computed.
    data(fflas_rev) = new_data->copy( value #(
            ( dimension = $demrevid_kfs low = kf_fflas_revenue ) ) )->group( value #(
               (        $category ) (       $time ) ( $account ) ( $matconn ) ( $fflas ) ( $mat_group_id ) ) )->replaces( value #(
            ( dimension = $audittrail replace_with = audit_dnrid_calc )
            ( dimension = $demrevid_kfs replace_with = kf_fflas_ratios_material ) ) ).
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

    " 6. Rounding correction: due to floating-point precision in get_ratio / division,
    "    the sum of ratios for a given Time/Account/Matconn may not be exactly 1.
    "    For each combination where the total differs from 1, the discrepancy is added
    "    to the first ratio row found (via binary search). This avoids incorrectly
    "    creating or inflating a FFLASNON row when one doesn't logically belong.
    data(fflas_ratios_cons) = fflas_ratios->copy( )->group(
        include_dimensions = abap_false
        group_by = value #( ( $fflas ) ( $mat_group_id ) ) )->filter( value #(
            ( dimension = $signeddata option = 'NE' low = 1 ) ) ).
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

  endmethod.









endclass.


" END ORIGINAL COMPARISON SNAPSHOT

CLASS ltc_original_compare DEFINITION FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS fflas_original_vs_port FOR TESTING.
    METHODS delta_original_vs_port FOR TESTING.
ENDCLASS.
CLASS ltc_original_compare IMPLEMENTATION.
  METHOD fflas_original_vs_port.
    DO 12 TIMES.
      DATA(scenario) = sy-index.
      DATA legacy_base TYPE zcl_bpc_demrevid=>tabl.
      DATA legacy_alloc TYPE zcl_bpc_demrevid=>tabl.
      CLEAR: legacy_base, legacy_alloc.
      legacy_base = VALUE #( ( category = 'Actual' time = '2025.007' account = '001054200'
        matconn = 'MAT_FIXTURE' mat_group_id = 'MG_NORMAL' demrevid_kfs = 'DEMREVID004' signeddata = 100 ) ).
      legacy_alloc = VALUE #( ( category = 'Actual' time = '2025.007' account = '001054200'
        matconn = 'MAT_FIXTURE' mat_group_id = 'MG_NORMAL' fflas = 'FFLASPQ' demrevid_kfs = 'DEMREVID023' signeddata = 60 )
        ( category = 'Actual' time = '2025.007' account = '001054200' matconn = 'MAT_FIXTURE'
          mat_group_id = 'MG_NORMAL' fflas = 'FFLASID' demrevid_kfs = 'DEMREVID023' signeddata = 25 ) ).
      CASE scenario.
        WHEN 2.
          LOOP AT legacy_base ASSIGNING FIELD-SYMBOL(<b>). <b>-signeddata = - <b>-signeddata. ENDLOOP.
          LOOP AT legacy_alloc ASSIGNING FIELD-SYMBOL(<a>). <a>-signeddata = - <a>-signeddata. ENDLOOP.
        WHEN 3.
          legacy_base[ 1 ]-signeddata = 3.
          legacy_alloc[ 1 ]-signeddata = 1. legacy_alloc[ 2 ]-signeddata = 1.
          APPEND VALUE #( category = 'Actual' time = '2025.007' account = '001054200' matconn = 'MAT_FIXTURE'
            mat_group_id = 'MG_NORMAL' fflas = 'FFLASNON' demrevid_kfs = 'DEMREVID023' signeddata = 1 ) TO legacy_alloc.
        WHEN 4. legacy_base[ 1 ]-signeddata = 0.
        WHEN 5 OR 6.
          legacy_base[ 1 ]-mat_group_id = 'MG_SKIP'.
          LOOP AT legacy_alloc ASSIGNING <a>. <a>-mat_group_id = 'MG_SKIP'. ENDLOOP.
        WHEN 7.
          legacy_base[ 1 ]-signeddata = 40.
          DATA(extra_base) = legacy_base[ 1 ]. extra_base-signeddata = 60. APPEND extra_base TO legacy_base.
        WHEN 8.
          extra_base = legacy_base[ 1 ]. extra_base-account = '001081800'. extra_base-matconn = 'MAT_OTHER'.
          extra_base-signeddata = 200. APPEND extra_base TO legacy_base.
        WHEN 9. CLEAR legacy_alloc.
        WHEN 10. legacy_alloc[ 1 ]-signeddata = 120.
        WHEN 11.
          extra_base = legacy_base[ 1 ]. extra_base-mat_group_id = 'MG_SKIP'.
          extra_base-signeddata = 50. APPEND extra_base TO legacy_base.
        WHEN 12. CLEAR: legacy_base, legacy_alloc.
      ENDCASE.
      DATA(original) = NEW lcl_original_demrevid( ).
      DATA(port) = NEW zcl_bn_dem_alloc( ).
      port->env = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( )
        dependencies = VALUE #( ) cell_id = 'comparison' ).
      original->sap_revenues = NEW zcl_bpc_demrevid( model_data = legacy_base compressed = abap_false ).
      original->new_data = NEW zcl_bpc_demrevid( model_data = legacy_alloc compressed = abap_false ).
      port->sap_revenues = NEW zcl_bn_dem_model( environment = port->env
        model_data = CORRESPONDING zcl_bn_dem_model=>tabl( legacy_base ) compressed = abap_false ).
      port->new_data = NEW zcl_bn_dem_model( environment = port->env
        model_data = CORRESPONDING zcl_bn_dem_model=>tabl( legacy_alloc ) compressed = abap_false ).
      IF scenario = 5 OR scenario = 11.
        original->skip_fflas_ratio_mat_group_id = VALUE #( ( sign = 'I' option = 'EQ' low = 'MG_SKIP' ) ).
        port->skip_fflas_ratio_mat_group_id = original->skip_fflas_ratio_mat_group_id.
      ENDIF.
      DATA(expected_model) = original->calc_fflas_ratios_by_material( ).
      DATA(actual_model) = port->calc_fflas_ratios_by_material( ).
      DATA(expected) = CORRESPONDING zcl_bn_dem_model=>tabl( expected_model->model_data ).
      DATA(actual) = actual_model->model_data.
      SORT expected. SORT actual.
      cl_abap_unit_assert=>assert_equals( act = actual exp = expected
        msg = |Original vs port FFLAS scenario { scenario }: every dimension and native amount| ).
    ENDDO.
  ENDMETHOD.
  METHOD delta_original_vs_port.
    DATA previous TYPE zcl_bpc_demrevid=>tabl.
    DATA proposed TYPE zcl_bpc_demrevid=>tabl.
    previous = VALUE #( ( category = 'Actual' time = '2025.007' account = 'CHANGED' signeddata = 100 )
      ( category = 'Actual' time = '2025.007' account = 'SAME' signeddata = 100 )
      ( category = 'Actual' time = '2025.007' account = 'GONE' signeddata = -50 ) ).
    proposed = VALUE #( ( category = 'Actual' time = '2025.007' account = 'CHANGED' signeddata = 120 )
      ( category = 'Actual' time = '2025.007' account = 'SAME' signeddata = 100 )
      ( category = 'Actual' time = '2025.007' account = 'NEW' signeddata = -25 ) ).
    DATA(old_original) = NEW zcl_bpc_demrevid( model_data = previous ).
    DATA(new_original) = NEW zcl_bpc_demrevid( model_data = proposed ).
    new_original->compare_delta( old_original ).
    DATA(io) = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'delta' ).
    DATA(old_port) = NEW zcl_bn_dem_model( environment = io model_data = CORRESPONDING #( previous ) ).
    DATA(new_port) = NEW zcl_bn_dem_model( environment = io model_data = CORRESPONDING #( proposed ) ).
    new_port->compare_delta( old_port ).
    DATA(expected) = CORRESPONDING zcl_bn_dem_model=>tabl( new_original->model_data ).
    DATA(actual) = new_port->model_data.
    SORT expected. SORT actual.
    cl_abap_unit_assert=>assert_equals( act = actual exp = expected msg = 'Original replacement change-set across all dimensions' ).
    cl_abap_unit_assert=>assert_equals( act = lines( actual ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = actual[ account = 'CHANGED' ]-signeddata exp = CONV uj_signeddata( 120 ) ).
    cl_abap_unit_assert=>assert_equals( act = actual[ account = 'GONE' ]-signeddata exp = CONV uj_signeddata( 0 ) ).
    cl_abap_unit_assert=>assert_equals( act = actual[ account = 'NEW' ]-signeddata exp = CONV uj_signeddata( -25 ) ).
  ENDMETHOD.
ENDCLASS.
