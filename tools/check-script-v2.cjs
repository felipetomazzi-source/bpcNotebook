// Preview-only native checks. Creates/archives only its own test notebooks.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),api=require('./bpc-api.cjs');
let Script;vm.runInNewContext(fs.readFileSync('webapp/model/Script.js','utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
const testSource=fs.readFileSync('tests/script-v2.test.mjs','utf8').match(/export const nativeScript = `([\s\S]*?)`;/)[1];
const evidence={at:new Date().toISOString(),system:'NPL',client:process.env.SAP_CLIENT,
 sourceCommit:require('node:child_process').execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),
 financialPosting:false,cases:[],passed:false};
async function run(n,scope='all',cellId=''){
 let r=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope,cellId,idempotencyKey:randomUUID()});
 for(let i=0;i<240&&['running','queued'].includes(r.state);i++){await new Promise(resolve=>setTimeout(resolve,500));r=await api('/run?id='+r.id,null,'GET');}
 return r;
}
async function check(name,cells,expect='succeeded',inputs=[],context={}){
 const n=await api('/notebooks',{...context,title:'Platform Script v2 '+name,explanation:'Controlled in-memory verification; no financial posting.',inputs:[{name:'PREVIEW_ROWS',type:'number',value:'3'},...inputs],cells:cells.map(c=>({...c,title:c.id,source:c.abap||Script.compile(c.script),dependencies:c.dependencies||[]}))});
 try{
  for(const c of n.cells){const v=await api('/validate',{notebookId:n.id,cellId:c.id});assert.equal(v.supported,true,JSON.stringify(v));}
  const r=await run(n);evidence.cases.push({name,notebookId:n.id,runId:r.id,state:r.state,error:r.error,results:r.results,messages:r.messages});
  assert.equal(r.state,expect,JSON.stringify(r.error));
  if(expect==='failed'){
   const expectedCodes={'unique index rejects duplicates':'SCRIPT_CARDINALITY','unique lookup rejects duplicates':'SCRIPT_CARDINALITY',
    'strict changes rejects duplicates':'SCRIPT_CARDINALITY','explicit native result boundary':'SCRIPT_BOUNDARY',
    'working table budget fails explicitly':'DATASET_BUDGET','undeclared reference period is rejected':'BPC_FILTER',
    'fixture financial result publication is blocked':'FIXTURE_POSTING'};
   assert.equal(r.error.code,expectedCodes[name],JSON.stringify(r.error));
  }
  if(name==='shared authorized fixtures and frozen scopes'){
   const summary=await api('/output?runId='+r.id+'&cellId=left&revision=1&offset=0&limit=100&table=READ_1%2FSUMMARY',null,'GET');
   const selection=await api('/output?runId='+r.id+'&cellId=left&revision=1&offset=0&limit=100&table=READ_1%2FFILTERS_AND_PERIODS',null,'GET');
   const sourceColumn=summary.schema.findIndex(c=>c.name==='source');
   const securityColumn=summary.schema.findIndex(c=>c.name==='security');
   const countColumn=summary.schema.findIndex(c=>c.name==='row_count');
   assert.equal(summary.rows[0].values[sourceColumn],'fixture');
   assert.equal(summary.rows[0].values[securityColumn],'MEMBER_AUTH_ON; NO_QUERY');
   assert.equal(Number(summary.rows[0].values[countColumn]),1);
   evidence.readDiagnostics={summary,selection};
   evidence.frozenSelections=r.snapshot.inputs;
  }
  if(name==='full shared tables'){
   const header=await api('/datasets?runId='+r.id+'&cellId=seed&revision=1',null,'GET');
   assert.equal(header.artifacts.find(d=>d.name==='FULL').rowCount,12003);
   assert.equal(header.artifacts.find(d=>d.name==='EMPTY').schema.length,5);
   const page=await api('/output?runId='+r.id+'&cellId=seed&revision=1&offset=0&limit=100&table=DATASET%2FFULL',null,'GET');
   assert.equal(page.total,3);assert.equal(page.sourceTotal,12003);
   const one=await run(n,'one','verify');assert.equal(one.state,'succeeded',JSON.stringify(one.error));
   evidence.cases.push({name:'single-cell execution using valid complete predecessors',runId:one.id,state:one.state});
   const saved=await api('/notebook',{...n,expectedRevision:n.revision,cells:n.cells.map(c=>c.id==='seed'?{...c,source:c.source+'\nio->message( `new version` ).'}:c)},'PUT');
   await assert.rejects(api('/runs',{notebookId:saved.id,expectedRevision:saved.revision,scope:'one',cellId:'verify',idempotencyKey:randomUUID()}),/STALE_DEPENDENCY/);
   evidence.cases.push({name:'stale predecessors rejected',state:'rejected'});
  }
  if(name==='dimension reference snapshot boundary'){
   const one=await run(n,'one','consumer');
   assert.equal(one.state,'failed',JSON.stringify(one.error));assert.equal(one.error.code,'DATA_SNAPSHOT');
   evidence.cases.push({name:'fresh dimension properties blocked with prior-run datasets',runId:one.id,state:one.state,error:one.error});
  }
  return {n,r};
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
DATA(old_model) = NEW zcl_bn_dem_model( environment = io compressed = abap_false ).
DATA(new_model) = NEW zcl_bn_dem_model( environment = io compressed = abap_false ).
old_model->model_data = old. new_model->model_data = current.
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
 const selections=[{name:'CATEGORY',type:'member',dimension:'CATEGORY',required:true,selected:['Actual']},
  {name:'TIME',type:'range',dimension:'TIME',hierarchy:'PARENTH1',required:true,selected:['2026.006']},
  {name:'REFERENCE_TIME',type:'range',dimension:'TIME',hierarchy:'PARENTH1',required:true,purpose:'reference',selected:['TIME_NA'],lookbackFrom:'TIME',lookbackSteps:1}];
 await check('dimension reference snapshot boundary',[
  {id:'seed',script:'script version 2\ndimension categories = DEMREVID-CATEGORY\nmembers rows = categories ["Actual"]\npublish rows as "MEMBERS"'},
  {id:'consumer',script:'script version 2\ndataset retained = "seed" named "MEMBERS"\ndimension categories = DEMREVID-CATEGORY\nmembers fresh = categories ["Actual"]\ncompare summary = retained with fresh as "METADATA_SNAPSHOT" ordered',dependencies:['seed']}
 ],'succeeded',[],{environment:'CH_PLANNING',model:'DEMREVID'});
 const fixtureSeed=`DATA(adapter) = NEW zcl_bn_bpc( environment = CONV string( io->environment ) model = CONV string( io->model ) ).
DATA(periods) = io->range( 'TIME' ).
DATA(source) = adapter->read_data( filters = VALUE #( ( dimension = 'CATEGORY' members = VALUE #( ( CONV string( io->member( 'CATEGORY' ) ) ) ) )
 ( dimension = 'TIME' members = VALUE #( ( CONV string( periods[ 1 ] ) ) ) ) ) max_rows = 100000 ).
FIELD-SYMBOLS <source> TYPE STANDARD TABLE. ASSIGN source->* TO <source>.
IF <source> IS INITIAL. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_SEED' detail = 'Need authorized nonempty metadata seed'. ENDIF.
DATA(fixture) = zcl_bn_table=>copy( io = io rows = <source> empty = abap_true ).
FIELD-SYMBOLS <fixture> TYPE STANDARD TABLE. ASSIGN fixture->* TO <fixture>.
READ TABLE <source> INDEX 1 ASSIGNING FIELD-SYMBOL(<seed>).
APPEND <seed> TO <fixture> ASSIGNING FIELD-SYMBOL(<row>).
ASSIGN COMPONENT 'TIME' OF STRUCTURE <row> TO FIELD-SYMBOL(<time>).
ASSIGN COMPONENT 'SIGNEDDATA' OF STRUCTURE <row> TO FIELD-SYMBOL(<amount>). <amount> = 1.
APPEND <seed> TO <fixture> ASSIGNING <row>.
ASSIGN COMPONENT 'TIME' OF STRUCTURE <row> TO <time>. <time> = 'TIME_NA'.
ASSIGN COMPONENT 'SIGNEDDATA' OF STRUCTURE <row> TO <amount>. <amount> = 2.
APPEND <seed> TO <fixture> ASSIGNING <row>.
ASSIGN COMPONENT 'TIME' OF STRUCTURE <row> TO <time>.
<time> = io->offset_period( member = periods[ 1 ] offset_by = -1 ).
ASSIGN COMPONENT 'SIGNEDDATA' OF STRUCTURE <row> TO <amount>. <amount> = 3.
io->enable_fixtures( VALUE #( ( environment = CONV string( io->environment ) model = CONV string( io->model ) rows = fixture ) ) ).
io->publish_dataset( name = 'FIXTURE' rows = <fixture> ).`;
 const shared=`script version 2
dataset inputs = "seed" named "FIXTURE"
fixture inputs model "DEMREVID"
model calculation = DEMREVID
data output = calculation where TIME = range("TIME") limit 100
assert count(output) == 1 message "Reference became output"
reference model references = DEMREVID
data mappings = references where TIME = ["TIME_NA"] limit 100
assert count(mappings) == 1 message "Reference mapping unavailable"
let periods = range("TIME")
for period in periods
  let prior = offset(period, -1)
  data previous = references where TIME = [prior] limit 100
  assert count(previous) == 1 message "Lookback unavailable"
end
data full = references limit 100
assert count(full) == 3 message "Scope coverage"
dimension categories = DEMREVID-CATEGORY
members stored = categories ["Actual"]
properties storedschema = categories
assert count(stored) == 1 message "Authorized member metadata"
assert count(storedschema) > 0 message "Stored-property schema"
for row in full
  let description = categories-EVDESCRIPTION(row.CATEGORY)
  message description
  row.SIGNEDDATA = row.SIGNEDDATA * 2
end
publish full as "TRANSFORMED"`;
 const compare=`script version 2
dataset inputs = "seed" named "FIXTURE"
fixture inputs model "DEMREVID"
dataset a = "left" named "TRANSFORMED"
dataset b = "right" named "TRANSFORMED"
compare summary = a with b as "FIXTURE_COMPARE"
assert summary.original_rows == 3 message "Nonempty comparison required"
assert summary.added == 0 and summary.missing == 0 and summary.changed == 0 message "Shared fixture mismatch"`;
 await check('shared authorized fixtures and frozen scopes',[{id:'seed',abap:fixtureSeed},{id:'left',script:shared,dependencies:['seed']},{id:'right',script:shared,dependencies:['seed']},{id:'compare',script:compare,dependencies:['seed','left','right']}],'succeeded',selections,{environment:'CH_PLANNING',model:'DEMREVID'});
 const fixturePrefix='script version 2\ndataset inputs = "seed" named "FIXTURE"\nfixture inputs model "DEMREVID"\n';
 await check('undeclared reference period is rejected',[{id:'seed',abap:fixtureSeed},{id:'fail',script:fixturePrefix+'reference model refs = DEMREVID\ndata forbidden = refs where TIME = ["2027.006"] limit 100',dependencies:['seed']}],'failed',selections,{environment:'CH_PLANNING',model:'DEMREVID'});
 await check('fixture financial result publication is blocked',[{id:'seed',abap:fixtureSeed},{id:'fail',script:fixturePrefix+'result inputs as "BPC_RESULT" kind delta',dependencies:['seed']}],'failed',selections,{environment:'CH_PLANNING',model:'DEMREVID'});
 evidence.passed=true;
})().catch(e=>{evidence.failure=e.message;console.error(e.message);process.exitCode=1;}).finally(()=>{
 fs.writeFileSync('docs/evidence/native-script-v2.json',JSON.stringify(evidence,null,2)+'\n','utf8');
 console.log(JSON.stringify({passed:evidence.passed,cases:evidence.cases.map(c=>({name:c.name,state:c.state,error:c.error}))}));
});
