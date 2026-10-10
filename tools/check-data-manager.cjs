// Native DEV contract check and a nonposting notebook used by the DM package test.
const fs=require('node:fs'),assert=require('node:assert/strict'),api=require('./bpc-api.cjs'),c=require('./adt-config.cjs')();
const q=s=>"'"+s.replaceAll("'","''")+"'";
(async()=>{
 const seedId=process.argv.find(x=>x.startsWith('--notebook='))?.slice(11);assert(seedId,'Supply an existing saved CATEGORY/TIME notebook as metadata seed');
 const seed=await api('/notebook?id='+seedId,null,'GET');
 const cat=seed.inputs.find(x=>x.name==='CATEGORY'),period=seed.inputs.find(x=>x.name==='TIME');
 assert(cat?.selected?.length===1&&period?.resolved?.length,'Seed needs CATEGORY and resolved TIME');
 const category=structuredClone(cat),time=structuredClone(period);time.selected=[period.resolved[0]];time.resolved=[];time.fiscalLinks=[];
 const n=await api('/notebooks',{technicalName:'BN_DM_TEST_'+Date.now().toString(36).toUpperCase(),description:'DEV verification of direct Data Manager execution; no financial posting',title:'Data Manager direct notebook - DEV verification',environment:seed.environment,model:seed.model,
  inputs:[category,time,{name:'factor',type:'number',value:'1'},{name:'label',type:'string',value:'default'}],
  cells:[{id:'calculate',title:'Read typed package inputs',dependencies:[],source:"DATA rows TYPE zcl_bn_context=>tt_rows.\nAPPEND VALUE #( key = io->input( 'label' ) amount = CONV decfloat34( io->input( 'factor' ) ) ) TO rows.\nio->emit( rows ).\nio->message( 'Direct Data Manager preview; no business posting' )."},
   {id:'apply',title:'Verify dependency and scope',dependencies:['calculate'],source:"DATA rows TYPE zcl_bn_context=>tt_rows.\nrows = io->read( 'calculate' ).\nLOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).\n <row>-amount = <row>-amount * CONV decfloat34( io->input( 'factor' ) ).\nENDLOOP.\nio->emit( rows ).\nIF lines( io->current_view( ) ) <> 2.\n RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_TEST_SCOPE' detail = 'Expected CATEGORY and TIME scope'.\nENDIF."}]});
 const handlerName='BN_DM_VERIFY';let prior;try{prior=await api('/logic-handler?id='+handlerName,null,'GET')}catch(e){assert(e.message.includes('NOT_FOUND'),e.message)}
 const handler=await api('/logic-handler',{handler:handlerName,notebookId:n.id,expectedRevision:n.revision,handlerRevision:prior?.revision||0});
 const selection='@@@SAVE@@@@@@EXPAND@@@|DIMENSION:'+category.dimension+'|'+category.selected[0]+'|DIMENSION:'+time.dimension+'|'+period.resolved[0]+'|';
 // A later notebook edit must not change the pinned package execution.
 const edited=structuredClone(n);edited.cells[0].source="RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'UNREVIEWED' detail = 'Do not execute this later edit'.";
 await api('/notebook',{...edited,expectedRevision:n.revision},'PUT');
 const source=`CLASS zcl_bn_dm_check DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION. INTERFACES if_oo_adt_classrun.
ENDCLASS.
CLASS zcl_bn_dm_check IMPLEMENTATION.
 METHOD if_oo_adt_classrun~main.
  TRY.
   cl_uj_context=>set_cur_context( i_appset_id = ${q(seed.environment)} i_appl_id = ${q(seed.model)} is_user = VALUE #( user_id = sy-uname langu = sy-langu ) ).
   DATA(scope) = zcl_bn_dm=>selection( ${q(selection)} ).
   ASSERT lines( scope ) = 2.
   DATA(params) = zcl_bn_dm=>parameters( 'INPUT_FACTOR=2|INPUT_LABEL=É · São = DM' ).
   DATA(run) = zcl_bn_dm=>preview( handler = '${handlerName}' handler_revision = ${handler.revision}
     environment = ${q(seed.environment)} model = ${q(seed.model)} scope = scope overrides = params ).
   ASSERT run-state = 'succeeded' AND run-snapshot-revision = ${n.revision} AND lines( run-results ) = 2.
   ASSERT run-current_view = scope AND run-handler_revision = ${handler.revision}.
   DATA payload TYPE string.
   payload = zcl_bn_store=>read( kind = 'D' id = |{ run-id }:apply| ).
   DATA dataset TYPE zcl_bn_service=>ty_dataset.
   /ui2/cl_json=>deserialize( EXPORTING json = payload pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = dataset ).
   ASSERT dataset-rows[ 1 ]-amount = 4 AND dataset-rows[ 1 ]-key = 'É · São = DM'.
   ROLLBACK WORK.
   ASSERT zcl_bn_store=>current( kind = 'R' id = run-id ) = 0.
   out->write( 'BNCHECK|selection, typed Unicode inputs, two cells, revision pin, caller rollback' ).
   DO 6 TIMES.
    TRY.
     CASE sy-index.
      WHEN 1. params = zcl_bn_dm=>parameters( 'WRITE=ON' ).
      WHEN 2. params = zcl_bn_dm=>parameters( 'INPUT_FACTOR=2|input_factor=3' ).
      WHEN 3. params = zcl_bn_dm=>parameters( 'INPUT_FACTOR' ).
      WHEN 4. DATA(empty) = zcl_bn_dm=>selection( '' ).
      WHEN 5. run = zcl_bn_dm=>preview( handler = '${handlerName}' handler_revision = ${handler.revision+1}
        environment = ${q(seed.environment)} model = ${q(seed.model)} scope = scope overrides = VALUE #( ) ).
      WHEN 6. run = zcl_bn_dm=>preview( handler = '${handlerName}' handler_revision = ${handler.revision}
        environment = ${q(seed.environment)} model = ${q(seed.model)} scope = VALUE #( ) overrides = VALUE #( ) ).
     ENDCASE.
     out->write( 'BNERROR|Invalid request accepted' ). RETURN.
    CATCH zcx_bn. ROLLBACK WORK.
    ENDTRY.
   ENDDO.
   out->write( 'BNCHECK|posting attempt, duplicate and malformed overrides, empty selection/scope, stale revision rejected' ).
  CATCH zcx_bn INTO DATA(fault). ROLLBACK WORK. out->write( 'BNERROR|' && fault->code && ': ' && fault->detail ).
  CATCH cx_root INTO DATA(error). ROLLBACK WORK. out->write( 'BNERROR|' && error->get_text( ) ).
  ENDTRY.
 ENDMETHOD.
ENDCLASS.`;
 await c.login();c.stateful='stateful';let proof;try{
  const name='ZCL_BN_DM_CHECK',url='/sap/bc/adt/oo/classes/zcl_bn_dm_check';
  if(!(await c.searchObject(name,'',10)).some(x=>x['adtcore:name']===name))await c.createObject('CLAS/OC',name,'$TMP','Notebook Data Manager DEV checks','/sap/bc/adt/packages/%24tmp');
  const info=await c.transportInfo(url+'/source/main'),lock=await c.lock(url);
  try{await c.setObjectSource(url+'/source/main',source,lock.LOCK_HANDLE,info.LOCKS?.HEADER?.TRKORR)}finally{await c.unLock(url,lock.LOCK_HANDLE)}
  const syntax=await c.syntaxCheck(url+'/source/main',url+'/source/main',source);assert(!syntax.some(x=>x.severity==='E'),JSON.stringify(syntax));
  let active=await c.activate(name,url);if(!active.success&&active.inactive.length)active=await c.activate(active.inactive.filter(x=>x.object?.['adtcore:parentUri']===url||x.object?.['adtcore:uri']===url).map(x=>x.object),false);
  assert(active.success,JSON.stringify(active));proof=await c.runClass(name);console.log(proof);assert(proof.includes('BNCHECK|')&&!proof.includes('BNERROR|'),proof);
 }finally{await c.logout()}
 const evidence={at:new Date().toISOString(),notebookId:n.id,notebookRevision:n.revision,handler,environment:seed.environment,model:seed.model,selection,proof};
 fs.mkdirSync('docs/evidence',{recursive:true});fs.writeFileSync('docs/evidence/data-manager-contract.json',JSON.stringify(evidence,null,2)+'\n');
 console.log(JSON.stringify({notebookId:n.id,handler:handler.name,revision:handler.revision,selection,environment:seed.environment,model:seed.model}));
})().catch(e=>{console.error(e.message);process.exitCode=1});
