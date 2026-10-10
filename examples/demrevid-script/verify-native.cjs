const fs=require('fs'),path=require('path'),assert=require('assert/strict'),api=require('../../tools/bpc-api.cjs');
const options=Object.fromEntries(process.argv.filter(x=>/^--[^=]+=/.test(x)).map(x=>{const p=x.indexOf('=');return[x.slice(2,p),x.slice(p+1)];}));
const get=p=>api(p,null,'GET');const local=p=>path.join(__dirname,p);
const definition=JSON.parse(fs.readFileSync(local(options.live==='true'?'live-validation.draft.json':'validation.draft.json'),'utf8'));
const cases=options.live==='true'?[['live',true],['live',false]]:[['standard',true],['standard',false],['fallback',false],['rounding',false],['negative',false],['carry',false],['carry',true],['hsns',false],['hsns',true]];
async function output(run,name){const o=await get('/output?runId='+run.id+'&cellId=compare&revision=1&limit=100&table='+encodeURIComponent(name));return o.rows.map(r=>Object.fromEntries(o.schema.map((f,i)=>[f.name.toUpperCase(),r.values[i]])));}
(async()=>{let notebook=options.notebook?await get('/notebook?id='+options.notebook):null;const evidence={at:new Date().toISOString(),financialPosting:false,customerEquivalent:false,cases:[],notebookId:''};
for(const [scenario,suppress]of cases){definition.inputs.find(i=>i.name==='FIXTURE_CASE').value=scenario;definition.inputs.find(i=>i.name==='FFLASMATGROUPS').value=String(suppress);
if(notebook){const latest=await get('/notebook?id='+notebook.id);notebook=await api('/notebook',{...definition,id:latest.id,expectedRevision:latest.revision},'PUT');}else notebook=await api('/notebooks',definition);
evidence.notebookId=notebook.id;fs.writeFileSync(local(options.live==='true'?'live-notebook-id.txt':'validation-notebook-id.txt'),notebook.id+'\n');
for(const c of definition.cells){const checked=await api('/validate',{notebookId:notebook.id,cellId:c.id});assert(!checked.diagnostics.some(d=>['error','E'].includes(d.severity)),JSON.stringify({cell:c.id,diagnostics:checked.diagnostics}));}
let run=await api('/runs',{notebookId:notebook.id,expectedRevision:notebook.revision,scope:'all',idempotencyKey:crypto.randomUUID()});console.log(JSON.stringify({scenario,suppress,runId:run.id,notebookId:notebook.id}));
for(let n=0;n<1500&&['queued','running'].includes(run.state);n++){await new Promise(r=>setTimeout(r,1500));run=await get('/run?id='+run.id);}
const result={scenario,suppress,runId:run.id,state:run.state,error:run.error};evidence.cases.push(result);
if(run.state==='succeeded'){result.replacement=(await output(run,'REPLACEMENT/SUMMARY'))[0];result.delta=(await output(run,'DELTA/SUMMARY'))[0];for(const c of [result.replacement,result.delta]){assert(Number(c.ORIGINAL_ROWS)>0);assert.equal(Number(c.ADDED)+Number(c.MISSING)+Number(c.CHANGED),0,JSON.stringify(c));}}
fs.writeFileSync(local(options.live==='true'?'live-evidence.json':'native-evidence.json'),JSON.stringify(evidence,null,2)+'\n');console.log(JSON.stringify(result));assert.equal(run.state,'succeeded',JSON.stringify(run));}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
