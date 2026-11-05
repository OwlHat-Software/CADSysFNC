{ : Enhanced metafiles and the Windows clipboard without the VCL - CS-06
  of docs\masterplanner-changes.md.

  <See Class=TCADGDIGraphics> is a drawing backend on a raw GDI device
  context. It is what VCL.FNCCS4GraphicsVCL does through a TCanvas, done
  with the Windows API alone, so it compiles for FMX as well. An FMX
  application on Windows can then record a sheet into an enhanced
  metafile and put it on the clipboard, which is what Word and
  PowerPoint paste as a vector picture.

  THE METAFILE

  A metafile records logical coordinates. The sheet is laid out at a
  resolution of its own (<See Variable=CADEMFResolution>, 2400 dpi,
  unless asked otherwise) and mapped
  onto the metafile's frame with MM_ANISOTROPIC, so the numbers in the
  file keep that precision and the picture says the paper size. GDI
  works out the frame in the reference device's pixels, from its
  HORZSIZE and HORZRES; the mapping uses the same two figures, so the
  two agree.

  WHY 2400 DPI (CS-17)

  GDI lays text out in the recording's logical units and writes each
  glyph's advance into the file as a whole number of them. At 600 dpi
  a glyph of a small label is a dozen units wide, and the rounding
  shows on playback - in Windows and in PowerPoint alike - as gaps
  inside words and as lines that measured as fitting running past
  their box. At 2400 dpi the same rounding is a hundredth of a
  millimetre. The file is vector either way; it only grows by the
  larger numbers.

  WRAPPED TEXT, CENTRED (CS-16)

  GDI's DrawText honours DT_VCENTER and DT_BOTTOM only for a single
  line, so a wrapped label sat at the top of its box where the screen,
  the PDF and the SVG centre it. A wrapped label that asks for either
  is measured first (DT_CALCRECT at the same width) and drawn that much
  lower, without the flag. VCL.FNCCS4GraphicsVCL does the same.

  THE CLIPBOARD (CS-18)

  Office ranks a registered 'PNG' above CF_ENHMETAFILE, so with both
  on the clipboard a plain paste in Word or PowerPoint took the bitmap
  and the vector picture was only reachable through Paste Special. The
  PNG is therefore left off unless <See Variable=CADClipboardPNG> asks
  for it; CF_DIB stays, for programs that take no metafile. The sheet
  also goes on as SVG under 'image/svg+xml' while
  <See Variable=CADClipboardSVG> is True, which current Office renders
  more faithfully than the metafile.

  STATE AND CLIPPING

  Pens, brushes and fonts are made when first asked for and kept until
  the graphics is freed, one per distinct value. That is not only
  economy. PushClip saves the device context and PopClip restores it,
  and a restore reselects whatever was selected at the save; keeping
  every object alive is what makes that always safe. After a restore
  the current pen, brush, font and colours are put back.

  WHAT GDI CANNOT DO

  No alpha: translucent colours are flattened onto
  <See Property=TCADGraphics@BlendBackground>, and a colour with alpha
  0 is not drawn, as in the VCL backend. Pictures with an alpha channel
  are flattened the same way. Gradients are drawn with GradientFill
  inside the shape's outline.

  Pictures are decoded with GDI+, which every Windows has. }
unit VCL.FNCCS4GDI;

{$I VCL.FNCCADSys.inc}

{ : Range checking off - PCADPoints is the 'array [0..0] of TPoint'
  idiom, which cannot be range checked. }
{$RANGECHECKS OFF}

{ : 'delayed' on the GDI+ imports is Windows-only, which this whole unit
  is. }
{$WARN SYMBOL_PLATFORM OFF}

interface

{$IFDEF MSWINDOWS}

uses
  Winapi.Windows, System.Types, System.Classes, System.SysUtils, System.Math,
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4Paper, VCL.FNCCS4Print,
  VCL.FNCCADSys4;

var
  { : The resolution of the PNG and the bitmap that go on the clipboard
    next to the metafile, for programs that cannot paste a vector
    picture. 150 keeps an A0 sheet within reason. }
  CADClipboardBitmapDPI: Integer = 150;

  { : The resolution a metafile is laid out at when the caller passes
    none (ADPI = 0) - see WHY 2400 DPI above. The clipboard uses it. }
  CADEMFResolution: Integer = 2400;

  { : Whether a copy puts the registered 'PNG' format on the clipboard
    as well. Off: Office would paste it in preference to the metafile.
    The CF_DIB bitmap goes on regardless. }
  CADClipboardPNG: Boolean = False;

  { : Whether a copy puts an SVG on the clipboard under 'image/svg+xml',
    next to the metafile. Office 365 pastes it ahead of the metafile. }
  CADClipboardSVG: Boolean = True;

type
  { : A <See Class=TCADGraphics> on a GDI device context: a screen DC, a
    printer's, a memory DC or an enhanced metafile being recorded. The
    DC belongs to the caller and must outlive the graphics. }
  TCADGDIGraphics = class(TCADGraphics)
  private type
    TPenEntry = record
      Style: TCADPenStyle;
      Width: Integer;
      Color: COLORREF;
      Handle: HPEN;
    end;

    TBrushEntry = record
      Color: COLORREF;
      Handle: HBRUSH;
    end;

    TFontEntry = record
      Spec: TCADFontSpec;
      Handle: HFONT;
    end;
  private
    fDC: HDC;
    fBounds: TRect;
    fFontColor: TCADColor;
    fTransparent: Boolean;
    fFont: TCADFontSpec;
    fFontSelected: Boolean;
    fOriginalFont: HFONT;
    fPenDirty: Boolean;
    fBrushDirty: Boolean;
    fCurBrush: HBRUSH;
    fClipSaves: Integer;
    fSaved: Boolean;
    fPens: array of TPenEntry;
    fPenCount: Integer;
    fBrushes: array of TBrushEntry;
    fBrushCount: Integer;
    fFonts: array of TFontEntry;
    fFontCount: Integer;
    procedure PenChanged(Sender: TObject);
    procedure BrushChanged(Sender: TObject);
    function GDIColor(const AColor: TCADColor): COLORREF;
    function PenHandle: HPEN;
    function BrushHandle: HBRUSH;
    function FontHandle(const AFont: TCADFontSpec): HFONT;
    procedure PreparePen;
    procedure PrepareBrush;
    procedure Prepare;
    { : Everything a RestoreDC may have put back, set again. }
    procedure Reapply;
    function GradientActive: Boolean;
    procedure GradientShape(const AShape: TProc; const ABox: TRect);
    function DrawTurnedText(const Text: string; var R: TRect;
      const Flags: Cardinal): Integer;
  protected
    function CreatePen: TCADPen; override;
    function CreateBrush: TCADBrush; override;
    function GetFontColor: TCADColor; override;
    procedure SetFontColor(const Value: TCADColor); override;
    function GetTransparent: Boolean; override;
    procedure SetTransparent(const Value: Boolean); override;
    function GetClipRect: TRect; override;
    procedure SetBlendBackground(const Value: TCADColor); override;
    procedure DoPushClip(const R: TRect); override;
    procedure DoPopClip; override;
    procedure DoPolygon(const Pts: Pointer; const Count: Integer); override;
    procedure DoRectangle(const X1, Y1, X2, Y2: Integer); override;
    procedure DoEllipse(const X1, Y1, X2, Y2: Integer); override;
    procedure DoFillRect(const R: TRect); override;
  public
    { : APixelsPerMM sets <See Property=TCADGraphics@PixelsPerMM>, 0 for
      "not known". The drawable area is whatever GetClipBox says. }
    constructor Create(const ADC: HDC; const APixelsPerMM: Double); overload;
    { : The same, with the drawable area given - for a metafile, where
      GetClipBox answers with the reference screen rather than the
      picture being recorded. }
    constructor Create(const ADC: HDC; const APixelsPerMM: Double;
      const ABounds: TRect); overload;
    destructor Destroy; override;

    procedure MoveTo(const X, Y: Integer); override;
    procedure LineTo(const X, Y: Integer); override;
    procedure Polyline(const Pts: Pointer; const Count: Integer); overload;
      override;
    procedure SelectFont(const Font: TCADFontSpec); override;
    procedure ResetFont; override;
    function DrawText(const Text: string; var R: TRect;
      const Flags: Cardinal): Integer; override;
    procedure DrawImage(const Dest: TRect; const Image: TCADImage;
      const CopyMode: LongInt); override;

    property DC: HDC read fDC;
  end;

{ : A linear blend from AColor1 to AColor2 over ARect on ADC, with GDI's
  GradientFill: left to right, or top to bottom when AVertical. The
  colours are COLORREFs. }
procedure CADGDIGradient(const ADC: HDC; const ARect: TRect;
  const AColor1, AColor2: COLORREF; const AVertical: Boolean);

{ : ASheet as an enhanced metafile the size of its paper, laid out at
  ADPI - 0 for <See Variable=CADEMFResolution>. The caller owns the
  handle: DeleteEnhMetaFile it, or hand it to the clipboard. }
function CADSheetToEMF(const ACAD: TFNCCADCmp2D; const ASheet: TCADSheet;
  const ADPI: Integer = 0): HENHMETAFILE;
{ : ARect of the model as an enhanced metafile, as large as it is on
  paper at AUnitsPerMM drawing units to the millimetre. }
function CADModelRectToEMF(const ACAD: TFNCCADCmp2D; const ARect: TRect2D;
  const AUnitsPerMM: TRealType; const ADPI: Integer = 0): HENHMETAFILE;
{ : CADSheetToEMF, written to AFileName (.emf). }
procedure CADSaveSheetToEMF(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const AFileName: String;
  const ADPI: Integer = 0);

{ : Puts ASheet on the Windows clipboard: an enhanced metafile, which
  Office pastes as a vector picture; an SVG under 'image/svg+xml' while
  <See Variable=CADClipboardSVG>; a CF_DIB, for everything else; and a
  PNG under the registered format 'PNG' only when
  <See Variable=CADClipboardPNG> - see THE CLIPBOARD above. The bitmaps
  are at <See Variable=CADClipboardBitmapDPI>; when they would be too
  large (see CADImageMaxPixels) they are left out. }
procedure CADCopySheetToClipboardWin(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet);
{ : The same for ARect of the model at AUnitsPerMM. }
procedure CADCopyModelRectToClipboardWin(const ACAD: TFNCCADCmp2D;
  const ARect: TRect2D; const AUnitsPerMM: TRealType);

{ : Printing on Windows, straight through GDI - the same drawing as the
  metafile, on the printer's own device context, with no VCL TPrinter or
  FMX printer in between. VCL.FNCCS4PrintFMX is built on it.

  Each sheet sets the orientation and, for a standard size, the paper of
  its own page: the device context is reset between pages, which Windows
  allows and Vcl.Printers does not offer. A custom size keeps the
  printer's paper. }

{ : The page device of a printer's device context: its resolution, and
  where the paper's corner is relative to the printable area - negative,
  see TCADPageDevice. }
function CADPrinterDCPageDevice(const ADC: HDC): TCADPageDevice;
{ : The page device of the printer APrinterName ('' for the default), or
  a 96 dpi device when there is no such printer. }
function CADPrinterPageDeviceWin(const APrinterName: String = ''): TCADPageDevice;
{ : The default printer's name, or '' when there is none. }
function CADDefaultPrinterName: String;

{ : Prints ASheets, from AFirstSheet to ALastSheet (-1: to the end), one
  sheet to a page, on APrinterName ('' for the default printer).
  ATitle names the job in the queue. AOutputFile, when given, is where
  the printer writes instead of to a port - for a printer that makes
  files, such as Microsoft Print to PDF, it saves without asking. }
procedure CADPrintSheetsWin(const ACAD: TFNCCADCmp2D;
  const ASheets: TCADSheets; const APrinterName: String = '';
  const ATitle: String = ''; const AFirstSheet: Integer = 0;
  const ALastSheet: Integer = -1; const AOutputFile: String = '');
{ : Prints ASheet tiled onto ATiling's paper at full size, one page per
  tile with its marks. See TCADSheetTiling. }
procedure CADPrintSheetTiledWin(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const ATiling: TCADSheetTiling;
  const APrinterName: String = ''; const ATitle: String = '';
  const AOutputFile: String = '');
{ : Prints ASetup's pages of the model, the same way. }
procedure CADPrintPagesWin(const ACAD: TFNCCADCmp2D;
  const ASetup: TCADPageSetup; const APrinterName: String = '';
  const ATitle: String = ''; const AFirstPage: Integer = 0;
  const ALastPage: Integer = -1; const AOutputFile: String = '');

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

uses
  Winapi.ActiveX, VCL.FNCCS4Image, VCL.FNCCS4SVG;

{ : DrawTextW, with a wrapped text's DT_VCENTER and DT_BOTTOM done by
  hand - GDI honours them only for a single line. See WRAPPED TEXT,
  CENTRED in the unit header. }
function GDIDrawText(const ADC: HDC; const AText: string; var R: TRect;
  const AFlags: Cardinal): Integer;
var
  TmpMeasure, TmpDraw: TRect;
  TmpSpare: Integer;
begin
  if ((AFlags and DT_WORDBREAK) = 0) or ((AFlags and DT_SINGLELINE) <> 0) or
    ((AFlags and DT_CALCRECT) <> 0) or
    ((AFlags and (DT_VCENTER or DT_BOTTOM)) = 0) then
  begin
    Result := DrawTextW(ADC, PChar(AText), Length(AText), R, AFlags);
    Exit;
  end;
  TmpMeasure := R;
  DrawTextW(ADC, PChar(AText), Length(AText), TmpMeasure,
    (AFlags and not (DT_VCENTER or DT_BOTTOM)) or DT_CALCRECT);
  TmpSpare := (R.Bottom - R.Top) - (TmpMeasure.Bottom - TmpMeasure.Top);
  TmpDraw := R;
  if (AFlags and DT_VCENTER) <> 0 then
    Inc(TmpDraw.Top, TmpSpare div 2)
  else
    Inc(TmpDraw.Top, TmpSpare);
  Result := DrawTextW(ADC, PChar(AText), Length(AText), TmpDraw,
    AFlags and not (DT_VCENTER or DT_BOTTOM));
end;

{ : ADPI, or CADEMFResolution for 0. }
function EMFDPI(const ADPI: Integer): Integer;
begin
  if ADPI > 0 then
    Result := Max(72, ADPI)
  else
    Result := Max(72, CADEMFResolution);
end;

{ ------------------------------------------------------------------
  GDI and GDI+ entry points, spelled out here so that nothing depends
  on how a given RTL version declares them.
  ------------------------------------------------------------------ }

type
  TCADTriVertex = record
    X, Y: Longint;
    Red, Green, Blue, Alpha: Word;
  end;

  TCADGradientRect = record
    UpperLeft, LowerRight: Cardinal;
  end;

  TCADGdipStartupInput = record
    GdiplusVersion: Cardinal;
    DebugEventCallback: Pointer;
    SuppressBackgroundThread: BOOL;
    SuppressExternalCodecs: BOOL;
  end;

function CADGDIGradientFill(DC: HDC; pVertex: Pointer; nVertex: Cardinal;
  pMesh: Pointer; nMesh, ulMode: Cardinal): BOOL; stdcall;
  external 'msimg32.dll' name 'GradientFill';

function CADGdiplusStartup(out Token: NativeUInt; Input: Pointer;
  Output: Pointer): Integer; stdcall;
  external 'gdiplus.dll' name 'GdiplusStartup' delayed;
procedure CADGdiplusShutdown(Token: NativeUInt); stdcall;
  external 'gdiplus.dll' name 'GdiplusShutdown' delayed;
function CADGdipCreateBitmapFromStream(Stream: Pointer;
  out Bitmap: Pointer): Integer; stdcall;
  external 'gdiplus.dll' name 'GdipCreateBitmapFromStream' delayed;
function CADGdipCreateHBITMAPFromBitmap(Bitmap: Pointer;
  out HBM: HBITMAP; Background: Cardinal): Integer; stdcall;
  external 'gdiplus.dll' name 'GdipCreateHBITMAPFromBitmap' delayed;
function CADGdipDisposeImage(Image: Pointer): Integer; stdcall;
  external 'gdiplus.dll' name 'GdipDisposeImage' delayed;

var
  GdipToken: NativeUInt = 0;
  GdipStarted: Boolean = False;

function EnsureGdiPlus: Boolean;
var
  TmpInput: TCADGdipStartupInput;
begin
  { GDI+ counts its starts, so starting it once more than the VCL or FNC
    already did costs nothing and does not depend on them. }
  if not GdipStarted then
  begin
    FillChar(TmpInput, SizeOf(TmpInput), 0);
    TmpInput.GdiplusVersion := 1;
    GdipStarted := CADGdiplusStartup(GdipToken, @TmpInput, nil) = 0;
  end;
  Result := GdipStarted;
end;

procedure CADGDIGradient(const ADC: HDC; const ARect: TRect;
  const AColor1, AColor2: COLORREF; const AVertical: Boolean);
const
  GRADIENT_FILL_RECT_H = 0;
  GRADIENT_FILL_RECT_V = 1;
var
  TmpV: array [0 .. 1] of TCADTriVertex;
  TmpG: TCADGradientRect;
begin
  if (ARect.Right <= ARect.Left) or (ARect.Bottom <= ARect.Top) then
    Exit;
  TmpV[0].X := ARect.Left;
  TmpV[0].Y := ARect.Top;
  TmpV[0].Red := GetRValue(AColor1) shl 8;
  TmpV[0].Green := GetGValue(AColor1) shl 8;
  TmpV[0].Blue := GetBValue(AColor1) shl 8;
  TmpV[0].Alpha := 0;
  TmpV[1].X := ARect.Right;
  TmpV[1].Y := ARect.Bottom;
  TmpV[1].Red := GetRValue(AColor2) shl 8;
  TmpV[1].Green := GetGValue(AColor2) shl 8;
  TmpV[1].Blue := GetBValue(AColor2) shl 8;
  TmpV[1].Alpha := 0;
  TmpG.UpperLeft := 0;
  TmpG.LowerRight := 1;
  if AVertical then
    CADGDIGradientFill(ADC, @TmpV[0], 2, @TmpG, 1, GRADIENT_FILL_RECT_V)
  else
    CADGDIGradientFill(ADC, @TmpV[0], 2, @TmpG, 1, GRADIENT_FILL_RECT_H);
end;

{ ------------------------------------------------------------------
  Pictures: decoded once by GDI+ into a 24-bit bottom-up DIB, flattened
  onto a background colour. The same DIB is what CF_DIB carries.
  ------------------------------------------------------------------ }

type
  TCADDIB = class(TObject)
  public
    Info: TBitmapInfo;
    Bits: TBytes;
    Background: TCADColor;
    function Width: Integer;
    function Height: Integer;
  end;

function TCADDIB.Width: Integer;
begin
  Result := Info.bmiHeader.biWidth;
end;

function TCADDIB.Height: Integer;
begin
  Result := Abs(Info.bmiHeader.biHeight);
end;

{ : AData (PNG, BMP, JPEG, GIF - anything GDI+ reads) as a DIB on
  ABackground, or nil. }
function DecodeDIB(const AData: TBytes; const ABackground: TCADColor): TCADDIB;
var
  TmpGlobal: HGLOBAL;
  TmpPtr: Pointer;
  TmpStream: IStream;
  TmpBitmap: Pointer;
  TmpHBM: HBITMAP;
  TmpBM: BITMAP;
  TmpStride: Integer;
  TmpDC: HDC;
begin
  Result := nil;
  if (Length(AData) = 0) or not EnsureGdiPlus then
    Exit;
  TmpGlobal := GlobalAlloc(GMEM_MOVEABLE, Length(AData));
  if TmpGlobal = 0 then
    Exit;
  TmpPtr := GlobalLock(TmpGlobal);
  Move(AData[0], TmpPtr^, Length(AData));
  GlobalUnlock(TmpGlobal);
  { The stream owns the memory from here and frees it with itself. }
  if Failed(CreateStreamOnHGlobal(TmpGlobal, True, TmpStream)) then
  begin
    GlobalFree(TmpGlobal);
    Exit;
  end;
  TmpBitmap := nil;
  if CADGdipCreateBitmapFromStream(Pointer(TmpStream), TmpBitmap) <> 0 then
    Exit;
  try
    { GDI+ wants the background as ARGB, which is what TCADColor is;
      opaque, so the picture's alpha is flattened onto it. }
    if CADGdipCreateHBITMAPFromBitmap(TmpBitmap, TmpHBM,
      CADColorSetAlpha(ABackground, $FF)) <> 0 then
      Exit;
    try
      if GetObject(TmpHBM, SizeOf(TmpBM), @TmpBM) = 0 then
        Exit;
      Result := TCADDIB.Create;
      Result.Background := ABackground;
      FillChar(Result.Info, SizeOf(Result.Info), 0);
      with Result.Info.bmiHeader do
      begin
        biSize := SizeOf(TBitmapInfoHeader);
        biWidth := TmpBM.bmWidth;
        biHeight := TmpBM.bmHeight;
        biPlanes := 1;
        biBitCount := 24;
        biCompression := BI_RGB;
        TmpStride := ((TmpBM.bmWidth * 3) + 3) and not 3;
        biSizeImage := TmpStride * TmpBM.bmHeight;
        SetLength(Result.Bits, biSizeImage);
      end;
      TmpDC := GetDC(0);
      try
        if (Length(Result.Bits) = 0) or (GetDIBits(TmpDC, TmpHBM, 0,
          TmpBM.bmHeight, @Result.Bits[0], Result.Info, DIB_RGB_COLORS) = 0)
        then
          FreeAndNil(Result);
      finally
        ReleaseDC(0, TmpDC);
      end;
    finally
      DeleteObject(TmpHBM);
    end;
  finally
    CADGdipDisposeImage(TmpBitmap);
  end;
end;

{ ------------------------------------------------------------------
  TCADGDIGraphics
  ------------------------------------------------------------------ }

const
  CADPenModeToROP2: array [TCADPenMode] of Integer = (R2_BLACK, R2_WHITE,
    R2_NOP, R2_NOT, R2_COPYPEN, R2_NOTCOPYPEN, R2_MERGEPENNOT, R2_MASKPENNOT,
    R2_MERGENOTPEN, R2_MASKNOTPEN, R2_MERGEPEN, R2_NOTMERGEPEN, R2_MASKPEN,
    R2_NOTMASKPEN, R2_XORPEN, R2_NOTXORPEN);

constructor TCADGDIGraphics.Create(const ADC: HDC; const APixelsPerMM: Double);
begin
  Create(ADC, APixelsPerMM, Rect(0, 0, 0, 0));
end;

constructor TCADGDIGraphics.Create(const ADC: HDC; const APixelsPerMM: Double;
  const ABounds: TRect);
begin
  inherited Create;
  fDC := ADC;
  fBounds := ABounds;
  if APixelsPerMM > 0 then
    PixelsPerMM := APixelsPerMM;
  fFontColor := cadclBlack;
  fTransparent := True;
  fFont := TCADFontSpec.Default;
  (Pen as TCADSimplePen).OnChange := PenChanged;
  (Brush as TCADSimpleBrush).OnChange := BrushChanged;
  if fDC <> 0 then
  begin
    { Whatever the DC had is given back in Destroy - objects, colours,
      modes and clip. }
    fSaved := SaveDC(fDC) <> 0;
    fOriginalFont := GetCurrentObject(fDC, OBJ_FONT);
  end;
  Reapply;
end;

destructor TCADGDIGraphics.Destroy;
var
  I: Integer;
begin
  if fDC <> 0 then
  begin
    PopAllClips;
    if fSaved then
      RestoreDC(fDC, -1)
    else
    begin
      SelectObject(fDC, GetStockObject(BLACK_PEN));
      SelectObject(fDC, GetStockObject(WHITE_BRUSH));
      SelectObject(fDC, fOriginalFont);
    end;
  end;
  { Only now: nothing is selected that could still be ours. }
  for I := 0 to fPenCount - 1 do
    DeleteObject(fPens[I].Handle);
  for I := 0 to fBrushCount - 1 do
    DeleteObject(fBrushes[I].Handle);
  for I := 0 to fFontCount - 1 do
    DeleteObject(fFonts[I].Handle);
  if Pen is TCADSimplePen then
    TCADSimplePen(Pen).OnChange := nil;
  if Brush is TCADSimpleBrush then
    TCADSimpleBrush(Brush).OnChange := nil;
  inherited Destroy;
end;

function TCADGDIGraphics.CreatePen: TCADPen;
begin
  Result := TCADSimplePen.Create;
end;

function TCADGDIGraphics.CreateBrush: TCADBrush;
begin
  Result := TCADSimpleBrush.Create;
end;

procedure TCADGDIGraphics.PenChanged(Sender: TObject);
begin
  fPenDirty := True;
end;

procedure TCADGDIGraphics.BrushChanged(Sender: TObject);
begin
  fBrushDirty := True;
end;

function TCADGDIGraphics.GDIColor(const AColor: TCADColor): COLORREF;
begin
  Result := COLORREF(CADColorToTColor(CADBlendColor(AColor,
    BlendBackground)));
end;

function TCADGDIGraphics.PenHandle: HPEN;
const
  DashPattern: array [0 .. 1] of DWORD = (18, 6);
  DotPattern: array [0 .. 1] of DWORD = (3, 3);
  DashDotPattern: array [0 .. 3] of DWORD = (9, 6, 3, 6);
  DashDotDotPattern: array [0 .. 5] of DWORD = (9, 3, 3, 3, 3, 3);
  AlternatePattern: array [0 .. 1] of DWORD = (1, 1);
var
  TmpStyle: TCADPenStyle;
  TmpColor: COLORREF;
  TmpWidth, I: Integer;
  TmpBrush: TLogBrush;
  TmpUnit: Double;
  TmpDashes: array of DWORD;

  procedure SetDashes(const APattern: array of DWORD);
  var
    J: Integer;
  begin
    SetLength(TmpDashes, Length(APattern));
    for J := 0 to High(APattern) do
      TmpDashes[J] := Max(1, Round(APattern[J] * TmpUnit));
  end;

begin
  if (Pen.Mode = cpmNop) or (Pen.Style = cpsClear) or
    (CADColorAlpha(Pen.Color) = 0) then
    Exit(GetStockObject(NULL_PEN));
  TmpStyle := Pen.Style;
  TmpColor := GDIColor(Pen.Color);
  TmpWidth := Max(1, Pen.Width);
  for I := 0 to fPenCount - 1 do
    if (fPens[I].Style = TmpStyle) and (fPens[I].Width = TmpWidth) and
      (fPens[I].Color = TmpColor) then
      Exit(fPens[I].Handle);

  TmpBrush.lbStyle := BS_SOLID;
  TmpBrush.lbColor := TmpColor;
  TmpBrush.lbHatch := 0;
  if (TmpWidth = 1) and (TmpStyle <> cpsInsideFrame) then
  begin
    { A one-pixel pen is a hairline, and a hairline has to stay one
      pixel wherever the picture ends up. A geometric pen of one 600 dpi
      dot, played back on a screen at a twentieth of that, is a polygon
      thinner than a pixel, and GDI leaves most of its pixels out. A
      cosmetic pen is one pixel of whatever device draws it - which is
      what this pen always meant on the screen. Its dashes are GDI's
      own, in device pixels, as on a VCL canvas. }
    case TmpStyle of
      cpsDash:
        Result := ExtCreatePen(PS_COSMETIC or PS_DASH, 1, TmpBrush, 0, nil);
      cpsDot:
        Result := ExtCreatePen(PS_COSMETIC or PS_DOT, 1, TmpBrush, 0, nil);
      cpsDashDot:
        Result := ExtCreatePen(PS_COSMETIC or PS_DASHDOT, 1, TmpBrush, 0, nil);
      cpsDashDotDot:
        Result := ExtCreatePen(PS_COSMETIC or PS_DASHDOTDOT, 1, TmpBrush,
          0, nil);
      cpsAlternate:
        Result := ExtCreatePen(PS_COSMETIC or PS_ALTERNATE, 1, TmpBrush,
          0, nil);
    else
      Result := ExtCreatePen(PS_COSMETIC or PS_SOLID, 1, TmpBrush, 0, nil);
    end;
  end
  else
    Result := 0;
  { Wider pens are geometric: their width is a width in the drawing. The
    dash patterns are GDI's own, in screen pixels, scaled as the SVG
    export scales them - see VCL.FNCCS4SVG. }
  TmpUnit := TmpWidth;
  if PixelsPerMM > 0 then
    TmpUnit := Max(TmpUnit, PixelsPerMM * 25.4 / 96);
  SetLength(TmpDashes, 0);
  case TmpStyle of
    cpsDash:
      SetDashes(DashPattern);
    cpsDot:
      SetDashes(DotPattern);
    cpsDashDot:
      SetDashes(DashDotPattern);
    cpsDashDotDot:
      SetDashes(DashDotDotPattern);
    cpsAlternate:
      SetDashes(AlternatePattern);
  end;
  if Result <> 0 then
    { The hairline above. }
  else if Length(TmpDashes) > 0 then
    Result := ExtCreatePen(PS_GEOMETRIC or PS_USERSTYLE or PS_ENDCAP_FLAT or
      PS_JOIN_ROUND, TmpWidth, TmpBrush, Length(TmpDashes), @TmpDashes[0])
  else if TmpStyle = cpsInsideFrame then
    Result := ExtCreatePen(PS_GEOMETRIC or PS_INSIDEFRAME or PS_ENDCAP_ROUND
      or PS_JOIN_ROUND, TmpWidth, TmpBrush, 0, nil)
  else
    Result := ExtCreatePen(PS_GEOMETRIC or PS_SOLID or PS_ENDCAP_ROUND or
      PS_JOIN_ROUND, TmpWidth, TmpBrush, 0, nil);
  if Result = 0 then
    Exit(GetStockObject(BLACK_PEN));
  if fPenCount = Length(fPens) then
    SetLength(fPens, fPenCount * 2 + 8);
  fPens[fPenCount].Style := TmpStyle;
  fPens[fPenCount].Width := TmpWidth;
  fPens[fPenCount].Color := TmpColor;
  fPens[fPenCount].Handle := Result;
  Inc(fPenCount);
end;

function TCADGDIGraphics.BrushHandle: HBRUSH;
var
  TmpColor: COLORREF;
  I: Integer;
begin
  if (Brush.Style = cbsClear) or (CADColorAlpha(Brush.Color) = 0) then
    Exit(GetStockObject(NULL_BRUSH));
  { Every other style is solid here: the hatches were drawn as lines by
    the base class, and a gradient is a solid brush in its first colour
    as far as anything that fills without GradientShape is concerned. }
  TmpColor := GDIColor(Brush.Color);
  for I := 0 to fBrushCount - 1 do
    if fBrushes[I].Color = TmpColor then
      Exit(fBrushes[I].Handle);
  Result := CreateSolidBrush(TmpColor);
  if Result = 0 then
    Exit(GetStockObject(WHITE_BRUSH));
  if fBrushCount = Length(fBrushes) then
    SetLength(fBrushes, fBrushCount * 2 + 8);
  fBrushes[fBrushCount].Color := TmpColor;
  fBrushes[fBrushCount].Handle := Result;
  Inc(fBrushCount);
end;

function TCADGDIGraphics.FontHandle(const AFont: TCADFontSpec): HFONT;
var
  LF: TLogFontW;
  I, Len: Integer;
begin
  for I := 0 to fFontCount - 1 do
    if TCADFontSpec.Same(fFonts[I].Spec, AFont) then
      Exit(fFonts[I].Handle);
  FillChar(LF, SizeOf(LF), 0);
  LF.lfHeight := AFont.Height;
  LF.lfWidth := AFont.Width;
  LF.lfEscapement := AFont.Escapement;
  LF.lfOrientation := AFont.Orientation;
  LF.lfWeight := AFont.Weight;
  LF.lfItalic := Byte(AFont.Italic);
  LF.lfUnderline := Byte(AFont.Underline);
  LF.lfStrikeOut := Byte(AFont.StrikeOut);
  LF.lfCharSet := AFont.CharSet;
  LF.lfOutPrecision := AFont.OutPrecision;
  LF.lfClipPrecision := AFont.ClipPrecision;
  LF.lfQuality := AFont.Quality;
  LF.lfPitchAndFamily := AFont.PitchAndFamily;
  Len := Min(Length(AFont.FaceName), LF_FACESIZE - 1);
  if Len > 0 then
    Move(PChar(AFont.FaceName)^, LF.lfFaceName[0], Len * SizeOf(Char));
  Result := CreateFontIndirectW(LF);
  if Result = 0 then
    Exit(GetStockObject(DEFAULT_GUI_FONT));
  if fFontCount = Length(fFonts) then
    SetLength(fFonts, fFontCount * 2 + 4);
  fFonts[fFontCount].Spec := AFont;
  fFonts[fFontCount].Handle := Result;
  Inc(fFontCount);
end;

procedure TCADGDIGraphics.PreparePen;
begin
  if not fPenDirty or (fDC = 0) then
    Exit;
  SelectObject(fDC, PenHandle);
  SetROP2(fDC, CADPenModeToROP2[Pen.Mode]);
  fPenDirty := False;
end;

procedure TCADGDIGraphics.PrepareBrush;
begin
  if not fBrushDirty or (fDC = 0) then
    Exit;
  fCurBrush := BrushHandle;
  SelectObject(fDC, fCurBrush);
  { As a VCL canvas does: the background behind opaque text is the
    brush colour. }
  SetBkColor(fDC, GDIColor(Brush.Color));
  fBrushDirty := False;
end;

procedure TCADGDIGraphics.Prepare;
begin
  PreparePen;
  PrepareBrush;
end;

procedure TCADGDIGraphics.Reapply;
begin
  if fDC = 0 then
    Exit;
  fPenDirty := True;
  fBrushDirty := True;
  Prepare;
  if fFontSelected then
    SelectObject(fDC, FontHandle(fFont))
  else
    SelectObject(fDC, fOriginalFont);
  SetTextColor(fDC, GDIColor(fFontColor));
  if fTransparent then
    SetBkMode(fDC, Winapi.Windows.TRANSPARENT)
  else
    SetBkMode(fDC, Winapi.Windows.OPAQUE);
  { GDI's default is ALTERNATE already; said here because a DC handed
    in may have been set otherwise, and CADSys polygons are even-odd. }
  SetPolyFillMode(fDC, ALTERNATE);
end;

function TCADGDIGraphics.GetFontColor: TCADColor;
begin
  Result := fFontColor;
end;

procedure TCADGDIGraphics.SetFontColor(const Value: TCADColor);
begin
  fFontColor := Value;
  if fDC <> 0 then
    SetTextColor(fDC, GDIColor(Value));
end;

function TCADGDIGraphics.GetTransparent: Boolean;
begin
  Result := fTransparent;
end;

procedure TCADGDIGraphics.SetTransparent(const Value: Boolean);
begin
  fTransparent := Value;
  if fDC = 0 then
    Exit;
  if Value then
    SetBkMode(fDC, Winapi.Windows.TRANSPARENT)
  else
    SetBkMode(fDC, Winapi.Windows.OPAQUE);
end;

procedure TCADGDIGraphics.SetBlendBackground(const Value: TCADColor);
begin
  inherited SetBlendBackground(Value);
  { Every flattened colour has to be flattened again. }
  fPenDirty := True;
  fBrushDirty := True;
  if fDC <> 0 then
    SetTextColor(fDC, GDIColor(fFontColor));
end;

function TCADGDIGraphics.GetClipRect: TRect;
begin
  if (fBounds.Right > fBounds.Left) and (fBounds.Bottom > fBounds.Top) then
    Exit(fBounds);
  if (fDC = 0) or (GetClipBox(fDC, Result) in [ERROR, NULLREGION]) then
    Result := Rect(0, 0, 0, 0);
end;

procedure TCADGDIGraphics.DoPushClip(const R: TRect);
begin
  if fDC = 0 then
    Exit;
  { SaveDC rather than saving the clip region: a region is in device
    coordinates and the DC of a metafile is mapped, while
    IntersectClipRect, like everything else here, is logical. }
  SaveDC(fDC);
  Inc(fClipSaves);
  IntersectClipRect(fDC, R.Left, R.Top, R.Right, R.Bottom);
end;

procedure TCADGDIGraphics.DoPopClip;
begin
  if (fDC = 0) or (fClipSaves = 0) then
    Exit;
  { -1: the save just made, which a metafile records the same way
    whatever came before it. }
  RestoreDC(fDC, -1);
  Dec(fClipSaves);
  Reapply;
end;

procedure TCADGDIGraphics.MoveTo(const X, Y: Integer);
begin
  if fDC <> 0 then
    MoveToEx(fDC, X, Y, nil);
end;

procedure TCADGDIGraphics.LineTo(const X, Y: Integer);
begin
  if fDC = 0 then
    Exit;
  PreparePen;
  Winapi.Windows.LineTo(fDC, X, Y);
end;

procedure TCADGDIGraphics.Polyline(const Pts: Pointer; const Count: Integer);
begin
  if (fDC = 0) or (Pts = nil) or (Count <= 1) then
    Exit;
  PreparePen;
  Winapi.Windows.Polyline(fDC, PCADPoints(Pts)^, Count);
end;

function TCADGDIGraphics.GradientActive: Boolean;
begin
  Result := (Brush.Style = cbsGradient) and (CADColorAlpha(Brush.Color) <> 0);
end;

procedure TCADGDIGraphics.GradientShape(const AShape: TProc;
  const ABox: TRect);
begin
  { The outline as a path, the path as the clip, the blend over the box;
    SaveDC/RestoreDC take the clip away again and nothing else, since
    nothing else changes in between. }
  SaveDC(fDC);
  try
    BeginPath(fDC);
    AShape();
    EndPath(fDC);
    SelectClipPath(fDC, RGN_AND);
    CADGDIGradient(fDC, ABox, GDIColor(Brush.Color), GDIColor(Brush.Color2),
      Brush.GradientVertical);
  finally
    RestoreDC(fDC, -1);
  end;
  { Then the outline over it, with nothing to fill. }
  SelectObject(fDC, GetStockObject(NULL_BRUSH));
  try
    AShape();
  finally
    SelectObject(fDC, fCurBrush);
  end;
end;

procedure TCADGDIGraphics.DoPolygon(const Pts: Pointer; const Count: Integer);
var
  TmpBox: TRect;
  I: Integer;
  P: PCADPoints;
begin
  if (fDC = 0) or (Pts = nil) or (Count <= 0) then
    Exit;
  Prepare;
  P := PCADPoints(Pts);
  if not GradientActive then
  begin
    Winapi.Windows.Polygon(fDC, P^, Count);
    Exit;
  end;
  TmpBox := Rect(P^[0].X, P^[0].Y, P^[0].X, P^[0].Y);
  for I := 1 to Count - 1 do
  begin
    TmpBox.Left := Min(TmpBox.Left, P^[I].X);
    TmpBox.Right := Max(TmpBox.Right, P^[I].X);
    TmpBox.Top := Min(TmpBox.Top, P^[I].Y);
    TmpBox.Bottom := Max(TmpBox.Bottom, P^[I].Y);
  end;
  GradientShape(
    procedure
    begin
      Winapi.Windows.Polygon(fDC, P^, Count);
    end, TmpBox);
end;

procedure TCADGDIGraphics.DoRectangle(const X1, Y1, X2, Y2: Integer);
begin
  if fDC = 0 then
    Exit;
  Prepare;
  if GradientActive then
    GradientShape(
      procedure
      begin
        Winapi.Windows.Rectangle(fDC, X1, Y1, X2, Y2);
      end, Rect(Min(X1, X2), Min(Y1, Y2), Max(X1, X2), Max(Y1, Y2)))
  else
    Winapi.Windows.Rectangle(fDC, X1, Y1, X2, Y2);
end;

procedure TCADGDIGraphics.DoEllipse(const X1, Y1, X2, Y2: Integer);
begin
  if fDC = 0 then
    Exit;
  Prepare;
  if GradientActive then
    GradientShape(
      procedure
      begin
        Winapi.Windows.Ellipse(fDC, X1, Y1, X2, Y2);
      end, Rect(Min(X1, X2), Min(Y1, Y2), Max(X1, X2), Max(Y1, Y2)))
  else
    Winapi.Windows.Ellipse(fDC, X1, Y1, X2, Y2);
end;

procedure TCADGDIGraphics.DoFillRect(const R: TRect);
var
  TmpR: TRect;
begin
  if fDC = 0 then
    Exit;
  Prepare;
  if GradientActive then
    CADGDIGradient(fDC, R, GDIColor(Brush.Color), GDIColor(Brush.Color2),
      Brush.GradientVertical)
  else if fCurBrush <> GetStockObject(NULL_BRUSH) then
  begin
    TmpR := R;
    Winapi.Windows.FillRect(fDC, TmpR, fCurBrush);
  end;
end;

procedure TCADGDIGraphics.SelectFont(const Font: TCADFontSpec);
begin
  fFont := Font;
  fFontSelected := True;
  if fDC <> 0 then
    SelectObject(fDC, FontHandle(Font));
end;

procedure TCADGDIGraphics.ResetFont;
begin
  if not fFontSelected then
    Exit;
  fFontSelected := False;
  if fDC <> 0 then
    SelectObject(fDC, fOriginalFont);
end;

function TCADGDIGraphics.DrawText(const Text: string; var R: TRect;
  const Flags: Cardinal): Integer;
begin
  Result := 0;
  if fDC = 0 then
    Exit;
  { The brush, for the background of opaque text. The CAD_DT_ flags are
    GDI's DT_ values, deliberately. }
  PrepareBrush;
  if (not fFontSelected) or (fFont.Escapement mod 3600 = 0) then
  begin
    Result := GDIDrawText(fDC, Text, R, Flags);
    Exit;
  end;
  Result := DrawTurnedText(Text, R, Flags);
end;

function TCADGDIGraphics.DrawTurnedText(const Text: string; var R: TRect;
  const Flags: Cardinal): Integer;
var
  TmpFlat: TCADFontSpec;
  TmpLayout: TRect;
  TmpAngle, TmpC, TmpS, TmpCX, TmpCY: Double;
  TmpOldMode: Integer;
  TmpOld, TmpTurn: TXForm;
begin
  { GDI turns a font's glyphs about each line's starting point, and
    DrawText's layout knows nothing of the turn. FNC - the screen and the
    PDF - lays the text out level in the turned rectangle's bounding box
    and turns the whole about the middle. This does what FNC does, with
    a level font and a world transform, so a turned label lands in the
    same place on paper as on the screen. Measuring needs no turn. }
  TmpFlat := fFont;
  TmpFlat.Escapement := 0;
  TmpFlat.Orientation := 0;
  SelectObject(fDC, FontHandle(TmpFlat));
  try
    if (Flags and CAD_DT_CALCRECT) <> 0 then
      Exit(DrawTextW(fDC, PChar(Text), Length(Text), R, Flags));
    Result := R.Bottom - R.Top;
    if not fTransparent then
      FillRect(R);
    TmpAngle := fFont.Escapement / 10;
    TmpLayout := CADRotatedTextRect(R, TmpAngle);
    TmpC := Cos(DegToRad(TmpAngle));
    TmpS := Sin(DegToRad(TmpAngle));
    TmpCX := (R.Left + R.Right) / 2;
    TmpCY := (R.Top + R.Bottom) / 2;
    { Counter-clockwise on the page, with Y down. }
    TmpTurn.eM11 := TmpC;
    TmpTurn.eM12 := -TmpS;
    TmpTurn.eM21 := TmpS;
    TmpTurn.eM22 := TmpC;
    TmpTurn.eDx := TmpCX - TmpCX * TmpC - TmpCY * TmpS;
    TmpTurn.eDy := TmpCY + TmpCX * TmpS - TmpCY * TmpC;
    TmpOldMode := SetGraphicsMode(fDC, GM_ADVANCED);
    GetWorldTransform(fDC, TmpOld);
    try
      ModifyWorldTransform(fDC, TmpTurn, MWT_LEFTMULTIPLY);
      { Transparent for the text itself: an opaque cell background
        would be turned too, and FNC's is the level rectangle filled
        above. }
      SetBkMode(fDC, Winapi.Windows.TRANSPARENT);
      { A line longer than its box runs on, as FNC lets turned text. }
      if (Flags and DT_WORDBREAK) = 0 then
        GDIDrawText(fDC, Text, TmpLayout, Flags or DT_NOCLIP)
      else
        GDIDrawText(fDC, Text, TmpLayout, Flags);
    finally
      SetWorldTransform(fDC, TmpOld);
      SetGraphicsMode(fDC, TmpOldMode);
      if not fTransparent then
        SetBkMode(fDC, Winapi.Windows.OPAQUE);
    end;
  finally
    SelectObject(fDC, FontHandle(fFont));
  end;
end;

procedure TCADGDIGraphics.DrawImage(const Dest: TRect; const Image: TCADImage;
  const CopyMode: LongInt);
var
  TmpDIB: TCADDIB;
  TmpRop: DWORD;
begin
  if (fDC = 0) or (Image = nil) or Image.IsEmpty then
    Exit;
  TmpDIB := TCADDIB(Image.CacheFor(Self));
  if (TmpDIB = nil) or (TmpDIB.Background <> BlendBackground) then
  begin
    TmpDIB := DecodeDIB(Image.Data, BlendBackground);
    if TmpDIB = nil then
      Exit;
    Image.SetCache(Self, TmpDIB);
  end;
  TmpRop := DWORD(CopyMode);
  if TmpRop = 0 then
    TmpRop := SRCCOPY;
  SetStretchBltMode(fDC, HALFTONE);
  SetBrushOrgEx(fDC, 0, 0, nil);
  StretchDIBits(fDC, Dest.Left, Dest.Top, Dest.Right - Dest.Left,
    Dest.Bottom - Dest.Top, 0, 0, TmpDIB.Width, TmpDIB.Height,
    @TmpDIB.Bits[0], TmpDIB.Info, DIB_RGB_COLORS, TmpRop);
end;

{ ------------------------------------------------------------------
  Metafiles
  ------------------------------------------------------------------ }

type
  TCADEMFDraw = reference to procedure(const ACanvas: TDecorativeCanvas;
    const ASizePx: TPoint);

{ : The reference device's pixels to the millimetre, across and down,
  as a metafile records them.

  Not HORZRES: in a process that is not DPI aware Windows scales that
  down to the virtual screen, while the metafile header records the
  physical one, and a picture mapped with the first is played back
  with the second - two and a half times too small on a 4K screen at
  250%. DESKTOPHORZRES is the physical figure either way. RecordEMF
  still checks the header afterwards, in case some driver disagrees. }
procedure ReferencePixelsPerMM(const ARef: HDC; out AX, AY: Double);
const
  DESKTOPVERTRES = 117;
  DESKTOPHORZRES = 118;
var
  TmpResX, TmpResY: Integer;
begin
  TmpResX := GetDeviceCaps(ARef, DESKTOPHORZRES);
  if TmpResX <= 0 then
    TmpResX := GetDeviceCaps(ARef, HORZRES);
  TmpResY := GetDeviceCaps(ARef, DESKTOPVERTRES);
  if TmpResY <= 0 then
    TmpResY := GetDeviceCaps(ARef, VERTRES);
  AX := TmpResX / Max(1, GetDeviceCaps(ARef, HORZSIZE));
  AY := TmpResY / Max(1, GetDeviceCaps(ARef, VERTSIZE));
end;

{ : One recording: the metafile AWidthMM by AHeightMM, laid out at ADPI,
  mapped onto the reference device at AX by AY pixels to the
  millimetre, with ADraw drawing on it. }
function RecordEMFAt(const AWidthMM, AHeightMM: TRealType; const ADPI: Integer;
  const ADescription: String; const AX, AY: Double;
  const ADraw: TCADEMFDraw): HENHMETAFILE;
var
  TmpDevice: TCADPageDevice;
  TmpSize: TPoint;
  TmpRef, TmpDC: HDC;
  TmpFrame: TRect;
  TmpGraphics: TCADGDIGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpDesc: String;
begin
  TmpDevice := TCADPageDevice.FromDPI(Max(72, ADPI), Max(72, ADPI));
  TmpSize := Point(TmpDevice.MMToPxX(AWidthMM), TmpDevice.MMToPxY(AHeightMM));
  TmpRef := GetDC(0);
  try
    { The frame is in hundredths of a millimetre. }
    TmpFrame := Rect(0, 0, Round(AWidthMM * 100), Round(AHeightMM * 100));
    { Application, then title, each ended by a nul, and a second nul at
      the end - the form CreateEnhMetaFile asks for. }
    TmpDesc := 'CADSys'#0 + ADescription + #0#0;
    TmpDC := CreateEnhMetaFileW(TmpRef, nil, @TmpFrame, PChar(TmpDesc));
    if TmpDC = 0 then
      RaiseLastOSError;
    try
      { ADPI dots onto the frame, in the reference device's pixels -
        see THE METAFILE above. }
      SetMapMode(TmpDC, MM_ANISOTROPIC);
      SetWindowExtEx(TmpDC, TmpSize.X, TmpSize.Y, nil);
      SetViewportExtEx(TmpDC, Max(1, Round(AWidthMM * AX)),
        Max(1, Round(AHeightMM * AY)), nil);
      TmpGraphics := TCADGDIGraphics.Create(TmpDC, TmpDevice.PixelsPerMM,
        Rect(0, 0, TmpSize.X, TmpSize.Y));
      try
        TmpCanvas := TDecorativeCanvas.Create(TmpGraphics, False);
        try
          ADraw(TmpCanvas, TmpSize);
        finally
          TmpCanvas.Free;
        end;
      finally
        TmpGraphics.Free;
      end;
    finally
      Result := CloseEnhMetaFile(TmpDC);
    end;
  finally
    ReleaseDC(0, TmpRef);
  end;
end;

{ : A metafile AWidthMM by AHeightMM, laid out at ADPI, with ADraw
  drawing on it. }
function RecordEMF(const AWidthMM, AHeightMM: TRealType; const ADPI: Integer;
  const ADescription: String; const ADraw: TCADEMFDraw): HENHMETAFILE;
var
  TmpRef: HDC;
  TmpX, TmpY, TmpHX, TmpHY: Double;
  TmpHeader: TEnhMetaHeader;
begin
  if (AWidthMM <= 0) or (AHeightMM <= 0) then
    Raise ECADPageError.Create('Nothing to make a metafile of');
  TmpRef := GetDC(0);
  try
    ReferencePixelsPerMM(TmpRef, TmpX, TmpY);
  finally
    ReleaseDC(0, TmpRef);
  end;
  Result := RecordEMFAt(AWidthMM, AHeightMM, ADPI, ADescription, TmpX, TmpY,
    ADraw);
  { What the header says is what playback will use. If it is not what
    the mapping assumed, once more with the header's own figures. }
  if (Result = 0) or (GetEnhMetaFileHeader(Result, SizeOf(TmpHeader),
    @TmpHeader) = 0) or (TmpHeader.szlMicrometers.cx <= 0) or
    (TmpHeader.szlMicrometers.cy <= 0) then
    Exit;
  TmpHX := TmpHeader.szlDevice.cx / (TmpHeader.szlMicrometers.cx / 1000);
  TmpHY := TmpHeader.szlDevice.cy / (TmpHeader.szlMicrometers.cy / 1000);
  if (Abs(TmpHX - TmpX) > TmpHX * 0.001) or
    (Abs(TmpHY - TmpY) > TmpHY * 0.001) then
  begin
    DeleteEnhMetaFile(Result);
    Result := RecordEMFAt(AWidthMM, AHeightMM, ADPI, ADescription, TmpHX,
      TmpHY, ADraw);
  end;
end;

function CADSheetToEMF(const ACAD: TFNCCADCmp2D; const ASheet: TCADSheet;
  const ADPI: Integer): HENHMETAFILE;
var
  TmpW, TmpH: TRealType;
  TmpDevice: TCADPageDevice;
begin
  Result := 0;
  if (ACAD = nil) or (ASheet = nil) then
    Exit;
  ASheet.SizeMM(TmpW, TmpH);
  TmpDevice := TCADPageDevice.FromDPI(EMFDPI(ADPI), EMFDPI(ADPI));
  Result := RecordEMF(TmpW, TmpH, EMFDPI(ADPI), ASheet.Name,
    procedure(const ACanvas: TDecorativeCanvas; const ASizePx: TPoint)
    begin
      CADDrawSheet(ACAD, ASheet, TmpDevice, ACanvas);
    end);
end;

function CADModelRectToEMF(const ACAD: TFNCCADCmp2D; const ARect: TRect2D;
  const AUnitsPerMM: TRealType; const ADPI: Integer): HENHMETAFILE;
var
  TmpRect: TRect2D;
begin
  Result := 0;
  if (ACAD = nil) or (AUnitsPerMM <= 0) then
    Exit;
  TmpRect := ReorderRect2D(ARect);
  Result := RecordEMF((TmpRect.Right - TmpRect.Left) / AUnitsPerMM,
    (TmpRect.Top - TmpRect.Bottom) / AUnitsPerMM, EMFDPI(ADPI), '',
    procedure(const ACanvas: TDecorativeCanvas; const ASizePx: TPoint)
    begin
      CADDrawModelRect(ACAD, ARect, ASizePx, ACanvas);
    end);
end;

procedure CADSaveSheetToEMF(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const AFileName: String; const ADPI: Integer);
var
  TmpEMF, TmpCopy: HENHMETAFILE;
begin
  if AFileName = '' then
    Exit;
  TmpEMF := CADSheetToEMF(ACAD, ASheet, ADPI);
  if TmpEMF = 0 then
    Exit;
  try
    TmpCopy := CopyEnhMetaFileW(TmpEMF, PChar(AFileName));
    if TmpCopy = 0 then
      RaiseLastOSError;
    DeleteEnhMetaFile(TmpCopy);
  finally
    DeleteEnhMetaFile(TmpEMF);
  end;
end;

{ ------------------------------------------------------------------
  Clipboard
  ------------------------------------------------------------------ }

function GlobalFromBytes(const AData: Pointer; const ASize: NativeInt;
  const AHeader: Pointer = nil; const AHeaderSize: NativeInt = 0): HGLOBAL;
var
  TmpPtr: PByte;
begin
  Result := GlobalAlloc(GMEM_MOVEABLE, AHeaderSize + ASize);
  if Result = 0 then
    Exit;
  TmpPtr := GlobalLock(Result);
  if AHeaderSize > 0 then
    Move(AHeader^, TmpPtr^, AHeaderSize);
  if ASize > 0 then
    Move(AData^, (TmpPtr + AHeaderSize)^, ASize);
  GlobalUnlock(Result);
end;

procedure OpenTheClipboard;
var
  I: Integer;
begin
  { Another program may have it open for a moment - a clipboard
    manager, Office reading what was just put there. }
  for I := 1 to 10 do
  begin
    if OpenClipboard(0) then
      Exit;
    Sleep(20);
  end;
  RaiseLastOSError;
end;

procedure PutOnClipboard(const AEMF: HENHMETAFILE;
  const APNG, ASVG: TBytes);
var
  TmpDIB: TCADDIB;
  TmpHandle: HGLOBAL;
begin
  TmpDIB := nil;
  if Length(APNG) > 0 then
    TmpDIB := DecodeDIB(APNG, cadclWhite);
  try
    OpenTheClipboard;
    try
      EmptyClipboard;
      { Each SetClipboardData that succeeds hands the handle over; one
        that fails leaves it ours to free. }
      if (AEMF <> 0) and (SetClipboardData(CF_ENHMETAFILE, AEMF) = 0) then
        DeleteEnhMetaFile(AEMF);
      if Length(ASVG) > 0 then
      begin
        TmpHandle := GlobalFromBytes(@ASVG[0], Length(ASVG));
        if (TmpHandle <> 0) and (SetClipboardData(RegisterClipboardFormat
          ('image/svg+xml'), TmpHandle) = 0) then
          GlobalFree(TmpHandle);
      end;
      { Not by default - Office would take it before the metafile. }
      if CADClipboardPNG and (Length(APNG) > 0) then
      begin
        TmpHandle := GlobalFromBytes(@APNG[0], Length(APNG));
        if (TmpHandle <> 0) and
          (SetClipboardData(RegisterClipboardFormat('PNG'), TmpHandle) = 0) then
          GlobalFree(TmpHandle);
      end;
      if TmpDIB <> nil then
      begin
        TmpHandle := GlobalFromBytes(@TmpDIB.Bits[0], Length(TmpDIB.Bits),
          @TmpDIB.Info.bmiHeader, SizeOf(TBitmapInfoHeader));
        if (TmpHandle <> 0) and (SetClipboardData(CF_DIB, TmpHandle) = 0) then
          GlobalFree(TmpHandle);
      end;
    finally
      CloseClipboard;
    end;
  finally
    TmpDIB.Free;
  end;
end;

type
  TCADPNGWrite = reference to procedure(const AStream: TStream);

{ : What AWrite writes, as bytes; nothing if it raises - the metafile
  goes on the clipboard either way. }
function StreamBytes(const AWrite: TCADPNGWrite): TBytes;
var
  TmpStream: TBytesStream;
begin
  SetLength(Result, 0);
  TmpStream := TBytesStream.Create;
  try
    try
      AWrite(TmpStream);
      Result := Copy(TmpStream.Bytes, 0, TmpStream.Size);
    except
      on Exception do
        SetLength(Result, 0);
    end;
  finally
    TmpStream.Free;
  end;
end;

{ : ARect of the model as an SVG, at the size it has on paper - the SVG
  unit draws sheets; the model rectangle is drawn as its PNG and its
  metafile are, by CADDrawModelRect. }
procedure SaveModelRectToSVGStream(const ACAD: TFNCCADCmp2D;
  const ARect: TRect2D; const AUnitsPerMM: TRealType; const AStream: TStream);
var
  TmpRect: TRect2D;
  TmpW, TmpH: TRealType;
  TmpDevice: TCADPageDevice;
  TmpSVG: TCADSVGGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpSize: TPoint;
begin
  TmpRect := ReorderRect2D(ARect);
  TmpW := (TmpRect.Right - TmpRect.Left) / AUnitsPerMM;
  TmpH := (TmpRect.Top - TmpRect.Bottom) / AUnitsPerMM;
  if (TmpW <= 0) or (TmpH <= 0) then
    Exit;
  TmpDevice := TCADPageDevice.FromDPI(Max(72, CADSVGResolution),
    Max(72, CADSVGResolution));
  TmpSize := Point(TmpDevice.MMToPxX(TmpW), TmpDevice.MMToPxY(TmpH));
  TmpSVG := TCADSVGGraphics.Create(TmpSize.X, TmpSize.Y,
    TmpDevice.PixelsPerMM);
  try
    TmpSVG.WidthMM := TmpW;
    TmpSVG.HeightMM := TmpH;
    TmpCanvas := TDecorativeCanvas.Create(TmpSVG, False);
    try
      CADDrawModelRect(ACAD, ARect, TmpSize, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    TmpSVG.SaveToStream(AStream);
  finally
    TmpSVG.Free;
  end;
end;

{ : The PNG, or nothing when it would be larger than the image export
  allows - the metafile goes on the clipboard either way. }
function PNGBytes(const AWrite: TCADPNGWrite): TBytes;
var
  TmpStream: TBytesStream;
begin
  SetLength(Result, 0);
  TmpStream := TBytesStream.Create;
  try
    try
      AWrite(TmpStream);
      Result := Copy(TmpStream.Bytes, 0, TmpStream.Size);
    except
      on ECADPageError do
        SetLength(Result, 0);
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure CADCopySheetToClipboardWin(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet);
var
  TmpEMF: HENHMETAFILE;
  TmpPNG, TmpSVG: TBytes;
begin
  if (ACAD = nil) or (ASheet = nil) then
    Exit;
  TmpPNG := PNGBytes(
    procedure(const AStream: TStream)
    begin
      CADSaveSheetToPNGStream(ACAD, ASheet, AStream, CADClipboardBitmapDPI,
        False);
    end);
  TmpSVG := nil;
  if CADClipboardSVG then
    TmpSVG := StreamBytes(
      procedure(const AStream: TStream)
      begin
        CADSaveSheetToSVGStream(ACAD, ASheet, AStream);
      end);
  TmpEMF := CADSheetToEMF(ACAD, ASheet);
  PutOnClipboard(TmpEMF, TmpPNG, TmpSVG);
end;

procedure CADCopyModelRectToClipboardWin(const ACAD: TFNCCADCmp2D;
  const ARect: TRect2D; const AUnitsPerMM: TRealType);
var
  TmpEMF: HENHMETAFILE;
  TmpPNG, TmpSVG: TBytes;
begin
  if (ACAD = nil) or (AUnitsPerMM <= 0) then
    Exit;
  TmpPNG := PNGBytes(
    procedure(const AStream: TStream)
    begin
      CADSaveModelRectToPNGStream(ACAD, ARect, AUnitsPerMM, AStream,
        CADClipboardBitmapDPI, False);
    end);
  TmpSVG := nil;
  if CADClipboardSVG then
    TmpSVG := StreamBytes(
      procedure(const AStream: TStream)
      begin
        SaveModelRectToSVGStream(ACAD, ARect, AUnitsPerMM, AStream);
      end);
  TmpEMF := CADModelRectToEMF(ACAD, ARect, AUnitsPerMM);
  PutOnClipboard(TmpEMF, TmpPNG, TmpSVG);
end;

{ ------------------------------------------------------------------
  Printing
  ------------------------------------------------------------------ }

function CADOpenPrinterW(pPrinterName: PWideChar; out hPrinter: THandle;
  pDefault: Pointer): BOOL; stdcall;
  external 'winspool.drv' name 'OpenPrinterW';
function CADClosePrinter(hPrinter: THandle): BOOL; stdcall;
  external 'winspool.drv' name 'ClosePrinter';
function CADDocumentPropertiesW(hWnd: HWND; hPrinter: THandle;
  pDeviceName: PWideChar; pDevModeOutput, pDevModeInput: Pointer;
  fMode: DWORD): Longint; stdcall;
  external 'winspool.drv' name 'DocumentPropertiesW';
function CADGetDefaultPrinterW(pszBuffer: PWideChar; pcchBuffer: PDWORD): BOOL;
  stdcall; external 'winspool.drv' name 'GetDefaultPrinterW';

const
  CAD_DMORIENT_PORTRAIT = 1;
  CAD_DMORIENT_LANDSCAPE = 2;
  CAD_DM_ORIENTATION = $00000001;
  CAD_DM_PAPERSIZE = $00000002;
  CAD_DM_PAPERLENGTH = $00000004;
  CAD_DM_PAPERWIDTH = $00000008;
  { DMPAPER_ for each TCADPaperKind, 0 for "leave the printer's". A1
    and A0 have no number of their own in GDI. }
  CADPaperToDMPaper: array [TCADPaperKind] of SmallInt = (11 { A5 },
    9 { A4 }, 8 { A3 }, 66 { A2 }, 0, 0, 1 { Letter }, 5 { Legal },
    3 { Tabloid }, 0);

function CADDefaultPrinterName: String;
var
  TmpLen: DWORD;
  TmpBuf: array of WideChar;
begin
  Result := '';
  TmpLen := 0;
  CADGetDefaultPrinterW(nil, @TmpLen);
  if TmpLen = 0 then
    Exit;
  SetLength(TmpBuf, TmpLen + 1);
  if CADGetDefaultPrinterW(@TmpBuf[0], @TmpLen) then
    Result := PWideChar(@TmpBuf[0]);
end;

function CADPrinterDCPageDevice(const ADC: HDC): TCADPageDevice;
begin
  Result := TCADPageDevice.FromDPI(96, 96);
  if ADC = 0 then
    Exit;
  Result := TCADPageDevice.FromDPI(GetDeviceCaps(ADC, LOGPIXELSX),
    GetDeviceCaps(ADC, LOGPIXELSY));
  Result.OffsetXPx := -GetDeviceCaps(ADC, PHYSICALOFFSETX);
  Result.OffsetYPx := -GetDeviceCaps(ADC, PHYSICALOFFSETY);
end;

function ResolvePrinterName(const AName: String): String;
begin
  Result := AName;
  if Result = '' then
    Result := CADDefaultPrinterName;
end;

function CADPrinterPageDeviceWin(const APrinterName: String): TCADPageDevice;
var
  TmpName: String;
  TmpIC: HDC;
begin
  Result := TCADPageDevice.FromDPI(96, 96);
  TmpName := ResolvePrinterName(APrinterName);
  if TmpName = '' then
    Exit;
  TmpIC := CreateICW('WINSPOOL', PChar(TmpName), nil, nil);
  if TmpIC = 0 then
    Exit;
  try
    Result := CADPrinterDCPageDevice(TmpIC);
  finally
    DeleteDC(TmpIC);
  end;
end;

{ : The printer's own DEVMODE, driver part and all, or nothing when the
  printer will not say. }
function LoadDevMode(const AName: String): TBytes;
var
  TmpPrinter: THandle;
  TmpSize: Integer;
begin
  SetLength(Result, 0);
  if not CADOpenPrinterW(PChar(AName), TmpPrinter, nil) then
    Exit;
  try
    TmpSize := CADDocumentPropertiesW(0, TmpPrinter, PChar(AName), nil, nil, 0);
    if TmpSize <= 0 then
      Exit;
    SetLength(Result, TmpSize);
    if CADDocumentPropertiesW(0, TmpPrinter, PChar(AName), @Result[0], nil,
      DM_OUT_BUFFER) < 0 then
      SetLength(Result, 0);
  finally
    CADClosePrinter(TmpPrinter);
  end;
end;

{ : ADevMode with the orientation and paper of one page, merged by the
  driver - which may refuse a paper it does not have and keep its own. }
procedure SetPageMode(const AName: String; var ADevMode: TBytes;
  const AOrientation: TCADPageOrientation; const APaper: TCADPaperKind);
var
  TmpMode: PDeviceModeW;
  TmpOut: TBytes;
  TmpPrinter: THandle;
begin
  if Length(ADevMode) = 0 then
    Exit;
  TmpMode := PDeviceModeW(@ADevMode[0]);
  TmpMode.dmFields := TmpMode.dmFields or CAD_DM_ORIENTATION;
  if AOrientation = pgoLandscape then
    TmpMode.dmOrientation := CAD_DMORIENT_LANDSCAPE
  else
    TmpMode.dmOrientation := CAD_DMORIENT_PORTRAIT;
  if CADPaperToDMPaper[APaper] <> 0 then
  begin
    { A paper number, and no explicit length and width to override it. }
    TmpMode.dmFields := (TmpMode.dmFields or CAD_DM_PAPERSIZE) and
      not (CAD_DM_PAPERLENGTH or CAD_DM_PAPERWIDTH);
    TmpMode.dmPaperSize := CADPaperToDMPaper[APaper];
  end;
  if not CADOpenPrinterW(PChar(AName), TmpPrinter, nil) then
    Exit;
  try
    TmpOut := Copy(ADevMode);
    if CADDocumentPropertiesW(0, TmpPrinter, PChar(AName), @TmpOut[0],
      @ADevMode[0], DM_IN_BUFFER or DM_OUT_BUFFER) >= 0 then
      ADevMode := TmpOut;
  finally
    CADClosePrinter(TmpPrinter);
  end;
end;

type
  TCADWinPageSetup = reference to procedure(const AIndex: Integer;
    out AOrientation: TCADPageOrientation; out APaper: TCADPaperKind);
  TCADWinPageDraw = reference to procedure(const AIndex: Integer;
    const ADevice: TCADPageDevice; const ACanvas: TDecorativeCanvas);

procedure PrintJob(const APrinterName, ATitle, AOutputFile: String;
  const AFirst, ALast: Integer; const ASetup: TCADWinPageSetup;
  const ADraw: TCADWinPageDraw);
var
  TmpName, TmpTitle: String;
  TmpDevMode: TBytes;
  TmpModePtr: PDeviceModeW;
  TmpDC: HDC;
  TmpInfo: TDocInfoW;
  TmpOrientation: TCADPageOrientation;
  TmpPaper: TCADPaperKind;
  TmpDevice: TCADPageDevice;
  TmpGraphics: TCADGDIGraphics;
  TmpCanvas: TDecorativeCanvas;
  I: Integer;
begin
  TmpName := ResolvePrinterName(APrinterName);
  if TmpName = '' then
    Raise ECADPageError.Create('There is no printer to print on');
  TmpDevMode := LoadDevMode(TmpName);
  ASetup(AFirst, TmpOrientation, TmpPaper);
  SetPageMode(TmpName, TmpDevMode, TmpOrientation, TmpPaper);
  if Length(TmpDevMode) > 0 then
    TmpModePtr := PDeviceModeW(@TmpDevMode[0])
  else
    TmpModePtr := nil;
  TmpDC := CreateDCW('WINSPOOL', PChar(TmpName), nil, TmpModePtr);
  if TmpDC = 0 then
    RaiseLastOSError;
  try
    TmpTitle := ATitle;
    if TmpTitle = '' then
      TmpTitle := 'CADSys';
    FillChar(TmpInfo, SizeOf(TmpInfo), 0);
    TmpInfo.cbSize := SizeOf(TmpInfo);
    TmpInfo.lpszDocName := PChar(TmpTitle);
    if AOutputFile <> '' then
      TmpInfo.lpszOutput := PChar(AOutputFile);
    if StartDocW(TmpDC, TmpInfo) <= 0 then
      RaiseLastOSError;
    try
      for I := AFirst to ALast do
      begin
        { Between EndPage and StartPage is the one place a printer's DC
          may be reset, and the page after takes the new mode. }
        if (I > AFirst) and (Length(TmpDevMode) > 0) then
        begin
          ASetup(I, TmpOrientation, TmpPaper);
          SetPageMode(TmpName, TmpDevMode, TmpOrientation, TmpPaper);
          ResetDCW(TmpDC, PDeviceModeW(@TmpDevMode[0])^);
        end;
        if StartPage(TmpDC) <= 0 then
          RaiseLastOSError;
        { Asked per page: a page turned the other way has its printable
          area somewhere else. }
        TmpDevice := CADPrinterDCPageDevice(TmpDC);
        TmpGraphics := TCADGDIGraphics.Create(TmpDC, TmpDevice.PixelsPerMM);
        try
          TmpCanvas := TDecorativeCanvas.Create(TmpGraphics, False);
          try
            ADraw(I, TmpDevice, TmpCanvas);
          finally
            TmpCanvas.Free;
          end;
        finally
          TmpGraphics.Free;
        end;
        if EndPage(TmpDC) <= 0 then
          RaiseLastOSError;
      end;
    except
      { A half-printed document left in the spooler is worse than none. }
      AbortDoc(TmpDC);
      Raise;
    end;
    EndDoc(TmpDC);
  finally
    DeleteDC(TmpDC);
  end;
end;

procedure CADPrintSheetsWin(const ACAD: TFNCCADCmp2D;
  const ASheets: TCADSheets; const APrinterName: String;
  const ATitle: String; const AFirstSheet: Integer;
  const ALastSheet: Integer; const AOutputFile: String);
var
  TmpFirst, TmpLast: Integer;
begin
  if (ACAD = nil) or (ASheets = nil) then
    Exit;
  TmpFirst := Max(0, AFirstSheet);
  TmpLast := ALastSheet;
  if (TmpLast < 0) or (TmpLast > ASheets.Count - 1) then
    TmpLast := ASheets.Count - 1;
  if TmpLast < TmpFirst then
    Exit;
  PrintJob(APrinterName, ATitle, AOutputFile, TmpFirst, TmpLast,
    procedure(const AIndex: Integer; out AOrientation: TCADPageOrientation;
      out APaper: TCADPaperKind)
    begin
      AOrientation := ASheets[AIndex].Orientation;
      APaper := ASheets[AIndex].Paper;
    end,
    procedure(const AIndex: Integer; const ADevice: TCADPageDevice;
      const ACanvas: TDecorativeCanvas)
    begin
      CADDrawSheet(ACAD, ASheets[AIndex], ADevice, ACanvas);
    end);
end;

procedure CADPrintSheetTiledWin(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const ATiling: TCADSheetTiling;
  const APrinterName: String; const ATitle: String;
  const AOutputFile: String);
var
  TmpAcross, TmpDown: Integer;
  TmpTiling: TCADSheetTiling;
begin
  if (ACAD = nil) or (ASheet = nil) then
    Exit;
  TmpTiling := ATiling;
  { The page count has to be known before the job starts, so it comes from
    the printer as it stands. The paper and orientation the job sets could
    move its edges by a little; with margins above them, as the default's
    10 mm are on an office printer, that changes nothing. }
  CADSheetTileCount(ASheet, TmpTiling, CADPrinterPageDeviceWin(APrinterName),
    TmpAcross, TmpDown);
  PrintJob(APrinterName, ATitle, AOutputFile, 0, TmpAcross * TmpDown - 1,
    procedure(const AIndex: Integer; out AOrientation: TCADPageOrientation;
      out APaper: TCADPaperKind)
    begin
      AOrientation := TmpTiling.Orientation;
      APaper := TmpTiling.Paper;
    end,
    procedure(const AIndex: Integer; const ADevice: TCADPageDevice;
      const ACanvas: TDecorativeCanvas)
    begin
      CADDrawSheetTile(ACAD, ASheet, TmpTiling, ADevice, AIndex, ACanvas);
    end);
end;

procedure CADPrintPagesWin(const ACAD: TFNCCADCmp2D;
  const ASetup: TCADPageSetup; const APrinterName: String;
  const ATitle: String; const AFirstPage: Integer; const ALastPage: Integer;
  const AOutputFile: String);
var
  TmpSetup: TCADPageSetup;
  TmpFirst, TmpLast, TmpCount: Integer;
begin
  if ACAD = nil then
    Exit;
  { A copy, because the query methods are not const and a const record
    parameter cannot be asked anything. }
  TmpSetup := ASetup;
  TmpCount := TmpSetup.PageCount(ACAD);
  TmpFirst := Max(0, AFirstPage);
  TmpLast := ALastPage;
  if (TmpLast < 0) or (TmpLast > TmpCount - 1) then
    TmpLast := TmpCount - 1;
  if TmpLast < TmpFirst then
    Exit;
  PrintJob(APrinterName, ATitle, AOutputFile, TmpFirst, TmpLast,
    procedure(const AIndex: Integer; out AOrientation: TCADPageOrientation;
      out APaper: TCADPaperKind)
    begin
      AOrientation := TmpSetup.Orientation;
      APaper := TmpSetup.Paper;
    end,
    procedure(const AIndex: Integer; const ADevice: TCADPageDevice;
      const ACanvas: TDecorativeCanvas)
    begin
      CADDrawPage(ACAD, TmpSetup, ADevice, AIndex, ACanvas);
    end);
end;

initialization

finalization

if GdipStarted then
  CADGdiplusShutdown(GdipToken);

{$ENDIF}

end.
