// Native authorized metadata retention tests; model facts remain untouched.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),api=require('./bpc-api.cjs');
let Script;vm.runInNewContext(fs.readFileSync('webapp/model/Script.js','utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
const capture=`DATA facts TYPE zcl_bn_dem_model=>tabl.
DATA bundles TYPE zcl_bn_bpc=>tt_dimension_fixtures.
DATA(products) = io->bpc_dimension( 'PRODUCT_TYPE' ).
APPEND products->capture_dimension( snapshot_id = io->snapshot_identifier( ) ) TO bundles.
DATA(audit) = io->bpc_dimension( 'AUDITTRAIL' ).
APPEND audit->capture_dimension( snapshot_id = io->snapshot_identifier( )
 hierarchy_reads = VALUE #( ( hierarchy = 'PARENTH1' member = 'DEMREVID_OUTPUT' ) ) ) TO bundles.
DATA(member_ref) = bundles[ 1 ]-rows.
FIELD-SYMBOLS <members> TYPE STANDARD TABLE. ASSIGN member_ref->* TO <members>.
READ TABLE <members> ASSIGNING FIELD-SYMBOL(<member>) INDEX 1.
IF sy-subrc <> 0. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'METADATA_TEST' detail = 'Authorized nonempty member fixture required'. ENDIF.
ASSIGN COMPONENT 'EVDESCRIPTION' OF STRUCTURE <member> TO FIELD-SYMBOL(<description>).
<description> = 'Frozen É · São'.
DATA(packets) = zcl_bn_bpc=>pack_dimensions( bundles ).
io->enable_fixtures( fixtures = VALUE #( ( environment = io->environment model = io->model rows = REF #( facts ) ) )
 dimensions = bundles freeze_metadata = abap_true ).
<description> = 'Changed by author after freeze'.
io->publish_dataset( name = 'FACTS' rows = facts ).
io->publish_dataset( name = 'METADATA' rows = packets ).`;
const script=`script version 2 compact
dataset facts = "capture" named "FACTS"
dataset metadata = "capture" named "METADATA"
fixture facts model "DEMREVID" metadata metadata
members products = DEMREVID-PRODUCT_TYPE
assert count(products) > 0 message "Nonempty retained member table"
let first = integer(0)
for row in products
  first = first + 1
  if first == 1
    assert row.EVDESCRIPTION == "Frozen É · São" message "Retained native Unicode description"
  end
end
publish products as "PRODUCTS"`;
const verify=`DATA(facts) = io->read_dataset( dependency = 'capture' name = 'FACTS' ).
DATA(metadata) = io->read_dataset( dependency = 'capture' name = 'METADATA' ).
FIELD-SYMBOLS <metadata> TYPE STANDARD TABLE. ASSIGN metadata->* TO <metadata>.
io->enable_fixtures( fixtures = VALUE #( ( environment = io->environment model = io->model rows = facts ) )
 metadata = <metadata> freeze_metadata = abap_true ).
DATA(original_context) = io->fixture_copy( 'original' ).
DATA(products) = original_context->bpc_dimension( 'PRODUCT_TYPE' ).
DATA(ref) = products->member_data( ). FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN ref->* TO <rows>.
READ TABLE <rows> ASSIGNING FIELD-SYMBOL(<row>) INDEX 1.
ASSIGN COMPONENT 'ID' OF STRUCTURE <row> TO FIELD-SYMBOL(<id>).
DATA(id) = CONV string( <id> ).
ASSIGN COMPONENT 'EVDESCRIPTION' OF STRUCTURE <row> TO FIELD-SYMBOL(<description>).
IF <description> <> 'Frozen É · São'. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'METADATA_TEST' detail = 'Frozen description lost'. ENDIF.
<description> = 'Consumer-private change'.
IF products->property( member = id name = 'EVDESCRIPTION' ) <> 'Frozen É · São'.
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'METADATA_TEST' detail = 'Consumer mutated retained metadata'. ENDIF.
DATA(audit) = original_context->bpc_dimension( 'AUDITTRAIL' ).
DATA(children) = audit->children( member = 'DEMREVID_OUTPUT' hierarchy = 'PARENTH1' ).
IF children IS INITIAL. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'METADATA_TEST' detail = 'Captured hierarchy empty'. ENDIF.
TRY. audit->children( member = 'DEMREVID_INPUT' hierarchy = 'PARENTH1' ).
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'METADATA_TEST' detail = 'Uncaptured hierarchy fell back to live'.
CATCH zcx_bn INTO DATA(error). IF error->code <> 'FIXTURE_MISSING'. RAISE EXCEPTION error. ENDIF. ENDTRY.
TRY. original_context->bpc_dimension( 'MATCONN' ).
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'METADATA_TEST' detail = 'Uncaptured dimension fell back to live'.
CATCH zcx_bn INTO error. IF error->code <> 'FIXTURE_MISSING'. RAISE EXCEPTION error. ENDIF. ENDTRY.
TRY. products->member_data( VALUE #( ( CONV string( 'UNRETAINED_PLATFORM_MEMBER' ) ) ) ).
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'METADATA_TEST' detail = 'Uncaptured member fell back to live'.
CATCH zcx_bn INTO error. IF error->code <> 'FIXTURE_MISSING'. RAISE EXCEPTION error. ENDIF. ENDTRY.
TRY. products->capture_dimension( snapshot_id = io->snapshot_identifier( ) ).
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'METADATA_TEST' detail = 'Fixture adapter performed fresh capture'.
CATCH zcx_bn INTO error. IF error->code <> 'FIXTURE_METADATA'. RAISE EXCEPTION error. ENDIF. ENDTRY.
DATA(packets) = CORRESPONDING zcl_bn_bpc=>tt_dimension_packets( <metadata> ).
LOOP AT packets ASSIGNING FIELD-SYMBOL(<packet>). <packet>-snapshot_id = 'WRONG_CAPTURE'. ENDLOOP.
DATA(test_context) = NEW zcl_bn_context( inputs = VALUE #( ) bindings = VALUE #( ) dependencies = VALUE #( )
 cell_id = 'mismatch' environment = CONV string( io->environment ) model = CONV string( io->model ) run_id = io->snapshot_identifier( ) ).
TRY. test_context->enable_fixtures( fixtures = VALUE #( ( environment = io->environment model = io->model rows = facts ) )
 metadata = packets freeze_metadata = abap_true ).
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'METADATA_TEST' detail = 'Mixed capture accepted'.
CATCH zcx_bn INTO error. IF error->code <> 'DATA_SNAPSHOT'. RAISE EXCEPTION error. ENDIF. ENDTRY.
io->message( 'METADATA_FIXTURE_OK: native manifest, private copies, original context, captured hierarchy, no enrichment, snapshot guard' ).`;
(async()=>{
 const n=await api('/notebooks',{title:'Platform native metadata fixture contract',environment:'CH_PLANNING',model:'DEMREVID',inputs:[],cells:[
  {id:'capture',title:'Capture authorized metadata',source:capture,dependencies:[]},
  {id:'script',title:'Script retained metadata',source:Script.compile(script),dependencies:['capture']},
  {id:'verify',title:'Native retained metadata',source:verify,dependencies:['capture','script']} ]});
 let run;
 try{
  for(const c of n.cells){const validation=await api('/validate',{notebookId:n.id,cellId:c.id});assert.equal(validation.supported,true,JSON.stringify(validation));}
  run=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:randomUUID()});
  for(let i=0;i<240&&['queued','running'].includes(run.state);i++){await new Promise(r=>setTimeout(r,500));run=await api('/run?id='+run.id,null,'GET');}
  const evidence={at:new Date().toISOString(),financialPosting:false,passed:run.state==='succeeded',runId:run.id,state:run.state,error:run.error,messages:run.messages,results:run.results};
  fs.writeFileSync('docs/evidence/native-metadata-fixtures.json',JSON.stringify(evidence,null,2)+'\n','utf8');console.log(JSON.stringify(evidence));
  assert.equal(run.state,'succeeded',JSON.stringify(run.error));
 }finally{
  if(run&&['queued','running'].includes(run.state))await api('/cancel',{id:run.id});
  else await api('/delete-notebook',{notebookId:n.id,expectedRevision:n.revision});
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
