// Mechanical starting point: business logic lives in cells, never in an engine call.
// Rebuild after reviewing the input class; generated cells are not proof of equivalence.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const original = fs.readFileSync(path.join(root, 'src/zcl_bn_dem_alloc.clas.abap'), 'utf8');
const methods = new Map([...original.matchAll(/^  method ([\w~]+)\.([\s\S]*?)^  endmethod\./gim)].map(m => [m[1].toLowerCase(), m[2].replace(/^\s*TRY\./i, '').replace(/\s*CATCH zcx_bn INTO DATA\(notebook_error\)\.[\s\S]*ENDTRY\.\s*$/i, '').trim()]));
function body(name) { if (!methods.has(name)) throw Error('Missing method ' + name); return methods.get(name); }
const constants = [...original.matchAll(/^    constants .*?\.\s*$/gim)].map(m => m[0].trim()).join('\n');
const enums = original.match(/    types: begin of enum rev_split_method,[\s\S]*?end of enum rev_split_type\./i)[0];
const attributes = original.match(/    data:\s*\r?\n[\s\S]*?skip_fflas_ratio_mat_group_id type ujw_t_dimmem_range\./i)[0];
const models = [...attributes.matchAll(/(\w+)\s+type ref to zcl_bn_dem_model/g)].map(m => m[1]);
models.push('complete_source_data');
const stageRows = [...body('get_steps').matchAll(/id = '([^']+)' label = '([^']+)' method_name = '([^']+)'/g)];
const rules = require('./rules.json');
const produced = new Map();
const lineage = [];
const cells = [];
const outputs = {
 INITIALISE: ['complete_source_data','input_data','output_data','new_data','sap_revenues','conn_reg_split','l1_l2_mapping','mat_group_mapping','rsp_location_material_ratio','rsp_location_gl_ratio','cal_location_gl_ratio','cal_location_conn_seg_ratio','rsp_supplier_material_ratio','rsp_supplier_gl_ratio','cal_supplier_gl_ratio','cal_supplier_conn_seg_ratio'],
 ENRICH_REVENUES: ['sap_revenues','new_data'], CONSOLIDATE: ['sap_revenues_consol'],
 LOCATION_ALLOC_METHOD:['new_data'], LOCATION_ALLOC_RATIOS:['rsp_split_ratios','new_data'],
 ALLOC_RSP_BILLED_DATA:['new_data'], REMAINING_RSP_BILLING:['new_data'], RSP_NOT_BILLED_LOCATION:['new_data'],
 FFLAS_GROUPING:['new_data','fflas_month_ratio'], PQ_ID_FFLAS_REVENUE:['new_data'], PQ_FFLAS_RATIO:['new_data'],
 SUPPLIER_ALLOC_METHOD:['new_data'], SUPPLIER_ALLOC_RATIOS:['new_data','supplier_ratios'],
 ALLOC_ID_REV_SUPPLIER:['new_data'], PRICE_MATERIAL_LEVEL:['new_data'], HSNS_REV_ALLOC:['new_data'],
 FFLAS_RATIOS_BY_MATERIAL:['new_data'], TRANSPOSE_REVENUES:['new_data','transposed_revenues'],
 TRANSPOSE_PRICES:['new_data'], TRANSPOSE_CONNECTIONS:['new_data','transposed_revenues']
};
function replaceNames(text, names) {
 // ABAP literals/comments are preserved; only lexical code identifiers are changed.
 return text.split(/('(?:''|[^'])*'|"[^\r\n]*)/g).map((part, i) => i % 2 ? part : part.replace(/<?[A-Za-z_][A-Za-z_0-9]*>?/g, token => names.get(token.toLowerCase()) || token)).join('');
}
function enrichment(target, suffix) {
 let source = body('assign_new_fields_rev');
 const renames = new Map([['model_ref', target]]);
 for (const m of source.matchAll(/(?:data|field-symbol)\((<?[\w]+>?)\)/gi)) {
   const name = m[1]; renames.set(name.toLowerCase(), name.startsWith('<') ? '<' + name.slice(1,-1).slice(0,23) + '_' + suffix + '>' : name.slice(0,24) + '_' + suffix);
 }
 // The original initializer resolves MAT_REMAPPING to the key-figure constant;
 // its local table of the same name becomes visible only after declaration.
 const expanded = replaceNames(source, renames).replace(new RegExp('low = mat_remapping_' + suffix, 'g'), 'low = mat_remapping');
 return '" Visible mapping precedence, expanded here rather than called in an engine.\n' + expanded;
}
function retainedReads(source) {
 const pattern = /new zcl_bn_dem_model\(/gi;
 let match;
 while ((match = pattern.exec(source))) {
   let end = pattern.lastIndex, depth = 1;
   for (; end < source.length && depth; end++) {
     if (source[end] === "'") { end++; while (end < source.length) { if (source[end] === "'" && source[end+1] === "'") {end+=2;continue;} if (source[end] === "'") break; end++; } }
     else if (source[end] === '"') { while (end < source.length && source[end] !== '\n') end++; }
     else if (source[end] === '(') depth++;
     else if (source[end] === ')') depth--;
   }
   if (depth) throw Error('Unclosed model constructor');
   const args = source.slice(pattern.lastIndex,end-1);
   const filter = args.match(/filters\s*=([\s\S]*)$/i);
   if (!filter) continue;
   const replacement = 'complete_source_data->copy( ' + filter[1].trim() + ' )';
   source = source.slice(0,match.index) + replacement + source.slice(end);
   pattern.lastIndex = match.index + replacement.length;
 }
 return source;
}
for (let index = 0; index < stageRows.length; index++) {
 const [, stage, , method] = stageRows[index];
 const id = 'step_' + String(index + 1).padStart(2, '0');
 let calculation;
 if (stage === 'ENRICH_REVENUES') calculation = enrichment('sap_revenues','e1') + '\nnew_data->append( sap_revenues ).';
 else if (stage === 'CONSOLIDATE') calculation = "sap_revenues_consol = sap_revenues->copy( )->group( include_dimensions = abap_false group_by = VALUE #( ( 'DEMREVID_KFS' ) ) ).";
 else calculation = body(method);
 if (stage === 'INITIALISE') {
   calculation = `DATA(source_adapter) = io->reference_model( ).
DATA(source_ref) = source_adapter->read_data( max_rows = CONV i( io->input( 'READ_LIMIT' ) ) ).
FIELD-SYMBOLS <source_facts> TYPE STANDARD TABLE.
ASSIGN source_ref->* TO <source_facts>.
complete_source_data = NEW #( environment = io model_data = <source_facts> compressed = abap_false ).
` + retainedReads(calculation);
 }
 if (stage === 'TRANSPOSE_CONNECTIONS') {
   calculation = retainedReads(calculation);
 }
 let count = 0;
 calculation = calculation.replace(/assign_new_fields_rev\( (\w+) \)\./gi, (_, target) => enrichment(target, 'e' + (++count)));
 calculation = calculation.replace(/_new_data-signeddata = conv i\( get_rev_split_method\( ratio_type = (location|supplier) _sap_revenue = _new_data \) \)\./gi, (_, kind) => {
   const lookup = replaceNames(body('get_rev_split_method'), new Map([['ratio_type',kind],['_sap_revenue','_new_data'],['rev_split_index','chosen_method']])).replace(/\breturn\./gi,'EXIT.');
   return 'DATA chosen_method TYPE rev_split_method.\nDO 1 TIMES.\n' + lookup + '\nENDDO.\n_new_data-signeddata = CONV i( chosen_method ).';
 });
 if (['PQ_ID_FFLAS_REVENUE','PQ_FFLAS_RATIO'].includes(stage)) {
   calculation = replaceNames(calculation,new Map([['result','stage_result']]));
   calculation = 'DATA stage_result TYPE REF TO zcl_bn_dem_model.\n' + calculation + '\nnew_data->append( stage_result ).';
 }
 if (stage === 'FFLAS_RATIOS_BY_MATERIAL') calculation = 'DATA fflas_ratios TYPE REF TO zcl_bn_dem_model.\n' + calculation + '\nnew_data->append( fflas_ratios ).';
 calculation = calculation.replace(/capture\( dataset = '([^']+)' model = (\w+) \)\./gi, (_, name, model) => `io->emit_table( name = '${name}' rows = ${model}->model_data ).`);
 const codeOnly = calculation.replace(/'[^']*'|"[^\r\n]*/g,'');
 const referenced = models.filter(name => new RegExp('\\b' + name + '\\b','i').test(codeOnly));
 const deps = new Set(index ? [cells[index-1].id] : []);
 let imports = '';
 for (const name of referenced) {
   imports += `DATA ${name} TYPE REF TO zcl_bn_dem_model.\n`;
   if (produced.has(name)) {
     const producer = produced.get(name); deps.add(producer);
     imports += `DATA(ref_${name.slice(0,24)}) = io->read_dataset( dependency = '${producer}' name = '${name.toUpperCase()}' ).\nFIELD-SYMBOLS <t_${name.slice(0,25)}> TYPE STANDARD TABLE.\nASSIGN ref_${name.slice(0,24)}->* TO <t_${name.slice(0,25)}>.\n${name} = NEW #( environment = io model_data = <t_${name.slice(0,25)}> compressed = abap_false ).\n`;
   }
 }
 let prelude = `${constants}\n${enums}\nDATA(env) = io.\nDATA(preview_rows) = CONV i( io->input( 'PREVIEW_ROWS' ) ).\nDATA(category) = io->member( 'CATEGORY' ).\nDATA(parameters) = io->script_parameters( ).\nREAD TABLE parameters ASSIGNING FIELD-SYMBOL(<flag>) WITH KEY hashkey = 'FFLASMATGROUPS'.\nIF sy-subrc = 0.\nCASE <flag>-hashvalue. WHEN 'true'. <flag>-hashvalue = '1'. WHEN 'false'. <flag>-hashvalue = '0'. ENDCASE.\nENDIF.\nDATA(param) = NEW zcl_bpc_param( parameters ).\nDATA(skip_fflas_ratio_mat_group_id) = param->get_dimmem_range( 'FFLASMATGROUPSID' ).\nIF io->input( 'FFLASMATGROUPS' ) = 'false'. CLEAR skip_fflas_ratio_mat_group_id. ENDIF.\nDATA(product_type_dim) = NEW zcl_bn_dimension( io = io name = 'PRODUCT_TYPE' ).\nDATA(mat_group_id_dim) = NEW zcl_bn_dimension( io = io name = 'MAT_GROUP_ID' ).\nDATA(matconn_dim) = NEW zcl_bn_dimension( io = io name = 'MATCONN' ).\n`;
 prelude = prelude.replace("IF io->input( 'FFLASMATGROUPS' ) = 'false'. CLEAR skip_fflas_ratio_mat_group_id. ENDIF.", `DATA(nb_skip_flags) = param->get_dimmem_range( 'FFLASMATGROUPS' ).
LOOP AT skip_fflas_ratio_mat_group_id INTO DATA(nb_skip_id).
 READ TABLE nb_skip_flags INTO DATA(nb_skip_flag) INDEX sy-tabix.
 IF sy-subrc <> 0 OR nb_skip_flag-low = 0. DELETE skip_fflas_ratio_mat_group_id. ENDIF.
ENDLOOP.`);
 if (stage === 'INITIALISE') {
   prelude += 'DATA it_param TYPE ujk_t_script_logic_hashtable. it_param = parameters.\nDATA(current_view) = io->current_view( ).\nDATA time TYPE ujw_t_dimmem_range.\n';
   calculation = calculation.replace('param = new #( it_param ).','param = new #( it_param ).').replace(/\bdata\(skip_fflas_ratio_mat_group\)/i,'data(skip_fflas_ratio_mat_group)');
 }
 let exports = '';
 for (const name of outputs[stage]) {
   if (!referenced.includes(name)) throw Error('Undeclared output ' + stage + '/' + name);
   exports += `IF ${name} IS BOUND.\nio->check_rows( lines( ${name}->model_data ) ).\nio->publish_dataset( name = '${name.toUpperCase()}' rows = ${name}->model_data ).\nio->emit_table( name = '${name.toUpperCase()}' rows = ${name}->model_data ).\nENDIF.\n`;
   produced.set(name,id);
 }
 const explanation = rules[stage].rule + '\n\nCheck: ' + rules[stage].check;
 const source = `" ${rules[stage].title}\n" Calculation is inline. Full dependencies are independent of display previews.\n${prelude}${imports}\nio->check_budget( ).\nDO 1 TIMES.\n${calculation}\nENDDO.\n${exports}io->check_budget( ).\n`;
 if (/get_rev_split_method\(|assign_new_fields_rev\(|calc_\w+\(|zcl_bn_dem_alloc=>/i.test(source.replace(/"[^\r\n]*/g,''))) throw Error('Hidden calculation call in ' + stage);
 if (source.length > 60000) throw Error('Cell source limit ' + stage);
 cells.push({id,title:String(index+1).padStart(2,'0') + ' · ' + rules[stage].title,explanation,source,dependencies:[...deps]});
 lineage.push({id,stage,method,imports:referenced.filter(n=>!outputs[stage].includes(n)||index>0).map(n=>({name:n})),exports:outputs[stage],dependencies:[...deps]});
 fs.mkdirSync(path.join(__dirname,'cells'),{recursive:true});
 fs.writeFileSync(path.join(__dirname,'cells',id + '.abap'),source.replace(/\r?\n/g,'\r\n'));
}
const finalSource = `DATA(replacement_ref) = io->read_dataset( dependency = 'step_20' name = 'NEW_DATA' ).
DATA(old_ref) = io->read_dataset( dependency = 'step_01' name = 'OUTPUT_DATA' ).
FIELD-SYMBOLS <replacement> TYPE STANDARD TABLE.
FIELD-SYMBOLS <old> TYPE STANDARD TABLE.
ASSIGN replacement_ref->* TO <replacement>. ASSIGN old_ref->* TO <old>.
DATA(replacement) = NEW zcl_bn_dem_model( environment = io model_data = <replacement> compressed = abap_false ).
DATA(previous) = NEW zcl_bn_dem_model( environment = io model_data = <old> compressed = abap_false ).
io->publish_dataset( name = 'FINAL_REPLACEMENT' rows = replacement->model_data ).
io->emit_table( name = 'FINAL_REPLACEMENT' rows = replacement->model_data ).
replacement->compare_delta( previous ).
io->publish_dataset( name = 'FINAL_DELTA' rows = replacement->model_data ).
io->emit_table( name = 'FINAL_DELTA' rows = replacement->model_data ).
io->message( 'Preview only: complete replacement and delta retained; no financial posting.' ).
`;
cells.push({id:'reconcile',title:'21 · Final result and change-set',explanation:'Review the complete replacement and the changes from previously stored results. Disappeared records must have a clearing delta. This notebook does not post to BPC.',source:finalSource,dependencies:['step_20','step_01']});
const definition = JSON.parse(fs.readFileSync(path.join(root,'examples/demrevid-allocation/definition.json'),'utf8'));
definition.title = 'DEMREVID003 - step-by-step allocation';
definition.explanation = 'Choose CATEGORY, output TIME, and separate reference periods. Work through the numbered calculation tabs. Read the rule and checks before running a step. Code remains visible in Advanced mode. All financial calculations run on SAP using complete tables; previews are only for inspection. No financial posting.';
definition.inputs = definition.inputs.filter(x=>x.name!=='STOP_AFTER').map(x=>{delete x.fiscalLinks; delete x.resolved; return x;});
definition.cells = cells;
fs.writeFileSync(path.join(__dirname,'definition.draft.json'),JSON.stringify(definition,null,2)+'\n');
fs.writeFileSync(path.join(__dirname,'lineage.json'),JSON.stringify({status:'awaiting platform deployment and native validation',sourceClass:'ZCL_BN_DEM_ALLOC',sourceRevision:'91d08e3',cells:lineage},null,2)+'\n');
console.log(JSON.stringify({cells:cells.length,maxSourceLength:Math.max(...cells.map(c=>c.source.length)),status:'draft; not SAP-validated'}));
