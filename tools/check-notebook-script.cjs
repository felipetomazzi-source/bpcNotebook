const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),api=require('./bpc-api.cjs');
let Script;vm.runInNewContext(fs.readFileSync('webapp/model/Script.js','utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
(async()=>{
const seedId=process.argv.find(x=>x.startsWith('--notebook='))?.slice(11);
assert(seedId,'Supply --notebook=<existing notebook with CATEGORY and TIME selections>');
const seed=await api('/notebook?id='+encodeURIComponent(seedId),null,'GET');
const category=seed.inputs.find(p=>p.name==='CATEGORY'),time=seed.inputs.find(p=>p.name==='TIME');
assert(category?.selected?.length===1&&time?.resolved?.length,'Seed needs CATEGORY and resolved TIME');
const math=`# É · São — exact author text  \r\nlet total = number(input("total"))
table rows
append rows key = "CC100" amount = total * 0.5
append rows key = "CC200" amount = total * 0.3
append rows key = "CC300" amount = total * 0.2
for row in rows
  if row.amount > 0
    row.amount = row.amount * number(input("factor"))
  else
    row.amount = 0
  end
end
emit rows
show rows as "ALLOCATION"
message "É · São — ready"`;
const members=`dimension category = ${seed.model}-${category.dimension}
members rows = category
let description = category-EVDESCRIPTION(member("CATEGORY"))
message description
show rows as "MEMBERS"`;
const model=`model plan = ${seed.model}
data facts = plan where ${time.dimension} = range("TIME") and ${category.dimension} = selection("CATEGORY") limit 10000
for row in facts
  row.SIGNEDDATA = row.SIGNEDDATA * 1.1
end
show facts as "FACTS"
message text(count(facts))`;
const sources=[math,members,model];
const cells=sources.map((s,i)=>({id:'script'+i,title:['Script arithmetic and loop','Script dimension members','Script model read'][i],source:Script.compile(s),dependencies:[]}));
const inputs=seed.inputs.filter(p=>['CATEGORY','TIME'].includes(p.name)).concat([{name:'total',type:'number',value:'120000'},{name:'factor',type:'number',value:'1.1'}]);
const n=await api('/notebooks',{title:'Notebook Script - SAP verification',environment:seed.environment,model:seed.model,inputs,cells});

for(const c of cells){const v=await api('/validate',{notebookId:n.id,cellId:c.id});console.log(JSON.stringify({cell:c.id,validation:v}));assert.equal(v.supported,true);}
const saved=await api('/notebook?id='+n.id,null,'GET');saved.cells.forEach((c,i)=>assert.equal(Script.unpack(c.source).text,sources[i]));
const invalid=structuredClone(saved);invalid.cells[2].source='* BPC Notebook Script v1\n* @bn-line 23\nBROKEN.';
await assert.rejects(api('/notebook',{...invalid,expectedRevision:saved.revision},'PUT'),/SCRIPT_ABAP.*script line 23/);
const unchanged=await api('/notebook?id='+n.id,null,'GET');assert.equal(unchanged.revision,saved.revision);assert.deepEqual(unchanged.cells,saved.cells);
const submitted=await api('/runs',{notebookId:n.id,expectedRevision:n.revision,scope:'all',idempotencyKey:crypto.randomUUID()});
let run;for(let i=0;i<90;i++){run=await api('/run?id='+submitted.id,null,'GET');if(['succeeded','failed','cancelled'].includes(run.state))break;await new Promise(r=>setTimeout(r,1000));}
assert.equal(run.state,'succeeded',JSON.stringify(run.error));
const output=await api('/output?runId='+run.id+'&cellId=script0&revision=1&offset=0&limit=20&table=ALLOCATION',null,'GET');
console.log(JSON.stringify({notebookId:n.id,runId:run.id,rows:output.rows}));
assert.deepEqual(output.rows.map(r=>Number(r.values[1])),[66000,39600,26400]);
assert.deepEqual(run.snapshot.inputs.find(p=>p.name==='TIME').resolved,saved.inputs.find(p=>p.name==='TIME').resolved);
const evidence={at:new Date().toISOString(),passed:true,notebookId:n.id,runId:run.id,checks:['SAP native compilation of all three scripts',
 'arithmetic/loop/condition outputs 66000,39600,26400','authorized dimension/property and model adapters','frozen TIME selections',
 'exact Unicode and whitespace author-source reopen','invalid generated ABAP rejected at save without persisted changes'],output};
fs.writeFileSync('docs/evidence/notebook-script.json',JSON.stringify(evidence,null,2)+'\n','utf8');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
