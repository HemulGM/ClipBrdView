unit Buf.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, HGM.Button, Vcl.ExtCtrls, ClipBrd, Vcl.Grids, System.DateUtils,
  HGM.Controls.VirtualTable, HGM.Controls.PanelExt, Buf.History, SQLiteTable3,
  System.ImageList, Vcl.ImgList, Vcl.ComCtrls, Vcl.WinXCalendars, HGM.Popup;

const
  WM_DOREADCLIPBOARD = WM_USER + $1101;

type
  TFromMain = class(TForm)
    PanelTools: TPanel;
    ButtonFlatRefresh: TButtonFlat;
    PanelClient: TPanel;
    PanelInfo: TPanel;
    LabelBuf: TLabel;
    PanelStream: TPanel;
    MemoStream: TMemo;
    ScrollBarStream: TScrollBar;
    PanelText: TPanel;
    MemoText: TMemo;
    PanelHistory: TPanel;
    TableExHistory: TTableEx;
    PanelImage: TDrawPanel;
    Image: TImage;
    PanelHistoryTools: TPanel;
    ButtonFlatDrop: TButtonFlat;
    ImageList24: TImageList;
    PanelFiles: TPanel;
    ListViewFiles: TListView;
    Shape1: TShape;
    Panel1: TPanel;
    EditFilter: TEdit;
    ButtonFlatSearch: TButtonFlat;
    ButtonFlatSearchClear: TButtonFlat;
    ButtonFlatDate: TButtonFlat;
    CalendarView: TCalendarView;
    procedure ButtonFlatRefreshClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PanelImagePaint(Sender: TObject);
    procedure TableExHistoryDrawCellData(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure TableExHistoryDblClick(Sender: TObject);
    procedure ButtonFlatDropClick(Sender: TObject);
    procedure ButtonFlatSearchClick(Sender: TObject);
    procedure ButtonFlatSearchClearClick(Sender: TObject);
    procedure ButtonFlatDateClick(Sender: TObject);
    procedure CalendarViewChange(Sender: TObject);
  private
    FDB: TSQLiteDatabase;
    FHistory: THistory;
    FIsHistory: Boolean;
    FDescFilter: string;
    FHistoryDate: TDate;
    FCalendarPopup: TFormPopup;
    FCalHand: Boolean;
    procedure ClosePopup;
    procedure ReadBuffer(Save: Boolean);
    procedure ReadBufAsImage(Save: Boolean);
    procedure ReadBufAsText(Save: Boolean);
    procedure WMClipboardUpdate(var Msg: TMessage); message WM_CLIPBOARDUPDATE;
    procedure WMDoReadClipboard(var Msg: TMessage); message WM_DOREADCLIPBOARD;
    procedure ReadBufAsDropFiles(Save: Boolean);
    procedure SetFileList(List: TStringList);
    procedure SetImage(BMP: TBitmap);
    procedure SetText(Text: string);
    procedure SetIsHistory(const Value: Boolean);
  public
    procedure RefreshHistory;
    property IsHistory: Boolean read FIsHistory write SetIsHistory;
  end;

var
  FromMain: TFromMain;

implementation

uses ShellApi;


{$R *.dfm}

procedure TFromMain.ButtonFlatSearchClearClick(Sender: TObject);
begin
  FHistoryDate := Now;
  EditFilter.Clear;
end;

procedure TFromMain.ButtonFlatSearchClick(Sender: TObject);
begin
  FDescFilter := EditFilter.Text;
  RefreshHistory;
end;

procedure TFromMain.CalendarViewChange(Sender: TObject);
begin
  if FCalHand then Exit;

  FCalendarPopup.Close;
  if CalendarView.Date <> FHistoryDate then
  begin
    FHistoryDate := CalendarView.Date;
    RefreshHistory;
  end;
end;

procedure TFromMain.ClosePopup;
begin
  FCalendarPopup := nil;
end;

procedure TFromMain.ButtonFlatDateClick(Sender: TObject);
var Pt: TPoint;
begin
  Pt := ButtonFlatDate.ClientToScreen(Point(0, ButtonFlatDate.Height));
  FCalHand := True;
  CalendarView.Date := FHistoryDate;
  FCalHand := False;
  FCalendarPopup := TFormPopup.CreatePopup(Self, CalendarView, ClosePopup, Pt.X, Pt.Y, False, True);
end;

procedure TFromMain.ButtonFlatDropClick(Sender: TObject);
begin
  FHistory.DropTable;
end;

procedure TFromMain.ButtonFlatRefreshClick(Sender: TObject);
begin
  ReadBuffer(False);
end;

procedure TFromMain.FormCreate(Sender: TObject);
begin
  IsHistory := True;
  FHistoryDate := Now;
  FDescFilter := '';
  FDB := TSQLiteDatabase.Create('history.db');
  FHistory := THistory.Create(TableExHistory, FDB);
  AddClipboardFormatListener(Handle);
  RefreshHistory;
  ReadBuffer(False);
end;

procedure TFromMain.FormDestroy(Sender: TObject);
begin
  RemoveClipboardFormatListener(Handle);
  ListViewFiles.SmallImages.Free;
  FHistory.Clear;
  FHistory.Free;
  FDB.Free;
end;

procedure TFromMain.PanelImagePaint(Sender: TObject);
const
  Sz: Integer = 15;
var
  i, j: Integer;
begin
  with PanelImage.Canvas do
  begin
    Brush.Color := $00FDFDFD;
    FillRect(PanelImage.ClientRect);
    Brush.Color := $00CCCACA;
    for i := 0 to PanelImage.Width div Sz do
      for j := 0 to PanelImage.Height div Sz do
      begin
        if ((j mod 2 = 0) and (i mod 2 = 0)) or ((j mod 2 = 1) and (i mod 2 = 1)) then
          FillRect(Rect(i * Sz, j * Sz, i * Sz + Sz, j * Sz + Sz));
      end;
  end;
end;

procedure TFromMain.ReadBufAsDropFiles(Save: Boolean);
var
  CBContext: THandle;
  buffer: array[0..MAX_PATH] of Char;
  i, numFiles: Integer;
  Item: THistoryItem;
  List: TStringList;
begin
  List := TStringList.Create;
  try
    Clipboard.Open;
    CBContext := Clipboard.GetAsHandle(CF_HDROP);
    if CBContext <> 0 then
    begin
      numFiles := DragQueryFile(CBContext, $FFFFFFFF, nil, 0);
      for i := 0 to numFiles - 1 do
      begin
        buffer[0] := #0;
        DragQueryFile(CBContext, i, buffer, SizeOf(buffer));
        List.Add(StrPas(buffer));
      end;
    end;
    IsHistory := False;
    SetFileList(List);
    if Save then
    begin
      Item.Date := DateOf(Now);
      Item.Time := TimeOf(Now);
      Item.Desc := '<Список файлов>';
      FHistory.Insert(Item, List);
    end;
  finally
    List.Free;
    Clipboard.Close;
  end;
end;

procedure TFromMain.ReadBufAsImage(Save: Boolean);
var
  BMP: TBitmap;
  Item: THistoryItem;
begin
  BMP := TBitmap.Create;
  BMP.PixelFormat := pf32bit;
  BMP.Assign(Clipboard);
  BMP.SaveToFile('F:\test.bmp');
  IsHistory := False;
  SetImage(BMP);
  if Save then
  begin
    Item.Date := DateOf(Now);
    Item.Time := TimeOf(Now);
    Item.Desc := '<Изображение>';
    FHistory.Insert(Item, BMP);
  end;
  BMP.Free;
end;

procedure TFromMain.ReadBufAsText(Save: Boolean);
var
  Item: THistoryItem;
begin
  IsHistory := False;
  SetText(Clipboard.AsText);
  if Save then
  begin
    Item.Date := DateOf(Now);
    Item.Time := TimeOf(Now);
    if MemoText.Lines.Count > 0 then
      Item.Desc := Copy(MemoText.Lines[0], 1, 40);
    FHistory.Insert(Item, MemoText.Text);
  end;
end;

procedure TFromMain.ReadBuffer(Save: Boolean);
begin
  if Clipboard.HasFormat(CF_BITMAP) then
  begin
    ReadBufAsImage(Save);
  end
  else if Clipboard.HasFormat(CF_TEXT) then
  begin
    ReadBufAsText(Save);
  end
  else if Clipboard.HasFormat(CF_HDROP) then
  begin
    ReadBufAsDropFiles(Save);
  end;
end;

procedure TFromMain.RefreshHistory;
begin
  FHistory.Reload(FHistoryDate, FDescFilter);
end;

function GetFileIcon(FileName: string; IL: TCustomImageList): Integer;
var
  Icon: TIcon;
  Icon32, IcEx: HICON;
  i: word;
  FFile: PChar;
begin
  Result := -1;
  try
    FFile := PChar(Copy(FileName, 1, Length(FileName)));
    IcEx := ExtractAssociatedIcon(0, FFile, i);
    if IcEx > 0 then
    begin
      Icon := TIcon.Create;
      if Integer(ExtractIconEx(FFile, i, Icon32, IcEx, 1)) > 0 then
        Icon.Handle := IcEx;
      Result := IL.AddIcon(Icon);
      Icon.Free;
    end;
  except
    on E: Exception do
      Exit;
  end;
end;

procedure TFromMain.SetFileList(List: TStringList);
var
  i: Integer;
  Icon: TIcon;
  ListItem: TListItem;
  FileInfo: SHFILEINFO;
  Rs: Integer;
begin
  Icon := TIcon.Create;
  ListViewFiles.Items.BeginUpdate;
  ListViewFiles.Items.Clear;
  try
    if not Assigned(ListViewFiles.SmallImages) then
    begin
      ListViewFiles.SmallImages := TImageList.CreateSize(16, 16);
      ListViewFiles.SmallImages.ColorDepth := cd32Bit;
    end
    else
      ListViewFiles.SmallImages.Clear;

    for i := 0 to List.Count - 1 do
      with ListViewFiles.Items do
      begin
        ListItem := Add;

        if SHGetFileInfo(PChar(List[i]), 0, FileInfo, SizeOf(FileInfo), SHGFI_DISPLAYNAME) = 1 then
        begin
          ListItem.Caption := FileInfo.szDisplayName;
          SHGetFileInfo(PChar(List[i]), 0, FileInfo, SizeOf(FileInfo), SHGFI_ICON or SHGFI_SMALLICON);
          Icon.Handle := FileInfo.hIcon;
          ListItem.ImageIndex := ListViewFiles.SmallImages.AddIcon(Icon);
          ListItem.SubItems.Add(List[i]);
          DestroyIcon(FileInfo.hIcon);
        end
        else
        begin
          ListItem.Caption := ExtractFileName(List[i]);
          ListItem.ImageIndex := GetFileIcon(List[i], ListViewFiles.SmallImages);
          ListItem.SubItems.Add(List[i]);
        end;
      end;
  finally
    Icon.Free;
    ListViewFiles.Items.EndUpdate;
  end;
  PanelFiles.BringToFront;
  LabelBuf.Caption := 'Список файлов';
end;

procedure TFromMain.SetImage(BMP: TBitmap);
begin
  Image.Picture.Assign(BMP);
  PanelImage.BringToFront;
  LabelBuf.Caption := 'Точечный рисунок';
end;

procedure TFromMain.SetIsHistory(const Value: Boolean);
begin
  FIsHistory := Value;
end;

procedure TFromMain.SetText(Text: string);
begin
  MemoText.Text := Text;
  PanelText.BringToFront;
  LabelBuf.Caption := 'Текстовые данные';
end;

procedure TFromMain.TableExHistoryDblClick(Sender: TObject);
var BMP: TBitmap;
    Str: string;
    List: TStringList;
begin
  if not IndexInList(TableExHistory.ItemIndex, FHistory.Count) then Exit;
  case FHistory[TableExHistory.ItemIndex].Format of
    hfImage:
      begin
        BMP := FHistory.GetImage(FHistory[TableExHistory.ItemIndex].ID);
        IsHistory := True;
        SetImage(BMP);
        BMP.Free;
      end;
    hfText:
      begin
        Str := FHistory.GetText(FHistory[TableExHistory.ItemIndex].ID);
        IsHistory := True;
        SetText(Str);
      end;
    hfList:
      begin
        Str := FHistory.GetText(FHistory[TableExHistory.ItemIndex].ID);
        List := TStringList.Create;
        List.Text := Str;
        IsHistory := True;
        SetFileList(List);
        List.Free;
      end;
  end;
end;

procedure TFromMain.TableExHistoryDrawCellData(Sender: TObject; ACol,
  ARow: Integer; Rect: TRect; State: TGridDrawState);
var Str: string;
begin
  with TableExHistory.Canvas do
  begin
    if not IndexInList(ARow, FHistory.Count) then Exit;
    Str := FHistory[ARow].Desc;
    Font.Size := 10;
    Font.Color := $00454545;
    TextOut(10, Rect.Top + 5, Str);
    Str := FormatDateTime('c', DateOf(FHistory[ARow].Date) + TimeOf(FHistory[ARow].Time));
    Font.Size := 8;
    Font.Color := $005D5D5D;
    TextOut(Rect.Right - (TextWidth(Str) + 10), Rect.Top + 25, Str);
  end;
end;

procedure TFromMain.WMClipboardUpdate(var Msg: TMessage);
begin
  SendMessage(Handle, WM_DOREADCLIPBOARD, 0, 0);
end;

procedure TFromMain.WMDoReadClipboard(var Msg: TMessage);
var Success: Boolean;
    RetryCount: Integer;
begin
  while not Success do
  try
    ReadBuffer(True);
    Success := True;
  except
    on Exception do
    begin
      Inc(RetryCount);
      if RetryCount < 3 then
        Sleep(RetryCount * 100);
    end;
  end;
end;

end.

