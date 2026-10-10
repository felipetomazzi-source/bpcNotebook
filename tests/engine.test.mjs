import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Engine, demo } from '../local/engine.mjs';
const user='alice';
const fixture = () => { const e=new Engine({auto:false,delay:0}); const n=e.create({...demo(),technicalName:"TEST_ALLOCATION",description:"Test allocation"},user); return {e,n}; };
const request = (n, extra={}) => ({notebookId:n.id,expectedRevision:n.revision,scope:'all',cellId:'',idempotencyKey:crypto.randomUUID(),...extra});
test('immutable source history, checksums and optimistic saves',()=>{
  const {e,n}=fixture();const edit=structuredClone(n);edit.cells[0].source+='\n" change';
  const saved=e.save(n.id,{...edit,expectedRevision:1},user);
  assert.equal(saved.revision,2);assert.equal(saved.cells[0].sourceVersion,2);assert.equal(saved.cells[1].sourceVersion,1);
  assert.equal(e.history(n.id,user)[0].cells[0].source,n.cells[0].source);
  assert.throws(()=>e.save(n.id,{...n,expectedRevision:1},user),{code:'CONFLICT'});
});
test('removing and readding a cell cannot reuse a source version for different content',()=>{
  const {e,n}=fixture();const removed=e.save(n.id,{...n,cells:[],expectedRevision:1},user);
  const restored=e.save(n.id,{...removed,cells:[{...n.cells[0],source:n.cells[0].source+'\n" v2'}],expectedRevision:2},user);
  assert.equal(restored.cells[0].sourceVersion,2);
});
test('tampered frozen snapshot is refused',async()=>{
  const {e,n}=fixture();const r=e.submit(request(n),user);e.db.runs[r.id].snapshot.inputs[0].value=1;
  await e.execute(r.id);assert.equal(e.run(r.id,user).error.code,'SNAPSHOT_INTEGRITY');
});
test('frozen run survives edits and consumes persisted dependency dataset',async()=>{
  const {e,n}=fixture();const run=e.submit(request(n),user);
  e.save(n.id,{...n,inputs:n.inputs.map(p=>({...p,value:p.name==='total'?10:p.value})),expectedRevision:1},user);
  await e.execute(run.id); const done=e.run(run.id,user);
  assert.equal(done.state,'succeeded');assert.equal(done.snapshot.inputs[0].value,120000);
  const page=e.preview(run.id,'allocate',1,0,2,user);assert.equal(page.total,3);assert.equal(page.rows[0].amount,66000);
  assert.ok(e.get(n.id,user).cells.every(c=>c.output.stale));
});
test('one scope rejects missing and stale dependencies; current refs execute',async()=>{
  const {e,n}=fixture();assert.throws(()=>e.submit(request(n,{scope:'one',cellId:'allocate'}),user),{code:'STALE_DEPENDENCY'});
  const seed=e.submit(request(n,{scope:'one',cellId:'seed'}),user);await e.execute(seed.id);
  const run=e.submit(request(n,{scope:'one',cellId:'allocate'}),user);await e.execute(run.id);assert.equal(e.run(run.id,user).state,'succeeded');
  const changed=e.save(n.id,{...n,expectedRevision:1,inputs:n.inputs.map(p=>({...p,value:p.name==='factor'?2:p.value}))},user);
  assert.throws(()=>e.submit(request(changed,{scope:'one',cellId:'allocate'}),user),{code:'STALE_DEPENDENCY'});
});
test('a new upstream output invalidates consumers even when source and inputs are unchanged',async()=>{
  const {e,n}=fixture();const first=e.submit(request(n),user);await e.execute(first.id);
  assert.ok(e.get(n.id,user).cells.every(c=>!c.output.stale));
  const second=e.submit(request(n,{scope:'one',cellId:'seed'}),user);await e.execute(second.id);
  assert.equal(e.get(n.id,user).cells[1].output.stale,true);
  assert.equal(e.get(n.id,user).cells[0].output.stale,false);
});
test('explicit retry preserves historical source, inputs and external bindings after edits',async()=>{
  const {e,n}=fixture();const original=e.submit(request(n),user);await e.execute(original.id);
  e.save(n.id,{...n,expectedRevision:1,inputs:n.inputs.map(p=>({...p,value:p.name==='total'?10:p.value}))},user);
  const retry=e.retry(original.id,crypto.randomUUID(),user);await e.execute(retry.id);
  assert.notEqual(retry.id,original.id);assert.equal(retry.snapshot.revision,1);
  assert.equal(e.preview(retry.id,'allocate',1,0,2,user).rows[0].amount,66000);
});
test('through scope freezes only participating cells and repeat keys return same run',async()=>{
  const {e,n}=fixture();const req=request(n,{scope:'through',cellId:'seed'});const a=e.submit(req,user),b=e.submit(req,user);
  assert.equal(a.id,b.id);assert.equal(a.snapshot.cells.length,1);
  assert.throws(()=>e.submit({...req,scope:'all'},user),{code:'KEY_REUSED'});
  await e.execute(a.id);assert.equal(e.run(a.id,user).results.length,1);
});
test('dependency graph rejects cycles, reordering and missing IDs',()=>{
  const {e,n}=fixture();for(const cells of [[...n.cells].reverse(),n.cells.map(c=>({...c,dependencies:['missing']}))]){
    assert.throws(()=>e.save(n.id,{...n,cells,expectedRevision:1},user),{code:'DEPENDENCY_ORDER'});
  }
});
test('source edits invalidate all downstream outputs and local service refuses arbitrary ABAP',async()=>{
  const {e,n}=fixture();const r=e.submit(request(n),user);await e.execute(r.id);
  const edit=structuredClone(n);edit.cells[0].source='DELETE FROM live_data.';
  const changed=e.save(n.id,{...edit,expectedRevision:1},user);assert.ok(changed.cells.every(c=>c.output.stale));
  assert.equal(e.validate(n.id,'seed',user).supported,false);
  const next=e.submit(request(changed),user);await e.execute(next.id);assert.equal(e.run(next.id,user).error.code,'NATIVE_REQUIRED');
});
test('paging is bounded, ordered, immutable, revision checked and owner restricted',async()=>{
  const {e,n}=fixture();const r=e.submit(request(n),user);await e.execute(r.id);
  const p=e.preview(r.id,'seed',1,2,2,user);assert.deepEqual(p.rows,[{key:'CC300',amount:24000}]);
  p.rows[0].amount=0;assert.equal(e.preview(r.id,'seed',1,2,2,user).rows[0].amount,24000);
  assert.throws(()=>e.preview(r.id,'seed',2,0,2,user),{code:'OUTPUT_REVISION'});
  assert.throws(()=>e.preview(r.id,'seed',1,0,101,user),{code:'PAGE'});
  assert.throws(()=>e.preview(r.id,'seed',1,0,2,'bob'),{code:'NOT_FOUND'});
});
test('cancel, timeout and worker-loss recovery are terminal without implicit retry',async()=>{
  const {e,n}=fixture();const r=e.submit(request(n),user);e.cancel(r.id,user);await e.execute(r.id);assert.equal(e.run(r.id,user).state,'cancelled');
  const r2=e.submit(request(n),user);e.db.runs[r2.id].timeoutMs=-1;await e.execute(r2.id);assert.equal(e.run(r2.id,user).error.code,'TIMEOUT');
  const dir=mkdtempSync(join(tmpdir(),'bpc-notebook-'));try{
    const path=join(dir,'store.json');const persistent=new Engine({file:path,auto:false});const notebook=persistent.create({...demo(),technicalName:"TEST_ALLOCATION",description:"Test allocation"},user);
    const req=request(notebook);const run=persistent.submit(req,user);const recovered=new Engine({file:path,auto:false});
    assert.equal(recovered.run(run.id,user).error.code,'WORKER_LOST');assert.equal(recovered.submit(req,user).id,run.id);
  }finally{rmSync(dir,{recursive:true,force:true});}
});
