unit QueryMapper;

interface

uses u_IDbConnection, u_TDbConnection, Generics.Collections;

type
  TQueryMapper = class
  public
    class function Map<T: class, constructor>(Connection: IDbConnection; Query: string; Params: array of Variant): T; overload;
    class function MapList<T: class, constructor>(Connection: IDbConnection; Query: string; Params: array of Variant): TList<T>;

    // non-interfaced crutch
    class function Map<T: class, constructor>(Connection: TDbConnection; Query: string; Params: array of Variant): T; overload;
    class function MapListOfRecords<T>(Connection: TDbConnection; Query: string; Params: array of Variant): TList<T>;
  end;

implementation

uses SysUtils, DB, DataSetMapper;

{ TQueryMapper }

class function TQueryMapper.Map<T>(Connection: IDbConnection; Query: string; Params: array of Variant): T;
var
  Ds: TDataSet;
begin
  Result := nil;
  Ds := nil;
  try
    Ds := Connection.SelectSQL(Query, Params);
    if Ds.Eof then Exit(nil);

    Result := T.Create;
    TDataSetMapper.Map(Ds, Result);
  finally
    Ds.Free;
  end;
end;

class function TQueryMapper.MapList<T>(Connection: IDbConnection; Query: string; Params: array of Variant): TList<T>;
var
  Ds: TDataSet;
  Item: T;
begin
  Result := TList<T>.Create;
  Ds := nil;
  try
    Ds := Connection.SelectSQL(Query, Params);
    while not Ds.Eof do
    begin
      Item := T.Create;
      TDataSetMapper.Map(Ds, Item);
      Result.Add(Item);
      Ds.Next;
    end;
  finally
    Ds.Free;
  end;
end;

class function TQueryMapper.MapListOfRecords<T>(Connection: TDbConnection; Query: string;
  Params: array of Variant): TList<T>;
var
  Ds: TDataSet;
  Item: T;
begin
  Result := TList<T>.Create;
  Ds := nil;
  try
    Ds := Connection.SelectSQL(Query, Params);
    while not Ds.Eof do
    begin
      TDataSetMapper.Map<T>(Ds, @Item);
      Result.Add(Item);
      Ds.Next;
    end;
  finally
    Ds.Free;
  end;
end;

class function TQueryMapper.Map<T>(Connection: TDbConnection; Query: string; Params: array of Variant): T;
var
  Ds: TDataSet;
begin
  Result := nil;
  Ds := nil;
  try
    Ds := Connection.SelectSQL(Query, Params);
    if Ds.Eof then Exit(nil);

    Result := T.Create;
    TDataSetMapper.Map(Ds, Result);
  finally
    Ds.Free;
  end;
end;

end.
