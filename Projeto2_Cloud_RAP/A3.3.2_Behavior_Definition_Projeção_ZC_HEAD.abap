projection;
strict ( 2 );
use Draft;

define Behavior for ZC_PO_UP_HEAD alias Upload
{
  use Create;
  use update;
  use delete;
  use action Edit;
  use action Activate;
  use action Discard;
  use action Resume;
  use action Prepare;
  use action GeneratePOs;
  use action FetchPONumber;
  use association _Itens { Create; with Draft; }
  use association _Logs { with Draft; }
}

define Behavior for ZC_PO_UP_ITEM alias Item
{
  use update;
  use delete;
  use association _Upload { with Draft; }
}

define Behavior for ZC_PO_UP_LOG alias Log
{
  use update;
  use delete;
  use association _Upload { with Draft; }
}
