unit u_TPagedList;

interface

uses Generics.Collections;

type
  TPagedList<T> = class(TList<T>)
  private
    FCurrentPage: Integer;
    FPageSize: Integer;
    FTotalCount: Integer;
    FPageCount: Integer;
  public
    property CurrentPage: Integer read FCurrentPage;
    property PageSize: Integer read FPageSize;
    property TotalCount: Integer read FTotalCount;
    property PageCount: Integer read FPageCount;
    function HasPreviuos: Boolean;
    function HasNext: Boolean;

    constructor Create(TotalCount, Page, PageSize: Integer);
    class function CreatePagedList(List: TList<T>; TotalCount, Page, PageSize: Integer): TPagedList<T>;
  end;

implementation

uses Math;

{ TPagedList }

constructor TPagedList<T>.Create(TotalCount, Page, PageSize: Integer);
begin
  inherited Create;

  FTotalCount := TotalCount;
  FCurrentPage := Page;
  FPageSize := PageSize;
  FPageCount := Ceil(TotalCount / PageSize);
end;

class function TPagedList<T>.CreatePagedList(List: TList<T>; TotalCount, Page, PageSize: Integer): TPagedList<T>;
begin
  Result := TPagedList<T>.Create(TotalCount, Page, PageSize);
  if Assigned(List) then
    Result.AddRange(List.ToArray);
end;

function TPagedList<T>.HasNext: Boolean;
begin
  Result := CurrentPage < PageCount;
end;

function TPagedList<T>.HasPreviuos: Boolean;
begin
  Result := CurrentPage > 1;
end;

end.
