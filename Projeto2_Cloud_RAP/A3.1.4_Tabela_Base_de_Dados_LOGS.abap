@EnduserText.label : 'Tabela de Logs - Upload PO'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.DataMaintenance : #RESTRICTED
define table zpo_up_log {
  key client   : abap.clnt not null;
  key log_uuid : sysuuid_x16 not null;
  upload_uuid  : sysuuid_x16;
  msg_type     : symsgty;
  msg_text     : abap.char(255);
  Created_at   : tzntstmpl;
}
