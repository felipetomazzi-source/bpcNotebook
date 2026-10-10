import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
let Script;
vm.runInNewContext(readFileSync('webapp/model/Script.js','utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
test('metadata fixtures require explicit typed dataset names and preserve author source',()=>{
 const text='script version 2 compact\ndataset facts = "capture" named "FACTS"\ndataset metadata = "capture" named "METADATA"\nfixture facts model "DEMREVID" metadata metadata';
 const source=Script.compile(text);
 assert(source.includes('metadata = <'));
 assert(source.includes('freeze_metadata = abap_true'));
 assert.equal(Script.unpack(source).text,text);
 assert.throws(()=>Script.compile('script version 2\ntable facts columns TIME member\nfixture facts model "DEMREVID" metadata absent'),/Unknown/);
 assert.throws(()=>Script.compile('script version 2\ntable facts columns TIME member\nlet scalar = 1\nfixture facts model "DEMREVID" metadata scalar'),/table/);
});
