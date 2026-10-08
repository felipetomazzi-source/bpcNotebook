import test from 'node:test';
import assert from 'node:assert/strict';
import { Engine, demo } from '../local/engine.mjs';
import { createServer } from '../local/server.mjs';
const user='alice';
const request=n=>({notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:crypto.randomUUID()});

test('notebook deletion checks ownership/revision/active runs and retains immutable history and outputs',async()=>{
 const e=new Engine({auto:false,delay:0}),n=e.create(demo(),user),run=e.submit(request(n),user);
 assert.throws(()=>e.deleteNotebook(n.id,1,'bob'),{code:'NOT_FOUND'});
 assert.throws(()=>e.deleteNotebook(n.id,0,user),{code:'CONFLICT'});
 assert.throws(()=>e.deleteNotebook(n.id,1,user),{code:'NOTEBOOK_BUSY'});
 await e.execute(run.id);
 assert.deepEqual(e.deleteNotebook(n.id,1,user),{deleted:true});
 assert.equal(e.list(user).length,0);
 assert.throws(()=>e.get(n.id,user),{code:'NOTEBOOK_DELETED'});
 assert.throws(()=>e.save(n.id,{...n,expectedRevision:1},user),{code:'NOTEBOOK_DELETED'});
 assert.throws(()=>e.submit(request(n),user),{code:'NOTEBOOK_DELETED'});
 assert.equal(e.history(n.id,user)[0].cells[0].source,n.cells[0].source);
 assert.equal(e.run(run.id,user).state,'succeeded');
 assert.equal(e.preview(run.id,'allocate',1,0,2,user).rows[0].amount,66000);
});

test('removing cells in a saved revision retains old execution snapshots and rejects dangling dependencies',async()=>{
 const e=new Engine({auto:false,delay:0}),n=e.create(demo(),user),run=e.submit(request(n),user);
 await e.execute(run.id);
 assert.throws(()=>e.save(n.id,{...n,cells:[n.cells[1]],expectedRevision:1},user),{code:'DEPENDENCY_ORDER'});
 const saved=e.save(n.id,{...n,cells:[n.cells[0]],expectedRevision:1},user);
 assert.equal(saved.cells.length,1);
 assert.equal(e.history(n.id,user)[0].cells.length,2);
 assert.equal(e.run(run.id,user).snapshot.cells.length,2);
 assert.equal(e.preview(run.id,'allocate',1,0,2,user).rows[0].amount,66000);
});

test('HTTP notebook deletion uses the write protections and hides only the deleted notebook',async()=>{
 const e=new Engine({auto:false}),server=createServer(e);
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const base='http://127.0.0.1:'+server.address().port;
 const post=(path,data,headers={})=>fetch(base+'/api'+path,{method:'POST',headers:{'Content-Type':'application/json','X-BPC-Notebook':'1',...headers},body:JSON.stringify(data)});
 try{
  const n=await (await post('/notebooks',{demo:true})).json();
  assert.equal((await post('/delete-notebook',{notebookId:n.id,expectedRevision:1},{Origin:'https://foreign.example'})).status,403);
  assert.equal((await post('/delete-notebook',{notebookId:n.id,expectedRevision:0})).status,409);
  assert.equal((await post('/delete-notebook',{notebookId:n.id,expectedRevision:1})).status,200);
  assert.deepEqual(await (await fetch(base+'/api/notebooks')).json(),[]);
  assert.equal((await fetch(base+'/api/notebook?id='+n.id)).status,410);
  assert.equal((await fetch(base+'/api/versions?id='+n.id)).status,200);
 }finally{await new Promise(resolve=>server.close(resolve));}
});
