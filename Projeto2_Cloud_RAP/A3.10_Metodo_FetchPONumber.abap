METHOD FetchPONumber.
    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_upload).

    DATA lt_update_headers TYPE TABLE FOR UPDATE zr_po_up_head.
    DATA lt_Create_logs    TYPE TABLE FOR CREATE zr_po_up_head\_Logs.

    LOOP AT lt_upload INTO DATA(ls_upload).
      IF ls_upload-PurchaseOrder IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      DATA ls_Create_log LIKE LINE OF lt_Create_logs.
      ls_Create_log-%tky = ls_upload-%tky.

      DATA lv_tracking_id TYPE c LENGTH 12.
      TRY.
          cl_system_uuid=>convert_uuid_x16_static(
            EXPORTING uuid     = ls_upload-UploadUuid
            IMPORTING uuid_c32 = DATA(lv_uuid_c32)
          ).
          lv_tracking_id = lv_uuid_c32+20(12).
        CATCH cx_Root.
          lv_tracking_id = 'ERRO_UUID'.
      ENDTRY.

      SELECT PurchaseOrder
        FROM I_PurchaseOrderAPI01 WITH PRIVILEGED ACCESS
        WHERE CreatedByuser              = @sy-uname
          AND CreationDate               = @sy-datum
          AND CorrespncInternalReference = @lv_tracking_id
        ORDER BY PurchaseOrder DESCENDING
        INTO TABLE @DATA(lt_matched_po)
        UP TO 1 ROWS.

      IF sy-subrc = 0 AND lt_matched_po IS NOT INITIAL.
        DATA(lv_real_po_Number) = lt_matched_po[ 1 ]-PurchaseOrder.

        APPEND VALUE #( %tky          = ls_upload-%tky
                        PurchaseOrder = lv_real_po_Number
                        %control      = VALUE #( PurchaseOrder = if_abap_behv=>mk-on )
                      ) TO lt_update_headers.

        DATA(lv_log_fetch) = |Purchase Order of Excel File "{ ls_upload-FileName }" is { lv_real_po_Number }|.

        APPEND VALUE #(
          %cid      = 'LOG_FINAL_' && lv_real_po_Number
          %is_Draft = ls_upload-%is_Draft
          MsgType   = 'S'
          MsgText   = CONV #( lv_log_fetch )
          %control  = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
        ) TO ls_Create_log-%target.
      ENDIF.

      IF ls_Create_log-%target IS NOT INITIAL.
        APPEND ls_Create_log TO lt_Create_logs.
      ENDIF.
    ENDLOOP.

    IF lt_update_headers IS NOT INITIAL.
      MODIFY ENTITIES OF zr_po_up_head IN LOCAL MODE
        ENTITY Upload UPDATE FROM lt_update_headers.
    ENDIF.

    IF lt_Create_logs IS NOT INITIAL.
      MODIFY ENTITIES OF zr_po_up_head IN LOCAL MODE
        ENTITY Upload CREATE BY \_Logs FROM lt_Create_logs.
    ENDIF.

    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_upload_updated).

    result = VALUE #( FOR upload IN lt_upload_updated ( %tky = upload-%tky %param = upload ) ).
  ENDMETHOD.
