// Installs only this prototype's DDIC/service sources into $TMP for DEV verification.
// Full deployment belongs in package ZBPC_NOTEBOOK via abapGit/CTS; no ICF enablement here.
const fs=require('node:fs');
const client=require('./adt-config.cjs')();
const evidence={at:new Date().toISOString(),package:'$TMP',tables:[],activation:null,tests:null};
const definitions={
 zbn_head:`key mandt : abap.clnt not null; key kind : abap.char(1) not null; key id : abap.char(64) not null; revision : abap.int4; owner : abap.char(12);`,
 zbn_doc:`key mandt : abap.clnt not null; key kind : abap.char(1) not null; key id : abap.char(64) not null; key revision : abap.int4 not null;
 author : abap.char(12); created_at : abap.dec(21,7); checksum : abap.char(64); payload : abap.string(0);`,
 zbn_src:`key mandt : abap.clnt not null; key notebook_id : abap.char(32) not null; key cell_id : abap.char(30) not null; key version : abap.int4 not null;
 sequence : abap.int4; author : abap.char(12); created_at : abap.dec(21,7); checksum : abap.char(64); dependencies : abap.string(0); source : abap.string(0);`
};
async function install(name,type,url,source){
  console.log('Installing',name);
  const found=await client.searchObject(name.toUpperCase(),'',10);
  if(!found.some(o=>o['adtcore:name']===name.toUpperCase())) await client.createObject(type,name.toUpperCase(),'$TMP','BPC Notebook DEV verification','/sap/bc/adt/packages/%24tmp');
  const {LOCK_HANDLE}=await client.lock(url);
  if(!LOCK_HANDLE)throw new Error('Lock handle missing for '+name);
  try{await client.setObjectSource(url+'/source/main',source,LOCK_HANDLE);}finally{await client.unLock(url,LOCK_HANDLE);}
}
(async()=>{
  await client.login();
  client.stateful='stateful';
  try{
    for(const [name,fields] of Object.entries(definitions)){
      const url='/sap/bc/adt/ddic/tables/'+name;
      const source=`@EndUserText.label : 'BPC Notebook ${name}'
@AbapCatalog.enhancementCategory : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ${name} { ${fields} }`;
      await install(name,'TABL/DT',url,source);
      const result=await client.activate(name.toUpperCase(),url);evidence.tables.push({name,result});
      console.log(name,JSON.stringify(result));
    }
    const objects=[];
    const names=['zcx_bn','zcl_bn_types','zcl_bn_store','zcl_bn_context','zcl_bn_compiler','zcl_bn_service','zcl_bn_http'];
    for(const name of names){
      const url='/sap/bc/adt/oo/classes/'+name;
      await install(name,'CLAS/OC',url,fs.readFileSync('src/'+name+'.clas.abap','utf8'));
      objects.push({'adtcore:uri':url,'adtcore:name':name.toUpperCase(),'adtcore:type':'CLAS/OC','adtcore:parentUri':'/sap/bc/adt/packages/%24tmp'});
      if(fs.existsSync('src/'+name+'.clas.testclasses.abap')){
        const {LOCK_HANDLE}=await client.lock(url);
        try{
          let exists=false;
          try{await client.getObjectSource(url+'/includes/testclasses');exists=true;}catch{}
          if(!exists)await client.createTestInclude(name.toUpperCase(),LOCK_HANDLE,'');
          await client.setObjectSource(url+'/includes/testclasses',fs.readFileSync('src/'+name+'.clas.testclasses.abap','utf8'),LOCK_HANDLE);
        }finally{await client.unLock(url,LOCK_HANDLE);}
      }
    }
    await install('zbn_job','PROG/P','/sap/bc/adt/programs/programs/zbn_job',fs.readFileSync('src/zbn_job.prog.abap','utf8'));
    objects.push({'adtcore:uri':'/sap/bc/adt/programs/programs/zbn_job','adtcore:name':'ZBN_JOB','adtcore:type':'PROG/P','adtcore:parentUri':'/sap/bc/adt/packages/%24tmp'});
    evidence.activation=await client.activate(objects);console.log(JSON.stringify(evidence.activation,null,2));
    if(evidence.activation.success){
      evidence.tests=await client.unitTestRun('/sap/bc/adt/oo/classes/zcl_bn_compiler');console.log(JSON.stringify(evidence.tests,null,2));
      if(evidence.tests.some(c=>c.alerts.length || c.testmethods.some(m=>m.alerts.length)))process.exitCode=1;
    }else{process.exitCode=1;}
  }finally{
    fs.mkdirSync('docs/evidence',{recursive:true});fs.writeFileSync('docs/evidence/native-check.json',JSON.stringify(evidence,null,2));await client.logout();
  }
})().catch(e=>{console.error(e.message);process.exitCode=1;});

