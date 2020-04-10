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

class function TModelFactory.CreateModel(Name: string): TModelBase;
begin

end;

end.
