CLASS ltcl_git DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS bytes_and_definition FOR TESTING RAISING zcx_bn.
    METHODS rejects_unexpected_files FOR TESTING RAISING zcx_bn.
    METHODS rejects_script_disguise FOR TESTING RAISING zcx_bn.
    METHODS rejects_bad_manifest FOR TESTING RAISING zcx_bn.
    METHODS script_export FOR TESTING RAISING zcx_bn.
    METHODS empty_and_dependencies FOR TESTING RAISING zcx_bn.
    METHODS bom_source FOR TESTING RAISING zcx_bn.
    METHODS invalid_bytes FOR TESTING RAISING zcx_bn.
    METHODS sample RETURNING VALUE(notebook) TYPE zcl_bn_types=>ty_notebook.
ENDCLASS.
CLASS ltcl_git IMPLEMENTATION.
  METHOD sample.
    notebook = VALUE #( id = 'LOCAL' revision = 7 author = 'PRIVATE' saved_at = 'PRIVATE'
      environment = 'ENV' model = 'MODEL' title = 'Allocation · É'
      cells = VALUE #( ( id = 'first' title = 'First' source = |io->message( 'É ·' ).  \r\n\r\n| ) )
      inputs = VALUE #( ( name = 'TIME' type = 'range' dimension = 'TIME' hierarchy = 'PARENTH1' required = abap_true
        selected = VALUE #( ( `PRIVATE_SELECTION` ) ) resolved = VALUE #( ( `PRIVATE_PERIOD` ) ) )
        ( name = 'flag' type = 'boolean' value = 'true' ) ) ).
  ENDMETHOD.
  METHOD bytes_and_definition.
    DATA(notebook) = sample( ).
    DATA(bundle) = zcl_bn_git=>export_bundle( notebook = notebook key = 'allocation' ).
    DATA(changed) = notebook.
    changed-revision = 88. changed-author = 'OTHER'. changed-saved_at = 'OTHER'.
    changed-inputs[ 1 ]-selected = VALUE #( ( `OTHER` ) ). changed-inputs[ 2 ]-value = 'false'.
    DATA(again) = zcl_bn_git=>export_bundle( notebook = changed key = 'allocation' ).
    cl_abap_unit_assert=>assert_equals( act = again-files exp = bundle-files ).
    DATA(restored) = zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
    cl_abap_unit_assert=>assert_equals( act = restored-cells[ 1 ]-source exp = notebook-cells[ 1 ]-source ).
    cl_abap_unit_assert=>assert_initial( restored-inputs[ 1 ]-selected ).
    cl_abap_unit_assert=>assert_initial( restored-inputs[ 1 ]-resolved ).
    cl_abap_unit_assert=>assert_initial( restored-id ).
    cl_abap_unit_assert=>assert_equals( act = restored-inputs[ 2 ]-value exp = 'false' ).
  ENDMETHOD.
  METHOD rejects_unexpected_files.
    DATA(bundle) = zcl_bn_git=>export_bundle( notebook = sample( ) key = 'allocation' ).
    APPEND VALUE #( path = 'NOTEBOOKS/allocation/../evil.abap' content_base64 = 'YQ==' ) TO bundle-files.
    TRY.
        zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
        cl_abap_unit_assert=>fail( 'Undeclared path accepted' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'GIT_FILES' ).
    ENDTRY.
    DELETE bundle-files INDEX lines( bundle-files ).
    APPEND bundle-files[ 1 ] TO bundle-files.
    TRY.
        zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
        cl_abap_unit_assert=>fail( 'Duplicate file accepted' ).
      CATCH zcx_bn INTO error.
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'GIT_FILES' ).
    ENDTRY.
  ENDMETHOD.
  METHOD rejects_script_disguise.
    DATA(notebook) = sample( ).
    notebook-cells[ 1 ]-source = '* @bn-source disguise'.
    DATA(bundle) = zcl_bn_git=>export_bundle( notebook = notebook key = 'allocation' ).
    TRY.
        zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
        cl_abap_unit_assert=>fail( 'Generated Script accepted as ABAP' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'GIT_SCRIPT_UNSUPPORTED' ).
    ENDTRY.
  ENDMETHOD.
  METHOD rejects_bad_manifest.
    DATA(bundle) = zcl_bn_git=>export_bundle( notebook = sample( ) key = 'allocation' ).
    TRY.
        zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'OTHER_ENV' ).
        cl_abap_unit_assert=>fail( 'Environment rebinding accepted' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'GIT_MANIFEST' ).
    ENDTRY.
    READ TABLE bundle-files ASSIGNING FIELD-SYMBOL(<file>) WITH KEY path = 'NOTEBOOKS/allocation/notebook.json'.
    DATA(bytes) = cl_http_utility=>decode_x_base64( <file>-content_base64 ).
    DATA(text) = cl_abap_codepage=>convert_from( source = bytes codepage = 'UTF-8' ).
    text = '{"unknown":true,' && substring( val = text off = 1 ).
    <file>-content_base64 = cl_http_utility=>encode_x_base64( cl_abap_codepage=>convert_to( source = text codepage = 'UTF-8' ) ).
    TRY.
        zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
        cl_abap_unit_assert=>fail( 'Unknown manifest field accepted' ).
      CATCH zcx_bn INTO error.
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'GIT_MANIFEST' ).
    ENDTRY.
  ENDMETHOD.
  METHOD script_export.
    DATA(notebook) = sample( ).
    notebook-cells[ 1 ]-source = |* BPC Notebook Script v1\n* @bn-source bWVzc2FnZSAieCI=\n* @bn-generated\nio->message( 'x' ).|.
    DATA(bundle) = zcl_bn_git=>export_bundle( notebook = notebook key = 'allocation' ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( bundle-files[ path = 'NOTEBOOKS/allocation/cells/first.bns' ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( bundle-files[ path = 'NOTEBOOKS/allocation/cells/first.generated.abap' ] ) ) ).
    TRY.
        zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
        cl_abap_unit_assert=>fail( 'Script imported without server transpiler' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'GIT_SCRIPT_UNSUPPORTED' ).
    ENDTRY.
  ENDMETHOD.
  METHOD empty_and_dependencies.
    DATA(notebook) = sample( ).
    APPEND VALUE #( id = 'empty' title = 'Empty' dependencies = VALUE #( ( `first` ) ) ) TO notebook-cells.
    DATA(bundle) = zcl_bn_git=>export_bundle( notebook = notebook key = 'allocation' ).
    DATA(restored) = zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
    cl_abap_unit_assert=>assert_initial( restored-cells[ 2 ]-source ).
    cl_abap_unit_assert=>assert_equals( act = restored-cells[ 2 ]-dependencies exp = notebook-cells[ 2 ]-dependencies ).
    CLEAR notebook-cells.
    bundle = zcl_bn_git=>export_bundle( notebook = notebook key = 'allocation' ).
    restored = zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
    cl_abap_unit_assert=>assert_initial( restored-cells ).
    cl_abap_unit_assert=>assert_equals( act = lines( bundle-files ) exp = 1 ).
  ENDMETHOD.
  METHOD bom_source.
    DATA(notebook) = sample( ).
    notebook-cells[ 1 ]-source = cl_abap_conv_in_ce=>uccp( 'FEFF' ) && notebook-cells[ 1 ]-source.
    DATA(bundle) = zcl_bn_git=>export_bundle( notebook = notebook key = 'allocation' ).
    DATA(restored) = zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
    cl_abap_unit_assert=>assert_equals( act = restored-cells[ 1 ]-source exp = notebook-cells[ 1 ]-source ).
  ENDMETHOD.
  METHOD invalid_bytes.
    DATA(bundle) = zcl_bn_git=>export_bundle( notebook = sample( ) key = 'allocation' ).
    READ TABLE bundle-files ASSIGNING FIELD-SYMBOL(<file>) WITH KEY path = 'NOTEBOOKS/allocation/cells/first.abap'.
    <file>-content_base64 = 'wyg='.
    TRY.
        zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
        cl_abap_unit_assert=>fail( 'Corrupt UTF-8 accepted' ).
      CATCH zcx_bn INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'GIT_ENCODING' ).
    ENDTRY.
    <file>-content_base64 = 'YQ='.
    TRY.
        zcl_bn_git=>decode_bundle( files = bundle-files key = bundle-key environment = 'ENV' ).
        cl_abap_unit_assert=>fail( 'Noncanonical base64 accepted' ).
      CATCH zcx_bn INTO error.
        cl_abap_unit_assert=>assert_equals( act = error->code exp = 'GIT_ENCODING' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
