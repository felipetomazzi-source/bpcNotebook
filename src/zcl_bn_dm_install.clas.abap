CLASS zcl_bn_dm_install DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
    CLASS-METHODS install RAISING zcx_bn.
  PRIVATE SECTION.
    CLASS-METHODS failed IMPORTING detail TYPE string RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_dm_install IMPLEMENTATION.
  METHOD failed.
    RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_INSTALL' detail = detail.
  ENDMETHOD.
  METHOD if_oo_adt_classrun~main.
    TRY.
        install( ).
        out->write( 'BNINSTALL|ZBNBOOK|ZBPC_NOTEBOOK|ZBPC_NOTEBOOK_RUN|ZBPC_NOTEBOOK_START' ).
      CATCH zcx_bn INTO DATA(fault).
        ROLLBACK WORK.
        out->write( |BNERROR\|{ fault->code }: { fault->detail }| ).
      CATCH cx_root INTO DATA(error).
        ROLLBACK WORK.
        out->write( |BNERROR\|{ error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
  METHOD install.
    " Explicit DEV provisioning only. This never schedules or executes a package.
    zcl_bn_service=>authorize( '02' ).
    AUTHORITY-CHECK OBJECT 'S_TABU_NAM' ID 'TABLE' FIELD 'RSPROCESSTYPES' ID 'ACTVT' FIELD '02'.
    IF sy-subrc <> 0. failed( 'Process type customizing authorization is required' ). ENDIF.
    AUTHORITY-CHECK OBJECT 'S_TABU_NAM' ID 'TABLE' FIELD 'RSPROCESSTYPEST' ID 'ACTVT' FIELD '02'.
    IF sy-subrc <> 0. failed( 'Process type text customizing authorization is required' ). ENDIF.
    SELECT SINGLE * FROM rspcchainattr INTO @DATA(existing) WHERE chain_id = 'ZBPC_NOTEBOOK' AND objvers = 'A'.
    IF sy-subrc = 0. failed( 'ZBPC_NOTEBOOK already exists; inspect it instead of overwriting' ). ENDIF.
    SELECT SINGLE * FROM rspcchainattr INTO @existing WHERE chain_id = 'ZBPC_NOTEBOOK' AND objvers = 'M'.
    IF sy-subrc = 0. failed( 'A modified ZBPC_NOTEBOOK chain already exists; inspect it before retrying' ). ENDIF.
    SELECT * FROM rspcchain INTO TABLE @DATA(template) WHERE chain_id = '/CPMB/DEFAULT_FORMULAS' AND objvers = 'A'.
    IF lines( template ) <> 6 OR NOT line_exists( template[ type = 'BPCRUNLGC' variante = '/CPMB/DEFAULT_FORMULAS_LOGIC' ] )
      OR NOT line_exists( template[ type = 'BPCMODIFY' ] ) OR NOT line_exists( template[ type = 'BPCCLEAR' ] )
      OR NOT line_exists( template[ type = 'TRIGGER' ] ) OR NOT line_exists( template[ type = 'OR' ] ).
      failed( 'Installed DEFAULT_FORMULAS template differs from the reviewed six-node BPC chain' ).
    ENDIF.
    SELECT SINGLE * FROM rsprocesstypes INTO @DATA(process) WHERE type = 'ZBNBOOK'.
    IF sy-subrc = 0.
      IF process-object <> 'ZCL_BN_DM_PROCESS'. failed( 'ZBNBOOK belongs to another implementation' ). ENDIF.
    ELSE.
      SELECT SINGLE * FROM rsprocesstypes INTO @process WHERE type = 'BPCRUNLGC'.
      IF sy-subrc <> 0. failed( 'Installed BPC Run Logic process type is missing' ). ENDIF.
      process-type = 'ZBNBOOK'. process-object = 'ZCL_BN_DM_PROCESS'. process-display_order = 90.
      CLEAR: process-docu_type, process-docu_obj.
      INSERT rsprocesstypes FROM @process.
      IF sy-subrc <> 0. failed( 'Could not register ZBNBOOK' ). ENDIF.
    ENDIF.
    DATA process_text TYPE rsprocesstypest.
    process_text = VALUE #( langu = sy-langu type = 'ZBNBOOK' icon_text = 'Run Notebook' description = 'BPC: Notebook Preview' ).
    SELECT SINGLE * FROM rsprocesstypest INTO @DATA(old_text) WHERE type = 'ZBNBOOK' AND langu = @sy-langu.
    IF sy-subrc <> 0. INSERT rsprocesstypest FROM @process_text. ENDIF.
    IF cl_rspc_variant=>exists( i_type = 'ZBNBOOK' i_variant = 'ZBPC_NOTEBOOK_RUN' ) = abap_true.
      failed( 'ZBPC_NOTEBOOK_RUN already exists; no variant will be overwritten' ).
    ENDIF.
    DATA variant TYPE REF TO cl_rspc_variant.
    CALL METHOD cl_rspc_variant=>create
      EXPORTING i_type = 'ZBNBOOK' i_variant = 'ZBPC_NOTEBOOK_RUN' i_no_transport = abap_true i_lock = abap_true
      RECEIVING r_r_variant = variant EXCEPTIONS locked = 1 OTHERS = 2.
    IF sy-subrc <> 0. failed( 'Could not lock the new notebook variant' ). ENDIF.
    DATA fields TYPE string_table.
    fields = VALUE #( ( `SUSER` ) ( `SAPPSET` ) ( `SAPP` ) ( `SELECTION` )
      ( `HANDLER` ) ( `HANDLER_REVISION` ) ( `REPLACEPARAM` ) ( `TAB` ) ( `EQU` ) ).
    DATA values TYPE rspc_t_variant.
    LOOP AT fields INTO DATA(field).
      APPEND VALUE #( type = 'ZBNBOOK' variante = 'ZBPC_NOTEBOOK_RUN' objvers = 'A' lnr = sy-tabix
        fnam = field sign = 'I' opt = 'EQ'
        low = COND #( WHEN field = 'TAB' THEN '|' WHEN field = 'EQU' THEN '=' ELSE '' ) ) TO values.
    ENDLOOP.
    CALL METHOD variant->save
      EXPORTING i_t_rspcvariant = values
        i_s_rspcvariantt = VALUE #( type = 'ZBNBOOK' variante = 'ZBPC_NOTEBOOK_RUN' objvers = 'A' langu = sy-langu txtlg = 'BPC: Notebook Preview' )
      EXCEPTIONS failed = 1 OTHERS = 2.
    IF sy-subrc <> 0. variant->free( ). failed( 'Could not save notebook process variant' ). ENDIF.
    variant->free( ).
    CALL FUNCTION 'RSPC_TRIGGER_GENERATE'
      EXPORTING i_variant = 'ZBPC_NOTEBOOK_START' i_variant_text = 'BPC: Notebook Start'
        i_startspecs = VALUE tbtcstrt( startdttyp = 'I' ) i_no_transport = abap_true
      EXCEPTIONS exists = 1 failed = 2 OTHERS = 3.
    IF sy-subrc <> 0. failed( 'Could not create unique notebook start variant' ). ENDIF.
    DATA chain TYPE REF TO cl_rspc_chain.
    CREATE OBJECT chain
      EXPORTING i_chain = 'ZBPC_NOTEBOOK' i_objvers = 'A' i_new = abap_true i_copy_from = '/CPMB/DEFAULT_FORMULAS'
        i_with_dialog = abap_false i_no_transport = abap_true
      EXCEPTIONS aborted_by_user = 1 not_unique = 2 wrong_name = 3 display_only = 4 OTHERS = 5.
    IF sy-subrc <> 0. failed( 'Could not create notebook chain through BW API' ). ENDIF.
    chain->rename( 'BPC: Notebook Preview' ).
    DATA(old_run) = chain->p_t_chain[ type = 'BPCRUNLGC' ].
    CALL METHOD chain->replace_process
      EXPORTING i_s_old = old_run i_new_type = 'ZBNBOOK' i_new_variant = 'ZBPC_NOTEBOOK_RUN'
      EXCEPTIONS aborted_by_user = 1 OTHERS = 2.
    IF sy-subrc <> 0. failed( 'Could not replace the Script Logic step' ). ENDIF.
    DATA(old_start) = chain->p_t_chain[ type = 'TRIGGER' ].
    CALL METHOD chain->replace_process
      EXPORTING i_s_old = old_start i_new_variant = 'ZBPC_NOTEBOOK_START'
      EXCEPTIONS aborted_by_user = 1 OTHERS = 2.
    IF sy-subrc <> 0. failed( 'Could not replace the start step' ). ENDIF.
    chain->set_application( i_applnm = '/CPMB/BPC_MISC_PC' ).
    CALL METHOD chain->set_batchuser EXPORTING i_batchuser = sy-uname EXCEPTIONS aborted_by_user = 1 OTHERS = 2.
    IF sy-subrc <> 0. failed( 'Could not set the current DEV execution user' ). ENDIF.
    CALL METHOD chain->save EXCEPTIONS failed = 1 OTHERS = 2.
    IF sy-subrc <> 0. failed( 'Could not save notebook chain' ). ENDIF.
    DATA conflicts TYPE rspc_t_conflicts.
    CALL METHOD chain->check IMPORTING e_t_conflicts = conflicts EXCEPTIONS errors = 1 warnings = 2 OTHERS = 3.
    IF sy-subrc <> 0. failed( |Notebook chain check failed: { /ui2/cl_json=>serialize( data = conflicts ) }| ). ENDIF.
    CALL METHOD chain->activate
      EXPORTING i_noplan = abap_true i_gui = 'N'
      IMPORTING e_t_conflicts = conflicts EXCEPTIONS errors = 1 warnings = 2 OTHERS = 3.
    IF sy-subrc <> 0. failed( |Notebook chain activation failed: { /ui2/cl_json=>serialize( data = conflicts ) }| ). ENDIF.
    COMMIT WORK AND WAIT.
  ENDMETHOD.
ENDCLASS.

