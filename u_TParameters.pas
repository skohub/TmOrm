unit u_TParameters;

interface

uses Variants;

type
  TParameter = record
    Name: string;
    Value: Variant;
    CompareSign: string;
  end;

  TParameters = class(TObject)
  private
    FParametersList: array of TParameter;
    function GetParametersList(Index: integer): TParameter;
    procedure SetParametersList(Index: integer; const Value: TParameter);
  public
    procedure AddParameter(Name: string; Value: Variant; CompareSign: string = '=');
    function GetParameter(Name: string): TParameter;
    procedure Remove(Name: string); overload;
    procedure Remove(Index: integer); overload;
    function Length: integer;
    property ParametersList[Index: integer]: TParameter read GetParametersList write SetParametersList; default;
    destructor Destroy; override;
  end;


implementation


{ TParameters }

procedure TParameters.AddParameter(Name: string; Value: Variant;
  CompareSign: string);
var
  Len, i, t: integer;
  Param: TParameter;
begin
  Len := System.Length(FParametersList);
  SetLength(FParametersList, Len+1);
  Param.Name := Name;
  t := VarType(Value) and varTypeMask;
  case t of
    varShortInt, varByte, varWord: Param.Value := Integer(Value);
    varLongWord, varInt64, varUInt64: Param.Value := Int64(Value);
    else
      Param.Value := Value;
  end;
  Param.CompareSign := CompareSign;
  FParametersList[Len] := Param;
end;

destructor TParameters.Destroy;
begin
  SetLength(FParametersList, 0);
  inherited;
end;

function TParameters.GetParameter(Name: string): TParameter;
var
  i, l: Integer;
begin
  Result.name := '';
  l := Length;
  for i := 0 to l - 1 do begin
    if ParametersList[i].name = Name then begin
      Result := ParametersList[i];
      Self.Remove(i);
      Break;
    end;
  end;
end;

function TParameters.GetParametersList(Index: integer): TParameter;
begin
  Result := FParametersList[Index];
end;

function TParameters.Length: integer;
begin
  Result := System.Length(FParametersList);
end;

procedure TParameters.Remove(Name: string);
var
  len: Integer;
  i: Integer;
  j: Integer;
begin
  len := System.Length(FParametersList);
  for i := 0 to len - 1 do begin
    if FParametersList[i].name = Name then
      Remove(i);
    Break;
  end;
end;

procedure TParameters.Remove(Index: integer);
var
  i: Integer;
  len: Integer;
begin
  len := System.Length(FParametersList);
  for i := Index to len - 2 do
    FParametersList[i] := FParametersList[i + 1];
  SetLength(FParametersList, len - 1);
end;

procedure TParameters.SetParametersList(Index: integer;
  const Value: TParameter);
begin
  FParametersList[Index] := Value;
end;


end.
