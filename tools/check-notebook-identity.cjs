// Controlled notebook identity tests; no source deployment or financial posting.
const assert=require('node:assert/strict'),fs=require('node:fs'),{randomUUID,createHash}=require('node:crypto'),api=require('./bpc-api.cjs');
const digest=value=>createHash('sha256').update(JSON.stringify(value),'utf8').digest('hex');
const get=path=>api(path,null,'GET');
const operationalId='E82AEA36D1571FE1B18BD135480E4C5E';
const created=[];
const checks=[];
async function rejected(path,data,codes){try{await api(path,data);assert.fail('Expected rejection');}catch(e){const fault=JSON.parse(e.message);assert.ok(codes.includes(fault.code),JSON.stringify(fault));checks.push(fault.code);}}
(async()=>{
 const operational=await get('/notebook?id='+operationalId),scope={environment:operational.environment,model:operational.model};
 const beforeVersions=await get('/versions?id='+operationalId),beforeRun=await get('/run?id=E82AEA36D1571FE1B18C4A97C6DC4CF0');
 const versionsHash=digest(beforeVersions),runHash=digest(beforeRun);
 const name='TEST_ID_'+randomUUID().replaceAll('-','').slice(0,18).toUpperCase();
 const definition={...scope,title:'Controlled identity validation',technicalName:name,description:'Identity · É São — test',inputs:[],cells:[]};
 try {
  await rejected('/notebooks',{...definition,technicalName:''},['TECHNICAL_NAME']);
  await rejected('/notebooks',{...definition,description:' '},['DESCRIPTION']);
  await rejected('/notebooks',{...definition,demo:true,technicalName:''},['TECHNICAL_NAME']);
  await rejected('/notebooks',{...definition,environment:'',model:''},['BPC_CONTEXT']);
  const races=await Promise.allSettled([api('/notebooks',definition),api('/notebooks',definition)]);
  const winners=races.filter(r=>r.status==='fulfilled');assert.equal(winners.length,1);
  const n=winners[0].value;created.push(n.id);assert.equal(n.technicalName,name);assert.equal(n.description,definition.description);
  const losing=races.find(r=>r.status==='rejected');assert.ok(['NAME_TAKEN','CONFLICT'].includes(JSON.parse(losing.reason.message).code));checks.push('CONCURRENT_UNIQUENESS');
  const body={notebookId:n.id,expectedRevision:n.revision,expectedIdentityRevision:n.identityRevision,technicalName:name,description:'Changed · É São'};
  await rejected('/notebook-identity',{...body,technicalName:name+'_X'},['NAME_IMMUTABLE']);
  await rejected('/notebook-identity',{...body,expectedRevision:99},['CONFLICT']);
  const history=digest(await get('/versions?id='+n.id));const edited=await api('/notebook-identity',body);
  assert.equal(edited.identityRevision,2);assert.equal(digest(await get('/versions?id='+n.id)),history);checks.push('DESCRIPTION_WITHOUT_SOURCE_REVISION');
  await rejected('/notebook-identity',body,['CONFLICT']);
  const resolved=await api('/notebook-resolve',{...scope,technicalName:name,approvedRevision:1});assert.equal(resolved.id,n.id);checks.push('PINNED_RESOLUTION');
  await rejected('/notebook-resolve',{...scope,technicalName:name,approvedRevision:0},['APPROVED_REVISION']);
  await rejected('/notebook-resolve',{...scope,technicalName:name,approvedRevision:99},['INTEGRITY']);
  const demo=await api('/notebooks',{...definition,demo:true,technicalName:name+'_D'});created.push(demo.id);assert.equal(demo.technicalName,name+'_D');checks.push('DEMO_IDENTITY');
  // Explicit, requested assignment of the existing operational notebook only.
  if(!operational.technicalName){
   await api('/notebook-identity',{notebookId:operationalId,expectedRevision:operational.revision,expectedIdentityRevision:0,
    technicalName:'DEMREVID003_ALLOCATION',description:'DEMREVID003 demand revenue allocation'});
  } else {assert.equal(operational.technicalName,'DEMREVID003_ALLOCATION');}
  const after=await get('/notebook?id='+operationalId);assert.equal(after.technicalName,'DEMREVID003_ALLOCATION');assert.equal(after.revision,operational.revision);
  assert.equal(digest(await get('/versions?id='+operationalId)),versionsHash);assert.equal(digest(await get('/run?id='+beforeRun.id)),runHash);
  const operationalResolved=await api('/notebook-resolve',{...scope,technicalName:after.technicalName,approvedRevision:operational.revision});assert.equal(operationalResolved.id,operationalId);
  checks.push('LEGACY_ASSIGNMENT_PRESERVES_HISTORY_AND_RUN');
  const listed=await get('/notebooks');assert.equal(listed.find(v=>v.id===operationalId).technicalName,after.technicalName);
  const evidence={at:new Date().toISOString(),passed:true,checks,operational:{id:operationalId,technicalName:after.technicalName,revision:after.revision,scope,versionsHash,runId:beforeRun.id,runHash},created};
  fs.writeFileSync('docs/evidence/notebook-identity-native.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));
 } finally {
  for(const id of created){const n=await get('/notebook?id='+id);await api('/delete-notebook',{notebookId:id,expectedRevision:n.revision});}
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
