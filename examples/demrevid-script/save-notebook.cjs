// Save the operational Script-only notebook; never modify another notebook implicitly.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),vm=require('node:vm');
const api=require('../../tools/bpc-api.cjs');
const local=p=>path.join(__dirname,p);
let Script;vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../../webapp/model/Script.js'),'utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
const options=Object.fromEntries(process.argv.filter(x=>/^--[^=]+=/.test(x)).map(x=>{const p=x.indexOf('=');return[x.slice(2,p),x.slice(p+1)];}));
(async()=>{
 const definition=JSON.parse(fs.readFileSync(local('definition.draft.json'),'utf8'));
 assert.equal(definition.cells.length,21);
 assert(definition.cells.every(c=>c.source&&Script.unpack(c.source).language==='script'));
 assert(!definition.cells.some(c=>/zcl_bn_dem_alloc|zcl_bpc_demrevid_calc_003/i.test(c.source)));
 let id=options.notebook;
 if(!id&&fs.existsSync(local('notebook-id.txt')))id=fs.readFileSync(local('notebook-id.txt'),'utf8').trim();
 let notebook;
 if(id){const current=await api('/notebook?id='+encodeURIComponent(id),null,'GET');
  assert.equal(current.title,definition.title,'Explicitly review the target notebook before overwriting');
  notebook=await api('/notebook',{...definition,id:current.id,expectedRevision:current.revision},'PUT');
 }else notebook=await api('/notebooks',definition);
 fs.writeFileSync(local('notebook-id.txt'),notebook.id+'\n');
 for(const cell of definition.cells){const result=await api('/validate',{notebookId:notebook.id,cellId:cell.id});
  assert(!result.diagnostics.some(d=>['error','E'].includes(d.severity)),JSON.stringify({cell:cell.id,diagnostics:result.diagnostics}));}
 console.log(JSON.stringify({notebookId:notebook.id,title:notebook.title,revision:notebook.revision,cells:21,language:'script',financialPosting:false}));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
