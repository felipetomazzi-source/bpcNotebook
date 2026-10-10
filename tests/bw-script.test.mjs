import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
let Script;
vm.runInNewContext(readFileSync('webapp/model/Script.js','utf8'), {
  sap:{ui:{define:(_,factory)=>{Script=factory();}}},TextEncoder,TextDecoder,btoa,atob
});
const source=`script version 2
bwdata facts = "ZSALES" fields characteristic "0CALMONTH" as MONTH type "/BI0/OICALMONTH", keyfigure "0AMOUNT" as AMOUNT type "/BI0/OIAMOUNT" where "0CALMONTH" = ["202601"] limit 1000
show facts as "BW"
`;
test('BW explicit projection, exact filters, limit and native table round trip',()=>{
  const abap=Script.compile(source);
  assert.equal(Script.unpack(abap).text,source);
  assert.match(abap,/io->bw_data\(/);
  assert.match(abap,/max_rows = 1000/);
  assert.match(abap,/ddic_type =\s+`\/BI0\/OIAMOUNT`/);
  assert.match(abap,/dimension = `0CALMONTH`/);
  assert.equal(abap.split('\n').every(line=>line.length<=255),true);
});
test('BW rejects missing/unbounded limits, duplicate projections and injected names',()=>{
  for(const invalid of [source.replace(' limit 1000',''),source.replace('limit 1000','limit 100001'),
    source.replace('as AMOUNT','as MONTH'),source.replace('"ZSALES"','"ZSALES; SELECT"'),
    source.replace('type "/BI0/OIAMOUNT"','type "TYPE; CODE"'),source.replace('["202601"]','"202601"')]){
    assert.throws(()=>Script.compile(invalid));
  }
});
test('BW filters escape literal bytes and reject executable expressions',()=>{
  const literalSource=source.replace('["202601"]','["a`b; SELECT *", "x\\\"y"]');
  const abap=Script.compile(literalSource);
  assert.equal(Script.unpack(abap).text,literalSource);
  assert.match(abap,/`a``b; SELECT \*`/);
  assert.throws(()=>Script.compile(source.replace('["202601"]','number(input("limit"))')));
  assert.throws(()=>Script.compile(source.replace('limit 1000','limit input("limit")')));
});
test('BW source enforces authorization, single-call bounds, complete results and adapter scope',()=>{
  // Static policy regression check only; runtime behavior is covered by the unexecuted ABAP Unit seams.
  const native=readFileSync('src/zcl_bn_bw.clas.abap','utf8');
  assert.match(native,/io->check_bw_context\( \)/);
  assert.match(native,/i_authority_check = 'R'/);
  assert.match(native,/i_commit_allowed = abap_false/);
  assert.match(native,/max_rows > 100000/);
  assert.match(native,/fetch_limit\) = max_rows \+ 1/);
  assert.match(native,/i_packagesize = fetch_limit/);
  assert.match(native,/i_maxrows = fetch_limit/);
  assert.equal((native.match(/CALL FUNCTION 'RSDRI_INFOPROV_READ'/g)||[]).length,1);
  assert.match(native,/IF ended <> abap_true OR split_occurred IS NOT INITIAL OR lines\( <rows> \) > max_rows\./);
  assert.match(native,/IF sy-subrc <> 0\.\s+CLEAR <rows>\.\s+RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BW_READ'/);
});
