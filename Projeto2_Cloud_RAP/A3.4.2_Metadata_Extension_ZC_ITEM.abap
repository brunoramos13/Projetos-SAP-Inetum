@Metadata.layer: #CORE
@UI: {
  headerInfo: { typeName: 'Item',
                typeNamePlural: 'Itens',
                title: { type: #STANDARD, value: 'Material' } }
}
annotate View ZC_PO_UP_ITEM with
{
  @UI.facet: [ { id: 'Item',
                 purpose: #STANDARD,
                 type: #IDENTIFICATION_REFERENCE,
                 label: 'Item Details',
                 position: 10 } ]

  @UI.hidden: true
  ItemUuid;
  
  @UI.hidden: true
  UploadUuid;
  
  @UI: { lineItem:       [ { position: 1, label: 'Line' } ],
         identification: [ { position: 1, label: 'Line' } ] }
  ExcelRow;

  @UI: { lineItem:       [ { position: 5, label: 'PO Type' } ],
         identification: [ { position: 5, label: 'PO Type' } ] }
  PurchaseOrderType;
  
  @UI: { lineItem:       [ { position: 6, label: 'Comp. Code' } ],
         identification: [ { position: 6, label: 'Comp. Code' } ] }
  CompanyCode;

  @UI: { lineItem:       [ { position: 10, label: 'Purch. Org.' } ],
         identification: [ { position: 10, label: 'Purch. Org.' } ] }
  PurchasingOrganization;

  @UI: { lineItem:       [ { position: 15, label: 'Purch. Group' } ],
         identification: [ { position: 15, label: 'Purch. Group' } ] }
  PurchasingGroup;

  @UI: { lineItem:       [ { position: 20 } ],
         identification: [ { position: 20 } ] }
  Supplier;

  @UI: { lineItem:       [ { position: 25 } ],
         identification: [ { position: 25 } ] }
  Material;

  @UI: { lineItem:       [ { position: 30 } ],
         identification: [ { position: 30 } ] }
  Plant;

  @UI: { lineItem:       [ { position: 35, label: 'Delivery Date' } ],
         identification: [ { position: 35, label: 'Delivery Date' } ] }
  DeliveryDate;
  
  @UI: { lineItem:       [ { position: 40, label: 'Quantity' } ],
         identification: [ { position: 40, label: 'Quantity' } ] }
  Quantity;
  
  @UI.hidden: true
  QuantityUnit;

  @UI: { lineItem:       [ { position: 45, label: 'Net Price' } ],
         identification: [ { position: 45, label: 'Net Price' } ] }
  NetPriceAmount;      

  @UI: { lineItem:       [ { position: 50, label: 'Status' } ],
         identification: [ { position: 50, label: 'Status' } ] }
  ItemStatus;

  @UI: { lineItem:       [ { position: 55, label: 'Log Message' } ],
         identification: [ { position: 55, label: 'Log Message' } ],
         multiLineText: true }
  ItemMessage;
  
  @UI.hidden: true
  PurchaseOrder;
  @UI.hidden: true
  DocumentCurrency;
  @UI.hidden: true
  CreatedBy;
  @UI.hidden: true
  CreatedAt;
  @UI.hidden: true
  LastChangedBy;
  @UI.hidden: true
  LastChangedAt;
  @UI.hidden: true
  LocalLastChangedAt;
}
