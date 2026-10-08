const assert=require('node:assert/strict'),api=require('./bpc-api.cjs');
module.exports=async function(n){
 const c=require('./adt-config.cjs')();await c.login();c.stateful='stateful';
 try{
  let previous;try{previous=await api('/logic-handler?id=BN_DELETE_VERIFY',null,'GET');}catch(e){if(!e.message.includes('NOT_FOUND'))throw e;}
  await api('/logic-handler',{handler:'BN_DELETE_VERIFY',notebookId:n.id,expectedRevision:n.revision,handlerRevision:previous?.revision||0});
  const name='ZCL_BN_DELETE_CHECK',url='/sap/bc/adt/oo/classes/zcl_bn_delete_check';
  const source=[
   'CLASS zcl_bn_delete_check DEFINITION PUBLIC FINAL CREATE PUBLIC.',
   ' PUBLIC SECTION. INTERFACES if_oo_adt_classrun.',
   'ENDCLASS.',
   'CLASS zcl_bn_delete_check IMPLEMENTATION.',
   ' METHOD if_oo_adt_classrun~main.',
   '  TRY.',
   '   DATA run TYPE zcl_bn_types=>ty_run.',
   "   run-id = zcl_bn_types=>uuid( ). run-notebook_id = '"+n.id+"'. run-owner = sy-uname.",
   "   run-state = 'queued'. run-snapshot = zcl_bn_service=>get_notebook( run-notebook_id ).",
   '   run-created_at = zcl_bn_types=>timestamp( ). GET TIME STAMP FIELD run-deadline.',
   '   run-deadline = cl_abap_tstmp=>add( tstmp = run-deadline secs = 600 ).',
   "   zcl_bn_store=>write( kind = 'R' id = run-id payload = zcl_bn_types=>json( run ) expected = 0 ).",
   '   COMMIT WORK AND WAIT.',
   '   TRY.',
   "     zcl_bn_service=>dispatch( path = '/delete-notebook' method = 'POST'",
   '       body = \'{"notebookId":"'+n.id+'","expectedRevision":'+n.revision+'}\' ).',
   "     RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST_FAILED' detail = 'Active execution was not blocked'.",
   '    CATCH zcx_bn INTO DATA(fault).',
   "     ASSERT fault->code = 'NOTEBOOK_BUSY'.",
   '   ENDTRY.',
   '   ROLLBACK WORK.',
   "   run-state = 'cancelled'. run-finished_at = zcl_bn_types=>timestamp( ).",
   "   zcl_bn_store=>write( kind = 'R' id = run-id payload = zcl_bn_types=>json( run ) expected = 1 ).",
   '   COMMIT WORK AND WAIT.',
   "   out->write( 'BNCHECK|active execution blocks deletion; synthetic run cancelled' ).",
   "   zcl_bn_service=>dispatch( path = '/delete-notebook' method = 'POST'",
   '     body = \'{"notebookId":"'+n.id+'","expectedRevision":'+n.revision+'}\' ).',
   '   COMMIT WORK AND WAIT.',
   '   TRY.',
   "     zcl_bn_logic=>invoke( name = 'BN_DELETE_VERIFY' environment = 'CH_PLANNING' model = 'DEMREVID'",
   "       parameters = VALUE #( ( hashkey = 'WRITE' hashvalue = 'OFF' ) ) scope = VALUE #( ) ).",
   "     RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TEST_FAILED' detail = 'Deleted handler notebook ran'.",
   '    CATCH zcx_bn INTO fault.',
   "     ASSERT fault->code = 'NOTEBOOK_DELETED'.",
   '   ENDTRY.',
   "   ROLLBACK WORK. out->write( 'BNCHECK|deleted notebook blocks bound handler' ).",
   '  CATCH cx_root INTO DATA(error).',
   "   ROLLBACK WORK. out->write( 'BNERROR|' && error->get_text( ) ).",
   '  ENDTRY.',
   ' ENDMETHOD.',
   'ENDCLASS.'
  ].join('\n');
  if(!(await c.searchObject(name,'',10)).some(o=>o['adtcore:name']===name))await c.createObject('CLAS/OC',name,'$TMP','Notebook deletion verification','/sap/bc/adt/packages/%24tmp');
  const {LOCK_HANDLE}=await c.lock(url);try{await c.setObjectSource(url+'/source/main',source,LOCK_HANDLE);}finally{await c.unLock(url,LOCK_HANDLE);}
  const activation=await c.activate(name,url);assert(activation.success,JSON.stringify(activation));
  const output=await c.runClass(name);console.log(output);assert(!output.includes('BNERROR|'),output);
 }finally{await c.logout();}
};
