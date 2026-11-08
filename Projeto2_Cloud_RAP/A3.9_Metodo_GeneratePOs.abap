METHOD GeneratePOs.
    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_upload).

    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload BY \_Itens ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    DATA lt_update_items   TYPE TABLE FOR UPDATE zr_po_up_item.
    DATA lt_update_headers TYPE TABLE FOR UPDATE zr_po_up_head.
    DATA lt_Create_logs    TYPE TABLE FOR CREATE zr_po_up_head\_Logs.

    LOOP AT lt_upload INTO DATA(ls_upload).
      DATA ls_Create_log LIKE LINE OF lt_Create_logs.
      ls_Create_log-%tky = ls_upload-%tky.

      DATA lt_valid_items LIKE lt_items.
      CLEAR lt_valid_items.

      LOOP AT lt_items INTO DATA(ls_check_item)
           WHERE UploadUuid    = ls_upload-UploadUuid
             AND ItemStatus    = 'Ready'
             AND PurchaseOrder IS INITIAL.
        APPEND ls_check_item TO lt_valid_items.
      ENDLOOP.

      IF lt_valid_items IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_first_item) = lt_valid_items[ 1 ].
      DATA lv_sup_char TYPE c LENGTH 10.
      lv_sup_char = ls_first_item-Supplier.
      lv_sup_char = |{ lv_sup_char ALPHA = IN }|.

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

      DATA lt_po_items TYPE TABLE FOR CREATE I_PurchaseOrderTP_2\_PurchaseOrderItem.
      lt_po_items = VALUE #( (
        %cid_ref = |PO_{ lv_tracking_id }|
        %target  = VALUE #( FOR ls_item IN lt_valid_items INDEX INTO idx (
          %cid             = |ITM_{ lv_tracking_id }_{ idx }|
          Material         = ls_item-Material
          Plant            = ls_item-Plant
          OrderQuantity    = ls_item-Quantity
          NetPriceAmount   = ls_item-NetPriceAmount
          DocumentCurrency = ls_item-DocumentCurrency
        ) )
      ) ).

      MODIFY ENTITIES OF I_PurchaseOrderTP_2 PRIVILEGED
        ENTITY PurchaseOrder
        CREATE SET FIELDS WITH VALUE #( (
          %cid                       = |PO_{ lv_tracking_id }|
          PurchaseOrderType          = ls_first_item-PurchaseOrderType
          CompanyCode                = ls_first_item-CompanyCode
          PurchasingOrganization     = ls_first_item-PurchasingOrganization
          PurchasingGroup            = ls_first_item-PurchasingGroup
          Supplier                   = lv_sup_char
          DocumentCurrency           = ls_first_item-DocumentCurrency
          CorrespncInternalReference = lv_tracking_id
        ) )
        CREATE BY \_PurchaseOrderItem SET FIELDS WITH lt_po_items
        MAPPED DATA(lt_MAPPED_po)
        FAILED DATA(lt_failed_po)
        REPORTED DATA(lt_reported_po).

      IF lt_failed_po-PurchaseOrder IS INITIAL AND lt_MAPPED_po-PurchaseOrder IS NOT INITIAL.
        LOOP AT lt_valid_items INTO DATA(ls_valid_item).
          APPEND VALUE #( %tky        = ls_valid_item-%tky
                          ItemStatus  = 'Success'
                          ItemMessage = 'PO Accepted by API. Use Fetch Button to retrieve PO Number.'
                          %control    = VALUE #( ItemStatus = if_abap_behv=>mk-on ItemMessage = if_abap_behv=>mk-on )
                        ) TO lt_update_items.
        ENDLOOP.

        DATA(lv_log_success) = |Purchase Order accepted. Use Fetch Button to retrieve PO Number.|.
        APPEND VALUE #(
          %cid      = 'LOG_SUCC_PO'
          %is_Draft = ls_upload-%is_Draft
          MsgType   = 'S'
          MsgText   = CONV #( lv_log_success )
          %control  = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
        ) TO ls_Create_log-%target.

      ELSE.
        DATA(lv_error_msg) = 'API rejected PO creation'.
        IF line_exists( lt_reported_po-PurchaseOrder[ 1 ] ).
          lv_error_msg = lt_reported_po-PurchaseOrder[ 1 ]-%msg->if_message~get_text( ).
        ENDIF.

        LOOP AT lt_valid_items INTO DATA(ls_error_item).
          APPEND VALUE #( %tky        = ls_error_item-%tky
                          ItemStatus  = 'Error'
                          ItemMessage = lv_error_msg
                          %control    = VALUE #( ItemStatus = if_abap_behv=>mk-on ItemMessage = if_abap_behv=>mk-on )
                        ) TO lt_update_items.
        ENDLOOP.

        DATA(lv_err_trunc) = CONV string( lv_error_msg ).
        IF strlen( lv_err_trunc ) > 100.
          lv_err_trunc = lv_err_trunc(97) && '...'.
        ENDIF.

        DATA(lv_log_error) = |PO Creation failed - { lv_err_trunc }|.
        APPEND VALUE #(
          %cid      = 'LOG_ERR_PO'
          %is_Draft = ls_upload-%is_Draft
          MsgType   = 'E'
          MsgText   = CONV #( lv_log_error )
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

    IF lt_update_items IS NOT INITIAL.
      MODIFY ENTITIES OF zr_po_up_head IN LOCAL MODE
        ENTITY Item UPDATE FROM lt_update_items.
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
