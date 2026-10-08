const fs=require('fs'),assert=require('node:assert/strict'),api=require('./bpc-api.cjs');
(async()=>{
 const seed=JSON.parse(fs.readFileSync('.local/allocation-notebook.json','utf8'));
 const notebook=await api('/notebooks',{title:'Allocation incomplete checkpoint verification',environment:seed.environment,model:seed.model,inputs:seed.inputs,
  cells:[{id:'allocation',title:'Fail after initial checkpoint',dependencies:[],source:
   "zcl_bn_dem_alloc=>execute( io = io stop_after = 'INITIALISE' ).\nio->checkpoint( name = 'TEST_BOUNDARY' state = 'running' ).\nRAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST_FAILURE' detail = 'Intentional checkpoint test'."}]});
 let run=await api('/runs',{notebookId:notebook.id,expectedRevision:notebook.revision,scope:'all',idempotencyKey:'checkpoint-'+Date.now()});
 while(['running','queued'].includes(run.state)){await new Promise(r=>setTimeout(r,1000));run=await api('/run?id='+run.id,null,'GET');}
 assert.equal(run.state,'failed');assert.equal(run.error.code,'TEST_FAILURE');assert.equal(run.results.length,0);
 assert.equal(run.checkpoints.find(x=>x.name==='TEST_BOUNDARY').state,'failed');
 const output=await api('/output?runId='+run.id+'&cellId=allocation&revision=1&limit=1',null,'GET');
 assert.equal(output.partial,true);assert(output.tables.find(x=>x.name==='INITIALISE/INPUT_DATA').totalCount>0);
 await assert.rejects(api('/retry',{id:run.id,idempotencyKey:'forbidden-reference-retry-'+Date.now()}),/DATA_SNAPSHOT/);
 const evidence={at:new Date().toISOString(),passed:true,notebookId:notebook.id,runId:run.id,state:run.state,error:run.error,checkpoints:run.checkpoints,
  partial:output.partial,tables:output.tables,retryRejected:true,completedDatasets:run.results.length};
 fs.writeFileSync('.local/allocation-checkpoints-evidence.json',JSON.stringify(evidence,null,2),'utf8');
 console.log('PASS: incomplete previews retained; no completed dependency; reference retry rejected',run.id);
})().catch(e=>{console.error(e.message);process.exitCode=1;});
