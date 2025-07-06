unit pisno;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Registry, ComCtrls,ShellApi, ExtCtrls;


type
  TMain = class(TForm)
    cmbPrinters: TComboBox;
    Button1: TButton;
    Memo1: TMemo;
    StatusBar1: TStatusBar;
    Shape1: TShape;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    procedure MainCreate(Sender: TObject);
    procedure cmbPrintersChange(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure enviarArch(nombre : string);
    procedure click(Sender, Target: TObject; X, Y: Integer);
  private
    { Private declarations }
     procedure WMDROPFILES(var msg : TWMDropFiles) ; message WM_DROPFILES;
  public
    { Public declarations }
  end;

var
  Main: TMain;
  Regis: String;

implementation

{$R *.dfm}

uses Printers, WinSpool;


//Funciones para el registro
function GetRegistryData(RootKey: HKEY; Key, Value: string): variant;
var
  Reg: TRegistry;
  RegDataType: TRegDataType;
  DataSize, Len: integer;
  s: string;
label cantread;
begin
  Reg := nil;
  try
    Reg := TRegistry.Create(KEY_QUERY_VALUE);
    Reg.RootKey := RootKey;
    if Reg.OpenKeyReadOnly(Key) then begin
      try
        RegDataType := Reg.GetDataType(Value);
        if (RegDataType = rdString) or
           (RegDataType = rdExpandString) then
          Result := Reg.ReadString(Value)
        else if RegDataType = rdInteger then
          Result := Reg.ReadInteger(Value)
        else if RegDataType = rdBinary then begin
          DataSize := Reg.GetDataSize(Value);
          if DataSize = -1 then goto cantread;
          SetLength(s, DataSize);
          Len := Reg.ReadBinaryData(Value, PChar(s)^, DataSize);
          if Len <> DataSize then goto cantread;
          Result := s;
        end else
cantread:
          Result := '';
      except
        s := '';
        Reg.CloseKey;
        Result := '';
      end;
      Reg.CloseKey;
    end else
      Result := '';
  except
    Reg.Free;
    raise;
  end;
  Reg.Free;
end;

procedure SetRegistryData(RootKey: HKEY; Key, Value: string;
  RegDataType: TRegDataType; Data: variant);
var
  Reg: TRegistry;
  s: string;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := RootKey;
    if Reg.OpenKey(Key, True) then begin
      try
        if RegDataType = rdUnknown then
          RegDataType := Reg.GetDataType(Value);
        if RegDataType = rdString then
          Reg.WriteString(Value, Data)
        else if RegDataType = rdExpandString then
          Reg.WriteExpandString(Value, Data)
        else if RegDataType = rdInteger then
          Reg.WriteInteger(Value, Data)
        else if RegDataType = rdBinary then begin
          s := Data;
          Reg.WriteBinaryData(Value, PChar(s)^, Length(s));
        end else
          raise Exception.Create(SysErrorMessage(ERROR_CANTWRITE));
      except
        Reg.CloseKey;
        raise;
      end;
      Reg.CloseKey;
    end else
      raise Exception.Create(SysErrorMessage(GetLastError));
  finally
    Reg.Free;
  end;
end;
//fin funciones de registro


function RawToWindows(Str: String): String;
var
  i: Integer;
begin
  Result:= '<';
  while Length(Str) > 0 do
  begin
    if Copy(Str, 1, 1) = '\' then
    begin
      if Uppercase(Copy(Str, 2, 1)) = 'X' then
        Str[2]:= '$';
      if not TryStrToInt(Copy(Str, 2, 3),i) then
        Continue;
      Delete(Str, 1, 3);
    end else i:= Byte(Str[1]);
    Delete(Str,1,1);
    Result:= Result + IntToHex(i,2);
  end;
  Result:= Result + '>';
end;

function WriteRawDataToPrinter(PrinterName: String; Str: String): Boolean;
var
  PrinterHandle: THandle;
  DocInfo: TDocInfo1;
  i: Integer;
  B: Byte;
  Escritos: DWORD;
begin
  Result:= FALSE;
  if OpenPrinter(PChar(PrinterName), PrinterHandle, nil) then
  try
    FillChar(DocInfo,Sizeof(DocInfo),#0);
    with DocInfo do
    begin
      pDocName:= PChar('Printer Test');
      pOutputFile:= nil;
      pDataType:= 'RAW';
    end;
    if StartDocPrinter(PrinterHandle, 1, @DocInfo) <> 0 then
    try
      if StartPagePrinter(PrinterHandle) then
      try
        while Length(Str) > 0 do
        begin
          if Copy(Str, 1, 1) = '\' then
          begin
            if Uppercase(Copy(Str, 2, 1)) = 'X' then
              Str[2]:= '$';
            if not TryStrToInt(Copy(Str, 2, 3),i) then
              Exit;
            B:= Byte(i);
            Delete(Str, 1, 3);
          end else B:= Byte(Str[1]);
          B:= Byte(Str[1]);
          Delete(Str,1,1);
          WritePrinter(PrinterHandle, @B, 1, Escritos);
        end;
        Result:= TRUE;
      finally
        EndPagePrinter(PrinterHandle);
      end;
    finally
      EndDocPrinter(PrinterHandle);
    end;
  finally
    ClosePrinter(PrinterHandle);
  end;
end;

  procedure TMain.MainCreate(Sender: TObject);
  var
    s: string;
    I: Integer;
    f : TextFile;
    lineaactual : string;
  begin
    DragAcceptFiles(Handle,True);
    statusBar1.SimpleText:='Pisno PRN';
    memo1.Clear;
    s:=GetRegistryData(HKEY_CURRENT_USER, Regis, 'Printer');
    cmbPrinters.Items.Assign(Printer.Printers);
    if Length(s)>0 then
      begin
        I := cmbPrinters.Items.IndexOf(s);
        if I <> -1 then
          cmbPrinters.ItemIndex := I;
    end;
    if ParamCount > 0 then
      begin
        Application.ShowMainForm := False;
        if FileExists(ParamStr(1)) then
          begin
             enviarArch(ParamStr(1));
             Application.Terminate;
          end;
      end;
  end;

  procedure TMain.enviarArch(nombre : string);
  begin
    if cmbPrinters.Text<>'' then
      begin
      statusBar1.SimpleText:='Enviando '+nombre;
      Memo1.Lines.LoadFromFile(nombre);
      WriteRawDataToPrinter(cmbPrinters.Items[cmbPrinters.ItemIndex],Memo1.Text);
      statusBar1.SimpleText:='Enviado '+nombre;
      end else
      begin
        statusBar1.SimpleText:='Seleccione una impresora';
        showMessage('Debe primero seleccionar una impresora');
      end;
  end;

  procedure TMain.cmbPrintersChange(Sender: TObject);
  begin
    SetRegistryData(HKEY_CURRENT_USER,Regis,'Printer', rdString, cmbPrinters.Text);
  end;

  procedure TMain.WMDROPFILES(var msg: TWMDropFiles) ;
 const
   MAXFILENAME = 255;
 var
   cnt, fileCount : integer;
   fileName : array [0..MAXFILENAME] of char;
 begin
   fileCount := DragQueryFile(msg.Drop, $FFFFFFFF, fileName, MAXFILENAME) ;

   for cnt := 0 to -1 + fileCount do
   begin
     DragQueryFile(msg.Drop, cnt, fileName, MAXFILENAME) ;

     enviarArch(fileName);
   end;

   DragFinish(msg.Drop) ;
 end;


  procedure TMain.Button1Click(Sender: TObject);
   var
     s : string;
   begin
     s:='Funciona!';
     if cmbPrinters.Text<>'' then
     begin
       statusBar1.SimpleText:='Enviando prueba...';
       WriteRawDataToPrinter(cmbPrinters.Items[cmbPrinters.ItemIndex],s);
       statusBar1.SimpleText:='Envio realizado';
     end else showMessage('Debe primero seleccionar una impresora');
   end;

procedure TMain.click(Sender, Target: TObject; X, Y: Integer);
var
  openDialog : TOpenDialog;
begin
  openDialog := TOpenDialog.Create(self);
  openDialog.Filter := 'Archivos de texto|*.txt|Archivos prn|*.prn';
  if OpenDialog.Execute then
    if FileExists(OpenDialog.FileName) then
      begin
      enviarArch(OpenDialog.FileName);
      Memo1.Lines.LoadFromFile(OpenDialog.FileName);
    end else
      raise Exception.Create('Archivo no existe.');
end;

end.
