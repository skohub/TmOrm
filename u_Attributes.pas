unit u_Attributes;

interface

type
  //
  SelectAttribute = class (TCustomAttribute)
  private
    FSql: string;
  public
    constructor Create(Sql: string);
    property Sql: string read FSql;
  end;

  FkNameAttribute = class (TCustomAttribute)
  private
    FFkName: string;
  public
    constructor Create(FkName: string);
    property FkName: string read FFkName;
  end;

  UTF8Attribute = class (TCustomAttribute)
  end;

  ReadOnlyAttribute = class (TCustomAttribute)
  end;

  DefaultValueAttribute = class (TCustomAttribute)
  private
    FValue: Variant;
  public
    property Value: Variant read FValue;
    constructor Create(Value: Variant);
  end;

implementation

{ SelectAttribute }

constructor SelectAttribute.Create(Sql: string);
begin
  FSql := Sql;
end;

{ FkNameAttribute }

constructor FkNameAttribute.Create(FkName: string);
begin
  FFkName := FkName;
end;

{ DefaultValueAttribute }

constructor DefaultValueAttribute.Create(Value: Variant);
begin
  FValue := Value;
end;

end.
