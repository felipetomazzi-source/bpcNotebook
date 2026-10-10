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
// The original filter helper constructs dimension objects even for literal equality
// filters, so retain their metadata as well as the properties used in arithmetic.
const requiredMetadata={ACCOUNT:[],CATEGORY:[],TIME:[],MATCONN:[],MAT_GROUP_ID:[],FFLAS:[],GEO_DRIVERS:[],LFC_WIN_SUPPLIER:[],MATREMAP:[],DOC_TYP:[],UFB_DR_ID:[],PRODUCT_TYPE:['PRODUCT_TYPE_ACCESS'],AUDITTRAIL:['DEMREVID_INPUT','DEMREVID_OUTPUT'],DEMREVID_KFS:['DEMREVID004']};
const capture=`DATA bundles TYPE zcl_bn_bpc=>tt_dimension_fixtures.\n`+Object.entries(requiredMetadata).map(([name,roots],i)=>`DATA(metadata_${i}) = io->bpc_dimension( '${name}' ).\nAPPEND metadata_${i}->capture_dimension( snapshot_id = io->snapshot_identifier( )${roots.length?'\n hierarchy_reads = VALUE #( '+roots.map(member=>`( hierarchy = 'PARENTH1' member = '${member}' )`).join('\n')+' )':''} ) TO bundles.\n`).join('')+`DATA(packets) = zcl_bn_bpc=>pack_dimensions( bundles ).\n`;
const metadataHook=`DATA(metadata_ref) = io->read_dataset( dependency = 'fixtures' name = 'FIXTURE_METADATA' ).\nFIELD-SYMBOLS <metadata> TYPE STANDARD TABLE. ASSIGN metadata_ref->* TO <metadata>.\n`;
definition.cells.forEach(c=>{const original=Script.unpack(c.source);if(original.language!=='script')throw Error('Operational ABAP cell '+c.id);const text=original.text.replace(/^(script version 2(?: compact)?)\n/,'$1\ndataset validation_fixture = "fixtures" named "FIXTURE_INPUT"\ndataset validation_metadata = "fixtures" named "FIXTURE_METADATA"\nfixture validation_fixture model "DEMREVID" metadata validation_metadata\n');c.source=Script.compile(text);c.dependencies.push('fixtures');});
const fixtures={...old.cells.find(c=>c.id==='fixtures')};
fixtures.source=fixtures.source.replace('io->enable_fixtures( VALUE #( ( environment = io->environment model = io->model rows = fixture_ref ) ) ).',capture+`io->enable_fixtures( fixtures = VALUE #( ( environment = io->environment model = io->model rows = fixture_ref ) )\n dimensions = bundles freeze_metadata = abap_true ).\nio->publish_dataset( name = 'FIXTURE_METADATA' rows = packets ).`);
definition.cells.unshift(fixtures);
const comparison={...old.cells.find(c=>c.id==='compare')};
comparison.source=comparison.source.replace('io->enable_fixtures( VALUE #( ( environment = io->environment model = io->model rows = complete_fixture ) ) ).',metadataHook+`io->enable_fixtures( fixtures = VALUE #( ( environment = io->environment model = io->model rows = complete_fixture ) )\n metadata = <metadata> freeze_metadata = abap_true ).`);
comparison.explanation='Compare every native dimension and exact seven-decimal amounts. Nonempty outputs required. Original code is used only as a test oracle.';
// Preserve duplicate multiplicity, but canonicalize both outputs for positional comparison.
// Original and Script native table descriptors share the same 21 fields/order.
comparison.source=comparison.source.replace("io->compare_results( name = 'REPLACEMENT' original = original-replacement notebook = <replacement> )","zcl_bn_table=>compare_ordered( io = io name = 'REPLACEMENT' original = original-replacement notebook = <replacement> )")
.replace("io->compare_results( name = 'DELTA' original = original-delta notebook = <delta> )","zcl_bn_table=>compare_ordered( io = io name = 'DELTA' original = original-delta notebook = <delta> )");
const order='account audittrail category costcentre demrevid_kfs fflas fflas_subset matconn time product_type geo_drivers doc_typ conn_reg_split lfc_win_supplier mat_group_id reg_fflas_serv ufb_dr_id matremap rsp_service_id rev_id_group signeddata';
const dynamicOrder=order.toUpperCase().split(' ').map(name=>`( name = '${name}' )`).join('\n');
const formattedOrder=order.split(' ').join('\n');
comparison.source=comparison.source.replace('DATA(replacement_comparison)',`SORT original-replacement BY\n${formattedOrder}.\nSORT original-delta BY\n${formattedOrder}.\nzcl_bn_table=>sort( EXPORTING io = io stable = abap_false order = VALUE #(\n${dynamicOrder}\n) CHANGING rows = <replacement> ).\nzcl_bn_table=>sort( EXPORTING io = io stable = abap_false order = VALUE #(\n${dynamicOrder}\n) CHANGING rows = <delta> ).\nDATA(replacement_comparison)`);
comparison.source=comparison.source.replaceAll('STEPWISE_DIFFERENCE','SCRIPT_DIFFERENCE').replaceAll('stepwise','Script');
definition.cells.push(comparison);
fs.writeFileSync(path.join(__dirname,'validation.draft.json'),JSON.stringify(definition,null,2)+'\n');
// Real-data comparison: one authorized read frozen as native fixtures for both paths.
const live=JSON.parse(JSON.stringify(definition));live.title='DEMREVID003 - Script live-data comparison';
live.cells[0].source=`" Read live facts with a separate secured adapter before entering fixture mode.
" Only backend-frozen base IDs are used; TIME is not expanded here.
io->check_data_snapshot( ).
DATA(cv) = io->current_view( ).
LOOP AT cv INTO DATA(selection).
 IF selection-dimension <> 'CATEGORY' AND selection-dimension <> 'TIME'.
  RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'VALIDATION_SCOPE'
   detail = 'This live fixture preparation accepts CATEGORY/TIME selections only'.
 ENDIF.
ENDLOOP.
DATA(periods) = io->range( 'TIME' ).
DATA(references) = io->range( 'REFERENCE_TIME' ).
APPEND LINES OF references TO periods.
SORT periods. DELETE ADJACENT DUPLICATES FROM periods.
DATA(filters) = VALUE zcl_bn_bpc=>tt_filters(
 ( dimension = 'CATEGORY' members = VALUE #( ( CONV string( io->member( 'CATEGORY' ) ) ) ) )
 ( dimension = 'TIME' members = CORRESPONDING #( periods ) ) ).
DATA(adapter) = NEW zcl_bn_bpc( environment = CONV string( io->environment )
 model = CONV string( io->model ) ).
DATA(source) = adapter->read_data( filters = filters max_rows = CONV i( io->input( 'READ_LIMIT' ) ) ).
FIELD-SYMBOLS <source> TYPE STANDARD TABLE. ASSIGN source->* TO <source>.
IF <source> IS INITIAL. RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'EMPTY_COMPARISON' detail = 'Live input is empty'. ENDIF.
${capture}
io->enable_fixtures( fixtures = VALUE #( ( environment = io->environment model = io->model rows = source ) )
 dimensions = bundles freeze_metadata = abap_true ).
io->publish_dataset( name = 'FIXTURE_METADATA' rows = packets ).
io->publish_dataset( name = 'FIXTURE_INPUT' rows = <source> ).
io->message( |Complete authorized live input retained: { lines( <source> ) } records| ).`;
fs.writeFileSync(path.join(__dirname,'live-validation.draft.json'),JSON.stringify(live,null,2)+'\n');
console.log(JSON.stringify({cells:definition.cells.length,operationalLanguage:'script',financialPosting:false}));
