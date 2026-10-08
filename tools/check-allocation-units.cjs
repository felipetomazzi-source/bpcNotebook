process.argv.push('--codex-env');const fs=require('fs'),assert=require('node:assert/strict'),c=require('./adt-config.cjs')();
(async()=>{await c.login();try{const result={at:new Date().toISOString(),classes:[],passed:true};
 for(const name of ['ZCL_BN_BPC','ZCL_BN_DEM_ALLOC']){
  const tests=await c.unitTestRun('/sap/bc/adt/oo/classes/'+name.toLowerCase());
  result.classes.push({name,tests});const methods=tests.flatMap(x=>x.testmethods||[]);
  const passed=methods.length>0&&tests.every(x=>!(x.alerts||[]).length&&(x.testmethods||[]).every(y=>!(y.alerts||[]).length));
  result.passed&&=passed;console.log(name,methods.length,'tests',passed?'PASS':'FAIL');
  if(!passed)console.log(JSON.stringify(tests));
 }
 fs.writeFileSync('.local/allocation-unit-evidence.json',JSON.stringify(result,null,2),'utf8');assert(result.passed,'Native allocation unit tests failed');
}finally{await c.logout();}})().catch(e=>{console.error(e.message);process.exitCode=1;});
