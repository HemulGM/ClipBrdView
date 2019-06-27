unit Buf.History;

interface

  uses
    Vcl.Graphics, System.DateUtils, System.Classes, SQLite3, SQLiteTable3, SQLLang,
    HGM.Controls.VirtualTable;

  type
    THistoryFormat = (hfText, hfImage, hfList, hfOther);

    THistoryItem = record
    private
      FID: Integer;
      FFormat: THistoryFormat;
      FDate: TDate;
      FTime: TTime;
      FDesc: string;
      procedure SetDate(const Value: TDate);
      procedure SetDesc(const Value: string);
      procedure SetFormat(const Value: THistoryFormat);
      procedure SetID(const Value: Integer);
      procedure SetTime(const Value: TTime);
    public
      property ID: Integer read FID write SetID;
      property Date: TDate read FDate write SetDate;
      property Time: TTime read FTime write SetTime;
      property Desc: string read FDesc write SetDesc;
      property Format: THistoryFormat read FFormat write SetFormat;
    end;

    THistory = class(TTableData<THistoryItem>)
     const
       tnHistory = 'HISTORY';
       fnID      = 'HI_ID';
       fnFormat  = 'HI_FORMAT';
       fnDate    = 'HI_DATE';
       fnTime    = 'HI_TIME';
       fnDesc    = 'HI_DESC';
       fnData    = 'HI_DATA';
     private
       FDB: TSQLiteDatabase;
     public
       procedure Reload(Date: TDate; DescFilter: string);
       procedure DropTable;
       function Insert(var Item: THistoryItem; Image: TBitmap): Integer; overload;
       function Insert(var Item: THistoryItem; Text: string): Integer; overload;
       function Insert(var Item: THistoryItem; Files: TStringList): Integer; overload;
       constructor Create(AOwner: TTableEx; ADB: TSQLiteDatabase); overload;
       function GetImage(ID: Integer): TBitmap;
       function GetText(ID: Integer): string;
       property DB: TSQLiteDatabase read FDB;
    end;


implementation

{ THistoryItem }

procedure THistoryItem.SetDate(const Value: TDate);
begin
  FDate := Value;
end;

procedure THistoryItem.SetDesc(const Value: string);
begin
  FDesc := Value;
end;

procedure THistoryItem.SetFormat(const Value: THistoryFormat);
begin
  FFormat := Value;
end;

procedure THistoryItem.SetID(const Value: Integer);
begin
  FID := Value;
end;

procedure THistoryItem.SetTime(const Value: TTime);
begin
  FTime := Value;
end;

{ THistory }

constructor THistory.Create(AOwner: TTableEx; ADB: TSQLiteDatabase);
begin
  inherited Create(AOwner);
  FDB := ADB;
  if not FDB.TableExists(tnHistory) then
  begin
    with SQL.CreateTable(tnHistory) do
    begin
      AddField(fnID, ftInteger, True, True);
      AddField(fnDesc, ftString);
      AddField(fnFormat, ftInteger);
      AddField(fnDate, ftDateTime);
      AddField(fnTime, ftDateTime);
      AddField(fnData, ftBlob);
      FDB.ExecSQL(GetSQL);
      EndCreate;
    end;
  end;
end;

procedure THistory.DropTable;
begin
  with SQL.Delete(tnHistory) do
  begin
    FDB.ExecSQL(GetSQL);
    EndCreate;
  end;
  Clear;
end;

function THistory.GetImage(ID: Integer): TBitmap;
var Table: TSQLiteTable;
    Mem: TMemoryStream;
begin
  with SQL.Select(tnHistory) do
  begin
    AddField(fnData);
    WhereFieldEqual(fnID, ID);
    Table := FDB.GetTable(GetSQL);
    if Table.RowCount > 0 then
    begin
      Mem := Table.FieldAsBlob(0);
      Mem.Position := 0;
      Result := TBitmap.Create;
      Result.LoadFromStream(Mem);
    end;
    Table.Free;
    EndCreate;
  end;
end;

function THistory.GetText(ID: Integer): string;
var Table: TSQLiteTable;
    Mem: TStringStream;
begin
  with SQL.Select(tnHistory) do
  begin
    AddField(fnData);
    WhereFieldEqual(fnID, ID);
    Table := FDB.GetTable(GetSQL);
    if Table.RowCount > 0 then
    begin
      Mem := TStringStream.Create;
      Mem.LoadFromStream(Table.FieldAsBlob(0));
      Mem.Position := 0;
      Result := Mem.DataString;
      Mem.Free;
    end;
    Table.Free;
    EndCreate;
  end;
end;

function THistory.Insert(var Item: THistoryItem; Image: TBitmap): Integer;
var Mem: TMemoryStream;
begin
  with SQL.InsertInto(tnHistory) do
  begin
    AddValue(fnDesc, Item.Desc);
    AddValue(fnDate, DateOf(Item.Date));
    AddValue(fnTime, TimeOf(Item.Time));
    AddValue(fnFormat, Ord(hfImage));
    FDB.ExecSQL(GetSQL);
    Item.Format := hfImage;
    Item.ID := FDB.GetLastInsertRowID;
    EndCreate;
  end;
  with SQl.UpdateBlob(tnHistory) do
  begin
    BlobField := fnData;
    WhereFieldEqual(fnID, Item.ID);
    Mem := TMemoryStream.Create;
    Image.SaveToStream(Mem);
    FDB.UpdateBlob(GetSQL, Mem);
    Mem.Free;
    EndCreate;
  end;
  inherited Insert(0, Item);
  Result := 0;
end;

function THistory.Insert(var Item: THistoryItem; Text: string): Integer;
var Mem: TStringStream;
begin
  with SQL.InsertInto(tnHistory) do
  begin
    AddValue(fnDesc, Item.Desc);
    AddValue(fnDate, DateOf(Item.Date));
    AddValue(fnTime, TimeOf(Item.Time));
    AddValue(fnFormat, Ord(hfText));
    FDB.ExecSQL(GetSQL);
    Item.Format := hfText;
    Item.ID := FDB.GetLastInsertRowID;
    EndCreate;
  end;
  with SQl.UpdateBlob(tnHistory) do
  begin
    BlobField := fnData;
    WhereFieldEqual(fnID, Item.ID);
    Mem := TStringStream.Create(Text);
    FDB.UpdateBlob(GetSQL, Mem);
    Mem.Free;
    EndCreate;
  end;
  inherited Insert(0, Item);
  Result := 0;
end;

function THistory.Insert(var Item: THistoryItem; Files: TStringList): Integer;
var Mem: TStringStream;
begin
  with SQL.InsertInto(tnHistory) do
  begin
    AddValue(fnDesc, Item.Desc);
    AddValue(fnDate, DateOf(Item.Date));
    AddValue(fnTime, TimeOf(Item.Time));
    AddValue(fnFormat, Ord(hfList));
    FDB.ExecSQL(GetSQL);
    Item.Format := hfList;
    Item.ID := FDB.GetLastInsertRowID;
    EndCreate;
  end;
  with SQl.UpdateBlob(tnHistory) do
  begin
    BlobField := fnData;
    WhereFieldEqual(fnID, Item.ID);
    Mem := TStringStream.Create(Files.Text);
    FDB.UpdateBlob(GetSQL, Mem);
    Mem.Free;
    EndCreate;
  end;
  inherited Insert(0, Item);
  Result := 0;
end;

procedure THistory.Reload(Date: TDate; DescFilter: string);
var Table: TSQLiteTable;
    Item: THistoryItem;
begin
  BeginUpdate;
  Clear;
  with SQL.Select(tnHistory) do
  begin
    AddField(fnID);
    AddField(fnFormat);
    AddField(fnDate);
    AddField(fnTime);
    AddField(fnDesc);
    WhereFieldEqual(fnDate, DateOf(Date));
    if DescFilter <> '' then WhereFieldLike(fnDesc, '%'+DescFilter+'%');
    OrderBy(fnTime, True);
    Table := FDB.GetTable(GetSQL);
    EndCreate;
    while not Table.EOF do
    begin
      Item.ID := Table.FieldAsInteger(0);
      Item.Format := THistoryFormat(Table.FieldAsInteger(1));
      Item.Date := DateOf(Table.FieldAsDateTime(2));
      Item.Time := TimeOf(Table.FieldAsDateTime(3));
      Item.Desc := Table.FieldAsString(4);
      Add(Item);
      Table.Next;
    end;
    Table.Free;
  end;
  EndUpdate;
end;

end.
