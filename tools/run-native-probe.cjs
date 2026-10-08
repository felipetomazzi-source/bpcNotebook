// Development-only evidence runner. Never called by the application.
const fs = require('node:fs');
const client = require('./adt-config.cjs')();
(async () => {
  await client.login();
  try {
    const result = await client.unitTestRun('/sap/bc/adt/oo/classes/zcl_bn_probe',
      {harmless:true,dangerous:true,critical:false,short:true,medium:true,long:false});
    fs.mkdirSync('docs/evidence',{recursive:true});
    fs.writeFileSync('docs/evidence/native-probe.json',JSON.stringify({at:new Date().toISOString(),result},null,2));
    console.log(JSON.stringify(result,null,2));
    if (result.reduce((sum,c)=>sum+c.testmethods.length,0)!==3 || result.some(c=>c.alerts.length || c.testmethods.some(m=>m.alerts.length))) process.exitCode=1;
  } finally { await client.logout(); }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
