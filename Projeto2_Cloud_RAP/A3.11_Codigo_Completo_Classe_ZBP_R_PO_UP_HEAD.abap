CLASS lhc_Upload DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Upload RESULT result.

    METHODS ParseExcel FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Upload~ParseExcel.

    METHODS ValidateAttachment FOR VALIDATE ON SAVE
      IMPORTING keys FOR Upload~ValidateAttachment.

    METHODS GeneratePOs FOR MODIFY
      IMPORTING keys FOR ACTION Upload~GeneratePOs RESULT result.

    METHODS FetchPONumber FOR MODIFY
      IMPORTING keys FOR ACTION Upload~FetchPONumber RESULT result.

ENDCLASS.

CLASS lhc_Upload IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD ParseExcel.
    TYPES: BEGIN OF ty_excel_row,
             purchaseordertype      TYPE string, " Coluna A
             companycode            TYPE string, " Coluna B
             purchasingorganization TYPE string, " Coluna C
             purchasinggroup        TYPE string, " Coluna D
             supplier               TYPE string, " Coluna E
             material               TYPE string, " Coluna F
             plant                  TYPE string, " Coluna G
             quantity               TYPE string, " Coluna H
             netpriceamount         TYPE string, " Coluna I
             documentcurrency       TYPE string, " Coluna J
             delivery_date          TYPE string, " Coluna K
           END OF ty_excel_row.

    DATA lt_excel_data   TYPE STANDARD TABLE OF ty_excel_row.
    DATA lt_create_items TYPE TABLE FOR CREATE zr_po_up_head\_Itens. " Tabela para os Itens
    DATA lt_create_logs  TYPE TABLE FOR CREATE zr_po_up_head\_Logs.  " Tabela para os Logs

    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload
      FIELDS ( Attachment FileName ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_upload).

    LOOP AT lt_upload INTO DATA(ls_upload).
      IF ls_upload-Attachment IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA ls_create_log LIKE LINE OF lt_create_logs.
      ls_create_log-%tky = ls_upload-%tky.

      DATA ls_create_item LIKE LINE OF lt_create_items.
      ls_create_item-%tky = ls_upload-%tky.


      " 1. VALIDAÇÃO ANTI-DUMP (Para o tipo de ficheiro - xlsx)
      DATA(lv_filename_upper) = to_upper( ls_upload-FileName ).
      IF lv_filename_upper NP '*.XLSX'.
        APPEND VALUE #(
          %cid     = 'LOG_FILE_ERR'
          %is_draft = ls_upload-%is_draft
          MsgType  = 'E'
          MsgText  = '1 : File type incorrect. Must be an Excel (.xlsx) file.'
          %control = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
        ) TO ls_create_log-%target.

        APPEND ls_create_log TO lt_create_logs.
        CONTINUE.
      ELSE.
        APPEND VALUE #(
          %cid     = 'LOG_FILE_OK'
          %is_draft = ls_upload-%is_draft
          MsgType  = 'S'
          MsgText  = '1 : File type correct (.xlsx). Reading Excel Lines...'
          %control = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
        ) TO ls_create_log-%target.
      ENDIF.


      " 2. LEITURA SEGURA DO EXCEL (Proteção de ficheiros corrompidos)
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

        CATCH cx_root.
          " Apanhar qualquer erro interno do SAP na leitura (Excel vazio ou corrompido)
          APPEND VALUE #(
            %cid     = 'LOG_CORRUPT'
            %is_draft = ls_upload-%is_draft
            MsgType  = 'E'
            MsgText  = '1 : Error reading file. The file is empty or corrupted.'
            %control = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
          ) TO ls_create_log-%target.

          APPEND ls_create_log TO lt_create_logs.
          CONTINUE.
      ENDTRY.


      " 3. LOOP PELAS LINHAS DO EXCEL
      DATA(lv_index) = 1.

      LOOP AT lt_excel_data INTO DATA(ls_excel_row) WHERE supplier IS NOT INITIAL OR material IS NOT INITIAL.

        REPLACE ALL OCCURRENCES OF '-' IN ls_excel_row-delivery_date WITH ''.
        REPLACE ALL OCCURRENCES OF ',' IN ls_excel_row-quantity WITH '.'.
        REPLACE ALL OCCURRENCES OF ',' IN ls_excel_row-netpriceamount WITH '.'.

        " Começar a contagem do ExcelRow em 2 para ficar igual ao excel
        DATA(lv_excel_row) = lv_index + 1.
        DATA(lv_row_str) = CONV string( lv_excel_row ).

        DATA lv_status   TYPE string.
        DATA lv_message  TYPE string.
        DATA lv_err_txt  TYPE string.

        CLEAR: lv_status, lv_message, lv_err_txt.
        lv_status = 'Ready'.

        DATA(lv_quant)         = CONV decfloat16( condense( val = ls_excel_row-quantity ) ).
        DATA(lv_price)         = CONV decfloat16( condense( val = ls_excel_row-netpriceamount ) ).
        DATA(lv_bsart_clean)   = to_upper( condense( val = ls_excel_row-purchaseordertype ) ).
        DATA(lv_bukrs_clean)   = to_upper( condense( val = ls_excel_row-companycode ) ).
        DATA(lv_ekorg_clean)   = to_upper( condense( val = ls_excel_row-purchasingorganization ) ).
        DATA(lv_ekgrp_clean)   = to_upper( condense( val = ls_excel_row-purchasinggroup ) ).

        " VALIDAÇÕES DE NEGÓCIO - CABEÇALHO
        IF lv_bsart_clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'PO Type' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SELECT SINGLE PurchasingDocumentType FROM I_PurchasingDocumentType WITH PRIVILEGED ACCESS
            WHERE PurchasingDocumentType = @lv_bsart_clean INTO @DATA(lv_bsart_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'PO Type' lv_bsart_clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        IF lv_bukrs_clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Company Code' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SELECT SINGLE CompanyCode FROM I_CompanyCode WITH PRIVILEGED ACCESS
            WHERE CompanyCode = @lv_bukrs_clean INTO @DATA(lv_bukrs_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Company Code' lv_bukrs_clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        IF lv_ekorg_clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Purch. Org.' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SELECT SINGLE PurchasingOrganization FROM I_PurchasingOrganization WITH PRIVILEGED ACCESS
            WHERE PurchasingOrganization = @lv_ekorg_clean INTO @DATA(lv_ekorg_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Purch. Org.' lv_ekorg_clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        IF lv_ekgrp_clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Purch. Group' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SELECT SINGLE PurchasingGroup FROM I_PurchasingGroup WITH PRIVILEGED ACCESS
            WHERE PurchasingGroup = @lv_ekgrp_clean INTO @DATA(lv_ekgrp_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Purch. Group' lv_ekgrp_clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        DATA(lv_sup_clean) = condense( val = ls_excel_row-supplier ).
        IF lv_sup_clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Supplier' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SPLIT lv_sup_clean AT '.' INTO lv_sup_clean DATA(dummy_sup).
          lv_sup_clean = to_upper( lv_sup_clean ).
          DATA lv_sup_char TYPE c LENGTH 10.
          lv_sup_char = lv_sup_clean.
          lv_sup_char = |{ lv_sup_char ALPHA = IN }|.
          SELECT SINGLE Supplier FROM I_Supplier WITH PRIVILEGED ACCESS
            WHERE Supplier = @lv_sup_char INTO @DATA(lv_sup_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Supplier' lv_sup_clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        " VALIDAÇÕES DE NEGÓCIO - ITEM
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

        DATA(lv_mat_clean) = condense( val = ls_excel_row-material ).
        IF lv_mat_clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Material' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SPLIT lv_mat_clean AT '.' INTO lv_mat_clean DATA(dummy_mat).
          lv_mat_clean = to_upper( lv_mat_clean ).
          SELECT SINGLE Product FROM I_Product WITH PRIVILEGED ACCESS
            WHERE Product = @lv_mat_clean INTO @DATA(lv_mat_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Material' lv_mat_clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        DATA(lv_plant_clean) = condense( val = ls_excel_row-plant ).
        IF lv_plant_clean IS INITIAL.
          lv_status = 'Error'.
          MESSAGE e001(zmc_po_upload) WITH 'Plant' INTO lv_err_txt.
          lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
        ELSE.
          SPLIT lv_plant_clean AT '.' INTO lv_plant_clean DATA(dummy_plant).
          lv_plant_clean = to_upper( lv_plant_clean ).
          SELECT SINGLE Plant FROM I_Plant WITH PRIVILEGED ACCESS
            WHERE Plant = @lv_plant_clean INTO @DATA(lv_plant_check).
          IF sy-subrc <> 0.
            lv_status = 'Error'.
            MESSAGE e002(zmc_po_upload) WITH 'Plant' lv_plant_clean INTO lv_err_txt.
            lv_message = COND #( WHEN lv_message IS INITIAL THEN lv_err_txt ELSE lv_message && |; | && lv_err_txt ).
          ENDIF.
        ENDIF.

        " INSERIR OS DADOS NA TABELA INTERNA
        APPEND VALUE #(
            %cid                   = 'ITEM_' && condense( val = CONV string( lv_index ) )
            %is_draft              = ls_upload-%is_draft
            ExcelRow               = lv_excel_row
            PurchaseOrderType      = lv_bsart_clean
            CompanyCode            = lv_bukrs_clean
            PurchasingOrganization = lv_ekorg_clean
            PurchasingGroup        = lv_ekgrp_clean
            DocumentCurrency       = condense( val = ls_excel_row-documentcurrency )
            NetPriceAmount         = lv_price
            Supplier               = lv_sup_clean
            Material               = lv_mat_clean
            Plant                  = lv_plant_clean
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
        ) TO ls_create_item-%target.

        " REGISTAR O LOG DE ERRO OU SUCESSO
        IF lv_status = 'Error'.
          DATA(lv_log_text) = |{ lv_row_str } : Validation failed --> { lv_message }|.

          APPEND VALUE #(
              %cid      = 'LOG_' && condense( val = CONV string( lv_index ) )
              %is_draft = ls_upload-%is_draft
              MsgType   = 'E'
              MsgText   = CONV #( lv_log_text )
              %control  = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
          ) TO ls_create_log-%target.

        ELSE.
          DATA(lv_log_succ) = |{ lv_row_str } : Validated successfully (Ready for PO)|.

          APPEND VALUE #(
              %cid      = 'LOG_' && condense( val = CONV string( lv_index ) )
              %is_draft = ls_upload-%is_draft
              MsgType   = 'S'
              MsgText   = CONV #( lv_log_succ )
              %control  = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
          ) TO ls_create_log-%target.
        ENDIF.

        lv_index += 1.
      ENDLOOP.

      APPEND ls_create_item TO lt_create_items.

      IF ls_create_log-%target IS NOT INITIAL.
        APPEND ls_create_log TO lt_create_logs.
      ENDIF.
    ENDLOOP.

    " 4. DAR COMMIT PARA A BASE DE DADOS
    IF lt_create_items IS NOT INITIAL OR lt_create_logs IS NOT INITIAL.
      MODIFY ENTITIES OF zr_po_up_head IN LOCAL MODE
        ENTITY Upload
        CREATE BY \_Itens FROM lt_create_items
        CREATE BY \_Logs  FROM lt_create_logs
        REPORTED DATA(lt_reported).

      reported-upload = CORRESPONDING #( lt_reported-upload ).
      reported-item   = CORRESPONDING #( lt_reported-item ).
    ENDIF.

  ENDMETHOD.

  METHOD ValidateAttachment.
    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload FIELDS ( Attachment ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_upload).
    LOOP AT lt_upload INTO DATA(ls_upload).
      IF ls_upload-Attachment IS INITIAL.
        APPEND VALUE #( %tky = ls_upload-%tky ) TO failed-upload.
        APPEND VALUE #( %tky = ls_upload-%tky %msg = new_message( id = '00' number = 001 severity = if_abap_behv_message=>severity-error v1 = 'Excel file attachment cannot be empty' ) %element-Attachment = if_abap_behv=>mk-on ) TO reported-upload.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD GeneratePOs.
    " 1. Ler todos os cabeçalhos selecionados
    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_upload).

    " 2. Ler os Itens associados aos Cabeçalhos
    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload BY \_Itens ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    DATA lt_update_items TYPE TABLE FOR UPDATE zr_po_up_item.
    DATA lt_update_headers TYPE TABLE FOR UPDATE zr_po_up_head.
    DATA lt_create_logs TYPE TABLE FOR CREATE zr_po_up_head\_Logs.

    " 3. Processar por Ficheiro
    LOOP AT lt_upload INTO DATA(ls_upload).
      DATA ls_create_log LIKE LINE OF lt_create_logs.
      ls_create_log-%tky = ls_upload-%tky.

      DATA lt_valid_items LIKE lt_items.
      CLEAR lt_valid_items.

      LOOP AT lt_items INTO DATA(ls_check_item)
           WHERE UploadUuid = ls_upload-UploadUuid
             AND ItemStatus = 'Ready'
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

      " Criar o CARIMBO atraves do id do upload (Converter o UUID binário para texto)
      DATA lv_tracking_id TYPE c LENGTH 12.
      TRY.
          cl_system_uuid=>convert_uuid_x16_static(
            EXPORTING uuid     = ls_upload-UploadUuid
            IMPORTING uuid_c32 = DATA(lv_uuid_c32)
          ).
          " Apanha os ÚLTIMOS 12 carateres
          lv_tracking_id = lv_uuid_c32+20(12).
        CATCH cx_root.
          lv_tracking_id = 'ERRO_UUID'.
      ENDTRY.

      " Preencher os itens usando um CID ÚNICO com base no carimbo
      DATA lt_po_items TYPE TABLE FOR CREATE I_PurchaseOrderTP_2\_PurchaseOrderItem.
      lt_po_items = VALUE #( (
        %cid_ref = |PO_{ lv_tracking_id }|
        %target  = VALUE #( FOR ls_item IN lt_valid_items INDEX INTO idx (
          %cid                      = |ITM_{ lv_tracking_id }_{ idx }|
          Material                  = ls_item-Material
          Plant                     = ls_item-Plant
          OrderQuantity             = ls_item-Quantity
          NetPriceAmount            = ls_item-NetPriceAmount
          DocumentCurrency          = ls_item-DocumentCurrency
          "PurchaseOrderQuantityUnit = 'PC'
        ) )
      ) ).

      " 4. Chamar a API Standard Moderna (Injetando o Carimbo e usando o CID ÚNICO)
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
        MAPPED DATA(lt_mapped_po)
        FAILED DATA(lt_failed_po)
        REPORTED DATA(lt_reported_po).

      " 5. Avaliar o resultado
      IF lt_failed_po-purchaseorder IS INITIAL AND lt_mapped_po-purchaseorder IS NOT INITIAL.
        " A API Cloud usa Late Numbering, por isso o ID real só é gerado no Commit.

        " Atualizar as Linhas
        LOOP AT lt_valid_items INTO DATA(ls_valid_item).
          APPEND VALUE #( %tky = ls_valid_item-%tky
                          ItemStatus = 'Success'
                          ItemMessage = 'PO Accepted by API. Use Fetch Button to retrieve PO Number.'
                          %control = VALUE #( ItemStatus = if_abap_behv=>mk-on ItemMessage = if_abap_behv=>mk-on )
                        ) TO lt_update_items.
        ENDLOOP.

        " Log de Sucesso
        DATA(lv_log_success) = |Purchase Order accepted. Use Fetch Button to retrieve PO Number.|.
        APPEND VALUE #(
          %cid     = 'LOG_SUCC_PO'
          %is_draft = ls_upload-%is_draft
          MsgType  = 'S'
          MsgText  = CONV #( lv_log_success )
          %control = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
        ) TO ls_create_log-%target.

      ELSE.
        DATA(lv_error_msg) = 'API rejected PO creation'.
        IF line_exists( lt_reported_po-purchaseorder[ 1 ] ).
          lv_error_msg = lt_reported_po-purchaseorder[ 1 ]-%msg->if_message~get_text( ).
        ENDIF.

        LOOP AT lt_valid_items INTO DATA(ls_error_item).
          APPEND VALUE #( %tky = ls_error_item-%tky
                          ItemStatus = 'Error'
                          ItemMessage = lv_error_msg
                          %control = VALUE #( ItemStatus = if_abap_behv=>mk-on ItemMessage = if_abap_behv=>mk-on )
                        ) TO lt_update_items.
        ENDLOOP.

        DATA(lv_err_trunc) = CONV string( lv_error_msg ).
        IF strlen( lv_err_trunc ) > 100.
          lv_err_trunc = lv_err_trunc(97) && '...'.
        ENDIF.

        DATA(lv_log_error) = |PO Creation failed - { lv_err_trunc }|.
        APPEND VALUE #(
          %cid     = 'LOG_ERR_PO'
          %is_draft = ls_upload-%is_draft
          MsgType  = 'E'
          MsgText  = CONV #( lv_log_error )
          %control = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
        ) TO ls_create_log-%target.
      ENDIF.

      IF ls_create_log-%target IS NOT INITIAL.
        APPEND ls_create_log TO lt_create_logs.
      ENDIF.
    ENDLOOP.

    " 6. Gravar as alterações
    IF lt_update_headers IS NOT INITIAL.
      MODIFY ENTITIES OF zr_po_up_head IN LOCAL MODE
        ENTITY Upload UPDATE FROM lt_update_headers.
    ENDIF.

    IF lt_update_items IS NOT INITIAL.
      MODIFY ENTITIES OF zr_po_up_head IN LOCAL MODE
        ENTITY Item UPDATE FROM lt_update_items.
    ENDIF.

    IF lt_create_logs IS NOT INITIAL.
      MODIFY ENTITIES OF zr_po_up_head IN LOCAL MODE
        ENTITY Upload CREATE BY \_Logs FROM lt_create_logs.
    ENDIF.

    " 7. REFRESH DA UI
    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_upload_updated).

    result = VALUE #( FOR upload IN lt_upload_updated ( %tky = upload-%tky %param = upload ) ).
  ENDMETHOD.


  METHOD FetchPONumber.
    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_upload).

    DATA lt_update_headers TYPE TABLE FOR UPDATE zr_po_up_head.
    DATA lt_create_logs    TYPE TABLE FOR CREATE zr_po_up_head\_Logs. " <--- TABELA PARA OS NOVOS LOGS

    LOOP AT lt_upload INTO DATA(ls_upload).
      IF ls_upload-PurchaseOrder IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      " Prepara a estrutura do log para este ficheiro
      DATA ls_create_log LIKE LINE OF lt_create_logs.
      ls_create_log-%tky = ls_upload-%tky.

      " 1. LER O CARIMBO
      DATA lv_tracking_id TYPE c LENGTH 12.
      TRY.
          cl_system_uuid=>convert_uuid_x16_static(
            EXPORTING uuid     = ls_upload-UploadUuid
            IMPORTING uuid_c32 = DATA(lv_uuid_c32)
          ).
          lv_tracking_id = lv_uuid_c32+20(12).
        CATCH cx_root.
          lv_tracking_id = 'ERRO_UUID'.
      ENDTRY.

      " 2. Ir buscar o numero da PO exata com o TRINCO TRIPLO (User + Data Hoje + Carimbo Único)
      SELECT PurchaseOrder
        FROM I_PurchaseOrderAPI01 WITH PRIVILEGED ACCESS
        WHERE CreatedByUser              = @sy-uname
          AND CreationDate               = @sy-datum
          AND CorrespncInternalReference = @lv_tracking_id
        ORDER BY PurchaseOrder DESCENDING
        INTO TABLE @DATA(lt_matched_po)
        UP TO 1 ROWS.

      IF sy-subrc = 0 AND lt_matched_po IS NOT INITIAL.
        DATA(lv_real_po_number) = lt_matched_po[ 1 ]-PurchaseOrder.

        " Atualizar o Cabeçalho
        APPEND VALUE #( %tky = ls_upload-%tky
                        PurchaseOrder = lv_real_po_number
                        %control = VALUE #( PurchaseOrder = if_abap_behv=>mk-on )
                      ) TO lt_update_headers.

        " Adicionar a mensagem do Log final
        DATA(lv_log_fetch) = |Purchase Order of Excel File "{ ls_upload-FileName }" is { lv_real_po_number }|.

        APPEND VALUE #(
          %cid     = 'LOG_FINAL_' && lv_real_po_number
          %is_draft = ls_upload-%is_draft
          MsgType  = 'S'
          MsgText  = CONV #( lv_log_fetch )
          %control = VALUE #( MsgType = if_abap_behv=>mk-on MsgText = if_abap_behv=>mk-on )
        ) TO ls_create_log-%target.
      ENDIF.

      " Adiciona à tabela principal de logs (se houver algum log gerado)
      IF ls_create_log-%target IS NOT INITIAL.
        APPEND ls_create_log TO lt_create_logs.
      ENDIF.
    ENDLOOP.

    " 3. Gravar as alterações (Cabeçalhos e Logs)
    IF lt_update_headers IS NOT INITIAL.
      MODIFY ENTITIES OF zr_po_up_head IN LOCAL MODE
        ENTITY Upload UPDATE FROM lt_update_headers.
    ENDIF.

    IF lt_create_logs IS NOT INITIAL.
      MODIFY ENTITIES OF zr_po_up_head IN LOCAL MODE
        ENTITY Upload CREATE BY \_Logs FROM lt_create_logs.
    ENDIF.

    " 4. Atualizar o ecrã
    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_upload_updated).

    result = VALUE #( FOR upload IN lt_upload_updated ( %tky = upload-%tky %param = upload ) ).
  ENDMETHOD.

ENDCLASS.
