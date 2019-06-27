program Buf;

uses
  Vcl.Forms,
  Buf.Main in 'Buf.Main.pas' {FromMain},
  Buf.Zoom in 'Buf.Zoom.pas',
  SQLite3 in '..\SQLite\SQLite3.pas',
  SQLiteTable3 in '..\SQLite\SQLiteTable3.pas',
  SQLLang in '..\SQLite\SQLLang.pas',
  Buf.History in 'Buf.History.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := True;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFromMain, FromMain);
  Application.Run;
end.
