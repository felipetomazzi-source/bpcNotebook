import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import vm from 'node:vm';
import {nativeScript} from './script-v2.test.mjs';
import {Engine,demo} from '../local/engine.mjs';
function load(source){let Script;vm.runInNewContext(source,{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});return Script;}
const Script=load(readFileSync('webapp/model/Script.js','utf8'));
test('ordinary saved v1/v2 envelopes retain their exact existing compiled bytes',()=>{
 const previous=load(execFileSync('git',['show','3e55590:webapp/model/Script.js'],{encoding:'utf8'}));
 for(const source of ['let x = 1\nmessage text(x)',nativeScript]){
  const saved=previous.compile(source);assert.equal(Script.compile(source),saved);assert.equal(Script.unpack(saved).text,source);
 }
});
test('compact mode reduces repeated field scaffolding without caching row pointers',()=>{
 const source='script version 2\ntable rows columns TIME member, SIGNEDDATA signed\nfor row in rows\n'+
  Array.from({length:50},()=> 'row.SIGNEDDATA = row.SIGNEDDATA + 1').join('\n')+'\nend';
 const ordinary=Script.compile(source),compact=Script.compile(source.replace('version 2','version 2 compact'));
 assert(compact.length<ordinary.length*0.4);
 assert.equal((compact.match(/^bn_field_new /gm)||[]).length,1);
 assert.match(compact,/DEFINE bn_field/);assert.match(compact,/UNASSIGN &1/);assert.match(compact,/ASSIGN COMPONENT &2 OF STRUCTURE &3 TO &1/);
 assert.equal((compact.match(/^bn_field(?:_new)? </gm)||[]).length,100);
 assert.equal(Script.unpack(compact).language,'script');
 assert.equal(compact.split('\n').every(s=>s.length<=255),true);
});
test('defaults and scalar list helpers are explicit and reject ambiguous maps',()=>{
 const source='script version 2 compact\ntable rows columns TIME member, SIGNEDDATA signed\ndefaults rows with TIME "TIME_NA", SIGNEDDATA "1.2345678"\nlet ids = split(" A, B ,,C ", ",")\nlet id = trim(at(ids, 2))\nmessage id';
 const code=Script.compile(source);assert.match(code,/zcl_bn_table=>defaults/);assert.match(code,/name = `TIME` value = `TIME_NA`/);
 assert.match(code,/zcl_bn_table=>split/);assert.match(code,/zcl_bn_table=>at/);assert.match(code,/shift_left/);
 assert.equal(Script.unpack(code).text,source);
 for(const bad of ['defaults rows with TIME "X", TIME "Y"','defaults rows with TIME 5',
 'let ids = split(1, ",")','let item = at("abc", 1)','let item = trim(1)']){
  assert.throws(()=>Script.compile('script version 2\ntable rows columns TIME member\n'+bad),/Script line/);
 }
});
test('larger budget is bounded and restricted to the exact compact envelope',()=>{
 const e=new Engine({auto:false}),definition={...demo(),technicalName:'TEST_COMPACT',description:'Compact test'};
 definition.cells=definition.cells.slice(0,1);
 definition.cells[0].source='* BPC Notebook Script v2 compact\n'+' '.repeat(90000);
 assert.equal(e.create(definition,'alice').cells[0].source,definition.cells[0].source);
 for(const source of [' '.repeat(90000),'* BPC Notebook Script v2\n'+' '.repeat(90000),
 '* BPC Notebook Script v2 compact\n'+' '.repeat(120000)]){
  assert.throws(()=>e.create({...definition,cells:[{...definition.cells[0],source}]},'alice'),{code:'SOURCE'});
 }
});
