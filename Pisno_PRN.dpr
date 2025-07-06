program Pisno_PRN;

uses
  Forms,
  pisno in 'pisno.pas' {Main};

{$R *.res}

begin
  Regis:='\Software\Pisno\prn';
  Application.Initialize;
  Application.Title := 'Pisno PRN';
  Application.CreateForm(TMain, Main);
  Application.Run;
end.
