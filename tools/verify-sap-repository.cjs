process.argv.push('--codex-env');
const fs=require('fs'),{execFileSync}=require('child_process'),{createHash}=require('crypto'),c=require('./adt-config.cjs')();
const args=Object.fromEntries(process.argv.filter(x=>x.startsWith('--')&&x.includes('=')).map(x=>x.slice(2).split('=')));
const repoId=args['repo-id'], target=args.package || 'ZBPC_NOTEBOOK';
if(!/^\d{12}$/.test(repoId||'')||!/^[$A-Z0-9_]+$/.test(target))throw Error('Specify --repo-id=<12 digit SAP repository key> and optionally --package=<ID>');
(async()=>{await c.login();c.stateful='stateful';try{
 const name='ZCL_BN_SERIALIZE_CHECK',url='/sap/bc/adt/oo/classes/zcl_bn_serialize_check';
 const source=`CLASS zcl_bn_serialize_check DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION. INTERFACES if_oo_adt_classrun.
ENDCLASS.
CLASS zcl_bn_serialize_check IMPLEMENTATION.
 METHOD if_oo_adt_classrun~main.
  TRY.
   DATA(repo) = zcl_abapgit_repo_srv=>get_instance( )->get( '${repoId}' ).
   IF repo->get_package( ) <> '${target}'. out->write( 'BNERROR|Wrong package' ). RETURN. ENDIF.
   repo->refresh( abap_true ).
   DATA(files) = repo->get_files_local( ).
   LOOP AT files INTO DATA(file).
    out->write( 'BNFILE|' && file-file-path && file-file-filename && '|' && cl_http_utility=>encode_x_base64( file-file-data ) ).
   ENDLOOP.
  CATCH cx_root INTO DATA(error). out->write( 'BNERROR|' && error->get_text( ) ). ENDTRY.
 ENDMETHOD.
ENDCLASS.`;
 const {LOCK_HANDLE}=await c.lock(url);try{await c.setObjectSource(url+'/source/main',source,LOCK_HANDLE);}finally{await c.unLock(url,LOCK_HANDLE);}
 const activation=await c.activate(name,url);if(!activation.success)throw Error(JSON.stringify(activation));
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
