unit u_TModelBase;

interface

uses
  u_TParameters, Db, Variants, Winapi.Windows, SysUtils, Generics.Collections,
  u_IModelBase, RTTI, System.TypInfo, Classes, u_TDbConnection, u_TPagedList,
  u_TPaginationParameters, FireDAC.Comp.Client, FireDAC.Stan.Param;

type
  TModelClass = class of TModelBase;
  TModelBase = class(TInterfacedObject, IModelBase)
  private
    class var
      FDb: TDbConnection;
    var
      FFields: TDictionary<string, string>;
    function GetPkValue: Integer;
    procedure SetPkValue(Value: Integer);
    procedure LoadFields(Ds: TDataSet);
    procedure AddQueryParam(Query: TFDQuery; Param: TParameter; Name: string);

    class function GetDb: TDbConnection; static;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    class property Db: TDbConnection read GetDb write FDb;
    class function GetTableName: string; virtual;
    class function GetPkName: string; virtual;
    // relations
    class function GetSelectFields: string;
    class function GetJoinPart(SecondTableName, SecondPkName: string): string;

    class procedure GetRelationVariables(Relations: TList<TObject>; var Select, Join: string);
    class function GetRelations(TableNames: TStringList): TList<TObject>;
    procedure SetRelations(Relations: TList<TObject>);
    //
    class function Find<T:IModelBase, constructor>(Params: TParameters = nil; EagerLoad: TStringList = nil): TList<T>; overload;
    class function Find(Params: TParameters = nil): TList<TModelBase>; overload;
    class function FindPaged(PaginationParameters: TPaginationParameters;
      Params: TParameters = nil): TPagedList<TModelBase>;
    class function ParamsSpecification(Params: TParameters = nil): TFunc<TList<TObject>>;
    class function PagedSpecification(PaginationParameters: TPaginationParameters;
      Params: TParameters = nil): TFunc<TList<TModelBase>>;
    class function FindByPk<T:IModelBase, constructor>(Id: Integer): T;
    procedure LoadFromDs(Ds: TDataSet); virtual;
    procedure Clear; virtual;
    procedure Release;
    procedure Assign(Source: TModelBase); virtual;
    procedure Delete; virtual;
    procedure Validate; virtual;
    procedure Save(ForceCreate: Boolean); overload; virtual;
    procedure Save; overload; virtual;
    procedure Reload;
    function IsFieldReadOnly(Field: TRTTIField): Boolean;
    function FieldValue(FieldName: string): string;
    property PkValue: Integer read GetPkValue write SetPkValue;
    function ToParameters(): TParameters;
    function InsertRecord(Params: TParameters; TableName: string): integer; virtual;
    procedure UpdateRecord(Params: TParameters; TableName, KeyName: string); virtual;

    class function GetAttribute<T: TCustomAttribute>(Field: TRTTIField): TCustomAttribute;
    class function GetCompareSign(CompareSign: string): string;
    class function PrepareSql(Params: TParameters; TableName, Select, Join, Where, GroupBy,
      OrderBy, Limit: string): string;
    class function PrepareParams(Params: TParameters): TParams;
    class function FindRecords(Params: TParameters; TableName: string; RelationsSelect, RelationsJoin: string): TDataSet; virtual;
    class function CountRecords(Params: TParameters): Integer;
    class function LastInsertID: integer;
    class procedure DeleteRecord(id: integer; id_column: string; table_name: string); virtual;
    class procedure Log(level: integer; text: string);
  end;

implementation

uses u_Attributes, u_TRelation, StrUtils, Math;

procedure TModelBase.UpdateRecord(Params: TParameters; TableName, KeyName: string);
var
  Sql, Sep: string;
  i, l: integer;
  Ds: TFDQuery;
  Key: TParameter;
  t: Integer;
begin
  Ds := TFDQuery.Create(nil);
  Ds.Connection := FDb.Connection;
  Ds.ResourceOptions.ParamCreate := False;
  Sql := 'UPDATE `' + TableName + '` SET ';
  Key := Params.GetParameter(KeyName);
  if Key.name = '' then
    raise Exception.Create('Не получен обязательный параметр ' + KeyName);

  Sep := '';
  l := Params.Length;
  if l = 0 then
    raise Exception.Create('Не передано ни одного параметра для редактирования таблицы ' + TableName + '.');

  for i := 0 to l - 1 do begin
    Sql := Sql + Sep + '`' + Params[i].name + '`=?';
    Sep := ',';
  end;
  Sql := Sql + ' WHERE `' + KeyName + '`=?';
  Ds.Sql.Text := Sql;

  for i := 0 to l - 1 do begin
    AddQueryParam(Ds, Params[i], Format('p%d', [i]));
  end;

  Ds.Params.Add.AsInteger := Key.Value;
  Ds.ExecSQL;
end;

function TModelBase.InsertRecord(Params: TParameters; TableName: string): integer;
var
  Sql, Sep: string;
  i, l: integer;
  Ds: TFDQuery;
  t: Integer;
begin
  Result := -1;
  Ds := TFDQuery.Create(nil);
  Ds.ResourceOptions.ParamCreate := False;
  Ds.Connection := FDb.Connection;
  Sql := 'INSERT INTO `' + TableName + '` SET ';
  Sep := '';
  l := Params.Length;
  if l = 0 then
    raise Exception.Create('Не передано ни одного параметра для редактирования таблицы ' + TableName + '.');

  for i := 0 to l - 1 do begin
    Sql := Sql + Sep + '`' + Params[i].name + '`=?';
    Sep := ',';
  end;
  Ds.Sql.Text := Sql;

  for i := 0 to l - 1 do begin
    AddQueryParam(Ds, Params[i], Format('p%d', [i]));
  end;

  Ds.ExecSQL;
  Result := LastInsertID;
end;

function TModelBase.IsFieldReadOnly(Field: TRTTIField): Boolean;
var
  a: TCustomAttribute;
begin
  Result := False;
  for a in Field.GetAttributes do
    if (a is ReadOnlyAttribute) or (a is SelectAttribute) then
      Result := True;
  if Field.Visibility = mvPrivate then
    Result := True;
end;

procedure TModelBase.AddQueryParam(Query: TFDQuery; Param: TParameter;
  Name: string);
var
  ParameterType: Integer;
  QueryParam: TFDParam;
begin
  QueryParam := Query.Params.Add;
  QueryParam.ParamType := ptInput;

  if Param.Value = Null then begin // если NULL
    QueryParam.Bound := True;
    QueryParam.Clear;
    Exit;
  end;

  ParameterType := VarType(Param.Value) and VarTypeMask;
  case ParameterType of
    varDouble:
    begin
      QueryParam.DataType := ftFloat;
      QueryParam.Value := Param.Value;
    end;
    varInteger,
    varInt64:
    begin
      QueryParam.DataType := ftInteger;
      QueryParam.Value := Param.Value;
    end;
    varBoolean:
    begin
      QueryParam.DataType := ftInteger;
      QueryParam.Value := IfThen(Param.Value = True, 1, 0);
    end
    else
    begin
      QueryParam.DataType := ftWideString;
      QueryParam.Value := Param.Value;
    end;
  end;
end;

procedure TModelBase.Assign(Source: TModelBase);
var
  Context: TRTTIContext;
  t, st: TRTTIType;
  f, sf: TRTTIField;
  v, sv: TValue;
begin
  Assert(Self.ClassName = Source.ClassName, 'Classes should be identical');
  Context := TRTTIContext.Create;
  try
    t := Context.GetType(Self.ClassType);
    st := Context.GetType(Source.ClassType);
    for f in t.GetFields do begin
      if f.Visibility <> mvPublic then Continue;
      sf := st.GetField(f.Name);
      v  := f.GetValue(Self);
      sv := sf.GetValue(Source);
      case f.FieldType.TypeKind of
        tkInteger, tkFloat, tkUString, tkEnumeration: begin
          v := sv;
          f.SetValue(Self, v);
        end;
//        tkClass: begin
//          if v.AsObject <> nil then
//            v.AsObject.Free;
//          v := nil;
//          f.SetValue(Self, v);
//        end;
      end;
    end;
  finally
    Context.Free;
  end;
end;

procedure TModelBase.Clear;
var
  Context: TRTTIContext;
  t: TRTTIType;
  f: TRTTIField;
  v: TValue;
  a: TCustomAttribute;
begin
  Context := TRTTIContext.Create;
  t := Context.GetType(Self.ClassType);
  for f in t.GetFields do begin
    if f.Visibility <> mvPublic then Continue;
    v := f.GetValue(Self);
    a := GetAttribute<DefaultValueAttribute>(f);
    if Assigned(a) then begin // если есть значение по-умолчанию
      v := TValue.FromVariant(DefaultValueAttribute(a).Value);
      f.SetValue(Self, v);
    end else
      case f.FieldType.TypeKind of
        tkInteger: begin
          v := -1;
          f.SetValue(Self, v);
        end;
        tkFloat: begin
          v := 0;
          f.SetValue(Self, v);
        end;
        tkUString: begin
          v := '';
          f.SetValue(Self, v);
        end;
        tkClass: begin
          if f.Visibility <> mvPrivate then begin
            if v.AsObject <> nil then
              v.AsObject.Free;
          end;
        end;
      end;
  end;
end;

class function TModelBase.CountRecords(Params: TParameters): Integer;
var
  Sql: string;
  SqlParams: array of Variant;
  TableName: string;
begin
  TableName := GetTableName();
  Params.Remove('select');
  Sql := PrepareSql(
    Params,
    TableName,
    'count(*)',
    Params.GetJoinSql,
    Params.GetWhereSql(TableName),
    Params.GetGroupBySql,
    Params.GetOrderBySql,
    Params.GetLimitSql
  );

  SqlParams := Params.ToVarArray();
  Result := MainDb.ExecSQLScalar(Sql, SqlParams);
end;

constructor TModelBase.Create;
begin
  inherited;
  FFields := TDictionary<string, string>.Create;
  Clear;
end;

procedure TModelBase.Delete;
begin
  if PkValue > -1 then
    DeleteRecord(PkValue, GetPkName, GetTableName);
end;

class procedure TModelBase.DeleteRecord(id: integer; id_column: string; table_name: string);
begin
  FDb.ExecSQL(Format('DELETE FROM %s WHERE %s=?', [table_name, id_column]), [id]);
end;

destructor TModelBase.Destroy;
begin
  FreeAndNil(FFields);
  Clear;
  inherited;
end;

class function  TModelBase.FindRecords(Params: TParameters; TableName: string; RelationsSelect, RelationsJoin: string): TDataSet;
var
  Sql: string;
  Select, Join, Group, OrderBy, Limit: string;
  Ds: TFDQuery;
  SqlParams: TParams;
  p: TParameter;
begin
  Ds := TFDQuery.Create(nil);
  Ds.Connection := Db.Connection;

  Group := Params.GetGroupBySql;
  Select := Params.GetSelectSql;
  if Group = '' then
  begin
    if Select <> '' then
      Select := Select + ',';
    Select := Select + GetSelectFields
  end
  else
    Assert(Select<>'', 'если исползуется group by, то надо указывать каждое поле в параметре select');
  if (Group = '') and (RelationsSelect <> '') then
    Select := Select + ',' + RelationsSelect;

  Join := Format('%s %s', [Params.GetJoinSql, RelationsJoin]);
  OrderBy := Params.GetOrderBySql;
  Limit := Params.GetLimitSql;

  Ds.SQL.Text := PrepareSql(
    Params,
    TableName,
    Select,
    IfThen(Join.IsEmpty, RelationsJoin, Join),
    Params.GetWhereSql(TableName),
    Group,
    OrderBy,
    Limit
  );

  SqlParams := PrepareParams(Params);
  try
    Ds.Params.Assign(SqlParams);
  finally
    SqlParams.Free;
  end;
  Ds.Open;
  Result := Ds;
end;

function TModelBase.FieldValue(FieldName: string): string;
begin
  if not FFields.TryGetValue(FieldName, Result) then
    Result := '';
end;

class function TModelBase.Find(Params: TParameters): TList<TModelBase>;
var
  Ds: TDataSet;
  Value: TModelBase;
begin
  Result := TList<TModelBase>.Create;
  if Params = nil then
    Params := TParameters.Create;
  Ds := FindRecords(Params, GetTableName, '', '');
  try
    while not Ds.Eof do begin
      Value := Self.Create;
      Value.LoadFromDs(Ds);
      Result.Add(Value);
      Ds.Next;
    end;
  finally
    Ds.Free;
  end;
end;

class function TModelBase.Find<T>(Params: TParameters; EagerLoad: TStringList): TList<T>;
var
  Ds: TDataSet;
  Value: T;
  Relations: TList<TObject>;
  r: TObject;
  s1, j1: string;
  RelationInstance: TModelBase;
  RelationInstances: TList<TObject>;
begin
  Result := TList<T>.Create;
  try
    Relations := GetRelations(EagerLoad);
    GetRelationVariables(Relations, s1, j1);
  finally
    for r in Relations do
      r.Free;
    FreeAndNil(Relations);
  end;
  if Params = nil then
    Params := TParameters.Create;
  Ds := FindRecords(Params, GetTableName, s1, j1);
  try
    while not Ds.Eof do begin
      Relations := GetRelations(EagerLoad);
      try
        Value := T.Create;
        Value.LoadFromDs(Ds);
        for r in Relations do
          TRelation(r).Model.LoadFromDs(Ds);
        Value.SetRelations(Relations);
      finally
        FreeAndNil(Relations);
      end;
      Result.Add(Value);
      Ds.Next;
    end;
  finally
    Ds.Free;
  end;
end;

class function TModelBase.FindByPk<T>(Id: Integer): T;
 var
  Params: TParameters;
  Entities: TList<T>;
begin
  Result := nil;
  Params := TParameters.Create;
  Params.AddParameter(GetPkName, Id);
  Entities := Find<T>(Params, nil);
  try
    Assert(Entities.Count = 1, 'Record not found');
    Result := Entities.Items[0];
  finally
    Entities.Free;
  end;
end;

class function TModelBase.PagedSpecification(PaginationParameters: TPaginationParameters;
  Params: TParameters): TFunc<TList<TModelBase>>;
begin
  Result :=
    function: TList<TModelBase>
    begin
      Result := Self.FindPaged(PaginationParameters, Params);
    end;
end;

class function TModelBase.ParamsSpecification(Params: TParameters): TFunc<TList<TObject>>;
begin
  Result :=
    function: TList<TObject>
    begin
      Result := TList<TObject>(Self.Find(Params));
    end;
end;

class function TModelBase.FindPaged(PaginationParameters: TPaginationParameters;
    Params: TParameters = nil): TPagedList<TModelBase>;
var
  ParamsClone: TParameters;
  TotalCount: Integer;
  List: TList<TModelBase>;
begin
  ParamsClone := TParameters.Create;
  try
    ParamsClone.AddRange(Params);
    TotalCount := CountRecords(ParamsClone);
  finally
    ParamsClone.Free;
  end;

  if TotalCount = 0 then
  begin
    List := nil
  end else begin
    Params.Offset := PaginationParameters.PageSize * (PaginationParameters.Page - 1);
    Params.Limit := PaginationParameters.PageSize;
    List := Find(Params);
  end;

  Result := TPagedList<TModelBase>.CreatePagedList(List, TotalCount,
    PaginationParameters.Page, PaginationParameters.PageSize);
end;

class procedure TModelBase.GetRelationVariables(Relations: TList<TObject>; var Select, Join: string);
var
  Relation: TObject;
  Sep: string;
begin
  Select := '';
  Join   := '';
  Sep    := '';
  for Relation in Relations do begin
    Select := Select + Sep + TModelBase(TRelation(Relation).Model).GetSelectFields;
    Join   := Join + TModelBase(TRelation(Relation).Model).GetJoinPart(GetTableName, TRelation(Relation).FkName);
    Sep    := ',';
  end;
end;

class function  TModelBase.GetCompareSign(CompareSign: string): string;
begin
  if (CompareSign = '=')
  or (CompareSign = '<>')
  or (CompareSign = '<')
  or (CompareSign = '>')
  or (CompareSign = '<=')
  or (CompareSign = '=>')
  or (CompareSign = 'LIKE')
  or (CompareSign = 'RLIKE')
  then
    Result := CompareSign
  else
    raise Exception.Create('Unknown compare sign');
end;

class function TModelBase.GetDb: TDbConnection;
begin
  if not Assigned(FDb) then
    FDb := u_TDbConnection.MainDb;
  Result := FDb;
end;

class function TModelBase.GetJoinPart(SecondTableName, SecondPkName: string): string;
begin
  Result := Format(
    'LEFT JOIN `%s` ON `%s`.`%s`=`%s`.`%s` ',
    [GetTableName, GetTableName, GetPkName, SecondTableName, SecondPkName]
  );
end;

class function TModelBase.GetPkName: string;
begin
  Result := GetTableName + 'id';
end;

function TModelBase.GetPkValue: Integer;
var
  Context: TRTTIContext;
  RTTIType: TRTTIType;
  RTTIField: TRTTIField;
  RTTIValue: TValue;
begin
  Context := TRTTIContext.Create;
  try
    RTTIType := Context.GetType(Self.ClassType);
    RTTIField := RTTIType.GetField(GetPkName);
    Assert(Assigned(RTTIField), 'Pk value not found');
    RTTIValue := RTTIField.GetValue(Self);
    Result := RTTIValue.AsInteger;
  finally
    Context.Free;
  end;
end;

class function TModelBase.GetRelations(TableNames: TStringList): TList<TObject>;
var
  c: TRTTIContext;
  t, t1: TRTTIType;
  f: TRTTIField;
  a: TCustomAttribute;
  FkName: string;
  r: TRelation;
  v: TValue;
begin
  c := TRTTIContext.Create;
  try
    Result := TList<TObject>.Create;
    t := c.GetType(Self);
    for f in t.GetFields do begin
      if f.Visibility <> mvPublic then Continue;
      FkName := '';
      a := GetAttribute<FkNameAttribute>(f);
      if Assigned(a) then
        FkName := FkNameAttribute(a).FkName;
      if f.FieldType.TypeKind = tkClass then
        if Assigned(TableNames) and (TableNames.IndexOf(f.Name) > -1) then begin
          r := TRelation.Create;
          t1 := c.GetType(f.FieldType.AsInstance.MetaclassType);
          v := t1.GetMethod('Create').Invoke(t1.AsInstance.MetaclassType,[]);
          r.Model := TModelBase(v.AsObject);
          if FkName = '' then
            FkName := TModelBase(r.Model).GetPkName;
          r.FkName := FkName;
          Result.Add(r);
        end;
    end;
  finally
    c.Free;
  end;
end;

class function TModelBase.GetSelectFields: string;
var
  Context: TRTTIContext;
  t: TRTTIType;
  f: TRTTIField;
  a: TCustomAttribute;
  FieldSql: string;
  FieldName: string;
  Sep: string;
begin
  Sep := '';
  Result := '';
  Context := TRTTIContext.Create;
  t := Context.GetType(Self);
  for f in t.GetFields do begin
    FieldSql := '';
    FieldName := '';
    // предусловия
    if f.Visibility <> mvPublic then Continue;
    if f.FieldType.TypeKind = tkClass then Continue;
    // поиск атрибута DbField
    a := GetAttribute<DbFieldAttribute>(f);
    if a <> nil then FieldName := DbFieldAttribute(a).Name;
    // поиск атрибута Select
    a := GetAttribute<SelectAttribute>(f);
    if a <> nil then begin
      if SelectAttribute(a).Sql = '' then Continue;
      FieldSql := SelectAttribute(a).Sql
    end;

    if FieldSql.IsEmpty then FieldSql := FieldName;
    if FieldName.IsEmpty then FieldName := f.Name;
    if FieldSql.IsEmpty then
      FieldSql := Format('`%s`.`%s`', [GetTableName, f.Name]);
    Result := Format('%s%s %s AS %s_%s',
      [Result, Sep, FieldSql, GetTableName, FieldName]);
    Sep := ',';
  end;
end;

class function TModelBase.GetTableName: string;
var
  l: Integer;
  r: string;
begin
  r := Lowercase(Self.ClassName);
  l := Length(r);
  if l > 1 then begin
    if r[1] = 't' then
      r := Copy(r, 2, l - 1);
  end;
  Result := r;
end;

class function TModelBase.GetAttribute<T>(Field: TRTTIField): TCustomAttribute;
var
  a: TCustomAttribute;
begin
  Result := nil;
  for a in Field.GetAttributes do
    if a is T then
      Result := a;
end;

class function  TModelBase.LastInsertID: integer;
var
  Ds: TDataSet;
begin
  Ds := Db.SelectSQL('SELECT LAST_INSERT_ID()');
  Result := Ds.Fields[0].AsInteger;
  Ds.Free;
end;

procedure TModelBase.LoadFields(Ds: TDataSet);
var
  I: Integer;
begin
  for I := 0 to Ds.FieldCount - 1 do
    FFields.AddOrSetValue(Ds.Fields[I].FieldName, Ds.Fields[I].AsString);
end;

procedure TModelBase.LoadFromDs(Ds: TDataSet);
var
  Context: TRTTIContext;
  t: TRTTIType;
  f: TRTTIField;
  v: TValue;
  a: TCustomAttribute;
  DbFieldName: string;
  FieldName: string;
  DsField: TField;
begin
  LoadFields(Ds);
  Context := TRTTIContext.Create;
  try
    t := Context.GetType(Self.ClassType);
    for f in t.GetFields do begin
      if f.Visibility <> mvPublic then Continue;

      v := f.GetValue(Self);
      a := GetAttribute<DbFieldAttribute>(f);
      if a <> nil then
        DbFieldName := DbFieldAttribute(a).Name
      else
        DbFieldName := f.Name;
      FieldName := Format('%s_%s', [GetTableName, DbFieldName]);
      DsField := Ds.FindField(FieldName);
      if not Assigned(DsField) then
        DsField := Ds.FindField(f.Name);
      if Assigned(DsField) then
        if DsField.IsNull then begin
          case f.FieldType.TypeKind of
            tkInteger    : v := -1;
            tkFloat      : v := 0;
            tkUString    : v := '';
            tkEnumeration: v := False;
          end;
        end else begin
          case f.FieldType.TypeKind of
            tkInteger    : v := DsField.AsInteger;
            tkFloat      : v := DsField.AsFloat;
            tkEnumeration: v := DsField.AsInteger = 1;
            tkUString: begin
              v := DsField.AsString;
              for a in f.GetAttributes do
                if a is UTF8Attribute then
                  v := DsField.AsString;
            end;
          end;
          // remove from unmapped fields
          FFields.Remove(FieldName);
        end;
      f.SetValue(Self, v);
    end;
  finally
    Context.Free;
  end;
end;

class procedure TModelBase.Log(level: integer; text: string);
begin
  Db.ExecSQL('INSERT INTO `log` SET `message`=?', [text]);
end;

class function TModelBase.PrepareParams(Params: TParameters): TParams;
var
  Len: integer;
  i: Integer;
begin
  Result := TParams.Create(nil);
  Len := Params.Length;
  for i := 0 to Len-1 do begin
    if not Params[i].IsNull then
      Result.AddParameter.AsString := Params[i].Value
  end;
end;

class function TModelBase.PrepareSql(Params: TParameters; TableName, Select, Join, Where, GroupBy, OrderBy,
  Limit: string): string;
begin
  Result := Format('SELECT %s FROM `%s` %s %s %s %s %s', [
    Select,
    TableName,
    Join,
    Where,
    GroupBy,
    OrderBy,
    Limit
  ]);
end;

procedure TModelBase.Release;
begin
  Free;
end;

procedure TModelBase.Reload;
var
  cl: TModelClass;
  m: TModelBase;
  Ds: TDataSet;
  Params: TParameters;
begin
  cl := TModelClass(Self.ClassType);
  m := cl.Create;
  Params := TParameters.Create;
  Ds := nil;
  try
    Params.AddParameter(GetPkName, PkValue);
    Ds := FindRecords(Params, GetTableName, '', '');
    if not Ds.Eof then begin
      m.LoadFromDs(Ds);
      Assign(m);
    end;
  finally
    m.Free;
    Params.Free;
    Ds.Free;
  end;
//  v := Self.FindByPk<T>(GetPkValue);
//  Self.Assign(TModelBase(v));
//  v.Release;
end;

procedure TModelBase.Save(ForceCreate: Boolean);
var
  Params: TParameters;
begin
  Validate;
  Params := ToParameters();
  try
    if Params.Length > 0 then begin // если есть что сохранять
      try
        if not ForceCreate and (PkValue > -1) then begin
          Params.AddParameter(GetPkName, PkValue);
          UpdateRecord(Params, GetTableName, GetPkName)
        end else begin
          if ForceCreate then
          begin
            Params.AddParameter(GetPkName, PkValue);
            InsertRecord(Params, GetTableName)
          end
          else
            PkValue := InsertRecord(Params, GetTableName);
          Reload();
        end;
      except
        Reload;
        raise
      end;
    end;
  finally
    Params.Free;
  end;
end;

procedure TModelBase.Save;
begin
  Save(False);
end;

procedure TModelBase.SetPkValue(Value: Integer);
var
  Context: TRTTIContext;
  RTTIType: TRTTIType;
  RTTIField: TRTTIField;
  RTTIValue: TValue;
begin
  Context := TRTTIContext.Create;
  RTTIType := Context.GetType(Self.ClassType);
  RTTIField := RTTIType.GetField(GetPkName);
  Assert(Assigned(RTTIField), 'Pk value not found');
  RTTIValue := RTTIField.GetValue(Self);
  RTTIValue := Value;
  RTTIField.SetValue(Self, RTTIValue);
end;

procedure TModelBase.SetRelations(Relations: TList<TObject>);
var
  c: TRTTIContext;
  t: TRTTIType;
  f: TRTTIField;
  v: TValue;
  r: TObject;
  Model: TModelBase;
begin
  c := TRTTIContext.Create;
  try
    t := c.GetType(Self.ClassType);
    for f in t.GetFields do begin
      if f.Visibility <> mvPublic then Continue;

      if f.FieldType.TypeKind = tkClass then
        for r in Relations do begin
          Model := TRelation(r).Model;
          if Lowercase(f.Name) = Lowercase(Model.GetTableName) then begin
            v := f.GetValue(Self);
            v := Model;
            f.SetValue(Self, v);
          end;
        end;
    end;
  finally
    c.Free;
  end;
end;

function TModelBase.ToParameters: TParameters;
var
  Context: TRTTIContext;
  t: TRTTIType;
  f: TRTTIField;
  v: TValue;
  Def: DefaultValueAttribute;
  FieldName: string;
  a: TCustomAttribute;
begin
  Result  := TParameters.Create;
  Context := TRTTIContext.Create;
  try
    t := Context.GetType(Self.ClassType);
    for f in t.GetFields do begin
      if f.Visibility <> mvPublic then Continue;
      if not IsFieldReadOnly(f) and (f.Name <> GetPkName) then begin
        a := GetAttribute<DbFieldAttribute>(f);
        if a <> nil then
          FieldName := DbFieldAttribute(a).Name
        else
          FieldName := f.Name;
        v := f.GetValue(Self);

        case f.FieldType.TypeKind of
          tkInteger:begin
            if v.AsInteger = -1 then
              Result.AddParameter(FieldName, Null)
            else
              Result.AddParameter(FieldName, v.AsVariant);
          end;
          tkFloat:begin
            if CompareText(f.FieldType.Name, 'TDateTime') = 0 then begin// дата сохраняется текстом
              if v.AsExtended > 0 then
                Result.AddParameter(FieldName, FormatDateTime('yyyy-mm-dd hh:mm:ss', v.AsExtended))
              else
                Result.AddParameter(FieldName, Null);
            end else
              Result.AddParameter(FieldName, v.AsVariant);
          end;
          tkUString:
          begin
            if v.AsString = ''  then begin
              Def := DefaultValueAttribute(GetAttribute<DefaultValueAttribute>(f));
              if Assigned(Def) then
              begin
                Result.AddParameter(FieldName, Def.Value);
                Break;
              end;
            end;
            Result.AddParameter(FieldName, v.AsVariant);
          end;
          tkEnumeration:
            Result.AddParameter(FieldName, v.AsVariant);
        end;
      end;
    end;
  finally
    Context.Free;
  end;
end;

procedure TModelBase.Validate;
begin

end;

end.

