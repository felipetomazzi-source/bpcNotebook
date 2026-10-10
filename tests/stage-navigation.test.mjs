import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

test('stage navigation preserves editors and draft state while selecting matching results',()=>{
 let definition;
 vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{sap:{m:{},ui:{define:(_,factory)=>factory({extend:(_,d)=>{definition=d;}},{},{},{},{},{},{},{})}}});
 const panels=['first','second'].map(id=>({visible:true,data:()=>id,setVisible(v){this.visible=v;},editor:{value:'unsaved '+id}}));
 const state={notebook:{cells:[{id:'first'},{id:'second'}]},dirty:true,scriptDrafts:{first:{text:'unsaved first'}},
  stageTabs:{getItems:()=>["__setup","first","second"].map(key=>({data:()=>key})),setSelectedItem(item){this.key=item.data();}},inputs:{setVisible(v){this.visible=v;}},setupHelp:{setVisible(v){this.visible=v;}},
  cells:{getItems:()=>panels},outputSelect:{getItems:()=>[{getKey:()=> 'second'}],setSelectedKey(k){this.key=k;}},preview(){this.previews=(this.previews||0)+1;}};
 definition.selectStage.call(state,'second');assert.equal(panels[0].visible,false);assert.equal(panels[1].visible,true);
 assert.equal(state.outputSelect.key,'second');assert.equal(state.previews,1);assert.equal(state.dirty,true);
 assert.equal(state.scriptDrafts.first.text,'unsaved first');assert.equal(panels[0].editor.value,'unsaved first');
 definition.selectStage.call(state,'removed');assert.equal(state.stageTabs.key,'__setup');assert.equal(state.inputs.visible,true);assert.equal(state.setupHelp.visible,true);
 assert.equal(panels.every(p=>!p.visible),true);
});

test('rendering rebuilds Setup and stages once, and clearing needs no notebook variables',()=>{
 class Control {
  constructor(options={}) { this.options=options;this.items=[];this.values={}; }
  setText(v){this.text=v;return this;} setValue(v){this.value=v;return this;} setState(){return this;}
  setVisible(v){this.visible=v;return this;} setSelectedKey(v){this.key=v;return this;}
  setSelectedItem(item){this.selected=item;return this;}
  addStyleClass(){return this;} addEventDelegate(d){(this.delegates ||= []).push(d);return this;}
  setProperty(k,v){this[k]=v;return this;}
  addItem(v){this.items.push(v);return this;} getItems(){return this.items;} destroyItems(){this.items=[];}
  data(k,v){if(arguments.length===2){this.values[k]=v;return this;}return this.values[k];}
 }
 let definition;
 const m=new Proxy({},{get:()=>Control});
 vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{sap:{m,ui:{define:(_,factory)=>factory(
  {extend:(_,d)=>{definition=d;}},{},{},{},Control,{}, {},{unpack:text=>({language:'abap',text})})}}});
 const n={id:'N',title:'Calculation',revision:1,author:'A',savedAt:'',explanation:'Setup help',inputs:[{name:'FLAG',type:'boolean',value:true}],
  cells:[{id:'setup',title:'01 · First stage',source:'DATA x TYPE i.',sourceVersion:1,dependencies:[],explanation:'First stage help'},
   {id:'second',title:'02 · Second stage',source:'DATA y TYPE i.',sourceVersion:1,dependencies:['setup']}]};
 const state=Object.assign({},definition,{notebook:n,title:new Control(),meta:new Control(),inputs:new Control(),setupHelp:new Control(),
  selectedStageTitle:new Control(),stageTabs:new Control(),cells:new Control(),outputSelect:new Control(),datasetInfo:new Control(),resetReview(){}});
 state.renderNotebook();assert.equal(state.stageTabs.getItems().length,3);assert.equal(state.stageTabs.getItems()[0].options.content[0].options.text,'Setup');
 assert.equal(state.stageTabs.getItems()[1].options.content[0].options.text,'1 · First stage');
 assert.equal(state.setupHelp.getItems()[0].options.text,'Setup help');assert.equal(state.inputs.visible,true);
 state.selectStage('setup');assert.equal(state.stageTabs.selected.data('stageKey'),'setup');
 assert.equal(state.selectedStageTitle.text,'Selected step: 01 · First stage');
 assert.equal(state.stageTabs.selected.options.content[0].options.wrapping,true);
 assert.equal(state.inputs.visible,false);assert.equal(state.cells.getItems()[0].visible,true);
 assert.equal(state.cells.getItems()[1].visible,false);
 state.renderNotebook();assert.equal(state.stageTabs.getItems().length,3);assert.equal(state.cells.getItems()[0].visible,true);
 const editor=state.cells.getItems()[0].data('editor'), original=n.cells[0].source;
 let marks=0;state.mark=()=>{marks++;state.dirty=true;};
 const change=value=>editor.options.liveChange({getParameter:()=>value,getSource:()=>editor});
 editor.delegates.forEach(d=>d.onBeforeRendering?.());
 change('');change(original.replace(/\r\n/g,'\n'));
 editor.delegates.forEach(d=>d.onAfterRendering?.());
 assert.equal(marks,0);assert.equal(state.dirty,false);assert.equal(n.cells[0].source,original);
 change(original+'\n* User edit');assert.equal(marks,1);assert.equal(n.cells[0].source,original+'\n* User edit');
 assert.equal(editor.value,n.cells[0].source);
 editor.delegates.forEach(d=>d.onBeforeRendering?.());change('');change(editor.value);
 editor.delegates.forEach(d=>d.onAfterRendering?.());assert.equal(marks,1);assert.equal(n.cells[0].source,original+'\n* User edit');
 state.clearNotebook();assert.equal(state.stageTabs.getItems().length,0);assert.equal(state.setupHelp.getItems().length,0);assert.equal(state.cells.getItems().length,0);
});
