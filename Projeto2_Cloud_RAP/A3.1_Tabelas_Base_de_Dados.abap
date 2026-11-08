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
