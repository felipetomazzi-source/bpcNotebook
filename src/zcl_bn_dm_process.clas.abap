CLASS zcl_bn_dm_process DEFINITION PUBLIC INHERITING FROM cl_ujd_actor_base FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rspc_execute.
    INTERFACES if_rspc_get_variant.
    INTERFACES if_rspc_maintain.
    INTERFACES if_rspc_transport.
    INTERFACES if_rspc_get_parallelization.
    CONSTANTS process_type TYPE rspc_type VALUE 'ZBNBOOK'.
  PROTECTED SECTION.
    METHODS run REDEFINITION.
  PRIVATE SECTION.
    CLASS-METHODS set_pc_type.
    METHODS property IMPORTING properties TYPE REF TO if_ujd_property_collection name TYPE string
      RETURNING VALUE(value) TYPE string RAISING cx_uj_static_check.
ENDCLASS.

CLASS zcl_bn_dm_process IMPLEMENTATION.
  METHOD set_pc_type.
    cl_ujd_custom_type=>set_pc_type( process_type ).
  ENDMETHOD.
  METHOD property.
    DATA item TYPE REF TO if_ujd_property.
    properties->item( EXPORTING i_name = name IMPORTING eo_property = item ).
    ASSIGN item->dr_value->* TO FIELD-SYMBOL(<value>).
    value = <value>.
  ENDMETHOD.
  METHOD if_rspc_execute~execute.
    CLEAR: e_instance, e_state, e_eventno, e_hold.
    e_state = 'R'.
    DATA instance TYPE sysuuid_25.
    DATA config TYPE REF TO cl_ujd_config.
    TRY.
        CALL FUNCTION 'RSSM_UNIQUE_ID' IMPORTING e_uni_idc25 = instance.
        e_instance = instance.
        IF i_simulate IS NOT INITIAL.
          RAISE EXCEPTION TYPE cx_uj_input_error EXPORTING object = 'Notebook' key = 'Process-chain simulation is not supported'.
        ENDIF.
        config = NEW #( i_variant = i_variant i_type = process_type i_jobcount = i_jobcount
          it_processlist = i_t_processlist i_logid = i_logid it_variables = i_t_variables ).
        config->init( ).
        DATA(actor) = NEW zcl_bn_dm_process( ).
        actor->if_ujd_actor~init( ).
        DATA status TYPE uj_pack_status.
        DATA event TYPE uj_integer.
        actor->if_ujd_actor~execute( EXPORTING io_config = config if_error_rollback = abap_true
          IMPORTING e_pack_status = status e_event_no = event ).
        e_eventno = event.
        IF status = ujd0_cs_package_status-succeed OR status = ujd0_cs_package_status-warning.
          e_state = 'G'.
        ENDIF.
        cl_ujd_custom_type=>reset_log( ).
      CATCH cx_root INTO DATA(error).
        TRY.
            IF config IS BOUND. cl_ujd_custom_type=>set_error_status( config ). ENDIF.
            cl_ujd_custom_type=>write_exception_log( error ).
            cl_ujd_custom_type=>reset_log( ).
          CATCH cx_root.
        ENDTRY.
        e_state = 'R'.
    ENDTRY.
  ENDMETHOD.
  METHOD run.
    e_pack_status = ujd0_cs_package_status-failed.
    e_event_no = 0.
    " Existing synchronous notebook cells do not poll DM abort; finish the current task.
    set_allow_abort( io_variable_list = io_variable_list if_not_allow_abort = abap_true ).
    TRY.
        DATA(environment) = property( properties = io_property_list name = 'SAPPSET' ).
        DATA(model) = property( properties = io_property_list name = 'SAPP' ).
        DATA(user) = property( properties = io_property_list name = 'SUSER' ).
        IF user <> sy-uname.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_USER' detail = 'Notebook handlers must belong to the executing SAP user'.
        ENDIF.
        DATA(handler) = property( properties = io_property_list name = 'HANDLER' ).
        DATA(revision_text) = property( properties = io_property_list name = 'HANDLER_REVISION' ).
        FIND REGEX '^[1-9][0-9]*$' IN revision_text.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'DM_REVISION' detail = 'HANDLER_REVISION must be a positive integer'.
        ENDIF.
        DATA(revision) = CONV i( revision_text ).
        DATA(scope) = zcl_bn_dm=>selection( property( properties = io_property_list name = 'SELECTION' ) ).
        DATA(parameters) = zcl_bn_dm=>parameters(
          text = property( properties = io_property_list name = 'REPLACEPARAM' )
          splitter = property( properties = io_property_list name = 'TAB' )
          equal = property( properties = io_property_list name = 'EQU' ) ).
        DATA(result) = zcl_bn_dm=>preview( handler = handler handler_revision = revision
          environment = environment model = model scope = scope overrides = parameters ).
        io_logger->if_ujd_logger~add_message(
          is_message = VALUE #( msgty = 'I' )
          i_addition_text = |Notebook run { result-id } succeeded; preview only; no financial posting| ).
        LOOP AT result-messages INTO DATA(message).
          io_logger->if_ujd_logger~add_message(
            is_message = VALUE #( msgty = 'I' )
            i_addition_text = message-text ).
        ENDLOOP.
        e_pack_status = ujd0_cs_package_status-succeed.
      CATCH zcx_bn INTO DATA(fault).
        io_logger->if_ujd_logger~add_message(
          is_message = VALUE #( msgty = 'E' )
          i_addition_text = |{ fault->code }: { fault->detail }| ).
    ENDTRY.
  ENDMETHOD.
  METHOD if_rspc_execute~give_chain.
    return = cl_ujd_custom_type=>if_rspc_execute~give_chain( i_variant ).
  ENDMETHOD.
  METHOD if_rspc_get_parallelization~is_synchronous.
    r_synchronous = abap_true.
  ENDMETHOD.
  METHOD if_rspc_get_variant~exists.
    r_exists = cl_ujd_custom_type=>if_rspc_get_variant~exists( i_variant = i_variant i_objvers = i_objvers ).
  ENDMETHOD.
  METHOD if_rspc_get_variant~get_variant.
    cl_ujd_custom_type=>if_rspc_get_variant~get_variant(
      EXPORTING i_type = i_type i_variant = i_variant i_t_chain = i_t_chain i_t_select = i_t_select i_objvers = i_objvers
      IMPORTING e_variant = e_variant e_variant_text = e_variant_text ).
  ENDMETHOD.
  METHOD if_rspc_get_variant~wildcard_enabled.
    result = cl_ujd_custom_type=>if_rspc_get_variant~wildcard_enabled( ).
  ENDMETHOD.
  METHOD if_rspc_maintain~get_header.
    set_pc_type( ).
    cl_ujd_custom_type=>if_rspc_maintain~get_header(
      EXPORTING i_variant = i_variant i_objvers = i_objvers
      IMPORTING e_variant_text = e_variant_text e_s_changed = e_s_changed e_contrel = e_contrel e_conttimestmp = e_conttimestmp ).
  ENDMETHOD.
  METHOD if_rspc_maintain~maintain.
    set_pc_type( ).
    cl_ujd_custom_type=>if_rspc_maintain~maintain(
      EXPORTING i_variant = i_variant i_t_chain = i_t_chain i_display_only = i_display_only
      IMPORTING e_variant = e_variant e_variant_text = e_variant_text ).
  ENDMETHOD.
  METHOD if_rspc_transport~get_tlogo.
    set_pc_type( ).
    cl_ujd_custom_type=>if_rspc_transport~get_tlogo(
      EXPORTING i_variant = i_variant i_objvers = i_objvers IMPORTING e_tlogo = e_tlogo e_objnm = e_objnm ).
  ENDMETHOD.
  METHOD if_rspc_transport~key_change.
    CLEAR: e_t_variante, e_serial.
  ENDMETHOD.
ENDCLASS.

