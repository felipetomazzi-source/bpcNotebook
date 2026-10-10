// Build a separate, nonposting validation notebook using the exact visible stage cells.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname,'../..');
const definition = JSON.parse(fs.readFileSync(path.join(__dirname,'definition.draft.json'),'utf8'));
const oldDefinition = JSON.parse(fs.readFileSync(path.join(root,'examples/demrevid-allocation/validation-definition.json'),'utf8'));
definition.title = 'DEMREVID003 - stepwise original comparison';
definition.explanation = 'Validation only. Complete authorized synthetic native fixtures feed the visible step cells and the original baseline. This does not prove equivalence on customer data and never posts financial results.';
definition.inputs.push(oldDefinition.inputs.find(i=>i.name==='FIXTURE_CASE'));
let fixtureSource = fs.readFileSync(path.join(root,'examples/demrevid-allocation/fixture-validation.abap'),'utf8').replace(/\r\n/g,'\n');
fixtureSource = fixtureSource.replace(/zcl_bn_dem_validation=>execute\( io \)\./i,"io->publish_dataset( name = 'FIXTURE_INPUT' rows = fixtures ).\nio->emit_table( name = 'FIXTURE_INPUT' rows = fixtures ).");
const fixtureCell = {id:'fixtures',title:'00 · Prepare controlled test data',explanation:'Use authorized member IDs and synthetic amounts. Verify the scenario and suppression flag. Both implementations receive identical complete native tables.',source:fixtureSource,dependencies:[]};
const hook = "DATA(complete_fixture) = io->read_dataset( dependency = 'fixtures' name = 'FIXTURE_INPUT' ).\nio->enable_fixtures( VALUE #( ( environment = io->environment model = io->model rows = complete_fixture ) ) ).\n";
definition.cells.forEach(cell=>{cell.dependencies.push('fixtures'); cell.source=hook+cell.source;});
const comparison = `DATA(complete_fixture) = io->read_dataset( dependency = 'fixtures' name = 'FIXTURE_INPUT' ).
io->enable_fixtures( VALUE #( ( environment = io->environment model = io->model rows = complete_fixture ) ) ).
DATA(reader) = NEW zcl_bn_dem_validation( io ).
DATA(parameters) = io->script_parameters( ).
LOOP AT parameters ASSIGNING FIELD-SYMBOL(<flag>).
 CASE <flag>-hashkey.
 WHEN 'FFLASMATGROUPS'. CASE <flag>-hashvalue. WHEN 'true'. <flag>-hashvalue = '1'. WHEN 'false'. <flag>-hashvalue = '0'. ENDCASE.
 WHEN 'DEBUG'. CASE <flag>-hashvalue. WHEN 'true'. <flag>-hashvalue = 'ON'. WHEN 'false'. <flag>-hashvalue = 'OFF'. ENDCASE.
 ENDCASE.
ENDLOOP.
DATA(original) = zcl_bpc_demrevid_calc_003=>validate_with_reader( reader = reader it_param = parameters current_view = io->current_view( ) ).
DATA(replacement_ref) = io->read_dataset( dependency = 'reconcile' name = 'FINAL_REPLACEMENT' ).
DATA(delta_ref) = io->read_dataset( dependency = 'reconcile' name = 'FINAL_DELTA' ).
FIELD-SYMBOLS <replacement> TYPE STANDARD TABLE. FIELD-SYMBOLS <delta> TYPE STANDARD TABLE.
ASSIGN replacement_ref->* TO <replacement>. ASSIGN delta_ref->* TO <delta>.
DATA(replacement_comparison) = io->compare_results( name = 'REPLACEMENT' original = original-replacement notebook = <replacement> ).
DATA(delta_comparison) = io->compare_results( name = 'DELTA' original = original-delta notebook = <delta> ).
io->emit_table( name = 'FINAL_DELTA' rows = <delta> ).
IF replacement_comparison-original_rows = 0 OR replacement_comparison-notebook_rows = 0.
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'EMPTY_COMPARISON' detail = 'Empty tables do not establish equivalence'.
ENDIF.
IF replacement_comparison-added + replacement_comparison-missing + replacement_comparison-changed + delta_comparison-added + delta_comparison-missing + delta_comparison-changed <> 0.
 RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'STEPWISE_DIFFERENCE' detail = 'Complete original and stepwise results differ; inspect native comparison tables'.
ENDIF.
io->message( 'Complete native replacement and delta match the original for this fixture only.' ).
`;
definition.cells.unshift(fixtureCell);
definition.cells.push({id:'compare',title:'22 · Compare with the original',explanation:'Compare all dimensions and exact native signed amounts. Every added, missing or changed record must be explained. Nonempty fixtures test only the paths they exercise.',source:comparison,dependencies:['fixtures','reconcile']});
fs.writeFileSync(path.join(__dirname,'validation.draft.json'),JSON.stringify(definition,null,2)+'\n');
console.log(JSON.stringify({cells:definition.cells.length,status:'generated; see native-evidence.json for SAP verification'}));
