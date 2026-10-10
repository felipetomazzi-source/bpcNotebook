import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
let Script;
vm.runInNewContext(readFileSync('webapp/model/Script.js','utf8'), {
  sap:{ui:{define:(_,factory)=>{Script=factory();}}}, TextEncoder,TextDecoder,btoa,atob
});
const allocation = `# É · São — preserves original text and spaces  \r\n
let total = number(input("total"))
table rows
append rows key = "CC100" amount = total * 0.5
append rows key = "CC200" amount = total * 0.3
append rows key = "CC300" amount = total * 0.2
for row in rows
  if row.amount > 0
    row.amount = row.amount * number(input("factor"))
  else
    row.amount = 0
  end
end
emit rows
show rows as "ALLOCATION"
message "É · São — ready"
`;
test('script round trip preserves author text exactly and generates deterministic ABAP',()=>{
  const abap=Script.compile(allocation);
  assert.equal(Script.unpack(abap).text,allocation);
  assert.equal(Script.unpack(abap).language,'script');
  assert.equal(Script.compile(allocation),abap);
  assert.match(abap,/LOOP AT/);assert.match(abap,/io->emit_table/);assert.match(abap,/xsdbool/);
  assert.match(abap,/É · São — ready/);
  assert.equal(abap.split('\n').every(s=>s.length<=255),true);
  const line=abap.split('\n').findIndex(s=>s.includes('io->emit_table'))+1;
  assert.equal(Script.sourceLine(abap,line),16);
});
test('dimension and model sugar retains authorized adapter calls and frozen selections',()=>{
  const abap=Script.compile(`dimension materials = DEMREVID-MATCONN
members members = materials ["A", "B"]
let label = materials-EVDESCRIPTION("A")
let label2 = DEMREVID-MATCONN-EVDESCRIPTION(member("CATEGORY"))
model plan = DEMREVID
data facts = plan where TIME = range("TIME") and CATEGORY = selection("CATEGORY") limit 500
for row in facts
  row.SIGNEDDATA = row.SIGNEDDATA * 1.1
end
show facts as "FACTS"
message text(count(facts))`);
  assert.match(abap,/model_name = `DEMREVID`/);assert.match(abap,/max_rows = 500/);
  assert.match(abap,/io->range/);assert.match(abap,/io->selection/);assert.match(abap,/BPC_SCRIPT_FIELD/);
  assert.match(abap,/name = `EVDESCRIPTION`/);
  assert.equal(Script.unpack(abap).language,'script');
});
test('syntax and type errors fail closed with script line numbers',()=>{
  for(const source of ['EXEC SQL.', 'let n = unknown', 'let n = "x" * 2', 'for row in missing',
    'if true', 'end', 'else', 'let n = 1\nlet n = 2', 'let n = 1\nn = "text"',
    'data x = DEMREVID where TIME = "2025"', 'data x = DEMREVID limit 0',
    'message "unterminated', 'message "a\\nb"', 'dimension d = DEMREVID-MATCONN\nmessage d',
    'table rows\nfor row in rows\nend\nmessage row.ID']) {
    assert.throws(()=>Script.compile(source),/Script line \d+:/,source);
  }
});
test('ABAP compatibility and changed generated source are never silently rewritten',()=>{
  const source="io->message( 'ABAP remains ABAP' ).";
  assert.equal(Script.unpack(source).language,'abap');assert.equal(Script.unpack(source).text,source);
  const abap=Script.compile('message "script"');
  assert.equal(Script.unpack(abap+'\nio->message( `manual` ).').language,'abap');
  const escaped=Script.compile('message "a`b \'c É ·"');
  assert.match(escaped,/`a``b 'c É ·`/);
});
test('model aliases generate actual model names for dimension access',()=>{
  const abap=Script.compile('model plan = DEMREVID\ndimension category = plan-CATEGORY\nlet label = plan-CATEGORY-EVDESCRIPTION("Actual")\nmessage label');
  assert.equal((abap.match(/model_name = `DEMREVID`/g)||[]).length,2);
  assert.equal(Script.unpack(abap).language,'script');
});
test('text concatenation and long literals use SAP string expressions',()=>{
  const source='let label = "É ·"\nmessage concat(label, " São ` quote: \'")\nmessage "'+'x'.repeat(150)+'"';
  const abap=Script.compile(source);
  assert.match(abap,/CONV string\( CONV string\( bn_s1 \) && CONV string\(/);
  assert.equal(Script.unpack(abap).text,source);
});
test('editor completions fetch metadata with the current environment and resolve aliases',async()=>{
  let component;
  vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{
    sap:{m:{},ui:{define:(_,f)=>{component=f({extend:(_,definition)=>definition},null,null,null,null,null,null,Script);}}}
  });
  component.notebook={environment:'ENV',model:'DEMREVID'};
  const calls=[];
  component.scriptMetadata=async(kind,model,dimension)=>{
    if(model==='NOTAUTHORIZED'){throw new Error('BPC_AUTH');}
    calls.push({kind,model,dimension});return [{id:kind==='dimensions'?'TIME':'EVDESCRIPTION',description:'From metadata'}];
  };
  let items=await component.scriptSuggestions('', 'DEMREV-');
  assert.equal(items[0].value,'DEMREV-TIME');assert.equal(calls.at(-1).model,'DEMREV');
  items=await component.scriptSuggestions('model plan = DEMREVID\ndimension time = plan-TIME', 'time-');
  assert.equal(items[0].value,'time-EVDESCRIPTION');assert.deepEqual(calls.at(-1),{kind:'properties',model:'DEMREVID',dimension:'TIME'});
  items=await component.scriptSuggestions('model plan = DEMREVID', 'plan-TIME-');
  assert.equal(items[0].value,'plan-TIME-EVDESCRIPTION');
  items=await component.scriptSuggestions('reference model refs = DEMREVID', 'refs-TIME-');
  assert.equal(items[0].value,'refs-TIME-EVDESCRIPTION');
  items=await component.scriptSuggestions('script version 2', '');
  for(const keyword of ['dataset','index','ordered','fixture','decimal'])assert(items.some(i=>i.value===keyword));
  await assert.rejects(component.scriptSuggestions('', 'NOTAUTHORIZED-'),/BPC_AUTH/);
});
