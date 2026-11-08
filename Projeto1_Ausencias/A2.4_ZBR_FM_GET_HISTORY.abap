FUNCTION ZBR_FM_GET_HISTORY.
CLEAR et_requests[].
  SELECT * FROM zbr_t_request
    INTO TABLE et_requests
    WHERE employee_id = iv_employee_id
    ORDER BY Created_on DESCENDING.
ENDFUNCTION.
