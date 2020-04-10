unit u_TRelation;

interface

uses
  Generics.Collections, u_TModelBase;

type
  TRelation = class (TObject)
  public
    Model: TModelBase;
    FkName: string;

    destructor Destroy; override;
  end;

implementation

{ TRelation }

{ TRelation }

destructor TRelation.Destroy;
begin
  Model.Free;
  inherited;
end;

end.
