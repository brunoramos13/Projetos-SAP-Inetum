@EnduserText.label : 'Tabela de Cabeçalho - Upload de Purchase Orders'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.DataMaintenance : #RESTRICTED
define table zpo_up_head {

  key client            : abap.clnt not null;
  key upload_uuid       : sysuuid_x16 not null;
  Attachment            : /dmo/Attachment;
  mimetype              : /dmo/mime_type;
  filename              : /dmo/filename;
  Created_by            : abp_creation_user;
  Created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_locinst_lastchange_user;
  last_changed_at       : abp_locinst_lastchange_tstmpl;
  local_last_changed_at : abp_lastchange_tstmpl;
  Purchase_Order        : abap.char(10);

}

@EnduserText.label : 'Draft table for entity ZR_PO_UP_HEAD'
@AbapCatalog.enhancement.category : #EXTENSIBLE_ANY
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.DataMaintenance : #RESTRICTED
define table zpo_up_head_d {

  key mandt          : mandt not null;
  key uploaduuid     : sysuuid_x16 not null;
  Attachment         : /dmo/Attachment;
  mimetype           : /dmo/mime_type;
  filename           : /dmo/filename;
  Createdby          : abp_creation_user;
  Createdat          : abp_creation_tstmpl;
  lastchangedby      : abp_locinst_lastchange_user;
  lastchangedat      : abp_locinst_lastchange_tstmpl;
  locallastchangedat : abp_lastchange_tstmpl;
  PurchaseOrder      : abap.char(10);
  "%admin"           : include sych_bdl_Draft_admin_inc;

}
