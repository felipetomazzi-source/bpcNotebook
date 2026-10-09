const fs=require('node:fs'),assert=require('node:assert/strict'),api=require('./bpc-api.cjs');
const options=Object.fromEntries(process.argv.filter(x=>/^--[^=]+=/.test(x)).map(x=>{const i=x.indexOf('=');return[x.slice(2,i),x.slice(i+1)];}));
const get=p=>api(p,null,'GET');
async function output(run,table){const o=await get('/output?runId='+run.id+'&cellId=validation&revision=1&limit=100&table='+encodeURIComponent(table));return o.rows.map(r=>Object.fromEntries(o.schema.map((f,i)=>[f.name.toUpperCase(),r.values[i]])));}
(async()=>{
 const definition=JSON.parse(fs.readFileSync('examples/demrevid-allocation/validation-definition.json'));
 const saved=await get('/notebook?id='+options.notebook);
 const evidence={sourceCommit:require('child_process').execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),at:new Date().toISOString(),system:'NPL',client:'001',notebookId:saved.id,cases:[],businessEquivalent:false};
 const cases=[['standard',true],['standard',false],['fallback',false],['rounding',false],['negative',false],['carry',false],['carry',true],['hsns',false],['hsns',true],['standard',true]];
 for(const [scenario,suppress]of cases){
  definition.inputs.find(i=>i.name==='FIXTURE_CASE').value=scenario;
  definition.inputs.find(i=>i.name==='FFLASMATGROUPS').value=suppress;
  const latest=await get('/notebook?id='+saved.id);
  const n=await api('/notebooks',{...definition,id:saved.id,revision:latest.revision});
  const validation=await api('/validate',{notebookId:n.id,cellId:'validation'});
  assert(!validation.diagnostics.some(d=>d.severity==='error'),JSON.stringify(validation));
  let r=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:crypto.randomUUID()});
  for(let poll=0;['queued','running'].includes(r.state)&&poll<240;poll++){await new Promise(resolve=>setTimeout(resolve,1500));r=await get('/run?id='+r.id);}
  const result={scenario,suppress,runId:r.id,state:r.state,error:r.error};evidence.cases.push(result);
  if(r.state==='succeeded'){
   result.replacement=(await output(r,'REPLACEMENT/SUMMARY'))[0];result.delta=(await output(r,'DELTA/SUMMARY'))[0];result.coverage=await output(r,'COVERAGE');
   const deltaRows=await output(r,'NOTEBOOK/FINAL_DELTA');
   assert.equal(deltaRows.length,Number(result.delta.NOTEBOOK_ROWS),'Fixture output must fit the verification preview; native comparison remains complete');
   result.zeroClears=deltaRows.filter(x=>/^[-+]?0(?:\.0+)?$/.test(x.SIGNEDDATA)).length;
   assert(result.zeroClears>0,'Disappeared old records must produce native zero clears');
   result.diagnostics=await output(r,'ORIGINAL/READ_1/SUMMARY');
   assert(result.diagnostics.every(x=>x.SOURCE==='fixture'&&x.SECURITY==='MEMBER_AUTH_ON; NO_QUERY'));
   if(scenario==='hsns')assert(deltaRows.some(x=>x.AUDITTRAIL==='DEMREVID_CALC_HSNS'),'HSNS fixture must enter HSNS output');
   for(const comparison of [result.replacement,result.delta]){assert(Number(comparison.ORIGINAL_ROWS)>0);assert.equal(Number(comparison.ADDED)+Number(comparison.MISSING)+Number(comparison.CHANGED),0,JSON.stringify(result));}
   if(scenario==='carry')assert(result.coverage.some(x=>['DEMREVID040','DEMREVID041'].includes(x.KEY_FIGURE)),'Carry fixture must produce connection output');
  }
  fs.writeFileSync('docs/evidence/demrevid-complete-fixtures.json',JSON.stringify(evidence,null,2)+'\n');
  console.log(JSON.stringify(result));assert.equal(r.state,'succeeded',JSON.stringify(r.error));
 }
 console.log('All nonempty native fixture comparisons passed; full customer-data acceptance remains pending.');
})().catch(e=>{console.error(e.message);process.exitCode=1});
