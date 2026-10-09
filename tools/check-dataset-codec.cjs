const fs=require('node:fs'),{execFileSync}=require('node:child_process'),{createHash}=require('node:crypto');
process.argv.push('--codex-env');
const c=require('./adt-config.cjs')(),target='ZCL_BN_DATASET_TEST',helper='ZCL_BN_DATASET_CHECK',folder='.local/dataset-roundtrip';
fs.mkdirSync(folder+'/src',{recursive:true});const expected=new Map();
for(const filename of fs.readdirSync('src').filter(n=>n.startsWith('zcl_bn_dataset.clas.'))){
 const path='src/'+filename,blob=execFileSync('git',['hash-object','-w','--path='+path,path],{encoding:'utf8'}).trim();
 const bytes=execFileSync('git',['cat-file','blob',blob]);let text=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
 // Isolated codec tests exclude the two tests requiring the still-undeployed context APIs.
 if(filename.endsWith('testclasses.abap'))for(const name of ['context_handoff','data_read_policy']){
  text=text.replace(new RegExp('    METHODS '+name+' FOR TESTING RAISING zcx_bn.\\n'),'');
  text=text.replace(new RegExp('  METHOD '+name+'\\.[\\s\\S]*?  ENDMETHOD.\\n'),'');
 }
 text=text.replaceAll('zcl_bn_dataset','zcl_bn_dataset_test').replaceAll('ZCL_BN_DATASET','ZCL_BN_DATASET_TEST');
 const testfile=filename.replace('zcl_bn_dataset','zcl_bn_dataset_test');fs.writeFileSync(folder+'/src/'+testfile,text,'utf8');expected.set(testfile,Buffer.from(text));
}
execFileSync('python',['-c',`import zipfile,pathlib; z=zipfile.ZipFile('${folder}/input.zip','w',zipfile.ZIP_DEFLATED); z.write('.abapgit.xml','.abapgit.xml'); [z.write(p,'src/'+p.name) for p in pathlib.Path('${folder}/src').iterdir()]; z.close()`]);
const encoded=fs.readFileSync(folder+'/input.zip').toString('base64');
const source=`CLASS ${helper.toLowerCase()} DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION. INTERFACES if_oo_adt_classrun.
ENDCLASS.
CLASS ${helper.toLowerCase()} IMPLEMENTATION.
 METHOD if_oo_adt_classrun~main.
 TRY.
 DATA encoded TYPE string.
 ${encoded.match(/.{1,180}/g).map(s=>`encoded = encoded && '${s}'.`).join('\n')}
 DATA(files) = zcl_abapgit_zip=>load( cl_http_utility=>decode_x_base64( encoded ) ).
 DATA(item) = VALUE zif_abapgit_definitions=>ty_item( obj_type = 'CLAS' obj_name = '${target}' devclass = '$TMP' origlang = 'E' ).
 DATA(object_files) = zcl_abapgit_objects_files=>new( is_item = item iv_path = '/src/' ).
 object_files->set_files( files ).
 DATA object TYPE REF TO zif_abapgit_object.
 CREATE OBJECT object TYPE zcl_abapgit_object_clas EXPORTING is_item = item iv_language = 'E' io_files = object_files.
 READ TABLE files INTO DATA(metadata) WITH KEY filename = 'zcl_bn_dataset_test.clas.xml'.
 DATA(xml) = NEW zcl_abapgit_xml_input( zcl_abapgit_convert=>xstring_to_string_utf8( metadata-data ) ).
 DATA(log) = NEW zcl_abapgit_log( ).
 zcl_abapgit_objects_activation=>clear( ).
 LOOP AT object->get_deserialize_steps( ) INTO DATA(step).
 object->deserialize( iv_package = '$TMP' io_xml = xml iv_step = step ii_log = log iv_transport = '' ).
 ENDLOOP.
 zcl_abapgit_objects_activation=>activate( ii_log = log ).
 COMMIT WORK AND WAIT.
 LOOP AT log->zif_abapgit_log~get_messages( ) INTO DATA(message).
 IF message-type = 'E'. out->write( 'ERROR|' && message-text ). ENDIF.
 ENDLOOP.
 DATA(serialized) = zcl_abapgit_objects=>serialize( is_item = item io_i18n_params = zcl_abapgit_i18n_params=>new( iv_main_language = 'E' iv_main_language_only = abap_true ) ).
 LOOP AT serialized-files INTO DATA(file).
 out->write( 'FILE|' && file-filename && '|' && cl_http_utility=>encode_x_base64( file-data ) ).
 ENDLOOP.
 CATCH cx_root INTO DATA(error). out->write( 'ERROR|' && error->get_text( ) ). ENDTRY.
 ENDMETHOD.
ENDCLASS.`;
(async()=>{await c.login();c.stateful='stateful';try{
 const found=await c.searchObject(helper,'',10);if(!found.some(o=>o['adtcore:name']===helper))await c.createObject('CLAS/OC',helper,'$TMP','Isolated native dataset verification','/sap/bc/adt/packages/%24tmp');
 const url='/sap/bc/adt/oo/classes/'+helper.toLowerCase(),{LOCK_HANDLE}=await c.lock(url);
 try{await c.setObjectSource(url+'/source/main',source,LOCK_HANDLE);}finally{await c.unLock(url,LOCK_HANDLE);}
 const activation=await c.activate(helper,url);if(!activation.success)throw Error(JSON.stringify(activation));
 const output=await c.runClass(helper);if(output.includes('ERROR|'))throw Error(output.split(/\r?\n/).filter(s=>s.includes('ERROR|')).join('\n'));
 const evidence={at:new Date().toISOString(),method:'Isolated $TMP CLAS import/serialize using native abapGit; class renamed; two context integration tests excluded until coordinated deployment',files:[],tests:null,passed:false};
 for(const line of output.split(/\r?\n/)){if(!line.startsWith('FILE|'))continue;const [,filename,data]=line.split('|'),bytes=Buffer.from(data,'base64');fs.writeFileSync(folder+'/'+filename,bytes);evidence.files.push({filename,equal:bytes.equals(expected.get(filename)),sapSha256:createHash('sha256').update(bytes).digest('hex')});expected.delete(filename);}
 evidence.tests=await c.unitTestRun('/sap/bc/adt/oo/classes/'+target.toLowerCase());
 evidence.passed=!expected.size&&evidence.files.every(f=>f.equal)&&evidence.tests.length>0&&evidence.tests.every(t=>!t.alerts.length&&t.testmethods.every(m=>!m.alerts.length));
 fs.writeFileSync('docs/evidence/dataset-codec-roundtrip.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));if(!evidence.passed)process.exitCode=1;
}finally{await c.logout();}})().catch(e=>{console.error(e.message);process.exitCode=1;});
