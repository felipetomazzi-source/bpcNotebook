const assert = require('node:assert/strict'), fs = require('node:fs'), api = require('./bpc-api.cjs');
(async () => {
  const notebook = await api('/notebooks', { title: 'DEMREVID output display test (synthetic)', inputs: [], cells: [
    { id: 'preview', title: 'Dimension columns and exact decimal preview', dependencies: [], source:
      "DATA rows TYPE zcl_bpc_demrevid=>tabl.\n" +
      "APPEND VALUE #( account = '001081800' category = 'Actual' time = '2025.007' matconn = 'M_TEST' demrevid_kfs = 'DEMREVID052' fflas = 'FFLAS_NA' signeddata = 1 ) TO rows.\n" +
      "io->emit_table( name = 'FLAGS' rows = rows total_count = 10 ).\n" +
      "io->emit_table( name = 'EMPTY' rows = VALUE zcl_bpc_demrevid=>tabl( ) )." }
  ] });
  const run = await api('/runs', { notebookId: notebook.id, expectedRevision: notebook.revision,
    scope: 'all', idempotencyKey: crypto.randomUUID() });
  let finished;
  for (let i = 0; i < 25; i++) {
    finished = await api('/run?id=' + run.id, null, 'GET');
    if (['succeeded', 'failed', 'cancelled'].includes(finished.state)) break;
    await new Promise(r => setTimeout(r, 1000));
  }
  assert.equal(finished.state, 'succeeded', JSON.stringify(finished.error));
  const route = '/output?runId=' + run.id + '&cellId=preview&revision=1&offset=0&limit=2';
  const page = await api(route, null, 'GET');
  assert.equal(page.tables.length, 2); assert.equal(page.schema.length, 21);
  assert.equal(page.sourceTotal, 10); assert.equal(page.total, 1); assert.equal(page.truncated, true);
  assert.equal(page.rows[0].values[page.schema.findIndex(c => c.name === 'account')], '001081800');
  assert.equal(page.rows[0].values[page.schema.findIndex(c => c.name === 'demrevid_kfs')], 'DEMREVID052');
  const empty = await api(route + '&table=EMPTY', null, 'GET');
  assert.equal(empty.schema.length, 21); assert.equal(empty.rows.length, 0);
  await assert.rejects(api(route + '&table=UNKNOWN', null, 'GET'), /TABLE_NAME/);
  fs.writeFileSync('docs/evidence/named-tables.json', JSON.stringify({ at: new Date().toISOString(), passed: true,
    synthetic: true, notebookId: notebook.id, runId: run.id, page, empty,
    checks: ['background execution', '21 dimension columns', 'member leading zeros', 'named selection',
      'empty table schema', 'bounded preview totals', 'unknown table rejected'] }, null, 2) + '\n');
  console.log(JSON.stringify({ notebookId: notebook.id, runId: run.id, passed: true, columns: page.schema.length }));
})().catch(e => { console.error(e.message); process.exitCode = 1; });
