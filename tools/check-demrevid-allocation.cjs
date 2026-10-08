const fs=require('node:fs'),assert=require('node:assert/strict'),api=require('./bpc-api.cjs');
const get=(p)=>api(p,null,'GET');
const options=Object.fromEntries(process.argv.filter(x=>/^--[^=]+=/.test(x)).map(x=>{const i=x.indexOf('=');return[x.slice(2,i),x.slice(i+1)];}));
(async()=>{
 const inputs=[
  {name:'CATEGORY',type:'member',dimension:'CATEGORY',required:true,selected:['Actual']},
  {name:'TIME',type:'range',dimension:'TIME',hierarchy:'PARENTH1',required:true,selected:[options.period||'2027.006']},
  {name:'REFERENCE_TIME',type:'range',purpose:'reference',dimension:'TIME',hierarchy:'PARENTH1',required:true,
   selected:['TIME_NA'],lookbackFrom:'TIME',lookbackSteps:1},
  {name:'READ_LIMIT',type:'number',value:'1000000'},
  {name:'PREVIEW_ROWS',type:'number',value:'100'},
  {name:'RUN_SECONDS',type:'number',value:'7200'},
  {name:'FFLASMATGROUPS',type:'boolean',value:true},
  {name:'FFLASMATGROUPSID',type:'string',value:'MATGROUPID038'},
  {name:'DEBUG',type:'string',value:'OFF'},
  {name:'HSNS_REALLOC_LOCATIONS',type:'string',value:''},
  {name:'STOP_AFTER',type:'string',value:options.stop||''}
 ];
 const notebook=await api('/notebooks',{title:'DEMREVID003 generic allocation - native verification',environment:'CH_PLANNING',model:'DEMREVID',inputs,
   cells:[{id:'allocation',title:'DEMREVID003 allocation in native working memory',source:"zcl_bn_dem_alloc=>execute( io = io stop_after = io->input( 'STOP_AFTER' ) ).",dependencies:[]}]});
 fs.writeFileSync('.local/allocation-notebook.json',JSON.stringify(notebook,null,2),'utf8');
 const saved=await get('/notebook?id='+notebook.id);assert(saved.inputs.find(i=>i.name==='REFERENCE_TIME').resolved.includes('TIME_NA'));
 const validation=await api('/validate',{notebookId:notebook.id,cellId:'allocation'});assert(!validation.diagnostics.some(d=>d.severity==='error'),JSON.stringify(validation));
 const request={notebookId:notebook.id,expectedRevision:notebook.revision,scope:'all',idempotencyKey:'allocation-check-'+Date.now()};
 let run=await api('/runs',request);console.log('Notebook',notebook.id,'run',run.id);
 while(['queued','running'].includes(run.state)){await new Promise(r=>setTimeout(r,1500));run=await get('/run?id='+run.id);}
 const evidence={at:new Date().toISOString(),notebookId:notebook.id,runId:run.id,state:run.state,inputs:saved.inputs,validation,
  checkpoints:run.checkpoints,error:run.error,messages:run.messages,results:run.results,businessEquivalent:false};
 if(run.state==='succeeded'){
  const output=await get('/output?runId='+run.id+'&cellId=allocation&revision=1&limit=1');
  evidence.tables=output.tables;console.log('Completed checkpoints:',run.checkpoints?.length,'preview tables:',output.tables?.length);
 }
 fs.writeFileSync('.local/allocation-native-evidence.json',JSON.stringify(evidence,null,2),'utf8');
 console.log('State',run.state,JSON.stringify(run.error));
 if(run.state!=='succeeded')process.exitCode=1;
})().catch(e=>{console.error(e.message);process.exitCode=1;});
