unit u_TModelFactory;

interface

uses
  u_TModelBase;

type
  TModelFactory = class
    class function CreateModel(Name: string): TModelBase;
  end;

implementation

{ TModelFactory }


uses u_TProduct;

class function TModelFactory.CreateModel(Name: string): TModelBase;
begin

end;

end.
