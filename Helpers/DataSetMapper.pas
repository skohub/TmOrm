unit DataSetMapper;

interface

uses DB, System.Rtti, System.TypInfo, Generics.Collections;

type
  TDataSetMapper = class
  private
    class function FieldIsId(FieldName: string): Boolean;
    class procedure Map(Ds: TDataSet; RecieverType: Pointer; Reciever: Pointer); overload;
  public
    class procedure Map<T>(Ds: TDataSet; Reciever: Pointer); overload;
    class function Map<T: class, constructor>(Ds: TDataSet): TList<T>; overload;
    class procedure Map(Ds: TDataSet; Reciever: TObject); overload;
  end;

implementation

uses
  Math, StrUtils;

{ TDataSetHelper }

class function TDataSetMapper.FieldIsId(FieldName: string): Boolean;
begin
  Result := StrUtils.RightStr(FieldName, 2) = 'id';
end;

class procedure TDataSetMapper.Map(Ds: TDataSet; RecieverType: Pointer; Reciever: Pointer);
var
  LContext: TRTTIContext;
  LType: TRTTIType;
  LField: TRTTIField;
  LValue: TValue;
  LAttribute: TCustomAttribute;
  LFieldName: string;
  LDsField: TField;
begin
  if not Assigned(Ds) then Exit;

  LContext := TRTTIContext.Create;
  try
    LType := LContext.GetType(RecieverType);
    for LField in LType.GetFields do begin
      if LField.Visibility <> mvPublic then Continue;

      LDsField := Ds.FindField(LField.Name);
      if Assigned(LDsField) then
      begin
        if LDsField.IsNull then begin
          case LField.FieldType.TypeKind of
            tkInteger     : LValue := IfThen(FieldIsId(LField.Name), -1, 0);
            tkFloat       : LValue := 0;
            tkUString     : LValue := '';
            tkEnumeration :
              if LField.FieldType.ClassName = 'TRttiEnumerationType' then
                TValue.Make(0, LField.FieldType.Handle, LValue)
              else
                LValue := False;
          end;
        end else begin
          case LField.FieldType.TypeKind of
            tkInteger     : LValue := LDsField.AsInteger;
            tkFloat       : LValue := LDsField.AsFloat;
            tkEnumeration :
              if LField.FieldType.ClassName = 'TRttiEnumerationType' then
                TValue.Make(LDsField.AsInteger, LField.FieldType.Handle, LValue)
              else
                LValue := LDsField.AsInteger = 1;
            tkUString     : LValue := LDsField.AsString;
          end;
        end;
        LField.SetValue(Reciever, LValue);
      end;
    end;
  finally
    LContext.Free;
  end;
end;

class procedure TDataSetMapper.Map(Ds: TDataSet; Reciever: TObject);
begin
  Map(Ds, Reciever.ClassType.ClassInfo, Reciever);
end;

class function TDataSetMapper.Map<T>(Ds: TDataSet): TList<T>;
var
  Item: T;
begin
  Result := TList<T>.Create();
  if Ds = nil then Exit();
  
  while not Ds.Eof do
  begin
    Item := T.Create();
    Map(Ds, Item);
    Result.Add(Item);
    Ds.Next;
  end;  
end;

class procedure TDataSetMapper.Map<T>(Ds: TDataSet; Reciever: Pointer);
begin
  Map(Ds, TypeInfo(T), Reciever);
end;

end.
