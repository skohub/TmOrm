unit u_TPaginationParameters;

interface

type
  TPaginationParameters = class
  private
    const
      FDefaultPage = 1;
      FDefaultPageSize = 10;
      FMaxPageSize = 50;
    var
      FPage: Integer;
      FPageSize: Integer;
    procedure SetPage(const Value: Integer);
    procedure SetPageSize(const Value: Integer);
  public
    property Page: Integer read FPage write SetPage;
    property PageSize: Integer read FPageSize write SetPageSize;

    constructor Create; overload;
    constructor Create(Page, PageSize: Integer); overload;
  end;

implementation

uses Math;

{ TPaginationParameters }

constructor TPaginationParameters.Create;
begin
  inherited;

  FPage := FDefaultPage;
  FPageSize := FDefaultPageSize;
end;

constructor TPaginationParameters.Create(Page, PageSize: Integer);
begin
  inherited Create;

  Self.Page := Page;
  Self.PageSize := PageSize;
end;

procedure TPaginationParameters.SetPage(const Value: Integer);
begin
  FPage := Value;
end;

procedure TPaginationParameters.SetPageSize(const Value: Integer);
begin
  if Value > FMaxPageSize then
    FPageSize := FMaxPageSize
  else
    FPageSize := Value;
end;

end.
