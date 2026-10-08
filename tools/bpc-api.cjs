process.argv.push('--codex-env');require('./adt-config.cjs')();
async function api(path,data,method='POST'){
 const r=await fetch(new URL('/sap/bc/zbpc_notebook'+path+(path.includes('?')?'&':'?')+'sap-client='+process.env.SAP_CLIENT,process.env.SAP_URL),{method,headers:{Authorization:'Basic '+Buffer.from(process.env.SAP_USER+':'+process.env.SAP_PASSWORD).toString('base64'),'Content-Type':'application/json','X-BPC-Notebook':'1'},body:data?JSON.stringify(data):undefined});
 const v=await r.json();if(!r.ok)throw Error(JSON.stringify(v));return v;
}
module.exports=api;
