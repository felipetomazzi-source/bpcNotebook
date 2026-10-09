const fs=require('node:fs'),assert=require('node:assert/strict'),api=require('./bpc-api.cjs'),{randomUUID}=require('node:crypto');
(async()=>{
 const source="DATA x TYPE i.\r\n\r\nx = 1.\r\nio->message( 'É · native source' ).\r\n";
 const label='É · "quoted" \\ literal \\u0001\r\n\tstandalone\rCR';
 const definition={title:'Platform native text persistence verification',inputs:[{name:'label',type:'string',value:label}],cells:[{id:'text',title:'Native text',source,dependencies:[]}]};
 await assert.rejects(api('/notebooks',{...definition,inputs:[{name:'label',type:'string',value:'bad\x01'}]}),/JSON_UNICODE|TEXT_CONTROL/);
 const n=await api('/notebooks',definition);try{
  const saved=await api('/notebook?id='+n.id,null,'GET');assert.equal(saved.cells[0].source,source);assert.equal(saved.inputs[0].value,label);
  const validation=await api('/validate',{notebookId:n.id,cellId:'text'});assert.equal(validation.diagnostics.length,0);
  let run=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:randomUUID()});
  for(let i=0;i<60&&['queued','running'].includes(run.state);i++){await new Promise(resolve=>setTimeout(resolve,500));run=await api('/run?id='+run.id,null,'GET');}
  assert.equal(run.state,'succeeded',JSON.stringify(run.error));assert.equal(run.snapshot.cells[0].source,source);assert.equal(run.snapshot.inputs[0].value,label);
  const evidence={at:new Date().toISOString(),runId:run.id,method:'Actual REST save/read/validate/background execution and frozen snapshot',crlf:true,tab:true,unicode:true,quotes:true,backslash:true,literalUnicodeEscape:true,unsupportedControlRejected:true,globalSourceUploads:false,passed:true};
  fs.writeFileSync('docs/evidence/native-text-persistence.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));
 }finally{await api('/delete-notebook',{notebookId:n.id,expectedRevision:n.revision});}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
