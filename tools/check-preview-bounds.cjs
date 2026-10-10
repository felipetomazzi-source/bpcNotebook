// Preview clipping must never change complete native artifacts or financial values.
const fs=require('node:fs'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),api=require('./bpc-api.cjs');
const capture=`TYPES: BEGIN OF ty_row, member_id TYPE uj_dim_member, signeddata TYPE uj_signeddata,
 rows_packet TYPE string, END OF ty_row.
DATA rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
APPEND VALUE #( member_id = 'MEMBER_É' signeddata = '-123.1234567'
 rows_packet = repeat( val = 'É · São "packet" ' occ = 1200 ) ) TO rows.
DATA(original) = zcl_bn_dataset=>freeze( name = 'FULL' rows = rows ).
io->publish_dataset( name = 'FULL' rows = rows ).
DATA(packets) = io->dataset_packets( ).
IF packets[ name = 'FULL' ]-checksum <> original-checksum OR packets[ name = 'FULL' ]-content <> original-content.
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PREVIEW_TEST' detail = 'Preview changed native dataset bytes'. ENDIF.
DATA(empty) = rows. CLEAR empty. io->emit_table( name = 'EMPTY' rows = empty ).
DATA(exact) = rows. exact[ 1 ]-rows_packet = repeat( val = 'x' occ = 4096 ).
io->emit_table( name = 'EXACT_BOUNDARY' rows = exact ).
DATA legacy TYPE zcl_bn_context=>tt_tables.
APPEND VALUE #( name = 'LEGACY' row_count = 1 total_count = 1
 schema = VALUE #( ( name = 'ROWS_PACKET' type = 'string' ) )
 rows = VALUE #( ( values = VALUE #( ( repeat( val = 'É' occ = 12000 ) ) ) ) ) ) TO legacy.
DATA bounded TYPE zcl_bn_context=>tt_tables. bounded = zcl_bn_context=>bounded_previews( legacy ).
IF strlen( legacy[ 1 ]-rows[ 1 ]-values[ 1 ] ) <> 12000 OR
 strlen( bounded[ 1 ]-rows[ 1 ]-values[ 1 ] ) <> 4096 OR bounded[ 1 ]-values_truncated <> abap_true.
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PREVIEW_TEST' detail = 'Legacy preview mutated or was not bounded'. ENDIF.
" Retain a synthetic legacy display document for the GET compatibility test.
TYPES: BEGIN OF ty_legacy_output, tables TYPE zcl_bn_context=>tt_tables, END OF ty_legacy_output.
DATA(legacy_output) = VALUE ty_legacy_output( tables = legacy ).
DATA(legacy_revision) = zcl_bn_store=>write( kind = 'D' id = |{ io->snapshot_identifier( ) }:legacy|
 payload = zcl_bn_types=>json( legacy_output ) expected = 0 ).
DATA huge TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
DO 3000 TIMES.
 APPEND VALUE #( member_id = 'MEMBER_É' signeddata = '-123.1234567'
 rows_packet = repeat( val = 'é' occ = 4100 ) ) TO huge.
ENDDO.
io->publish_dataset( name = 'BIG' rows = huge ).
io->emit_table( name = 'BYTE_BUDGET' rows = huge ).
DATA(bytes) = io->tables[ name = 'BYTE_BUDGET' ].
IF bytes-byte_limit_reached <> abap_true OR bytes-row_count >= 3000 OR bytes-total_count <> 3000 OR bytes-truncated <> abap_true.
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PREVIEW_TEST' detail = 'Byte-bound preview lost full counts or clipping marker'. ENDIF.
DATA total_bytes TYPE i.
LOOP AT io->tables INTO DATA(table). total_bytes = total_bytes + table-preview_bytes. ENDLOOP.
IF total_bytes > 8388608. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PREVIEW_TEST' detail = 'Aggregate byte budget exceeded'. ENDIF.
io->message( |PREVIEW_NATIVE_BYTES_UNCHANGED:TOTAL_PREVIEW_BYTES:{ total_bytes }:FULL_ROWS:3000| ).`;
const verify=`DATA(ref) = io->read_dataset( dependency = 'capture' name = 'FULL' ).
FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN ref->* TO <rows>.
READ TABLE <rows> ASSIGNING FIELD-SYMBOL(<row>) INDEX 1.
ASSIGN COMPONENT 'ROWS_PACKET' OF STRUCTURE <row> TO FIELD-SYMBOL(<packet>).
IF <packet> <> repeat( val = 'É · São "packet" ' occ = 1200 ).
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PREVIEW_TEST' detail = 'Consumer received clipped calculation input'. ENDIF.
ASSIGN COMPONENT 'SIGNEDDATA' OF STRUCTURE <row> TO FIELD-SYMBOL(<amount>).
IF <amount> <> CONV uj_signeddata( '-123.1234567' ).
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PREVIEW_TEST' detail = 'Financial value changed'. ENDIF.
DATA(big) = io->read_dataset( dependency = 'capture' name = 'BIG' ).
FIELD-SYMBOLS <big> TYPE STANDARD TABLE. ASSIGN big->* TO <big>.
IF lines( <big> ) <> 3000. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PREVIEW_TEST' detail = 'Full dataset row count changed'. ENDIF.
LOOP AT <big> ASSIGNING <row>.
 ASSIGN COMPONENT 'ROWS_PACKET' OF STRUCTURE <row> TO <packet>.
 IF strlen( <packet> ) <> 4100. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'PREVIEW_TEST' detail = 'Full string was clipped'. ENDIF.
ENDLOOP.
io->message( 'FULL_NATIVE_CONSUMER_OK' ).`;
(async()=>{
 const n=await api('/notebooks',{title:'Platform bounded preview contract',inputs:[],cells:[
  {id:'capture',title:'Full artifacts and bounded previews',source:capture,dependencies:[]},
  {id:'verify',title:'Private full native consumer',source:verify,dependencies:['capture']} ]});
 let r;
 try{
  for(const c of n.cells){const v=await api('/validate',{notebookId:n.id,cellId:c.id});assert.equal(v.supported,true,JSON.stringify(v));}
  r=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:randomUUID()});
  for(let i=0;i<240&&['running','queued'].includes(r.state);i++){await new Promise(resolve=>setTimeout(resolve,500));r=await api('/run?id='+r.id,null,'GET');}
  assert.equal(r.state,'succeeded',JSON.stringify(r.error));
  const page=table=>api('/output?runId='+r.id+'&cellId=capture&revision=1&limit=100&table='+encodeURIComponent(table),null,'GET');
  const full=await page('DATASET/FULL'),empty=await page('EMPTY'),exact=await page('EXACT_BOUNDARY'),byte=await page('BYTE_BUDGET');
  const legacy=await api('/output?runId='+r.id+'&cellId=legacy&revision=1&limit=100&table=LEGACY',null,'GET');
  assert.equal(legacy.valuesTruncated,true);assert.equal(legacy.rows[0].values[0].length,4096);
  assert.equal(full.valuesTruncated,true);assert.equal(full.truncatedValues,1);
  assert.equal(full.valueCharacterLimit,4096);assert.equal(full.sourceTotal,1);
  assert.equal(full.rows[0].values[0],'MEMBER_É');assert.equal(full.rows[0].values[1],'-123.1234567');
  assert.equal(full.rows[0].values[2].length,4096);assert(full.rows[0].values[2].endsWith('…'));
  assert.equal(empty.total,0);assert.equal(empty.schema.length,3);assert.equal(empty.valuesTruncated,false);
  assert.equal(exact.valuesTruncated,false);assert.equal(exact.rows[0].values[2].length,4096);
  assert.equal(byte.byteLimitReached,true);assert.equal(byte.truncated,true);assert.equal(byte.sourceTotal,3000);assert(byte.total<3000);
  assert(full.tables.find(t=>t.name==='DATASET/FULL').valuesTruncated);
  const evidence={at:new Date().toISOString(),financialPosting:false,passed:true,runId:r.id,messages:r.messages,
   nativeFullRows:3000,previewRows:byte.total,previewByteLimit:byte.previewByteLimit,previewBytes:byte.previewBytes,
   truncatedValues:full.truncatedValues,fullArtifactUnchanged:true,emptySchemaPreserved:true,legacyGetClipped:true};
  fs.writeFileSync('docs/evidence/native-preview-bounds.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));
 }finally{
  if(r&&['running','queued'].includes(r.state))await api('/cancel',{id:r.id});
  else await api('/delete-notebook',{notebookId:n.id,expectedRevision:n.revision});
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
