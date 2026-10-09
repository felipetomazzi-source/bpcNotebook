import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

function api(fetch, local=false) {
  let value;
  vm.runInNewContext(readFileSync('webapp/model/Api.js','utf8'),{fetch,URL,URLSearchParams,
    window:{location:{search:'?sap-client=001',href:'http://sap.invalid/'}},
    sap:{ui:{require:{toUrl:()=>local?'http://sap.invalid/webapp/Component.js':'/sap/bc/ui5_ui5/sap/zbpc_notebook/Component.js'},
      define:(_,factory)=>{value=factory();}}}});
  return value;
}
function script() {
  let value;
  vm.runInNewContext(readFileSync('webapp/model/Script.js','utf8'),{TextEncoder,TextDecoder,btoa,atob,
    sap:{ui:{define:(_,factory)=>{value=factory();}}}});
  return value;
}
function component(format) {
  let definition;
  vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{sap:{m:{},ui:{define:(_,factory)=>{
    factory({extend:(_,value)=>{definition=value;}},{},{},{show(){}},{},{},{prettyPrint:format},script(),{});
  }}}});
  const cell={id:'c',source:'original'},notebook={cells:[cell]},draft={language:'abap',text:'original'};
  const editor={value:'original',getCurrentValue(){return this.value;},setValue(v){this.value=v;},focus(){}};
  const button={setEnabled(v){this.enabled=v;}};
  const state={notebook,mark(){this.dirty=true;},error(e){this.failure=e;}};
  return {definition,state,cell,notebook,draft,editor,button,
    run(){return definition.prettyPrintCell.call(state,notebook,cell,draft,editor,{},button);}};
}

test('native formatting separates collapsed ABAP without touching literals, nested templates or comments',async()=>{
  let sent;
  const calls=[];
  const service=api(async(url,options)=>{
    calls.push({url,options});
    if(options.method!=='POST')return new Response('',{headers:{'X-CSRF-Token':'token'}});
    sent=options.body;return new Response(options.body);
  });
  const source=`DATA x TYPE decfloat34. x = 0.5. io->message( 'É · Don''t. split' ). io->message( \`Keep. text\` ).
* Full-line. comment.
io->message( |{ CONV string( |Inner. value| ) }. tail| ). x = 2. " Inline. comment.

`;
  const result=await service.prettyPrint(source);
  assert.match(sent,/decfloat34\.\n x = 0\.5\.\n io->message/);
  assert.ok(sent.includes("'É · Don''t. split'"));
  assert.ok(sent.includes('`Keep. text`'));
  assert.ok(sent.includes('|{ CONV string( |Inner. value| ) }. tail|'));
  assert.ok(sent.includes('* Full-line. comment.'));
  assert.ok(sent.includes('x = 2. " Inline. comment.'));
  assert.ok(result.endsWith('\n\n'));
  assert.equal(calls[0].url,'/sap/bc/adt/abapsource/prettyprinter/settings?sap-client=001');
  assert.equal(calls[1].options.headers['X-CSRF-Token'],'token');
  assert.equal(calls[1].options.credentials,'same-origin');
});

test('SAP errors fail closed; formatting retries an expired token only once',async()=>{
  let posts=0;
  const service=api(async(_,options)=> options.method==='POST'
    ? (++posts===1 ? new Response('',{status:403}) : new Response('DATA x TYPE i.\r\n'))
    : new Response('',{headers:{'X-CSRF-Token':'new-token'}}));
  assert.equal(await service.prettyPrint('data x type i.\r\n\r\n'),'DATA x TYPE i.\r\n\r\n');
  assert.equal(posts,2);
  const unavailable=api(async()=>new Response('',{status:403}));
  await assert.rejects(()=>unavailable.prettyPrint('data x type i.'),/ADT access/);
  await assert.rejects(()=>api(()=>assert.fail('No SAP in local mode'),true).prettyPrint('data x type i.'),/requires the SAP/);
  await assert.rejects(()=>service.prettyPrint("io->message( 'unclosed )."),/Close the ABAP literal/);
});

test('script indentation preserves compiled logic, text, comments and line endings',()=>{
  const Script=script();
  const source=`let x = 1\r\nif x > 0\r\nmessage "É ·  text"  \r\n# Comment. untouched\r\nelse\r\nmessage "other"\r\nend\r\n\r\n`;
  const formatted=Script.prettyPrint(source);
  assert.ok(formatted.includes('\r\n  message "É ·  text"  \r\n  # Comment. untouched'));
  assert.ok(formatted.endsWith('\r\n\r\n'));
  assert.equal(Script.compile(formatted).split('* @bn-generated\n')[1],Script.compile(source).split('* @bn-generated\n')[1]);
  assert.equal(Script.prettyPrint(formatted),formatted);
  assert.throws(()=>Script.prettyPrint('if true\nmessage "x"'),/Missing end/);
});

test('format action marks a draft without saving and never overwrites edits made during its request',async()=>{
  const success=component(async()=> 'formatted');
  await success.run();
  assert.equal(success.cell.source,'formatted');assert.equal(success.draft.text,'formatted');
  assert.equal(success.editor.value,'formatted');assert.equal(success.state.dirty,true);assert.equal(success.button.enabled,true);
  let resolve;
  const pending=component(()=>new Promise(r=>{resolve=r;}));
  const request=pending.run();await Promise.resolve();pending.editor.value='newer edit';resolve('obsolete');await request;
  assert.equal(pending.editor.value,'newer edit');assert.equal(pending.cell.source,'original');
  assert.equal(pending.state.dirty,undefined);assert.equal(pending.button.enabled,true);
  const failure=component(async()=>{throw new Error('Denied');});
  await failure.run();assert.equal(failure.cell.source,'original');assert.equal(failure.state.failure.message,'Denied');
});
