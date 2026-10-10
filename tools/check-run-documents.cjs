const fs=require('node:fs'),runProbe=require('./run-readonly-probe.cjs');
const id=process.argv.find(a=>a.startsWith('--run-id='))?.slice(9);if(!/^[A-F0-9]{32}$/.test(id||''))throw Error('Supply --run-id=<32 hexadecimal ID>');
(async()=>{
 const source=`SELECT SINGLE revision FROM zbn_head INTO @DATA(head) WHERE kind = 'R' AND id = '${id}' AND owner = @sy-uname.
IF sy-subrc <> 0. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PROBE' detail = 'Owned run missing'. ENDIF.
io->message( |HEAD:{ head }| ).
SELECT revision, checksum, payload FROM zbn_doc INTO TABLE @DATA(documents) WHERE kind = 'R' AND id = '${id}' ORDER BY revision.
LOOP AT documents INTO DATA(doc).
 DATA(actual) = zcl_bn_types=>hash( doc-payload ).
 io->message( |REV:{ doc-revision }:VALID:{ xsdbool( actual = doc-checksum ) }:LEN:{ strlen( doc-payload ) }| ).
ENDLOOP.`;
 const run=await runProbe('Platform run document integrity diagnostic',source),revisions=run.messages.map(m=>m.text).filter(t=>t.startsWith('REV:'));
 if(!revisions.length||revisions.some(t=>!t.includes(':VALID:X:')))throw Error('A persisted revision checksum failed');
 const evidence={at:new Date().toISOString(),runId:id,probeRunId:run.id,method:'Read-only owned revisions SELECT and SHA-256 in a preview-only Notebook cell; target records unchanged',globalSourceUploads:false,revisions,passed:true};
 fs.writeFileSync('docs/evidence/run-document-integrity.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify({passed:true,revisions:revisions.length,runId:id}));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
