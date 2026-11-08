METHOD ParseExcel.
    TYPES: BEGIN OF ty_excel_row,
             PurchaseOrdertype      TYPE string,
             companycode            TYPE string,
             purchasingorganization TYPE string,
             purchasinggroup        TYPE string,
             supplier               TYPE string,
             material               TYPE string,
             plant                  TYPE string,
             quantity               TYPE string,
             netpriceamount         TYPE string,
             documentcurrency       TYPE string,
             delivery_date          TYPE string,
           END OF ty_excel_row.

    DATA lt_excel_data   TYPE STANDARD TABLE OF ty_excel_row.
    DATA lt_Create_items TYPE TABLE FOR CREATE zr_po_up_head\_Itens.
    DATA lt_Create_logs  TYPE TABLE FOR CREATE zr_po_up_head\_Logs.

    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload
      FIELDS ( Attachment FileName ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_upload).

    LOOP AT lt_upload INTO DATA(ls_upload).
      IF ls_upload-Attachment IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA ls_Create_log LIKE LINE OF lt_Create_logs.
      ls_Create_log-%tky = ls_upload-%tky.

      DATA ls_Create_item LIKE LINE OF lt_Create_items.
      ls_Create_item-%tky = ls_upload-%tky.

      DATA(lv_filename_upper) = to_upper( ls_upload-FileName ).
      IF lv_filename_upper NP '*.XLSX'.
        APPEND VALUE #(
          %cid      = 'LOG_FILE_ERR'
          %is_Draft = ls_upload-%is_Draft
          MsgType   = 'E'
          MsgText   = '1 : File type incorrect. Must be an Excel (.xlsx) file.'
          %control  = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
        ) TO ls_Create_log-%target.

        APPEND ls_Create_log TO lt_Create_logs.
        CONTINUE.
      ELSE.
        APPEND VALUE #(
          %cid      = 'LOG_FILE_OK'
          %is_Draft = ls_upload-%is_Draft
          MsgType   = 'S'
          MsgText   = '1 : File type correct (.xlsx). Reading Excel Lines...'
          %control  = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
        ) TO ls_Create_log-%target.
      ENDIF.

      TRY.
          DATA(lo_document)  = xco_cp_xlsx=>document->for_file_content( ls_upload-Attachment ).
          DATA(lo_worksheet) = lo_document->read_access( )->get_workbook( )->worksheet->at_position( 1 ).

          DATA(lo_selection) = lo_worksheet->select(
            xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
              )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
              )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'K' )
              )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 2 )
            )->get_pattern( )
          ).

          lo_selection->row_stream( )->operation->write_to( REF #( lt_excel_data ) )->execute( ).

        CATCH cx_Root.
          APPEND VALUE #(
            %cid      = 'LOG_CORRUPT'
            %is_Draft = ls_upload-%is_Draft
            MsgType   = 'E'
            MsgText   = '1 : Error reading file. The file is empty or corrupted.'
            %control  = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
          ) TO ls_Create_log-%target.

          APPEND ls_Create_log TO lt_Create_logs.
          CONTINUE.
      ENDTRY.

      DATA(lv_index) = 1.

      LOOP AT lt_excel_data INTO DATA(ls_excel_row) WHERE supplier IS NOT INITIAL OR material IS NOT INITIAL.

        REPLACE ALL OCCURRENCES OF '-' IN ls_excel_row-delivery_date WITH ''.
        REPLACE ALL OCCURRENCES OF ',' IN ls_excel_row-quantity WITH '.'.
        REPLACE ALL OCCURRENCES OF ',' IN ls_excel_row-netpriceamount WITH '.'.

        DATA(lv_excel_row) = lv_index + 1.
        DATA(lv_row_str)   = CONV string( lv_excel_row ).

        DATA lv_status  TYPE string.
        DATA lv_message TYPE string.
        DATA lv_err_txt TYPE string.

        CLEAR: lv_status, lv_message, lv_err_txt.
        lv_status = 'Ready'.

        DATA(lv_quant)       = CONV decfloat16( condense( val = ls_excel_row-quantity ) ).
        DATA(lv_price)       = CONV decfloat16( condense( val = ls_excel_row-netpriceamount ) ).
        DATA(lv_bsart_Clean) = to_upper( condense( val = ls_excel_row-PurchaseOrdertype ) ).
        DATA(lv_bukrs_Clean) = to_upper( condense( val = ls_excel_row-companycode ) ).
        DATA(lv_ekorg_Clean) = to_upper( condense( val = ls_excel_row-purchasingorganization ) ).
        DATA(lv_ekgrp_Clean) = to_upper( condense( val = ls_excel_row-purchasinggroup ) ).

        IF lv_bsart_Clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'PO Type' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SELECT SINGLE PurchasingDocumentType FROM I_PurchasingDocumentType WITH PRIVILEGED ACCESS
            WHERE PurchasingDocumentType = @lv_bsart_Clean INTO @DATA(lv_bsart_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'PO Type' lv_bsart_Clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        IF lv_bukrs_Clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Company Code' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SELECT SINGLE CompanyCode FROM I_CompanyCode WITH PRIVILEGED ACCESS
            WHERE CompanyCode = @lv_bukrs_Clean INTO @DATA(lv_bukrs_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Company Code' lv_bukrs_Clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        IF lv_ekorg_Clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Purch. Org.' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SELECT SINGLE PurchasingOrganization FROM I_PurchasingOrganization WITH PRIVILEGED ACCESS
            WHERE PurchasingOrganization = @lv_ekorg_Clean INTO @DATA(lv_ekorg_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Purch. Org.' lv_ekorg_Clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        IF lv_ekgrp_Clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Purch. Group' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SELECT SINGLE PurchasingGroup FROM I_PurchasingGroup WITH PRIVILEGED ACCESS
            WHERE PurchasingGroup = @lv_ekgrp_Clean INTO @DATA(lv_ekgrp_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Purch. Group' lv_ekgrp_Clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        DATA(lv_sup_Clean) = condense( val = ls_excel_row-supplier ).
        IF lv_sup_Clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Supplier' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SPLIT lv_sup_Clean AT '.' INTO lv_sup_Clean DATA(dummy_sup).
          lv_sup_Clean = to_upper( lv_sup_Clean ).
          DATA lv_sup_char TYPE c LENGTH 10.
          lv_sup_char = lv_sup_Clean.
          lv_sup_char = |{ lv_sup_char ALPHA = IN }|.
          SELECT SINGLE Supplier FROM I_Supplier WITH PRIVILEGED ACCESS
            WHERE Supplier = @lv_sup_char INTO @DATA(lv_sup_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Supplier' lv_sup_Clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        IF lv_quant <= 0.
          lv_status = 'Error'.
          MESSAGE e003(zmc_po_upload) WITH 'Quantity' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ENDIF.

        IF lv_price <= 0.
          lv_status = 'Error'.
          MESSAGE e003(zmc_po_upload) WITH 'Price' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ENDIF.

        DATA(lv_mat_Clean) = condense( val = ls_excel_row-material ).
        IF lv_mat_Clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Material' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SPLIT lv_mat_Clean AT '.' INTO lv_mat_Clean DATA(dummy_mat).
          lv_mat_Clean = to_upper( lv_mat_Clean ).
          SELECT SINGLE Product FROM I_Product WITH PRIVILEGED ACCESS
            WHERE Product = @lv_mat_Clean INTO @DATA(lv_mat_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Material' lv_mat_Clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        DATA(lv_plant_Clean) = condense( val = ls_excel_row-plant ).
        IF lv_plant_Clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Plant' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SPLIT lv_plant_Clean AT '.' INTO lv_plant_Clean DATA(dummy_plant).
          lv_plant_Clean = to_upper( lv_plant_Clean ).
          SELECT SINGLE Plant FROM I_Plant WITH PRIVILEGED ACCESS
            WHERE Plant = @lv_plant_Clean INTO @DATA(lv_plant_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Plant' lv_plant_Clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        APPEND VALUE #(
            %cid                   = 'ITEM_' && condense( val = CONV string( lv_index ) )
            %is_Draft              = ls_upload-%is_Draft
            ExcelRow               = lv_excel_row
            PurchaseOrderType      = lv_bsart_Clean
            CompanyCode            = lv_bukrs_Clean
            PurchasingOrganization = lv_ekorg_Clean
            PurchasingGroup        = lv_ekgrp_Clean
            DocumentCurrency       = condense( val = ls_excel_row-documentcurrency )
            NetPriceAmount         = lv_price
            Supplier               = lv_sup_Clean
            Material               = lv_mat_Clean
            Plant                  = lv_plant_Clean
            Quantity               = lv_quant
            DeliveryDate           = condense( val = ls_excel_row-delivery_date )
            ItemStatus             = lv_status
            ItemMessage            = lv_message
            %control               = VALUE #(
                ExcelRow               = if_abap_behv=>mk-on
                PurchaseOrderType      = if_abap_behv=>mk-on
                CompanyCode            = if_abap_behv=>mk-on
                PurchasingOrganization = if_abap_behv=>mk-on
                PurchasingGroup        = if_abap_behv=>mk-on
                DocumentCurrency       = if_abap_behv=>mk-on
                NetPriceAmount         = if_abap_behv=>mk-on
                Supplier               = if_abap_behv=>mk-on
                Material               = if_abap_behv=>mk-on
                Plant                  = if_abap_behv=>mk-on
                Quantity               = if_abap_behv=>mk-on
                DeliveryDate           = if_abap_behv=>mk-on
                ItemStatus             = if_abap_behv=>mk-on
                ItemMessage            = if_abap_behv=>mk-on )
        ) TO ls_Create_item-%target.

        IF lv_status = 'Error'.
          DATA(lv_log_text) = |{ lv_row_str } : Validation failed --> { lv_message }|.

          APPEND VALUE #(
              %cid      = 'LOG_' && condense( val = CONV string( lv_index ) )
              %is_Draft = ls_upload-%is_Draft
              MsgType   = 'E'
              MsgText   = CONV #( lv_log_text )
              %control  = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
          ) TO ls_Create_log-%target.
        ELSE.
          DATA(lv_log_succ) = |{ lv_row_str } : Validated successfully (Ready for PO)|.

          APPEND VALUE #(
              %cid      = 'LOG_' && condense( val = CONV string( lv_index ) )
              %is_Draft = ls_upload-%is_Draft
              MsgType   = 'S'
              MsgText   = CONV #( lv_log_succ )
              %control  = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
          ) TO ls_Create_log-%target.
        ENDIF.

        lv_index += 1.
      ENDLOOP.

      APPEND ls_Create_item TO lt_Create_items.

      IF ls_Create_log-%target IS NOT INITIAL.
        APPEND ls_Create_log TO lt_Create_logs.
      ENDIF.
    ENDLOOP.

    IF lt_Create_items IS NOT INITIAL OR lt_Create_logs IS NOT INITIAL.
      MODIFY ENTITIES OF zr_po_up_head IN LOCAL MODE
        ENTITY Upload
        CREATE BY \_Itens FROM lt_Create_items
        CREATE BY \_Logs  FROM lt_Create_logs
        REPORTED DATA(lt_reported).

      reported-upload = CORRESPONDING #( lt_reported-upload ).
      reported-item   = CORRESPONDING #( lt_reported-item ).
    ENDIF.
  ENDMETHOD.
