const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),api=require('./bpc-api.cjs');
const args=Object.fromEntries(process.argv.filter(x=>x.startsWith('--')&&x.includes('=')).map(x=>{const i=x.indexOf('=');return[x.slice(2,i),x.slice(i+1)];}));
function guard(expression,code,index){return `TRY.\n  ${expression}\n  RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST_EXPECTED' detail = 'Expected rejection'.\nCATCH zcx_bn INTO DATA(error_${index}).\n  IF error_${index}->code <> '${code}'. RAISE EXCEPTION error_${index}. ENDIF.\nENDTRY.\nio->message( 'Guard ${index}: ${code}' ).`;}
(async()=>{
 assert(args.notebook,'Supply --notebook=<existing notebook with CATEGORY/TIME selections>');
 const seed=await api('/notebook?id='+encodeURIComponent(args.notebook),null,'GET');
 const context={environment:seed.environment,model:seed.model};
 const dimensions=await api('/metadata',{kind:'dimensions',...context});
 const dimension=args.dimension||dimensions.items.find(x=>x.dimType==='U')?.id||dimensions.items[0].id;
 assert(dimensions.items.some(x=>x.id===dimension));
 const properties=await api('/metadata',{kind:'properties',...context,dimension});
 const fields=await api('/metadata',{kind:'fields',...context});
 assert(properties.items.some(x=>x.id==='ID'));assert(properties.items.some(x=>x.id==='EVDESCRIPTION'));
 assert(fields.items.some(x=>x.id==='SIGNEDDATA'));
 await assert.rejects(api('/metadata',{kind:'properties',...context,dimension:'UNKNOWN_DIMENSION'}),/BPC_DIMENSION/);
 await assert.rejects(api('/metadata',{kind:'fields',...context,model:'UNKNOWN_MODEL'}),/BPC_AUTH/);
 const category=seed.inputs.find(x=>x.name==='CATEGORY'),time=seed.inputs.find(x=>x.name==='TIME');
 assert(category?.selected?.length===1&&time?.selected?.length,'Seed must have CATEGORY and TIME selected');
 const dimLiteral=dimension.replace(/'/g,"''");
 const common="DATA(periods) = io->range( 'TIME' ).\nDATA(adapter) = io->bpc_model( ).\nDATA filters TYPE zcl_bn_bpc=>tt_filters.\nfilters = VALUE #( ( dimension = 'TIME' members = VALUE #( ( CONV string( periods[ 1 ] ) ) ) ) ).\n";
 const cells=[{id:'members',title:'Generic dimension members',dependencies:[],source:
 `DATA(adapter) = io->bpc_dimension( '${dimLiteral}' ).\nDATA(rows_ref) = adapter->member_data( ).\nFIELD-SYMBOLS <rows> TYPE STANDARD TABLE.\nASSIGN rows_ref->* TO <rows>.\nio->emit_table( name = 'MEMBERS' rows = <rows> ).\nDATA(props) = adapter->properties( ).\nio->emit_table( name = 'PROPERTIES' rows = props ).\nDATA(hierarchies) = adapter->hierarchies( ).\nLOOP AT hierarchies INTO DATA(hierarchy). io->message( hierarchy ). ENDLOOP.`},
 {id:'property',title:'Generic stored description',dependencies:[],source:
 "DATA(adapter) = io->bpc_dimension( 'CATEGORY' ).\nDATA(value) = adapter->property( member = CONV string( io->member( 'CATEGORY' ) ) name = 'EVDESCRIPTION' ).\nio->message( value )."},
 {id:'model',title:'Generic secured model read',dependencies:[],source:common+
 "DATA(rows_ref) = adapter->read_data( filters = filters ).\nFIELD-SYMBOLS <rows> TYPE STANDARD TABLE.\nASSIGN rows_ref->* TO <rows>.\nio->emit_table( name = 'MODEL' rows = <rows> ).\nDATA(fields) = adapter->fields( ).\nio->emit_table( name = 'FIELDS' rows = fields ).\nIF lines( <rows> ) > 1.\n"+
 guard("adapter->read_data( filters = filters max_rows = 1 ).",'BPC_READ_LIMIT',10)+"\nENDIF."},
 {id:'guards',title:'Fail-closed adapter validation',dependencies:[],source:[
 guard("io->bpc_dimension( 'UNKNOWN_DIMENSION' ).",'BPC_DIMENSION',1),
 guard("io->bpc_model( 'UNKNOWN_MODEL' ).",'BPC_AUTH',2),
 "DATA(adapter) = io->bpc_dimension( 'CATEGORY' ).",
 guard("adapter->member_data( VALUE #( ( `UNKNOWN_MEMBER` ) ) ).",'BPC_AUTH',3),
 guard("adapter->property( member = CONV string( io->member( 'CATEGORY' ) ) name = 'UNKNOWN_PROPERTY' ).",'BPC_PROPERTY',4),
 guard("adapter->property( member = CONV string( io->member( 'CATEGORY' ) ) name = 'VIRTUAL_PROPERTY' source = 'virtual' ).",'BPC_VIRTUAL_PROPERTY',5),
 "DATA(model_adapter) = io->bpc_model( ).",
 guard("model_adapter->read_data( filters = VALUE #( ( dimension = 'UNKNOWN_DIMENSION' members = VALUE #( ( `X` ) ) ) ) ).",'BPC_DIMENSION',6),
 guard("model_adapter->read_data( filters = VALUE #( ( dimension = 'TIME' ) ) ).",'BPC_FILTER',7),
 guard("model_adapter->read_data( filters = VALUE #( ( dimension = 'CATEGORY' members = VALUE #( ( `UNKNOWN_MEMBER` ) ) ) ) ).",'BPC_AUTH',8),
 guard("model_adapter->read_data( max_rows = 0 ).",'BPC_READ',9),
 guard("model_adapter->read_data( filters = VALUE #( ( dimension = 'CATEGORY' members = VALUE #( ( CONV string( io->member( 'CATEGORY' ) ) ) ( `UNKNOWN_MEMBER` ) ) ) ) ).",'BPC_AUTH',11)
 ].join('\n')}];
 if(time.selected.some(id=>!time.resolved.includes(id))){
  cells.find(x=>x.id==='guards').source+='\n'+guard("DATA(selected_time) = io->selection( 'TIME' ).\nmodel_adapter->read_data( filters = VALUE #( ( dimension = 'TIME' members = VALUE #( ( selected_time[ 1 ] ) ) ) ) ).",'BPC_BASE_FILTER',12);
 }
 const notebook=await api('/notebooks' ,{title:'Generic BPC adapters - read-only verification',...context,inputs:[category,time],cells});
 for(const cell of cells){const validation=await api('/validate',{notebookId:notebook.id,cellId:cell.id});assert.equal(validation.supported,true,JSON.stringify(validation));}
 let component;
 vm.runInNewContext(fs.readFileSync('webapp/Component.js','utf8'),{sap:{m:{},ui:{define:(deps,factory)=>{
   component=factory({extend:(name,definition)=>definition},null,null,null,null);
 }}}});
 const memberList=await api('/metadata',{kind:'members',...context,dimension});
 const baseMember=memberList.items.find(x=>!x.isNode); assert(baseMember,'Dimension requires a base member for generated filter example');
 const chosen={model:context.model,dimension,property:'EVDESCRIPTION',member:baseMember.id,field:'SIGNEDDATA'};
 const snippets=['members','properties','hierarchies','property','model','filter','field'].map((action,index)=>({
   id:'snippet'+index,title:'Generated '+action,dependencies:[],source:component.bpcSnippet({source:''},chosen,action)
 }));
 const helperNotebook=await api('/notebooks',{title:'BPC authoring helpers - compilation verification',...context,inputs:[category,time],cells:snippets});
 for(const cell of snippets){const validation=await api('/validate',{notebookId:helperNotebook.id,cellId:cell.id});assert.equal(validation.supported,true,JSON.stringify({action:cell.title,validation}));}
 const submitted=await api('/runs' ,{notebookId:notebook.id,expectedRevision:notebook.revision,scope:'all',idempotencyKey:crypto.randomUUID()});
 let run;
 for(let i=0;i<90;i++){run=await api('/run?id='+submitted.id,null,'GET');if(['succeeded','failed','cancelled'].includes(run.state))break;await new Promise(r=>setTimeout(r,1000));}
 assert.equal(run.state,'succeeded',JSON.stringify(run.error));
 assert.deepEqual(run.snapshot.inputs.find(x=>x.name==='TIME').resolved,notebook.inputs.find(x=>x.name==='TIME').resolved);
 assert.deepEqual(run.snapshot.inputs.find(x=>x.name==='TIME').selected,notebook.inputs.find(x=>x.name==='TIME').selected);
 const summaries=[];
 for(const [cell,table] of [['members','MEMBERS'],['members','PROPERTIES'],['model','MODEL'],['model','FIELDS']]){
  const output=await api('/output?runId='+run.id+'&cellId='+cell+'&revision=1&offset=0&limit=2&table='+table,null,'GET');
  assert(output.rows.length<=2);assert(output.total<=5000);assert(output.schema.length>0);
  if(table==='MODEL'){assert.equal(output.schema.length,fields.items.length);assert(output.schema.some(x=>x.name.toUpperCase()==='SIGNEDDATA'));}
  summaries.push({cell,table,columns:output.schema.map(x=>x.name),previewRows:output.rows.length,storedRows:output.total,sourceRows:output.sourceTotal,truncated:output.truncated});
 }
 const evidence={at:new Date().toISOString(),passed:true,notebookId:notebook.id,runId:run.id,helperNotebookId:helperNotebook.id,generatedSnippets:snippets.map(x=>x.title),...context,dimension,
  properties:properties.items.map(x=>x.id),fields:fields.items.map(x=>x.id),resolvedPeriods:notebook.inputs.find(x=>x.name==='TIME').resolved,
  checks:['native compilation','authorized generic dimension and model reads','stored properties and hierarchy names','unknown context/member/property rejected',
   'virtual property rejected without provider','empty and invalid model filters rejected','explicit read limit checked when data exceeds one row','bounded named-table preview'],outputs:summaries};
 fs.writeFileSync('docs/evidence/generic-bpc.json',JSON.stringify(evidence,null,2)+'\n','utf8');
 console.log(JSON.stringify({passed:true,notebookId:notebook.id,runId:run.id,outputs:summaries.map(x=>({table:x.table,sourceRows:x.sourceRows,columns:x.columns.length}))}));
})().catch(e=>{console.error(e.message);process.exitCode=1});
