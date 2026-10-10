// Nonposting native deadline, cancellation and large-source loop checks.
const fs=require('node:fs'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),api=require('./bpc-api.cjs');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const evidence={at:new Date().toISOString(),financialPosting:false,cases:[],passed:false};
async function check(name,source,cancel=false){
 const n=await api('/notebooks',{title:'Platform budget polling '+name,inputs:[],cells:[{id:'probe',title:name,source,dependencies:[]}]});
 let r;
 try{
  const v=await api('/validate',{notebookId:n.id,cellId:'probe'});assert.equal(v.supported,true,JSON.stringify(v));
  r=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:randomUUID()});
  if(cancel){
   for(let i=0;i<600&&r.state==='queued';i++){await pause(100);r=await api('/run?id='+r.id,null,'GET');}
   assert.equal(r.state,'running');await pause(1000);
   const requested=Date.now();await api('/cancel',{id:r.id});
   for(let i=0;i<150&&['running','queued'].includes(r.state);i++){await pause(100);r=await api('/run?id='+r.id,null,'GET');}
   evidence.cases.push({name,state:r.state,error:r.error,cancellationElapsedMs:Date.now()-requested,runId:r.id});
   assert.equal(r.state,'cancelled',JSON.stringify(r.error));assert(Date.now()-requested<15000);
  }else{
   for(let i=0;i<120&&['running','queued'].includes(r.state);i++){await pause(500);r=await api('/run?id='+r.id,null,'GET');}
   evidence.cases.push({name,state:r.state,error:r.error,messages:r.messages,runId:r.id});assert.equal(r.state,'succeeded',JSON.stringify(r.error));
  }
 }finally{
  if(r&&['queued','running'].includes(r.state)){
   await api('/cancel',{id:r.id});
   for(let i=0;i<60&&['queued','running'].includes(r.state);i++){await pause(500);r=await api('/run?id='+r.id,null,'GET');}
  }
  if(!r||!['queued','running'].includes(r.state))await api('/delete-notebook',{notebookId:n.id,expectedRevision:n.revision});
 }
}
(async()=>{
 const padding=Array.from({length:900},(_,i)=>'" Author-source payload retained in run snapshot '+i+' '.repeat(8)).join('\n');
 await check('50000 budget checks with large snapshot',padding+`\nDATA started TYPE i. DATA finished TYPE i.
GET RUN TIME FIELD started.
DO 50000 TIMES. io->check_budget( ). ENDDO.
GET RUN TIME FIELD finished.
DATA elapsed TYPE i. elapsed = finished - started.
IF elapsed > 10000000. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'POLL_PERFORMANCE' detail = '50000 budget checks exceeded ten seconds'. ENDIF.
io->message( |BUDGET_CHECKS:50000:ELAPSED_US:{ elapsed }| ).`);
 await check('deadline checked during polling interval',`DATA(short) = NEW zcl_bn_context(
 inputs = VALUE #( ( name = 'RUN_SECONDS' type = 'number' value = '1' ) )
 bindings = VALUE #( ) dependencies = VALUE #( ) cell_id = 'deadline' ).
DATA expired TYPE abap_bool.
TRY. DO 10000000 TIMES. short->check_budget( ). ENDDO.
CATCH zcx_bn INTO DATA(error).
 IF error->code <> 'TIMEOUT'. RAISE EXCEPTION error. ENDIF. expired = abap_true.
ENDTRY.
IF expired <> abap_true. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DEADLINE_TEST' detail = 'Deadline was not enforced'. ENDIF.
io->message( 'DEADLINE_CHECK_OK' ).`);
 await check('cooperative in-cell cancellation',padding+`\nDATA started TYPE timestampl. GET TIME STAMP FIELD started.
DO.
 io->check_budget( ).
 DATA stamp TYPE timestampl. GET TIME STAMP FIELD stamp.
 IF cl_abap_tstmp=>subtract( tstmp1 = stamp tstmp2 = started ) > 45. EXIT. ENDIF.
ENDDO.
RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CANCEL_TEST' detail = 'Cancellation was not observed within 45 seconds'.`,true);
 evidence.passed=true;
})().catch(e=>{evidence.failure=e.message;console.error(e.message);process.exitCode=1;}).finally(()=>{
 fs.writeFileSync('docs/evidence/native-budget-polling.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));
});
