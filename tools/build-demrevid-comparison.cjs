// Test-only original source snapshot; never change the customer calculation for instrumentation.
const fs=require('node:fs'),{execFileSync}=require('node:child_process'),crypto=require('node:crypto');
const root=process.argv.find(a=>a.startsWith('--chorus='))?.slice(9)||'C:/Users/FelipeTomazzi/chorus-workspace/chorus_bpc';
const sourcePath='src/zbpc_demrevid/zcl_bpc_demrevid_calc_003.clas.abap';
const baseline=execFileSync('git',['show','2796a7f:'+sourcePath],{cwd:root,encoding:'utf8',maxBuffer:2e6});
const path='src/zcl_bn_dem_alloc.clas.testclasses.abap';
let current=fs.readFileSync(path,'utf8').replace(/\r\n/g,'\n');
const marker='" BEGIN ORIGINAL COMPARISON SNAPSHOT';
if(current.includes(marker))throw Error('Comparison already generated; update deliberately, do not append twice');
let original=baseline.replace(/zcl_bpc_demrevid_calc_003/gi,'lcl_original_demrevid')
  .replace(/class lcl_original_demrevid definition public/i,'class lcl_original_demrevid definition');
original=original.replace(/create public/i,'create public friends ltc_original_compare');
const compare=`
class ltc_original_compare definition deferred.
class zcl_bn_dem_alloc definition local friends ltc_original_compare.
${marker}
INCLUDE zi_dim_names.
" Customer source 2796a7f, class identity changed only for ABAP Unit isolation.
${original}
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
    DATA(old_port) = NEW zcl_bn_dem_model( environment = io model_data = CORRESPONDING zcl_bn_dem_model=>tabl( previous ) ).
    DATA(new_port) = NEW zcl_bn_dem_model( environment = io model_data = CORRESPONDING zcl_bn_dem_model=>tabl( proposed ) ).
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
`;
fs.writeFileSync(path,(current+'\n'+compare).replace(/\r?\n/g,'\r\n'));
fs.writeFileSync('docs/demrevid-comparison-baseline.json',JSON.stringify({
  originalRepository:'chorus_bpc',originalCommit:'2796a7f',sourcePath,
  originalGitBlob:execFileSync('git',['rev-parse','2796a7f:'+sourcePath],{cwd:root,encoding:'utf8'}).trim(),
  originalSourceSha256:crypto.createHash('sha256').update(baseline).digest('hex'),
  isolation:'Test-only local class identity; original business method bodies retained. No original BAdI execution or business reads/writes.',
  coverage:['12 original-versus-port FFLAS cases','Original-versus-port replacement change-set'],
  businessEquivalent:false
},null,2)+'\n');
console.log('Generated original-source comparison tests');
