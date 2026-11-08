@EnduserText.label : 'Tabela de Itens - Upload PO'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.DataMaintenance : #RESTRICTED
define table zpo_up_item {

  key client            : abap.clnt not null;
  key item_uuid         : sysuuid_x16 not null;
  upload_uuid           : sysuuid_x16 not null;
  po_type               : abap.char(4);
  company_code          : abap.char(4);
  purch_org             : abap.char(4);
  purch_group           : abap.char(3);
  doc_currency          : abap.cuky;
  supplier              : abap.char(10);
  material              : abap.char(40);
  plant                 : abap.char(4);
  @Semantics.quantity.unitOfMeasure : 'zpo_up_item.quantity_unit'
  quantity              : abap.quan(13,2);
  quantity_unit         : abap.unit(3);
  delivery_date         : abap.dats;
  @Semantics.amount.currencyCode : 'zpo_up_item.doc_currency'
  net_price_amount      : abap.curr(15,2);
  Purchase_Order        : abap.char(10);
  item_status           : abap.char(10);
  item_message          : abap.char(255);
  Created_by            : abp_creation_user;
  Created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_locinst_lastchange_user;
  last_changed_at       : abp_locinst_lastchange_tstmpl;
  local_last_changed_at : abp_lastchange_tstmpl;
  excel_row             : abap.int4;

}
