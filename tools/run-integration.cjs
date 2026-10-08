// Requires Basis permission for dangerous/long tests and trusted DEV-user enablement.
const fs=require('node:fs');
const client=require('./adt-config.cjs')();
(async()=>{
  await client.login();
  try{
    const result=await client.unitTestRun('/sap/bc/adt/oo/classes/zcl_bn_service',
      {harmless:true,dangerous:true,critical:false,short:true,medium:true,long:true});
    fs.mkdirSync('docs/evidence',{recursive:true});
    fs.writeFileSync('docs/evidence/native-integration.json',JSON.stringify({at:new Date().toISOString(),result},null,2));
    console.log(JSON.stringify(result,null,2));
    if(!result.some(c=>c.testmethods.length>0) || result.some(c=>c.alerts.length || c.testmethods.some(m=>m.alerts.length)))process.exitCode=1;
  }finally{await client.logout();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
