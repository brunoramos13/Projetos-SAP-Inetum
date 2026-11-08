REPORT zbr_r_approval_dashboard.

TABLES: zbr_t_request.

SELECT-OPTIONS: s_empid FOR zbr_t_request-employee_id NO-DISPLAY,
                s_type  FOR zbr_t_request-absence_type NO-DISPLAY,
                s_stat  FOR zbr_t_request-status NO-DISPLAY,
                s_cdate FOR zbr_t_request-Created_on NO-DISPLAY,
                s_sdate FOR zbr_t_request-start_date NO-DISPLAY.

TYPES: BEGIN OF ty_alv,
         request_id   TYPE zbr_de_req_id,     
         employee_id  TYPE zbr_de_emp_id,     
         emp_name     TYPE zbr_de_emp_name,   
         absence_type TYPE zbr_de_abs_type,   
         abs_desc     TYPE zbr_de_abs_desc,   
         start_date   TYPE zbr_de_start_date, 
         end_date     TYPE zbr_de_end_date,   
         total_days   TYPE zbr_de_tot_days,   
         status       TYPE zbr_de_status,    
       END OF ty_alv.

DATA: gt_alv TYPE TABLE OF ty_alv, 
      gs_alv TYPE ty_alv,           
      go_alv TYPE REF TO cl_salv_table.
CLASS lcl_events DEFINITION.
  PUBLIC SECTION.
    METHODS: on_click FOR EVENT added_function OF cl_salv_events_table
      IMPORTING e_salv_function,
      on_double_click FOR EVENT double_click OF cl_salv_events_table
        IMPORTING row column.
ENDCLASS.

CLASS lcl_events IMPLEMENTATION.
  METHOD on_double_click.
    DATA: ls_log_filter TYPE bal_s_lfil,
          ls_extnumber  TYPE bal_s_extn,
          ls_object     TYPE bal_s_obj,
          lt_log_header TYPE balhdr_t,
          lt_log_handle TYPE bal_t_logh.

    READ TABLE gt_alv INTO gs_alv INDEX row.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CALL FUNCTION 'BAL_GLB_MEMORY_REFRESH'.
    ls_object-sign   = 'I'.
    ls_object-option = 'EQ'.
    ls_object-low    = 'ZBR_ABSENCE'.
    APPEND ls_object TO ls_log_filter-object.

    ls_extnumber-sign   = 'I'.
    ls_extnumber-option = 'CP'.  
    ls_extnumber-low    = |*{ gs_alv-request_id }*|.
    APPEND ls_extnumber TO ls_log_filter-extnumber.

    CALL FUNCTION 'BAL_DB_SEARCH'
      EXPORTING
        i_s_log_filter = ls_log_filter
      IMPORTING
        e_t_log_header = lt_log_header
      EXCEPTIONS
        log_not_found  = 1
        OTHERS         = 2.

    IF sy-subrc = 0.
      CALL FUNCTION 'BAL_DB_LOAD'
        EXPORTING
          i_t_log_header = lt_log_header
        IMPORTING
          e_t_log_handle = lt_log_handle
        EXCEPTIONS
          OTHERS         = 3.
      IF sy-subrc = 0.
        CALL FUNCTION 'BAL_DSP_LOG_DISPLAY'
          EXPORTING
            i_s_log_filter = ls_log_filter " 
          EXCEPTIONS
            OTHERS         = 1.
      ENDIF.
    ELSE.
      MESSAGE 'Ainda não existem logs de auditoria para este pedido.' TYPE 'I'.
    ENDIF.

  ENDMETHOD.

  METHOD on_click.
    DATA: lt_rows        TYPE salv_t_row,      
          lv_row         TYPE int4,
          ls_balance     TYPE zbr_t_balance,   
          lv_ano         TYPE c LENGTH 4,      
          lv_dias_livres TYPE i,               
          lv_old_status  TYPE zbr_de_status.   

    lt_rows = go_alv->get_selections( )->get_selected_rows( ).

    IF e_salv_function = 'BTN_REF'.
      PERFORM z_carregar_dados.
      go_alv->refresh( ).
      MESSAGE 'Dados atualizados com sucesso!' TYPE 'S'.
      RETURN. 
    ENDIF.

    IF e_salv_function = 'BTN_IDOC'.
      DATA: lv_count        TYPE i VALUE 0,
            ls_edidc        TYPE edidc,
            lt_edidd        TYPE TABLE OF edidd,
            ls_edidd        TYPE edidd,
            ls_segment      TYPE z1br_absence,
            lt_comm_control TYPE TABLE OF edidc,
            ls_audit_idoc   TYPE zbr_t_audit.

      IF lt_rows IS INITIAL.
        MESSAGE 'Seleciona pelo menos um pedido Aprovado ou Rejeitado!' TYPE 'W'.
        RETURN.
      ENDIF.

      LOOP AT lt_rows INTO lv_row.
        READ TABLE gt_alv INTO gs_alv INDEX lv_row.

        IF gs_alv-status = 'A' OR gs_alv-status = 'R'.
          CLEAR: ls_edidc, lt_edidd, ls_edidd, ls_segment, lt_comm_control.

          ls_edidc-mestyp = 'ZBR_ABS_SYNC'.
          ls_edidc-idoctp = 'ZBR_IDOC_ABS'.
          ls_edidc-rcvprt = 'LS'.
          ls_edidc-rcvprn = 'HR_EXTERNO'.

          ls_segment-employee_id  = gs_alv-employee_id.
          ls_segment-absence_type = gs_alv-absence_type.
          ls_segment-start_date   = gs_alv-start_date.
          ls_segment-end_date     = gs_alv-end_date.
          ls_segment-total_days   = gs_alv-total_days.
          CONDENSE ls_segment-total_days.
          ls_segment-status       = gs_alv-status.

          ls_edidd-segnam = 'Z1BR_ABSENCE'.
          ls_edidd-sData  = ls_segment.
          APPEND ls_edidd TO lt_edidd.

          CALL FUNCTION 'MASTER_IDOC_DISTRIBUTE'
            EXPORTING
              master_idoc_control        = ls_edidc
            TABLES
              communication_idoc_control = lt_comm_control
              master_idoc_data           = lt_edidd
            EXCEPTIONS
              OTHERS                     = 1.

          IF sy-subrc = 0.
            COMMIT WORK.

            READ TABLE lt_comm_control INTO DATA(ls_comm_control) INDEX 1.

            IF sy-subrc = 0.
              DATA: lv_idoc_num TYPE string.
              lv_idoc_num = ls_comm_control-docnum.

              SHIFT lv_idoc_num LEFT DELETING LEADING '0'.
              ls_audit_idoc-log_id   = |{ gs_alv-request_id }-IDOC-{ lv_idoc_num }|.
              ls_audit_idoc-log_date = sy-datum.
              ls_audit_idoc-log_time = sy-uzeit.
              ls_audit_idoc-sap_user = sy-uname.
              ls_audit_idoc-action   = 'IDOC CRIADO'.
              ls_audit_idoc-details  = |IDOC { lv_idoc_num } criado em { sy-datum+6(2) }.{ sy-datum+4(2) }.{ sy-datum(4) } por { sy-uname } do pedido { gs_alv-request_id } ({ gs_alv-status }).|.

              INSERT zbr_t_audit FROM ls_audit_idoc.

              CALL FUNCTION 'ZBR_GRAVAR_LOG_SLG1'
                EXPORTING
                  iv_subobject = 'IDOCS'
                  iv_ext_id    = gs_alv-request_id
                  iv_mensagem  = ls_audit_idoc-details
                  iv_tipo      = 'S'.
            ENDIF.

            lv_count = lv_count + 1.
          ENDIF.
        ENDIF.
      ENDLOOP.

      IF lv_count > 0.
        MESSAGE |{ lv_count } pedido(s) exportado(s) com sucesso para os RH!| TYPE 'I' DISPLAY LIKE 'S'.
      ELSE.
        MESSAGE 'Nenhum pedido válido foi selecionado. Apenas pedidos com estado "A" ou "R" são exportados.' TYPE 'I' DISPLAY LIKE 'E'.
      ENDIF.

      RETURN.
    ENDIF.

    IF e_salv_function = 'BTN_IDOC_G'.
      DATA: ls_edidc_g TYPE edidc,
            lt_edidd_g TYPE TABLE OF edidd,
            ls_edidd_g TYPE edidd,
            ls_seg_g   TYPE z1br_absence,
            lt_comm_g  TYPE TABLE OF edidc,
            lv_count_g TYPE i VALUE 0,
            ls_audit_g TYPE zbr_t_audit.

      IF lt_rows IS INITIAL.
        MESSAGE 'Seleciona pelo menos um pedido Aprovado/Rejeitado para o IDoc Global!' TYPE 'W'.
        RETURN.
      ENDIF.

      ls_edidc_g-mestyp = 'ZBR_ABS_SYNC'.
      ls_edidc_g-idoctp = 'ZBR_IDOC_ABS'.
      ls_edidc_g-rcvprt = 'LS'.
      ls_edidc_g-rcvprn = 'HR_EXTERNO'.
      LOOP AT lt_rows INTO lv_row.
        READ TABLE gt_alv INTO gs_alv INDEX lv_row.

        IF gs_alv-status = 'A' OR gs_alv-status = 'R'.
          CLEAR: ls_seg_g, ls_edidd_g.
          ls_seg_g-employee_id  = gs_alv-employee_id.
          ls_seg_g-absence_type = gs_alv-absence_type.
          ls_seg_g-start_date   = gs_alv-start_date.
          ls_seg_g-end_date     = gs_alv-end_date.
          ls_seg_g-total_days   = gs_alv-total_days.
          CONDENSE ls_seg_g-total_days.
          ls_seg_g-status       = gs_alv-status.

          ls_edidd_g-segnam = 'Z1BR_ABSENCE'.
          ls_edidd_g-sData  = ls_seg_g.
          APPEND ls_edidd_g TO lt_edidd_g.

          lv_count_g = lv_count_g + 1.
        ENDIF.
      ENDLOOP.

      IF lv_count_g = 0.
        MESSAGE 'Nenhum dos pedidos selecionados é válido. Apenas "A" ou "R" vão para o IDoc.' TYPE 'W'.
        RETURN.
      ENDIF.

      CALL FUNCTION 'MASTER_IDOC_DISTRIBUTE'
        EXPORTING
          master_idoc_control        = ls_edidc_g
        TABLES
          communication_idoc_control = lt_comm_g
          master_idoc_data           = lt_edidd_g
        EXCEPTIONS
          OTHERS                     = 1.

      IF sy-subrc = 0.
        COMMIT WORK.

        READ TABLE lt_comm_g INTO DATA(ls_comm_g) INDEX 1.
        IF sy-subrc = 0.
          DATA(lv_idoc_num_g) = ls_comm_g-docnum.
          SHIFT lv_idoc_num_g LEFT DELETING LEADING '0'.
          DATA(lv_data_formatada) = |{ sy-datum+6(2) }.{ sy-datum+4(2) }.{ sy-datum(4) }|.
          ls_audit_g-log_id   = |GLOBAL-IDOC-{ lv_idoc_num_g }|.
          ls_audit_g-log_date = sy-datum.
          ls_audit_g-log_time = sy-uzeit.
          ls_audit_g-sap_user = sy-uname.
          ls_audit_g-action   = 'IDOC GLOBAL'.
          ls_audit_g-details  = |GLOBAL-IDOC { lv_idoc_num_g } criado em { lv_data_formatada } por { sy-uname } com { lv_count_g } pedido(s) agrupados.|.

          INSERT zbr_t_audit FROM ls_audit_g.

          CALL FUNCTION 'ZBR_GRAVAR_LOG_SLG1'
            EXPORTING
              iv_subobject = 'IDOCS'
              iv_ext_id    = ls_audit_g-log_id
              iv_mensagem  = ls_audit_g-details
              iv_tipo      = 'S'.

          MESSAGE |IDoc Global exportado com sucesso! ({ lv_count_g } pedidos processados).| TYPE 'S'.
        ENDIF.
      ELSE.
        MESSAGE 'Erro ao gerar o IDoc Global.' TYPE 'E'.
      ENDIF.

      RETURN.
    ENDIF.

    IF lt_rows IS INITIAL.
      MESSAGE 'Por favor, seleciona um pedido primeiro!' TYPE 'W'. "#EC NOTEXT
      RETURN.
    ENDIF.

    READ TABLE lt_rows INTO lv_row INDEX 1.
    READ TABLE gt_alv INTO gs_alv INDEX lv_row.
    lv_old_status = gs_alv-status.

    IF e_salv_function = 'BTN_APP' OR e_salv_function = 'BTN_REJ'.
      IF lv_old_status <> 'P'.
        MESSAGE 'Este pedido já foi processado! Só podes alterar pedidos Pendentes.' TYPE 'I' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ELSEIF e_salv_function = 'BTN_RESET'.
      IF lv_old_status = 'P'.
        MESSAGE 'Este pedido já está Pendente! Não há nada para reverter.' TYPE 'I' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ENDIF.

    IF e_salv_function = 'BTN_APP' OR ( e_salv_function = 'BTN_RESET' AND lv_old_status = 'A' ).

      lv_ano = gs_alv-start_date(4). " Extrai o ano

      SELECT SINGLE *
        FROM zbr_t_balance
        INTO ls_balance
       WHERE employee_id = gs_alv-employee_id
         AND ref_year = lv_ano
         AND absence_type = gs_alv-absence_type.

      IF sy-subrc = 0.
        IF e_salv_function = 'BTN_APP'.
          lv_dias_livres = ls_balance-entitled_days - ls_balance-used_days.
          IF gs_alv-total_days > lv_dias_livres.
            MESSAGE |Aprovação recusada: Apenas tem { lv_dias_livres } dias para gastar| TYPE 'I' DISPLAY LIKE 'E'.
            RETURN.
          ENDIF.

          DATA: ls_Overlap TYPE zbr_t_request.

          SELECT SINGLE *
            FROM zbr_t_request
            INTO ls_Overlap
           WHERE employee_id = gs_alv-employee_id
             AND status      = 'A'
             AND start_date <= gs_alv-end_date
             AND end_date   >= gs_alv-start_date.

          IF sy-subrc = 0. 
            
            DATA: lv_data_ini TYPE string,
                  lv_data_fim TYPE string.

            lv_data_ini = |{ ls_Overlap-start_date+6(2) }.{ ls_Overlap-start_date+4(2) }.{ ls_Overlap-start_date(4) }|.
            lv_data_fim = |{ ls_Overlap-end_date+6(2) }.{ ls_Overlap-end_date+4(2) }.{ ls_Overlap-end_date(4) }|.

            MESSAGE |Aprovação recusada: Já existe um pedido APROVADO ({ ls_Overlap-request_id }) de { lv_data_ini } a { lv_data_fim }| TYPE 'I' DISPLAY LIKE 'E'.
            RETURN.
          ENDIF.
        ENDIF.
      ELSE.
        MESSAGE 'Erro: Não existe registo de saldo para este colaborador/ano.' TYPE 'I' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    ENDIF.

    DATA: lv_msg_tipo TYPE c.
    CASE e_salv_function.
      WHEN 'BTN_APP'.
        gs_alv-status = 'A'.
        lv_msg_tipo = 'S'.
        MESSAGE |O pedido { gs_alv-request_id } do(a) { gs_alv-emp_name } ({ gs_alv-employee_id }) foi APROVADO.| TYPE 'I' DISPLAY LIKE 'S'.
      WHEN 'BTN_REJ'.
        gs_alv-status = 'R'.
        lv_msg_tipo = 'E'. 
        MESSAGE |O pedido { gs_alv-request_id } do(a) { gs_alv-emp_name } ({ gs_alv-employee_id }) foi REJEITADO!| TYPE 'I' DISPLAY LIKE 'E'.
      WHEN 'BTN_RESET'.
        gs_alv-status = 'P'.
        lv_msg_tipo = 'W'. 
        MESSAGE |O pedido { gs_alv-request_id } do(a) { gs_alv-emp_name } ({ gs_alv-employee_id }) voltou a PENDENTE!| TYPE 'I' DISPLAY LIKE 'S'.
    ENDCASE.

    UPDATE zbr_t_request
       SET status     = gs_alv-status
           changed_by = sy-uname
           changed_on = sy-datum
           changed_at = sy-uzeit
     WHERE request_id = gs_alv-request_id.

    IF sy-subrc = 0.

      IF e_salv_function = 'BTN_APP'.
        ls_balance-used_days = ls_balance-used_days + gs_alv-total_days.
      ELSEIF e_salv_function = 'BTN_RESET' AND lv_old_status = 'A'.
        ls_balance-used_days = ls_balance-used_days - gs_alv-total_days.
      ENDIF.

      IF ( e_salv_function = 'BTN_APP' ) OR ( e_salv_function = 'BTN_RESET' AND lv_old_status = 'A' ).
        ls_balance-changed_by = sy-uname.
        ls_balance-changed_on = sy-datum.
        ls_balance-changed_at = sy-uzeit.
        UPDATE zbr_t_balance FROM ls_balance.
      ENDIF.

      DATA: ls_audit TYPE zbr_t_audit.
      ls_audit-log_id   = |{ gs_alv-request_id }-{ sy-uzeit }|.
      ls_audit-log_date = sy-datum.
      ls_audit-log_time = sy-uzeit.
      ls_audit-sap_user = sy-uname.

      CASE e_salv_function.
        WHEN 'BTN_APP'.
          ls_audit-action  = 'APROVADO'.
          ls_audit-details = |O pedido { gs_alv-request_id } do(a) { gs_alv-emp_name } ({ gs_alv-employee_id }) foi APROVADO.|.
        WHEN 'BTN_REJ'.
          ls_audit-action  = 'REJEITADO'.
          ls_audit-details = |O pedido { gs_alv-request_id } do(a) { gs_alv-emp_name } ({ gs_alv-employee_id }) foi REJEITADO.|.
        WHEN 'BTN_RESET'.
          ls_audit-action  = 'RESET'.
          ls_audit-details = |O pedido { gs_alv-request_id } do(a) { gs_alv-emp_name } ({ gs_alv-employee_id }) voltou a PENDENTE. (Era: { lv_old_status }).|.
      ENDCASE.

      INSERT zbr_t_audit FROM ls_audit.

      CALL FUNCTION 'ZBR_GRAVAR_LOG_SLG1'
        EXPORTING
          iv_subobject = 'PEDIDOS'
          iv_ext_id    = gs_alv-request_id
          iv_mensagem  = ls_audit-details
          iv_tipo      = lv_msg_tipo.

      MODIFY gt_alv FROM gs_alv INDEX lv_row.
      go_alv->refresh( ).

    ELSE.
      MESSAGE 'Erro ao atualizar a base de dados.' TYPE 'E'.
    ENDIF.

  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  PERFORM z_carregar_dados.

  IF gt_alv IS NOT INITIAL.
    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = go_alv
          CHANGING
            t_table      = gt_alv ).

        go_alv->get_selections( )->set_selection_mode( if_salv_c_selection_mode=>row_column ).

        go_alv->set_screen_status(
          pfstatus      = 'ZALV'
          report        = sy-repid
          set_functions = go_alv->c_functions_all ).

        DATA: lo_events  TYPE REF TO cl_salv_events_table,
              lo_handler TYPE REF TO lcl_events.

        lo_events = go_alv->get_event( ).
        CREATE OBJECT lo_handler.
        SET HANDLER lo_handler->on_click FOR lo_events.
        SET HANDLER lo_handler->on_double_click FOR lo_events.

        go_alv->get_functions( )->set_all( abap_true ).

        go_alv->display( ).

      CATCH cx_salv_msg.
        MESSAGE 'Erro ao tentar mostrar o ecrã.' TYPE 'E'.
    ENDTRY.

  ELSE.
    MESSAGE 'Nenhum pedido encontrado!' TYPE 'I'.
  ENDIF.

FORM z_carregar_dados.

  CLEAR gt_alv.

  SELECT req~request_id,
         req~employee_id,
         emp~name AS emp_name,
         abs~absence_type,
         abs~Description AS abs_desc,
         req~start_date,
         req~end_date,
         req~total_days,
         req~status
    FROM zbr_t_request AS req
    INNER JOIN zbr_t_employee AS emp
      ON req~employee_id = emp~employee_id
    INNER JOIN zbr_t_abs_type AS abs
      ON req~absence_type = abs~absence_type
    INTO TABLE @gt_alv
    WHERE req~employee_id  IN @s_empid
      AND req~absence_type IN @s_type
      AND req~status       IN @s_stat
      AND req~Created_on   IN @s_cdate
      AND req~start_date   IN @s_sdate.

  IF sy-subrc = 0.
    DATA: ls_audit_exp TYPE zbr_t_audit,
          ls_req_upd   TYPE zbr_t_request.

    LOOP AT gt_alv ASSIGNING FIELD-SYMBOL(<fs_req>) WHERE status = 'P' AND start_date <= sy-datum.
      <fs_req>-status = 'R'.

      MOVE-CORRESPONDING <fs_req> TO ls_req_upd.
      ls_req_upd-changed_by = 'SISTEMA'.
      ls_req_upd-changed_on = sy-datum.
      ls_req_upd-changed_at = sy-uzeit.
      UPDATE zbr_t_request FROM ls_req_upd.

      ls_audit_exp-log_id   = |{ ls_req_upd-request_id }-{ sy-uzeit }|.
      ls_audit_exp-log_date = sy-datum.
      ls_audit_exp-log_time = sy-uzeit.
      ls_audit_exp-sap_user = 'SISTEMA'.
      ls_audit_exp-action   = 'REJEITADO'.
      ls_audit_exp-details  = |O pedido { ls_req_upd-request_id } do(a) { <fs_req>-emp_name } ({ ls_req_upd-employee_id }) foi REJEITADO automaticamente (data Expirada).|.

      INSERT zbr_t_audit FROM ls_audit_exp.

      CALL FUNCTION 'ZBR_GRAVAR_LOG_SLG1'
        EXPORTING
          iv_subobject = 'PEDIDOS'
          iv_ext_id    = ls_audit_exp-log_id
          iv_mensagem  = ls_audit_exp-details
          iv_tipo      = 'E'.
    ENDLOOP.
  ENDIF.
ENDFORM.
