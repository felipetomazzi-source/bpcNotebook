CLASS zcl_bn_http DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_http_extension.
ENDCLASS.
CLASS zcl_bn_http IMPLEMENTATION.
  METHOD if_http_extension~handle_request.
    server->response->set_content_type( 'application/json; charset=utf-8' ).
    server->response->set_header_field( name = 'Cache-Control' value = 'no-store' ).
    server->response->set_header_field( name = 'X-Content-Type-Options' value = 'nosniff' ).
    DATA method TYPE string.
    method = server->request->get_method( ).
    TRY.
        IF method <> 'GET'.
          IF ( method <> 'POST' AND method <> 'PUT' ) OR
             server->request->get_header_field( 'X-BPC-Notebook' ) <> '1' OR
             server->request->get_header_field( 'Content-Type' ) NP 'application/json*'.
            RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CSRF' detail = 'JSON request and custom header required' status = 403.
          ENDIF.
          DATA(origin) = server->request->get_header_field( 'Origin' ).
          IF origin IS NOT INITIAL.
            DATA origin_host TYPE string.
            FIND REGEX '^https?://([^/]+)$' IN origin SUBMATCHES origin_host.
            IF sy-subrc <> 0 OR to_lower( origin_host ) <> to_lower( server->request->get_header_field( 'Host' ) ).
              RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'ORIGIN' detail = 'Cross-origin write refused' status = 403.
            ENDIF.
          ENDIF.
        ENDIF.
        DATA body TYPE string.
        body = server->request->get_cdata( ).
        IF strlen( body ) > 2000000.
          RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'SIZE' detail = 'Request exceeds 2 MB' status = 413.
        ENDIF.
        DATA(json) = zcl_bn_service=>dispatch(
          path = server->request->get_header_field( '~path_info' ) method = method body = body
          id = server->request->get_form_field( 'id' )
          notebook_id = server->request->get_form_field( 'notebookId' )
          run_id = server->request->get_form_field( 'runId' ) cell_id = server->request->get_form_field( 'cellId' )
          revision = CONV i( server->request->get_form_field( 'revision' ) )
          offset = CONV i( server->request->get_form_field( 'offset' ) )
          page_size = CONV i( server->request->get_form_field( 'limit' ) ) ).
        COMMIT WORK AND WAIT.
        server->response->set_status( code = COND #( WHEN method = 'POST' AND
          server->request->get_header_field( '~path_info' ) = '/runs' THEN 202 ELSE 200 ) reason = 'OK' ).
        server->response->set_cdata( json ).
      CATCH zcx_bn INTO DATA(fault).
        ROLLBACK WORK.
        server->response->set_status( code = fault->status reason = 'Notebook request failed' ).
        server->response->set_cdata( zcl_bn_types=>json( VALUE zcl_bn_types=>ty_error( code = fault->code message = fault->detail ) ) ).
      CATCH cx_root INTO DATA(error).
        ROLLBACK WORK.
        server->response->set_status( code = 400 reason = 'Invalid request' ).
        server->response->set_cdata( zcl_bn_types=>json( VALUE zcl_bn_types=>ty_error( code = 'REQUEST' message = error->get_text( ) ) ) ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
