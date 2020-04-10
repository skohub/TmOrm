unit ObjectComparer;

interface

uses Generics.Collections;

type
  TObjectComparer = class
  public
    class function ShallowCompare<T>(
      ASource, ATarget: Pointer; BlackList: TList<string> = nil;
      WhiteList: TList<string> = nil): Boolean;
  private
    class function ShallowCompareByPointer(ASource, ATarget: Pointer;
      ATypeInfo: Pointer; BlackList: TList<string> = nil;
      WhiteList: TList<string> = nil): Boolean;
  end;

implementation

uses System.Rtti, System.TypInfo;

class function TObjectComparer.ShallowCompareByPointer(ASource, ATarget: Pointer;
    ATypeInfo: Pointer; BlackList, WhiteList: TList<string>): Boolean;
var
  LContext: TRTTIContext;
  LSourceType, LTargetType: TRTTIType;
  LSourceField, LTargetField: TRTTIField;
  LSourceValue, LTargetValue: TValue;
begin
  Result := True;
  LContext := TRTTIContext.Create;
  try
    LSourceType := LContext.GetType(ATypeInfo);
    LTargetType := LContext.GetType(ATypeInfo);
    for LSourceField in LSourceType.GetFields do begin
      if LSourceField.Visibility <> mvPublic then Continue;

      if Assigned(BlackList) and BlackList.Contains(LSourceField.Name) then
        Continue;

      if Assigned(WhiteList) and not WhiteList.Contains(LSourceField.Name) then
        Continue;

      LTargetField := LTargetType.GetField(LSourceField.Name);
      if LTargetField = nil then Exit(False);

      if LSourceField.FieldType.TypeKind <> LTargetField.FieldType.TypeKind then
        Exit(False);

      LSourceValue := LSourceField.GetValue(ASource);
      LTargetValue := LTargetField.GetValue(ATarget);
      if LSourceValue.AsVariant <> LTargetValue.AsVariant then
        Exit(False);
    end;
  finally
    LContext.Free;
  end;
end;

class function TObjectComparer.ShallowCompare<T>(ASource, ATarget: Pointer; BlackList,
  WhiteList: TList<string>): Boolean;
begin
  Result := ShallowCompareByPointer(ASource, ATarget, TypeInfo(T), BlackList, WhiteList);
end;

end.
