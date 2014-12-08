unit u_TModelBase;

interface

uses
  u_TParameters, Db, Data.SqlExpr, Data.dbxcommon, Variants, Winapi.Windows,
  SysUtils, Generics.Collections, u_IModelBase, RTTI, System.TypInfo, Classes;

type
  TModelClass = class of TModelBase;
  TModelBase = class(TInterfacedObject, IModelBase)
  private
    function GetPkValue: Integer;
    procedure SetPkValue(Value: Integer);
  public
    class var Connection: TSqlConnection;

    constructor Create; virtual;
    destructor Destroy; override;
    class function GetTableName: string; virtual; abstract;
    class function GetPkName: string; virtual; abstract;
    // relations
    class function GetSelectFields: string;
    class function GetJoinPart(SecondTableName, SecondPkName: string): string;

    class procedure GetRelationVariables(Relations: TList<TObject>; var Select, Join: string);
    class function  GetRelations(TableNames: TStringList): TList<TObject>;
    procedure SetRelations(RelationInstances: TList<TObject>);
    //
    class function Find<T:IModelBase, constructor>(Params: TParameters; EagerLoad: TStringList = nil): TList<T>;
    class function FindByPk<T:IModelBase, constructor>(Id: Integer): T;
    procedure LoadFromDs(Ds: TDataSet);
    procedure Clear;
    procedure Release;
    procedure Assign(Source: TModelBase);
    procedure Delete; virtual;
    procedure Save; virtual;
    procedure Reload;
    function  IsFieldReadOnly(Field: TRTTIField): Boolean;
    class function  GetAttribute<T: TCustomAttribute>(Field: TRTTIField): TCustomAttribute;
    property  PkValue: Integer read GetPkValue write SetPkValue;

    procedure FreeRelatedModel(Model: TObject); virtual;
    class function  GetCompareSign(CompareSign: string): string;
    class function  ProcessSearchProperties(Params: TParameters; TableName: string; var Sql: string): TParams;
    class function  FindRecords(Params: TParameters; TableName: string; RelationsSelect, RelationsJoin: string): TDataSet; virtual;
    class function  InsertRecord(Params: TParameters; TableName: string): integer; virtual;
    class procedure EditRecord(Params: TParameters; TableName, KeyName: string); virtual;
    class procedure DeleteRecord(id: integer; id_column: string; table_name: string); virtual;
    class function  FindExRecord(Params: TParameters; SQL: string): TDataSet;
    class function  ExecSQL(SQL: String; Params: Variant): TDataSet;
    class function  LastInsertID: integer;
    class procedure Log(level: integer; text: string);
    class function  Select(Sql: String; Params: TParameters): TDataSet;
  end;

implementation

uses u_Attributes, u_TRelation;


class function TModelBase.ExecSQL(SQL: String; Params: Variant): TDataSet;
var
  Ds: TSqlDataSet;
  l: Integer;
  h: Integer;
  i: Integer;
begin
  Ds := TSqlDataSet.Create(nil);
  Ds.SQLConnection := Connection;
  Ds.CommandText := SQL;
  Ds.Params.Clear;
  if VarIsArray(Params) then begin
    l := VarArrayLowBound(Params, 1);
    h := VarArrayHighBound(Params, 1);
    for i := l to h do
      Ds.Params.AddParameter.Value := VarArrayGet(Params, [i]);
  end;
  Ds.Open;
  VarClear(Params);
  Result := Ds;
end;

class procedure TModelBase.EditRecord(Params: TParameters; TableName, KeyName: string);
var
  Sql, Sep: string;
  i, l: integer;
  Ds: TSqlDataSet;
  Key: TParameter;
begin
  Ds := TSqlDataSet.Create(nil);
  Ds.SQLConnection := Connection;
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
  Ds.CommandText := Sql;
  for i := 0 to l - 1 do begin
    if Params[i].Value = Null then // если NULL
      with Ds.Params.AddParameter do begin
        DataType := ftString;
        Bound := True;
        Clear;
      end else
        Ds.Params.AddParameter.Value := Params[i].Value;
  end;
  Ds.Params.AddParameter.AsInteger := Key.Value;
  Ds.ExecSQL;
end;

class function TModelBase.InsertRecord(Params: TParameters; TableName: string): integer;
var
  Sql, Sep: string;
  i, l: integer;
  Ds: TSqlDataSet;
  Key: TParameter;
begin
  Result := -1;
  Ds := TSqlDataSet.Create(nil);
  Ds.SQLConnection := Connection;
  Sql := 'INSERT INTO `' + TableName + '` SET ';
  Sep := '';
  l := Params.Length;
  if l = 0 then
    raise Exception.Create('Не передано ни одного параметра для редактирования таблицы ' + TableName + '.');
  for i := 0 to l - 1 do begin
    Sql := Sql + Sep + '`' + Params[i].name + '`=?';
    Sep := ',';
  end;
  Ds.CommandText := Sql;
  for i := 0 to l - 1 do begin
    if Params[i].Value = Null then // если NULL
      with Ds.Params.AddParameter do begin
        DataType := ftString;
        Bound := True;
        Clear;
      end else
        Ds.Params.AddParameter.Value := Params[i].Value;
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
    for f in t.GetDeclaredFields do begin
      sf := st.GetField(f.Name);
      v  := f.GetValue(Self);
      sv := sf.GetValue(Source);
      case f.FieldType.TypeKind of
        tkInteger, tkFloat, tkUString: begin
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
  m: TRTTIMethod;
begin
  Context := TRTTIContext.Create;
  t := Context.GetType(Self.ClassType);
  f := t.GetField(GetPkName);
  for f in t.GetDeclaredFields do begin
    v := f.GetValue(Self);
    a := GetAttribute<DefaultValueAttribute>(f);
    if Assigned(a) then begin // если есть значение по-умолчанию
      v.FromVariant(DefaultValueAttribute(a).Value);
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
          if v.AsObject <> nil then
            FreeRelatedModel(v.AsObject);
          v := nil;
          f.SetValue(Self, v);
        end;
      end;
  end;
end;

constructor TModelBase.Create;
begin
  inherited;
  Clear;
end;

procedure TModelBase.Delete;
begin
  if PkValue > -1 then
    DeleteRecord(PkValue, GetPkName, GetTableName);
end;

class procedure TModelBase.DeleteRecord(id: integer; id_column: string; table_name: string);
var
  Ds: TSqlDataSet;
begin
  Ds := TSqlDataSet.Create(nil);
  try
    Ds.SQLConnection := Connection;
    Ds.CommandText := Format('DELETE FROM %s WHERE %s=?', [table_name, id_column]);
    Ds.Params.AddParameter.Value := id;
    Ds.ExecSQL;
  finally
    Ds.Free;
  end;
end;

destructor TModelBase.Destroy;
begin
  Clear;
  inherited;
end;

class function  TModelBase.FindRecords(Params: TParameters; TableName: string; RelationsSelect, RelationsJoin: string): TDataSet;
var
  Sql: string;
  Select: string;
  Join: string;
  Order: string;
  Group: string;
  Limit: string;
  Where: string;
  Ds: TSQLDataSet;
  SqlParams: TParams;
  p: TParameter;
begin
  Ds := TSQLDataSet.Create(nil);
  Ds.ParamCheck := False;
  Ds.GetMetadata := False;
  Ds.SQLConnection := Connection;
  p := Params.GetParameter('groupby');
  if p.Name <> '' then
    Group := 'GROUP BY ' + p.Value;
  p := Params.GetParameter('orderby');
  if p.Name <> '' then
    Order := 'ORDER BY ' + p.Value;
  p := Params.GetParameter('limit');
  if p.Name <> '' then
    Limit := 'LIMIT ' + p.Value;
  if Group = '' then // если исползуется group by, то надо указывать каждое поле в параметре select
    Select := GetSelectFields;
  p := Params.GetParameter('select');
  if p.Name <> '' then begin
    if Select <> '' then
      Select := Select + ',';
    Select := Select + p.Value
  end;
  if (Group = '') and (RelationsSelect <> '') then
    Select := Select + ',' + RelationsSelect;

  Join := RelationsJoin;
  p := Params.GetParameter('join');
  if p.Name <> '' then
    Join := Join + p.Value;

  p := Params.GetParameter('where');
  if p.Name <> '' then
    Where := 'WHERE ' + p.Value;
  SqlParams := ProcessSearchProperties(Params, TableName, Sql);
  if Sql <> '' then
    if Where = '' then
      Where := Format('WHERE %s', [Sql])
    else
      Where := Format('%s AND %s', [Where, Sql]);
  Ds.CommandText := Format('SELECT %s FROM `%s` %s %s %s %s %s',
    [Select, TableName, Join, Where, Group, Order,
    Limit]);
  try
    Ds.Params.Assign(SqlParams);
    SqlParams.Free;
    Ds.Open;
    Result := Ds;
  except
    Result := nil;
    Ds.Free;
    raise;
  end;
end;

procedure TModelBase.FreeRelatedModel(Model: TObject);
begin
  Model.Free;
end;

class function TModelBase.Find<T>(Params: TParameters; EagerLoad: TStringList): TList<T>;
var
  Ds: TDataSet;
  Value: T;
  i, Len: Integer;
  Relations: TList<TObject>;
  Relation: TObject;
  RelationInstance: TModelBase;
  RelationInstances: TList<TObject>;
  s1, j1: string;
begin
  RelationInstances := nil;
  Result := TList<T>.Create;
  Relations := GetRelations(EagerLoad);
  RelationInstances := TList<TObject>.Create;
  GetRelationVariables(Relations, s1, j1);
  Ds := FindRecords(Params, GetTableName, s1, j1);
  try
    while not Ds.Eof do begin
      for Relation in Relations do begin
        RelationInstance := TModelBase(TRelation(Relation).Model.ClassType.Create);
        RelationInstance.LoadFromDs(Ds);
        RelationInstances.Add(RelationInstance);
      end;
      Value := T.Create;
      Value.LoadFromDs(Ds);
      Value.SetRelations(RelationInstances);
      RelationInstances.Clear;
      Result.Add(Value);
      Ds.Next;
    end;
  finally
    Ds.Free;
    Relations.Free;
    RelationInstances.Free;
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

class function  TModelBase.FindExRecord(Params: TParameters; SQL: string): TDataSet;
var where: string;
    _and: string;
    ds: TSqlDataSet;
    len: integer;
    i: integer;
begin
  ds := TSqlDataSet.Create(nil);
  try
    ds.ParamCheck := False;
    ds.SqlConnection := Connection;
    len := params.Length;
    if len > 0 then where := 'WHERE';
    for i := 0 to len-1 do begin
      where := Format(
                 '%s %s %s %s ?',
                 [where,
                 _and,
                 params[i].name,
                 GetCompareSign(params[i].CompareSign)]
               );
      _and := 'AND';
    end;
    ds.CommandText := Format(SQL, [where]);
    for i := 0 to len-1 do
      ds.Params.AddParameter.Value := params[i].value;
    ds.Open;
    Result := ds;
  except
    ds.Free;
  end;
end;

class procedure TModelBase.GetRelationVariables(Relations: TList<TObject>; var Select, Join: string);
var
  Len: Integer;
  i: Integer;
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

class function TModelBase.GetJoinPart(SecondTableName, SecondPkName: string): string;
begin
  Result := Format(
    'LEFT JOIN `%s` ON `%s`.`%s`=`%s`.`%s` ',
    [GetTableName, GetTableName, GetPkName, SecondTableName, SecondPkName]
  );
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
  t: TRTTIType;
  f: TRTTIField;
  a: TCustomAttribute;
  FkName: string;
  r: TRelation;
begin
  c := TRTTIContext.Create;
  try
    Result := TList<TObject>.Create;
    t := c.GetType(Self);
    f := t.GetField(GetPkName);
    for f in t.GetDeclaredFields do begin
      FkName := '';
      a := GetAttribute<FkNameAttribute>(f);
      if Assigned(a) then
        FkName := FkNameAttribute(a).FkName;
      if f.FieldType.TypeKind = tkClass then
        if Assigned(TableNames) and (TableNames.IndexOf(f.Name) > -1) then begin
          r := TRelation.Create;
          r.Model := TModelBase(f.FieldType.AsInstance.MetaclassType.Create);
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
  v: TValue;
  a: TCustomAttribute;
  FieldSql: string;
  Sep: string;
  SkipField: Boolean;
begin
  Sep := '';
  Result := '';
  Context := TRTTIContext.Create;
  t := Context.GetType(Self);
  f := t.GetField(GetPkName);
  for f in t.GetDeclaredFields do begin
    FieldSql := '';
    SkipField := False;
    if f.Visibility = mvPrivate then
      SkipField := True
    else
      for a in f.GetAttributes do begin
        if a is SelectAttribute then
          if SelectAttribute(a).Sql <> '' then
            FieldSql := SelectAttribute(a).Sql
          else
            SkipField := True;
    end;
    if not SkipField and (f.FieldType.TypeKind <> tkClass) then begin
      if FieldSql = '' then
        FieldSql := Format('`%s`.`%s`', [GetTableName, f.Name]);
      Result := Format('%s%s %s AS %s_%s',
        [Result, Sep, FieldSql, GetTableName, f.Name]);
      Sep := ',';
    end;
  end;
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
  Ds: TSqlDataSet;
begin
  Result := -1;
  Ds := TSqlDataSet.Create(nil);
  try
    Ds.SQLConnection := Connection;
    Ds.CommandText := 'SELECT LAST_INSERT_ID()';
    Ds.Open;
    Result := ds.Fields[0].AsInteger;
  finally
    Ds.Free;
  end;
end;

procedure TModelBase.LoadFromDs(Ds: TDataSet);
var
  Context: TRTTIContext;
  t: TRTTIType;
  f: TRTTIField;
  v: TValue;
  a: TCustomAttribute;
  FieldName: string;
  DsField: TField;
begin
  Context := TRTTIContext.Create;
  try
    t := Context.GetType(Self.ClassType);
    f := t.GetField(GetPkName);
    for f in t.GetDeclaredFields do begin
      v := f.GetValue(Self);
      FieldName := Format('%s_%s', [GetTableName, f.Name]);
      DsField := Ds.FindField(FieldName);
      if not Assigned(DsField) then
        DsField := Ds.FindField(f.Name);
      if Assigned(DsField) then
        if DsField.IsNull then begin
          case f.FieldType.TypeKind of
            tkInteger: v := -1;
            tkFloat  : v := 0;
            tkUString: v := '';
          end;
        end else
          case f.FieldType.TypeKind of
            tkInteger: v := DsField.AsInteger;
            tkFloat  : v := DsField.AsFloat;
            tkUString: begin
              v := DsField.AsString;
              for a in f.GetAttributes do
                if a is UTF8Attribute then
                  v := TEncoding.UTF8.GetString(DsField.AsBytes);
            end;
          end;
      f.SetValue(Self, v);
    end;
  finally
    Context.Free;
  end;
end;

class procedure TModelBase.Log(level: integer; text: string);
begin
  ExecSQL('INSERT INTO log SET message=?', text);
end;

class function TModelBase.ProcessSearchProperties(Params: TParameters; TableName: string; var Sql: string): TParams;
var
  Len, n: integer;
  Field: string;
  i: Integer;
  p: TParams;
begin
  p := TParams.Create(nil);
  Len := Params.Length;
  for i := 0 to Len-1 do begin
    if Sql <> '' then
      Sql := Sql + ' AND ';
    if Pos('.', Params[i].Name) = 0 then
      Field := TableName + '.' + Params[i].Name
    else
      Field := Params[i].Name;
    if lowercase(Params[i].Value) = 'null' then
      Sql := Sql + Field + ' IS NULL '
    else begin
      Sql := Format('%s %s %s ? ', [Sql, Field, Params[i].CompareSign]);
      p.AddParameter.AsString := Params[i].Value
    end;
  end;
  Result := p;
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
  Ds := TDataSet.Create(nil);
  try
    Params.AddParameter(GetPkName, PkValue);
    Ds := FindRecords(Params, GetTableName, '', '');
    m.LoadFromDs(Ds);
    Assign(m);
  finally
    m.Free;
    Params.Free;
    Ds.Free;
  end;
//  v := Self.FindByPk<T>(GetPkValue);
//  Self.Assign(TModelBase(v));
//  v.Release;
end;

procedure TModelBase.Save;
var
  Context: TRTTIContext;
  t: TRTTIType;
  f: TRTTIField;
  v: TValue;
  Params: TParameters;
begin
  Context := TRTTIContext.Create;
  Params  := TParameters.Create;
  try
    t := Context.GetType(Self.ClassType);
    f := t.GetField(GetPkName);
    for f in t.GetDeclaredFields do begin
      if not IsFieldReadOnly(f) and (f.Name <> GetPkName) then begin
        case f.FieldType.TypeKind of
          tkInteger:begin
            v := f.GetValue(Self);
            if v.AsInteger = -1 then
              Params.AddParameter(f.Name, Null)
            else
              Params.AddParameter(f.Name, v.AsVariant);
          end;
          tkFloat, tkUString:begin
            v := f.GetValue(Self);
            if CompareText(f.FieldType.Name, 'TDateTime') = 0 then // дата сохраняется текстом
              Params.AddParameter(f.Name, FormatDateTime('yyyy-mm-dd hh:mm:ss', v.AsExtended))
            else
            Params.AddParameter(f.Name, v.AsVariant);
          end;
        end;
      end;
    end;
    if Params.Length > 0 then begin // если есть что сохранять
      try
        if PkValue > -1 then begin
          Params.AddParameter(GetPkName, PkValue);
          EditRecord(Params, GetTableName, GetPkName)
        end else begin
          PkValue := InsertRecord(Params, GetTableName);
          Reload;
        end;
      except
        Reload;
        raise
      end;
    end;
  finally
    Context.Free;
  end;
end;

class function TModelBase.Select(Sql: String; Params: TParameters): TDataSet;
var
  Ds: TSqlDataSet;
  i: Integer;
begin
  Ds := TSqlDataSet.Create(nil);
  try
    Ds.SQLConnection := TModelBase.Connection;
    Ds.CommandText := Sql;
    for i := 0 to Params.Length - 1 do
      Ds.Params.AddParameter.Value := Params[i].Value;
    Ds.Open;
    Result := Ds;
  except
    Ds.Free;
    raise;
  end;
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

procedure TModelBase.SetRelations(RelationInstances: TList<TObject>);
var
  c: TRTTIContext;
  t: TRTTIType;
  f: TRTTIField;
  v: TValue;
  r: TObject;
begin
  c := TRTTIContext.Create;
  try
    t := c.GetType(Self.ClassType);
    for f in t.GetDeclaredFields do begin
      if f.FieldType.TypeKind = tkClass then
        for r in RelationInstances do begin
          if f.Name = TModelBase(r).GetTableName then begin
            v := f.GetValue(Self);
            v := TModelBase(r);
            f.SetValue(Self, v);
          end;
        end;
    end;
  finally
    c.Free;
  end;
end;

end.
