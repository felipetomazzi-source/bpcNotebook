// Independent nonposting fixture/oracle notebook. Operational cells remain Script-only.
const fs=require('fs'),path=require('path'),vm=require('vm');
const root=path.resolve(__dirname,'../..');let Script;
vm.runInNewContext(fs.readFileSync(path.join(root,'webapp/model/Script.js'),'utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
const definition=JSON.parse(fs.readFileSync(path.join(__dirname,'definition.draft.json'),'utf8'));
if(definition.cells.some(c=>!c.source))throw Error('Compile all operational Script cells before creating validation notebook');
definition.title='DEMREVID003 - Script original comparison';
definition.explanation='Nonposting validation of complete native results. Synthetic fixtures exercise specific business paths; they do not establish customer-data equivalence.';
definition.inputs.push({name:'FIXTURE_CASE',type:'string',value:'standard'});
const old=JSON.parse(fs.readFileSync(path.join(root,'examples/demrevid-stepwise/validation.draft.json'),'utf8'));
definition.cells.forEach(c=>{const original=Script.unpack(c.source);if(original.language!=='script')throw Error('Operational ABAP cell '+c.id);const text=original.text.replace(/^(script version 2(?: compact)?)\n/,'$1\ndataset validation_fixture = "fixtures" named "FIXTURE_INPUT"\nfixture validation_fixture model "DEMREVID"\n');c.source=Script.compile(text);c.dependencies.push('fixtures');});
definition.cells.unshift(old.cells.find(c=>c.id==='fixtures'));
const comparison={...old.cells.find(c=>c.id==='compare')};
comparison.explanation='Compare every native dimension and exact seven-decimal amounts. Nonempty outputs required. Original code is used only as a test oracle.';
// Preserve duplicate multiplicity, but canonicalize both outputs for positional comparison.
// Original and Script native table descriptors share the same 21 fields/order.
comparison.source=comparison.source.replace("io->compare_results( name = 'REPLACEMENT' original = original-replacement notebook = <replacement> )","zcl_bn_table=>compare_ordered( io = io name = 'REPLACEMENT' original = original-replacement notebook = <replacement> )")
.replace("io->compare_results( name = 'DELTA' original = original-delta notebook = <delta> )","zcl_bn_table=>compare_ordered( io = io name = 'DELTA' original = original-delta notebook = <delta> )");
const order='account audittrail category costcentre demrevid_kfs fflas fflas_subset matconn time product_type geo_drivers doc_typ conn_reg_split lfc_win_supplier mat_group_id reg_fflas_serv ufb_dr_id matremap rsp_service_id rev_id_group signeddata';
comparison.source=comparison.source.replace('DATA(replacement_comparison)',`SORT original-replacement BY ${order}.\nSORT original-delta BY ${order}.\nSORT <replacement> BY ${order}.\nSORT <delta> BY ${order}.\nDATA(replacement_comparison)`);
comparison.source=comparison.source.replaceAll('STEPWISE_DIFFERENCE','SCRIPT_DIFFERENCE').replaceAll('stepwise','Script');
definition.cells.push(comparison);
fs.writeFileSync(path.join(__dirname,'validation.draft.json'),JSON.stringify(definition,null,2)+'\n');
console.log(JSON.stringify({cells:definition.cells.length,operationalLanguage:'script',financialPosting:false}));
