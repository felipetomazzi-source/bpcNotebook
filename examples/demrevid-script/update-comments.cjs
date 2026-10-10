// Update only author comments in the existing operational notebook, never its selections.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const api=require('../../tools/bpc-api.cjs'),{annotate,generatedLogic}=require('./comments.cjs');
let Script;vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../../webapp/model/Script.js'),'utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
(async()=>{
 const id=fs.readFileSync(path.join(__dirname,'notebook-id.txt'),'utf8').trim();
 const current=await api('/notebook?id='+encodeURIComponent(id),null,'GET');
 assert.equal(current.technicalName,'DEMREVID003_ALLOCATION');assert.equal(current.cells.length,21);
 const cells=current.cells.map(c=>{
  const unpacked=Script.unpack(c.source);assert.equal(unpacked.language,'script');
  const text=annotate(unpacked.text,c.title,c.explanation||'');const source=Script.compile(text);
  assert.equal(generatedLogic(source),generatedLogic(c.source),c.id+' generated calculation changed');
  return {...c,source};
 });
 const changed=cells.some((c,i)=>c.source!==current.cells[i].source);
 const saved=changed?await api('/notebook',{id:current.id,expectedRevision:current.revision,title:current.title,
  explanation:current.explanation,environment:current.environment,model:current.model,inputs:current.inputs,cells},'PUT'):current;
 const checked=[];
 for(const cell of cells){const result=await api('/validate',{notebookId:id,cellId:cell.id});
  assert(!result.diagnostics.some(d=>['error','E'].includes(d.severity)),JSON.stringify({cell:cell.id,diagnostics:result.diagnostics}));checked.push(cell.id);}
 const readback=await api('/notebook?id='+encodeURIComponent(id),null,'GET');
 assert.equal(readback.revision,saved.revision);assert.deepEqual(readback.inputs,current.inputs);
 for(const cell of readback.cells)assert.equal(cell.source,cells.find(c=>c.id===cell.id).source);
 const evidence={at:new Date().toISOString(),notebookId:id,technicalName:current.technicalName,previousRevision:current.revision,
  revision:saved.revision,cells:checked.length,generatedLogicUnchanged:true,inputsUnchanged:true,readbackExact:true,financialPosting:false};
 fs.writeFileSync(path.join(__dirname,'comments-evidence.json'),JSON.stringify(evidence,null,2)+'\n');console.log(JSON.stringify(evidence));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
