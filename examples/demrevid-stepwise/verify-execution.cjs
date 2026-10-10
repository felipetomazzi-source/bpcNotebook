// Read-only financial calculation: exercise the saved live notebook execution modes.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const api=require('../../tools/bpc-api.cjs');
const id=fs.readFileSync(path.join(__dirname,'allocation-notebook-id.txt'),'utf8').trim();
async function get(p){return api(p,null,'GET');}
async function execute(n,scope,cellId){
 let r=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope,cellId,idempotencyKey:crypto.randomUUID()});
 for(let i=0;['queued','running'].includes(r.state)&&i<1200;i++){await new Promise(resolve=>setTimeout(resolve,1500));r=await get('/run?id='+r.id);}
 console.log(JSON.stringify({scope,cellId,state:r.state,error:r.error}));
 assert.equal(r.state,'succeeded',JSON.stringify(r.error));return r;
}
(async()=>{
 const n=await get('/notebook?id='+id), evidence={notebookId:id,at:new Date().toISOString(),financialPosting:false,customerEquivalent:false,runs:[]};
 for(const [scope,cellId] of [['all',''],['one','step_02'],['through','step_04']]){
  const r=await execute(n,scope,cellId);
  evidence.runs.push({id:r.id,scope,cellId,state:r.state,cells:r.results.map(c=>({id:c.cellId,durationMs:c.durationMs,previewRows:c.rowCount}))});
  if(scope==='one')assert.deepEqual(r.results.map(c=>c.cellId),['step_02']);
  if(scope==='through')assert.deepEqual(r.results.map(c=>c.cellId),['step_01','step_02','step_03','step_04']);
  fs.writeFileSync(path.join(__dirname,'execution-evidence.json'),JSON.stringify(evidence,null,2)+'\n');
 }
 try{
  await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope:'one',cellId:'step_06',idempotencyKey:crypto.randomUUID()});
  throw Error('Expected stale step_05 to prevent step_06');
 }catch(error){
  const rejected=JSON.parse(error.message);assert.equal(rejected.code,'STALE_DEPENDENCY');
  evidence.staleDependency=rejected;
  fs.writeFileSync(path.join(__dirname,'execution-evidence.json'),JSON.stringify(evidence,null,2)+'\n');
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
