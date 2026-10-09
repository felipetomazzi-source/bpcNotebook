import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

test('stage navigation preserves editors and draft state while selecting matching results',()=>{
 let definition;
 vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{sap:{m:{},ui:{define:(_,factory)=>factory({extend:(_,d)=>{definition=d;}},{},{},{},{},{},{},{})}}});
 const panels=['first','second'].map(id=>({visible:true,data:()=>id,setVisible(v){this.visible=v;},editor:{value:'unsaved '+id}}));
 const state={notebook:{cells:[{id:'first'},{id:'second'}]},dirty:true,scriptDrafts:{first:{text:'unsaved first'}},
  stageTabs:{setSelectedKey(k){this.key=k;}},inputs:{setVisible(v){this.visible=v;}},setupHelp:{setVisible(v){this.visible=v;}},
  cells:{getItems:()=>panels},outputSelect:{getItems:()=>[{getKey:()=> 'second'}],setSelectedKey(k){this.key=k;}},preview(){this.previews=(this.previews||0)+1;}};
 definition.selectStage.call(state,'second');assert.equal(panels[0].visible,false);assert.equal(panels[1].visible,true);
 assert.equal(state.outputSelect.key,'second');assert.equal(state.previews,1);assert.equal(state.dirty,true);
 assert.equal(state.scriptDrafts.first.text,'unsaved first');assert.equal(panels[0].editor.value,'unsaved first');
 definition.selectStage.call(state,'removed');assert.equal(state.stageTabs.key,'setup');assert.equal(state.inputs.visible,true);assert.equal(state.setupHelp.visible,true);
 assert.equal(panels.every(p=>!p.visible),true);
});
