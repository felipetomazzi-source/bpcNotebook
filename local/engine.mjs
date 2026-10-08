import { createHash, randomUUID } from 'node:crypto';
import { readFileSync, writeFileSync, renameSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

export const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
export class Fault extends Error {
  constructor(status, code, message) { super(message); Object.assign(this, {status, code}); }
}
const fail = (status, code, message) => { throw new Fault(status, code, message); };
const copy = value => structuredClone(value);
const now = () => new Date().toISOString();
export const demo = () => ({title: 'Allocation · operating expenses', inputs: [
  {name: 'total', type: 'number', value: 120000}, {name: 'factor', type: 'number', value: 1.1}
], cells: [
  {id: 'seed', title: '01 · Prepare cost centres', dependencies: [], source:
`DATA rows TYPE zcl_bn_context=>tt_rows.
DATA total TYPE decfloat34.
total = io->input( 'total' ).
APPEND VALUE #( key = 'CC100' amount = total * '0.5' ) TO rows.
APPEND VALUE #( key = 'CC200' amount = total * '0.3' ) TO rows.
APPEND VALUE #( key = 'CC300' amount = total * '0.2' ) TO rows.
io->emit( rows ).
io->message( 'Prepared three cost centres' ).`},
  {id: 'allocate', title: '02 · Apply planning factor', dependencies: ['seed'], source:
`DATA rows TYPE zcl_bn_context=>tt_rows.
DATA factor TYPE decfloat34.
rows = io->read( 'seed' ).
factor = io->input( 'factor' ).
LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
  <row>-amount = <row>-amount * factor.
ENDLOOP.
io->emit( rows ).
io->message( 'Planning factor applied' ).`}
]});

export class Engine {
  constructor({file, auto = true, delay = 30} = {}) {
    this.file = file; this.auto = auto; this.delay = delay; this.tasks = new Set();
    this.db = {notebooks: {}, runs: {}, outputs: {}, keys: {}, audit: []};
    if (file) {
      try { this.db = JSON.parse(readFileSync(file, 'utf8')); }
      catch (e) { if (e.code !== 'ENOENT') throw e; }
      // A process restart cannot silently replay a calculation.
      for (const run of Object.values(this.db.runs)) {
        if (['queued', 'running'].includes(run.state)) {
          run.state = 'failed'; run.error = {code: 'WORKER_LOST', message: 'Worker restarted; explicit retry required'};
          run.finishedAt = now();
        }
      }
      this.persist();
    }
  }
  persist() {
    if (!this.file) return;
    mkdirSync(dirname(this.file), {recursive: true});
    writeFileSync(this.file + '.tmp', JSON.stringify(this.db)); renameSync(this.file + '.tmp', this.file);
  }
  audit(user, action, id) { this.db.audit.push({user, action, id, at: now()}); }
  owned(collection, id, user, includeDeleted = false) {
    const item = this.db[collection][id];
    if (!item || item.owner !== user) fail(404, 'NOT_FOUND', 'Resource not found');
    if (collection === 'notebooks' && item.deletedAt && !includeDeleted) fail(410, 'NOTEBOOK_DELETED', 'Notebook has been deleted');
    return item;
  }
  validateDefinition(n) {
    if (typeof n.title !== 'string' || !n.title.trim() || n.title.length > 120) fail(400, 'TITLE', 'Title is required (max 120 characters)');
    if (!Array.isArray(n.cells) || n.cells.length > 30) fail(400, 'CELL_LIMIT', 'At most 30 cells per notebook');
    if (!Array.isArray(n.inputs) || n.inputs.length > 50) fail(400, 'INPUTS', 'At most 50 typed inputs');
    const names = new Set();
    for (const p of n.inputs) {
      if (!/^[a-zA-Z][a-zA-Z0-9_]{0,29}$/.test(p.name) || names.has(p.name)) fail(400, 'INPUT_NAME', 'Input names must be unique identifiers');
      names.add(p.name);
      if (p.type === 'member' || p.type === 'range') fail(501, 'SAP_REQUIRED', 'BPC member metadata and authorization require the SAP backend');
      if (!['number', 'string', 'boolean'].includes(p.type) || typeof p.value !== p.type || (p.type === 'number' && !Number.isFinite(p.value)))
        fail(400, 'INPUT_TYPE', 'Input value must match its declared type');
    }
    const seen = new Set();
    for (const c of n.cells) {
      if (!/^[a-zA-Z][a-zA-Z0-9_-]{0,29}$/.test(c.id) || seen.has(c.id)) fail(400, 'CELL_ID', 'Cell IDs must be unique identifiers');
      if (typeof c.source !== 'string' || c.source.length > 60000) fail(400, 'SOURCE', 'Source must be text (max 60 KB)');
      if (typeof c.title !== 'string' || c.title.length > 120) fail(400, 'CELL_TITLE', 'Cell title is required');
      if (!Array.isArray(c.dependencies) || new Set(c.dependencies).size !== c.dependencies.length || c.dependencies.some(d => !seen.has(d)))
        fail(400, 'DEPENDENCY_ORDER', 'Dependencies must be unique and precede their consumer');
      seen.add(c.id);
    }
  }
  create(data, user) {
    const id = randomUUID(); this.validateDefinition(data);
    const n = {id, owner: user, versions: [], current: 0}; this.db.notebooks[id] = n;
    return this.save(id, {...data, expectedRevision: 0}, user);
  }
  save(id, data, user) {
    const n = this.owned('notebooks', id, user); this.validateDefinition(data);
    if (data.expectedRevision !== n.current) fail(409, 'CONFLICT', 'Notebook changed; reload before saving');
    const old = n.versions.at(-1);
    const cells = data.cells.map(c => {
      const previous = n.versions.flatMap(v=>v.cells).filter(p=>p.id===c.id).at(-1);
      const checksum = hash(c.source);
      return {...copy(c), checksum, sourceVersion: (previous?.sourceVersion || 0) + (previous?.checksum === checksum ? 0 : 1)};
    });
    const version = {id, title: data.title.trim(), environment: data.environment || '', model: data.model || '', inputs: copy(data.inputs), cells,
      revision: n.current + 1, author: user, savedAt: now()};
    version.checksum = hash(version); n.versions.push(version); n.current++;
    this.audit(user, 'SAVE', id); this.persist(); return this.get(id, user);
  }
  list(user) { return Object.values(this.db.notebooks).filter(n => n.owner === user && !n.deletedAt).map(n => {
    const v = n.versions.at(-1); return {id: n.id, title: v.title, revision: v.revision, savedAt: v.savedAt};
  }); }
  fingerprint(n, cellId) {
    const c = n.cells.find(c => c.id === cellId);
    return hash({id: c.id, sequence:n.cells.findIndex(c=>c.id===cellId),source: c.checksum, environment:n.environment, model:n.model, inputs: n.inputs,
      dependencies: c.dependencies.map(d => [d, this.fingerprint(n, d)])});
  }
  latest(n, cellId, user) {
    return Object.values(this.db.outputs).filter(o => o.owner === user && o.notebookId === n.id && o.cellId === cellId)
      .sort((a,b) => b.ordinal - a.ordinal)[0];
  }
  isCurrent(n, o, user) {
    if (!o || o.fingerprint !== this.fingerprint(n,o.cellId)) return false;
    const c=n.cells.find(c=>c.id===o.cellId);
    return c.dependencies.every(d=>{
      const latest=this.latest(n,d,user);
      return latest && o.dependencyBindings?.[d]===latest.id && this.isCurrent(n,latest,user);
    });
  }
  get(id, user) {
    const n = copy(this.owned('notebooks', id, user).versions.at(-1));
    n.cells = n.cells.map(c => {
      const o = this.latest(n, c.id, user);
      return {...c, output: o ? {runId: o.runId, cellId: o.cellId, revision: o.revision, rowCount: o.rows.length,
        stale: !this.isCurrent(n,o,user)} : null};
    }); return n;
  }
  deleteNotebook(id, expectedRevision, user) {
    const n = this.owned('notebooks', id, user);
    if (n.current !== expectedRevision) fail(409, 'CONFLICT', 'Notebook changed; reload before deleting');
    const active = Object.values(this.db.runs).filter(r => r.owner === user && r.notebookId === id)
      .some(r => ['queued','running'].includes(this.run(r.id,user).state));
    if (active) fail(409, 'NOTEBOOK_BUSY', 'Cancel or finish active executions before deleting this notebook');
    n.deletedAt = now(); n.deletedBy = user; this.audit(user, 'DELETE', id); this.persist();
    return {deleted:true};
  }
  history(id, user) { return copy(this.owned('notebooks', id, user, true).versions); }
  validate(id, cellId, user) {
    const n = this.get(id, user); const c = n.cells.find(c => c.id === cellId);
    if (!c) fail(404, 'CELL', 'Cell not found');
    // The local service cannot compile arbitrary ABAP. Only exact demo sources are simulated.
    const supported = demo().cells.some(d => hash(d.source) === c.checksum);
    return {native: false, supported, diagnostics: supported ? [] : [{severity: 'warning', line: 1,
      message: 'Local simulator supports only the two demo cell bodies. SAP compilation is required for edited ABAP.'}]};
  }
  submit(request, user) {
    const {notebookId, expectedRevision, scope, cellId, idempotencyKey} = request;
    if (typeof idempotencyKey !== 'string' || !/^[\w-]{8,80}$/.test(idempotencyKey)) fail(400, 'KEY', 'Supply a unique submission key (8–80 characters)');
    const key = user + ':' + idempotencyKey; const digest = hash(request);
    if (this.db.keys[key]) {
      if (this.db.keys[key].digest !== digest) fail(409, 'KEY_REUSED', 'Submission key is bound to a different request');
      return this.run(this.db.keys[key].id, user);
    }
    const original = request.retryRunId ? this.owned('runs',request.retryRunId,user) : null;
    if (original && original.notebookId!==notebookId) fail(400,'RETRY','Retry notebook mismatch');
    const n = copy(original ? this.owned('notebooks',notebookId,user).versions.find(v=>v.revision===original.snapshot.revision)
      : this.owned('notebooks', notebookId, user).versions.at(-1));
    if (expectedRevision !== n.revision) fail(409, 'CONFLICT', 'Expected notebook revision is no longer current');
    if (!['one','through','all'].includes(scope)) fail(400, 'SCOPE', 'Invalid execution scope');
    const index = n.cells.findIndex(c => c.id === cellId);
    if (scope !== 'all' && index < 0) fail(404, 'CELL', 'Selected cell does not exist');
    const cells = scope === 'one' ? [n.cells[index]] : scope === 'through' ? n.cells.slice(0,index + 1) : n.cells;
    if (!cells.length) fail(400, 'EMPTY', 'No cells to execute');
    const selected = new Set(cells.map(c => c.id)); const bindings = {};
    for (const c of cells) for (const d of c.dependencies) if (!selected.has(d)) {
      const o = original ? this.db.outputs[original.bindings[d]] : this.latest(n, d, user);
      if (!o || (!original && !this.isCurrent(n,o,user))) fail(409, 'STALE_DEPENDENCY', `Run current dependency ${d} first`);
      bindings[d] = o.id;
    }
    const id = randomUUID(); const run = {id, owner: user, notebookId, state: 'queued', scope,
      jobName: 'LOCAL_SIMULATION', jobId: id.slice(0,8), native: false, createdAt: now(), progress: 0,
      snapshot: {...n, cells}, bindings, frozenBindings:copy(bindings),messages: [], results: [], cancelRequested: false,
      timeoutMs: 60000};
    run.checksum=hash({snapshot:run.snapshot,bindings:run.frozenBindings});
    this.db.runs[id] = run; this.db.keys[key] = {id, digest}; this.audit(user, 'SUBMIT', id); this.persist();
    if (this.auto) { const task = this.execute(id).finally(() => this.tasks.delete(task)); this.tasks.add(task); }
    return this.run(id, user);
  }
  run(id, user) { return copy(this.owned('runs', id, user)); }
  retry(id, key, user) {
    const original=this.owned('runs',id,user);
    if(['queued','running'].includes(original.state)) fail(409,'RETRY_ACTIVE','Wait for the original execution to end');
    return this.submit({notebookId:original.notebookId,expectedRevision:original.snapshot.revision,scope:original.scope,
      cellId:original.snapshot.cells.at(-1).id,idempotencyKey:key,retryRunId:id},user);
  }
  runs(notebookId, user) {
    this.owned('notebooks', notebookId, user);
    return Object.values(this.db.runs).filter(r => r.owner === user && r.notebookId === notebookId)
      .sort((a,b) => b.createdAt.localeCompare(a.createdAt)).map(r => copy({id:r.id,notebookId:r.notebookId,state:r.state,scope:r.scope,createdAt:r.createdAt,finishedAt:r.finishedAt,results:r.results}));
  }
  cancel(id, user) {
    const r = this.owned('runs', id, user);
    if (['queued','running'].includes(r.state)) { r.cancelRequested = true; this.audit(user,'CANCEL',id); this.persist(); }
    return this.run(id, user);
  }
  async execute(id) {
    const r = this.db.runs[id]; if (r.state !== 'queued') return;
    r.state = 'running'; r.startedAt = now(); this.persist();
    const started = Date.now(); const n = r.snapshot;
    try {
      if(r.checksum!==hash({snapshot:r.snapshot,bindings:r.frozenBindings}))fail(409,'SNAPSHOT_INTEGRITY','Frozen snapshot changed');
      for (const c of n.cells) {
        await new Promise(resolve => setTimeout(resolve, this.delay));
        if (r.cancelRequested) { r.state = 'cancelled'; break; }
        if (Date.now() - started > r.timeoutMs) fail(408,'TIMEOUT','Execution deadline exceeded');
        const begin = Date.now(); const kind = demo().cells.findIndex(d => hash(d.source) === c.checksum);
        if(hash(c.source)!==c.checksum)fail(409,'SOURCE_INTEGRITY','Source checksum mismatch');
        if (kind < 0) fail(422, 'NATIVE_REQUIRED', 'Edited ABAP requires the SAP backend; simulation refused');
        const inputs = Object.fromEntries(n.inputs.map(p => [p.name,p.value])); let rows;
        if (kind === 0) {
          if (typeof inputs.total !== 'number') fail(422,'INPUT_TYPE','total must be a number');
          rows = [0.5,0.3,0.2].map((weight,i) => ({key: `CC${(i+1)*100}`, amount: inputs.total*weight}));
        } else {
          const dependency = c.dependencies[0]; const output = this.db.outputs[r.bindings[dependency]];
          if (!output || typeof inputs.factor !== 'number') fail(422,'DEPENDENCY','Declared dataset and numeric factor are required');
          rows = output.rows.map(row => ({...row, amount: row.amount*inputs.factor}));
        }
        const outputId = id + ':' + c.id;
        const o = {id: outputId, owner: r.owner, notebookId: r.notebookId, runId: id, cellId: c.id, revision: 1,
          schema: [{name:'key',type:'string'},{name:'amount',type:'number'}], rows,
          checksum:hash(rows),
          fingerprint: this.fingerprint(this.owned('notebooks', r.notebookId, r.owner).versions.find(v => v.revision === n.revision), c.id),
          dependencyBindings:Object.fromEntries(c.dependencies.map(d=>[d,r.bindings[d]])),
          ordinal: Object.keys(this.db.outputs).length + 1, createdAt: now(), retention: 'manual DEV retention'};
        this.db.outputs[outputId] = o; r.bindings[c.id] = outputId;
        r.results.push({cellId:c.id, runId:id, revision:1, rowCount:rows.length, durationMs:Date.now()-begin, checksum:hash(rows)});
        r.messages.push({cellId:c.id,severity:'success',text:`Persisted ${rows.length} rows in the local simulation store`});
        r.progress = r.results.length/n.cells.length; this.persist();
      }
      if (r.state === 'running') r.state = 'succeeded';
    } catch (e) { r.state = 'failed'; r.error = {code:e.code || 'EXECUTION',message:e.message}; }
    r.finishedAt = now(); r.durationMs = Date.now()-started; this.persist();
  }
  preview(runId, cellId, revision, offset, limit, user) {
    this.owned('runs', runId, user); const o = this.owned('outputs', runId + ':' + cellId, user);
    if (revision !== o.revision) fail(409,'OUTPUT_REVISION','Output revision changed');
    if(o.checksum && hash(o.rows)!==o.checksum)fail(409,'OUTPUT_INTEGRITY','Dataset checksum mismatch');
    if (!Number.isInteger(offset) || offset < 0 || !Number.isInteger(limit) || limit < 1 || limit > 100)
      fail(400,'PAGE','Offset must be nonnegative; page size must be 1–100');
    return {runId,cellId,revision,total:o.rows.length,offset,limit,schema:copy(o.schema),rows:copy(o.rows.slice(offset,offset+limit))};
  }
}
