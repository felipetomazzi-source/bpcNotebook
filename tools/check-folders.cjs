const fs=require('node:fs'),assert=require('node:assert/strict'),api=require('./bpc-api.cjs');
(async()=>{
 let current=await api('/folders',null,'GET');current.folders ||= [];current.memberships ||= [];
 const initial=structuredClone(current),save=async next=>{current=await api('/folders',{...next,expectedRevision:current.revision||0},'PUT');current.folders ||= [];current.memberships ||= [];return current;};
 const id='verify_'+Date.now();let n;
 try {
  n=await api('/notebooks',{title:'Platform folder verification',explanation:'Controlled organization test; no financial posting.',inputs:[],cells:[{id:'check',title:'Check',source:"io->message( 'Folder test' ).",dependencies:[]}]});
  const original=await api('/notebook?id='+n.id,null,'GET');const versions=await api('/versions?id='+n.id,null,'GET');
  await save({...current,folders:[...current.folders,{id,name:'Folder · É verification'}]});
  await save({...current,memberships:[...current.memberships,{notebookId:n.id,folderId:id}]});
  await assert.rejects(api('/folders',{...current,expectedRevision:0},'PUT'),/CONFLICT/);
  await assert.rejects(api('/folders',{...current,expectedRevision:current.revision,folders:current.folders.filter(f=>f.id!==id),memberships:current.memberships.filter(m=>m.notebookId!==n.id)},'PUT'),/FOLDER_NOT_EMPTY/);
  await assert.rejects(api('/folders',{...current,expectedRevision:current.revision,memberships:[...current.memberships,{notebookId:'not_owned_or_missing',folderId:id}]},'PUT'),/NOT_FOUND/);
  await assert.rejects(api('/folders',{...current,expectedRevision:current.revision,folders:[...current.folders,{id:id+'_duplicate',name:'FOLDER · É VERIFICATION'}]},'PUT'),/FOLDER/);
  await save({...current,folders:current.folders.map(f=>f.id===id?{...f,name:'Renamed folder · É'}:f)});
  assert.deepEqual(await api('/folders',null,'GET'),current);
  assert.deepEqual(await api('/notebook?id='+n.id,null,'GET'),original);
  assert.deepEqual(await api('/versions?id='+n.id,null,'GET'),versions);
  await save({...current,memberships:current.memberships.filter(m=>m.notebookId!==n.id)});
  await save({...current,folders:current.folders.filter(f=>f.id!==id)});
  assert.deepEqual(current.folders,initial.folders);assert.deepEqual(current.memberships,initial.memberships);
  const evidence={at:new Date().toISOString(),passed:true,notebookId:n.id,checks:['create','move','rename','reload','stale revision','nonempty removal rejected','unknown or unowned notebook rejected','duplicate name rejected','unfile','empty removal','notebook source/revision/history unchanged'],financialPosting:false,globalSourceUploads:false};
  fs.writeFileSync('docs/evidence/native-folders.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));
 }finally{
  if(current.memberships.some(m=>m.folderId===id))await save({...current,memberships:current.memberships.filter(m=>m.folderId!==id)});
  if(current.folders.some(f=>f.id===id))await save({...current,folders:current.folders.filter(f=>f.id!==id)});
  if(n)await api('/delete-notebook',{notebookId:n.id,expectedRevision:n.revision});
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
