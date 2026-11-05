{: VCL export helpers for CADSys.

   Everything here puts a drawing onto something that only exists on the
   VCL: a <I=TCanvas>, a printer, the clipboard. The viewport itself no
   longer knows about any of those - it copies onto a
   <See Class=TDecorativeCanvas> and calibrates from a millimetres-per-pixel
   figure - which is what lets VCL.FNCCADSys4 compile for FMX and LCL as well.

   These are plain routines rather than methods so that the unit is purely
   additive: add it to your uses clause and the old calls keep their shape.

     CADCopyToCanvas(Viewport, Printer.Canvas, cmAspect, cvExtension, 1, 1);
     CADCopyToClipboard(Viewport, Clipboard);

   Nothing in the library uses this unit, so a project that does not need
   it does not link it.
}
unit VCL.FNCCS4ExportVCL;

{$I VCL.FNCCADSys.inc}

{$IFNDEF CADSYS_VCL}
{$MESSAGE Fatal 'VCL.FNCCS4ExportVCL is VCL-only (the printing and clipboard helpers). Remove it from the FMX or LCL package rather than compiling it there.'}
{$ENDIF}

interface

uses
  WinAPI.Windows, System.Types, System.UITypes, System.Classes,
  Vcl.Graphics, Vcl.ClipBrd, Vcl.Printers,
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4GraphicsVCL, VCL.FNCCADSys4,
  VCL.FNCCS4Print;

{: The size of one pixel of <I=Cnv>, in millimetres. It is what
   <See Method=TFNCCADViewport@CalibrateMM> wants, and it is the one thing
   about a canvas the viewport cannot work out for itself. }
procedure CADCanvasMMPerPixel(const Cnv: TCanvas;
  out AMMPerPixelX, AMMPerPixelY: TRealType);

{: Scales the viewport so that one drawing unit comes out at the given
   scale on <I=Cnv>. The screen version is CADCalibrate. }
procedure CADCalibrateToCanvas(const V: TFNCCADViewport; const Cnv: TCanvas;
  const XScale, YScale: TRealType);

{: The same, against the viewport's own screen surface. }
procedure CADCalibrate(const V: TFNCCADViewport;
  const XScale, YScale: TRealType);

{: Draws <I=CADRect> of the drawing onto <I=CanvasRect> of <I=Cnv>. }
procedure CADCopyRectToCanvas(const V: TFNCCADViewport; CADRect: TRect2D;
  const CanvasRect: TRect; const Cnv: TCanvas; const Mode: TCanvasCopyMode);

{: Draws the whole view onto <I=Cnv>. <I=View> says what to fit: the
   current view, the drawing's extension, or the given scale. }
procedure CADCopyToCanvas(const V: TFNCCADViewport; const Cnv: TCanvas;
  const Mode: TCanvasCopyMode; const View: TCanvasCopyView;
  const XScale, YScale: TRealType);

{: Puts the viewport's off-screen buffer on the clipboard. }
procedure CADCopyToClipboard(const V: TFNCCADViewport; const Clp: TClipboard);

{: The page device for a printer: its real resolution, and where the
   sheet's corner is relative to the canvas.

   A printer canvas starts at the printable area, not at the paper, so
   the sheet begins above and to the left of pixel zero - which is why
   the offsets come back negative. Get them wrong and everything prints
   a few millimetres off, consistently, which reads as a margin bug.

   Valid while the printer has a device context: between BeginDoc and
   EndDoc for certain. }
function CADPrinterPageDevice(const APrinter: TPrinter): TCADPageDevice;

{: Prints ASetup's pages of ACAD.

   The whole print path, and it is short on purpose: the page model
   works out what goes on each sheet and CADDrawPage draws it. The only
   thing this adds is the printer.

   ALastPage of -1 means "to the end". The printer's orientation is set
   from the setup, because a landscape page setup sent to a portrait
   printer is simply wrong and there is nothing to be gained by letting
   the two disagree. }
procedure CADPrintPages(const ACAD: TFNCCADCmp2D; const ASetup: TCADPageSetup;
  const APrinter: TPrinter; const AFirstPage: Integer = 0;
  const ALastPage: Integer = -1);

{: Prints sheets - paper space - one sheet to a page.

   The same shape as CADPrintPages, with CADDrawSheet in place of
   CADDrawPage, because a sheet needs no scaling decisions: it is
   drawn at 1:1 and the scales live in its viewports.

   ALastSheet of -1 means "to the end".

   ONE LIMITATION, and it is Vcl.Printers': the orientation belongs to
   the document, not to the page, so it is taken from the first sheet
   printed. A run of sheets that disagree about orientation has to be
   printed as separate documents - or exported to PDF, where each page
   carries its own size. }
procedure CADPrintSheets(const ACAD: TFNCCADCmp2D; const ASheets: TCADSheets;
  const APrinter: TPrinter; const AFirstSheet: Integer = 0;
  const ALastSheet: Integer = -1);

{ : Prints ASheet tiled onto ATiling's paper at full size, one page per
  tile with its marks. The orientation is ATiling's; the paper is whatever
  APrinter has been set to, which has to agree with ATiling's. }
procedure CADPrintSheetTiled(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const ATiling: TCADSheetTiling;
  const APrinter: TPrinter);

implementation

{ : The millimetres-per-pixel of a device context. The one place that
  actually asks GDI, so both entry points below give the same answer. }
procedure DCMMPerPixel(const DC: HDC;
  out AMMPerPixelX, AMMPerPixelY: TRealType);
var
  TmpRes: Integer;
begin
  AMMPerPixelX := 0;
  AMMPerPixelY := 0;
  if DC = 0 then
    Exit;
  TmpRes := GetDeviceCaps(DC, HORZRES);
  if TmpRes <> 0 then
    AMMPerPixelX := GetDeviceCaps(DC, HORZSIZE) / TmpRes;
  TmpRes := GetDeviceCaps(DC, VERTRES);
  if TmpRes <> 0 then
    AMMPerPixelY := GetDeviceCaps(DC, VERTSIZE) / TmpRes;
end;

procedure CADCanvasMMPerPixel(const Cnv: TCanvas;
  out AMMPerPixelX, AMMPerPixelY: TRealType);
begin
  AMMPerPixelX := 0;
  AMMPerPixelY := 0;
  if Cnv = nil then
    Exit;
  DCMMPerPixel(Cnv.Handle, AMMPerPixelX, AMMPerPixelY);
end;

procedure CADCalibrateToCanvas(const V: TFNCCADViewport; const Cnv: TCanvas;
  const XScale, YScale: TRealType);
var
  TmpX, TmpY: TRealType;
begin
  if V = nil then
    Exit;
  CADCanvasMMPerPixel(Cnv, TmpX, TmpY);
  V.CalibrateMM(TmpX, TmpY, XScale, YScale);
end;

procedure CADCalibrate(const V: TFNCCADViewport;
  const XScale, YScale: TRealType);
var
  TmpDC: HDC;
  TmpX, TmpY: TRealType;
begin
  if V = nil then
    Exit;
  { The screen's own device context, not the viewport's canvas.
    TCustomControl.Canvas is protected, so this unit cannot reach it -
    and it does not need to: a control's canvas reports the metrics of
    the screen it sits on, which is exactly what a screen DC gives. }
  TmpDC := GetDC(0);
  try
    DCMMPerPixel(TmpDC, TmpX, TmpY);
  finally
    ReleaseDC(0, TmpDC);
  end;
  V.CalibrateMM(TmpX, TmpY, XScale, YScale);
end;

procedure CADCopyRectToCanvas(const V: TFNCCADViewport; CADRect: TRect2D;
  const CanvasRect: TRect; const Cnv: TCanvas; const Mode: TCanvasCopyMode);
var
  TmpCanvas: TDecorativeCanvas;
begin
  if (V = nil) or (Cnv = nil) then
    Exit;
  TmpCanvas := TDecorativeCanvas.Create(Cnv);
  try
    V.CopyRectToCanvas(CADRect, CanvasRect, TmpCanvas, Mode);
  finally
    TmpCanvas.Free;
  end;
end;

procedure CADCopyToCanvas(const V: TFNCCADViewport; const Cnv: TCanvas;
  const Mode: TCanvasCopyMode; const View: TCanvasCopyView;
  const XScale, YScale: TRealType);
var
  TmpCanvas: TDecorativeCanvas;
  TmpX, TmpY: TRealType;
begin
  if (V = nil) or (Cnv = nil) then
    Exit;
  CADCanvasMMPerPixel(Cnv, TmpX, TmpY);
  TmpCanvas := TDecorativeCanvas.Create(Cnv);
  try
    V.CopyToCanvas(TmpCanvas, Mode, View, TmpX, TmpY, XScale, YScale);
  finally
    TmpCanvas.Free;
  end;
end;

procedure CADCopyToClipboard(const V: TFNCCADViewport; const Clp: TClipboard);
begin
  if (V = nil) or (Clp = nil) then
    Exit;
  Clp.Assign(V.OffScreenBitmap);
end;

function CADPrinterPageDevice(const APrinter: TPrinter): TCADPageDevice;
var
  TmpDC: HDC;
begin
  Result := TCADPageDevice.FromDPI(96, 96);
  if APrinter = nil then
    Exit;
  TmpDC := APrinter.Handle;
  if TmpDC = 0 then
    Exit;
  Result := TCADPageDevice.FromDPI(GetDeviceCaps(TmpDC, LOGPIXELSX),
    GetDeviceCaps(TmpDC, LOGPIXELSY));
  Result.OffsetXPx := -GetDeviceCaps(TmpDC, PHYSICALOFFSETX);
  Result.OffsetYPx := -GetDeviceCaps(TmpDC, PHYSICALOFFSETY);
end;

procedure CADPrintPages(const ACAD: TFNCCADCmp2D; const ASetup: TCADPageSetup;
  const APrinter: TPrinter; const AFirstPage, ALastPage: Integer);
var
  TmpSetup: TCADPageSetup;
  TmpDevice: TCADPageDevice;
  TmpCanvas: TDecorativeCanvas;
  TmpCount, TmpFirst, TmpLast, Cont: Integer;
begin
  if (ACAD = nil) or (APrinter = nil) then
    Exit;
  { A copy, because the query methods are not const and a const record
    parameter cannot be asked anything. }
  TmpSetup := ASetup;
  TmpCount := TmpSetup.PageCount(ACAD);
  TmpFirst := AFirstPage;
  if TmpFirst < 0 then
    TmpFirst := 0;
  TmpLast := ALastPage;
  if (TmpLast < 0) or (TmpLast > TmpCount - 1) then
    TmpLast := TmpCount - 1;
  if TmpLast < TmpFirst then
    Exit;

  if TmpSetup.Orientation = pgoLandscape then
    APrinter.Orientation := Vcl.Printers.poLandscape
  else
    APrinter.Orientation := Vcl.Printers.poPortrait;

  APrinter.BeginDoc;
  try
    { After BeginDoc: that is when the printing device context exists,
      and it is the one the canvas draws on. }
    TmpDevice := CADPrinterPageDevice(APrinter);
    TmpCanvas := TDecorativeCanvas.Create(APrinter.Canvas);
    try
      for Cont := TmpFirst to TmpLast do
      begin
        if Cont > TmpFirst then
          APrinter.NewPage;
        CADDrawPage(ACAD, TmpSetup, TmpDevice, Cont, TmpCanvas);
      end;
    finally
      TmpCanvas.Free;
    end;
  except
    { A half-printed document left in the spooler is worse than none. }
    APrinter.Abort;
    Raise;
  end;
  APrinter.EndDoc;
end;

procedure CADPrintSheets(const ACAD: TFNCCADCmp2D; const ASheets: TCADSheets;
  const APrinter: TPrinter; const AFirstSheet, ALastSheet: Integer);
var
  TmpDevice: TCADPageDevice;
  TmpCanvas: TDecorativeCanvas;
  TmpFirst, TmpLast, Cont: Integer;
begin
  if (ACAD = nil) or (ASheets = nil) or (APrinter = nil) then
    Exit;
  TmpFirst := AFirstSheet;
  if TmpFirst < 0 then
    TmpFirst := 0;
  TmpLast := ALastSheet;
  if (TmpLast < 0) or (TmpLast > ASheets.Count - 1) then
    TmpLast := ASheets.Count - 1;
  if TmpLast < TmpFirst then
    Exit;

  { From the first sheet, and see the note on the declaration. }
  if ASheets[TmpFirst].Orientation = pgoLandscape then
    APrinter.Orientation := Vcl.Printers.poLandscape
  else
    APrinter.Orientation := Vcl.Printers.poPortrait;

  APrinter.BeginDoc;
  try
    TmpDevice := CADPrinterPageDevice(APrinter);
    TmpCanvas := TDecorativeCanvas.Create(APrinter.Canvas);
    try
      for Cont := TmpFirst to TmpLast do
      begin
        if Cont > TmpFirst then
          APrinter.NewPage;
        CADDrawSheet(ACAD, ASheets[Cont], TmpDevice, TmpCanvas);
      end;
    finally
      TmpCanvas.Free;
    end;
  except
    { A half-printed document left in the spooler is worse than none. }
    APrinter.Abort;
    Raise;
  end;
  APrinter.EndDoc;
end;

procedure CADPrintSheetTiled(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const ATiling: TCADSheetTiling;
  const APrinter: TPrinter);
var
  TmpDevice: TCADPageDevice;
  TmpCanvas: TDecorativeCanvas;
  TmpAcross, TmpDown, Cont: Integer;
begin
  if (ACAD = nil) or (ASheet = nil) or (APrinter = nil) then
    Exit;
  if ATiling.Orientation = pgoLandscape then
    APrinter.Orientation := Vcl.Printers.poLandscape
  else
    APrinter.Orientation := Vcl.Printers.poPortrait;
  APrinter.BeginDoc;
  try
    TmpDevice := CADPrinterPageDevice(APrinter);
    CADSheetTileCount(ASheet, ATiling, TmpDevice, TmpAcross, TmpDown);
    TmpCanvas := TDecorativeCanvas.Create(APrinter.Canvas);
    try
      for Cont := 0 to TmpAcross * TmpDown - 1 do
      begin
        if Cont > 0 then
          APrinter.NewPage;
        CADDrawSheetTile(ACAD, ASheet, ATiling, TmpDevice, Cont, TmpCanvas);
      end;
    finally
      TmpCanvas.Free;
    end;
  except
    APrinter.Abort;
    Raise;
  end;
  APrinter.EndDoc;
end;

end.
