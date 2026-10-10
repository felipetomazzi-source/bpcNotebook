import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
test('preview displays clipping warnings while preserving exact decimal strings and empty schemas',async()=>{
 class Control {constructor(o={}){this.options=o;this.items=[];}setText(v){this.text=v;return this;}setVisible(v){this.visible=v;}removeAllItems(){this.items=[];}addItem(v){this.items.push(v);}setSelectedKey(v){this.key=v;}destroyColumns(){}addColumn(){}setFirstVisibleRow(){}}
 let definition;
 const page={total:1,offset:0,limit:100,revision:1,sourceTotal:200,tableName:'DATASET/FULL',truncated:true,
  valuesTruncated:true,truncatedValues:2,byteLimitReached:true,
  schema:[{name:'SIGNEDDATA',type:'decimal'},{name:'rows_packet',type:'string'}],
  rows:[{values:['-12345678901234.1234567','É · São…']}],
  tables:[{name:'DATASET/FULL',totalCount:200,valuesTruncated:true,byteLimitReached:true}]};
 const Api={local:true,request:async()=>page};
 vm.runInNewContext(readFileSync('webapp/Component.js','utf8'),{sap:{m:{Label:Control,Text:Control},ui:{core:{Item:Control},define:(_,f)=>f(
  {extend:(_,d)=>{definition=d;}},{},{},{},Control,{},Api,{},{},Control,Control)}}});
 const properties={};
 const state={outputSelect:{getSelectedKey:()=> 'cell'},runId:'run',pageOffset:0,previewPageSize:100,
  datasetInfo:new Control(),previewModel:{setProperty:(k,v)=>{properties[k]=v;}},table:new Control(),datasetSelect:new Control(),pageLabel:new Control(),error:e=>{throw e;}};
 definition.preview.call(state);await new Promise(r=>setImmediate(r));
 assert.match(state.pageLabel.text,/2 long values shortened for preview/);
 assert.match(state.pageLabel.text,/preview size limit reached/);
 assert.match(state.datasetSelect.items[0].options.text,/shortened preview/);
 assert.equal(properties['/rows'][0].c0,'-12345678901234.1234567');
 assert.equal(properties['/rows'][0].c1,'É · São…');
 page.total=0;page.rows=[];page.valuesTruncated=false;page.truncatedValues=0;
 definition.preview.call(state);await new Promise(r=>setImmediate(r));
 assert.match(state.pageLabel.text,/0 rows/);assert.match(state.pageLabel.text,/preview size limit reached/);
 assert.equal(properties['/rows'].length,0);assert.equal(page.schema.length,2);
});
