// Refresh only the Notebook application's standard SAPUI5 cache-buster metadata after deployment.
process.argv.push('--codex-env');require('./adt-config.cjs')();
const fs=require('node:fs'),assert=require('node:assert/strict'),{createHash}=require('node:crypto');
const base=new URL('/sap/bc/ui5_ui5/sap/zbpc_notebook/',process.env.SAP_URL);
async function get(path){const url=new URL(path,base);url.searchParams.set('sap-client',process.env.SAP_CLIENT);
 const response=await fetch(url,{headers:{Authorization:'Basic '+Buffer.from(process.env.SAP_USER+':'+process.env.SAP_PASSWORD).toString('base64'),'Cache-Control':'no-cache'}});
 const text=await response.text();if(!response.ok)throw Error('SAP UI resource '+path+' returned HTTP '+response.status);
 return {text,status:response.status,modified:response.headers.get('last-modified'),cache:response.headers.get('cache-control')};}
(async()=>{
 const before=JSON.parse((await get('sap-ui-cachebuster-info.json')).text);
 await get('do-update-meta-data');
 const after=JSON.parse((await get('sap-ui-cachebuster-info.json')).text),token=after['Component.js'];
 assert.match(token,/^[A-Za-z0-9_~.-]+$/);
 const component=await get('~'+token+'~/Component.js'),index=await get('index.html');
 assert(component.text.includes('stageTabs'),'Cache-busted component must contain the deployed stage UI');
 assert(!component.text.includes('SAP DEV PROTOTYPE'),'Obsolete component was served');
 assert(index.text.includes('data-sap-ui-appCacheBuster'),'Standalone bootstrap must enable application cache busting');
 const evidence={at:new Date().toISOString(),application:'ZBPC_NOTEBOOK',action:'Per-repository do-update-meta-data',before,after,
  cacheBustedComponent:{token,status:component.status,modified:component.modified,cache:component.cache,sha256:createHash('sha256').update(component.text).digest('hex')},passed:true};
 fs.writeFileSync('docs/evidence/ui-cache-refresh.json',JSON.stringify(evidence,null,2)+'\n','utf8');
 console.log(JSON.stringify({passed:true,componentToken:token,oldToken:before['Component.js'],cacheBustedStatus:component.status}));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
