unit u_IDbConnection;

interface

uses DB;

type
  IDbConnection = interface
    ['{A9FF1FBC-43F8-411D-A543-2FD9F6226AD0}']
    procedure ExecSQL(SQL: String); overload;
    procedure ExecSQL(SQL: String; Params: array of Variant); overload;
    procedure ExecSQL(SQL: String; Params: array of Variant; ATypes: array of TFieldType); overload;
    function ExecSQLScalar(SQL: string): Variant; overload;
    function ExecSQLScalar(SQL: string; Params: array of Variant): Variant; overload;
    function SelectSQL(SQL: String; Params: array of Variant): TDataSet; overload;
    function SelectSQL(SQL: String): TDataSet; overload;
  end;

implementation

end.
