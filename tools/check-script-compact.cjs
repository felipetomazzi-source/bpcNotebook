// Native nonposting checks for compact compilation, defaults and scalar adapters.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),api=require('./bpc-api.cjs');
let Script;vm.runInNewContext(fs.readFileSync('webapp/model/Script.js','utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
const evidence={at:new Date().toISOString(),financialPosting:false,sourceCommit:require('node:child_process').execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),cases:[],passed:false};
async function check(name,cells,expectedCode=''){
 const n=await api('/notebooks',{title:'Platform compact Script '+name,explanation:'Controlled native preview only; no financial posting.',inputs:[],cells:cells.map(c=>({...c,title:c.id,dependencies:c.dependencies||[],source:c.abap||Script.compile(c.script)}))});
 try{
  for(const c of n.cells){const v=await api('/validate',{notebookId:n.id,cellId:c.id});assert.equal(v.supported,true,JSON.stringify(v));}
  const saved=await api('/notebook?id='+n.id,null,'GET');
  saved.cells.forEach((c,i)=>{if(cells[i].script)assert.equal(Script.unpack(c.source).text,cells[i].script);});
  let r=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:randomUUID()});
  for(let i=0;i<240&&['running','queued'].includes(r.state);i++){await new Promise(resolve=>setTimeout(resolve,500));r=await api('/run?id='+r.id,null,'GET');}
  evidence.cases.push({name,runId:r.id,state:r.state,error:r.error,messages:r.messages,sourceCharacters:n.cells.map(c=>c.source.length)});
  assert.equal(r.state,expectedCode?'failed':'succeeded',JSON.stringify(r.error));
  if(expectedCode)assert.equal(r.error.code,expectedCode);
 }finally{const current=await api('/notebook?id='+n.id,null,'GET');await api('/delete-notebook',{notebookId:n.id,expectedRevision:current.revision});}
}
const defaults=`script version 2 compact
table rows columns ACCOUNT member, TIME member, SIGNEDDATA signed, NOTE text
row r like rows
r.ACCOUNT = "kept"
r.SIGNEDDATA = 7
append rows row r
clear r
append rows row r
defaults rows with ACCOUNT "ACCOUNT_NA", TIME "TIME_NA", SIGNEDDATA "1.2345678", NOTE "É · São"
let counter = integer(0)
for row in rows
  counter = counter + 1
  if counter == 1
    assert row.ACCOUNT == "kept" and row.SIGNEDDATA == 7 message "Noninitial values overwritten"
  else
    assert row.ACCOUNT == "ACCOUNT_NA" and row.SIGNEDDATA == signed("1.2345678") message "Initial native defaults missing"
  end
  assert row.TIME == "TIME_NA" and row.NOTE == "É · São" message "Generic Unicode defaults"
end
defaults rows with ACCOUNT "DIFFERENT", TIME "DIFFERENT", SIGNEDDATA "9"
for row in rows
  assert row.TIME == "TIME_NA" message "Idempotent initial-only defaults"
end
let ids = split(" A, B ,,C ", ",")
assert count(ids) == 4 message "Split positions"
assert trim(at(ids, 1)) == "A" and trim(at(ids, 2)) == "B" message "Trim preserves position"
assert at(ids, 3) == "" and trim(at(ids, 4)) == "C" message "Interior empty position"
assert at(ids, 0) == "" and at(ids, 5) == "" message "Missing position"
assert no_gaps(" A B  C ") == "ABC" message "Native CONDENSE NO-GAPS"
let flags = split("1,0", ",")
let index = integer(0)
let kept = integer(0)
for id in ids
  index = index + 1
  let flag = trim(at(flags, index))
  if not initial(flag)
    if signed(flag) != 0
      kept = kept + 1
    end
  end
end
assert kept == 1 message "Explicit paired flags and absent position"
assert matches(numeric_text(signed("1.5"), 3), "+++") message "Native NUMC width"
publish rows as "DEFAULTS"
show rows as "DEFAULTS_PREVIEW"`;
const numeric=`DATA values TYPE zcl_bn_types=>tt_ids.
values = VALUE #( ( CONV string( '-1000' ) ) ( CONV string( '-999.5' ) ) ( CONV string( '-1.5' ) )
 ( CONV string( '-0.5' ) ) ( CONV string( '-0.4999999' ) ) ( CONV string( '0' ) ) ( CONV string( '0.5' ) )
 ( CONV string( '1.5' ) ) ( CONV string( '999' ) ) ( CONV string( '999.5' ) ) ( CONV string( '1000' ) ) ).
LOOP AT values INTO DATA(text).
 DATA(amount) = CONV uj_signeddata( text ). DATA(expected) = CONV num03( amount ).
 DATA(actual) = zcl_bn_table=>numeric_text( value = amount width = 3 ).
 IF actual <> CONV string( expected ). RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NUMC_ORACLE' detail = text. ENDIF.
 DATA(decimal) = CONV decfloat34( text ). expected = CONV num03( decimal ).
 actual = zcl_bn_table=>numeric_text( value = decimal width = 3 ).
 IF actual <> CONV string( expected ). RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NUMC_ORACLE' detail = text. ENDIF.
ENDLOOP.
io->message( 'NATIVE_NUM03_ORACLE_OK: 11 boundaries x packed/decfloat34' ).`;
(async()=>{
 const original=fs.readFileSync('tests/script-v2.test.mjs','utf8').match(/export const nativeScript = `([\s\S]*?)`;/)[1];
 await check('all native table operations in compact mode',[{id:'native',script:original.replace('script version 2','script version 2 compact')}]);
 await check('generic defaults and scalar lists',[{id:'defaults',script:defaults}]);
 await check('native numeric conversion oracle',[{id:'oracle',abap:numeric}]);
 const large='script version 2 compact\ntable rows columns SIGNEDDATA signed, TIME member\nrow row like rows\n'+
  Array.from({length:500},()=> 'row.SIGNEDDATA = row.SIGNEDDATA + 1').join('\n')+'\nassert row.SIGNEDDATA == 500 message "Large native source"\npublish rows as "EMPTY"';
 assert(Script.compile(large).length>60000&&Script.compile(large).length<=120000);
 await check('larger compact source save compile run reopen',[{id:'large',script:large}]);
 await check('empty schema validates default fields',[{id:'fail',script:'script version 2 compact\ntable rows columns TIME member\ndefaults rows with UNKNOWN "X"'}],'SCRIPT_FIELD');
 await check('defaults validate native conversion before mutation',[{id:'fail',script:'script version 2 compact\ntable rows columns SIGNEDDATA signed\ndefaults rows with SIGNEDDATA "bad"'}],'SCRIPT_DEFAULTS');
 await check('empty separator rejected',[{id:'fail',script:'script version 2 compact\nlet items = split("abc", "")'}],'SCRIPT_LIST');
 await check('numeric width rejected',[{id:'fail',script:'script version 2 compact\nlet text = numeric_text(1, 0)'}],'SCRIPT_NUMERIC_TEXT');
 evidence.passed=true;
})().catch(e=>{evidence.failure=e.message;console.error(e.message);process.exitCode=1;}).finally(()=>{
 fs.writeFileSync('docs/evidence/native-script-compact.json',JSON.stringify(evidence,null,2)+'\n','utf8');
 console.log(JSON.stringify({passed:evidence.passed,cases:evidence.cases}));
});
