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
