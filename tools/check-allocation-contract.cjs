// Tests the synchronous NOTEBOOK BAdI without invoking SAP writeback or changing model facts.
process.argv.push('--codex-env');
const fs=require('fs'),assert=require('node:assert/strict'),api=require('./bpc-api.cjs'),c=require('./adt-config.cjs')();
(async()=>{
 const seed=JSON.parse(fs.readFileSync('.local/allocation-notebook.json','utf8'));
 const inputs=seed.inputs.filter(x=>['CATEGORY','TIME','REFERENCE_TIME'].includes(x.name));
 inputs.push({name:'fail',type:'boolean',value:'false'},{name:'badScope',type:'boolean',value:'false'});
 const source=`DATA adapter TYPE REF TO zcl_bn_bpc.
adapter = io->reference_model( ).
DATA facts TYPE REF TO data.
facts = adapter->read_data( max_rows = 1000000 ).
FIELD-SYMBOLS <facts> TYPE STANDARD TABLE.
ASSIGN facts->* TO <facts>.
IF <facts> IS INITIAL.
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST_FIXTURE' detail = 'Nonempty authorized facts required'.
ENDIF.
DATA rows TYPE zcl_bn_dem_model=>tabl.
rows = CORRESPONDING #( <facts> ).
DELETE rows FROM 2.
rows[ 1 ]-signeddata = '-67.1234567'.
IF io->input( 'badScope' ) = 'true'. rows[ 1 ]-time = 'TIME_NA'. ENDIF.
io->allocation_result( name = 'TEST_DELTA' rows = rows kind = 'delta' ).
IF io->input( 'fail' ) = 'true'.
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST_FAILURE' detail = 'Fail after result construction'.
ENDIF.`;
 const notebook=await api('/notebooks',{title:'Allocation CT_DATA contract verification',environment:seed.environment,model:seed.model,inputs,
  cells:[{id:'result',title:'Native result contract fixture',source,dependencies:[]}]});
 const name='BN_ALLOCATION_VERIFY';let previous=0;try{previous=(await api('/logic-handler?id='+name,null,'GET')).revision;}catch(e){if(!e.message.includes('NOT_FOUND'))throw e;}
 const binding=await api('/logic-handler',{handler:name,notebookId:notebook.id,expectedRevision:notebook.revision,handlerRevision:previous,executionMode:'allocation'});
 const text=`CLASS zcl_bn_alloc_check DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION. INTERFACES if_oo_adt_classrun.
ENDCLASS.
CLASS zcl_bn_alloc_check IMPLEMENTATION.
 METHOD if_oo_adt_classrun~main.
  TRY.
   DATA badi TYPE REF TO badi_uj_custom_logic.
   GET BADI badi FILTERS custom_logic_name = 'NOTEBOOK'.
   DATA params TYPE ujk_t_script_logic_hashtable.
   params = VALUE #( ( hashkey = 'HANDLER' hashvalue = '${name}' )
    ( hashkey = 'QUERY' hashvalue = 'OFF' ) ( hashkey = 'WRITE' hashvalue = 'ON' )
    ( hashkey = 'EXECUTION' hashvalue = 'ALLOCATION' ) ( hashkey = 'READ_REFERENCES' hashvalue = 'DECLARED' ) ).
   DATA cv TYPE ujk_t_cv.
   cv = VALUE #( ( dimension = 'CATEGORY' dim_upper_case = 'CATEGORY' member = VALUE #( ( 'Actual' ) ) )
    ( dimension = 'TIME' dim_upper_case = 'TIME' member = VALUE #( ( '${inputs.find(x=>x.name==='TIME').resolved[0]}' ) ) ) ).
   DATA data TYPE zcl_bn_dem_model=>tabl.
   data = VALUE #( ( account = 'KEEP' signeddata = 77 ) ).
   DATA(original) = data.
   DATA messages TYPE uj0_t_message.
   CALL BADI badi->execute EXPORTING i_appset_id = 'CH_PLANNING' i_appl_id = 'DEMREVID'
    it_param = params it_cv = cv IMPORTING et_message = messages CHANGING ct_data = data.
   ASSERT lines( data ) = 1 AND data[ 1 ]-signeddata = CONV uj_signeddata( '-67.1234567' ).
   ASSERT data[ 1 ]-time = '${inputs.find(x=>x.name==='TIME').resolved[0]}'.
   DATA run_id TYPE string. run_id = messages[ 1 ]-message+13(32).
   DATA(run) = zcl_bn_service=>get_run( run_id ).
   ASSERT run-state = 'succeeded' AND run-handler_revision = ${binding.revision}.
   ASSERT run-snapshot-inputs[ name = 'REFERENCE_TIME' ]-purpose = 'reference'.
   ROLLBACK WORK.
   ASSERT zcl_bn_store=>current( kind = 'R' id = run_id ) = 0.
   ASSERT zcl_bn_store=>current( kind = 'D' id = |{ run_id }:result| ) = 0.
   out->write( 'BNCHECK|nonempty typed CT_DATA result, frozen references, caller rollback, no business writeback invoked' ).
   data = original.
   params[ hashkey = 'EXECUTION' ]-hashvalue = 'PREVIEW'. params[ hashkey = 'WRITE' ]-hashvalue = 'OFF'.
   CALL BADI badi->execute EXPORTING i_appset_id = 'CH_PLANNING' i_appl_id = 'DEMREVID'
    it_param = params it_cv = cv IMPORTING et_message = messages CHANGING ct_data = data.
   ASSERT data = original. ROLLBACK WORK.
   out->write( 'BNCHECK|preview ignores allocation result and preserves CT_DATA' ).
   params[ hashkey = 'EXECUTION' ]-hashvalue = 'ALLOCATION'. params[ hashkey = 'WRITE' ]-hashvalue = 'ON'.
   DO 4 TIMES.
    DATA bad TYPE ujk_t_script_logic_hashtable. bad = params.
    DATA expected TYPE string.
    CASE sy-index.
     WHEN 1. INSERT VALUE #( hashkey = 'INPUT_FAIL' hashvalue = 'ON' ) INTO TABLE bad. expected = 'TEST_FAILURE'.
     WHEN 2. DELETE bad WHERE hashkey = 'READ_REFERENCES'. expected = 'REFERENCE_POLICY'.
     WHEN 3. INSERT VALUE #( hashkey = 'INPUT_REFERENCE_TIME' hashvalue = 'TIME_NA' ) INTO TABLE bad. expected = 'REFERENCE_POLICY'.
     WHEN 4. INSERT VALUE #( hashkey = 'INPUT_BADSCOPE' hashvalue = 'ON' ) INTO TABLE bad. expected = 'RESULT_SCOPE'.
    ENDCASE.
    TRY.
      CALL BADI badi->execute EXPORTING i_appset_id = 'CH_PLANNING' i_appl_id = 'DEMREVID'
       it_param = bad it_cv = cv IMPORTING et_message = messages CHANGING ct_data = data.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST_FAILED' detail = |Expected rejection { expected }|.
     CATCH cx_uj_custom_logic INTO DATA(rejected). ASSERT rejected->datavalue CS expected.
    ENDTRY.
    ASSERT data = original. ROLLBACK WORK.
    out->write( 'BNCHECK|failure preserves caller data: ' && expected ).
   ENDDO.
  CATCH cx_root INTO DATA(error).
   ROLLBACK WORK. out->write( 'BNERROR|' && error->get_text( ) ).
  ENDTRY.
 ENDMETHOD.
ENDCLASS.`;
 assert(text.split('\n').every(x=>x.length<=255));
 await c.login();c.stateful='stateful';try{
  const cls='ZCL_BN_ALLOC_CHECK',url='/sap/bc/adt/oo/classes/zcl_bn_alloc_check';
  if(!(await c.searchObject(cls,'',10)).some(x=>x['adtcore:name']===cls))await c.createObject('CLAS/OC',cls,'$TMP','Allocation caller transaction verification','/sap/bc/adt/packages/%24tmp');
  const {LOCK_HANDLE}=await c.lock(url);try{await c.setObjectSource(url+'/source/main',text,LOCK_HANDLE);}finally{await c.unLock(url,LOCK_HANDLE);}
  assert((await c.activate(cls,url)).success,'Native verification activation failed');
  const output=await c.runClass(cls);console.log(output);assert(!output.includes('BNERROR|'),output);
  const checks=output.split(/\r?\n/).filter(x=>x.startsWith('BNCHECK|'));assert.equal(checks.length,6);
  fs.writeFileSync('.local/allocation-contract-evidence.json',JSON.stringify({at:new Date().toISOString(),passed:true,notebookId:notebook.id,binding,checks,businessFactsWritten:false},null,2),'utf8');
 }finally{await c.logout();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
