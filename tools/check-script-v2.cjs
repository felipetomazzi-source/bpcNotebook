// Preview-only native checks. Creates/archives only its own test notebooks.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),api=require('./bpc-api.cjs');
let Script;vm.runInNewContext(fs.readFileSync('webapp/model/Script.js','utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
const testSource=fs.readFileSync('tests/script-v2.test.mjs','utf8').match(/export const nativeScript = `([\s\S]*?)`;/)[1];
const evidence={at:new Date().toISOString(),financialPosting:false,cases:[],passed:false};
async function run(n,scope='all',cellId=''){
 let r=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope,cellId,idempotencyKey:randomUUID()});
 for(let i=0;i<240&&['running','queued'].includes(r.state);i++){await new Promise(resolve=>setTimeout(resolve,500));r=await api('/run?id='+r.id,null,'GET');}
 return r;
}
async function check(name,cells,expect='succeeded',inputs=[]){
 const n=await api('/notebooks',{title:'Platform Script v2 '+name,explanation:'Controlled in-memory verification; no financial posting.',inputs:[{name:'PREVIEW_ROWS',type:'number',value:'3'},...inputs],cells:cells.map(c=>({...c,title:c.id,source:c.abap||Script.compile(c.script),dependencies:c.dependencies||[]}))});
 try{
  for(const c of n.cells){const v=await api('/validate',{notebookId:n.id,cellId:c.id});assert.equal(v.supported,true,JSON.stringify(v));}
  const r=await run(n);evidence.cases.push({name,notebookId:n.id,runId:r.id,state:r.state,error:r.error,results:r.results});
  assert.equal(r.state,expect,JSON.stringify(r.error));return {n,r};
 }finally{const current=await api('/notebook?id='+n.id,null,'GET');await api('/delete-notebook',{notebookId:n.id,expectedRevision:current.revision});}
}
const prefix='script version 2\ntable rows columns TIME member, MATCONN member, SIGNEDDATA signed\nrow r like rows\nr.TIME = "period_A"\nr.MATCONN = "A"\nr.SIGNEDDATA = 1\nappend rows row r\nappend rows row r\n';
const oracle=`DATA native TYPE uj_signeddata.
DATA(descr) = cl_abap_typedescr=>describe_by_data( native ).
IF descr->decimals <> 7 OR descr->type_kind <> cl_abap_typedescr=>typekind_packed.
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NATIVE_TYPE' detail = 'Unexpected native UJ_SIGNEDDATA'.
ENDIF.
io->message( |UJ_SIGNEDDATA kind={ descr->type_kind } bytes={ descr->length } decimals={ descr->decimals }| ).
DATA old TYPE zcl_bn_dem_model=>tabl.
DATA current TYPE zcl_bn_dem_model=>tabl.
APPEND VALUE #( category = 'Actual' time = 'T1' account = 'A' signeddata = 10 ) TO old.
APPEND VALUE #( category = 'Actual' time = 'T1' account = 'A' signeddata = 12 ) TO old.
APPEND VALUE #( category = 'Actual' time = 'T1' account = 'B' signeddata = 7 ) TO old.
APPEND VALUE #( category = 'Actual' time = 'T1' account = 'D' signeddata = 0 ) TO old.
APPEND VALUE #( category = 'Actual' time = 'T1' account = 'A' signeddata = 10 ) TO current.
APPEND VALUE #( category = 'Actual' time = 'T1' account = 'A' signeddata = 10 ) TO current.
APPEND VALUE #( category = 'Actual' time = 'T1' account = 'C' signeddata = 0 ) TO current.
APPEND VALUE #( category = 'Actual' time = 'T1' account = 'E' signeddata = CONV uj_signeddata( '-0.0000001' ) ) TO current.
DATA(old_model) = NEW zcl_bn_dem_model( environment = 'CH_PLANNING' model_data = old compressed = abap_false ).
DATA(new_model) = NEW zcl_bn_dem_model( environment = 'CH_PLANNING' model_data = current compressed = abap_false ).
DATA(ignore) = new_model->compare_delta( old_model ).
DATA(actual) = zcl_bn_table=>changes( io = io rows = current previous = old mode = 'legacy' ).
FIELD-SYMBOLS <actual> TYPE STANDARD TABLE. ASSIGN actual->* TO <actual>.
DATA typed TYPE zcl_bn_dem_model=>tabl. typed = <actual>.
IF typed <> new_model->model_data.
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DELTA_ORACLE' detail = 'Legacy change-set differs including duplicate order'.
ENDIF.
io->emit_table( name = 'DELTA_ORACLE' rows = typed ).
io->message( 'DELTA_ORACLE_OK' ).`;
(async()=>{
 await check('native operations',[{id:'native',script:testSource}]);
 await check('legacy changeset',[{id:'oracle',abap:oracle}]);
 await check('unique index rejects duplicates',[{id:'fail',script:prefix+'index ix = rows by ["TIME", "MATCONN"] unique'}],'failed');
 await check('unique lookup rejects duplicates',[{id:'fail',script:prefix+'index ix = rows by ["TIME", "MATCONN"] many\nlookup hit = ix where TIME = "period_A" and MATCONN = "A" policy unique missing error'}],'failed');
 await check('strict changes rejects duplicates',[{id:'fail',script:prefix+'empty old = rows\nchanges delta = rows against old mode unique'}],'failed');
 await check('explicit native result boundary',[{id:'fail',script:prefix+'cast high = rows with SIGNEDDATA decimal\nresult high as "OUTPUT" kind delta'}],'failed');
 const seed=`script version 2
table rows columns CATEGORY member, TIME member, SIGNEDDATA signed, RATIO decimal, POSITION integer
row r like rows
r.CATEGORY = "Actual"
r.TIME = "period_A"
r.RATIO = decimal("0.000000000000000000000000000000001")
let counter = integer(0)
for memberid in ["batch"]
  counter = 1
end
`;
 const abapSeed="TYPES: BEGIN OF ty_row, category TYPE uj_dim_member, time TYPE uj_dim_member, signeddata TYPE uj_signeddata, ratio TYPE decfloat34, position TYPE i, END OF ty_row.\nDATA rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.\nDO 12003 TIMES.\n APPEND VALUE #( category = 'Actual' time = 'period_A' signeddata = CONV uj_signeddata( '-0.0000001' ) * sy-index ratio = CONV decfloat34( '0.000000000000000000000000000000001' ) position = sy-index ) TO rows.\nENDDO.\nio->publish_dataset( name = 'FULL' rows = rows ).\nCLEAR rows.\nio->publish_dataset( name = 'EMPTY' rows = rows ).";
 const handoff=`script version 2
dataset rows = "seed" named "FULL"
assert count(rows) == 12003 message "Preview used as input"
find final = rows where POSITION = 12003 search linear missing error
assert final.SIGNEDDATA == signed("-0.0012003") message "Native amount lost"
assert final.RATIO == decimal("0.000000000000000000000000000000001") message "Native precision lost"
final.SIGNEDDATA = 99
publish rows as "CHANGED"`;
 const verify=`script version 2
dataset rows = "seed" named "FULL"
find first = rows where POSITION = 1 search linear missing error
assert first.SIGNEDDATA == signed("-0.0000001") message "Producer dataset mutated"
dataset emptyrows = "seed" named "EMPTY"
assert count(emptyrows) == 0 message "Empty dataset lost"
row emptyrow like emptyrows
emptyrow.POSITION = 1
append emptyrows row emptyrow
publish emptyrows as "EMPTY_SCHEMA"
publish rows as "VERIFIED"`;
 const handoffResult=await check('full shared tables',[{id:'seed',abap:abapSeed},{id:'mutate',script:handoff,dependencies:['seed']},{id:'verify',script:verify,dependencies:['seed','mutate']}]);
 assert.equal(handoffResult.r.results.find(c=>c.cellId==='seed').rowCount,12003);
 await check('working table budget fails explicitly',[{id:'fail',abap:abapSeed.replace("io->publish_dataset( name = 'FULL' rows = rows ).","zcl_bn_table=>check( io = io rows = rows ).")}],'failed',[{name:'DATASET_BYTES',type:'number',value:'1048576'}]);
 evidence.passed=true;
})().catch(e=>{evidence.failure=e.message;console.error(e.message);process.exitCode=1;}).finally(()=>{
 fs.writeFileSync('docs/evidence/native-script-v2.json',JSON.stringify(evidence,null,2)+'\n','utf8');
 console.log(JSON.stringify({passed:evidence.passed,cases:evidence.cases.map(c=>({name:c.name,state:c.state,error:c.error}))}));
});
