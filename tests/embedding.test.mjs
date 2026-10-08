import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

function fixture(request = async () => ({items:[]})) {
  let definition;
  const prompts=[];
  vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{sap:{m:{},ui:{define:(_,factory)=>{
    factory({extend:(_,value)=>{definition=value;}},{},{Action:{CANCEL:'Cancel'},warning:(_,options)=>prompts.push(options)},{},{},{},{request},{});
  }}}});
  const properties={embedded:true,environment:'OLD'};
  const events=[];
  const state=Object.assign({},definition,{
    _apiReady:true,dirty:false,notebook:{id:'saved',environment:'OLD'},
    getEmbedded:()=>properties.embedded,getEnvironment:()=>properties.environment,
    setProperty:(name,value)=>{properties[name]=value;},
    workspace:{setBusy(value){this.busy=value;}},
    list:{destroyItems(){},getItems:()=>[]},meta:{setText(value){this.text=value;}},
    clearNotebook(){this.dirty=false;this.notebook=null;},
    refresh(){this.refreshed=properties.environment;return Promise.resolve();},
    fireNavigateBack:event=>events.push(event),
    save(){this.dirty=false;return Promise.resolve();}
  });
  return {definition,state,properties,prompts,events};
}

test('component settings are accepted before content exists without metadata calls',()=>{
  const f=fixture(()=>{assert.fail('Constructor settings must not request metadata');});
  delete f.state.workspace;
  assert.equal(f.state.setEnvironment('SELECTED'),f.state);
  assert.equal(f.properties.environment,'SELECTED');
  assert.equal(f.definition.metadata.properties.embedded.defaultValue,false);
});

test('embedded constructor settings also update content created before settings are applied',()=>{
  const f=fixture();f.properties.embedded=false;
  f.state.standaloneHeader={setVisible(value){this.visible=value;}};
  f.state.rootContent={toggleStyleClass(name,value){this.compact=value;}};
  f.state.setEmbedded(true);
  assert.equal(f.state.standaloneHeader.visible,false);assert.equal(f.state.rootContent.compact,false);
  f.state.setEmbedded(false);
  assert.equal(f.state.standaloneHeader.visible,true);assert.equal(f.state.rootContent.compact,true);
});

test('Back fires only after save/discard approval; cancel and failed save preserve work',async()=>{
  const f=fixture();f.state.dirty=true;
  f.state.requestNavigateBack();assert.equal(f.events.length,0);
  f.prompts.pop().onClose('Cancel');assert.equal(f.state.dirty,true);
  f.state.save=()=>Promise.reject(new Error('Save failed'));
  f.state.requestNavigateBack();f.prompts.pop().onClose('Save');
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(f.events.length,0);assert.equal(f.state.notebook.id,'saved');
  f.state.requestNavigateBack();f.prompts.pop().onClose('Discard');
  assert.equal(f.events.length,1);assert.equal(f.events[0].environment,'OLD');assert.equal(f.state.dirty,false);
  const saved=fixture();saved.state.dirty=true;
  saved.state.requestNavigateBack();saved.prompts.pop().onClose('Save');
  await new Promise(resolve=>setImmediate(resolve));assert.equal(saved.events.length,1);
});

test('environment changes protect unsaved work and never rewrite its saved environment',async()=>{
  const f=fixture(async()=>({items:[{id:'NEW'}]}));f.state.dirty=true;
  const original=f.state.notebook;
  f.state.setEnvironment('NEW');assert.equal(f.properties.environment,'OLD');
  f.prompts.pop().onClose('Cancel');assert.equal(f.properties.environment,'OLD');
  f.state.setEnvironment('NEW');f.prompts.pop().onClose('Discard');
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(f.properties.environment,'NEW');assert.equal(f.state.refreshed,'NEW');
  assert.equal(original.environment,'OLD');assert.equal(f.state.notebook,null);
});

test('unauthorized/empty environments do not fall back; obsolete responses cannot repopulate the workspace',async()=>{
  const pending=[];const f=fixture(()=>new Promise(resolve=>pending.push(resolve)));
  const old=f.state._loadHostEnvironment('OLD');
  const current=f.state._loadHostEnvironment('CURRENT');
  pending[1]({items:[{id:'CURRENT'}]});await current;
  pending[0]({items:[{id:'OLD'}]});await old;
  assert.equal(f.state.hostEnvironmentValid,true);
  const bad=f.state._loadHostEnvironment('FORBIDDEN');pending[2]({items:[]});await bad;
  assert.equal(f.state.hostEnvironmentValid,false);
  assert.match(f.state.meta.text,/unavailable or unauthorized/);
  await f.state._loadHostEnvironment('');assert.equal(pending.length,3);
  assert.equal(f.state.workspace.busy,false);
});

test('embedded backend routing follows component deployment rather than hub pathname',async()=>{
  const requests=[];let api;
  vm.runInNewContext(readFileSync('webapp/model/Api.js','utf8'),{
    URL,URLSearchParams,window:{location:{href:'https://sap.example/hub/',search:'?sap-client=001',pathname:'/hub/'}},
    sap:{ui:{require:{toUrl:()=>'/sap/bc/ui5_ui5/sap/zbpc_notebook/Component.js'},define:(_,factory)=>{api=factory();}}},
    fetch:async(url,options)=>{requests.push({url,options});return {ok:true,json:async()=>[]};}
  });
  assert.equal(api.local,false);await api.request('/notebooks');
  assert.equal(requests[0].url,'/sap/bc/zbpc_notebook/notebooks?sap-client=001');
  assert.equal(requests[0].options.credentials,'same-origin');
});
