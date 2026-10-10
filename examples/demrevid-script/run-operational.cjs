// Exercise the saved Script-only simulation and retain counts/timing, never financial values.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
const api=require('../../tools/bpc-api.cjs');const local=p=>path.join(__dirname,p);
const get=async p=>{for(let attempt=0;;attempt++){try{return await api(p,null,'GET');}catch(e){if(attempt>=3||!p.startsWith('/run?id=')||!e.message.includes('INTEGRITY'))throw e;await new Promise(r=>setTimeout(r,1500));}}};
(async()=>{
 const id=fs.readFileSync(local('notebook-id.txt'),'utf8').trim();
 const notebook=await get('/notebook?id='+id);assert.equal(notebook.cells.length,21);
 let run=await api('/runs',{notebookId:id,expectedRevision:notebook.revision,scope:'all',idempotencyKey:randomUUID()});
 console.log(JSON.stringify({notebookId:id,runId:run.id,state:run.state}));
 for(let n=0;n<1500&&['queued','running'].includes(run.state);n++){await new Promise(r=>setTimeout(r,1500));run=await get('/run?id='+run.id);}
 const evidence={at:new Date().toISOString(),notebookId:id,revision:notebook.revision,runId:run.id,state:run.state,error:run.error,
  financialPosting:false,fixtureMode:run.fixtureMode,inputs:run.snapshot.inputs,results:run.results};
 if(run.state==='succeeded'){
  assert.equal(run.fixtureMode,false);assert.equal(run.results.length,21);
  const output=await get('/output?runId='+run.id+'&cellId=reconcile&revision=1&limit=1');
  evidence.tables=output.tables;
  for(const name of ['FINAL_REPLACEMENT','FINAL_DELTA'])assert(output.tables.find(t=>t.name===name)?.totalCount>0);
 }
 fs.writeFileSync(local('operational-evidence.json'),JSON.stringify(evidence,null,2)+'\n');
 console.log(JSON.stringify({state:run.state,error:run.error,cells:run.results.length,tables:evidence.tables}));
 assert.equal(run.state,'succeeded',JSON.stringify({error:run.error,checkpoint:run.checkpointCell}));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
