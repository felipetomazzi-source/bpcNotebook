CLASS zcl_bn_dem_validation DEFINITION PUBLIC FINAL CREATE PUBLIC.
 PUBLIC SECTION.
  INTERFACES zif_bpc_validation_reader.
  METHODS constructor IMPORTING io TYPE REF TO zcl_bn_context RAISING zcx_bn.
  CLASS-METHODS execute IMPORTING io TYPE REF TO zcl_bn_context RAISING zcx_bn.
 PRIVATE SECTION. DATA context TYPE REF TO zcl_bn_context.
ENDCLASS.
CLASS zcl_bn_dem_validation IMPLEMENTATION.
 METHOD constructor.
  IF io IS NOT BOUND OR io->fixture_mode <> abap_true.
   RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FIXTURE_MODE' detail = 'Install native fixtures before constructing the original reader'.
  ENDIF.
  context = io.
 ENDMETHOD.
 METHOD zif_bpc_validation_reader~fixture_mode. enabled = context->fixture_mode. ENDMETHOD.
 METHOD zif_bpc_validation_reader~check_budget. context->check_budget( ). ENDMETHOD.
 METHOD zif_bpc_validation_reader~offset_period.
  result = context->offset_period( member = member offset_by = offset_by ).
 ENDMETHOD.
 METHOD zif_bpc_validation_reader~read_model.
  IF model <> context->model.
   RAISE EXCEPTION TYPE zcx_bpc_validation EXPORTING code = 'FIXTURE_MISSING' detail = 'Unexpected original calculation model'.
  ENDIF.
  " Same generic reader and frozen scope; the original retains its own native transformations.
  DATA(data) = NEW zcl_bn_dem_model( environment = context filters = filters compressed = abap_false ).
  CREATE DATA rows LIKE data->model_data.
  FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN rows->* TO <rows>.
  <rows> = data->model_data.
 ENDMETHOD.
 METHOD execute.
  DATA(original_context) = io->fixture_copy( 'original' ).
  DATA(notebook_context) = io->fixture_copy( 'notebook' ).
  DATA(reader) = NEW zcl_bn_dem_validation( original_context ).
  DATA(parameters) = original_context->script_parameters( ).
  LOOP AT parameters ASSIGNING FIELD-SYMBOL(<flag>).
   CASE <flag>-hashkey.
    WHEN 'FFLASMATGROUPS'.
     CASE <flag>-hashvalue. WHEN 'true'. <flag>-hashvalue = '1'. WHEN 'false'. <flag>-hashvalue = '0'. ENDCASE.
    WHEN 'DEBUG'.
     CASE <flag>-hashvalue. WHEN 'true'. <flag>-hashvalue = 'ON'. WHEN 'false'. <flag>-hashvalue = 'OFF'. ENDCASE.
   ENDCASE.
  ENDLOOP.
  DATA(original) = zcl_bpc_demrevid_calc_003=>validate_with_reader(
   reader = reader it_param = parameters current_view = original_context->current_view( ) ).
  DATA(notebook) = zcl_bn_dem_alloc=>validate_fixtures( notebook_context ).
  DATA(replacement) = io->compare_results( name = 'REPLACEMENT' original = original-replacement notebook = notebook-replacement ).
  DATA(delta) = io->compare_results( name = 'DELTA' original = original-delta notebook = notebook-delta ).
  io->include_fixture_outputs( context = original_context prefix = 'ORIGINAL' ).
  io->include_fixture_outputs( context = notebook_context prefix = 'NOTEBOOK' ).
  IF replacement-original_rows = 0 OR replacement-notebook_rows = 0.
   io->message( 'EMPTY RESULT: full business equivalence is not established' ).
  ENDIF.
  IF replacement-added + replacement-missing + replacement-changed + delta-added + delta-missing + delta-changed > 0.
   io->message( 'DIFFERENCES: review every complete-key difference before accepting the conversion' ).
  ELSE.
   io->message( 'Exact comparison matched for this fixture only; review fixture path coverage separately' ).
  ENDIF.
 ENDMETHOD.
ENDCLASS.
