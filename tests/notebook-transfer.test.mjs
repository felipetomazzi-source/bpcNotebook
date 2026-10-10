import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import vm from 'node:vm';
function load(api={}) {
 let Script,Component;
 vm.runInNewContext(readFileSync('webapp/model/Script.js','utf8'),{TextEncoder,TextDecoder,btoa,atob,sap:{ui:{define:(_,f)=>{Script=f();}}}});
 vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{sap:{m:{},ui:{define:(_,f)=>f({extend:(_,d)=>{Component=d;}},{},
  {information:(_text,o)=>o.onClose()}, {show(){}}, {},{},api,Script,{})}}});
 return {Script,Component};
}
function fixture() {
 const {Script,Component}=load();
 const text='# É · São\r\nscript version 2 compact\r\nmessage "<tag> // #"  \r\n';
 const notebook={id:'ORIGINAL',revision:7,technicalName:'ALLOC',description:'É · Allocation',title:'Allocation',environment:'ENV',model:'MODEL',
  explanation:'All explanations\n<script>alert(1)</script>',inputs:[{name:'TIME',type:'range',value:'',dimension:'TIME',hierarchy:'PARENTH1',
  selected:['FISCAL_NODE'],resolved:['P01'],purpose:'output'},{name:'flag',type:'boolean',value:true},{name:'factor',type:'number',value:1.1}],
  cells:[{id:'first',title:'ABAP stage',source:"io->message( 'É · São' ).\r\n",explanation:'First explanation',dependencies:[],output:{runId:'PRIVATE'}},
   {id:'second',title:'Script stage',source:Script.compile(text),explanation:'Second explanation',dependencies:['first']}]};
 const state={notebook,dirty:true,scriptDrafts:{second:{language:'script',text:text+'// unsaved comment\r\n'}}};
 return {Script,Component,state};
}
test('whole notebook JSON preserves author drafts, ordering, definitions and Unicode without runtime state',()=>{
 const {Script,Component,state}=fixture(),file=Component.portableNotebook.call(state);
 assert.equal(file.origin.unsavedChanges,true);assert.equal(file.notebook.cells[1].language,'script');
 assert.equal(file.notebook.cells[1].source,state.scriptDrafts.second.text);
 assert.equal(JSON.stringify(file).includes('PRIVATE'),false);
 const restored=Component.parseNotebookFile('\uFEFF'+JSON.stringify(file));
 assert.equal(restored.cells[0].source,state.notebook.cells[0].source);
 assert.equal(Script.unpack(restored.cells[1].source).text,state.scriptDrafts.second.text);
 assert.equal(restored.cells[1].dependencies[0],'first');assert.equal(restored.inputs[0].selected[0],'FISCAL_NODE');
 assert.equal(restored.inputs[0].resolved.length,0);assert.equal(restored.id,undefined);assert.equal(restored.revision,undefined);
 assert.equal(restored.description,'É · Allocation');assert.equal(state.notebook.revision,7);
});
test('import rejects unsupported, oversized, corrupt and dependency-invalid definitions before requesting SAP',()=>{
 const {Component,state}=fixture(),file=Component.portableNotebook.call(state);
 const parse=change=>{const copy=JSON.parse(JSON.stringify(file));change(copy);return ()=>Component.parseNotebookFile(JSON.stringify(copy));};
 assert.throws(parse(f=>f.formatVersion=2),/version/);assert.throws(()=>Component.parseNotebookFile('x'.repeat(8000001)),/limit/);
 assert.throws(parse(f=>f.notebook.cells[1].dependencies=['missing']),/dependencies/);
 assert.throws(parse(f=>f.notebook.cells[1].dependencies=['first','first']),/dependencies/);
 assert.throws(parse(f=>f.notebook.cells[1].id='first'),/step definition/);
 assert.throws(parse(f=>f.notebook.cells[1].source='invalid statement'),/Script line/);
 assert.throws(parse(f=>f.notebook.inputs[2].value='NaN'),/numeric/);
 assert.throws(parse(f=>f.notebook.inputs[1].value='X'),/boolean/);
});
test('print document contains all stages, numbered complete code and explanations with safe escaping',()=>{
 const {Component,state}=fixture(),file=Component.portableNotebook.call(state),html=Component.notebookPrintHtml(file);
 assert.ok(html.includes('ABAP stage'));assert.ok(html.includes('Script stage'));assert.ok(html.includes('First explanation'));
 assert.ok(html.includes('Second explanation'));assert.ok(html.includes('unsaved comment'));
 assert.ok(html.includes('includes unsaved changes'));assert.ok(html.includes('Dependencies: first'));
 assert.ok(html.includes('&lt;script&gt;alert(1)&lt;/script&gt;'));assert.equal(html.includes('<script>'),false);
 assert.ok(html.includes('class="number">1</span>'));assert.ok(html.includes('@page{size:A4'));
 assert.equal(/https?:\/\//.test(html),false);assert.ok(html.includes('É · São'));
 if(process.env.BPC_PRINT_PREVIEW)writeFileSync(process.env.BPC_PRINT_PREVIEW,html,'utf8');
});
test('import creates a new notebook with chosen identity/context without running or binding a handler',async()=>{
 const calls=[],{Component}=load({local:false,request:async(...args)=>{calls.push(args);return {id:'NEW',revision:1};}});
 const {Component:original,state}=fixture(),definition=original.parseNotebookFile(JSON.stringify(original.portableNotebook.call(state)));
 let resolve;const done=new Promise(r=>resolve=r);
 const target={leaveNotebook:fn=>fn(),getEmbedded:()=>false,chooseContext:fn=>fn({environment:'TARGET',model:'MODEL'}),
  identityDialog:(_n,accept,initial)=>{assert.equal(initial.technicalName,'ALLOC');accept({technicalName:'ALLOC_COPY',description:'Copy'}).then(resolve);},
  resetReview(){},renderNotebook(){},refresh(){}};
 Component.importNotebookDefinition.call(target,definition);await done;
 assert.equal(calls.length,1);assert.equal(calls[0][0],'/notebooks');assert.equal(calls[0][1],'POST');
 assert.equal(calls[0][2].technicalName,'ALLOC_COPY');assert.equal(calls[0][2].environment,'TARGET');
 assert.equal(calls[0][2].id,undefined);assert.equal(target.notebook.id,'NEW');
});
