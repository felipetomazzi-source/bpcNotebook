import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { bspContent, readUtf8, gitBytes } from '../tools/sap-bytes.mjs';

test('BSP preserves Unicode, punctuation, trailing spaces and intentional final blank lines',()=>{
 const input='É · São — “notebook”  \r\n\r\n';
 const output=bspContent(input);
 assert.equal(output.split('\r\n').length,3);
 assert.deepEqual(output.split('\r\n').map(s=>s.length),[255,255,255]);
 assert.equal(output.slice(0,input.indexOf('\r')),input.slice(0,input.indexOf('\r')));
 assert.equal(bspContent('no newline').split('\r\n').length,1);
 assert.throws(()=>bspContent('\uFEFFpage'),/BOM/);
 assert.throws(()=>bspContent('x'.repeat(256)),/255/);
});

test('packaging leaves native sources and SAP metadata byte-identical and is idempotent',()=>{
 const names=readdirSync('src');
 const before=new Map(names.map(n=>[n,readFileSync('src/'+n)]));
 execFileSync(process.execPath,['tools/pack-sap.mjs']);
 for(const n of names)assert.deepEqual(readFileSync('src/'+n),before.get(n),n);
});

test('repository bytes match the recorded real SAP serialization',()=>{
 const evidence=JSON.parse(readUtf8('docs/evidence/sap-roundtrip.json'));
 assert.equal(evidence.passed,true);
 assert.equal(evidence.files.length,45);
 for(const file of evidence.files){
  const path=file.filename==='.abapgit.xml'?file.filename:'src/'+file.filename;
  const bytes=readFileSync(path);
  assert.equal(createHash('sha256').update(gitBytes(bytes)).digest('hex'),file.sapSha256,path);
  const bom=bytes.subarray(0,3).equals(Buffer.from([0xef,0xbb,0xbf]));
  assert.equal(bom,path.endsWith('.xml')&&!path.includes('.wapa.ui5repository'),path+' BOM');
  assert.equal(/(?<!\r)\n/.test(readUtf8(path)),false,path+' LF checkout');
  assert.equal(file.equal,true);
 }
});
