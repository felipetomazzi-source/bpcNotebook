// Complete native table handoff through real background workers; no financial writes.
const fs=require('node:fs'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),api=require('./bpc-api.cjs');
const schema="TYPES: BEGIN OF ty_row, category TYPE uj_dim_member, time TYPE uj_dim_member, signeddata TYPE uj_signeddata, ratio TYPE decfloat34, position TYPE i, END OF ty_row.\nDATA rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.";
const sources={
 seed:schema+"\nDO 12003 TIMES.\n APPEND VALUE #( category = 'Actual' time = '2025.007' signeddata = CONV uj_signeddata( '-0.0000001' ) * sy-index ratio = CONV decfloat34( '0.000000000000000000000000000000001' ) position = sy-index ) TO rows.\nENDDO.\nio->publish_dataset( name = 'FULL' rows = rows ).\nCLEAR rows.\nio->publish_dataset( name = 'EMPTY' rows = rows ).",
 mutate:schema+"\nDATA(copy) = io->read_dataset( dependency = 'seed' name = 'FULL' ).\nFIELD-SYMBOLS <full> TYPE STANDARD TABLE.\nASSIGN copy->* TO <full>.\nrows = <full>.\nIF lines( rows ) <> 12003 OR rows[ 12003 ]-signeddata <> CONV uj_signeddata( '-0.0012003' ) OR rows[ 12003 ]-position <> 12003.\n RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NATIVE_TEST' detail = 'Full exact native data lost'.\nENDIF.\nrows[ 1 ]-signeddata = 99.\nio->publish_dataset( name = 'CHANGED' rows = rows ).",
 verify:schema+"\nDATA(copy) = io->read_dataset( dependency = 'seed' name = 'FULL' ).\nFIELD-SYMBOLS <full> TYPE STANDARD TABLE.\nASSIGN copy->* TO <full>.\nrows = <full>.\nIF rows[ 1 ]-signeddata <> CONV uj_signeddata( '-0.0000001' ).\n RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NATIVE_TEST' detail = 'Producer changed'.\nENDIF.\nDATA(empty) = io->read_dataset( dependency = 'seed' name = 'EMPTY' ).\nASSIGN empty->* TO <full>.\nIF lines( <full> ) <> 0.\n RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NATIVE_TEST' detail = 'Empty schema lost'.\nENDIF.\nio->publish_dataset( name = 'VERIFIED' rows = rows )."
};
async function execute(n,scope,cellId){let r=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope,cellId,idempotencyKey:randomUUID()});
 for(let i=0;i<90&&['queued','running'].includes(r.state);i++){await new Promise(resolve=>setTimeout(resolve,500));r=await api('/run?id='+r.id,null,'GET');}
 assert.equal(r.state,'succeeded',JSON.stringify(r.error));return r;}
(async()=>{const n=await api('/notebooks',{title:'Platform native datasets verification',explanation:'Controlled native tables only; no business data posting.',inputs:[{name:'PREVIEW_ROWS',type:'number',value:'3'}],cells:Object.entries(sources).map(([id,source])=>({id,title:id,source,explanation:'Native handoff verification',dependencies:id==='seed'?[]:id==='mutate'?['seed']:['seed','mutate']}))});
 const evidence={at:new Date().toISOString(),notebookId:n.id,financialPosting:false,cases:[]};
 try{
  assert.equal(n.explanation,'Controlled native tables only; no business data posting.');
  await assert.rejects(api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope:'one',cellId:'verify',idempotencyKey:randomUUID()}),/STALE_DEPENDENCY/);
  const all=await execute(n,'all','');evidence.cases.push({scope:'all',runId:all.id,results:all.results});
  assert.equal(all.results.find(c=>c.cellId==='seed').rowCount,12003);
  const header=await api('/datasets?runId='+all.id+'&cellId=seed&revision=1',null,'GET');
  assert.equal(header.artifacts.find(d=>d.name==='FULL').rowCount,12003);assert.equal(header.artifacts.find(d=>d.name==='EMPTY').schema.length,5);
  assert.equal(JSON.stringify(header).includes('content'),false);
  const page=await api('/output?runId='+all.id+'&cellId=seed&revision=1&offset=0&limit=100&table=DATASET%2FFULL',null,'GET');
  assert.equal(page.total,3);assert.equal(page.sourceTotal,12003);
  const one=await execute(n,'one','verify');evidence.cases.push({scope:'one',runId:one.id,results:one.results});
  const through=await execute(n,'through','mutate');evidence.cases.push({scope:'through',runId:through.id,results:through.results});
  const updated=await api('/notebook',{...n,expectedRevision:n.revision,cells:n.cells.map(c=>c.id==='seed'?{...c,source:c.source+"\nio->message( 'changed source' )."}:c)},'PUT');
  await assert.rejects(api('/runs',{notebookId:updated.id,expectedRevision:updated.revision,scope:'one',cellId:'verify',idempotencyKey:randomUUID()}),/STALE_DEPENDENCY/);
  evidence.passed=true;console.log(JSON.stringify(evidence));
 }finally{fs.writeFileSync('docs/evidence/native-working-datasets.json',JSON.stringify(evidence,null,2)+'\n','utf8');
  const current=await api('/notebook?id='+n.id,null,'GET');await api('/delete-notebook',{notebookId:n.id,expectedRevision:current.revision});}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
