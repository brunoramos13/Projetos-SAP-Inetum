CLASS zbp_r_po_up_head DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zr_po_up_head.
ENDCLASS.
CLASS zbp_r_po_up_head IMPLEMENTATION.
ENDCLASS.

CLASS lhc_Upload DEFINITION INHERITING FROM cl_abap_Behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_Authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_Authorizations FOR Upload RESULT result.
    METHODS ParseExcel FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Upload~ParseExcel.
    METHODS ValidateAttachment FOR VALIDATE ON SAVE
      IMPORTING keys FOR Upload~ValidateAttachment.
    METHODS GeneratePOs FOR MODIFY
      IMPORTING keys FOR ACTION Upload~GeneratePOs RESULT result.
    METHODS FetchPONumber FOR MODIFY
      IMPORTING keys FOR ACTION Upload~FetchPONumber RESULT result.
ENDCLASS.
