// Isolated SAP BSP round trip. Does not replace the deployed Notebook application.
process.argv.push('--codex-env');
const fs=require('node:fs'),{execFileSync}=require('node:child_process'),{createHash}=require('node:crypto'),vm=require('node:vm');
const c=require('./adt-config.cjs')();
const target='ZBN_PRETTY_TEST',helper='ZCL_BN_PRETTY_CHECK',original='ZBPC_NOTEBOOK';
const folder='.local/pretty-roundtrip';
fs.mkdirSync(folder+'/src',{recursive:true});
const expected=new Map();
for(const filename of fs.readdirSync('src').filter(n=>n.startsWith('zbpc_notebook.wapa.'))){
  const path='src/'+filename;
  const blob=execFileSync('git',['hash-object','-w','--path='+path,path],{encoding:'utf8'}).trim();
  const bytes=execFileSync('git',['cat-file','blob',blob]);
  const text=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);
  const isolated=filename.endsWith('.xml')?text.replaceAll(original,target):text;
  fs.writeFileSync(folder+'/src/'+filename.replace('zbpc_notebook','zbn_pretty_test'),isolated,'utf8');
  expected.set(filename,{bytes,blob});
}
execFileSync('python',['-c',"import zipfile,pathlib; z=zipfile.ZipFile('.local/pretty-roundtrip/input.zip','w',zipfile.ZIP_DEFLATED); z.write('.abapgit.xml','.abapgit.xml'); [z.write(p,'src/'+p.name) for p in pathlib.Path('.local/pretty-roundtrip/src').iterdir()]; z.close()"]);
const zip=fs.readFileSync(folder+'/input.zip').toString('base64');
const source=`CLASS ${helper.toLowerCase()} DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION. INTERFACES if_oo_adt_classrun.
ENDCLASS.
CLASS ${helper.toLowerCase()} IMPLEMENTATION.
 METHOD if_oo_adt_classrun~main.
  TRY.
   DATA encoded TYPE string.
   ${zip.match(/.{1,180}/g).map(s=>`encoded = encoded && '${s}'.`).join('\n')}
   DATA(files) = zcl_abapgit_zip=>load( cl_http_utility=>decode_x_base64( encoded ) ).
   DATA(item) = VALUE zif_abapgit_definitions=>ty_item( obj_type = 'WAPA' obj_name = '${target}' devclass = '$TMP' origlang = 'E' ).
   DATA(object_files) = zcl_abapgit_objects_files=>new( is_item = item iv_path = '/src/' ).
   object_files->set_files( files ).
   DATA object TYPE REF TO zif_abapgit_object.
   CREATE OBJECT object TYPE zcl_abapgit_object_wapa EXPORTING is_item = item iv_language = 'E' io_files = object_files.
   READ TABLE files INTO DATA(metadata) WITH KEY filename = 'zbn_pretty_test.wapa.xml'.
   DATA(xml) = NEW zcl_abapgit_xml_input( zcl_abapgit_convert=>xstring_to_string_utf8( metadata-data ) ).
   DATA(log) = NEW zcl_abapgit_log( ).
   zcl_abapgit_objects_activation=>clear( ).
   LOOP AT object->get_deserialize_steps( ) INTO DATA(step).
    object->deserialize( iv_package = '$TMP' io_xml = xml iv_step = step ii_log = log iv_transport = '' ).
   ENDLOOP.
   zcl_abapgit_objects_activation=>activate( ii_log = log ).
   DATA pages TYPE o2pagelist.
   DATA page TYPE REF TO cl_o2_api_pages.
   cl_o2_api_pages=>get_all_pages( EXPORTING p_applname = '${target}' p_version = 'I' IMPORTING p_pages = pages ).
   LOOP AT pages INTO DATA(entry).
    cl_o2_api_pages=>load( EXPORTING p_pagekey = VALUE #( applname = entry-applname pagekey = entry-pagekey ) p_version = 'I'
      IMPORTING p_page = page EXCEPTIONS object_not_existing = 1 version_not_existing = 2 OTHERS = 3 ).
    IF sy-subrc = 2. CONTINUE. ENDIF.
    IF sy-subrc <> 0. out->write( 'ERROR|Test page load failed' ). RETURN. ENDIF.
    page->activate_page( EXCEPTIONS error_occured = 1 ).
    IF sy-subrc <> 0. out->write( 'ERROR|Test page activation failed' ). RETURN. ENDIF.
   ENDLOOP.
   COMMIT WORK AND WAIT.
   LOOP AT log->zif_abapgit_log~get_messages( ) INTO DATA(message).
    IF message-type = 'E'. out->write( 'ERROR|' && message-text ). ENDIF.
   ENDLOOP.
   DATA(serialized) = zcl_abapgit_objects=>serialize( is_item = item
     io_i18n_params = zcl_abapgit_i18n_params=>new( iv_main_language = 'E' iv_main_language_only = abap_true ) ).
   LOOP AT serialized-files INTO DATA(file).
    out->write( 'FILE|' && file-filename && '|' && cl_http_utility=>encode_x_base64( file-data ) ).
   ENDLOOP.
  CATCH cx_root INTO DATA(error). out->write( 'ERROR|' && error->get_text( ) ). ENDTRY.
 ENDMETHOD.
ENDCLASS.`;
(async()=>{await c.login();c.stateful='stateful';try{
  // Test the browser adapter's actual prepared source against the native formatter.
  let Api;
  vm.runInNewContext(fs.readFileSync('webapp/model/Api.js','utf8'),{URL,URLSearchParams,
    window:{location:{search:'?sap-client=001',href:'http://sap.invalid/'}},
    sap:{ui:{require:{toUrl:()=>'/sap/bc/ui5_ui5/sap/zbpc_notebook/Component.js'},define:(_,factory)=>{Api=factory();}}},
    fetch:async(_,options)=>options.method==='POST'
      ?new Response(await c.prettyPrinter(options.body)):new Response('',{headers:{'X-CSRF-Token':'sdk-session'}})});
  const input="DATA total TYPE decfloat34. IF total = 0. total = 1. io->message( 'É · literal. text' ). ENDIF.\n\n";
  const formatted=await Api.prettyPrint(input);
  if(!formatted.includes("\n  total = 1.\n")||!formatted.includes("'É · literal. text'")||!formatted.endsWith('\n\n'))throw Error('Native formatting check failed');
  const found=await c.searchObject(helper,'',10);
  if(!found.some(o=>o['adtcore:name']===helper))await c.createObject('CLAS/OC',helper,'$TMP','Isolated Notebook pretty printer round trip','/sap/bc/adt/packages/%24tmp');
  const url='/sap/bc/adt/oo/classes/'+helper.toLowerCase();
  const {LOCK_HANDLE}=await c.lock(url);try{await c.setObjectSource(url+'/source/main',source,LOCK_HANDLE);}finally{await c.unLock(url,LOCK_HANDLE);}
  const activation=await c.activate(helper,url);if(!activation.success)throw Error(JSON.stringify(activation));
  const output=await c.runClass(helper);if(output.includes('ERROR|'))throw Error(output.split(/\r?\n/).filter(x=>x.includes('ERROR|')).join('\n'));
  const evidence={at:new Date().toISOString(),method:'Isolated $TMP BSP imported and reserialized with native abapGit WAPA deserializer/serializer; only the test application name is remapped for comparison',application:target,liveApplicationModified:false,nativeFormatter:{input,formatted},files:[],passed:false};
  for(const line of output.split(/\r?\n/)){if(!line.startsWith('FILE|'))continue;
    const [,isolated,data]=line.split('|'),filename=isolated.replace('zbn_pretty_test','zbpc_notebook');
    let bytes=Buffer.from(data,'base64');
    if(filename.endsWith('.xml'))bytes=Buffer.from(new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes).replaceAll(target,original),'utf8');
    const input=expected.get(filename);if(!input)throw Error('Unexpected serialized file '+filename);
    evidence.files.push({filename,gitBlob:input.blob,sapSha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,equal:bytes.equals(input.bytes)});
    expected.delete(filename);
  }
  evidence.missing=[...expected.keys()];evidence.passed=evidence.files.every(x=>x.equal)&&!evidence.missing.length&&evidence.files.length===9;
  fs.writeFileSync('docs/evidence/pretty-printer-roundtrip.json',JSON.stringify(evidence,null,2)+'\n','utf8');
  if(!evidence.passed)throw Error(JSON.stringify(evidence));
  console.log(JSON.stringify({passed:true,files:evidence.files.length,nativeFormatting:true,liveApplicationModified:false}));
}finally{await c.logout();}})().catch(error=>{console.error(error.message);process.exitCode=1;});
