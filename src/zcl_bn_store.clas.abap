CLASS zcl_bn_store DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS read IMPORTING kind TYPE char1 id TYPE string revision TYPE i DEFAULT 0
      RETURNING VALUE(payload) TYPE string RAISING zcx_bn.
    CLASS-METHODS write IMPORTING kind TYPE char1 id TYPE string payload TYPE string expected TYPE i
      RETURNING VALUE(revision) TYPE i RAISING zcx_bn.
    CLASS-METHODS heads IMPORTING kind TYPE char1 RETURNING VALUE(result) TYPE zcl_bn_types=>tt_ids.
    CLASS-METHODS current IMPORTING kind TYPE char1 id TYPE string RETURNING VALUE(result) TYPE i.
    CLASS-METHODS lock_run IMPORTING id TYPE string RETURNING VALUE(revision) TYPE i RAISING zcx_bn.
ENDCLASS.
CLASS zcl_bn_store IMPLEMENTATION.
  METHOD read.
    DATA head TYPE zbn_head.
    SELECT SINGLE * FROM zbn_head INTO @head
      WHERE kind = @kind AND id = @id AND owner = @sy-uname.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NOT_FOUND' detail = 'Resource not found' status = 404.
    ENDIF.
    DATA rev TYPE i.
    rev = COND #( WHEN revision = 0 THEN head-revision ELSE revision ).
    SELECT SINGLE * FROM zbn_doc INTO @DATA(doc)
      WHERE kind = @kind AND id = @id AND revision = @rev.
    IF sy-subrc <> 0 OR zcl_bn_types=>hash( doc-payload ) <> doc-checksum.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INTEGRITY' detail = 'Document missing or checksum mismatch' status = 409.
    ENDIF.
    payload = doc-payload.
  ENDMETHOD.
  METHOD write.
    IF strlen( id ) > 64 OR id IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'ID' detail = 'Invalid document ID'.
    ENDIF.
    revision = expected + 1.
    IF expected = 0.
      DATA head TYPE zbn_head.
      head-mandt = sy-mandt. head-kind = kind. head-id = id.
      head-owner = sy-uname. head-revision = revision.
      INSERT zbn_head FROM @head.
    ELSE.
      UPDATE zbn_head SET revision = @revision
        WHERE kind = @kind AND id = @id AND owner = @sy-uname AND revision = @expected.
    ENDIF.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'CONFLICT' detail = 'Concurrent update; reload resource' status = 409.
    ENDIF.
    DATA doc TYPE zbn_doc.
    doc-mandt = sy-mandt. doc-kind = kind. doc-id = id. doc-revision = revision.
    doc-payload = payload. doc-checksum = zcl_bn_types=>hash( payload ).
    doc-author = sy-uname. GET TIME STAMP FIELD doc-created_at.
    INSERT zbn_doc FROM @doc.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'INTEGRITY' detail = 'Immutable revision already exists' status = 409.
    ENDIF.
  ENDMETHOD.
  METHOD heads.
    SELECT id FROM zbn_head INTO TABLE @result WHERE kind = @kind AND owner = @sy-uname ORDER BY id.
  ENDMETHOD.
  METHOD current.
    SELECT SINGLE revision FROM zbn_head INTO @result
      WHERE kind = @kind AND id = @id AND owner = @sy-uname.
  ENDMETHOD.
  METHOD lock_run.
    DATA head TYPE zbn_head.
    SELECT SINGLE FOR UPDATE * FROM zbn_head INTO @head
      WHERE kind = 'R' AND id = @id.
    IF sy-subrc <> 0 OR head-owner <> sy-uname.
      RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'NOT_FOUND' detail = 'Run not found' status = 404.
    ENDIF.
    revision = head-revision.
  ENDMETHOD.
ENDCLASS.
