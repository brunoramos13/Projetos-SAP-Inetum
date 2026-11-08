@Metadata.layer: #CORE
@UI: {
  headerInfo: { typeName: 'Upload',
                typeNamePlural: 'Uploads of Excel Files',
                title: { type: #STANDARD, value: 'Filename' } }
}
annotate View ZC_PO_UP_HEAD with
{
  @UI.facet: [
      { id:            'Upload',
        purpose:       #STANDARD,
        type:          #IDENTIFICATION_REFERENCE,
        label:         'File Details',
        position:      10 },
      { id:            'Itens',
        purpose:       #STANDARD,
        type:          #LINEITEM_REFERENCE,
        label:         'Excel Lines',
        position:      20,
        targetElement: '_Itens' },
      { id:            'Logs',
        purpose:       #STANDARD,
        type:          #LINEITEM_REFERENCE,
        label:         'Execution Logs',
        position:      30,
        targetElement: '_Logs' }
    ]

  @UI.hidden: true
  UploadUuid;

  @UI.lineItem: [
      { position: 10, label: 'Excel File' },
      { position: 20, type: #FOR_ACTION, DataAction: 'GeneratePOs',    label: 'Generate Purchase Orders' },
      { position: 30, type: #FOR_ACTION, DataAction: 'FetchPONumber', label: 'Fetch PO Number' }
    ]
  @UI.identification: [
      { position: 10, label: 'Excel File' },
      { position: 20, type: #FOR_ACTION, DataAction: 'GeneratePOs',    label: 'Generate Purchase Orders' },
      { position: 30, type: #FOR_ACTION, DataAction: 'FetchPONumber', label: 'Fetch PO Number' }
    ]
  Attachment;

  @UI.hidden: true
  MimeType;

  @UI.hidden: true
  Filename;

  @UI.lineItem: [ { position: 30, label: 'Purchase Order' } ]
  @UI.identification: [ { position: 30, label: 'Purchase Order' } ]
  PurchaseOrder;

  @UI.lineItem: [ { position: 40, label: 'Created By' } ]
  @UI.identification: [ { position: 40, label: 'Created By' } ]
  CreatedBy;

  @UI.lineItem: [ { position: 50, label: 'Created On' } ]
  @UI.identification: [ { position: 50, label: 'Created On' } ]
  CreatedAt;
}
