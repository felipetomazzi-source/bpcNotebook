// Native formatter and Script comment smoke test; no global source uploads or posting.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),{randomUUID}=require('crypto'),api=require('./bpc-api.cjs');
const c=require('./adt-config.cjs')();
let Script,Api;
vm.runInNewContext(fs.readFileSync('webapp/model/Script.js','utf8'),{TextEncoder,TextDecoder,btoa,atob,sap:{ui:{define:(_,f)=>Script=f()}}});
const text='# Allocation É · São\n// Explain inputs\nscript version 2 compact // version\nlet factor = 2 // factor\nif factor > 1\nmessage "Script É · São // # literal"\n// Explain result\nelse\nmessage "wrong branch"\nend\n';
(async()=>{
 await c.login();let notebook;
 try {
  vm.runInNewContext(fs.readFileSync('webapp/model/Api.js','utf8'),{URL,URLSearchParams,window:{location:{search:'?sap-client=001',href:'http://sap.invalid/'}},
   fetch:async(url,options)=>options.method==='POST'?new Response(await c.prettyPrinter(options.body)):new Response('',{headers:{'X-CSRF-Token':'sdk-session'}}),
   sap:{ui:{require:{toUrl:()=>'/sap/bc/ui5_ui5/sap/zbpc_notebook/Component.js'},define:(_,f)=>Api=f()}}});
  const raw="DATA total TYPE i. total = 2. IF total > 1. io->message( 'ABAP É · São' ). ENDIF.";
  const abap=await Api.prettyPrint(raw),script=Script.prettyPrint(text);
  assert.ok(abap.includes('\n'));assert.ok(abap.includes('É · São'));
  assert.equal(Script.compile(text).split('* @bn-generated\n')[1],Script.compile(script).split('* @bn-generated\n')[1]);
  assert.equal(Script.unpack(Script.compile(script)).text,script);
  const context=await api('/notebook?id=E82AEA36D1571FE1B18BD135480E4C5E',null,'GET');
  const cells=[['abap_raw',raw],['abap_formatted',abap],['script_raw',Script.compile(text)],['script_formatted',Script.compile(script)]].map(([id,source])=>({id,title:id,source,dependencies:[]}));
  notebook=await api('/notebooks',{title:'Controlled editor validation',technicalName:'TEST_EDITOR_'+randomUUID().replaceAll('-','').slice(0,16).toUpperCase(),description:'Native comment and formatting validation',environment:context.environment,model:context.model,inputs:[],cells});
  let run=await api('/runs',{notebookId:notebook.id,expectedRevision:notebook.revision,scope:'all',idempotencyKey:randomUUID()});
  for(let i=0;i<90 && ['queued','running'].includes(run.state);i++){await new Promise(r=>setTimeout(r,500));run=await api('/run?id='+run.id,null,'GET');}
  assert.equal(run.state,'succeeded',JSON.stringify(run.error));assert.equal(run.results.length,4);
  const evidence={at:new Date().toISOString(),passed:true,notebookId:notebook.id,runId:run.id,completedCells:run.results.length,comments:['#','//','before version declaration','inline','literal markers'],scriptGeneratedLogicEqual:true,nativeAbapFormatting:true,posting:false};
  fs.writeFileSync('docs/evidence/editor-usability-native.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));
 }finally{if(notebook)await api('/delete-notebook',{notebookId:notebook.id,expectedRevision:notebook.revision});await c.logout();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
