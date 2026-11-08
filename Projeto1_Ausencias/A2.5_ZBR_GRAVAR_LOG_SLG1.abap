FUNCTION zbr_gravar_log_slg1.
  DATA: ls_log        TYPE bal_s_log,
        lv_log_handle TYPE balloghndl,
        lt_log_handle TYPE bal_t_logh,
        ls_msg        TYPE bal_s_msg,
        lv_msg_char   TYPE c LENGTH 200.

  ls_log-object    = 'ZBR_ABSENCE'.
  ls_log-subobject = iv_subobject.
  ls_log-extnumber = iv_ext_id.
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
    lv_msg_char = iv_mensagem.
    ls_msg-msgty = iv_tipo.
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
      CALL FUNCTION 'BAL_DB_SAVE'
        EXPORTING
          i_t_log_handle = lt_log_handle
        EXCEPTIONS
          OTHERS         = 1.
    ENDIF.
  ENDIF.
ENDFUNCTION.
