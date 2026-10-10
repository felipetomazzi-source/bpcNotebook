import test from 'node:test';
import assert from 'node:assert/strict';
import {Engine,demo} from '../local/engine.mjs';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';

test('folders persist privately without changing notebook revisions, history or execution snapshots',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'bn-folders-'));try{
 const e=new Engine({file:join(dir,'store.json'),auto:false,delay:0});const n=e.create({...demo(),technicalName:"TEST_ALLOCATION",description:"Test allocation"},'alice');
 const run=e.submit({notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:crypto.randomUUID()},'alice');await e.execute(run.id);
 const original=e.get(n.id,'alice'),history=e.history(n.id,'alice'),snapshot=e.run(run.id,'alice');
 const save=org=>e.saveOrganization({...org,expectedRevision:org.revision},'alice');
 let org=save({...e.organization('alice'),folders:[{id:'revenue',name:'Demand & Revenue'}]});
 org=save({...org,memberships:[{notebookId:n.id,folderId:'revenue'}]});
 assert.deepEqual(e.organization('bob'),{revision:0,folders:[],memberships:[]});
 assert.throws(()=>e.saveOrganization({expectedRevision:0,folders:[{id:'x',name:'X'}],memberships:[{notebookId:n.id,folderId:'x'}]},'bob'),{code:'NOT_FOUND'});
 assert.throws(()=>save({...org,expectedRevision:0,revision:0}),{code:'CONFLICT'});
 assert.throws(()=>save({...org,folders:[],memberships:[]}),{code:'FOLDER_NOT_EMPTY'});
 assert.throws(()=>save({...org,memberships:[{notebookId:n.id,folderId:'missing'}]}),{code:'FOLDER'});
 assert.throws(()=>save({...org,folders:[...org.folders,{id:'other',name:'demand & revenue'}]}),{code:'FOLDER'});
 org=save({...org,folders:[{id:'revenue',name:'Revenue · É'}]});
 const restarted=new Engine({file:join(dir,'store.json'),auto:false});assert.deepEqual(restarted.organization('alice'),org);
 org=save({...org,memberships:[]});org=save({...org,folders:[]});
 assert.deepEqual(e.get(n.id,'alice'),original);assert.deepEqual(e.history(n.id,'alice'),history);assert.deepEqual(e.run(run.id,'alice'),snapshot);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
test('folder navigation shows each notebook once, searches explanations across collapsed folders and preserves drafts',()=>{
 class Control {
  constructor(options={}){this.options=options;this.items=[];this.values={};}
  addStyleClass(){return this;} data(k,v){if(arguments.length===2){this.values[k]=v;return this;}return this.values[k];}
  addItem(v){this.items.push(v);} destroyItems(){this.items=[];}getItems(){return this.items;}setNoDataText(){}setSelectedItem(){}
 }
 let definition;const m=new Proxy({},{get:()=>Control});
 vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{sap:{m,ui:{core:{Icon:Control},define:(_,f)=>f({extend:(_,d)=>definition=d},{},{},{},{},{},{},{})}}});
 const state=Object.assign({},definition,{list:new Control(),getEmbedded:()=>true,dirty:true,notebook:{id:'a'},scriptDrafts:{a:{text:'unsaved'}},
 organization:{folders:[{id:'calc',name:'Demand & Revenue'},{id:'test',name:'Validation'}],memberships:[{notebookId:'a',folderId:'calc'},{notebookId:'b',folderId:'test'}]},
 _notebookHeaders:[{id:'a',title:'Same',model:'DEM',environment:'E',revision:1,explanation:'Allocation'},
 {id:'b',title:'Same',model:'DEM',environment:'E',revision:1,explanation:'Exact comparison'},
 {id:'c',title:'Other',model:'DEM',environment:'E',revision:1}],notebookSearch:{getValue:()=>''}});
 const ids=()=>state.list.items.map(i=>i.data('id')).filter(Boolean);
 state.renderNotebookList();assert.deepEqual(ids(),['c','a','b']);
 state._closedFolders.test=true;state.renderNotebookList();assert.deepEqual(ids(),['c','a']);
 state.notebookSearch.getValue=()=> 'comparison';state.renderNotebookList();assert.deepEqual(ids(),['b']);
 const folder=state.list.items[0].options.content[0].options.content[1].options.text;assert.equal(folder,'Validation (1)');
 assert.equal(state.dirty,true);assert.equal(state.scriptDrafts.a.text,'unsaved');
});
