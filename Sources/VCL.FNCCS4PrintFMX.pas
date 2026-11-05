{ : Printing from an FMX application - CS-07 of
  docs\masterplanner-changes.md.

  The printer is the one FMX has selected - FMX.Printer's ActivePrinter,
  which is what an FMX print dialog sets - and the printing itself is
  VCL.FNCCS4GDI's: the sheet drawn through GDI on that printer's own
  device context, the same drawing as the metafile and as a VCL print.

  WHY NOT THE FMX PRINTER CANVAS

  An FMX canvas is a different renderer with its own idea of units -
  FNC's printer wrapper scales it by DPI/72 on Windows to make it agree
  with itself - and one more renderer is one more way for paper to
  differ from the preview. GDI on the printer's DC is what the VCL has
  always printed with, and it lets each sheet set its own orientation
  and paper, which neither printer class can do.

  What is not taken from FMX: copies, collation and the other settings
  an FMX print dialog may have changed on its own printer object. The
  printer's own defaults apply, with each sheet's orientation and paper.

  OTHER PLATFORMS

  Windows only. Elsewhere the calls raise ECADPageError: save a PDF
  (VCL.FNCCS4PDF) and print that. }
unit VCL.FNCCS4PrintFMX;

{$I VCL.FNCCADSys.inc}

{$IFNDEF CADSYS_FMX}
{$MESSAGE Fatal 'VCL.FNCCS4PrintFMX is FMX-only. A VCL application prints with VCL.FNCCS4ExportVCL or VCL.FNCCS4GDI.'}
{$ENDIF}

interface

uses
  System.SysUtils, VCL.FNCCS4BaseTypes, VCL.FNCCS4Paper, VCL.FNCCS4Print,
  VCL.FNCCADSys4;

{ : The name of FMX's active printer, or '' when there is none. }
function CADFMXPrinterName: String;

{ : The active printer's page device: its resolution and where the
  paper's corner is relative to the printable area. }
function CADFMXPrinterPageDevice: TCADPageDevice;

{ : Prints ASheets, AFirstSheet to ALastSheet (-1: to the end), one to a
  page, on FMX's active printer. ATitle names the job. }
procedure CADPrintSheetsFMX(const ACAD: TFNCCADCmp2D;
  const ASheets: TCADSheets; const ATitle: String = '';
  const AFirstSheet: Integer = 0; const ALastSheet: Integer = -1);

{ : Prints ASheet tiled onto ATiling's paper at full size, one page per
  tile with its marks, on FMX's active printer. }
procedure CADPrintSheetTiledFMX(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const ATiling: TCADSheetTiling;
  const ATitle: String = '');

{ : Prints ASetup's pages of the model on FMX's active printer. }
procedure CADPrintPagesFMX(const ACAD: TFNCCADCmp2D;
  const ASetup: TCADPageSetup; const ATitle: String = '';
  const AFirstPage: Integer = 0; const ALastPage: Integer = -1);

implementation

uses
{$IFDEF MSWINDOWS}
  VCL.FNCCS4GDI,
{$ENDIF}
  FMX.Printer;

function CADFMXPrinterName: String;
var
  TmpPrinter: TPrinter;
begin
  Result := '';
  TmpPrinter := Printer;
  if (TmpPrinter = nil) or (TmpPrinter.Count = 0) or
    (TmpPrinter.ActivePrinter = nil) then
    Exit;
  { Device is the name the spooler knows the printer by; Title is for
    showing. }
  Result := TmpPrinter.ActivePrinter.Device;
  if Result = '' then
    Result := TmpPrinter.ActivePrinter.Title;
end;

{$IFNDEF MSWINDOWS}
procedure NotHere;
begin
  Raise ECADPageError.Create('Printing from FMX is implemented on Windows ' +
    'only - save a PDF and print that');
end;
{$ENDIF}

function CADFMXPrinterPageDevice: TCADPageDevice;
begin
{$IFDEF MSWINDOWS}
  Result := CADPrinterPageDeviceWin(CADFMXPrinterName);
{$ELSE}
  Result := TCADPageDevice.FromDPI(72, 72);
  if (Printer <> nil) and (Printer.Count > 0) and
    (Printer.ActivePrinter <> nil) and
    (Printer.ActivePrinter.ActiveDPI.X > 0) then
    Result := TCADPageDevice.FromDPI(Printer.ActivePrinter.ActiveDPI.X,
      Printer.ActivePrinter.ActiveDPI.Y);
{$ENDIF}
end;

procedure CADPrintSheetsFMX(const ACAD: TFNCCADCmp2D;
  const ASheets: TCADSheets; const ATitle: String;
  const AFirstSheet: Integer; const ALastSheet: Integer);
begin
{$IFDEF MSWINDOWS}
  CADPrintSheetsWin(ACAD, ASheets, CADFMXPrinterName, ATitle, AFirstSheet,
    ALastSheet);
{$ELSE}
  NotHere;
{$ENDIF}
end;

procedure CADPrintSheetTiledFMX(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const ATiling: TCADSheetTiling;
  const ATitle: String);
begin
{$IFDEF MSWINDOWS}
  CADPrintSheetTiledWin(ACAD, ASheet, ATiling, CADFMXPrinterName, ATitle);
{$ELSE}
  NotHere;
{$ENDIF}
end;

procedure CADPrintPagesFMX(const ACAD: TFNCCADCmp2D;
  const ASetup: TCADPageSetup; const ATitle: String;
  const AFirstPage: Integer; const ALastPage: Integer);
begin
{$IFDEF MSWINDOWS}
  CADPrintPagesWin(ACAD, ASetup, CADFMXPrinterName, ATitle, AFirstPage,
    ALastPage);
{$ELSE}
  NotHere;
{$ENDIF}
end;

end.
