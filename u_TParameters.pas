unit u_TParameters;

interface

uses Variants;

type
  TParameter = record
    Name: string;
    Value: Variant;
    CompareSign: string;

    function IsNull: Boolean;
  end;

  TParameters = class(TObject)
  private
    FLimit: Integer;
    FOffset: Integer;
    FParameters: array of TParameter;
    // Get and delete
    function ExtractParameterValue(Name: string): string;
    function GetParameter(Index: integer): TParameter; overload;
    procedure SetParameter(Index: integer; const Value: TParameter);
    procedure SetLimit(const Value: Integer);
    procedure SetOffset(const Value: Integer);
  public
    function Length: integer;
    procedure AddRange(Source: TParameters);
    function GetParameter(Name: string): TParameter; overload;
    function ToVarArray: Variant;
    property Parameters[Index: integer]: TParameter read GetParameter write SetParameter; default;
    procedure AddParameter(Name: string; Value: Variant; CompareSign: string = '=');
    procedure Remove(Name: string); overload;
    procedure Remove(Index: integer); overload;
    procedure Clear;
    property Limit: Integer read FLimit write SetLimit;
    property Offset: Integer read FOffset write SetOffset;

    function GetSelectSql: string;
    function GetJoinSql: string;
    function GetWhereSql(TableName: string): string;
    function GetGroupBySql: string;
    function GetOrderBySql: string;
    function GetLimitSql: string;

    destructor Destroy; override;
  end;


implementation

uses SysUtils;

{ TParameters }

procedure TParameters.AddParameter(Name: string; Value: Variant;
  CompareSign: string);
var
  Len, i, t: integer;
  Param: TParameter;
  ExistingValue: string;
begin
  if Name = 'join' then
    ExistingValue := GetParameter(Name).Value;

  Len := System.Length(FParameters);
  SetLength(FParameters, Len+1);
  Param.Name := Name;
  t := VarType(Value) and varTypeMask;
  case t of
    varShortInt, varByte, varWord: Param.Value := Integer(Value);
    varLongWord, varInt64, varUInt64: Param.Value := Int64(Value);
    else
      if ExistingValue <> '' then
        Param.Value := ExistingValue + ' ' + Value
      else
        Param.Value := Value;
  end;
  Param.CompareSign := CompareSign;
  FParameters[Len] := Param;
end;

procedure TParameters.AddRange(Source: TParameters);
var
  I, L: Integer;
  P: TParameter;
begin
  L := Source.Length;
  for I := 0 to L - 1 do
  begin
    P := Source[I];
    AddParameter(P.Name, P.Value, P.CompareSign);
  end;
end;

procedure TParameters.Clear;
begin
  SetLength(FParameters, 0);
end;

destructor TParameters.Destroy;
begin
  SetLength(FParameters, 0);
  inherited;
end;

function TParameters.GetGroupBySql: string;
var
  GroupBy: string;
begin
  GroupBy := ExtractParameterValue('groupby');
  if GroupBy.IsEmpty then Exit('');

  Result := Format('GROUP BY %s', [GroupBy]);
end;

function TParameters.GetJoinSql: string;
begin
  Result := ExtractParameterValue('join');
end;

function TParameters.GetLimitSql: string;
begin
  Result := '';

  if (Limit > 0) and (Offset > 0) then
    Result := Format('LIMIT %d, %d', [Offset, Limit])
  else if Limit > 0 then
    Result := Format('LIMIT %d', [Limit]);
end;

function TParameters.GetOrderBySql: string;
var
  OrderBy: string;
begin
  OrderBy := ExtractParameterValue('orderby');
  if OrderBy.IsEmpty then Exit('');

  Result := Format('ORDER BY %s', [OrderBy]);
end;

function TParameters.GetParameter(Name: string): TParameter;
var
  i, l: Integer;
begin
  Result.name := '';
  Result.Value := '';
  l := Length;
  for i := 0 to l - 1 do begin
    if Parameters[i].name = Name then begin
      Result := Parameters[i];
      Self.Remove(i);
      Break;
    end;
  end;
end;

function TParameters.ExtractParameterValue(Name: string): string;
var
  Parameter: TParameter;
begin
  Result := '';

  Parameter := GetParameter(Name);
  if Parameter.Name <> '' then
  begin
    Result := Parameter.Value;
    Remove(Name);
  end;
end;

function TParameters.GetSelectSql: string;
begin
  Result := ExtractParameterValue('select');
end;

function TParameters.GetWhereSql(TableName: string): string;
var
  Len: integer;
  Field: string;
  I: Integer;
  Conditions: string;
  WhereParam: string;
begin
  WhereParam := ExtractParameterValue('where');
  // get conditions
  Len := Length;
  for I := 0 to Len-1 do begin
    if Conditions <> '' then
      Conditions := Conditions + ' AND ';

    if Pos('.', Parameters[i].Name) = 0 then
      Field := TableName + '.' + Parameters[i].Name
    else
      Field := Parameters[i].Name;

    if Parameters[i].IsNull then
      Conditions := Conditions + Field + ' IS NULL '
    else begin
      Conditions := Format('%s %s %s ? ', [Conditions, Field, Parameters[i].CompareSign]);
    end;
  end;
  //
  if not (Conditions.IsEmpty or WhereParam.IsEmpty) then
    Result := Format('WHERE %s AND %s', [Conditions, WhereParam])
  else if not (Conditions.IsEmpty and WhereParam.IsEmpty) then
    Result := Format('WHERE %s%s', [Conditions, WhereParam])
  else
    Result := '';
end;

function TParameters.GetParameter(Index: integer): TParameter;
begin
  Result := FParameters[Index];
end;

function TParameters.Length: integer;
begin
  Result := System.Length(FParameters);
end;

procedure TParameters.Remove(Name: string);
var
  len: Integer;
  i: Integer;
  j: Integer;
begin
  len := System.Length(FParameters);
  for i := 0 to len - 1 do begin
    if FParameters[i].name = Name then
      Remove(i);
    Break;
  end;
end;

procedure TParameters.Remove(Index: integer);
var
  i: Integer;
  len: Integer;
begin
  len := System.Length(FParameters);
  for i := Index to len - 2 do
    FParameters[i] := FParameters[i + 1];
  SetLength(FParameters, len - 1);
end;

procedure TParameters.SetLimit(const Value: Integer);
begin
  FLimit := Value;
end;

procedure TParameters.SetOffset(const Value: Integer);
begin
  FOffset := Value;
end;

procedure TParameters.SetParameter(Index: integer;
  const Value: TParameter);
begin
  FParameters[Index] := Value;
end;

function TParameters.ToVarArray: Variant;
var
  L, Count: Integer;
  I: Integer;
begin
  L := System.Length(FParameters);
  Count := 0;
  for I := 0 to L - 1 do
    Inc(Count, Integer(not Parameters[I].IsNull));

  Result := VarArrayCreate([0, Count - 1], VarVariant);
  for i := 0 to L - 1 do
    if not Parameters[i].IsNull then
      Result[i] := Parameters[i].Value;
end;

{ TParameter }

function TParameter.IsNull: Boolean;
begin
  Result := LowerCase(Value) = 'null'
end;

end.
