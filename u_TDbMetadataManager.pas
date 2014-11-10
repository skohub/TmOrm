unit u_TDbMetadataManager;

interface

uses
   Generics.Collections, Data.SqlExpr;

type
  TDbField = record
    name, _type: string;
  end;
  TDbTable = array of TDbField;

  TDbMetadataManager = class(TObject)
  private
    FConnection: TSqlConnection;
    FTables: TDictionary<string, TDBTable>;
    procedure LoadTable(TableName: string);
    function GetTable(Name: string): TDbTable;
  public
    constructor Create(Connection: TSqlConnection);
    destructor Destroy; override;
    property Table[Name: string]: TDbTable read GetTable; Default;
  end;

var
  DbMetadataManager: TDbMetadataManager;

implementation

uses
  SysUtils;

{ TDbMetadataManager }

constructor TDbMetadataManager.Create(Connection: TSqlConnection);
begin
  inherited Create;
  FTables := TDictionary<string, TDBTable>.Create;
  FConnection := Connection;
end;

destructor TDbMetadataManager.Destroy;
begin
  FTables.Free;
  inherited;
end;

function TDbMetadataManager.GetTable(Name: string): TDbTable;
begin
  if not FTables.ContainsKey(Name) then
    LoadTable(Name);
  Result := FTables[Name];
end;

procedure TDbMetadataManager.LoadTable(TableName: string);
var
  Table: TDbTable;
  Ds: TSqlDataSet;
  i: Integer;
begin
  Ds := TSqlDataSet.Create(nil);
  try
    Ds.SqlConnection := FConnection;
    Ds.CommandText := 'DESCRIBE ' + TableName;
    Ds.Open;
    i := 0;
    while not Ds.Eof do begin
      SetLength(Table, i+1);
      Table[i].name := Ds.fieldbyname('Field').AsString;
      Table[i]._type := TEncoding.UTF8.GetString(Ds.fieldbyname('Type').AsBytes);
      FTables.Add(TableName, Table);
      Ds.Next;
      Inc(i);
    end;
  finally
    Ds.Free;
  end;
end;

end.
