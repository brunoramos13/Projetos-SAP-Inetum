METHOD ValidateAttachment.
    READ ENTITIES OF zr_po_up_head IN LOCAL MODE
      ENTITY Upload FIELDS ( Attachment ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_upload).
    LOOP AT lt_upload INTO DATA(ls_upload).
      IF ls_upload-Attachment IS INITIAL.
        APPEND VALUE #( %tky = ls_upload-%tky ) TO failed-upload.
        APPEND VALUE #( %tky             = ls_upload-%tky
                        %msg             = new_message( id       = '00'
                                                        Number   = 001
                                                        severity = if_abap_behv_message=>severity-error
                                                        v1       = 'Excel file Attachment cannot be empty' )
                        %element-Attachment = if_abap_behv=>mk-on ) TO reported-upload.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
