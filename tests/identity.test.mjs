import test from 'node:test';
import assert from 'node:assert/strict';
import {Engine,demo} from '../local/engine.mjs';
import {createServer} from '../local/server.mjs';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const definition=(name='ALLOC')=>({...demo(),technicalName:name,description:'Demand revenue allocation · São',environment:'E',model:'DEM'});
const assignment=(n,changes={})=>({notebookId:n.id,expectedRevision:n.revision,expectedIdentityRevision:n.identityRevision,technicalName:n.technicalName,description:n.description,...changes});
test('creation requires explicit identity; scoped names are globally reserved and never silently recycled',()=>{
 const e=new Engine({auto:false});
 for(const data of [demo(),{...definition(),technicalName:'bad-name'},{...definition(),technicalName:'1BAD'},{...definition(),description:'  '},{...definition(),description:'x'.repeat(241)}]) assert.throws(()=>e.create(data,'alice'));
 assert.equal(Object.keys(e.db.notebooks).length,0);
 const n=e.create(definition(),'alice'); assert.equal(n.technicalName,'ALLOC');assert.equal(n.description,'Demand revenue allocation · São');
 assert.throws(()=>e.create(definition(),'bob'),{code:'NAME_TAKEN'});
 assert.throws(()=>e.create(definition(),'alice'),{code:'NAME_TAKEN'});
 assert.equal(e.create({...definition(),model:'OTHER'},'bob').technicalName,'ALLOC');
 e.deleteNotebook(n.id,n.revision,'alice');assert.throws(()=>e.create(definition(),'alice'),{code:'NAME_TAKEN'});
});
test('identity migration and description changes preserve source revisions, frozen runs, datasets and old checksums',async()=>{
 const e=new Engine({auto:false,delay:0}), n=e.create(definition(),'alice');
 const run=e.submit({notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:'identity-snapshot'},'alice'); await e.execute(run.id);
 // Emulate an existing pre-identity notebook; remove only the new sidecars.
 delete e.db.identities[n.id];e.db.identityNames={};
 const before=JSON.stringify({versions:e.db.notebooks[n.id].versions,runs:e.db.runs,outputs:e.db.outputs});
 const migrated=e.assignIdentity(assignment({...n,technicalName:'',identityRevision:0},{technicalName:'DEMREVID003_ALLOCATION'}),'alice');
 assert.equal(migrated.identityRevision,1);assert.equal(JSON.stringify({versions:e.db.notebooks[n.id].versions,runs:e.db.runs,outputs:e.db.outputs}),before);
 assert.throws(()=>e.assignIdentity(assignment(e.view(n.id,'alice'),{technicalName:'NEW'}),'alice'),{code:'NAME_IMMUTABLE'});
 const edited=e.assignIdentity(assignment(e.view(n.id,'alice'),{description:'Edited · É'}),'alice');assert.equal(edited.identityRevision,2);
 assert.equal(e.view(n.id,'alice').description,'Edited · É');assert.equal(e.get(n.id,'alice').revision,1);
 assert.equal(JSON.stringify({versions:e.db.notebooks[n.id].versions,runs:e.db.runs,outputs:e.db.outputs}),before);
 assert.throws(()=>e.assignIdentity(assignment(n),'alice'),{code:'CONFLICT'});
 assert.throws(()=>e.assignIdentity(assignment(e.view(n.id,'alice')),'bob'),{code:'NOT_FOUND'});
});
test('resolution requires owner, exact saved revision and exact environment/model; context moves preserve pinned references',()=>{
 const e=new Engine({auto:false}),n=e.create(definition(),'alice'),lookup={environment:'E',model:'DEM',technicalName:'ALLOC',approvedRevision:1};
 assert.equal(e.resolveIdentity(lookup,'alice').id,n.id);
 assert.throws(()=>e.resolveIdentity({...lookup,approvedRevision:0},'alice'),{code:'APPROVED_REVISION'});
 assert.throws(()=>e.resolveIdentity({...lookup,approvedRevision:99},'alice'),{code:'INTEGRITY'});
 assert.throws(()=>e.resolveIdentity(lookup,'bob'),{code:'NOT_FOUND'});
 e.save(n.id,{...n,model:'OTHER',expectedRevision:1},'alice');
 assert.equal(e.resolveIdentity(lookup,'alice').revision,1);
 assert.equal(e.resolveIdentity({...lookup,model:'OTHER',approvedRevision:2},'alice').revision,2);
 assert.throws(()=>e.resolveIdentity({...lookup,approvedRevision:2},'alice'),{code:'IDENTITY_SCOPE'});
});
test('HTTP demo and normal creation cannot omit identity; assignment is separate from calculation saves',async()=>{
 const engine=new Engine({auto:false}),server=createServer(engine);await new Promise(r=>server.listen(0,'127.0.0.1',r));
 try {
  const base='http://127.0.0.1:'+server.address().port+'/api';
  const post=(path,body)=>fetch(base+path,{method:'POST',headers:{'content-type':'application/json','x-bpc-notebook':'1'},body:JSON.stringify(body)});
  assert.equal((await post('/notebooks',{demo:true})).status,400);assert.equal((await post('/notebooks',demo())).status,400);
  const n=await (await post('/notebooks',{demo:true,technicalName:'HTTP_ALLOC',description:'HTTP allocation'})).json();assert.equal(n.technicalName,'HTTP_ALLOC');
  const response=await post('/notebook-identity',assignment(n,{description:'New description'}));assert.equal(response.status,200);
  assert.equal(engine.get(n.id,'LOCAL_DEVELOPER').revision,1);
  assert.equal((await post('/notebook-resolve',{technicalName:'HTTP_ALLOC',approvedRevision:1})).status,200);
 } finally {server.closeAllConnections();await new Promise(r=>server.close(r));}
});
test('identity assignment preserves unsaved UI code, dirty state and editor controls',async()=>{
 let methods,accept;
 const saved={technicalName:'ALLOC',description:'Allocation',identityRevision:1};
 vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{sap:{m:{},ui:{define:(_,f)=>f({extend:(_,d)=>methods=d},{},{},{show(){}},{},{},{request:async()=>saved},{})}}});
 const editors={value:'unsaved ABAP'},n={id:'N',revision:3},drafts={x:{text:'unsaved script'}};
 const state=Object.assign({},methods,{notebook:n,dirty:true,scriptDrafts:drafts,cells:editors,
  title:{setText(v){this.text=v;}},identityDescription:{setText(v){this.text=v;}},identityDialog(_,callback){accept=callback;},
  refresh(){},renderNotebook(){assert.fail('Identity must not rebuild editors');}});
 state.editIdentity();await accept(saved);
 assert.equal(state.dirty,true);assert.equal(state.scriptDrafts,drafts);assert.equal(state.cells,editors);
 assert.equal(state.title.text,'ALLOC');assert.equal(state.identityDescription.text,'Allocation');assert.equal(n.revision,3);
});

test('normal and demo SAP creation select context before requesting mandatory identity',async()=>{
 for(const demoMode of [false,true]){
  let methods,identify,posted;
  vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{sap:{m:{},ui:{define:(_,f)=>f({extend:(_,d)=>methods=d},{},{},{},{},{},{local:false,request:async(path,method,data)=>{posted={path,method,data};return {id:'created'};}},{})}}});
  const order=[],state=Object.assign({},methods,{getEmbedded:()=>false,workspace:{setBusy(){}},resetReview(){},
   chooseContext(callback){order.push('context');callback({environment:'E',model:'DEM'});},identityDialog(_,callback){order.push('identity');identify=callback;},
   renderNotebook(){},refresh(){}});
  state.create(demoMode,true);assert.deepEqual(order,['context','identity']);assert.equal(posted,undefined);
  await identify({technicalName:'ALLOC',description:'Allocation'});
  assert.equal(posted.path,'/notebooks');assert.equal(posted.data.technicalName,'ALLOC');assert.equal(posted.data.description,'Allocation');
  assert.equal(posted.data.environment,'E');assert.equal(posted.data.model,'DEM');
 }
});
