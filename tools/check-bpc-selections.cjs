const assert=require('node:assert/strict'),fs=require('fs'),api=require('./bpc-api.cjs');
(async()=>{
 const args=Object.fromEntries(process.argv.filter(x=>x.startsWith('--')&&x.includes('=')).map(x=>x.slice(2).split('=')));
 if(!args.environment||!args.model||!args.node||!args.hierarchy||!args.category)throw Error('Specify --environment= --model= --node= --hierarchy= --category= for a DEV model');
 const context={environment:args.environment,model:args.model};
 const demo=await api('/notebooks',{demo:true,...context});
 assert.deepEqual(demo.inputs.map(p=>p.type),['number','number','member','range','boolean']);
 await assert.rejects(api('/runs',{notebookId:demo.id,expectedRevision:demo.revision,scope:'all',idempotencyKey:crypto.randomUUID()}),/BPC_REQUIRED/);
 const categories=await api('/metadata',{kind:'members',...context,dimension:'CATEGORY',search:args.category});
 const time=await api('/metadata',{kind:'members',...context,dimension:'TIME',hierarchy:args.hierarchy,search:args.node});
 const node=time.items.find(m=>m.id===args.node); assert.equal(node.isNode,true);
 demo.inputs.find(p=>p.name==='CATEGORY').selected=[categories.items.find(m=>m.id===args.category).id];
 demo.inputs.find(p=>p.name==='TIME').selected=[node.id];
 let saved=await api('/notebook',{...demo,expectedRevision:demo.revision},'PUT');
 const periods=saved.inputs.find(p=>p.name==='TIME').resolved;
 assert(periods.length>1);assert(!periods.includes(node.id));
 const run=await api('/runs',{notebookId:saved.id,expectedRevision:saved.revision,scope:'all',idempotencyKey:crypto.randomUUID()});
 saved.inputs.find(p=>p.name==='TIME').selected=periods.slice(0,2);
 saved.inputs.find(p=>p.name==='TIME').resolved=['FORGED'];
 const changed=await api('/notebook',{...saved,expectedRevision:saved.revision},'PUT');
 assert.deepEqual(changed.inputs.find(p=>p.name==='TIME').resolved,periods.slice(0,2));
 let finished;
 for(let i=0;i<25;i++){finished=await api('/run?id='+run.id,null,'GET');if(['succeeded','failed','cancelled'].includes(finished.state))break;await new Promise(r=>setTimeout(r,1000));}
 assert.equal(finished.state,'succeeded',JSON.stringify(finished.error));
 assert.deepEqual(finished.snapshot.inputs.find(p=>p.name==='TIME').resolved,periods);
 assert.equal(finished.messages.filter(m=>m.text.includes(String(periods.length))&&m.text.includes('frozen periods')).length,2);
 const current=await api('/notebook?id='+saved.id,null,'GET');assert(current.cells.every(c=>c.output.stale));
 const invalid=structuredClone(changed);invalid.inputs.find(p=>p.name==='CATEGORY').selected=['NOT_AN_AUTHORIZED_MEMBER'];
 await assert.rejects(api('/notebook',{...invalid,expectedRevision:changed.revision},'PUT'),/BPC_AUTH/);
 const retry=await api('/retry',{id:run.id,idempotencyKey:crypto.randomUUID()});
 assert.deepEqual(retry.snapshot.inputs,finished.snapshot.inputs);
 const evidence={at:new Date().toISOString(),notebookId:saved.id,runId:run.id,retryId:retry.id,passed:true,
  checks:['required selections','real SAP hierarchy expansion','backend base members exclude selected parent','forged resolved values discarded',
   'all cells share frozen selections','editing selections marks outputs stale','invalid member rejected','retry retains original snapshot'],
  context,selected:finished.snapshot.inputs.filter(p=>p.type==='member'||p.type==='range'),messages:finished.messages};
 fs.writeFileSync('docs/evidence/bpc-selections.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
