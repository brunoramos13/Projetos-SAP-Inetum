@Metadata.layer: #CORE
@UI: {
  headerInfo: { 
    typeName: 'Execution Log', 
    typeNamePlural: 'Execution Logs', 
    title: { type: #STANDARD, value: 'MsgType' } 
  }
}
annotate View ZC_PO_UP_LOG with
{
  @UI.hidden: true
  LogUuid;

  @UI.hidden: true
  UploadUuid;

  @UI.facet: [ { 
    id:       'LogDetails',
    purpose:  #STANDARD,
    type:     #IDENTIFICATION_REFERENCE,
    label:    'Log Details',
    position: 10 
  } ]

  @UI: {
    lineItem:       [ { position: 10, label: 'Type' } ],
    identification: [ { position: 10, label: 'Type' } ]
  }
  MsgType;

  @UI: {
    lineItem:       [ { position: 20, label: 'Message' } ],
    identification: [ { position: 20, label: 'Message' } ],
    multiLineText: true
  }
  MsgText;

  @UI: {
    lineItem:       [ { position: 30, label: 'Timestamp' } ],
    identification: [ { position: 30, label: 'Timestamp' } ]
  }
  CreatedAt;  
}
