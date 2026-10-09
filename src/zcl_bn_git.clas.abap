CLASS zcl_bn_git DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_file,
             path TYPE string, content_base64 TYPE string,
           END OF ty_file,
           tt_files TYPE STANDARD TABLE OF ty_file WITH DEFAULT KEY,
           BEGIN OF ty_input,
             name TYPE string, type TYPE string, dimension TYPE string, hierarchy TYPE string,
             required TYPE abap_bool, purpose TYPE string, lookback_from TYPE string, lookback_steps TYPE i,
           END OF ty_input,
           tt_inputs TYPE STANDARD TABLE OF ty_input WITH DEFAULT KEY,
           BEGIN OF ty_cell,
             id TYPE string, title TYPE string, language TYPE string, source_file TYPE string,
             generated_file TYPE string, dependencies TYPE zcl_bn_types=>tt_ids,
           END OF ty_cell,
           tt_cells TYPE STANDARD TABLE OF ty_cell WITH DEFAULT KEY,
           BEGIN OF ty_manifest,
             contract_version TYPE i, key TYPE string, title TYPE string,
             environment TYPE string, model TYPE string, inputs TYPE tt_inputs, cells TYPE tt_cells,
           END OF ty_manifest,
           BEGIN OF ty_bundle,
             key TYPE string, title TYPE string, model TYPE string, revision TYPE i, files TYPE tt_files,
           END OF ty_bundle,
           tt_bundles TYPE STANDARD TABLE OF ty_bundle WITH DEFAULT KEY.
    CLASS-METHODS dispatch IMPORTING operation TYPE string request TYPE string
      RETURNING VALUE(json) TYPE string RAISING zcx_bn.
    " Pure codecs exposed for native round-trip validation; no persistence or execution.
    CLASS-METHODS export_bundle IMPORTING notebook TYPE zcl_bn_types=>ty_notebook key TYPE string
      RETURNING VALUE(bundle) TYPE ty_bundle RAISING zcx_bn.
    CLASS-METHODS decode_bundle IMPORTING files TYPE tt_files key TYPE string environment TYPE string
      RETURNING VALUE(notebook) TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_request,
             contract_version TYPE i, environment TYPE string, model TYPE string, key TYPE string,
             expected_revision TYPE i, source_commit TYPE string, files TYPE tt_files,
           END OF ty_request,
           BEGIN OF ty_mapping,
             key TYPE string, notebook_id TYPE string,
           END OF ty_mapping,
           BEGIN OF ty_provenance,
             key TYPE string, path TYPE string, source_commit TYPE string,
             notebook_id TYPE string, notebook_revision TYPE i, bundle_hash TYPE string,
           END OF ty_provenance,
           BEGIN OF ty_response,
             contract_version TYPE i, can_import TYPE abap_bool, validation_error TYPE string,
             revision TYPE i, notebook_id TYPE string,
           END OF ty_response.
    CLASS-METHODS encode IMPORTING text TYPE string RETURNING VALUE(result) TYPE string RAISING zcx_bn.
    CLASS-METHODS decode IMPORTING encoded TYPE string RETURNING VALUE(result) TYPE string RAISING zcx_bn.
    CLASS-METHODS validate_key IMPORTING key TYPE string RAISING zcx_bn.
    CLASS-METHODS target IMPORTING key TYPE string RETURNING VALUE(id) TYPE string RAISING zcx_bn.
    CLASS-METHODS validate_target IMPORTING req TYPE ty_request CHANGING notebook TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_git IMPLEMENTATION.
  METHOD validate_key.
    FIND REGEX '^[A-Za-z0-9_-]{1,64}$' IN key.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_KEY' detail = 'Invalid stable notebook key'.
    ENDIF.
  ENDMETHOD.
  METHOD encode.
    TRY.
        DATA(bytes) = cl_abap_codepage=>convert_to( source = text codepage = 'UTF-8' ).
        result = cl_http_utility=>encode_x_base64( bytes ).
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_ENCODING' detail = error->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD decode.
    IF strlen( encoded ) > 1200000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_SIZE' detail = 'File exceeds the bundle limit'.
    ENDIF.
    FIND REGEX '^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$' IN encoded.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_ENCODING' detail = 'Canonical base64 required'.
    ENDIF.
    TRY.
        DATA(bytes) = cl_http_utility=>decode_x_base64( encoded ).
        IF xstrlen( bytes ) >= 3 AND bytes(3) = 'EFBBBF'.
          result = cl_abap_conv_in_ce=>uccp( 'FEFF' ) &&
            cl_abap_codepage=>convert_from( source = bytes+3 codepage = 'UTF-8' ).
        ELSE.
          result = cl_abap_codepage=>convert_from( source = bytes codepage = 'UTF-8' ).
        ENDIF.
        IF encode( result ) <> encoded.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_ENCODING'
            detail = 'UTF-8 bytes cannot be preserved exactly by this SAP converter'.
        ENDIF.
        IF result CS cl_abap_char_utilities=>minchar.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_ENCODING' detail = 'Null characters are not source text'.
        ENDIF.
      CATCH zcx_bn INTO DATA(fault).
        RAISE EXCEPTION fault.
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_ENCODING' detail = error->get_text( ).
    ENDTRY.
  ENDMETHOD.
  METHOD export_bundle.
    validate_key( key ).
    DATA(root) = |NOTEBOOKS/{ key }/|.
    DATA manifest TYPE ty_manifest.
    manifest-contract_version = 1. manifest-key = key. manifest-title = notebook-title.
    manifest-environment = notebook-environment. manifest-model = notebook-model.
    manifest-inputs = CORRESPONDING #( notebook-inputs ).
    bundle-key = key. bundle-title = notebook-title. bundle-model = notebook-model. bundle-revision = notebook-revision.
    LOOP AT notebook-cells INTO DATA(cell).
      FIND REGEX '^[A-Za-z][A-Za-z0-9_-]{0,29}$' IN cell-id.
      IF sy-subrc <> 0 OR line_exists( manifest-cells[ id = cell-id ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_CELL' detail = 'Invalid or duplicate cell ID'.
      ENDIF.
      DATA(item) = VALUE ty_cell( id = cell-id title = cell-title language = 'abap'
        source_file = |cells/{ cell-id }.abap| dependencies = cell-dependencies ).
      DATA(source) = cell-source.
      " Browser-generated Script v1 embeds exact author bytes in comment lines.
      IF source CS '* BPC Notebook Script v1' AND source CS '* @bn-generated'.
        DATA script_lines TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
        SPLIT source AT cl_abap_char_utilities=>newline INTO TABLE script_lines.
        DATA encoded TYPE string.
        CLEAR encoded.
        DATA(found) = abap_false.
        IF script_lines[ 1 ] = '* BPC Notebook Script v1'.
          LOOP AT script_lines INTO DATA(line) FROM 2.
            IF line = '* @bn-generated'. found = abap_true. EXIT. ENDIF.
            IF line NP '* @bn-source *'. CLEAR encoded. EXIT. ENDIF.
            encoded = encoded && substring( val = line off = 13 ).
          ENDLOOP.
        ENDIF.
        IF found = abap_true.
          source = decode( encoded ). item-language = 'script'.
          item-source_file = |cells/{ cell-id }.bns|. item-generated_file = |cells/{ cell-id }.generated.abap|.
          APPEND VALUE #( path = root && item-generated_file content_base64 = encode( cell-source ) ) TO bundle-files.
        ENDIF.
      ENDIF.
      APPEND item TO manifest-cells.
      APPEND VALUE #( path = root && item-source_file content_base64 = encode( source ) ) TO bundle-files.
    ENDLOOP.
    APPEND VALUE #( path = root && 'notebook.json' content_base64 = encode( zcl_bn_types=>json( manifest ) ) ) TO bundle-files.
    SORT bundle-files BY path.
  ENDMETHOD.
  METHOD decode_bundle.
    validate_key( key ).
    IF lines( files ) < 1 OR lines( files ) > 61.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_SIZE' detail = 'Bundle must contain one manifest and at most 30 cells'.
    ENDIF.
    DATA(root) = |NOTEBOOKS/{ key }/|.
    DATA(paths) = VALUE zcl_bn_types=>tt_ids( ).
    DATA(total) = 0.
    LOOP AT files INTO DATA(file).
      total = total + strlen( file-content_base64 ).
      IF total > 4000000 OR line_exists( paths[ table_line = file-path ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_FILES' detail = 'Oversized bundle or duplicate file path'.
      ENDIF.
      APPEND file-path TO paths.
    ENDLOOP.
    READ TABLE files INTO file WITH KEY path = root && 'notebook.json'.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_MANIFEST' detail = 'Notebook manifest is missing'.
    ENDIF.
    DATA(text) = decode( file-content_base64 ).
    DATA manifest TYPE ty_manifest.
    /ui2/cl_json=>deserialize( EXPORTING json = text pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = manifest ).
    " Canonical schema rejects unknown fields, runtime inputs and forged metadata.
    IF text <> zcl_bn_types=>json( manifest ) OR manifest-contract_version <> 1 OR manifest-key <> key
      OR manifest-environment <> environment OR manifest-model IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_MANIFEST'
        detail = 'Canonical contract v1 manifest and matching target environment required'.
    ENDIF.
    notebook-title = manifest-title. notebook-environment = environment. notebook-model = manifest-model.
    notebook-inputs = CORRESPONDING #( manifest-inputs ).
    LOOP AT notebook-inputs ASSIGNING FIELD-SYMBOL(<input>).
      CASE <input>-type.
        WHEN 'number'.
          <input>-value = COND #( WHEN <input>-name = 'RUN_SECONDS' THEN '600'
            WHEN <input>-name = 'READ_LIMIT' THEN '100000'
            WHEN <input>-name = 'WORK_ROWS' THEN '1000000'
            WHEN <input>-name = 'PREVIEW_ROWS' THEN '200' ELSE '0' ).
        WHEN 'boolean'. <input>-value = 'false'.
      ENDCASE.
    ENDLOOP.
    DELETE paths WHERE table_line = root && 'notebook.json'.
    LOOP AT manifest-cells INTO DATA(item).
      FIND REGEX '^[A-Za-z][A-Za-z0-9_-]{0,29}$' IN item-id.
      IF sy-subrc <> 0 OR line_exists( notebook-cells[ id = item-id ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_CELL' detail = 'Invalid or duplicate cell ID'.
      ENDIF.
      IF item-language <> 'abap' OR item-generated_file IS NOT INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_SCRIPT_UNSUPPORTED'
          detail = 'Script import requires a supported server transpiler; export and Git diff remain available'.
      ENDIF.
      IF item-source_file <> |cells/{ item-id }.abap|.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_PATH' detail = 'Source path must match the cell ID'.
      ENDIF.
      READ TABLE files INTO file WITH KEY path = root && item-source_file.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_FILES' detail = 'Cell source file is missing'.
      ENDIF.
      DATA(source) = decode( file-content_base64 ).
      IF source CS 'BPC Notebook Script v1' OR source CS '* @bn-source' OR source CS '* @bn-generated'.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_SCRIPT_UNSUPPORTED' detail = 'Script envelopes cannot be imported as ABAP'.
      ENDIF.
      APPEND VALUE #( id = item-id title = item-title source = source dependencies = item-dependencies ) TO notebook-cells.
      DELETE paths WHERE table_line = root && item-source_file.
    ENDLOOP.
    IF paths IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_FILES' detail = 'Unexpected or undeclared bundle files'.
    ENDIF.
  ENDMETHOD.
  METHOD target.
    IF zcl_bn_store=>current( kind = 'G' id = key ) > 0.
      DATA(mapping_json) = zcl_bn_store=>read( kind = 'G' id = key ).
      DATA mapping TYPE ty_mapping.
      /ui2/cl_json=>deserialize( EXPORTING json = mapping_json pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = mapping ).
      IF mapping-key <> key OR mapping-notebook_id IS INITIAL.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_MAPPING' detail = 'Invalid notebook identity mapping'.
      ENDIF.
      id = mapping-notebook_id.
    ELSEIF zcl_bn_store=>current( kind = 'N' id = key ) > 0.
      id = key.
    ENDIF.
  ENDMETHOD.
  METHOD validate_target.
    notebook-id = target( req-key ).
    DATA current TYPE zcl_bn_types=>ty_notebook.
    IF notebook-id IS NOT INITIAL.
      current = zcl_bn_service=>get_notebook( notebook-id ).
      IF current-environment <> notebook-environment OR current-model <> notebook-model.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_CONTEXT' detail = 'Existing notebook environment/model must match'.
      ENDIF.
    ENDIF.
    IF current-revision <> req-expected_revision OR req-expected_revision < 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CONFLICT' detail = 'Notebook changed; preview again' status = 409.
    ENDIF.
    " Runtime scalar values stay local only when their definition is identical.
    " Member selections are cleared, then revalidated by the next execution.
    LOOP AT notebook-inputs ASSIGNING FIELD-SYMBOL(<input>) WHERE type <> 'member' AND type <> 'range'.
      READ TABLE current-inputs INTO DATA(old) WITH KEY name = <input>-name.
      IF sy-subrc = 0 AND CORRESPONDING ty_input( old ) = CORRESPONDING ty_input( <input> ).
        <input>-value = old-value.
      ENDIF.
    ENDLOOP.
    zcl_bn_service=>validate_definition( CHANGING notebook = notebook ).
  ENDMETHOD.
  METHOD dispatch.
    IF strlen( request ) > 4500000.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_SIZE' detail = 'Git request exceeds the server limit' status = 413.
    ENDIF.
    zcl_bn_service=>authorize( COND #( WHEN operation = 'IMPORT' OR operation = 'PREVIEW' THEN '02' ELSE '03' ) ).
    DATA req TYPE ty_request.
    /ui2/cl_json=>deserialize( EXPORTING json = request pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = req ).
    IF req-contract_version <> 1 OR req-environment IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_CONTRACT' detail = 'contractVersion=1 and environment required'.
    ENDIF.
    zcl_bn_bpc=>metadata( kind = 'models' environment = req-environment model = '' dimension = '' hierarchy = '' search = '' ).
    CASE operation.
      WHEN 'CAPABILITIES'.
        TYPES: BEGIN OF ty_capabilities,
                 contract_version TYPE i, abap_import TYPE abap_bool, script_export TYPE abap_bool,
                 script_import TYPE abap_bool, canonical_manifest TYPE abap_bool,
                 caller_transaction TYPE abap_bool, max_bundle_base64 TYPE i,
               END OF ty_capabilities.
        json = zcl_bn_types=>json( VALUE ty_capabilities( contract_version = 1 abap_import = abap_true
          script_export = abap_true canonical_manifest = abap_true caller_transaction = abap_true max_bundle_base64 = 4000000 ) ).
      WHEN 'LIST'.
        TYPES: BEGIN OF ty_list,
                 contract_version TYPE i, bundles TYPE tt_bundles,
               END OF ty_list.
        DATA listing TYPE ty_list.
        listing-contract_version = 1.
        DATA mappings TYPE STANDARD TABLE OF ty_mapping WITH DEFAULT KEY.
        LOOP AT zcl_bn_store=>documents( 'G' ) INTO DATA(mapping_doc).
          DATA mapping TYPE ty_mapping.
          CLEAR mapping.
          /ui2/cl_json=>deserialize( EXPORTING json = mapping_doc-payload pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = mapping ).
          APPEND mapping TO mappings.
        ENDLOOP.
        LOOP AT zcl_bn_store=>heads( 'N' ) INTO DATA(id).
          IF zcl_bn_store=>current( kind = 'A' id = id ) > 0. CONTINUE. ENDIF.
          DATA(notebook) = zcl_bn_service=>get_notebook( id ).
          IF notebook-environment <> req-environment OR ( req-model IS NOT INITIAL AND notebook-model <> req-model ). CONTINUE. ENDIF.
          " Recheck current BPC model access, not only document ownership.
          DATA(adapter) = NEW zcl_bn_bpc( environment = notebook-environment model = notebook-model ).
          DATA(key) = id.
          READ TABLE mappings INTO mapping WITH KEY notebook_id = id.
          IF sy-subrc = 0. key = mapping-key. ENDIF.
          APPEND export_bundle( notebook = notebook key = key ) TO listing-bundles.
        ENDLOOP.
        SORT listing-bundles BY key.
        json = zcl_bn_types=>json( listing ).
      WHEN 'PREVIEW' OR 'IMPORT'.
        DATA response TYPE ty_response.
        response-contract_version = 1. response-revision = req-expected_revision.
        TRY.
            validate_key( req-key ).
            FIND REGEX '^([0-9a-f]{40}|[0-9a-f]{64})$' IN req-source_commit.
            IF sy-subrc <> 0.
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_COMMIT' detail = 'Full lowercase source commit hash required'.
            ENDIF.
            notebook = decode_bundle( files = req-files key = req-key environment = req-environment ).
            IF req-model IS NOT INITIAL AND req-model <> notebook-model.
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_CONTEXT' detail = 'Requested model differs from manifest'.
            ENDIF.
            validate_target( EXPORTING req = req CHANGING notebook = notebook ).
            IF operation = 'IMPORT'.
              IF notebook-id IS NOT INITIAL.
                DATA(locked_revision) = zcl_bn_store=>lock_notebook( notebook-id ).
                IF locked_revision <> req-expected_revision.
                  RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CONFLICT' detail = 'Notebook changed during validation' status = 409.
                ENDIF.
              ENDIF.
              notebook = zcl_bn_service=>import_definition( notebook = notebook expected = req-expected_revision ).
              IF zcl_bn_store=>current( kind = 'G' id = req-key ) = 0.
                zcl_bn_store=>write( kind = 'G' id = req-key expected = 0
                  payload = zcl_bn_types=>json( VALUE ty_mapping( key = req-key notebook_id = notebook-id ) ) ).
              ENDIF.
              DATA(provenance_revision) = zcl_bn_store=>current( kind = 'V' id = notebook-id ).
              DATA ordered_files TYPE tt_files.
              ordered_files = req-files. SORT ordered_files BY path.
              zcl_bn_store=>write( kind = 'V' id = notebook-id expected = provenance_revision
                payload = zcl_bn_types=>json( VALUE ty_provenance( key = req-key path = |NOTEBOOKS/{ req-key }/|
                  source_commit = req-source_commit notebook_id = notebook-id notebook_revision = notebook-revision
                  bundle_hash = zcl_bn_types=>hash( zcl_bn_types=>json( ordered_files ) ) ) ) ).
              response-revision = notebook-revision.
            ENDIF.
            response-can_import = abap_true. response-notebook_id = notebook-id.
          CATCH zcx_bn INTO DATA(error).
            " IMPORT failures propagate so caller must roll back the entire LUW.
            IF operation = 'IMPORT'. RAISE EXCEPTION error. ENDIF.
            response-validation_error = |{ error->code }: { error->detail }|.
          CATCH cx_root INTO DATA(unexpected).
            IF operation = 'IMPORT'.
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_REQUEST' detail = unexpected->get_text( ).
            ENDIF.
            response-validation_error = |GIT_REQUEST: { unexpected->get_text( ) }|.
        ENDTRY.
        json = zcl_bn_types=>json( response ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'GIT_OPERATION' detail = 'Unsupported Git operation'.
    ENDCASE.
    " No COMMIT, ROLLBACK, transport recording, execution or handler rebinding.
  ENDMETHOD.
ENDCLASS.
