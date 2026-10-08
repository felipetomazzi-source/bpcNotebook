// Run a read-only BAdI integration fixture in SAP DEV; business CT_DATA stays unchanged.
const fs=require('node:fs'),assert=require('node:assert/strict'),api=require('./bpc-api.cjs'),c=require('./adt-config.cjs')();
const q=s=>"'"+s.replaceAll("'","''")+"'";
(async()=>{
 const seedId=process.argv.find(a=>a.startsWith('--notebook='))?.slice(11);
 assert(seedId,'Supply --notebook=<saved notebook with CATEGORY/TIME selections>');
 const seed=await api('/notebook?id='+seedId,null,'GET');
 const category=seed.inputs.find(p=>p.name==='CATEGORY'),time=seed.inputs.find(p=>p.name==='TIME');
 assert(category?.selected?.length===1&&time?.resolved?.length);
 const n=await api('/notebooks',{title:'Script Logic handler - SAP verification',environment:seed.environment,model:seed.model,
  inputs:[category,time,{name:'factor',type:'number',value:'1'},{name:'suppress',type:'boolean',value:'false'},{name:'label',type:'string',value:'default'}],
  cells:[{id:'seed',title:'Frozen parameters',dependencies:[],source:
   "DATA rows TYPE zcl_bn_context=>tt_rows.\nAPPEND VALUE #( key = io->input( 'label' ) amount = CONV decfloat34( io->input( 'factor' ) ) ) TO rows.\nio->emit( rows ).\nio->message( io->input( 'suppress' ) )."},
   {id:'apply',title:'Dependency and caller scope',dependencies:['seed'],source:
   "DATA rows TYPE zcl_bn_context=>tt_rows.\nrows = io->read( 'seed' ).\nLOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).\n <row>-amount = <row>-amount * CONV decfloat34( io->input( 'factor' ) ).\nENDLOOP.\nio->emit( rows ).\nDATA cv TYPE ujk_t_cv.\ncv = io->current_view( ).\nIF lines( cv ) < 2.\n RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST_SCOPE' detail = 'Caller scope missing'.\nENDIF."}]});
 const handlerName='BN_LOGIC_VERIFY';let previous;
 try{previous=await api('/logic-handler?id='+handlerName,null,'GET');}catch(e){if(!e.message.includes('NOT_FOUND'))throw e;}
 console.log('Registering handler',previous?.revision||0,n.id);
 const handler=await api('/logic-handler',{handler:handlerName,notebookId:n.id,expectedRevision:n.revision,handlerRevision:previous?.revision||0});
 console.log('Registered handler',JSON.stringify(handler));
 await assert.rejects(api('/logic-handler',{handler:handlerName,notebookId:n.id,expectedRevision:n.revision,handlerRevision:0}),/CONFLICT/);
 const changed=structuredClone(n);changed.cells[0].source="io->message( 'NEW revision must not run' ).";
 const newer=await api('/notebook',{...changed,expectedRevision:n.revision},'PUT');assert.equal(newer.revision,n.revision+1);
 const cv=`VALUE ujk_t_cv( ( dimension = ${q(category.dimension)} dim_upper_case = ${q(category.dimension.toUpperCase())} user_specified = abap_true member = VALUE #( ( ${q(category.selected[0])} ) ) ) ( dimension = ${q(time.dimension)} dim_upper_case = ${q(time.dimension.toUpperCase())} user_specified = abap_true member = VALUE #( ( ${q(time.resolved[0])} ) ) ) )`;
 const params=`VALUE ujk_t_script_logic_hashtable( ( hashkey = 'HANDLER' hashvalue = '${handlerName}' ) ( hashkey = 'QUERY' hashvalue = 'OFF' ) ( hashkey = 'WRITE' hashvalue = 'OFF' ) ( hashkey = 'INPUT_FACTOR' hashvalue = '2' ) ( hashkey = 'INPUT_SUPPRESS' hashvalue = 'ON' ) ( hashkey = 'INPUT_LABEL' hashvalue = 'É · São — handler' ) )`;
 let source=`CLASS zcl_bn_logic_check DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION. INTERFACES if_oo_adt_classrun.
ENDCLASS.
CLASS zcl_bn_logic_check IMPLEMENTATION.
 METHOD if_oo_adt_classrun~main.
  TRY.
   DATA badi TYPE REF TO badi_uj_custom_logic.
   GET BADI badi FILTERS custom_logic_name = 'NOTEBOOK'.
   DATA params TYPE ujk_t_script_logic_hashtable.
   params = ${params}.
   DATA cv TYPE ujk_t_cv.
   cv = ${cv}.
   DATA data TYPE zcl_bn_context=>tt_rows.
   data = VALUE #( ( key = 'Keep BPC CT_DATA' amount = 77 ) ).
   DATA original TYPE zcl_bn_context=>tt_rows.
   original = data.
   DATA messages TYPE uj0_t_message.
   CALL BADI badi->init EXPORTING i_appset_id = ${q(seed.environment)} i_appl_id = ${q(seed.model)} it_param = params.
   CALL BADI badi->execute EXPORTING i_appset_id = ${q(seed.environment)} i_appl_id = ${q(seed.model)} it_param = params it_cv = cv IMPORTING et_message = messages CHANGING ct_data = data.
   ASSERT data = original.
   DATA run_id TYPE string.
   run_id = messages[ 1 ]-message+13(32).
   DATA(run) = zcl_bn_service=>get_run( run_id ).
   ASSERT run-state = 'succeeded' AND run-snapshot-revision = ${n.revision} AND lines( run-results ) = 2.
   ASSERT run-current_view = cv AND run-handler_revision = ${handler.revision}.
   ASSERT run-snapshot-inputs[ name = 'factor' ]-value = '2'.
   ASSERT run-snapshot-inputs[ name = 'suppress' ]-value = 'true'.
   ASSERT run-snapshot-inputs[ name = 'label' ]-value = 'É · São — handler'.
   ASSERT lines( run-snapshot-inputs[ name = 'TIME' ]-resolved ) = 1.
   DATA payload TYPE string.
   payload = zcl_bn_store=>read( kind = 'D' id = |{ run_id }:apply| ).
   DATA dataset TYPE zcl_bn_service=>ty_dataset.
   /ui2/cl_json=>deserialize( EXPORTING json = payload pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = dataset ).
   ASSERT dataset-rows[ 1 ]-amount = 4 AND dataset-rows[ 1 ]-key = 'É · São — handler'.
   ROLLBACK WORK.
   ASSERT zcl_bn_store=>current( kind = 'R' id = run_id ) = 0.
   ASSERT zcl_bn_store=>current( kind = 'D' id = |{ run_id }:apply| ) = 0.
   out->write( 'BNCHECK|native NOTEBOOK filter, pinned revision, two cells, typed parameters, CV, CT_DATA unchanged, caller rollback' ).
   DO 9 TIMES.
    DATA bad TYPE ujk_t_script_logic_hashtable.
    bad = params.
    DATA bad_cv TYPE ujk_t_cv.
    bad_cv = cv.
    DATA expected TYPE string.
    CASE sy-index.
     WHEN 1. bad[ hashkey = 'WRITE' ]-hashvalue = 'ON'. expected = 'LOGIC_WRITE'.
     WHEN 2. DELETE bad WHERE hashkey = 'WRITE'. expected = 'LOGIC_WRITE'.
     WHEN 3. INSERT VALUE #( hashkey = 'INPUT_UNKNOWN' hashvalue = '1' ) INTO TABLE bad. expected = 'LOGIC_INPUT'.
     WHEN 4. bad[ hashkey = 'INPUT_FACTOR' ]-hashvalue = 'garbage'. expected = 'INPUT_TYPE'.
     WHEN 5. INSERT VALUE #( hashkey = 'input_factor' hashvalue = '3' ) INTO TABLE bad. expected = 'LOGIC_INPUT'.
     WHEN 6. INSERT VALUE #( hashkey = 'INPUT_TIME' hashvalue = ${q(time.selected[0])} ) INTO TABLE bad. expected = 'LOGIC_CV'.
     WHEN 7. bad_cv[ dimension = ${q(time.dimension)} ]-member = VALUE #( ( 'NOT_A_BPC_MEMBER' ) ). expected = 'BPC_AUTH'.
     WHEN 8. bad[ hashkey = 'WRITE' ]-hashvalue = 'off'. expected = 'LOGIC_WRITE'.
     WHEN 9. DELETE bad WHERE hashkey = 'WRITE'.
       INSERT VALUE #( hashkey = 'write' hashvalue = 'OFF' ) INTO TABLE bad. expected = 'LOGIC_WRITE'.
    ENDCASE.
    TRY.
      CALL BADI badi->execute EXPORTING i_appset_id = ${q(seed.environment)} i_appl_id = ${q(seed.model)} it_param = bad it_cv = bad_cv IMPORTING et_message = messages CHANGING ct_data = data.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST_FAILED' detail = |Expected rejection { expected }|.
     CATCH cx_uj_custom_logic INTO DATA(rejected).
      ASSERT rejected->datavalue CS expected.
      ASSERT rejected->get_text( ) CS expected.
    ENDTRY.
    ASSERT data = original.
    ROLLBACK WORK.
    out->write( 'BNCHECK|rejected ' && expected ).
   ENDDO.
   CALL BADI badi->execute EXPORTING i_appset_id = ${q(seed.environment)} i_appl_id = ${q(seed.model)} it_param = params it_cv = cv IMPORTING et_message = messages CHANGING ct_data = data.
   run_id = messages[ 1 ]-message+13(32).
   COMMIT WORK AND WAIT.
   CALL BADI badi->cleanup.
   out->write( 'BNRUN|' && run_id ).
  CATCH cx_root INTO DATA(error).
   ROLLBACK WORK.
   out->write( 'BNERROR|' && error->get_text( ) ).
  ENDTRY.
 ENDMETHOD.
ENDCLASS.`;
 source=source.replace(/ (dimension|dim_upper_case|user_specified|member|hashkey|hashvalue|EXPORTING|IMPORTING|CHANGING) =? ?/g,(match)=>'\n'+match.trimStart());
 assert(source.split(/\r?\n/).every(line=>line.length<=255),'Native fixture source line exceeds SAP limit');
 fs.mkdirSync('.local',{recursive:true});fs.writeFileSync('.local/logic-check.abap',source,'utf8');
 await c.login();c.stateful='stateful';try{
  const name='ZCL_BN_LOGIC_CHECK',url='/sap/bc/adt/oo/classes/zcl_bn_logic_check';
  if(!(await c.searchObject(name,'',10)).some(o=>o['adtcore:name']===name))await c.createObject('CLAS/OC',name,'$TMP','Notebook BAdI integration verification','/sap/bc/adt/packages/%24tmp');
  const {LOCK_HANDLE}=await c.lock(url);try{await c.setObjectSource(url+'/source/main',source,LOCK_HANDLE);}finally{await c.unLock(url,LOCK_HANDLE);}
  const activation=await c.activate(name,url);assert(activation.success,JSON.stringify(activation));
  const output=await c.runClass(name);console.log(output);assert(!output.includes('BNERROR|'),output);
  const runId=output.match(/BNRUN\|([A-F0-9]{32})/)?.[1];assert(runId,output);
  const run=await api('/run?id='+runId,null,'GET');assert.equal(run.state,'succeeded');assert.equal(run.snapshot.revision,n.revision);
  const outputRows=await api('/output?runId='+runId+'&cellId=apply&revision=1&limit=20',null,'GET');assert.equal(Number(outputRows.rows[0].amount),4);
  const unit=await c.unitTestRun('/sap/bc/adt/oo/classes/zcl_bn_bpc');
  assert.equal(unit.flatMap(t=>t.testmethods).length,6,'Expected all six native adapter/context tests');
  assert(unit.every(t=>t.alerts.length===0&&t.testmethods.every(m=>m.alerts.length===0)),JSON.stringify(unit));
  const evidence={at:new Date().toISOString(),passed:true,handler,notebookId:n.id,latestNotebookRevision:newer.revision,runId,checks:output.trim().split(/\r?\n/),nativeUnitTests:6,output:outputRows};
  const scriptHandler=process.argv.find(a=>a.startsWith('--script-handler='))?.slice(17);
  if(scriptHandler){
   assert(/^[A-Z][A-Z0-9_]{0,29}$/.test(scriptHandler));
   const scriptSource=`CLASS zcl_bn_logic_check DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION. INTERFACES if_oo_adt_classrun.
ENDCLASS.
CLASS zcl_bn_logic_check IMPLEMENTATION.
 METHOD if_oo_adt_classrun~main.
  TRY.
   DATA(binding) = zcl_bn_logic=>binding( '${scriptHandler}' ).
   DATA(payload) = zcl_bn_store=>read( kind = 'N' id = binding-notebook_id revision = binding-notebook_revision ).
   DATA notebook TYPE zcl_bn_types=>ty_notebook.
   /ui2/cl_json=>deserialize( EXPORTING json = payload pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = notebook ).
   DATA(cv) = zcl_bn_bpc=>current_view( notebook-inputs ).
   DATA params TYPE ujk_t_script_logic_hashtable.
   params = VALUE #( ( hashkey = 'HANDLER' hashvalue = '${scriptHandler}' )
     ( hashkey = 'QUERY' hashvalue = 'OFF' ) ( hashkey = 'WRITE' hashvalue = 'OFF' )
     ( hashkey = 'INPUT_FACTOR' hashvalue = '2' ) ).
   DATA badi TYPE REF TO badi_uj_custom_logic.
   GET BADI badi FILTERS custom_logic_name = 'NOTEBOOK'.
   DATA messages TYPE uj0_t_message.
   DATA data TYPE zcl_bn_context=>tt_rows.
   DATA appset TYPE uj_appset_id.
   DATA model TYPE uj_appl_id.
   appset = binding-environment. model = binding-model.
   CALL BADI badi->execute EXPORTING i_appset_id = appset
     i_appl_id = model it_param = params it_cv = cv
     IMPORTING et_message = messages CHANGING ct_data = data.
   COMMIT WORK AND WAIT.
   out->write( 'BNRUN|' && messages[ 1 ]-message+13(32) ).
  CATCH cx_root INTO DATA(error).
   ROLLBACK WORK. out->write( 'BNERROR|' && error->get_text( ) ).
  ENDTRY.
 ENDMETHOD.
ENDCLASS.`;
   const scriptName='ZCL_BN_SCRIPT_LOGIC_CHECK',scriptUrl='/sap/bc/adt/oo/classes/zcl_bn_script_logic_check';
   if(!(await c.searchObject(scriptName,'',10)).some(o=>o['adtcore:name']===scriptName))await c.createObject('CLAS/OC',scriptName,'$TMP','Notebook Script BAdI verification','/sap/bc/adt/packages/%24tmp');
   const lock=await c.lock(scriptUrl);try{await c.setObjectSource(scriptUrl+'/source/main',scriptSource.replaceAll('zcl_bn_logic_check','zcl_bn_script_logic_check'),lock.LOCK_HANDLE);}finally{await c.unLock(scriptUrl,lock.LOCK_HANDLE);}
   const active=await c.activate(scriptName,scriptUrl);assert(active.success,JSON.stringify(active));
   const proof=await c.runClass(scriptName);assert(!proof.includes('BNERROR|'),proof);const scriptId=proof.match(/BNRUN\|([A-F0-9]{32})/)?.[1];assert(scriptId,proof);
   const sr=await api('/run?id='+scriptId,null,'GET');assert.equal(sr.state,'succeeded');assert.equal(sr.results.length,4);
   const preview=await api('/output?runId='+scriptId+'&cellId=script0&revision=1&limit=20&table=ALLOCATION',null,'GET');
   assert.deepEqual(preview.rows.map(r=>Number(r.values[1])),[120000,72000,48000]);
   evidence.scriptRun={handler:scriptHandler,runId:scriptId,notebookRevision:sr.snapshot.revision,cells:sr.results.length,output:preview};
   console.log('Notebook Script BAdI run',scriptId,'four cells, factor override 2');
  }
  fs.writeFileSync('docs/evidence/notebook-logic.json',JSON.stringify(evidence,null,2)+'\n','utf8');
 }finally{await c.logout();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
