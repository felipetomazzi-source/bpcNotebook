const fs=require('node:fs');
const {spawnSync,execFileSync}=require('node:child_process');
const {createHash}=require('node:crypto');
const expected=new Map();
const evidence={at:new Date().toISOString(),method:'abapGit object deserializers and serializers through ADT classrun',objectPackage:'$TMP',packageMetadataTarget:'$BN_ROUNDTRIP',gitComparison:'Git clean-filter blobs (not the index or HEAD)',files:[],messages:[],passed:false};
const client=require('./adt-config.cjs')();
const mode=process.argv.includes('--import')?'import':'serialize';
const dir=process.argv.find(a=>a.startsWith('--output='))?.slice(9)||'.local/sap-serialized';
const objects=fs.readdirSync('src').filter(n=>/\.(clas|prog|tabl|wapa|sicf|devc)\.xml$/.test(n)).map(n=>({filename:n,type:n.split('.').at(-2).toUpperCase(),name:n.endsWith('.devc.xml')?'$BN_ROUNDTRIP':n.split('.')[0].toUpperCase()}));
const imported=objects;
const selected=process.argv.includes('--native-only')?objects.filter(o=>['CLAS','PROG','TABL'].includes(o.type)):imported;
const q=s=>"'"+s.replaceAll("'","''")+"'";
(async()=>{await client.login();client.stateful='stateful';try{
let setup='',actions='';
if(mode==='import'){
 fs.mkdirSync('.local/git-input/src',{recursive:true});
 for(const filename of ['.abapgit.xml',...fs.readdirSync('src').map(n=>'src/'+n)]){
  const hash=execFileSync('git',['hash-object','-w','--path='+filename,filename],{encoding:'utf8'}).trim();
  const bytes=execFileSync('git',['cat-file','blob',hash],{maxBuffer:4*1024*1024});
  new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
  fs.writeFileSync('.local/git-input/'+filename,bytes);
  expected.set(filename.replace(/^src\//,''),{hash,bytes});
 }

 const zip=spawnSync('python',['-c',"import zipfile,pathlib; z=zipfile.ZipFile('.local/roundtrip-input.zip','w',zipfile.ZIP_DEFLATED); z.write('.local/git-input/.abapgit.xml','.abapgit.xml'); [z.write(p,'src/'+p.name) for p in pathlib.Path('.local/git-input/src').iterdir() if p.is_file()]; z.close()"],{encoding:'utf8'});if(zip.status)throw Error(zip.stderr);
 const b64=fs.readFileSync('.local/roundtrip-input.zip').toString('base64');
 setup=`DATA lv_zip64 TYPE string.\n${b64.match(/.{1,180}/g).map(s=>`lv_zip64 = lv_zip64 && '${s}'.`).join('\n')}\nDATA(lt_files) = zcl_abapgit_zip=>load( cl_http_utility=>decode_x_base64( lv_zip64 ) ).\nDATA(lo_log) = NEW zcl_abapgit_log( ).\nzcl_abapgit_objects_activation=>clear( ).\n`;
 for(const o of selected)actions+=`\nls_item = VALUE #( obj_type = '${o.type}' obj_name = ${q(o.name)} devclass = '${o.type==='DEVC'?'$BN_ROUNDTRIP':'$TMP'}' origlang = 'E' ).
${o.type==='SICF'?`SELECT SINGLE icfparguid FROM icfservice INTO @ls_item-obj_name+15 WHERE icf_name = 'ZBPC_NOTEBOOK'.`:''}
lo_files = zcl_abapgit_objects_files=>new( is_item = ls_item iv_path = '/src/' ).
lo_files->set_files( lt_files ).
CREATE OBJECT lo_obj TYPE zcl_abapgit_object_${o.type.toLowerCase()} EXPORTING is_item = ls_item iv_language = 'E' io_files = lo_files.
READ TABLE lt_files INTO DATA(ls_input_${selected.indexOf(o)}) WITH KEY filename = ${q(o.filename)}.
lo_xml = NEW zcl_abapgit_xml_input( zcl_abapgit_convert=>xstring_to_string_utf8( ls_input_${selected.indexOf(o)}-data ) ).
LOOP AT lo_obj->get_deserialize_steps( ) INTO DATA(lv_step_${selected.indexOf(o)}).
 lo_obj->deserialize( iv_package = '${o.type==='DEVC'?'$BN_ROUNDTRIP':'$TMP'}' io_xml = lo_xml iv_step = lv_step_${selected.indexOf(o)} ii_log = lo_log iv_transport = '' ).
ENDLOOP.
out->write( 'BNIMPORTED|${o.type}|${o.name}' ).\n`;
 actions+=`READ TABLE lt_files INTO DATA(ls_dot) WITH KEY filename = '.abapgit.xml'.
DATA(lo_dot) = zcl_abapgit_dot_abapgit=>deserialize( ls_dot-data ).
out->write( 'BNFILE|.abapgit.xml|' && cl_http_utility=>encode_x_base64( lo_dot->serialize( ) ) ).
zcl_abapgit_objects_activation=>activate( iv_ddic = abap_true ii_log = lo_log ).
zcl_abapgit_objects_activation=>activate( ii_log = lo_log ).
DATA lt_pages TYPE o2pagelist.
DATA lo_page TYPE REF TO cl_o2_api_pages.
cl_o2_api_pages=>get_all_pages( EXPORTING p_applname = 'ZBPC_NOTEBOOK' p_version = 'I' IMPORTING p_pages = lt_pages ).
LOOP AT lt_pages INTO DATA(ls_page).
 cl_o2_api_pages=>load( EXPORTING p_pagekey = VALUE #( applname = ls_page-applname pagekey = ls_page-pagekey ) p_version = 'I' IMPORTING p_page = lo_page EXCEPTIONS object_not_existing = 1 version_not_existing = 2 OTHERS = 3 ).
 IF sy-subrc = 2. CONTINUE. ENDIF.
 IF sy-subrc <> 0. out->write( 'BNERROR|BSP inactive page load failed' ). CONTINUE. ENDIF.
 lo_page->activate_page( EXCEPTIONS error_occured = 1 ).
 IF sy-subrc <> 0. out->write( 'BNERROR|BSP activation failed: ' && ls_page-pagekey ). ENDIF.
ENDLOOP.
COMMIT WORK AND WAIT.
LOOP AT lo_log->zif_abapgit_log~get_messages( ) INTO DATA(ls_message).
 out->write( |BNLOG| && ls_message-type && '|' && ls_message-text ).
ENDLOOP.\n`;
}
for(const o of selected)actions+=`\nls_item = VALUE #( obj_type = '${o.type}' obj_name = ${q(o.name)} devclass = '${o.type==='DEVC'?'$BN_ROUNDTRIP':'$TMP'}' origlang = 'E' ).
${o.type==='SICF'?`SELECT SINGLE icfparguid FROM icfservice INTO @ls_item-obj_name+15 WHERE icf_name = 'ZBPC_NOTEBOOK'.`:''}
ls_serial = zcl_abapgit_objects=>serialize( is_item = ls_item io_i18n_params = zcl_abapgit_i18n_params=>new( iv_main_language = 'E' iv_main_language_only = abap_true ) ).
LOOP AT ls_serial-files INTO ls_file.
 out->write( 'BNFILE|' && ls_file-filename && '|' && cl_http_utility=>encode_x_base64( ls_file-data ) ).
ENDLOOP.\n`;
const source=`CLASS zcl_bn_serialize_check DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION. INTERFACES if_oo_adt_classrun.
ENDCLASS.
CLASS zcl_bn_serialize_check IMPLEMENTATION.
 METHOD if_oo_adt_classrun~main.
 DATA ls_item TYPE zif_abapgit_definitions=>ty_item.
 DATA ls_serial TYPE zif_abapgit_objects=>ty_serialization.
 DATA ls_file TYPE zif_abapgit_git_definitions=>ty_file.
 DATA lo_files TYPE REF TO zcl_abapgit_objects_files.
 DATA lo_obj TYPE REF TO zif_abapgit_object.
 DATA lo_xml TYPE REF TO zif_abapgit_xml_input.
 TRY.
 ${setup}\n${actions}
 CATCH cx_root INTO DATA(lx).
 out->write( 'BNERROR|' && lx->get_text( ) ).
 ENDTRY.
 ENDMETHOD.
ENDCLASS.`;
const name='ZCL_BN_SERIALIZE_CHECK',url='/sap/bc/adt/oo/classes/zcl_bn_serialize_check';
const found=await client.searchObject(name,'',10);
if(!found.some(o=>o['adtcore:name']===name))await client.createObject('CLAS/OC',name,'$TMP','BPC Notebook serialization verification','/sap/bc/adt/packages/%24tmp');
const {LOCK_HANDLE}=await client.lock(url);try{await client.setObjectSource(url+'/source/main',source,LOCK_HANDLE);}finally{await client.unLock(url,LOCK_HANDLE);}
const activation=await client.activate(name,url);if(!activation.success)throw Error(JSON.stringify(activation));
const output=await client.runClass(name);fs.mkdirSync(dir,{recursive:true});let count=0;
for(const line of output.split(/\r?\n/)){if(line.startsWith('BNFILE|')){const [,filename,data]=line.split('|');const bytes=Buffer.from(data,'base64');fs.writeFileSync(dir+'/'+filename,bytes);count++;
 const input=expected.get(filename);
 evidence.files.push({filename,gitBlob:input?.hash,sapSha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,equal:input?input.bytes.equals(bytes):null});}else if(line.trim()){console.log(line);evidence.messages.push(line);}}
console.log('Serialized files:',count,'to',dir);
if(mode==='import'){
  const returned=new Set(evidence.files.map(f=>f.filename));
  evidence.missing=[...expected.keys()].filter(n=>!returned.has(n));
  evidence.passed=evidence.files.every(f=>f.equal)&&evidence.missing.length===0&&!output.includes('BNERROR|')&&!output.includes('BNLOGE|');
  fs.mkdirSync('docs/evidence',{recursive:true});fs.writeFileSync('docs/evidence/sap-roundtrip.json',JSON.stringify(evidence,null,2)+'\n','utf8');
  console.log('Git blob comparison:',evidence.passed?'PASS':'FAIL');
  if(!evidence.passed)process.exitCode=1;
 }else if(output.includes('BNERROR|')||count===0)process.exitCode=1;
}finally{await client.logout();}})().catch(e=>{console.error(e.message);process.exitCode=1;});
