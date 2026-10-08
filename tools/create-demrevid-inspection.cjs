// Create an inspection notebook only; --run submits calculation previews, never BPC writeback.
const fs = require('node:fs');
const api = require('./bpc-api.cjs');
const args = Object.fromEntries(process.argv.filter(x => x.startsWith('--') && x.includes('='))
  .map(x => { const i = x.indexOf('='); return [x.slice(2, i), x.slice(i + 1)]; }));
(async () => {
  const context = { environment: 'CH_PLANNING', model: 'DEMREVID' };
  const metadata = await api('/metadata', { kind: 'members', ...context, dimension: 'TIME', hierarchy: '', search: args.time || '' });
  const hierarchy = args.hierarchy || metadata.hierarchies?.[0];
  if (!hierarchy) throw Error('Select an actual TIME hierarchy using --hierarchy=<metadata ID>');
  const definition = {
    title: 'DEMREVID 003 - allocation inspection', ...context,
    inputs: [
      { name: 'CATEGORY', type: 'member', dimension: 'CATEGORY', required: true, selected: args.category ? [args.category] : [] },
      { name: 'TIME', type: 'range', dimension: 'TIME', hierarchy, required: true, selected: args.time ? [args.time] : [] },
      { name: 'FFLASMATGROUPS', type: 'boolean', value: true },
      { name: 'FFLASMATGROUPSID', type: 'string', value: 'MATGROUPID038' },
      { name: 'STOP_AFTER', type: 'string', value: args.step || 'FFLAS_RATIOS_BY_MATERIAL' },
      { name: 'ROW_LIMIT', type: 'number', value: 200 }
    ],
    cells: [
      { id: 'steps', title: 'Available allocation steps', dependencies: [], source:
        "DATA steps TYPE zcl_bpc_demrevid_calc_003=>step_list.\nsteps = zcl_bpc_demrevid_calc_003=>get_steps( ).\nio->emit_table( name = 'STEPS' rows = steps )." },
      { id: 'inspect', title: 'Inspect allocation through selected step', dependencies: ['steps'], source:
        "zcl_bpc_demrevid_notebook=>execute(\n  io = io\n  stop_after = io->input( 'STOP_AFTER' )\n  row_limit = CONV i( io->input( 'ROW_LIMIT' ) ) )." }
    ]
  };
  const notebook = await api('/notebooks', definition);
  console.log(JSON.stringify({ notebookId: notebook.id, revision: notebook.revision, hierarchy }));
  if (!process.argv.includes('--run')) return;
  const run = await api('/runs', { notebookId: notebook.id, expectedRevision: notebook.revision,
    scope: 'all', idempotencyKey: crypto.randomUUID() });
  let finished;
  for (let i = 0; i < 45; i++) {
    finished = await api('/run?id=' + run.id, null, 'GET');
    if (['succeeded', 'failed', 'cancelled'].includes(finished.state)) break;
    await new Promise(r => setTimeout(r, 1000));
  }
  const evidence = { at: new Date().toISOString(), notebookId: notebook.id, run: finished };
  if (finished.state === 'succeeded') {
    const page = await api('/output?runId=' + run.id + '&cellId=inspect&revision=1&offset=0&limit=2', null, 'GET');
    evidence.output = page;
    const flags = page.tables.find(t => t.name === 'FFLAS_RATIOS_BY_MATERIAL/SKIPPED_MATERIAL_FLAGS');
    if (flags) evidence.flags = await api('/output?runId=' + run.id + '&cellId=inspect&revision=1&offset=0&limit=2&table=' + encodeURIComponent(flags.name), null, 'GET');
  }
  fs.mkdirSync('docs/evidence', { recursive: true });
  fs.writeFileSync('docs/evidence/demrevid-inspection.json', JSON.stringify(evidence, null, 2) + '\n');
  console.log(JSON.stringify({ runId: run.id, state: finished.state, error: finished.error,
    tables: evidence.output?.tables?.length, flagRows: evidence.flags?.sourceTotal }));
  if (finished.state !== 'succeeded') process.exitCode = 1;
})().catch(e => { console.error(e.message); process.exitCode = 1; });
