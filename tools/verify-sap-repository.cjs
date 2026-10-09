process.argv.push('--codex-env');
const fs=require('fs'),{execFileSync}=require('child_process'),{createHash}=require('crypto'),c=require('./adt-config.cjs')();
const args=Object.fromEntries(process.argv.filter(x=>x.startsWith('--')&&x.includes('=')).map(x=>x.slice(2).split('=')));
const repoId=args['repo-id'], target=args.package || 'ZBPC_NOTEBOOK';
if(!/^\d{12}$/.test(repoId||'')||!/^[$A-Z0-9_]+$/.test(target))throw Error('Specify --repo-id=<12 digit SAP repository key> and optionally --package=<ID>');
(async()=>{await c.login();c.stateful='stateful';try{
 const name='ZCL_BN_SERIALIZE_CHECK',url='/sap/bc/adt/oo/classes/zcl_bn_serialize_check';
 // Run the already installed, reviewed helper. Never upload global source here.
 const installed=await c.getObjectSource(url+'/source/main');
 if(!installed.includes("get( '"+repoId+"' )") || !installed.includes("get_package( ) <> '"+target+"'"))
   throw Error('Installed serialization helper does not target this repository/package; update only through reviewed Git/abapGit transport');
 const output=await c.runClass(name);if(output.includes('BNERROR|'))throw Error(output);
 const commit=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();
 const expected=new Set(['.abapgit.xml',...execFileSync('git',['ls-tree','-r','--name-only','HEAD','src'],{encoding:'utf8'}).trim().split(/\r?\n/)]);
 const evidence={at:new Date().toISOString(),repoId,package:target,transport:args.transport || '',commit,
  method:'Full online abapGit repository serialization (refresh + get_files_local) after network pull, compared byte-for-byte with committed Git blobs',files:[],missing:[],passed:false};
 for(const line of output.split(/\r?\n/)){if(!line.startsWith('BNFILE|'))continue;
  const [,path,base64]=line.split('|'), filename=path.replace(/^\//,''),bytes=Buffer.from(base64,'base64');
  if(!expected.has(filename))throw Error('Unexpected serialized file '+filename);
  const git=execFileSync('git',['show','HEAD:'+filename],{maxBuffer:10e6});
  evidence.files.push({filename,bytes:bytes.length,sapSha256:createHash('sha256').update(bytes).digest('hex'),equal:bytes.equals(git)});
  expected.delete(filename);
 }
 evidence.missing=[...expected];evidence.passed=evidence.files.every(f=>f.equal)&&!evidence.missing.length;
 fs.writeFileSync('docs/evidence/bpc-deployment.json',JSON.stringify(evidence,null,2)+'\n','utf8');
 console.log(JSON.stringify({commit,files:evidence.files.length,passed:evidence.passed,missing:evidence.missing,differences:evidence.files.filter(f=>!f.equal)}));
 if(!evidence.passed)process.exitCode=1;
}finally{await c.logout();}})().catch(e=>{console.error(e.message);process.exitCode=1;});
