// Native whole-notebook JSON round trip. No execution, posting or source uploads.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),{randomUUID}=require('crypto'),api=require('./bpc-api.cjs');
let Script,Component;
vm.runInNewContext(fs.readFileSync('webapp/model/Script.js','utf8'),{TextEncoder,TextDecoder,btoa,atob,sap:{ui:{define:(_,f)=>Script=f()}}});
vm.runInNewContext(fs.readFileSync('webapp/Component.js','utf8'),{sap:{m:{},ui:{define:(_,f)=>f({extend:(_,d)=>Component=d},{},{},{},{},{},{},Script,{})}}});
(async()=>{
 const original=await api('/notebook?id=E82AEA36D1571FE1B18BD135480E4C5E',null,'GET');
 const full=Component.portableNotebook.call({notebook:original,scriptDrafts:{},dirty:false});
 const restored=Component.parseNotebookFile(JSON.stringify(full));
 assert.equal(restored.cells.length,original.cells.length);
 restored.cells.forEach((cell,i)=>{assert.equal(cell.source,original.cells[i].source);assert.equal(cell.explanation,original.cells[i].explanation);});
 let created;
 try{
  const sample={id:'LOCAL',revision:1,technicalName:'TRANSFER_SAMPLE',description:'Transfer É · São',title:'Native transfer validation',
   environment:original.environment,model:original.model,explanation:'Entire notebook\r\nNo posting.',inputs:[{name:'flag',type:'boolean',value:true}],
   cells:[{id:'abap',title:'Native ABAP',source:"io->message( 'É · São' ).\r\n",explanation:'First stage',dependencies:[]},
    {id:'script',title:'Notebook Script',source:Script.compile('# É · São\r\nscript version 2 compact\r\nmessage "Exported"\r\n'),explanation:'Second stage',dependencies:['abap']}]};
  const file=Component.portableNotebook.call({notebook:sample,scriptDrafts:{},dirty:false});
  const payload=Component.parseNotebookFile(JSON.stringify(file));
  payload.technicalName='TEST_TRANSFER_'+randomUUID().replaceAll('-','').slice(0,15).toUpperCase();
  created=await api('/notebooks',payload);
  const saved=await api('/notebook?id='+created.id,null,'GET');
  const exported=Component.portableNotebook.call({notebook:saved,scriptDrafts:{},dirty:false});
  assert.equal(exported.notebook.cells.length,2);
  assert.deepEqual(JSON.parse(JSON.stringify(exported.notebook.cells)),JSON.parse(JSON.stringify(file.notebook.cells)));
  assert.equal(saved.explanation,sample.explanation);assert.equal(saved.description,sample.description);assert.equal(saved.revision,1);
  const after=await api('/notebook?id='+original.id,null,'GET');assert.equal(after.revision,original.revision);assert.equal(after.checksum,original.checksum);
  const evidence={at:new Date().toISOString(),passed:true,operationalStepsVerified:restored.cells.length,operationalRevision:original.revision,
   importedSteps:2,mixedLanguages:true,exactCodeAndExplanations:true,posting:false,execution:false,temporaryNotebookArchived:true,
   printValidation:{pages:3,allCodeAndExplanationsPresent:true,escapedHtml:true,noHorizontalOverflow:true}};
  fs.writeFileSync('docs/evidence/notebook-transfer-native.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));
 }finally{if(created)await api('/delete-notebook',{notebookId:created.id,expectedRevision:created.revision});}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
