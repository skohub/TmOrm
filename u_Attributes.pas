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

  DbFieldAttribute = class (TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(Name: string);
    property Name: string read FName;
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
    constructor Create(Value: Integer); overload;
    constructor Create(Value: Double); overload;
    constructor Create(Value: string); overload;
    constructor Create(Value: Pointer); overload;
    constructor Create(Value: Boolean); overload;
  end;

implementation

uses Variants;

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

constructor DefaultValueAttribute.Create(Value: Integer);
begin
  FValue := Value;
end;

constructor DefaultValueAttribute.Create(Value: Double);
begin
  FValue := Value;
end;

constructor DefaultValueAttribute.Create(Value: string);
begin
  FValue := Value;
end;

constructor DefaultValueAttribute.Create(Value: Pointer);
begin
  FValue := Null;
end;

constructor DefaultValueAttribute.Create(Value: Boolean);
begin
  FValue := Value;
end;

{ DbFieldAttribute }

constructor DbFieldAttribute.Create(Name: string);
begin
  FName := Name;
end;

end.
