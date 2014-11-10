unit u_IModelBase;

interface

uses
  Db, u_TParameters, Generics.Collections;

type
  IModelBase = interface
    procedure LoadFromDs(Ds: TDataSet);
    procedure SetRelations(RelationInstances: TList<TObject>);
    procedure Clear;
    procedure Release;
  end;

implementation

end.
