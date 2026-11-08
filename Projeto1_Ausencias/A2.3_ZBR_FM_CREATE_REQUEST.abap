FUNCTION zbr_fm_Create_request.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IS_REQUEST) TYPE  ZBR_S_WS_REQ_IN
*"  EXPORTING
*"     VALUE(ES_RETURN) TYPE  ZBR_S_WS_REQ_OUT
*"----------------------------------------------------------------------
  DATA: ls_request   TYPE zbr_t_request,
        ls_balance   TYPE zbr_t_balance,
        ls_audit     TYPE zbr_t_audit,
        lv_year      TYPE char4,
        lv_max_id    TYPE zbr_de_req_id,
        lv_limite    TYPE dats, 
        lv_weekday   TYPE i,
        lv_count     TYPE i,
        lv_nome_func TYPE zbr_de_emp_name.
  lv_year = is_request-start_date(4).

  IF is_request-start_date <= sy-datum.
    es_return-type    = 'E'.
    es_return-message = 'A data de início tem de ser superior à data atual.'. 
    RETURN.
  ENDIF.

  IF is_request-absence_type = 'VAC'.
    lv_limite = |{ lv_year }0331|. 
    IF sy-datum > lv_limite.
      es_return-type    = 'E'.
      es_return-message = |Os pedidos de férias para { lv_year } têm de ser feitos até 31 de Março.|.
      RETURN.
    ENDIF.
  ENDIF.

  DATA: lv_calc_end TYPE dats.
  lv_calc_end = is_request-start_date.
  lv_count = 1. 

  WHILE lv_count < is_request-total_days.

    lv_calc_end = lv_calc_end + 1. 

    DATA(lv_diff) = lv_calc_end - '20260720'.
    DATA(lv_rem)  = lv_diff MOD 7.

    IF lv_rem BETWEEN 0 AND 4.
      lv_count = lv_count + 1.
    ENDIF.

  ENDWHILE.

  DATA: ls_Overlap TYPE zbr_t_request.

  SELECT SINGLE *
      FROM zbr_t_request
      INTO ls_Overlap
     WHERE employee_id = is_request-employee_id
       AND status      = 'A'   
       AND start_date <= lv_calc_end             
       AND end_date   >= is_request-start_date.

  IF sy-subrc = 0.
    es_return-type    = 'E'.

    DATA: lv_data_ini TYPE string,
          lv_data_fim TYPE string.
    lv_data_ini = |{ ls_Overlap-start_date(4) }-{ ls_Overlap-start_date+4(2) }-{ ls_Overlap-start_date+6(2) }|.
    lv_data_fim = |{ ls_Overlap-end_date(4) }-{ ls_Overlap-end_date+4(2) }-{ ls_Overlap-end_date+6(2) }|.

    es_return-message = |Aprovação recusada: Já existe um pedido APROVADO ({ ls_Overlap-request_id }) de { lv_data_ini } a { lv_data_fim }|.
    RETURN.
  ENDIF.

  SELECT SINGLE * FROM zbr_t_balance INTO ls_balance
    WHERE employee_id  = is_request-employee_id
      AND ref_year     = lv_year
      AND absence_type = is_request-absence_type.

  IF sy-subrc <> 0.
    es_return-type    = 'E'.
    es_return-message = |Sem saldo configurado para { is_request-absence_type } no ano { lv_year }.|.
    RETURN.
  ENDIF.

  IF ( ls_balance-entitled_days - ls_balance-used_days ) < is_request-total_days.
    es_return-type    = 'E'.
    es_return-message = 'Dias disponiveis insuficientes para fazer o pedido pretendido.'.
    RETURN.
  ENDIF.

  SELECT MAX( request_id ) FROM zbr_t_request INTO lv_max_id.
  IF lv_max_id IS INITIAL.
    lv_max_id = 100000. 
  ENDIF.
  ls_request-request_id = lv_max_id + 1.
  ls_request-employee_id  = is_request-employee_id.
  ls_request-absence_type = is_request-absence_type.
  ls_request-start_date   = is_request-start_date.
  ls_request-end_date     = lv_calc_end. 
  ls_request-total_days   = is_request-total_days.
  ls_request-reason       = is_request-reason.
  ls_request-status       = 'P'. 
  ls_request-Created_by   = sy-uname.
  ls_request-Created_on   = sy-datum.
  ls_request-Created_at   = sy-uzeit.
  INSERT zbr_t_request FROM ls_request.
  IF sy-subrc = 0.
    SELECT SINGLE name
      FROM zbr_t_employee
      INTO lv_nome_func
     WHERE employee_id = is_request-employee_id.

    es_return-type       = 'S'.
    es_return-message    = |O pedido { ls_request-request_id } do(a) { lv_nome_func } ({ ls_request-employee_id }) foi criado com sucesso!|.
    es_return-request_id = ls_request-request_id.

    ls_audit-log_id   = |{ ls_request-request_id }-{ sy-uzeit }|.
    ls_audit-log_date = sy-datum.
    ls_audit-log_time = sy-uzeit.
    ls_audit-sap_user = sy-uname.
    ls_audit-action   = 'PEDIDO CRIADO(WS)'.
    ls_audit-details  = es_return-message.
    INSERT zbr_t_audit FROM ls_audit.

    CALL FUNCTION 'ZBR_GRAVAR_LOG_SLG1'
      EXPORTING
        iv_subobject = 'PEDIDOS'
        iv_ext_id    = ls_audit-log_id
        iv_mensagem  = es_return-message
        iv_tipo      = 'S'.

  ELSE.
    es_return-type    = 'E'.
    es_return-message = 'Erro interno ao gravar o pedido na base de dados.'.
  ENDIF.
ENDFUNCTION.
