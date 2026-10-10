import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from '../local/server.mjs';
import { Engine } from '../local/engine.mjs';
test('HTTP demonstration: save, queue, review, page, and reject forged writes',async()=>{
  const engine=new Engine({auto:false});const server=createServer(engine);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base='http://127.0.0.1:'+server.address().port;
  const post=(path,data,headers={})=>fetch(base+path,{method:'POST',headers:{'Content-Type':'application/json','X-BPC-Notebook':'1',...headers},body:JSON.stringify(data)});
  try{
    const n=await (await post('/api/notebooks',{demo:true,technicalName:"TEST_DEMO",description:"Demo test"})).json();assert.equal(n.revision,1);
    const submission=await post('/api/runs',{notebookId:n.id,expectedRevision:1,scope:'all',cellId:'',idempotencyKey:crypto.randomUUID()});
    assert.equal(submission.status,202);const run=await submission.json();await engine.execute(run.id);
    const result=await (await fetch(base+'/api/run?id='+run.id)).json();assert.equal(result.state,'succeeded');
    const page=await (await fetch(base+'/api/output?runId='+run.id+'&cellId=allocate&revision=1&offset=0&limit=2')).json();assert.equal(page.total,3);
    assert.equal((await post('/api/notebooks',{demo:true,technicalName:"TEST_DEMO",description:"Demo test"},{Origin:'https://attacker.example'})).status,403);
    assert.equal((await fetch(base+'/api/notebooks',{method:'POST',body:'{}'})).status,403);
    assert.equal((await fetch(base+'/api/unknown')).status,404);
  }finally{await new Promise(resolve=>server.close(resolve));}
});
