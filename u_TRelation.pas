unit u_TRelation;

interface

uses
  Generics.Collections, u_TModelBase;

type
  TRelation = class (TObject)
  public
    Model: TModelBase;
    FkName: string;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TRelation }

constructor TRelation.Create;
begin
end;

destructor TRelation.Destroy;
begin
  inherited;
end;

end.
