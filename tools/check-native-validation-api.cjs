// Connected DEV integration check. All temporary notebooks are removed in finally.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const api = require('./bpc-api.cjs');
const created = [];
async function run(n, scope = 'all', cellId) {
  let r = await api('/runs', {notebookId:n.id, expectedRevision:n.revision,
    scope, cellId, idempotencyKey:crypto.randomUUID()});
  for (let i=0; i<120; i++) {
    r = await api('/run?id='+r.id, null, 'GET');
    if (['succeeded','failed','cancelled'].includes(r.state)) return r;
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  await api('/cancel', {id:r.id});
  throw Error('Validation run did not finish within two minutes');
}
async function create(definition) {
  const n = await api('/notebooks', definition); created.push(n.id); return n;
}
async function output(r, cell, table) {
  return api('/output?runId='+r.id+'&cellId='+cell+'&revision=1&offset=0&limit=100&table='+encodeURIComponent(table), null, 'GET');
}
(async () => {
  const comparison = await create({title:'Temporary native comparison verification', inputs:[], cells:[{
    id:'compare', title:'Exact full-key comparison', dependencies:[], source:[
      'TYPES: BEGIN OF ty_row, account TYPE uj_dim_member, time TYPE uj_dim_member, signeddata TYPE uj_sdata, END OF ty_row.',
      'DATA original TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.',
      'DATA converted LIKE original.',
      "original = VALUE #( ( account = 'A' time = 'P1' signeddata = '1.0000001' ) ( account = 'B' time = 'P1' signeddata = '2' ) ).",
      "converted = VALUE #( ( account = 'A' time = 'P1' signeddata = '1.0000002' ) ( account = 'C' time = 'P1' signeddata = '3' ) ).",
      "DATA(summary) = io->compare_results( name = 'CHECK' original = original notebook = converted preview_rows = 1 )."
    ].join('\n')}]});
  const compared = await run(comparison); assert.equal(compared.state,'succeeded',JSON.stringify(compared.error));
  const differences = await output(compared,'compare','CHECK/DIFFERENCES');
  assert.equal(differences.total,1); assert.equal(differences.sourceTotal,3); assert.equal(differences.truncated,true);
  const summary = await output(compared,'compare','CHECK/SUMMARY');
  for (const field of ['ADDED','MISSING','CHANGED']) {
    const position = summary.schema.findIndex(c=>c.name.toUpperCase()===field);
    assert.equal(Number(summary.rows[0].values[position]),1);
  }
  const fixture = await create({title:'Temporary native fixture verification', environment:'CH_PLANNING', model:'DEMREVID', inputs:[], cells:[{
    id:'fixture', title:'Private inputs only', dependencies:[], source:[
      "DATA(seed) = NEW zcl_bn_bpc( environment = 'CH_PLANNING' model = 'DEMREVID' ).",
      "DATA(ref) = seed->read_data( filters = VALUE #( ( dimension = 'CATEGORY' members = VALUE #( ( `Actual` ) ) )",
      "  ( dimension = 'TIME' members = VALUE #( ( `2027.006` ) ) ) ) max_rows = 100000 ).",
      'FIELD-SYMBOLS <seed> TYPE STANDARD TABLE. ASSIGN ref->* TO <seed>. DELETE <seed> FROM 4.',
      'ASSERT lines( <seed> ) = 3.',
      "io->enable_fixtures( VALUE #( ( environment = 'CH_PLANNING' model = 'DEMREVID' rows = ref ) ) ).",
      'DATA(adapter) = io->bpc_model( ). DATA(first) = adapter->read_data( ). DATA(second) = adapter->read_data( ).',
      'FIELD-SYMBOLS <first> TYPE STANDARD TABLE. FIELD-SYMBOLS <second> TYPE STANDARD TABLE.',
      'ASSIGN first->* TO <first>. ASSIGN second->* TO <second>.',
      "DATA(summary) = io->compare_results( name = 'IDENTICAL' original = <first> notebook = <second> )."
    ].join('\n')}]});
  const tested = await run(fixture); assert.equal(tested.state,'succeeded',JSON.stringify(tested.error));
  assert.equal(tested.fixtureMode,true);
  const diagnostics = await output(tested,'fixture','READ_1/SUMMARY');
  const value = name => diagnostics.rows[0].values[diagnostics.schema.findIndex(c=>c.name.toUpperCase()===name)];
  assert.equal(value('SOURCE'),'fixture'); assert.equal(value('SECURITY'),'MEMBER_AUTH_ON; NO_QUERY');
  assert.equal(Number(value('ROW_COUNT')),3);
  await assert.rejects(api('/retry',{id:tested.id,idempotencyKey:crypto.randomUUID()}),/DATA_SNAPSHOT/);
  const expanded = await api('/notebook', {...fixture, expectedRevision:fixture.revision,
    cells:[...fixture.cells,{id:'consumer',title:'Must not consume fixture output',dependencies:['fixture'],source:"DATA(rows) = io->read( 'fixture' ). io->emit( rows )."}]}, 'PUT');
  await assert.rejects(run(expanded,'one','consumer'),/DEPEND|STALE|MISSING/);
  const blocked = await run(expanded); assert.equal(blocked.state,'failed'); assert.equal(blocked.error.code,'FIXTURE_MODE');
  assert.equal(blocked.fixtureMode,true);
  fs.mkdirSync('.local',{recursive:true});
  const evidence = {checkedAt:new Date().toISOString(),passed:true,businessFactsWritten:false,
    checks:['Background comparison persists full counts and bounded exact differences',
      'Background fixture diagnostics persist source, authorization mode and complete count',
      'Fixture runs reject historical retry and ordinary dependency reuse',
      'Multi-cell fixture execution fails before publishing a completed fixture dataset']};
  fs.writeFileSync('.local/native-validation-api.json',JSON.stringify(evidence,null,2)+'\n','utf8');
  console.log(JSON.stringify(evidence));
})().catch(e=>{console.error(e.message);process.exitCode=1;}).finally(async()=>{
  for (const id of created) {
    const n = await api('/notebook?id='+id,null,'GET');
    await api('/delete-notebook',{notebookId:id,expectedRevision:n.revision});
  }
  console.log('Removed temporary validation notebooks');
});
