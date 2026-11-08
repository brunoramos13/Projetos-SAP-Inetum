REPORT zbr_Cockpit_ausencias.

TABLES: zbr_t_request.

SELECTION-SCREEN BEGIN OF SCREEN 101 AS SUBSCREEN.
  SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
    SELECT-OPTIONS: s_empid FOR zbr_t_request-employee_id,
                    s_type  FOR zbr_t_request-absence_type NO INTERVALS NO-EXTENSION,
                    s_stat  FOR zbr_t_request-status NO INTERVALS NO-EXTENSION,
                    s_cdate FOR zbr_t_request-Created_on,  
                    s_sdate FOR zbr_t_request-start_date.  
  SELECTION-SCREEN END OF BLOCK b1.
SELECTION-SCREEN END OF SCREEN 101.

SELECTION-SCREEN BEGIN OF SCREEN 102 AS SUBSCREEN.
  SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
    SELECTION-SCREEN PUSHBUTTON /2(40) btn_emp USER-COMMAND cmd_emp.
    SELECTION-SCREEN PUSHBUTTON /2(40) btn_typ USER-COMMAND cmd_typ.
    SELECTION-SCREEN PUSHBUTTON /2(40) btn_bal USER-COMMAND cmd_bal.
    SELECTION-SCREEN PUSHBUTTON /2(40) btn_req USER-COMMAND cmd_req.
    SELECTION-SCREEN PUSHBUTTON /2(40) btn_log USER-COMMAND cmd_log.
    SELECTION-SCREEN PUSHBUTTON /2(40) btn_slg USER-COMMAND cmd_slg.
  SELECTION-SCREEN END OF BLOCK b2.
SELECTION-SCREEN END OF SCREEN 102.

SELECTION-SCREEN BEGIN OF SCREEN 103 AS SUBSCREEN.
  SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
    SELECTION-SCREEN PUSHBUTTON /2(40) btn_idoc USER-COMMAND cmd_idoc.
    SELECTION-SCREEN PUSHBUTTON /2(40) btn_we11 USER-COMMAND cmd_we11.
    SELECTION-SCREEN PUSHBUTTON /2(40) btn_glob USER-COMMAND cmd_glob.
  SELECTION-SCREEN END OF BLOCK b3.
SELECTION-SCREEN END OF SCREEN 103.

SELECTION-SCREEN BEGIN OF TABBED BLOCK my_tabs FOR 15 LINES.
  SELECTION-SCREEN TAB (25) tab1 USER-COMMAND u_tab1 DEFAULT SCREEN 101.
  SELECTION-SCREEN TAB (25) tab2 USER-COMMAND u_tab2 DEFAULT SCREEN 102.
  SELECTION-SCREEN TAB (25) tab3 USER-COMMAND u_tab3 DEFAULT SCREEN 103.
SELECTION-SCREEN END OF BLOCK my_tabs.

SELECTION-SCREEN BEGIN OF SCREEN 200 TITLE TEXT-p01 AS WINDOW.
  PARAMETERS: p_mes TYPE spmon. 
SELECTION-SCREEN END OF SCREEN 200.

INITIALIZATION.
  tab1 = 'Gestão de Pedidos'.
  tab2 = 'Manutenção das Tabelas'.
  tab3 = 'Gestão de IDocs'.

  btn_emp  = 'Colaboradores'.
  btn_typ  = 'Tipos de Ausência'.
  btn_bal  = 'Balanço/Saldo'.
  btn_req  = 'Pedidos'.
  btn_log  = 'Auditoria/Logs'.
  btn_slg  = 'Opção 2 Logs - SLG1'.

  btn_idoc = 'Visualizar IDocs (WE02)'.
  btn_we11 = 'Eliminar IDocs (WE11)'.
  btn_glob = 'Criar IDoc para um Mês Específico'.

AT SELECTION-SCREEN.
  DATA(lv_comando) = sy-ucomm. 
  CLEAR sy-ucomm.              
  CASE lv_comando.             
    WHEN 'CMD_EMP'.
      CALL FUNCTION 'SE16N_INTERFACE'
        EXPORTING
          i_tab  = 'ZBR_T_EMPLOYEE'
          i_edit = 'X'.

    WHEN 'CMD_TYP'.
      CALL FUNCTION 'SE16N_INTERFACE'
        EXPORTING
          i_tab  = 'ZBR_T_ABS_TYPE'
          i_edit = 'X'.

    WHEN 'CMD_BAL'.
      CALL FUNCTION 'SE16N_INTERFACE'
        EXPORTING
          i_tab  = 'ZBR_T_BALANCE'
          i_edit = 'X'.

    WHEN 'CMD_REQ'.
      CALL FUNCTION 'SE16N_INTERFACE'
        EXPORTING
          i_tab  = 'ZBR_T_REQUEST'
          i_edit = 'X'.

    WHEN 'CMD_LOG'.
      CALL FUNCTION 'SE16N_INTERFACE'
        EXPORTING
          i_tab  = 'ZBR_T_AUDIT'
          i_edit = 'X'.

    WHEN 'CMD_SLG'.
      SUBMIT sbal_display
        WITH object = 'ZBR_ABSENCE'
        AND RETURN.
    WHEN 'CMD_IDOC'.
      CALL TRANSACTION 'WE02'.

    WHEN 'CMD_WE11'.
      CALL TRANSACTION 'WE11'.

    WHEN 'CMD_GLOB'.
      CALL SELECTION-SCREEN 200 STARTING AT 15 10.
      IF sy-subrc = 0 AND p_mes IS NOT INITIAL.

        DATA: lv_start TYPE sy-datum,
              lv_end   TYPE sy-datum.

        lv_start = |{ p_mes }01|.

        CALL FUNCTION 'RP_LAST_DAY_OF_MONTHS'
          EXPORTING
            day_in            = lv_start
          IMPORTING
            last_day_of_month = lv_end
          EXCEPTIONS
            OTHERS            = 2.

        DATA: lt_req_mes TYPE TABLE OF zbr_t_request,
              ls_req_mes TYPE zbr_t_request,
              ls_edidc_g TYPE edidc,
              lt_edidd_g TYPE TABLE OF edidd,
              ls_edidd_g TYPE edidd,
              ls_seg_g   TYPE z1br_absence,
              lt_comm_g  TYPE TABLE OF edidc,
              lv_count_g TYPE i VALUE 0,
              ls_audit_g TYPE zbr_t_audit.

        SELECT * FROM zbr_t_request
          INTO TABLE lt_req_mes
          WHERE ( status = 'A' OR status = 'R' )
            AND start_date BETWEEN lv_start AND lv_end.

        IF sy-subrc <> 0 OR lt_req_mes IS INITIAL.
          MESSAGE 'Não existem pedidos Aprovados ou Rejeitados para o mês escolhido!' TYPE 'I' DISPLAY LIKE 'E'.
          EXIT.
        ENDIF.

        ls_edidc_g-mestyp = 'ZBR_ABS_SYNC'.
        ls_edidc_g-idoctp = 'ZBR_IDOC_ABS'.
        ls_edidc_g-rcvprt = 'LS'.
        ls_edidc_g-rcvprn = 'HR_EXTERNO'.

        LOOP AT lt_req_mes INTO ls_req_mes.
          CLEAR: ls_seg_g, ls_edidd_g.
          ls_seg_g-employee_id  = ls_req_mes-employee_id.
          ls_seg_g-absence_type = ls_req_mes-absence_type.
          ls_seg_g-start_date   = ls_req_mes-start_date.
          ls_seg_g-end_date     = ls_req_mes-end_date.
          ls_seg_g-total_days   = ls_req_mes-total_days.
          CONDENSE ls_seg_g-total_days.
          ls_seg_g-status       = ls_req_mes-status.

          ls_edidd_g-segnam = 'Z1BR_ABSENCE'.
          ls_edidd_g-sData  = ls_seg_g.
          APPEND ls_edidd_g TO lt_edidd_g.

          lv_count_g = lv_count_g + 1.
        ENDLOOP.

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

            DATA(lv_mes_ano_log) = |{ p_mes+4(2) }-{ p_mes(4) }|. 
            DATA(lv_data_hoje)   = |{ sy-datum+6(2) }.{ sy-datum+4(2) }.{ sy-datum(4) }|. 

            ls_audit_g-log_id   = |{ lv_mes_ano_log }-IDOC-{ lv_idoc_num_g }|.
            ls_audit_g-log_date = sy-datum.
            ls_audit_g-log_time = sy-uzeit.
            ls_audit_g-sap_user = sy-uname.
            ls_audit_g-action   = 'IDOC MÊS'.
            ls_audit_g-details  = |{ lv_mes_ano_log }-IDOC { lv_idoc_num_g } criado em { lv_data_hoje } por { sy-uname } com { lv_count_g } pedido(s) agrupados.|.

            INSERT zbr_t_audit FROM ls_audit_g.

            PERFORM z_gravar_log_slg1 USING 'IDOCS'
                                            ls_audit_g-log_id
                                            ls_audit_g-details
                                            'S'.

            MESSAGE |IDoc do mês { lv_mes_ano_log } exportado com sucesso! ({ lv_count_g } pedidos).| TYPE 'S'.
          ENDIF.
        ELSE.
          MESSAGE 'Erro ao gerar o IDoc Global.' TYPE 'E'.
        ENDIF.
      ENDIF.
  ENDCASE.

START-OF-SELECTION.

  SUBMIT zbr_r_approval_dashboard
    WITH s_empid IN s_empid
    WITH s_type  IN s_type
    WITH s_stat  IN s_stat
    WITH s_cdate IN s_cdate
    WITH s_sdate IN s_sdate
    AND RETURN.

FORM z_gravar_log_slg1 USING p_subobject TYPE clike
                             p_ext_id    TYPE clike
                             p_mensagem  TYPE clike
                             p_tipo      TYPE c. " 'S' Sucesso, 'E' Erro, 'W' Aviso

  DATA: ls_log        TYPE bal_s_log,
        lv_log_handle TYPE balloghndl,
        lt_log_handle TYPE bal_t_logh,
        ls_msg        TYPE bal_s_msg,
        lv_msg_char   TYPE c LENGTH 200.

  ls_log-object    = 'ZBR_ABSENCE'.
  ls_log-subobject = p_subobject.
  ls_log-extnumber = p_ext_id.
  ls_log-aluser    = sy-uname.
  ls_log-aldate    = sy-datum.
  ls_log-altime    = sy-uzeit.

  CALL FUNCTION 'BAL_LOG_CREATE'
    EXPORTING
      i_s_log      = ls_log
    IMPORTING
      e_log_handle = lv_log_handle
    EXCEPTIONS
      OTHERS       = 1.

  IF sy-subrc = 0.
    APPEND lv_log_handle TO lt_log_handle.

    lv_msg_char = p_mensagem.
    ls_msg-msgty = p_tipo.
    ls_msg-msgid = '00'.
    ls_msg-msgno = '398'.
    ls_msg-msgv1 = lv_msg_char(50).
    ls_msg-msgv2 = lv_msg_char+50(50).
    ls_msg-msgv3 = lv_msg_char+100(50).
    ls_msg-msgv4 = lv_msg_char+150(50).

    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle = lv_log_handle
        i_s_msg      = ls_msg
      EXCEPTIONS
        OTHERS       = 1.

    IF sy-subrc = 0.
      " 4. Gravar definitivamente na SLG1
      CALL FUNCTION 'BAL_DB_SAVE'
        EXPORTING
          i_t_log_handle = lt_log_handle
        EXCEPTIONS
          OTHERS         = 1.
    ENDIF.
  ENDIF.
ENDFORM.
