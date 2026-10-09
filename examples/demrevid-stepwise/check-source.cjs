// Read-only ADT syntax checking of business bodies before the artifact API is deployed.
// Artifact calls are deliberately substituted; this does NOT validate their runtime contract.
const fs=require('node:fs');
const path=require('node:path');
process.argv.push('--codex-env');
const client=require('../../tools/adt-config.cjs')();
const definition=require('./definition.draft.json');
(async()=>{
 await client.login();
 const evidence={kind:'read-only substituted artifact syntax check',artifactApiVerified:false,cells:[]};
 try {
  const url='/sap/bc/adt/oo/classes/zcl_bn_compiler/source/main';
  const baseline=fs.readFileSync(path.resolve(__dirname,'../../src/zcl_bn_compiler.clas.abap'),'utf8');
  for(const cell of definition.cells){
   const substituted=cell.source.replace(/io->read_dataset\( dependency = '[^']+' name = '[^']+' \)/g,'NEW zcl_bn_dem_model=>tabl( )').replace(/io->publish_dataset\( name = '[^']+' rows = [\s\S]*?\)\./g,'');
   const source=baseline.replace('PUBLIC SECTION.','PUBLIC SECTION.\nCLASS-METHODS execute IMPORTING io TYPE REF TO zcl_bn_context RAISING zcx_bn.').replace('CLASS zcl_bn_compiler IMPLEMENTATION.','CLASS zcl_bn_compiler IMPLEMENTATION.\nMETHOD execute.\n'+substituted+'\nENDMETHOD.\n');
   const diagnostics=await client.syntaxCheck(url,url,source);
   evidence.cells.push({id:cell.id,diagnostics});
   console.log(JSON.stringify({id:cell.id,errors:diagnostics.filter(d=>d.severity==='E').slice(0,4),count:diagnostics.length}));
  }
  fs.writeFileSync(path.join(__dirname,'source-syntax.json'),JSON.stringify(evidence,null,2)+'\n');
 } finally {await client.logout();}
})().catch(e=>{console.error(e.message);process.exitCode=1});
