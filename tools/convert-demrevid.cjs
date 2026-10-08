// Save the supported conversion slice and preserve unsupported source without claiming equivalence.
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const assert = require('node:assert/strict'), crypto = require('node:crypto');
const api = require('./bpc-api.cjs');
let Script;
vm.runInNewContext(fs.readFileSync('webapp/model/Script.js', 'utf8'), {
  sap: { ui: { define: (_, factory) => Script = factory() } }, TextEncoder, TextDecoder, btoa, atob
});
const options = Object.fromEntries(process.argv.filter(a => /^--[^=]+=/.test(a)).map(a => {
  const i = a.indexOf('='); return [a.slice(2, i), a.slice(i + 1)];
}));
const root = options.chorus || 'C:/Users/FelipeTomazzi/chorus-workspace/chorus_bpc';
const out = 'examples/demrevid-conversion';
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const original = read('src/zbpc_demrevid/zcl_bpc_demrevid_calc_003.clas.abap');
const stepBody = original.match(/method get_steps\.([\s\S]*?)endmethod\./i)[1];
const steps = [...stepBody.matchAll(/id = '([^']+)' label = '([^']+)' method_name = '([^']+)'/g)]
  .map((m, i) => ({ id: m[1], title: m[2], method: m[3], order: i + 1,
    status: 'retained-abap-not-ported', prerequisites: i ? [stepsPlaceholder(i)] : [] }));
function stepsPlaceholder(i) { return [...stepBody.matchAll(/id = '([^']+)'/g)][i - 1][1]; }
const cells = [
  { id: 'context', title: 'Frozen allocation selections and flags', dependencies: [], script:
`let periods = range("TIME")
let categoryId = member("CATEGORY")
table summary
append summary key = "PERIOD_COUNT" amount = count(periods)
emit summary
show summary as "CONTEXT_COUNTS"
message concat("CATEGORY ", categoryId)
message concat("Network Services suppression ", input("FFLASMATGROUPS"))
message "Read-stage conversion only; no allocation or writeback"` },
  ...['MATCONN', 'PRODUCT_TYPE', 'MAT_GROUP_ID'].map(name => ({ id: name.toLowerCase(),
    title: name + ' stored dimension members', dependencies: ['context'], script:
`dimension dim = DEMREVID-${name}
members rows = dim
show rows as "${name}_STORED_MEMBERS"
message text(count(rows))` })),
  { id: 'selected_facts', title: 'Generic DEMREVID read for frozen periods', dependencies: ['context'], script:
`model allocation = DEMREVID
data facts = allocation where TIME = range("TIME") and CATEGORY = selection("CATEGORY") limit 100000
show facts as "SELECTED_PERIOD_FACTS"
let total = 0
for row in facts
  total = total + number(row.SIGNEDDATA)
end
table summary
append summary key = "RAW_ROW_COUNT" amount = count(facts)
append summary key = "RAW_SIGNEDDATA_TOTAL" amount = total
emit summary
show summary as "READ_COUNTS"
message "Raw facts: TIME_NA and outside-scope lookback reads are not included"` },
  { id: 'conversion_status', title: 'Remaining calculation steps and conversion boundary',
    dependencies: ['selected_facts', 'matconn', 'product_type', 'mat_group_id'], abap:
`TYPES: BEGIN OF ty_step,
         step_id TYPE string, method_name TYPE string, status TYPE string,
       END OF ty_step.
DATA steps TYPE STANDARD TABLE OF ty_step WITH DEFAULT KEY.
${steps.map(s => `APPEND VALUE #( step_id = '${s.id}' method_name = '${s.method}' status = 'RETAINED_ABAP_NOT_PORTED' ) TO steps.`).join('\n')}
io->emit_table( name = 'CONVERSION_STATUS' rows = steps ).
DATA(counts) = io->read( 'selected_facts' ).
io->emit( counts ).
io->message( 'No allocation output: grouped transformations and lookback contract still require conversion' ).` }
];
async function main() {
  assert(options.notebook, 'Supply --notebook=<existing selected CATEGORY/TIME notebook>');
  const seed = await api('/notebook?id=' + encodeURIComponent(options.notebook), null, 'GET');
  assert.equal(seed.environment, 'CH_PLANNING'); assert.equal(seed.model, 'DEMREVID');
  const inputs = seed.inputs.filter(p => ['CATEGORY', 'TIME'].includes(p.name));
  assert.equal(inputs.find(p => p.name === 'CATEGORY')?.selected?.length, 1);
  assert(inputs.find(p => p.name === 'TIME')?.resolved?.length, 'Frozen periods required');
  inputs.push({ name: 'FFLASMATGROUPS', type: 'boolean', value: true },
    { name: 'FFLASMATGROUPSID', type: 'string', value: 'MATGROUPID038' },
    { name: 'DEBUG', type: 'string', value: 'OFF' },
    { name: 'HSNS_REALLOC_LOCATIONS', type: 'string', value: '' });
  fs.mkdirSync(out + '/retained-abap', { recursive: true });
  const sourceFiles = ['src/zbpc_demrevid/zcl_bpc_demrevid_calc_003.clas.abap',
    'src/zbpc_demrevid/zcl_bpc_demrevid.clas.abap', 'src/zcl_bpc_model.clas.abap',
    'src/zbpc_dimensions/zcl_bpc_dim_matconn.clas.abap',
    'src/zbpc_dimensions/zcl_bpc_dim_product_type.clas.abap',
    'src/zbpc_dimensions/zcl_bpc_dim_mat_group_id.clas.abap'];
  const sources = sourceFiles.map(file => {
    const text = read(file); fs.writeFileSync(out + '/retained-abap/' + path.basename(file), text);
    return { file, sha256: crypto.createHash('sha256').update(text).digest('hex') };
  });
  const definition = { title: 'DEMREVID 003 - generic conversion draft (reads only)',
    environment: seed.environment, model: seed.model, inputs,
    cells: cells.map(c => ({ id: c.id, title: c.title, dependencies: c.dependencies,
      source: c.script ? Script.compile(c.script) : c.abap })) };
  for (const c of cells) fs.writeFileSync(out + '/' + c.id + (c.script ? '.bns' : '.abap'), c.script || c.abap);
  fs.writeFileSync(out + '/definition.json', JSON.stringify(definition, null, 2) + '\n');
  fs.writeFileSync(out + '/inventory.json', JSON.stringify({ steps, sources,
    scriptReference: '5ba07f031060ab90dc8f5ba521880f246874a120',
    businessEquivalent: false, writes: false, handlerBound: false }, null, 2) + '\n');
  const saved = await api('/notebooks', definition);
  const evidence = { at: new Date().toISOString(), notebookId: saved.id, revision: saved.revision,
    environment: seed.environment, model: seed.model, inputs, validations: [],
    businessEquivalent: false, limitations: ['TIME_NA reference data omitted by frozen adapter scope',
      'Prior-period reads require a separate explicit authorized read scope',
      'Grouped allocation, keyed lookup, hierarchy traversal and rounding steps retained, not ported',
      'No full-table dependency handoff', 'No writeback or NOTEBOOK handler binding'] };
  for (const c of definition.cells) {
    const validation = await api('/validate', { notebookId: saved.id, cellId: c.id });
    assert.equal(validation.supported, true, JSON.stringify(validation));
    evidence.validations.push({ cellId: c.id, ...validation });
  }
  const reopened = await api('/notebook?id=' + saved.id, null, 'GET');
  cells.filter(c => c.script).forEach(c => assert.equal(Script.unpack(reopened.cells.find(s => s.id === c.id).source).text, c.script));
  const submitted = await api('/runs', { notebookId: saved.id, expectedRevision: saved.revision,
    scope: 'all', idempotencyKey: crypto.randomUUID() });
  let run;
  for (let i = 0; i < 90; i++) {
    run = await api('/run?id=' + submitted.id, null, 'GET');
    if (['succeeded', 'failed', 'cancelled'].includes(run.state)) break;
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  evidence.run = { id: run.id, state: run.state, error: run.error, results: run.results };
  if (run.state === 'succeeded') {
    evidence.outputSchemas = [];
    for (const c of cells) {
      const page = await api('/output?runId=' + run.id + '&cellId=' + c.id + '&revision=1&offset=0&limit=1', null, 'GET');
      evidence.outputSchemas.push({ cellId: c.id, tables: page.tables, schema: page.schema,
        sourceTotal: page.sourceTotal, total: page.total });
    }
    const counts = await api('/output?runId=' + run.id + '&cellId=selected_facts&revision=1&offset=0&limit=10&table=READ_COUNTS', null, 'GET');
    evidence.rawRowCount = counts.rows.find(r => r.values[0] === 'RAW_ROW_COUNT')?.values[1];
    assert.deepEqual(run.snapshot.inputs.find(p => p.name === 'TIME').resolved,
      reopened.inputs.find(p => p.name === 'TIME').resolved);
  }
  evidence.passed = run.state === 'succeeded';
  fs.writeFileSync('docs/evidence/demrevid-conversion.json', JSON.stringify(evidence, null, 2) + '\n');
  console.log(JSON.stringify({ notebookId: saved.id, runId: run.id, state: run.state,
    validationCount: evidence.validations.length, rawRowCount: evidence.rawRowCount, error: run.error }));
  assert.equal(run.state, 'succeeded', 'Conversion read-stage run failed');
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
