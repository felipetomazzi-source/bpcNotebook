// Run after the platform working-dataset APIs are deployed through abapGit.
// Uses complete native comparisons on SAP; JS examines only verification counts.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const api=require('../../tools/bpc-api.cjs');
const options=Object.fromEntries(process.argv.filter(x=>/^--[^=]+=/.test(x)).map(x=>{const i=x.indexOf('=');return[x.slice(2,i),x.slice(i+1)];}));
const get=p=>api(p,null,'GET');
const definition=JSON.parse(fs.readFileSync(path.join(__dirname,'validation.draft.json'),'utf8'));
async function table(run,name){const result=await get('/output?runId='+run.id+'&cellId=compare&revision=1&limit=100&table='+encodeURIComponent(name));return result.rows.map(row=>Object.fromEntries(result.schema.map((field,index)=>[field.name.toUpperCase(),row.values[index]])));}
(async()=>{
 let notebook=options.notebook?await get('/notebook?id='+options.notebook):await api('/notebooks',definition);
 const evidence={kind:'complete native multi-cell original comparison',notebookId:notebook.id,at:new Date().toISOString(),customerEquivalent:false,cases:[]};
 fs.writeFileSync(path.join(__dirname,'validation-notebook-id.txt'),notebook.id+'\n');
 const cases=[['standard',true],['standard',false],['fallback',false],['rounding',false],['negative',false],['carry',false],['carry',true],['hsns',false],['hsns',true]];
 for(const [scenario,suppress] of cases){
  definition.inputs.find(i=>i.name==='FIXTURE_CASE').value=scenario;
  definition.inputs.find(i=>i.name==='FFLASMATGROUPS').value=String(suppress);
  if(notebook.revision){const latest=await get('/notebook?id='+notebook.id);notebook=await api('/notebook',{...definition,id:notebook.id,expectedRevision:latest.revision},'PUT');}
  for(const cell of definition.cells){
   const checked=await api('/validate',{notebookId:notebook.id,cellId:cell.id});
   assert(!checked.diagnostics.some(d=>['error','E'].includes(d.severity)),JSON.stringify({cell:cell.id,diagnostics:checked.diagnostics}));
  }
  let run=await api('/runs',{notebookId:notebook.id,expectedRevision:notebook.revision,scope:'all',idempotencyKey:crypto.randomUUID()});
  for(let poll=0;['queued','running'].includes(run.state)&&poll<1200;poll++){await new Promise(resolve=>setTimeout(resolve,1500));run=await get('/run?id='+run.id);}
  const result={scenario,suppress,runId:run.id,state:run.state,error:run.error};evidence.cases.push(result);
  if(run.state==='succeeded'){
   result.replacement=(await table(run,'REPLACEMENT/SUMMARY'))[0];result.delta=(await table(run,'DELTA/SUMMARY'))[0];
   for(const comparison of [result.replacement,result.delta]){assert(Number(comparison.ORIGINAL_ROWS)>0,'Empty comparison');assert.equal(Number(comparison.ADDED)+Number(comparison.MISSING)+Number(comparison.CHANGED),0,'Complete native difference');}
   const delta=await table(run,'FINAL_DELTA');
   assert.equal(delta.length,Number(result.delta.NOTEBOOK_ROWS),'Small fixture must fit preview; full comparison is on SAP');
   result.zeroClears=delta.filter(row=>/^[-+]?0(?:\.0+)?$/.test(row.SIGNEDDATA)).length;
   assert(result.zeroClears>0,'Disappeared old records must be cleared');
   if(scenario==='hsns')assert(delta.some(row=>row.AUDITTRAIL==='DEMREVID_CALC_HSNS'),'HSNS output missing');
   if(scenario==='carry')assert(delta.some(row=>['DEMREVID040','DEMREVID041'].includes(row.DEMREVID_KFS)),'Connection carry output missing');
  }
  fs.writeFileSync(path.join(__dirname,'native-evidence.json'),JSON.stringify(evidence,null,2)+'\n');
  console.log(JSON.stringify(result));assert.equal(run.state,'succeeded',JSON.stringify(run.error));
 }
 console.log('Native fixtures matched. Customer-data and UI stepwise acceptance remain separate.');
})().catch(error=>{console.error(error.message);process.exitCode=1});
