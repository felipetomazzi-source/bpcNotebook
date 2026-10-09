CLASS zcl_bn_types DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES tt_ids TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_fiscal_link,
             dimension TYPE string, member TYPE string, prior TYPE string, next TYPE string,
           END OF ty_fiscal_link,
           tt_fiscal_links TYPE STANDARD TABLE OF ty_fiscal_link WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_checkpoint,
      name TYPE string, state TYPE string, started_at TYPE string, finished_at TYPE string,
      duration_us TYPE i, inputs TYPE tt_ids, outputs TYPE tt_ids,
    END OF ty_checkpoint, tt_checkpoints TYPE STANDARD TABLE OF ty_checkpoint WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_input,
             name TYPE string, type TYPE string, value TYPE string,
             dimension TYPE string, hierarchy TYPE string, required TYPE abap_bool,
             selected TYPE tt_ids, resolved TYPE tt_ids,
             purpose TYPE string, lookback_from TYPE string, lookback_steps TYPE i, fiscal_links TYPE tt_fiscal_links,
           END OF ty_input,
           tt_inputs TYPE STANDARD TABLE OF ty_input WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_ref,
             run_id TYPE string, cell_id TYPE string, revision TYPE i,
             row_count TYPE i, stale TYPE abap_bool,
           END OF ty_ref.
    TYPES: BEGIN OF ty_cell,
             id TYPE string, title TYPE string, source TYPE string,
             dependencies TYPE tt_ids, source_version TYPE i,
             checksum TYPE string, output TYPE ty_ref, explanation TYPE string,
           END OF ty_cell,
           tt_cells TYPE STANDARD TABLE OF ty_cell WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_notebook,
             id TYPE string, title TYPE string, revision TYPE i,
             environment TYPE string, model TYPE string,
             author TYPE string, saved_at TYPE string,
             checksum TYPE string, inputs TYPE tt_inputs, cells TYPE tt_cells, explanation TYPE string,
           END OF ty_notebook,
           tt_notebooks TYPE STANDARD TABLE OF ty_notebook WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_message,
             cell_id TYPE string, severity TYPE string, text TYPE string,
           END OF ty_message,
           tt_messages TYPE STANDARD TABLE OF ty_message WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_result,
             cell_id TYPE string, run_id TYPE string, revision TYPE i,
             row_count TYPE i, duration_ms TYPE i, checksum TYPE string, created_at TYPE string,
           END OF ty_result,
           tt_results TYPE STANDARD TABLE OF ty_result WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_binding,
             cell_id TYPE string, run_id TYPE string, revision TYPE i,
           END OF ty_binding,
           tt_bindings TYPE STANDARD TABLE OF ty_binding WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_error,
             code TYPE string, message TYPE string,
           END OF ty_error.
    TYPES: BEGIN OF ty_diagnostic,
             cell_id TYPE string, severity TYPE string, line TYPE i, generated_line TYPE i,
             word TYPE string, message TYPE string,
           END OF ty_diagnostic,
           tt_diagnostics TYPE STANDARD TABLE OF ty_diagnostic WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_run,
             id TYPE string, owner TYPE string, notebook_id TYPE string,
             state TYPE string, scope TYPE string,
             job_name TYPE btcjob, job_id TYPE btcjobcnt,
             native TYPE abap_bool, fixture_mode TYPE abap_bool, created_at TYPE string,
             started_at TYPE string, finished_at TYPE string,
             progress TYPE decfloat34, duration_ms TYPE i,
             cancel_requested TYPE abap_bool, checksum TYPE string,
             deadline TYPE timestampl,
             handler TYPE string, handler_revision TYPE i,
             logic_parameters TYPE ujk_t_script_logic_hashtable, current_view TYPE ujk_t_cv,
             snapshot TYPE ty_notebook, bindings TYPE tt_bindings,
             frozen_bindings TYPE tt_bindings,
             messages TYPE tt_messages, results TYPE tt_results, checkpoints TYPE tt_checkpoints,
             diagnostics TYPE tt_diagnostics, checkpoint_cell TYPE string,
             error TYPE ty_error,
           END OF ty_run,
           tt_runs TYPE STANDARD TABLE OF ty_run WITH DEFAULT KEY.
    CLASS-METHODS json IMPORTING data TYPE any RETURNING VALUE(result) TYPE string.
    CLASS-METHODS hash IMPORTING text TYPE string RETURNING VALUE(result) TYPE string RAISING zcx_bn.
    CLASS-METHODS timestamp RETURNING VALUE(result) TYPE string.
    CLASS-METHODS uuid RETURNING VALUE(result) TYPE string RAISING zcx_bn.
    CLASS-METHODS normalize_inputs IMPORTING inputs TYPE tt_inputs RETURNING VALUE(result) TYPE tt_inputs.
ENDCLASS.
CLASS zcl_bn_types IMPLEMENTATION.
  METHOD json.
    result = /ui2/cl_json=>serialize( data = data
      pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
    " Some installed /UI2 serializers leave raw CR/control characters inside strings.
    " Preserve existing JSON/hash bytes unless a raw control requires repair.
    FIND REGEX '[[:cntrl:]]' IN result.
    IF sy-subrc = 0.
      TYPES: BEGIN OF ty_control, character TYPE string, escaped TYPE string, END OF ty_control.
      DATA controls TYPE HASHED TABLE OF ty_control WITH UNIQUE KEY character.
      DO 32 TIMES.
        DATA hex TYPE x LENGTH 2.
        hex = sy-index - 1.
        INSERT VALUE #( character = cl_abap_conv_in_ce=>uccp( hex ) escaped = '\u' && |{ hex }| ) INTO TABLE controls.
      ENDDO.
      DATA pieces TYPE STANDARD TABLE OF string WITH EMPTY KEY.
      DATA in_string TYPE abap_bool.
      DATA escaped TYPE abap_bool.
      DO strlen( result ) TIMES.
        DATA(offset) = sy-index - 1.
        DATA(character) = substring( val = result off = offset len = 1 ).
        IF character = '"' AND escaped = abap_false. in_string = xsdbool( in_string = abap_false ). ENDIF.
        READ TABLE controls INTO DATA(control) WITH TABLE KEY character = character.
        APPEND COND #( WHEN in_string = abap_true AND sy-subrc = 0 THEN control-escaped ELSE character ) TO pieces.
        IF character = '\' AND in_string = abap_true AND escaped = abap_false.
          escaped = abap_true.
        ELSE.
          escaped = abap_false.
        ENDIF.
      ENDDO.
      result = concat_lines_of( table = pieces ).
    ENDIF.
    " Preserve checksums for snapshots saved before reference/checkpoint fields existed.
    REPLACE ALL OCCURRENCES OF ',"purpose":"","lookbackFrom":"","lookbackSteps":0,"fiscalLinks":[]' IN result WITH ''.
    REPLACE ALL OCCURRENCES OF ',"checkpoints":[]' IN result WITH ''.
    REPLACE ALL OCCURRENCES OF ',"explanation":""' IN result WITH ''.
    REPLACE ALL OCCURRENCES OF ',"artifacts":[]' IN result WITH ''.
    REPLACE ALL OCCURRENCES OF ',"datasetReads":[]' IN result WITH ''.
  ENDMETHOD.
  METHOD hash.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING if_algorithm = 'SHA-256' if_data = text
          IMPORTING ef_hashstring = result ).
      CATCH cx_abap_message_digest INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'HASH' detail = error->get_text( ) status = 500.
    ENDTRY.
  ENDMETHOD.
  METHOD timestamp.
    DATA stamp TYPE timestampl.
    GET TIME STAMP FIELD stamp.
    result = |{ stamp TIMESTAMP = ISO }Z|.
  ENDMETHOD.
  METHOD uuid.
    TRY.
        result = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'UUID' detail = error->get_text( ) status = 500.
    ENDTRY.
  ENDMETHOD.
  METHOD normalize_inputs.
    result = inputs.
    LOOP AT result ASSIGNING FIELD-SYMBOL(<input>).
      IF <input>-type = 'boolean'.
        IF <input>-value = 'X'. <input>-value = 'true'.
        ELSEIF <input>-value IS INITIAL. <input>-value = 'false'. ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
