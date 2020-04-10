unit ObjectMapper;

interface

uses System.Rtti, System.TypInfo;

type
  TObjectMapper = class
  public
    class procedure Map(ASource, ATarget: TObject); overload;
    class procedure Map<TSource, TTarget>(ASource, ATarget: Pointer); overload;
  private
    class procedure TypedMap(ASourceTypeInfo, ATargetTypeInfo,
        ASource, ATarget: Pointer);
  end;

implementation

{ TMapper }

class procedure TObjectMapper.Map(ASource, ATarget: TObject);
begin
  TypedMap(ASource.ClassInfo, ATarget.ClassInfo, ASource, ATarget);
end;

class procedure TObjectMapper.Map<TSource, TTarget>(ASource, ATarget: Pointer);
begin
  TypedMap(TypeInfo(TSource), TypeInfo(TTarget), ASource, ATarget);
end;

class procedure TObjectMapper.TypedMap(ASourceTypeInfo, ATargetTypeInfo,
    ASource, ATarget: Pointer);
var
  LContext: TRTTIContext;
  LSourceType, LTargetType: TRTTIType;
  LSourceField, LTargetField: TRTTIField;
begin
  LContext := TRTTIContext.Create;
  try
    LSourceType := LContext.GetType(ASourceTypeInfo);
    LTargetType := LContext.GetType(ATargetTypeInfo);
    for LSourceField in LSourceType.GetFields do begin
      if LSourceField.Visibility <> mvPublic then Continue;

      LTargetField := LTargetType.GetField(LSourceField.Name);
      if LTargetField = nil then Continue;
      if LSourceField.FieldType.TypeKind <> LTargetField.FieldType.TypeKind then
        Continue;

      LTargetField.SetValue(ATarget, LSourceField.GetValue(ASource));
    end;
  finally
    LContext.Free;
  end;
end;

end.
