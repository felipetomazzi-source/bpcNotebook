const fs=require('node:fs'),assert=require('node:assert/strict'),runProbe=require('./run-readonly-probe.cjs');
(async()=>{
 const source=String.raw`TYPES: BEGIN OF ty_text, word TYPE string, message TYPE string, END OF ty_text.
DATA(input) = VALUE ty_text( word = cl_abap_char_utilities=>cr_lf message = |É · "quoted" \\ slash| ).
DO 32 TIMES.
 DATA hex TYPE x LENGTH 2. hex = sy-index - 1.
 input-message = input-message && cl_abap_conv_in_ce=>uccp( hex ).
ENDDO.
DATA(json) = zcl_bn_types=>json( input ).
io->message( 'JSON|' && cl_http_utility=>encode_x_base64( zcl_abapgit_convert=>string_to_xstring_utf8( json ) ) ).`;
 const run=await runProbe('Platform JSON wire diagnostic',source),message=run.messages.find(m=>m.text.startsWith('JSON|'));
 assert(message,'Native JSON result missing');
 const json=Buffer.from(message.text.slice(5),'base64').toString('utf8'),parsed=JSON.parse(json);
 assert.equal(parsed.word,'\r\n');assert.equal(parsed.message,'É · "quoted" \\ slash'+String.fromCharCode(...Array.from({length:32},(_,i)=>i)));
 assert.equal([...json].some(c=>c.charCodeAt(0)<32),false);
 const evidence={at:new Date().toISOString(),method:'Preview-only native Notebook diagnostic cell; actual serialized wire parsed with Node JSON.parse',runId:run.id,globalSourceUploads:false,controls:32,passed:true};
 fs.writeFileSync('docs/evidence/native-json-controls.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
