Managed implementation in class zbp_r_po_up_head unique;
strict ( 2 );
with Draft;

define Behavior for ZR_PO_UP_HEAD alias Upload
persistent table zpo_up_head
Draft table zpo_up_head_d
lock master
total etag LocalLastChangedAt
Authorization master ( global )
etag master LastChangedAt
{
  Create;
  update;
  delete;
  association _Itens { Create; with Draft; }
  association _Logs { Create; with Draft; }

  determination ParseExcel on modify { field Attachment; }
  action GeneratePOs result [1] $self;
  action FetchPONumber result [1] $self;

  Side effects
  {
    field Attachment affects entity _Itens;
    action GeneratePOs affects $self, entity _Itens, entity _Logs;
    action FetchPONumber affects $self, entity _Itens, entity _Logs;
  }

  validation ValidateAttachment on save { field Attachment; Create; update; }
  field ( mandatory ) Attachment;
  field ( numbering : Managed, readonly ) UploadUuid;
  field ( readonly ) CreatedAt, CreatedBy, LastChangedAt, LastChangedBy, LocalLastChangedAt;

  Draft action Edit;
  Draft action Activate optimized;
  Draft action Discard;
  Draft action Resume;
  Draft determine action Prepare
  {
    validation ValidateAttachment;
  }

  mapping for zpo_up_head
    {
      UploadUuid         = upload_uuid;
      Attachment         = Attachment;
      MimeType           = mimetype;
      Filename           = filename;
      PurchaseOrder      = Purchase_Order;
      CreatedBy          = Created_by;
      CreatedAt          = Created_at;
      LastChangedBy      = last_changed_by;
      LastChangedAt      = last_changed_at;
      LocalLastChangedAt = local_last_changed_at;
    }
}
define Behavior for ZR_PO_UP_ITEM alias Item
persistent table zpo_up_item
Draft table zpo_up_item_d
lock dependent by _Upload
Authorization dependent by _Upload
etag master LastChangedAt
{
  update;
  delete;
  field ( readonly ) UploadUuid;
  field ( numbering : Managed, readonly ) ItemUuid;
  field ( readonly ) CreatedBy, CreatedAt, LastChangedBy, LastChangedAt, LocalLastChangedAt;
  association _Upload { with Draft; }

  mapping for zpo_up_item
    {
      ItemUuid               = item_uuid;
      UploadUuid             = upload_uuid;
      ExcelRow               = excel_row;
      PurchaseOrderType      = po_type;
      CompanyCode            = company_code;
      PurchasingOrganization = purch_org;
      PurchasingGroup        = purch_group;
      DocumentCurrency       = doc_currency;
      NetPriceAmount         = net_price_amount;
      QuantityUnit           = quantity_unit;
      Supplier               = supplier;
      Material               = material;
      Plant                  = plant;
      Quantity               = quantity;
      DeliveryDate           = delivery_date;
      PurchaseOrder          = Purchase_Order;
      ItemStatus             = item_status;
      ItemMessage            = item_message;
      CreatedBy              = Created_by;
      CreatedAt              = Created_at;
      LastChangedBy          = last_changed_by;
      LastChangedAt          = last_changed_at;
      LocalLastChangedAt     = local_last_changed_at;
    }
}
define Behavior for ZR_PO_UP_LOG alias Log
persistent table zpo_up_log
Draft table zpo_up_log_d
lock dependent by _Upload
Authorization dependent by _Upload
etag master CreatedAt
{
  update;
  delete;
  field ( readonly ) LogUuid, UploadUuid, CreatedAt;
  field ( numbering : Managed ) LogUuid;
  association _Upload { with Draft; }
  mapping for zpo_up_log
    {
      LogUuid    = log_uuid;
      UploadUuid = upload_uuid;
      MsgType    = msg_type;
      MsgText    = msg_text;
      CreatedAt  = Created_at;
    }
}
