CLASS zcl_bn_logic DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_uj_custom_logic.
    TYPES: BEGIN OF ty_handler,
             name TYPE string, revision TYPE i, notebook_id TYPE string, notebook_revision TYPE i,
             environment TYPE string, model TYPE string, checksum TYPE string, execution_mode TYPE string,
           END OF ty_handler.
    CLASS-METHODS register IMPORTING name TYPE string notebook_id TYPE string notebook_revision TYPE i expected TYPE i
      execution_mode TYPE string DEFAULT 'preview'
      RETURNING VALUE(result) TYPE ty_handler RAISING zcx_bn.
    CLASS-METHODS binding IMPORTING name TYPE string RETURNING VALUE(result) TYPE ty_handler RAISING zcx_bn.
    CLASS-METHODS invoke IMPORTING name TYPE string environment TYPE string model TYPE string
      parameters TYPE ujk_t_script_logic_hashtable scope TYPE ujk_t_cv
      EXPORTING result_data TYPE REF TO data
      RETURNING VALUE(run) TYPE zcl_bn_types=>ty_run RAISING zcx_bn.
  PRIVATE SECTION.
    CLASS-METHODS handler_name IMPORTING name TYPE string RETURNING VALUE(result) TYPE string RAISING zcx_bn.
    CLASS-METHODS bind_inputs IMPORTING parameters TYPE ujk_t_script_logic_hashtable scope TYPE ujk_t_cv
      CHANGING notebook TYPE zcl_bn_types=>ty_notebook RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_logic IMPLEMENTATION.
  METHOD handler_name.
    result = to_upper( name ).
    FIND REGEX '^[A-Z][A-Z0-9_]{0,29}$' IN result.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_HANDLER' detail = 'Handler name must be an identifier of 1 to 30 characters'.
    ENDIF.
  ENDMETHOD.
  METHOD binding.
    zcl_bn_service=>authorize( '03' ).
    DATA(payload) = zcl_bn_store=>read( kind = 'L' id = handler_name( name ) ).
    /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( payload ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = result ).
  ENDMETHOD.
  METHOD register.
    zcl_bn_service=>authorize( '02' ).
    IF execution_mode <> 'preview' AND execution_mode <> 'allocation'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_MODE' detail = 'Mode must be preview or allocation'.
    ENDIF.
    DATA(id) = handler_name( name ).
    DATA(notebook) = zcl_bn_service=>get_notebook( notebook_id ).
    IF notebook_revision < 1 OR notebook_revision <> notebook-revision OR notebook-cells IS INITIAL OR
       notebook-environment IS INITIAL OR notebook-model IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_REVISION'
        detail = 'Save and reload a notebook with its BPC environment/model before binding a handler' status = 409.
    ENDIF.
    " Script Logic keys are case-insensitive; do not allow ambiguous declared input names.
    DATA names TYPE zcl_bn_types=>tt_ids.
    LOOP AT notebook-inputs INTO DATA(input).
      DATA(key) = to_upper( input-name ).
      IF line_exists( names[ table_line = key ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_INPUT' detail = 'Handler input names must be unique ignoring case'.
      ENDIF.
      APPEND key TO names.
    ENDLOOP.
    DATA(payload) = zcl_bn_store=>read( kind = 'N' id = notebook_id revision = notebook_revision ).
    result = VALUE #( name = id revision = expected + 1 notebook_id = notebook_id notebook_revision = notebook_revision
      execution_mode = execution_mode environment = notebook-environment model = notebook-model checksum = zcl_bn_types=>hash( payload ) ).
    zcl_bn_store=>write( kind = 'L' id = id payload = zcl_bn_types=>json( result ) expected = expected ).
  ENDMETHOD.
  METHOD bind_inputs.
    DATA consumed TYPE zcl_bn_types=>tt_ids.
    LOOP AT notebook-inputs ASSIGNING FIELD-SYMBOL(<input>).
      DATA(key) = |INPUT_{ to_upper( <input>-name ) }|.
      DATA(hkey) = |HIERARCHY_{ to_upper( <input>-name ) }|.
      READ TABLE parameters INTO DATA(parameter) WITH KEY hashkey = key.
      DATA(explicit) = xsdbool( sy-subrc = 0 ).
      IF explicit = abap_true. APPEND key TO consumed. ENDIF.
      IF <input>-purpose = 'reference' AND ( explicit = abap_true OR line_exists( parameters[ hashkey = hkey ] ) ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'REFERENCE_POLICY' detail = 'Reference overrides are not allowed; rebind a reviewed notebook definition'.
      ENDIF.
      IF <input>-type = 'member' OR <input>-type = 'range'.
        READ TABLE parameters INTO DATA(hierarchy) WITH KEY hashkey = hkey.
        IF sy-subrc = 0.
          <input>-hierarchy = hierarchy-hashvalue. APPEND hkey TO consumed.
          IF explicit = abap_false.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_INPUT' detail = 'A hierarchy override requires an explicit INPUT_ selection'.
          ENDIF.
        ENDIF.
        IF explicit = abap_true.
          CLEAR <input>-selected.
          SPLIT parameter-hashvalue AT ',' INTO TABLE <input>-selected.
          LOOP AT <input>-selected ASSIGNING FIELD-SYMBOL(<id>).
            SHIFT <id> LEFT DELETING LEADING space. SHIFT <id> RIGHT DELETING TRAILING space.
          ENDLOOP.
        ELSEIF <input>-purpose <> 'reference'.
          READ TABLE scope INTO DATA(view) WITH KEY dimension = <input>-dimension.
          IF sy-subrc = 0.
            CLEAR <input>-selected.
            LOOP AT view-member INTO DATA(member). APPEND CONV string( member ) TO <input>-selected. ENDLOOP.
          ENDIF.
        ENDIF.
        CLEAR <input>-resolved.
      ELSEIF explicit = abap_true.
        <input>-value = parameter-hashvalue.
        IF <input>-type = 'boolean'.
          CASE to_upper( <input>-value ).
            WHEN 'TRUE' OR 'ON' OR '1' OR 'X'. <input>-value = 'true'.
            WHEN 'FALSE' OR 'OFF' OR '0' OR ''. <input>-value = 'false'.
            WHEN OTHERS.
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_INPUT' detail = 'Boolean override must be TRUE/FALSE, ON/OFF, 1/0 or X'.
          ENDCASE.
        ENDIF.
      ENDIF.
    ENDLOOP.
    LOOP AT parameters INTO parameter.
      IF ( parameter-hashkey CP 'INPUT_*' OR parameter-hashkey CP 'HIERARCHY_*' ) AND
         NOT line_exists( consumed[ table_line = parameter-hashkey ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_INPUT' detail = |Unknown notebook parameter { parameter-hashkey }|.
      ENDIF.
    ENDLOOP.
    zcl_bn_bpc=>resolve( EXPORTING complete = abap_true CHANGING notebook = notebook ).
    " Explicit selections and defaults may narrow, but never exceed the caller's base-member scope.
    LOOP AT notebook-inputs INTO DATA(input) WHERE type = 'member' OR type = 'range'.
      IF input-purpose = 'reference'. CONTINUE. ENDIF.
      READ TABLE scope INTO view WITH KEY dimension = input-dimension.
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      LOOP AT input-resolved INTO DATA(id).
        IF NOT line_exists( view-member[ table_line = id ] ).
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_CV' detail = 'Notebook selection exceeds the caller current view'.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
  METHOD invoke.
    zcl_bn_service=>authorize( '16' ).
    DATA(handler) = binding( name ).
    IF handler-environment <> environment OR handler-model <> model.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_CONTEXT' detail = 'Handler environment/model must match the Script Logic caller'.
    ENDIF.
    zcl_bn_store=>lock_notebook( handler-notebook_id ).
    DATA(payload) = zcl_bn_store=>read( kind = 'N' id = handler-notebook_id revision = handler-notebook_revision ).
    IF zcl_bn_types=>hash( payload ) <> handler-checksum.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_INTEGRITY' detail = 'Pinned handler notebook checksum mismatch'.
    ENDIF.
    DATA notebook TYPE zcl_bn_types=>ty_notebook.
    /ui2/cl_json=>deserialize( EXPORTING json = zcl_bn_types=>native_json( payload ) pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = notebook ).
    DATA normalized TYPE ujk_t_script_logic_hashtable.
    LOOP AT parameters INTO DATA(parameter).
      parameter-hashkey = to_upper( parameter-hashkey ).
      IF line_exists( normalized[ hashkey = parameter-hashkey ] ).
        RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_INPUT' detail = 'Duplicate Script Logic parameter ignoring case'.
      ENDIF.
      INSERT parameter INTO TABLE normalized.
    ENDLOOP.
    READ TABLE parameters INTO parameter WITH KEY hashkey = 'WRITE'.
    DATA allocation TYPE abap_bool.
    READ TABLE normalized INTO DATA(mode) WITH KEY hashkey = 'EXECUTION'.
    allocation = xsdbool( sy-subrc = 0 AND mode-hashvalue = 'ALLOCATION' ).
    IF allocation = abap_true AND handler-execution_mode <> 'allocation'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_MODE' detail = 'Handler must explicitly be bound for allocation'.
    ENDIF.
    IF sy-subrc = 0 AND mode-hashvalue <> 'ALLOCATION' AND mode-hashvalue <> 'PREVIEW'.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_MODE' detail = 'EXECUTION must be PREVIEW or ALLOCATION'.
    ENDIF.
    READ TABLE parameters INTO parameter WITH KEY hashkey = 'WRITE'.
    IF sy-subrc <> 0 OR ( allocation = abap_false AND parameter-hashvalue <> 'OFF' ) OR
       ( allocation = abap_true AND parameter-hashvalue <> 'ON' ).
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_WRITE' detail = 'Preview requires WRITE = OFF; explicitly bound allocation requires EXECUTION = ALLOCATION and WRITE = ON'.
    ENDIF.
    zcl_bn_bpc=>validate_scope( environment = environment model = model scope = scope ).
    bind_inputs( EXPORTING parameters = normalized scope = scope CHANGING notebook = notebook ).
    run = zcl_bn_service=>run_logic( EXPORTING allocation = allocation notebook = notebook parameters = normalized scope = scope
      handler = handler-name handler_revision = handler-revision IMPORTING result_data = result_data ).
  ENDMETHOD.
  METHOD if_uj_custom_logic~init.
  ENDMETHOD.
  METHOD if_uj_custom_logic~cleanup.
  ENDMETHOD.
  METHOD if_uj_custom_logic~execute.
    CLEAR et_message.
    TRY.
        DATA names TYPE zcl_bn_types=>tt_ids.
        LOOP AT it_param INTO DATA(parameter).
          IF to_upper( parameter-hashkey ) = 'HANDLER'. APPEND parameter-hashvalue TO names. ENDIF.
        ENDLOOP.
        IF lines( names ) <> 1.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'LOGIC_HANDLER' detail = 'Supply exactly one HANDLER parameter'.
        ENDIF.
        DATA result TYPE REF TO data.
        DATA(run) = invoke( EXPORTING name = names[ 1 ] environment = CONV #( i_appset_id ) model = CONV #( i_appl_id )
          parameters = it_param scope = it_cv IMPORTING result_data = result ).
        APPEND VALUE #( msgid = 'UJK_MESSAGE' msgno = '004' msgty = 'I' message = |Notebook run { run-id } succeeded| msgv1 = |Notebook run { run-id } succeeded| ) TO et_message.
        LOOP AT run-messages INTO DATA(message).
          APPEND VALUE #( msgid = 'UJK_MESSAGE' msgno = '004' msgty = 'I' message = message-text msgv1 = message-text ) TO et_message.
        ENDLOOP.
        IF result IS BOUND.
          FIELD-SYMBOLS <rows> TYPE STANDARD TABLE. ASSIGN result->* TO <rows>.
          DATA replacement TYPE REF TO data. CREATE DATA replacement LIKE ct_data.
          FIELD-SYMBOLS <replacement> TYPE STANDARD TABLE. ASSIGN replacement->* TO <replacement>.
          DATA line TYPE REF TO data. CREATE DATA line LIKE LINE OF ct_data.
          FIELD-SYMBOLS <line> TYPE any. ASSIGN line->* TO <line>.
          FIELD-SYMBOLS <field> TYPE any.
          DATA(adapter) = NEW zcl_bn_bpc( environment = CONV #( i_appset_id ) model = CONV #( i_appl_id ) ).
          DATA(dimensions) = adapter->dimensions( ).
          DATA(time_dim) = NEW zcl_bn_bpc( environment = CONV #( i_appset_id ) model = CONV #( i_appl_id ) dimension = 'TIME' ).
          TYPES: BEGIN OF ty_fiscal, member TYPE uj_dim_member, period TYPE string, END OF ty_fiscal.
          DATA fiscal TYPE HASHED TABLE OF ty_fiscal WITH UNIQUE KEY member.
          LOOP AT <rows> ASSIGNING FIELD-SYMBOL(<row>).
            CLEAR <line>. MOVE-CORRESPONDING <row> TO <line>.
            LOOP AT dimensions INTO DATA(dimension).
              UNASSIGN <field>. ASSIGN COMPONENT dimension-id OF STRUCTURE <line> TO <field>.
              IF <field> IS NOT ASSIGNED.
                RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_CALLER_SCHEMA' detail = 'Caller table is missing a model dimension'.
              ENDIF.
            ENDLOOP.
            UNASSIGN <field>. ASSIGN COMPONENT 'SIGNEDDATA' OF STRUCTURE <line> TO <field>.
            IF <field> IS NOT ASSIGNED.
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'RESULT_CALLER_SCHEMA' detail = 'Caller table is missing SIGNEDDATA'.
            ENDIF.
            UNASSIGN <field>. ASSIGN COMPONENT 'FISCPER' OF STRUCTURE <line> TO <field>.
            IF <field> IS ASSIGNED.
              FIELD-SYMBOLS <time> TYPE any. ASSIGN COMPONENT 'TIME' OF STRUCTURE <row> TO <time>.
              READ TABLE fiscal INTO DATA(fiscal_entry) WITH TABLE KEY member = CONV uj_dim_member( <time> ).
              IF sy-subrc <> 0.
                fiscal_entry-member = <time>.
                fiscal_entry-period = time_dim->property( member = CONV string( <time> ) name = 'FISCYEAR' ) &&
                  time_dim->property( member = CONV string( <time> ) name = 'BASE_PERIOD' ).
                IF fiscal_entry-period IS INITIAL.
                  RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'FISCAL_METADATA' detail = 'Caller fiscal period metadata is missing'.
                ENDIF.
                INSERT fiscal_entry INTO TABLE fiscal.
              ENDIF.
              <field> = fiscal_entry-period.
            ENDIF.
            APPEND <line> TO <replacement>.
          ENDLOOP.
          " Publish only after the entire result has been validated and converted.
          ct_data = <replacement>.
        ENDIF.
      CATCH zcx_bn INTO DATA(fault).
        RAISE EXCEPTION TYPE cx_uj_custom_logic EXPORTING textid = cx_uj_custom_logic=>info
          datavalue = |{ fault->code }: { fault->detail }| previous = fault.
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION TYPE cx_uj_custom_logic EXPORTING textid = cx_uj_custom_logic=>info
          datavalue = error->get_text( ) previous = error.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
