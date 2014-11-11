tm_orm
======
ORM для Delphi + MySQL

Удобено для использовать с существующей базой. Для каждой используемой таблицы создается класс с описанием, который в дальнейшем можно использовать для поиска и редактирования записей.

Описание таблицы
----------------

```pascal
unit u_TItem;

interface

uses
  u_TModelBase, u_Attributes, u_TItemChild;

type
  TItem = class(TModelBase)
  public
    itemid     : Integer;
    item_name  : string;
    [ReadOnly]
    created_at : Double;
    item_child : TWarehouse;
    [UTF8]
    [Select('get_user_name(warehouse_bobbin.created_by)')]
    user_name: string;

    class function GetPkName: string; override;
    class function GetTableName: string; override;
  end;

implementation

{ TItem }

class function TWarehouseBobbin.GetPkName: string;
begin
  Result := 'warehouse_bobbinid';
end;

class function TWarehouseBobbin.GetTableName: string;
begin
  Result := 'warehouse_bobbin';
end;

end.
```

Пример использования
--------------------

```pascal
var
  Params: TParameters;
  Items: TList<TItem>;
  Item: TItem;
begin
  Params := TParameters.Create;
  Params.AddParameter('orderby', 'item_name');  // сортировка по имени
  try
    Items := TItem.Find<TItem>(Params);
    for Item in Items do begin
      ShowMessage(Format('%d - %s', [Items.itemid, Item.item_name]));
    end;
  finally
    Params.Free;
    Items.Free;
  end;
end;
```

Пример со связанной таблицей
----------------------------

```pascal
var
  Params: TParameters;
  Eager: TStringList;
  Items: TList<TItem>;
  Item: TItem;
begin
  Params := TParameters.Create;
  Params.AddParameter('orderby', 'item_name');  // сортировка по имени
  Eager := TStringList.Create;
  Eager.Add('item_child');
  try
    Items := TItem.Find<TItem>(Params, Eager);
    for Item in Items do begin
      ShowMessage(Format('%d - %s - %s', [Items.itemid, Item.item_name, Items.item_child.name]));
    end;
  finally
    Params.Free;
    Eager.Free;
    Items.Free;
  end;
end;
```
