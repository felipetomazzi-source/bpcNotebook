CLASS zcl_bn_identity DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_identity,
             technical_name TYPE string, description TYPE string, identity_revision TYPE i,
           END OF ty_identity.
    TYPES BEGIN OF ty_view.
    INCLUDE TYPE zcl_bn_types=>ty_notebook.
    INCLUDE TYPE ty_identity.
    TYPES END OF ty_view.
    CLASS-METHODS get IMPORTING id TYPE string RETURNING VALUE(result) TYPE ty_identity RAISING zcx_bn.
    CLASS-METHODS view IMPORTING notebook TYPE zcl_bn_types=>ty_notebook RETURNING VALUE(result) TYPE ty_view RAISING zcx_bn.
    CLASS-METHODS assign IMPORTING notebook TYPE zcl_bn_types=>ty_notebook technical_name TYPE string
      description TYPE string expected TYPE i RETURNING VALUE(result) TYPE ty_identity RAISING zcx_bn.
    CLASS-METHODS reserve IMPORTING notebook TYPE zcl_bn_types=>ty_notebook technical_name TYPE string RAISING zcx_bn.
    CLASS-METHODS resolve IMPORTING environment TYPE string model TYPE string technical_name TYPE string approved_revision TYPE i
      RETURNING VALUE(notebook) TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_key, environment TYPE string, model TYPE string, technical_name TYPE string, END OF ty_key.
    CLASS-METHODS key IMPORTING environment TYPE string model TYPE string technical_name TYPE string RETURNING VALUE(result) TYPE string RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_identity IMPLEMENTATION.
  METHOD key.
    result = zcl_bn_types=>hash( zcl_bn_types=>json( VALUE ty_key( environment = environment model = model technical_name = technical_name ) ) ).
  ENDMETHOD.
  METHOD get.
    IF zcl_bn_store=>current( kind = 'I' id = id ) = 0. RETURN. ENDIF.
    DATA(payload) = zcl_bn_store=>read( kind = 'I' id = id ).
    /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( payload ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = result ).
  ENDMETHOD.
  METHOD view.
    result = CORRESPONDING #( notebook ).
    DATA(identity) = get( notebook-id ).
    result-technical_name = identity-technical_name. result-description = identity-description.
    result-identity_revision = identity-identity_revision.
  ENDMETHOD.
  METHOD reserve.
    zcl_bn_service=>authorize( '02' ).
    DATA(current_notebook) = zcl_bn_service=>get_notebook( notebook-id ).
    IF current_notebook-environment <> notebook-environment OR current_notebook-model <> notebook-model.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'IDENTITY_SCOPE' detail = 'Identity reservation must use the saved notebook context' status = 409.
    ENDIF.
    DATA(registry_id) = key( environment = notebook-environment model = notebook-model technical_name = technical_name ).
    SELECT SINGLE owner FROM zbn_head INTO @DATA(owner) WHERE kind = 'T' AND id = @registry_id.
    IF sy-subrc = 0.
      IF owner <> sy-uname.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NAME_TAKEN' detail = 'Technical name is reserved in this environment/model' status = 409.
      ENDIF.
      DATA(payload) = zcl_bn_store=>read( kind = 'T' id = registry_id ).
      DATA registered_id TYPE string.
      /ui2/cl_json=>deserialize( EXPORTING json = payload CHANGING data = registered_id ).
      IF registered_id <> notebook-id.
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NAME_TAKEN' detail = 'Technical name is reserved in this environment/model' status = 409.
      ENDIF.
      RETURN.
    ENDIF.
    zcl_bn_store=>write( kind = 'T' id = registry_id payload = zcl_bn_types=>json( notebook-id ) expected = 0 ).
  ENDMETHOD.
  METHOD assign.
    zcl_bn_service=>authorize( '02' ).
    DATA(notebook_revision) = zcl_bn_store=>lock_notebook( notebook-id ).
    IF notebook_revision <> notebook-revision.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CONFLICT' detail = 'Identity assignment requires the current saved notebook revision' status = 409.
    ENDIF.
    zcl_bn_service=>get_notebook( notebook-id ).
    FIND REGEX '^[A-Z][A-Z0-9_]{0,29}$' IN technical_name.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'TECHNICAL_NAME' detail = 'Technical name: 1 to 30 uppercase letters, digits or underscores; start with a letter'.
    ENDIF.
    FIND REGEX '[^[:space:]]' IN description.
    IF sy-subrc <> 0 OR strlen( description ) > 240.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DESCRIPTION' detail = 'Description is required (maximum 240 characters)'.
    ENDIF.
    FIND REGEX '[[:cntrl:]]' IN description.
    IF sy-subrc = 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DESCRIPTION' detail = 'Description must be single-line text'.
    ENDIF.
    result = get( notebook-id ).
    IF result-identity_revision <> expected.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CONFLICT' detail = 'Identity changed; reopen identity dialog' status = 409.
    ENDIF.
    IF result-technical_name IS NOT INITIAL AND result-technical_name <> technical_name.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NAME_IMMUTABLE' detail = 'Assigned technical names cannot be changed' status = 409.
    ENDIF.
    reserve( notebook = notebook technical_name = technical_name ).
    result-technical_name = technical_name. result-description = description. result-identity_revision = expected + 1.
    zcl_bn_store=>write( kind = 'I' id = notebook-id payload = zcl_bn_types=>json( result ) expected = expected ).
  ENDMETHOD.
  METHOD resolve.
    zcl_bn_service=>authorize( '03' ).
    IF approved_revision < 1.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'APPROVED_REVISION' detail = 'An explicit saved revision is required'.
    ENDIF.
    DATA(registry_id) = key( environment = environment model = model technical_name = technical_name ).
    DATA(payload) = zcl_bn_store=>read( kind = 'T' id = registry_id ).
    DATA notebook_id TYPE string.
    /ui2/cl_json=>deserialize( EXPORTING json = payload CHANGING data = notebook_id ).
    zcl_bn_service=>get_notebook( notebook_id ).
    payload = zcl_bn_store=>read( kind = 'N' id = notebook_id revision = approved_revision ).
    /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( payload ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = notebook ).
    DATA(identity) = get( notebook_id ).
    IF notebook-environment <> environment OR notebook-model <> model OR identity-technical_name <> technical_name.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'IDENTITY_SCOPE' detail = 'Saved revision does not match the requested identity scope' status = 409.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
