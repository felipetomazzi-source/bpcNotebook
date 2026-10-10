// Explicit DEV deployment of the new notebook Data Manager adapter only.
const fs=require('node:fs'),assert=require('node:assert/strict');
process.argv.push('--codex-env');const c=require('./adt-config.cjs')();
const names=['ZCL_BN_DM','ZCL_BN_DM_PROCESS','ZCL_BN_DM_INSTALL'];
(async()=>{await c.login();c.stateful='stateful';try{const evidence=[];for(const name of names){
 console.log('Deploying',name);
 const url='/sap/bc/adt/oo/classes/'+name.toLowerCase();
 if(!(await c.searchObject(name,'',10)).some(x=>x['adtcore:name']===name))
  await c.createObject('CLAS/OC',name,'$TMP','Notebook Data Manager preview','/sap/bc/adt/packages/%24tmp');
 const source=fs.readFileSync('src/'+name.toLowerCase()+'.clas.abap','utf8');
 console.log('Reading transport');const info=await c.transportInfo(url+'/source/main');
 const transport=info.LOCKS?.HEADER?.TRKORR;
 console.log('Writing source');const lock=await c.lock(url);try{await c.setObjectSource(url+'/source/main',source,lock.LOCK_HANDLE,transport);}catch(e){console.error('Source write:',e.message,typeof e.response?.data==='string'?e.response.data:'');throw e;}finally{try{await c.unLock(url,lock.LOCK_HANDLE);}catch(e){console.error('Unlock:',e.message);}}
 const syntax=await c.syntaxCheck(url+'/source/main',url+'/source/main',source);console.log(name,JSON.stringify(syntax));
 assert(!syntax.some(x=>x.severity==='E'),JSON.stringify(syntax));
 let active=await c.activate(name,url);
 if(!active.success&&active.inactive?.length)active=await c.activate(active.inactive.filter(x=>x.object?.['adtcore:parentUri']===url||x.object?.['adtcore:uri']===url).map(x=>x.object),false);
 assert(active.success,JSON.stringify(active));
 evidence.push({name,syntax,active});
 }let installation;
 if(process.argv.includes('--install')){installation=await c.runClass('ZCL_BN_DM_INSTALL');console.log(installation);assert(installation.includes('BNINSTALL|')&&!installation.includes('BNERROR|'),installation);}
 fs.mkdirSync('docs/evidence',{recursive:true});fs.writeFileSync('docs/evidence/data-manager-deployment.json',JSON.stringify({at:new Date().toISOString(),objects:evidence,installation},null,2)+'\n');
}finally{await c.logout()}})().catch(e=>{console.error(e.message, typeof e.response?.data==='string'?e.response.data:'');process.exitCode=1});
