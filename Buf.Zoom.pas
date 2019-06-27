unit Buf.Zoom;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Math, System.Types,
  Vcl.Forms, Vcl.Controls;

type
  TZoomController = class
  private
    FMain: TRect;
    FChild: TRect;
    FOldRect: TRect;
    FOnChange: TNotifyEvent;
    FValue: Integer;
    FCenter: TPoint;
    FOriginalSize: TSize;
    FUpdates: Integer;
    FMoveCenter: Boolean;
    FSaveViewPoint: Boolean;
    FChildMousePos: TPoint;
    FSavedXY: TPoint;
    FCursorUpdate: Boolean;
    FChangeControl: TWinControl;
    procedure SetChild(const Value: TRect);
    procedure SetMain(const Value: TRect);
    procedure SetOnChange(const Value: TNotifyEvent);
    procedure SetValue(const Value: Integer);
    procedure SetOriginalSize(const Value: TSize);
    procedure SetCenter(const Value: TPoint);
    procedure SetCursorUpdate(const Value: Boolean);
    function GetIsMoving: Boolean;
    procedure SetChangeControl(const Value: TWinControl);
    procedure DoChange;
  public
    T:TPoint;
    procedure AroundChange;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure MovingStart;
    procedure Moving;
    procedure MovingEnd;
    constructor Create;
    procedure Reset;
    procedure SaveViewPoint(Value: TPoint);
    property Main: TRect read FMain write SetMain;
    property Child: TRect read FChild write SetChild;
    property OriginalSize: TSize read FOriginalSize write SetOriginalSize;
    property OnChange: TNotifyEvent read FOnChange write SetOnChange;
    property Value: Integer read FValue write SetValue;
    property Center: TPoint read FCenter write SetCenter;
    property CursorUpdate: Boolean read FCursorUpdate write SetCursorUpdate;
    property IsMoving: Boolean read GetIsMoving;
    property ChangeControl: TWinControl read FChangeControl write SetChangeControl;
  end;

implementation

{ TZoom }

procedure TZoomController.AroundChange;
var
  R: TRect;
  W, H, DH, DW, PW, PH: Integer;
  NewRct: TRect;

  function ScaleRect(Src: TRect; Center: TPoint; Scale: Integer): TRect;
  begin
    Result := Src;
    Result.Left := Trunc(Center.X - ((Src.Width * Scale) / 2));
    Result.Top := Trunc(Center.Y - ((Src.Height * Scale) / 2));
    Result.Width := Src.Width * Scale;
    Result.Height := Src.Height * Scale;
  end;

begin
  if FUpdates > 0 then
    Exit;
  R := FMain;
  W := OriginalSize.Width;
  H := OriginalSize.Height;
  if (W <> 0) and (H <> 0) then
  begin
    DH := FMain.Height;
    DW := FMain.Width;
    //
    PW := DW;
    PH := Round(PW * (H / W));

    if PH > DH then
    begin
      PH := DH;
      PW := Round(PH * (W / H));
    end;

    NewRct.Left := DW div 2 - PW div 2;
    NewRct.Top := DH div 2 - PH div 2;
    NewRct.Width := PW;
    NewRct.Height := PH;
    //Сброс центра, если зума нет
    if FValue = 1 then
      FCenter := Point(DW div 2, DH div 2);
    //Установка размеров видео с зумом
    NewRct := ScaleRect(NewRct, FCenter, FValue);
    //Ограничения на передвижение при зуме
    if FValue > 1 then
    begin
      PW := NewRct.Width;
      PH := NewRct.Height;

      NewRct.Left := Min(0, NewRct.Left);
      NewRct.Right := NewRct.Left + PW;

      NewRct.Right := Max(DW, NewRct.Right);
      NewRct.Left := NewRct.Right - PW;

      NewRct.Top := Min(0, NewRct.Top);
      NewRct.Bottom := NewRct.Top + PH;

      NewRct.Bottom := Max(DH, NewRct.Bottom);
      NewRct.Top := NewRct.Bottom - PH;

      FCenter := NewRct.CenterPoint;
    end;

    R := NewRct;
  end;

  if FValue > 1 then
  begin
    if FSaveViewPoint then
    begin
      T := Point(FOldRect.CenterPoint.X - FChildMousePos.X, FOldRect.CenterPoint.Y - FChildMousePos.Y);
      //NewRct.Location :=
      //NewRct.Location := Point(NewRct.Location.X + (FChildMousePos.X), NewRct.Location.Y + (FChildMousePos.Y));
    end;
    //По центру, если меньше
    if R.Width < FMain.Width then
      R.Location := Point(FMain.Width div 2 - R.Width div 2, R.Top);
    if R.Height < FMain.Height then
      R.Location := Point(R.Left, FMain.Height div 2 - R.Height div 2);
  end;

  Child := R;
end;

procedure TZoomController.BeginUpdate;
begin
  Inc(FUpdates);
end;

constructor TZoomController.Create;
begin
  inherited;
  FSavedXY := Point(0, 0);
  FChildMousePos := Point(0, 0);
  FMoveCenter := False;
  FUpdates := 0;
  FCursorUpdate := False;
  FValue := 1;
end;

procedure TZoomController.DoChange;
begin
  if Assigned(FChangeControl) then
  begin
    with Child do
      FChangeControl.SetBounds(Left, Top, Width, Height);
    FChangeControl.Width := FChangeControl.Width - 1;
    FChangeControl.Width := FChangeControl.Width + 1;
  end;

  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TZoomController.EndUpdate;
begin
  Dec(FUpdates);
  if FUpdates < 0 then
    FUpdates := 0;
end;

function TZoomController.GetIsMoving: Boolean;
begin
  Result := FMoveCenter;
end;

procedure TZoomController.Moving;
var
  Offs: TPoint;
begin
  if IsMoving then
  begin
    if FMoveCenter and (Value > 1) then
    begin
      Offs := Center;
      Offs.Offset(Mouse.CursorPos.X - FSavedXY.X, Mouse.CursorPos.Y - FSavedXY.Y);
      FSavedXY := Point(Mouse.CursorPos.X, Mouse.CursorPos.Y);
      Center := Offs;
    end;
  end;
end;

procedure TZoomController.MovingEnd;
begin
  FMoveCenter := False;
  if FCursorUpdate then
    Screen.Cursor := crDefault;
end;

procedure TZoomController.MovingStart;
begin
  if Value > 1 then
  begin
    FMoveCenter := True;
    if FCursorUpdate then
      Screen.Cursor := crSizeAll;
    FSavedXY := Point(Mouse.CursorPos.X, Mouse.CursorPos.Y);
  end;
end;

procedure TZoomController.Reset;
begin
  FValue := 1;
  MovingEnd;
end;

procedure TZoomController.SetChangeControl(const Value: TWinControl);
begin
  FChangeControl := Value;
end;

procedure TZoomController.SetChild(const Value: TRect);
begin
  FChild := Value;
  FOldRect := FChild;
  DoChange;
end;

procedure TZoomController.SetCursorUpdate(const Value: Boolean);
begin
  FCursorUpdate := Value;
end;

procedure TZoomController.SetMain(const Value: TRect);
begin
  FMain := Value;
  AroundChange;
end;

procedure TZoomController.SetOnChange(const Value: TNotifyEvent);
begin
  FOnChange := Value;
end;

procedure TZoomController.SetOriginalSize(const Value: TSize);
begin
  if FOriginalSize = Value then
    Exit;
  FOriginalSize := Value;
  AroundChange;
end;

procedure TZoomController.SetValue(const Value: Integer);
begin
  FValue := Value;
  if FValue <= 0 then
    FValue := 1;
  AroundChange;
  FSaveViewPoint := False;
end;

procedure TZoomController.SaveViewPoint(Value: TPoint);
begin
  FSaveViewPoint := True;
  FOldRect := Child;
  FChildMousePos := Value;
end;

procedure TZoomController.SetCenter(const Value: TPoint);
begin
  if FCenter = Value then
    Exit;
  FCenter := Value;
  AroundChange;
end;

end.

