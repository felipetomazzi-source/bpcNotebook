// A diagnostic's ABAP runs in a normal preview-only Notebook cell, never a global source upload.
const api=require('./bpc-api.cjs'),{randomUUID}=require('node:crypto');
module.exports=async function runProbe(title,source){
 const n=await api('/notebooks',{title,inputs:[],cells:[{id:'probe',title:'Read-only diagnostic',source,dependencies:[]}]});
 try{
  let run=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:randomUUID()});
  for(let i=0;i<60&&['queued','running'].includes(run.state);i++){
   await new Promise(resolve=>setTimeout(resolve,500));run=await api('/run?id='+run.id,null,'GET');
  }
  if(run.state!=='succeeded')throw Error(JSON.stringify(run.error||{state:run.state}));
  return run;
 }finally{await api('/delete-notebook',{notebookId:n.id,expectedRevision:n.revision});}
};
