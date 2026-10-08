const fs=require('node:fs'),assert=require('node:assert/strict'),api=require('./bpc-api.cjs');
(async()=>{
 const n=await api('/notebooks',{title:'Deletion verification - temporary',environment:'CH_PLANNING',model:'DEMREVID',inputs:[],cells:[
  {id:'seed',title:'Seed',dependencies:[],source:"io->emit( VALUE #( ( key = 'preserved' amount = 77 ) ) )."},
  {id:'apply',title:'Dependent cell',dependencies:['seed'],source:"DATA rows TYPE zcl_bn_context=>tt_rows.\nrows = io->read( 'seed' ).\nLOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).\n <row>-amount = <row>-amount * 2.\nENDLOOP.\nio->emit( rows )."}]});
 const submitted=await api('/runs',{notebookId:n.id,expectedRevision:1,scope:'all',idempotencyKey:crypto.randomUUID()});
 let run;for(let i=0;i<60;i++){run=await api('/run?id='+submitted.id,null,'GET');if(!['queued','running'].includes(run.state))break;await new Promise(r=>setTimeout(r,1000));}
 assert.equal(run.state,'succeeded',JSON.stringify(run.error));
 const path='/output?runId='+run.id+'&cellId=apply&revision=1&limit=20';
 const before=await api(path,null,'GET');assert.equal(Number(before.rows[0].amount),154);
 await assert.rejects(api('/notebook',{...n,cells:[n.cells[1]],expectedRevision:1},'PUT'),/DEPENDENCY_ORDER/);
 const saved=await api('/notebook',{...n,cells:[n.cells[0]],expectedRevision:1},'PUT');assert.equal(saved.revision,2);
 const reopened=await api('/notebook?id='+n.id,null,'GET');assert.equal(reopened.cells.length,1);assert(!reopened.cells[0].output.stale);
 assert.equal((await api('/run?id='+run.id,null,'GET')).snapshot.cells.length,2);
 const list=await api('/notebooks',null,'GET');assert(list.some(x=>x.id===n.id));assert(list.every(x=>!('cells' in x)));
 const runs=await api('/runs?notebookId='+n.id,null,'GET');assert(runs.some(x=>x.id===run.id));assert(runs.every(x=>!('snapshot' in x)));
 await assert.rejects(api('/delete-notebook',{notebookId:n.id,expectedRevision:1}),/CONFLICT/);
 fs.writeFileSync('.local/deletion-fixture.json',JSON.stringify({notebook:saved,runId:run.id}),'utf8');
 const native=require('./notebook-deletion-native.cjs');
 await native(saved);
 assert(!(await api('/notebooks',null,'GET')).some(x=>x.id===n.id));
 await assert.rejects(api('/notebook?id='+n.id,null,'GET'),/NOTEBOOK_DELETED/);
 await assert.rejects(api('/notebook',{...saved,expectedRevision:2},'PUT'),/NOTEBOOK_DELETED/);
 await assert.rejects(api('/runs',{notebookId:n.id,expectedRevision:2,scope:'all',idempotencyKey:crypto.randomUUID()}),/NOTEBOOK_DELETED/);
 const history=await api('/versions?id='+n.id,null,'GET');assert.equal(history.length,2);assert.equal(history[0].cells.length,2);
 assert.deepEqual(await api(path,null,'GET'),before);
 fs.writeFileSync('docs/evidence/notebook-deletion.json',JSON.stringify({at:new Date().toISOString(),passed:true,notebookId:n.id,runId:run.id,
  checks:['leaf cell deletion keeps original snapshot/output','dangling dependencies rejected','revision conflict rejected','active execution blocks deletion',
   'deleted notebook hidden and blocked','bound handler blocked','historical versions and outputs unchanged','lightweight list responses'],output:before,
  navigationBefore:JSON.parse(fs.readFileSync('.local/navigation-before.json','utf8')),navigationAfter:JSON.parse(fs.readFileSync('.local/navigation-after.json','utf8'))},null,2)+'\n','utf8');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
