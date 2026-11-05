{ : PDF output, on all three frameworks, by doing almost nothing.

  TMS FNC Core ships a PDF library, and - this is the part that
  matters - <I=TTMSFNCGraphicsPDFEngine> descends from
  <I=TTMSFNCGraphics>. So the library's existing FNC backend attaches to
  a PDF exactly as it attaches to a control, and
  <See Procedure=CADDrawPage> draws a page onto it without knowing the
  difference.

    TCADFNCGraphics -> TTMSFNCGraphicsPDFEngine -> TTMSFNCPDFLib -> file

  There is no PDF-specific drawing code in this unit and there should
  never be any. Everything it does is arrange the pipe and turn the
  pages. That also means a PDF, a preview and a printed sheet come from
  one renderer rather than three, which is the property the page model
  was built for.

  It is not a new dependency either: the library already requires FNC
  Core. Hand-rolling a PDF writer was considered and would have been
  about eight hundred lines to arrive somewhere worse.

  WHY THE DRAWING IS LAID OUT AT 600 DPI AND THEN SCALED

  PDF measures in points, 72 to the inch, and the drawing layer works
  in integer device coordinates. Laid out directly in points, every
  endpoint would land on a 1/72 inch grid - a third of a millimetre -
  coarse enough to see on a CAD drawing and absurd on a plotter. So the
  page is laid out at <See Variable=CADPDFResolution> dots per inch and
  scaled to points on the way out. The output is vector either way;
  this only decides how finely the numbers going into it are rounded.

  AND WHY THAT TAKES TWO STEPS RATHER THAN ONE

  A transform alone is not enough, and the first attempt at this
  produced twenty-six blank pages.

  FNC's PDF graphics library turns the top-left origin the rest of FNC
  uses into PDF's bottom-left one **in Pascal**, per drawing call, as
  <I=FPageHeight - Y>. Its FPageHeight is in points. Hand it a Y in
  600 dpi dots and the subtraction mixes two units: a page 842 points
  tall against a Y up to 7016, giving coordinates thousands of points
  below the paper. No transform can repair that afterwards, because the
  damage is done before the transform is reached - the content stream
  came out reading <I=0.5 -3960.61 m>, which is exactly what it looked
  like on the page.

  So the page height the graphics library subtracts from is set in the
  same dots the drawing is laid out in, through
  ITMSFNCCustomPDFInitializationLib, and the transform then scales the
  result:

    s * (Hdots - Ydots) = Hpoints - s * Ydots     where s = 72/dpi

  which is the right answer with both halves in step. If that interface
  is ever not supported, the code falls back to laying out at 72 dpi,
  where no conversion is needed and the only cost is the rounding.

  FONTS

  TrueType fonts are embedded, subset to the characters used, while
  <See Variable=CADPDFEmbedFonts> is True (the default); a PDF without
  them is smaller and shows in whatever the reader has instead. A font
  the computer does not have is replaced by the first of
  <See Variable=CADPDFFontFallbacks> that it does have, and that one is
  embedded. With none of those either, the name is written as asked
  and nothing is embedded for it, and the reader substitutes.

  LINKS

  CADSaveSheetsToPDF takes an optional function that gives each sheet's
  link areas - rectangles in the sheet's millimetres with a URL each -
  and puts a link annotation on the page for each.

  FNC's PDF library offers a link only over text it draws itself
  (AddURL: the annotation is the text's own bounds), and the routine
  underneath that would take a rectangle lives in the implementation
  section of its unit, out of reach. So the links are added after the
  file is written, as a PDF incremental update
  (<See Procedure=CADAddPDFLinks>): the annotations and the changed
  page dictionaries are appended with a cross-reference section of
  their own, and the original bytes are not touched. Every reader
  applies an incremental update - it is how a PDF is signed or
  annotated in place. Annotations are in points, measured up from the
  bottom of the page as the sheet is, and not under the page transform
  the drawing is scaled by. }
unit VCL.FNCCS4PDF;

{$I VCL.FNCCADSys.inc}

interface

uses
{$IFDEF CADSYS_LCL}
  Classes, SysUtils, Types, Math,
{$ELSE}
  System.Classes, System.SysUtils, System.Types, System.Math,
{$ENDIF}
{$IFDEF CADSYS_FMX}
  FMX.TMSFNCTypes, FMX.TMSFNCGraphicsTypes, FMX.TMSFNCGraphics,
  FMX.TMSFNCPDFLib, FMX.TMSFNCPDFGraphicsLib, FMX.TMSFNCGraphicsPDFEngine,
{$ENDIF}
{$IFDEF CADSYS_LCL}
  LCLTMSFNCTypes, LCLTMSFNCGraphicsTypes, LCLTMSFNCGraphics,
  LCLTMSFNCPDFLib, LCLTMSFNCPDFGraphicsLib, LCLTMSFNCGraphicsPDFEngine,
{$ENDIF}
{$IFDEF CADSYS_VCL}
  VCL.TMSFNCTypes, VCL.TMSFNCGraphicsTypes, VCL.TMSFNCGraphics,
  VCL.TMSFNCPDFLib, VCL.TMSFNCPDFGraphicsLib, VCL.TMSFNCGraphicsPDFEngine,

{$ENDIF}
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4GraphicsFNC,
  VCL.FNCCADSys4, VCL.FNCCS4Views, VCL.FNCCS4Print;

const
  { : PDF's unit is the point, 72 to the inch. }
  CADPDFPointsPerMM = 72 / 25.4;

var
  { : Dots per inch the page is laid out at before the PDF transform
    scales it to points. See the unit header.

    Six hundred, which puts the rounding at four hundredths of a
    millimetre - below what a plotter can draw and well below what
    anyone can see. Raising it costs nothing in file size, because the
    numbers are scaled down again before they are written.

    Set it to 72 to take the transform out of the picture entirely and
    lay the page out directly in points. That is the fallback the code
    takes on its own if FNC's initialization interface is ever missing,
    and it is the first thing to try if a PDF comes out wrong. }
  CADPDFResolution: Integer = 600;

  { : Whether TrueType fonts are embedded (subset) - see FONTS above.
    Read when a document is started. }
  CADPDFEmbedFonts: Boolean = True;

  { : Fonts tried, in order, for a font the computer does not have,
    separated by commas - see FONTS above. Read when a document is
    started; '' for none. }
  CADPDFFontFallbacks: String = 'Arial,Liberation Sans,DejaVu Sans,Helvetica';

type
  { : The FNC backend with a clip that actually clips.

    TTMSFNCGraphicsPDFEngine.ClipRect does this:

      DrawPathAddRectangle(ARect);   -> 're'
      DrawPathBeginClip;             -> 'n'
      DrawPathBegin;                 -> 'n'

    and 'n' means "end the path and paint nothing". The operator that
    turns a path into a clip is 'W', which FNC writes in
    DrawPathEndClip - and the engine never calls it. So the rectangle
    is built, discarded, and nothing is clipped.

    The symptom is not subtle once you know: every sheet of a tiled
    drawing carries the whole drawing, running over the margins and off
    the paper. It was found by printing the same drawing through the
    printer and through here and diffing the two PDFs' coordinates -
    every difference came out as exactly one margin, 28.3 points, which
    is what an unclipped page looks like next to a clipped one.

    Driving the PDF library directly is enough, because it has all the
    pieces: q, then the rectangle, then W n, and Q to give it back.

    If a future FNC Core calls DrawPathEndClip from ClipRect, this
    override becomes harmless duplication rather than a wrong answer -
    the clip would simply be set twice to the same rectangle. It is
    still worth deleting then.

    AND DASHES THAT ARE DASHES ON PAPER

    FNC's PDF writer puts a fixed pattern on a dashed stroke - '[4] 1 d'
    for a dash - in the page's own units. Here those are 600 dpi dots,
    so a dash came out a sixth of a millimetre long whatever the pen:
    on paper a dashed line was a solid one. So a dashed pen is drawn
    here as solid pieces, laid out by CADDashPattern and
    CADDashSegments - the pattern the SVG and the metafile use, which
    scales with the pen's width. A filled shape with a dashed outline is
    filled first with no pen, then outlined.

    GRADIENTS (CS-12)

    FNC writes a gradient as a PDF shading pattern, and a pattern lives
    in the page's default space - points - whatever transform is in
    force where it is used. FNC gives it the shape's box in 600 dpi
    dots, with no /Matrix and without extending it, so the blend lay
    eight times too far out and the shape was not painted at all. The
    routine that writes the pattern is in FNC's implementation section.
    So a gradient is drawn here as bands of solid colour, one per step
    of the largest colour difference and at most 256, inside the shape
    as a clip path - the shape's own outline, not its box - and the
    outline goes over it with nothing to fill. On paper that is a
    gradient. Opaque bands overlap by a dot, so that a reader's
    anti-aliasing leaves no seams between them.

    TURNED TEXT (CS-13)

    FNC's PDF engine turns text about its rectangle's centre, flipped
    against the MediaBox height - in points - while the centre is in
    dots and the library flips everything else against the page height
    in dots. At 72 dpi the two heights agree; at 600 dpi turned text
    landed mid-page or off the paper. So the turn is done here: q, a
    rotation about the centre of the caller's rectangle in the page's
    own (dotted, flipped) space, the text drawn level in the box FNC
    would have laid it out in (CADRotatedTextRect), Q. Drawn level, FNC
    cuts a line longer than its box short where turned it lets it run
    on, so the box is opened out on the side or sides the alignment
    lets the text grow towards, and the text kept to one line, as FNC
    keeps turned text. That needs the
    page height the library flips against, which the save routines set
    as PageHeight; with none set the engine's own path is used.

    TRANSLUCENT COLOURS (CS-21)

    FNC's PDF library writes no transparency: the engine is given the
    colour's opacity and nothing reaches the file, so a fill at 22 % came
    out solid. PDF keeps it in a graphics state. So a shape, line or text
    whose colour has alpha is drawn inside q ... Q with its state selected
    by gs - /CADfAA for a fill or text (/ca) and /CADsAA for a pen (/CA),
    AA the alpha in hex, one of each per alpha - and an opaque one exactly
    as before. A gradient's alpha is worked out per band, so its bands do
    not overlap unless both colours are opaque.

    Neither half has a public way in. The operator has to go into the
    page's content stream as it is written, and the library's writer is
    the private field FOutput of the graphics library, reached through
    RTTI (PDFLibWriter). If a new FNC Core renames it there is no writer,
    and colours come out opaque as they did before: TCADPDFAlphaTests is
    what notices. The resources are added after the file is written, in
    the same incremental update as the links (PDFUpdatePages), because a
    page's resources are written before its content is known. }
  TCADPDFGraphics = class(TCADFNCGraphics)
  private
    fLib: ITMSFNCCustomPDFGraphicsLib;
    fCur: TPoint;
    fPageHeight: Single;
    fFontSpec: TCADFontSpec;
    fHaveFont: Boolean;
    fWriter: TObject;
    fFillAlphas, fPenAlphas: set of Byte;
    function BrushAlpha: Byte;
    function PenAlpha: Byte;
    function BeginAlpha(const AFill, APen: Byte): Boolean;
    procedure EndAlpha(const AActive: Boolean);
    procedure PlainPolygon(const Pts: Pointer; const Count: Integer);
    procedure PlainRectangle(const X1, Y1, X2, Y2: Integer);
    procedure PlainEllipse(const X1, Y1, X2, Y2: Integer);
    procedure PlainFillRect(const R: TRect);
    function PlainText(const Text: string; var R: TRect;
      const Flags: Cardinal): Integer;
    function Dashes: TCADDashPattern;
    procedure StrokeDashed(const APts: array of TPoint; const AClosed: Boolean;
      const APattern: TCADDashPattern);
    function GradientActive: Boolean;
    procedure GradientFill(const APts: array of TPoint;
      const AEllipse: Boolean; const ABox: TRect);
  protected
    procedure DoPushClip(const R: TRect); override;
    procedure DoPopClip; override;
  public
    { Public, as in TCADFNCGraphics. }
    procedure DoPolygon(const Pts: Pointer; const Count: Integer); override;
    procedure DoRectangle(const X1, Y1, X2, Y2: Integer); override;
    procedure DoEllipse(const X1, Y1, X2, Y2: Integer); override;
    procedure DoFillRect(const R: TRect); override;
    constructor CreateForPDF(const ALib: ITMSFNCCustomPDFGraphicsLib);
    procedure SelectFont(const Font: TCADFontSpec); override;
    procedure ResetFont; override;
    function DrawText(const Text: string; var R: TRect;
      const Flags: Cardinal): Integer; override;
    { : The page height the PDF library flips Y against, in the units
      the page is drawn in - set per page by the save routines. 0 leaves
      turned text to FNC's engine. }
    property PageHeight: Single read fPageHeight write fPageHeight;
    { : The graphics states drawn with so far, as the inside of a page's
      /ExtGState dictionary; '' for none. See TRANSLUCENT COLOURS. }
    function ExtGStates: String;
    procedure MoveTo(const X, Y: Integer); override;
    procedure LineTo(const X, Y: Integer); override;
    procedure Polyline(const Pts: Pointer; const Count: Integer); overload;
      override;
  end;

  { : One link area on a sheet: RectMM in the sheet's millimetres,
    origin at the bottom-left corner of the paper and Y upwards - the
    coordinates of CADSheetPointToMM - and the URL it opens. }
  TCADPDFLink = record
    RectMM: TRect2D;
    URL: String;
    class function Create(const ARectMM: TRect2D; const AURL: String)
      : TCADPDFLink; static;
  end;

  TCADPDFLinks = TArray<TCADPDFLink>;

  { : The link areas of ASheet, the AIndex-th of the sheets being
    written. Called once per sheet, after it is drawn. }
  TCADPDFSheetLinksFunc = reference to function(const ASheet: TCADSheet;
    const AIndex: Integer): TCADPDFLinks;

{ : The page device a PDF is drawn with. Public because a caller that
  wants to check what the numbers will be should not have to guess. }
function CADPDFPageDevice: TCADPageDevice;

{ : Writes ASetup's pages of ACAD to AFileName as a PDF.

  ALastPage of -1 means "to the end". The paper size goes in as a
  custom size in points rather than one of FNC's presets, so the page
  model stays the only place that knows how big A3 is - two tables of
  paper sizes would eventually disagree, and the one that was wrong
  would be the one nobody printed from.

  Orientation is already applied by the page model, which is why the
  document is always portrait: the sheet has been swapped, so saying
  landscape as well would swap it back. }
procedure CADSavePagesToPDF(const ACAD: TFNCCADCmp2D;
  const ASetup: TCADPageSetup; const AFileName: String;
  const AFirstPage: Integer = 0; const ALastPage: Integer = -1);

{ : Writes sheets - paper space - to AFileName, one sheet to a page.

  ALastSheet of -1 means "to the end".

  Unlike the printer, this handles sheets that disagree about paper
  size or orientation: the page size is set per page, so an A3
  landscape sheet and an A4 portrait one can sit in the same document.
  That is the same custom-size-in-points arrangement CADSavePagesToPDF
  uses, applied once per sheet rather than once per document. }
procedure CADSaveSheetsToPDF(const ACAD: TFNCCADCmp2D;
  const ASheets: TCADSheets; const AFileName: String;
  const AFirstSheet: Integer = 0; const ALastSheet: Integer = -1;
  const ALinks: TCADPDFSheetLinksFunc = nil);

{ : Writes ASheet tiled onto ATiling's paper at full size - one page per
  tile, with its marks - so that the tiles can be checked and sent without
  a printer. See TCADSheetTiling. }
procedure CADSaveSheetTiledToPDF(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const ATiling: TCADSheetTiling;
  const AFileName: String);

{ : Adds link annotations to a PDF already written: APageLinks[I] go on
  page I, counted from zero in document order, their rectangles in
  millimetres from the page's bottom-left corner. An incremental update
  - see LINKS above. Raises ECADPageError for a file it cannot follow
  (a cross-reference stream, or annotations kept in an object of their
  own), leaving the file as it was. }
procedure CADAddPDFLinks(const AFileName: String;
  const APageLinks: array of TCADPDFLinks);

implementation

{$IFNDEF CADSYS_LCL}
uses
  System.RegularExpressions, System.Rtti,
{$IFDEF CADSYS_FMX}
  FMX.TMSFNCPDFCoreLibBase;
{$ELSE}
  VCL.TMSFNCPDFCoreLibBase;
{$ENDIF}
{$ENDIF}

{ : Adds to a PDF already written, as one incremental update: APageLinks[I]
  on page I and, when AExtGStates is not empty, those graphics states on
  every page. See LINKS and TRANSLUCENT COLOURS. }
procedure PDFUpdatePages(const AFileName: String;
  const APageLinks: array of TCADPDFLinks; const AExtGStates: String); forward;

class function TCADPDFLink.Create(const ARectMM: TRect2D;
  const AURL: String): TCADPDFLink;
begin
  Result.RectMM := ARectMM;
  Result.URL := AURL;
end;

{ : The settings a document takes when it is started - see FONTS. }
procedure ConfigurePDF(const APDF: TTMSFNCPDFLib);
var
  TmpList: TStringList;
begin
  APDF.EmbedFonts := CADPDFEmbedFonts;
  TmpList := TStringList.Create;
  try
    TmpList.StrictDelimiter := True;
    TmpList.Delimiter := ',';
    TmpList.DelimitedText := CADPDFFontFallbacks;
    APDF.FontFallBackList.Assign(TmpList);
  finally
    TmpList.Free;
  end;
end;

constructor TCADPDFGraphics.CreateForPDF
  (const ALib: ITMSFNCCustomPDFGraphicsLib);
begin
  { Detached, like the preview's: until something is attached every
    drawing call is a no-op. }
  inherited Create(nil, Rect(0, 0, 0, 0));
  fLib := ALib;
end;

function TCADPDFGraphics.BrushAlpha: Byte;
begin
  Result := CADColorAlpha(Brush.Color);
  { Nothing painted, so nothing to carry: FNC is told so already. }
  if (Brush.Style = cbsClear) or (Result = 0) then
    Result := 255;
end;

function TCADPDFGraphics.PenAlpha: Byte;
begin
  Result := CADColorAlpha(Pen.Color);
  if (Pen.Mode <> cpmCopy) or (Pen.Style = cpsClear) or (Result = 0) then
    Result := 255;
end;

{ : The library's writer - see TRANSLUCENT COLOURS. nil when it cannot be
  reached, which leaves colours opaque. }
function PDFLibWriter(const ALib: ITMSFNCCustomPDFGraphicsLib): TObject;
{$IFNDEF CADSYS_LCL}
var
  TmpContext: TRttiContext;
  TmpField: TRttiField;
{$ENDIF}
begin
  Result := nil;
{$IFNDEF CADSYS_LCL}
  TmpField := TmpContext.GetType((ALib as TObject).ClassType)
    .GetField('FOutput');
  if TmpField <> nil then
  begin
    Result := TmpField.GetValue(ALib as TObject).AsObject;
    if not(Result is TTMSFNCPDFGraphicsLibOutputWriter) then
      Result := nil;
  end;
{$ENDIF}
end;

function TCADPDFGraphics.BeginAlpha(const AFill, APen: Byte): Boolean;
begin
  Result := False;
  if (fLib = nil) or (FNCGraphics = nil) or
    ((AFill = 255) and (APen = 255)) then
    Exit;
  { Looked for here, not when created: the document makes it. }
  if fWriter = nil then
    fWriter := PDFLibWriter(fLib);
  if fWriter = nil then
    Exit;
{$IFNDEF CADSYS_LCL}
  fLib.DrawSaveState;
  if AFill < 255 then
  begin
    Include(fFillAlphas, AFill);
    TTMSFNCPDFGraphicsLibOutputWriter(fWriter).WriteString('/CADf' +
      IntToHex(Integer(AFill), 2) + ' gs'#13#10);
  end;
  if APen < 255 then
  begin
    Include(fPenAlphas, APen);
    TTMSFNCPDFGraphicsLibOutputWriter(fWriter).WriteString('/CADs' +
      IntToHex(Integer(APen), 2) + ' gs'#13#10);
  end;
  Result := True;
{$ENDIF}
end;

procedure TCADPDFGraphics.EndAlpha(const AActive: Boolean);
begin
  if AActive then
    fLib.DrawRestoreState;
end;

function TCADPDFGraphics.ExtGStates: String;

  { Worked out in whole numbers, so that no locale's decimal comma gets
    into the file. An alpha here is below 255, so it is below one. }
  function Num(const AAlpha: Integer): String;
  begin
    Result := Format('0.%.4d', [AAlpha * 10000 div 255]);
  end;

var
  I: Integer;
begin
  Result := '';
  for I := 0 to 254 do
  begin
    if I in fFillAlphas then
      Result := Result + '/CADf' + IntToHex(I, 2) + '<</Type/ExtGState/ca ' +
        Num(I) + '>>';
    if I in fPenAlphas then
      Result := Result + '/CADs' + IntToHex(I, 2) + '<</Type/ExtGState/CA ' +
        Num(I) + '>>';
  end;
end;

procedure TCADPDFGraphics.PlainPolygon(const Pts: Pointer;
  const Count: Integer);
var
  TmpActive: Boolean;
begin
  TmpActive := BeginAlpha(BrushAlpha, PenAlpha);
  try
    inherited DoPolygon(Pts, Count);
  finally
    EndAlpha(TmpActive);
  end;
end;

procedure TCADPDFGraphics.PlainRectangle(const X1, Y1, X2, Y2: Integer);
var
  TmpActive: Boolean;
begin
  TmpActive := BeginAlpha(BrushAlpha, PenAlpha);
  try
    inherited DoRectangle(X1, Y1, X2, Y2);
  finally
    EndAlpha(TmpActive);
  end;
end;

procedure TCADPDFGraphics.PlainEllipse(const X1, Y1, X2, Y2: Integer);
var
  TmpActive: Boolean;
begin
  TmpActive := BeginAlpha(BrushAlpha, PenAlpha);
  try
    inherited DoEllipse(X1, Y1, X2, Y2);
  finally
    EndAlpha(TmpActive);
  end;
end;

procedure TCADPDFGraphics.PlainFillRect(const R: TRect);
var
  TmpActive: Boolean;
begin
  TmpActive := BeginAlpha(BrushAlpha, 255);
  try
    inherited DoFillRect(R);
  finally
    EndAlpha(TmpActive);
  end;
end;

function TCADPDFGraphics.PlainText(const Text: string; var R: TRect;
  const Flags: Cardinal): Integer;
var
  TmpAlpha: Byte;
  TmpTransparent, TmpActive: Boolean;
begin
  TmpAlpha := CADColorAlpha(FontColor);
  if (TmpAlpha = 255) or ((Flags and CAD_DT_CALCRECT) <> 0) then
  begin
    Result := inherited DrawText(Text, R, Flags);
    Exit;
  end;
  { The text's alpha is not the background's: that goes first, by itself. }
  TmpTransparent := Transparent;
  if not TmpTransparent then
    FillRect(R);
  Transparent := True;
  TmpActive := BeginAlpha(TmpAlpha, 255);
  try
    Result := inherited DrawText(Text, R, Flags);
  finally
    EndAlpha(TmpActive);
    Transparent := TmpTransparent;
  end;
end;

procedure TCADPDFGraphics.DoPushClip(const R: TRect);
begin
  if fLib = nil then
  begin
    inherited DoPushClip(R);
    Exit;
  end;
  { The rectangle goes in in device dots and the library flips it
    against the page height it was given - the same page height the
    drawing is laid out in, which is what makes the two agree. }
  fLib.DrawSaveState;
  fLib.DrawPathBeginClip;
  fLib.DrawPathAddRectangle(RectF(R.Left, R.Top, R.Right, R.Bottom));
  fLib.DrawPathEndClip;
end;

function TCADPDFGraphics.Dashes: TCADDashPattern;
begin
  SetLength(Result, 0);
  if (fLib = nil) or (Pen.Mode = cpmNop) or (CADColorAlpha(Pen.Color) = 0) then
    Exit;
  Result := CADDashPattern(Pen.Style, Pen.Width, PixelsPerMM);
end;

procedure TCADPDFGraphics.StrokeDashed(const APts: array of TPoint;
  const AClosed: Boolean; const APattern: TCADDashPattern);
var
  TmpSegs: TCADHatchSegments;
  TmpStyle: TCADPenStyle;
  I: Integer;
begin
  TmpSegs := CADDashSegments(APts, AClosed, APattern);
  TmpStyle := Pen.Style;
  { Solid for the pieces - which also sends Polyline below straight to
    the inherited one. }
  Pen.Style := cpsSolid;
  try
    for I := 0 to High(TmpSegs) do
      Polyline([TmpSegs[I].P1, TmpSegs[I].P2]);
  finally
    Pen.Style := TmpStyle;
  end;
end;

procedure TCADPDFGraphics.SelectFont(const Font: TCADFontSpec);
begin
  fFontSpec := Font;
  fHaveFont := True;
  inherited SelectFont(Font);
{$IFNDEF CADSYS_FMX}
  { FNC's PDF engine takes the font's Size, in the page's own units -
    and a VCL or LCL font's Size is its pixel height turned into points
    at whatever pixels per inch the font was made with: three quarters
    of it at 96, under a third on a 240 dpi screen. The text came out
    that much too small. On FMX the size already is the pixel height.
    So here it is set to the height in pixels - the page's units - which
    is what everything else on the page is measured in. }
  if (fLib <> nil) and (FNCGraphics <> nil) then
    FNCGraphics.Font.Size := Max(1,
      Round(CADFontHeightToFNCSize(Font.Height) * 96 / 72));
{$ENDIF}
end;

procedure TCADPDFGraphics.MoveTo(const X, Y: Integer);
begin
  fCur := Point(X, Y);
  inherited MoveTo(X, Y);
end;

procedure TCADPDFGraphics.LineTo(const X, Y: Integer);
var
  TmpDashes: TCADDashPattern;
  TmpActive: Boolean;
begin
  TmpDashes := Dashes;
  if Length(TmpDashes) = 0 then
  begin
    TmpActive := BeginAlpha(255, PenAlpha);
    try
      inherited LineTo(X, Y);
    finally
      EndAlpha(TmpActive);
    end;
  end
  else
  begin
    StrokeDashed([fCur, Point(X, Y)], False, TmpDashes);
    inherited MoveTo(X, Y);
  end;
  fCur := Point(X, Y);
end;

procedure TCADPDFGraphics.Polyline(const Pts: Pointer; const Count: Integer);
var
  TmpDashes: TCADDashPattern;
  TmpPts: array of TPoint;
  TmpActive: Boolean;
  I: Integer;
begin
  if (Pts = nil) or (Count <= 0) then
    Exit;
  TmpDashes := Dashes;
  if Length(TmpDashes) = 0 then
  begin
    TmpActive := BeginAlpha(255, PenAlpha);
    try
      inherited Polyline(Pts, Count);
    finally
      EndAlpha(TmpActive);
    end;
  end
  else
  begin
    SetLength(TmpPts, Count);
    for I := 0 to Count - 1 do
      TmpPts[I] := PCADPoints(Pts)^[I];
    StrokeDashed(TmpPts, False, TmpDashes);
    inherited MoveTo(TmpPts[Count - 1].X, TmpPts[Count - 1].Y);
  end;
  fCur := PCADPoints(Pts)^[Count - 1];
end;

procedure TCADPDFGraphics.DoPolygon(const Pts: Pointer; const Count: Integer);
var
  TmpStyle: TCADPenStyle;
  TmpBrush: TCADBrushStyle;
  TmpDashes: TCADDashPattern;
  TmpPts: array of TPoint;
  TmpBox: TRect;
  I: Integer;
begin
  if GradientActive and (Pts <> nil) and (Count > 2) then
  begin
    SetLength(TmpPts, Count);
    TmpBox := Rect(PCADPoints(Pts)^[0].X, PCADPoints(Pts)^[0].Y,
      PCADPoints(Pts)^[0].X, PCADPoints(Pts)^[0].Y);
    for I := 0 to Count - 1 do
    begin
      TmpPts[I] := PCADPoints(Pts)^[I];
      TmpBox.Left := Min(TmpBox.Left, TmpPts[I].X);
      TmpBox.Top := Min(TmpBox.Top, TmpPts[I].Y);
      TmpBox.Right := Max(TmpBox.Right, TmpPts[I].X);
      TmpBox.Bottom := Max(TmpBox.Bottom, TmpPts[I].Y);
    end;
    GradientFill(TmpPts, False, TmpBox);
    { The outline, dashed or not, with nothing to fill. }
    TmpBrush := Brush.Style;
    Brush.Style := cbsClear;
    try
      DoPolygon(Pts, Count);
    finally
      Brush.Style := TmpBrush;
    end;
    Exit;
  end;
  TmpDashes := Dashes;
  if (Length(TmpDashes) = 0) or (Pts = nil) or (Count <= 0) then
  begin
    PlainPolygon(Pts, Count);
    Exit;
  end;
  { The fill alone, then the dashed outline. }
  TmpStyle := Pen.Style;
  Pen.Style := cpsClear;
  try
    PlainPolygon(Pts, Count);
  finally
    Pen.Style := TmpStyle;
  end;
  SetLength(TmpPts, Count);
  for I := 0 to Count - 1 do
    TmpPts[I] := PCADPoints(Pts)^[I];
  StrokeDashed(TmpPts, True, TmpDashes);
end;

procedure TCADPDFGraphics.DoRectangle(const X1, Y1, X2, Y2: Integer);
var
  TmpStyle: TCADPenStyle;
  TmpBrush: TCADBrushStyle;
  TmpDashes: TCADDashPattern;
  TmpBox: TRect;
begin
  if GradientActive then
  begin
    TmpBox := Rect(Min(X1, X2), Min(Y1, Y2), Max(X1, X2), Max(Y1, Y2));
    { X2 and Y2 exclusive, as the FNC backend draws them. }
    GradientFill([TmpBox.TopLeft, Point(TmpBox.Right - 1, TmpBox.Top),
      Point(TmpBox.Right - 1, TmpBox.Bottom - 1),
      Point(TmpBox.Left, TmpBox.Bottom - 1)], False, TmpBox);
    TmpBrush := Brush.Style;
    Brush.Style := cbsClear;
    try
      DoRectangle(X1, Y1, X2, Y2);
    finally
      Brush.Style := TmpBrush;
    end;
    Exit;
  end;
  TmpDashes := Dashes;
  if Length(TmpDashes) = 0 then
  begin
    PlainRectangle(X1, Y1, X2, Y2);
    Exit;
  end;
  { The fill alone, then the dashed outline. }
  TmpStyle := Pen.Style;
  Pen.Style := cpsClear;
  try
    PlainRectangle(X1, Y1, X2, Y2);
  finally
    Pen.Style := TmpStyle;
  end;
  { X2 and Y2 exclusive, as the FNC backend draws them. }
  StrokeDashed([Point(X1, Y1), Point(X2 - 1, Y1), Point(X2 - 1, Y2 - 1),
    Point(X1, Y2 - 1)], True, TmpDashes);
end;

procedure TCADPDFGraphics.DoEllipse(const X1, Y1, X2, Y2: Integer);
var
  TmpStyle: TCADPenStyle;
  TmpBrush: TCADBrushStyle;
  TmpDashes: TCADDashPattern;
  TmpPts: array of TPoint;
  TmpCX, TmpCY, TmpRX, TmpRY: Double;
  I, TmpN: Integer;
begin
  if GradientActive then
  begin
    GradientFill([], True, Rect(Min(X1, X2), Min(Y1, Y2), Max(X1, X2),
      Max(Y1, Y2)));
    TmpBrush := Brush.Style;
    Brush.Style := cbsClear;
    try
      DoEllipse(X1, Y1, X2, Y2);
    finally
      Brush.Style := TmpBrush;
    end;
    Exit;
  end;
  TmpDashes := Dashes;
  if Length(TmpDashes) = 0 then
  begin
    PlainEllipse(X1, Y1, X2, Y2);
    Exit;
  end;
  { The fill alone, then the dashed outline. }
  TmpStyle := Pen.Style;
  Pen.Style := cpsClear;
  try
    PlainEllipse(X1, Y1, X2, Y2);
  finally
    Pen.Style := TmpStyle;
  end;
  TmpCX := (X1 + X2 - 1) / 2;
  TmpCY := (Y1 + Y2 - 1) / 2;
  TmpRX := Abs(X2 - 1 - X1) / 2;
  TmpRY := Abs(Y2 - 1 - Y1) / 2;
  { A point every two millimetres or so of outline at 600 dpi, and
    never fewer than 32. }
  TmpN := Max(32, Round(Pi * (TmpRX + TmpRY) / 48));
  SetLength(TmpPts, TmpN);
  for I := 0 to TmpN - 1 do
    TmpPts[I] := Point(Round(TmpCX + TmpRX * Cos(2 * Pi * I / TmpN)),
      Round(TmpCY + TmpRY * Sin(2 * Pi * I / TmpN)));
  StrokeDashed(TmpPts, True, TmpDashes);
end;

procedure TCADPDFGraphics.DoFillRect(const R: TRect);
begin
  if GradientActive then
  begin
    GradientFill([R.TopLeft, Point(R.Right, R.Top), R.BottomRight,
      Point(R.Left, R.Bottom)], False, R);
    Exit;
  end;
  PlainFillRect(R);
end;

function TCADPDFGraphics.GradientActive: Boolean;
begin
  Result := (fLib <> nil) and (Brush.Style = cbsGradient) and
    ((CADColorAlpha(Brush.Color) <> 0) or (CADColorAlpha(Brush.Color2) <> 0));
end;

procedure TCADPDFGraphics.GradientFill(const APts: array of TPoint;
  const AEllipse: Boolean; const ABox: TRect);

  function Channel(const AColor: TCADColor; const AShift: Integer): Integer;
  begin
    Result := (AColor shr AShift) and $FF;
  end;

var
  TmpFrom, TmpTo, TmpSaved: TCADColor;
  TmpStyle: TCADBrushStyle;
  TmpExtent, TmpN, TmpDiff, TmpOverlap, TmpA, TmpB, I: Integer;
  T: Double;
  TmpBand: TRect;
begin
  TmpFrom := Brush.Color;
  TmpTo := Brush.Color2;
  if Brush.GradientVertical then
    TmpExtent := ABox.Bottom - ABox.Top
  else
    TmpExtent := ABox.Right - ABox.Left;
  if TmpExtent <= 0 then
    Exit;
  { A band per step of the channel that changes most - more could not
    be told apart - and never thinner than a dot. }
  TmpDiff := Max(Max(Max(Abs(Channel(TmpFrom, 16) - Channel(TmpTo, 16)),
    Abs(Channel(TmpFrom, 8) - Channel(TmpTo, 8))),
    Abs(Channel(TmpFrom, 0) - Channel(TmpTo, 0))),
    Abs(Channel(TmpFrom, 24) - Channel(TmpTo, 24)));
  TmpN := Max(1, Min(TmpExtent, Min(256, TmpDiff + 1)));
  { Opaque bands overlap by a dot so that no seam shows between them;
    translucent ones must not, or the overlap would show darker. }
  if (CADColorAlpha(TmpFrom) = 255) and (CADColorAlpha(TmpTo) = 255) then
    TmpOverlap := 1
  else
    TmpOverlap := 0;

  fLib.DrawSaveState;
  try
    fLib.DrawPathBeginClip;
    if AEllipse then
      fLib.DrawPathAddEllipse(RectF(ABox.Left, ABox.Top, ABox.Right - 1,
        ABox.Bottom - 1))
    else if Length(APts) > 2 then
    begin
      fLib.DrawPathMoveToPoint(PointF(APts[0].X, APts[0].Y));
      for I := 1 to High(APts) do
        fLib.DrawPathAddLineToPoint(PointF(APts[I].X, APts[I].Y));
      fLib.DrawPathClose;
    end
    else
      fLib.DrawPathAddRectangle(RectF(ABox.Left, ABox.Top, ABox.Right,
        ABox.Bottom));
    fLib.DrawPathEndClip;

    TmpStyle := Brush.Style;
    TmpSaved := Brush.Color;
    try
      Brush.Style := cbsSolid;
      for I := 0 to TmpN - 1 do
      begin
        if TmpN = 1 then
          T := 0
        else
          T := I / (TmpN - 1);
        { The alpha too: on paper a band can carry its own (CS-21). }
        Brush.Color := TCADColor((Cardinal(Round(Channel(TmpFrom, 24) + T *
          (Channel(TmpTo, 24) - Channel(TmpFrom, 24)))) shl 24) or
          (Round(Channel(TmpFrom, 16) + T * (Channel(TmpTo, 16) -
          Channel(TmpFrom, 16))) shl 16) or
          (Round(Channel(TmpFrom, 8) + T * (Channel(TmpTo, 8) -
          Channel(TmpFrom, 8))) shl 8) or
          Round(Channel(TmpFrom, 0) + T * (Channel(TmpTo, 0) -
          Channel(TmpFrom, 0))));
        TmpA := Round(TmpExtent * I / TmpN);
        TmpB := Round(TmpExtent * (I + 1) / TmpN);
        if I < TmpN - 1 then
          Inc(TmpB, TmpOverlap);
        if Brush.GradientVertical then
          TmpBand := Rect(ABox.Left, ABox.Top + TmpA, ABox.Right,
            ABox.Top + TmpB)
        else
          TmpBand := Rect(ABox.Left + TmpA, ABox.Top, ABox.Left + TmpB,
            ABox.Bottom);
        PlainFillRect(TmpBand);
      end;
    finally
      Brush.Color := TmpSaved;
      Brush.Style := TmpStyle;
    end;
  finally
    fLib.DrawRestoreState;
  end;
end;

procedure TCADPDFGraphics.ResetFont;
begin
  fHaveFont := False;
  inherited ResetFont;
end;

function TCADPDFGraphics.DrawText(const Text: string; var R: TRect;
  const Flags: Cardinal): Integer;
const
  { Room for any line on any paper, in dots. }
  BIG = 100000;
var
  TmpSpec, TmpLevelSpec: TCADFontSpec;
  TmpFlags: Cardinal;
  TmpLevel: TRect;
  TmpAngle, TmpC, TmpS, TmpCX, TmpCY: Double;
  TmpTransparent: Boolean;
begin
  if (fLib = nil) or (fPageHeight <= 0) or not fHaveFont or
    (fFontSpec.Escapement = 0) or ((Flags and CAD_DT_CALCRECT) <> 0) then
  begin
    Result := PlainText(Text, R, Flags);
    Exit;
  end;
  TmpSpec := fFontSpec;
  TmpAngle := TmpSpec.Escapement / 10;
  { The background, as the engine would have filled it: level. }
  if not Transparent then
    FillRect(R);
  TmpLevel := CADRotatedTextRect(R, TmpAngle);
  { One line, free to run past the box the way the alignment says. }
  TmpFlags := (Flags and not CAD_DT_WORDBREAK) or CAD_DT_SINGLELINE;
  if (Flags and CAD_DT_CENTER) <> 0 then
  begin
    Dec(TmpLevel.Left, BIG);
    Inc(TmpLevel.Right, BIG);
  end
  else if (Flags and CAD_DT_RIGHT) <> 0 then
    Dec(TmpLevel.Left, BIG)
  else
    Inc(TmpLevel.Right, BIG);
  { The centre in the library's flipped space: X as it is, Y measured up
    from the bottom of the page - in dots, under the page transform. }
  TmpCX := (R.Left + R.Right) / 2;
  TmpCY := fPageHeight - (R.Top + R.Bottom) / 2;
  TmpC := Cos(DegToRad(TmpAngle));
  TmpS := Sin(DegToRad(TmpAngle));
  TmpTransparent := Transparent;
  fLib.DrawSaveState;
  try
    { Counter-clockwise about the centre, as LOGFONT's escapement is. }
    fLib.DrawSetTransform(TmpC, TmpS, -TmpS, TmpC,
      TmpCX - TmpC * TmpCX + TmpS * TmpCY,
      TmpCY - TmpS * TmpCX - TmpC * TmpCY);
    TmpLevelSpec := TmpSpec;
    TmpLevelSpec.Escapement := 0;
    SelectFont(TmpLevelSpec);
    Transparent := True;
    PlainText(Text, TmpLevel, TmpFlags);
  finally
    Transparent := TmpTransparent;
    SelectFont(TmpSpec);
    fLib.DrawRestoreState;
  end;
  Result := R.Bottom - R.Top;
end;

procedure TCADPDFGraphics.DoPopClip;
begin
  if fLib = nil then
  begin
    inherited DoPopClip;
    Exit;
  end;
  fLib.DrawRestoreState;
end;

function CADPDFPageDevice: TCADPageDevice;
begin
  if CADPDFResolution < 72 then
    CADPDFResolution := 72;
  Result := TCADPageDevice.FromDPI(CADPDFResolution, CADPDFResolution);
end;

{ : The transform that turns device dots into points.

  Built field by field rather than from a helper, because
  TTMSFNCGraphicsMatrix is declared twice in FNC's types unit behind
  conditionals and only the field names are certain to be there. }
function PDFScaleMatrix(const AScale: Single): TTMSFNCGraphicsMatrix;
begin
  Result.m11 := AScale;
  Result.m12 := 0;
  Result.m13 := 0;
  Result.m21 := 0;
  Result.m22 := AScale;
  Result.m23 := 0;
  Result.m31 := 0;
  Result.m32 := 0;
  Result.m33 := 1;
end;

procedure CADSavePagesToPDF(const ACAD: TFNCCADCmp2D;
  const ASetup: TCADPageSetup; const AFileName: String;
  const AFirstPage, ALastPage: Integer);
var
  TmpSetup: TCADPageSetup;
  TmpDevice: TCADPageDevice;
  TmpPDF: TTMSFNCPDFLib;
  TmpEngine: TTMSFNCGraphicsPDFEngine;
  TmpGraphics: TCADPDFGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpInit: ITMSFNCCustomPDFInitializationLib;
  TmpPaperW, TmpPaperH: TRealType;
  TmpBounds: TRect;
  TmpResolution: Integer;
  TmpCount, TmpFirst, TmpLast, Cont: Integer;
  TmpStates: String;
  TmpNoLinks: TArray<TCADPDFLinks>;
begin
  TmpStates := '';
  SetLength(TmpNoLinks, 0);
  if (ACAD = nil) or (AFileName = '') then
    Exit;
  { A copy: the query methods are not const, and a const record
    parameter cannot be asked anything. }
  TmpSetup := ASetup;
  TmpSetup.PaperSizeMM(TmpPaperW, TmpPaperH);
  TmpCount := TmpSetup.PageCount(ACAD);

  TmpFirst := AFirstPage;
  if TmpFirst < 0 then
    TmpFirst := 0;
  TmpLast := ALastPage;
  if (TmpLast < 0) or (TmpLast > TmpCount - 1) then
    TmpLast := TmpCount - 1;
  if TmpLast < TmpFirst then
    Exit;

  TmpPDF := TTMSFNCPDFLib.Create(nil);
  try
    TmpPDF.PageSize := psCustom;
    TmpPDF.PageWidth := TmpPaperW * CADPDFPointsPerMM;
    TmpPDF.PageHeight := TmpPaperH * CADPDFPointsPerMM;
    TmpPDF.PageOrientation := poPortrait;
    { FNC puts the words 'Header' and 'Footer' on a page by default.
      A drawing is not a report. }
    TmpPDF.Header := '';
    TmpPDF.Footer := '';
    TmpPDF.PageNumber := pnNone;
    ConfigurePDF(TmpPDF);

    { Laying out finer than a point needs the graphics library's own
      page height set in the same dots - see the unit header. Without
      that interface, 72 dpi is the honest answer rather than a wrong
      one. }
    TmpResolution := CADPDFResolution;
    if not Supports(TmpPDF.Graphics, ITMSFNCCustomPDFInitializationLib,
      TmpInit) then
      TmpResolution := 72;
    TmpDevice := TCADPageDevice.FromDPI(TmpResolution, TmpResolution);
    TmpBounds := Rect(0, 0, TmpDevice.MMToPxX(TmpPaperW),
      TmpDevice.MMToPxY(TmpPaperH));

    TmpEngine := TTMSFNCGraphicsPDFEngine.Create(TmpPDF);
    try
      TmpGraphics := TCADPDFGraphics.CreateForPDF(TmpPDF.Graphics);
      try
        TmpCanvas := TDecorativeCanvas.Create(TmpGraphics, False);
        try
          TmpPDF.BeginDocument(AFileName);
          try
            for Cont := TmpFirst to TmpLast do
            begin
              { Every page, the first one included.

                BeginDocument writes the file header and the document
                metadata and nothing else - it does not open a page,
                whatever the name suggests and whatever Vcl.Printers'
                BeginDoc does. Asking for a new page only from the
                second one onwards drew the first page's tile with no
                page open, threw it away, and shifted every other tile
                back by one. The output was three plausible pages that
                happened to be pages two, three and four. }
              TmpPDF.NewPage;
              TmpGraphics.Attach(TmpEngine, TmpBounds);
              { What the library flips Y against - see TURNED TEXT. }
              if TmpResolution <> 72 then
                TmpGraphics.PageHeight := TmpBounds.Bottom
              else
                TmpGraphics.PageHeight := TmpPDF.PageHeight;
              if TmpResolution <> 72 then
              begin
                { Per page, and after NewPage rather than before it:
                  NewPage draws the header and footer itself, and those
                  want the page height in points. By the time the
                  drawing starts they are already written. }
                TmpInit.SetPageWidth(TmpBounds.Right);
                TmpInit.SetPageHeight(TmpBounds.Bottom);
                { After Attach, which does not touch the transform, and
                  before anything is drawn. A clip pushed by CADDrawPage
                  brackets itself with q and Q, which leave a transform
                  set outside them alone. }
                TmpEngine.SetMatrix
                  (PDFScaleMatrix(72 / TmpResolution));
              end;
              CADDrawPage(ACAD, TmpSetup, TmpDevice, Cont, TmpCanvas);
              TmpGraphics.Attach(nil, Rect(0, 0, 0, 0));
            end;
          finally
            { A half-written PDF is still a file on disk with a
              plausible name, so the document is closed on the way out
              of a failure as well as a success. }
            TmpPDF.EndDocument;
          end;
          TmpStates := TmpGraphics.ExtGStates;
        finally
          TmpCanvas.Free;
        end;
      finally
        TmpGraphics.Free;
      end;
    finally
      TmpEngine.Free;
    end;
  finally
    TmpPDF.Free;
  end;
  { Only now: the file is complete and closed. }
  if TmpStates <> '' then
    PDFUpdatePages(AFileName, TmpNoLinks, TmpStates);
end;

procedure CADSaveSheetsToPDF(const ACAD: TFNCCADCmp2D;
  const ASheets: TCADSheets; const AFileName: String;
  const AFirstSheet, ALastSheet: Integer;
  const ALinks: TCADPDFSheetLinksFunc);
var
  TmpDevice: TCADPageDevice;
  TmpPDF: TTMSFNCPDFLib;
  TmpEngine: TTMSFNCGraphicsPDFEngine;
  TmpGraphics: TCADPDFGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpInit: ITMSFNCCustomPDFInitializationLib;
  TmpSheet: TCADSheet;
  TmpPaperW, TmpPaperH: TRealType;
  TmpBounds: TRect;
  TmpResolution: Integer;
  TmpFirst, TmpLast, Cont: Integer;
  TmpLinks: TCADPDFLinks;
  TmpPageLinks: TArray<TCADPDFLinks>;
  TmpAnyLinks: Boolean;
  TmpStates: String;
begin
  TmpAnyLinks := False;
  TmpStates := '';
  SetLength(TmpPageLinks, 0);
  if (ACAD = nil) or (ASheets = nil) or (AFileName = '') then
    Exit;
  TmpFirst := AFirstSheet;
  if TmpFirst < 0 then
    TmpFirst := 0;
  TmpLast := ALastSheet;
  if (TmpLast < 0) or (TmpLast > ASheets.Count - 1) then
    TmpLast := ASheets.Count - 1;
  if TmpLast < TmpFirst then
    Exit;

  TmpPDF := TTMSFNCPDFLib.Create(nil);
  try
    TmpPDF.PageSize := psCustom;
    { Always portrait, as the page version is: a landscape sheet has
      already had its two numbers swapped by the time it gets here, and
      saying landscape as well would swap them back. }
    TmpPDF.PageOrientation := poPortrait;
    TmpPDF.Header := '';
    TmpPDF.Footer := '';
    TmpPDF.PageNumber := pnNone;
    ConfigurePDF(TmpPDF);

    TmpResolution := CADPDFResolution;
    if not Supports(TmpPDF.Graphics, ITMSFNCCustomPDFInitializationLib,
      TmpInit) then
      TmpResolution := 72;
    TmpDevice := TCADPageDevice.FromDPI(TmpResolution, TmpResolution);

    TmpEngine := TTMSFNCGraphicsPDFEngine.Create(TmpPDF);
    try
      TmpGraphics := TCADPDFGraphics.CreateForPDF(TmpPDF.Graphics);
      try
        TmpCanvas := TDecorativeCanvas.Create(TmpGraphics, False);
        try
          TmpPDF.BeginDocument(AFileName);
          try
            for Cont := TmpFirst to TmpLast do
            begin
              TmpSheet := ASheets[Cont];
              TmpSheet.SizeMM(TmpPaperW, TmpPaperH);
              if (TmpPaperW <= 0) or (TmpPaperH <= 0) then
                Continue;
              { Before NewPage: the page takes its size when it is
                opened. This is the part the printer cannot do - there
                the orientation belongs to the document. }
              TmpPDF.PageWidth := TmpPaperW * CADPDFPointsPerMM;
              TmpPDF.PageHeight := TmpPaperH * CADPDFPointsPerMM;
              TmpBounds := Rect(0, 0, TmpDevice.MMToPxX(TmpPaperW),
                TmpDevice.MMToPxY(TmpPaperH));
              { Every page, the first one included - BeginDocument does
                not open one. }
              TmpPDF.NewPage;
              TmpGraphics.Attach(TmpEngine, TmpBounds);
              { What the library flips Y against - see TURNED TEXT. }
              if TmpResolution <> 72 then
                TmpGraphics.PageHeight := TmpBounds.Bottom
              else
                TmpGraphics.PageHeight := TmpPDF.PageHeight;
              if TmpResolution <> 72 then
              begin
                TmpInit.SetPageWidth(TmpBounds.Right);
                TmpInit.SetPageHeight(TmpBounds.Bottom);
                TmpEngine.SetMatrix(PDFScaleMatrix(72 / TmpResolution));
              end;
              CADDrawSheet(ACAD, TmpSheet, TmpDevice, TmpCanvas);
              TmpGraphics.Attach(nil, Rect(0, 0, 0, 0));
              SetLength(TmpPageLinks, Length(TmpPageLinks) + 1);
              if Assigned(ALinks) then
              begin
                TmpLinks := ALinks(TmpSheet, Cont);
                TmpPageLinks[High(TmpPageLinks)] := TmpLinks;
                if Length(TmpLinks) > 0 then
                  TmpAnyLinks := True;
              end;
            end;
          finally
            TmpPDF.EndDocument;
          end;
          TmpStates := TmpGraphics.ExtGStates;
        finally
          TmpCanvas.Free;
        end;
      finally
        TmpGraphics.Free;
      end;
    finally
      TmpEngine.Free;
    end;
  finally
    TmpPDF.Free;
  end;
  { Only now: the file is complete and closed. }
  if TmpAnyLinks or (TmpStates <> '') then
    PDFUpdatePages(AFileName, TmpPageLinks, TmpStates);
end;

procedure CADSaveSheetTiledToPDF(const ACAD: TFNCCADCmp2D;
  const ASheet: TCADSheet; const ATiling: TCADSheetTiling;
  const AFileName: String);
var
  TmpTiling: TCADSheetTiling;
  TmpDevice: TCADPageDevice;
  TmpPDF: TTMSFNCPDFLib;
  TmpEngine: TTMSFNCGraphicsPDFEngine;
  TmpGraphics: TCADPDFGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpInit: ITMSFNCCustomPDFInitializationLib;
  TmpPaperW, TmpPaperH: TRealType;
  TmpBounds: TRect;
  TmpResolution, TmpAcross, TmpDown, Cont: Integer;
  TmpStates: String;
  TmpNoLinks: TArray<TCADPDFLinks>;
begin
  TmpStates := '';
  SetLength(TmpNoLinks, 0);
  if (ACAD = nil) or (ASheet = nil) or (AFileName = '') then
    Exit;
  TmpTiling := ATiling;
  TmpTiling.PaperSizeMM(TmpPaperW, TmpPaperH);

  TmpPDF := TTMSFNCPDFLib.Create(nil);
  try
    TmpPDF.PageSize := psCustom;
    TmpPDF.PageWidth := TmpPaperW * CADPDFPointsPerMM;
    TmpPDF.PageHeight := TmpPaperH * CADPDFPointsPerMM;
    { Orientation is in the two numbers already - see CADSavePagesToPDF. }
    TmpPDF.PageOrientation := poPortrait;
    TmpPDF.Header := '';
    TmpPDF.Footer := '';
    TmpPDF.PageNumber := pnNone;
    ConfigurePDF(TmpPDF);

    TmpResolution := CADPDFResolution;
    if not Supports(TmpPDF.Graphics, ITMSFNCCustomPDFInitializationLib,
      TmpInit) then
      TmpResolution := 72;
    TmpDevice := TCADPageDevice.FromDPI(TmpResolution, TmpResolution);
    TmpBounds := Rect(0, 0, TmpDevice.MMToPxX(TmpPaperW),
      TmpDevice.MMToPxY(TmpPaperH));
    CADSheetTileCount(ASheet, ATiling, TmpDevice, TmpAcross, TmpDown);

    TmpEngine := TTMSFNCGraphicsPDFEngine.Create(TmpPDF);
    try
      TmpGraphics := TCADPDFGraphics.CreateForPDF(TmpPDF.Graphics);
      try
        TmpCanvas := TDecorativeCanvas.Create(TmpGraphics, False);
        try
          TmpPDF.BeginDocument(AFileName);
          try
            for Cont := 0 to TmpAcross * TmpDown - 1 do
            begin
              TmpPDF.NewPage;
              TmpGraphics.Attach(TmpEngine, TmpBounds);
              if TmpResolution <> 72 then
              begin
                TmpGraphics.PageHeight := TmpBounds.Bottom;
                TmpInit.SetPageWidth(TmpBounds.Right);
                TmpInit.SetPageHeight(TmpBounds.Bottom);
                TmpEngine.SetMatrix(PDFScaleMatrix(72 / TmpResolution));
              end
              else
                TmpGraphics.PageHeight := TmpPDF.PageHeight;
              CADDrawSheetTile(ACAD, ASheet, ATiling, TmpDevice, Cont,
                TmpCanvas);
              TmpGraphics.Attach(nil, Rect(0, 0, 0, 0));
            end;
          finally
            TmpPDF.EndDocument;
          end;
          TmpStates := TmpGraphics.ExtGStates;
        finally
          TmpCanvas.Free;
        end;
      finally
        TmpGraphics.Free;
      end;
    finally
      TmpEngine.Free;
    end;
  finally
    TmpPDF.Free;
  end;
  if TmpStates <> '' then
    PDFUpdatePages(AFileName, TmpNoLinks, TmpStates);
end;

{ ------------------------------------------------------------------
  Links, as an incremental update
  ------------------------------------------------------------------ }

{$IFDEF CADSYS_LCL}

procedure CADAddPDFLinks(const AFileName: String;
  const APageLinks: array of TCADPDFLinks);
begin
  Raise ECADPageError.Create('PDF links are not available on the LCL yet');
end;

procedure PDFUpdatePages(const AFileName: String;
  const APageLinks: array of TCADPDFLinks; const AExtGStates: String);
begin
  CADAddPDFLinks(AFileName, APageLinks);
end;

{$ELSE}

const
  PDFEOL = #13#10;

{ : AURL as the inside of a PDF literal string: UTF-8, anything outside
  printable ASCII percent-encoded as a URI wants it, and the three
  characters a literal string reserves escaped. }
function PDFURILiteral(const AURL: String): String;
var
  TmpBytes: TBytes;
  I: Integer;
begin
  Result := '';
  TmpBytes := TEncoding.UTF8.GetBytes(AURL);
  for I := 0 to High(TmpBytes) do
    case TmpBytes[I] of
      Ord('('), Ord(')'), Ord('\'):
        Result := Result + '\' + Char(TmpBytes[I]);
      33 .. 39, 42 .. 91, 93 .. 126:
        Result := Result + Char(TmpBytes[I]);
    else
      Result := Result + '%' + IntToHex(TmpBytes[I], 2);
    end;
end;

function PDFNum(const AValue: Double): String;
var
  TmpFmt: TFormatSettings;
begin
  TmpFmt := FormatSettings;
  TmpFmt.DecimalSeparator := '.';
  Result := FormatFloat('0.##', AValue, TmpFmt);
end;

{ : The index just past the '>>' that closes the dictionary opening at
  or after AFrom, or 0. Strings are skipped, so a '>>' inside one does
  not count. }
function DictEnd(const S: String; const AFrom: Integer;
  out AStart: Integer): Integer;
var
  I, TmpDepth: Integer;
begin
  Result := 0;
  AStart := Pos('<<', S, AFrom);
  if AStart = 0 then
    Exit;
  TmpDepth := 0;
  I := AStart;
  while I < Length(S) do
  begin
    if S[I] = '(' then
    begin
      { A literal string, with escapes and balanced parentheses. }
      Inc(I);
      TmpDepth := TmpDepth + 1000;
      while (I <= Length(S)) and (TmpDepth >= 1000) do
      begin
        if S[I] = '\' then
          Inc(I)
        else if S[I] = '(' then
          Inc(TmpDepth, 1000)
        else if S[I] = ')' then
          Dec(TmpDepth, 1000);
        Inc(I);
      end;
      Continue;
    end;
    if (S[I] = '<') and (S[I + 1] = '<') then
    begin
      Inc(TmpDepth);
      Inc(I, 2);
      Continue;
    end;
    if (S[I] = '>') and (S[I + 1] = '>') then
    begin
      Dec(TmpDepth);
      Inc(I, 2);
      if TmpDepth = 0 then
        Exit(I);
      Continue;
    end;
    Inc(I);
  end;
end;

{ : Where object ANum's latest definition starts ('ANum G obj'), and its
  generation; 0 when there is none. }
function FindObject(const S: String; const ANum: Integer;
  out AGen: Integer): Integer;
var
  TmpMatch: TMatch;
begin
  Result := 0;
  AGen := 0;
  { The last one: a file already updated before has the newest last. }
  for TmpMatch in TRegEx.Matches(S, '(?<![0-9])' + IntToStr(ANum) +
    '\s+(\d+)\s+obj\b') do
  begin
    Result := TmpMatch.Index;
    AGen := StrToInt(TmpMatch.Groups[1].Value);
  end;
end;

function ObjectDict(const S: String; const ANum: Integer; out AGen: Integer;
  out AStart, AEnd: Integer): String;
var
  TmpAt: Integer;
begin
  Result := '';
  AStart := 0;
  AEnd := 0;
  TmpAt := FindObject(S, ANum, AGen);
  if TmpAt = 0 then
    Exit;
  AEnd := DictEnd(S, TmpAt, AStart);
  if AEnd > 0 then
    Result := Copy(S, AStart, AEnd - AStart);
end;

procedure CADAddPDFLinks(const AFileName: String;
  const APageLinks: array of TCADPDFLinks);
begin
  PDFUpdatePages(AFileName, APageLinks, '');
end;

procedure PDFUpdatePages(const AFileName: String;
  const APageLinks: array of TCADPDFLinks; const AExtGStates: String);

  procedure Fail(const AWhy: String);
  begin
    Raise ECADPageError.Create('The PDF could not be completed: ' + AWhy);
  end;

var
  TmpLatin: TEncoding;
  TmpStream: TFileStream;
  TmpBytes: TBytes;
  S, TmpTrailer, TmpRoot, TmpInfo, TmpOut, TmpDict, TmpRefs: String;
  TmpPages: TArray<Integer>;
  TmpObjNums, TmpObjOffsets, TmpObjGens: TArray<Integer>;
  TmpPrev, TmpSize, TmpNext, TmpBase, TmpGen, TmpDummy, I, J,
    TmpPagesNum, TmpAt: Integer;
  TmpMatch: TMatch;
  TmpRect: TRect2D;
  TmpAny: Boolean;

  procedure Collect(const ANum: Integer; const ADepth: Integer);
  var
    TmpKidsDict: String;
    TmpKid: TMatch;
    TmpKidsGen, TmpA, TmpB: Integer;
  begin
    if ADepth > 32 then
      Fail('the page tree is too deep');
    TmpKidsDict := ObjectDict(S, ANum, TmpKidsGen, TmpA, TmpB);
    if TmpKidsDict = '' then
      Fail('page tree object ' + IntToStr(ANum) + ' not found');
    if TRegEx.IsMatch(TmpKidsDict, '/Type\s*/Pages(?![A-Za-z])') then
    begin
      TmpKid := TRegEx.Match(TmpKidsDict, '/Kids\s*\[([^\]]*)\]');
      if not TmpKid.Success then
        Fail('a page tree node without /Kids');
      for TmpKid in TRegEx.Matches(TmpKid.Groups[1].Value,
        '(\d+)\s+\d+\s+R') do
        Collect(StrToInt(TmpKid.Groups[1].Value), ADepth + 1);
    end
    else
      TmpPages := TmpPages + [ANum];
  end;

  procedure AddOffset(const ANum, AGen: Integer);
  begin
    TmpObjNums := TmpObjNums + [ANum];
    TmpObjGens := TmpObjGens + [AGen];
    TmpObjOffsets := TmpObjOffsets + [TmpBase + Length(TmpOut)];
  end;

begin
  TmpAny := AExtGStates <> '';
  for I := 0 to High(APageLinks) do
    if Length(APageLinks[I]) > 0 then
      TmpAny := True;
  if not TmpAny then
    Exit;
  { Latin-1: one byte, one character, both ways - so a character index
    is a byte offset and nothing is lost on the way back. }
  TmpLatin := TEncoding.GetEncoding(28591);
  try
    TmpStream := TFileStream.Create(AFileName, fmOpenReadWrite or
      fmShareDenyWrite);
    try
      SetLength(TmpBytes, TmpStream.Size);
      if Length(TmpBytes) > 0 then
        TmpStream.ReadBuffer(TmpBytes[0], Length(TmpBytes));
      S := TmpLatin.GetString(TmpBytes);

      { The previous cross-reference section and its trailer. }
      TmpMatch := TRegEx.Match(S, 'startxref\s+(\d+)\s+%%EOF\s*$');
      if not TmpMatch.Success then
        Fail('no startxref at the end');
      TmpPrev := StrToInt(TmpMatch.Groups[1].Value);
      if Copy(S, TmpPrev + 1, 4) <> 'xref' then
        Fail('a cross-reference stream, which this does not update');
      TmpAt := Pos('trailer', S, TmpPrev + 1);
      if (TmpAt = 0) or (DictEnd(S, TmpAt, TmpDummy) = 0) then
        Fail('no trailer');
      TmpTrailer := Copy(S, TmpDummy, DictEnd(S, TmpAt, TmpDummy) - TmpDummy);
      TmpMatch := TRegEx.Match(TmpTrailer, '/Size\s+(\d+)');
      if not TmpMatch.Success then
        Fail('no /Size');
      TmpSize := StrToInt(TmpMatch.Groups[1].Value);
      TmpMatch := TRegEx.Match(TmpTrailer, '/Root\s+(\d+)\s+(\d+)\s+R');
      if not TmpMatch.Success then
        Fail('no /Root');
      TmpRoot := TmpMatch.Value;
      TmpMatch := TRegEx.Match(TmpTrailer, '/Info\s+\d+\s+\d+\s+R');
      if TmpMatch.Success then
        TmpInfo := TmpMatch.Value
      else
        TmpInfo := '';

      { The pages, in document order. }
      TmpMatch := TRegEx.Match(TmpRoot, '(\d+)');
      TmpDict := ObjectDict(S, StrToInt(TmpMatch.Value), TmpGen, TmpDummy,
        TmpAt);
      TmpMatch := TRegEx.Match(TmpDict, '/Pages\s+(\d+)\s+\d+\s+R');
      if not TmpMatch.Success then
        Fail('no /Pages in the catalogue');
      TmpPagesNum := StrToInt(TmpMatch.Groups[1].Value);
      SetLength(TmpPages, 0);
      Collect(TmpPagesNum, 0);

      { The appended part: annotations, then the pages that carry them,
        then their cross-reference section. }
      TmpOut := '';
      if (Length(S) > 0) and not CharInSet(S[Length(S)], [#10, #13]) then
        TmpOut := PDFEOL;
      TmpBase := Length(TmpBytes);
      TmpNext := TmpSize;
      for I := 0 to High(TmpPages) do
      begin
        TmpRefs := '';
        if I <= High(APageLinks) then
        for J := 0 to High(APageLinks[I]) do
        begin
          if APageLinks[I][J].URL = '' then
            Continue;
          TmpRect := ReorderRect2D(APageLinks[I][J].RectMM);
          AddOffset(TmpNext, 0);
          TmpOut := TmpOut + IntToStr(TmpNext) + ' 0 obj' + PDFEOL +
            '<</Type/Annot/Subtype/Link/Rect[' +
            PDFNum(TmpRect.Left * CADPDFPointsPerMM) + ' ' +
            PDFNum(TmpRect.Bottom * CADPDFPointsPerMM) + ' ' +
            PDFNum(TmpRect.Right * CADPDFPointsPerMM) + ' ' +
            PDFNum(TmpRect.Top * CADPDFPointsPerMM) +
            ']/Border[0 0 0]/A<</Type/Action/S/URI/URI(' +
            PDFURILiteral(APageLinks[I][J].URL) + ')>>>>' + PDFEOL +
            'endobj' + PDFEOL;
          TmpRefs := TmpRefs + ' ' + IntToStr(TmpNext) + ' 0 R';
          Inc(TmpNext);
        end;
        if (TmpRefs = '') and (AExtGStates = '') then
          Continue;
        TmpDict := ObjectDict(S, TmpPages[I], TmpGen, TmpDummy, TmpAt);
        if AExtGStates <> '' then
        begin
          TmpMatch := TRegEx.Match(TmpDict, '/Resources\s*<<');
          if not TmpMatch.Success then
            Fail('page ' + IntToStr(I + 1) +
              ' keeps its resources in an object of their own');
          Insert('/ExtGState<<' + AExtGStates + '>>', TmpDict,
            TmpMatch.Index + TmpMatch.Length);
        end;
        TmpMatch := TRegEx.Match(TmpDict, '/Annots\s*\[');
        if TmpRefs = '' then
          { Nothing to add to them. }
        else if TmpMatch.Success then
        begin
          TmpAt := Pos(']', TmpDict, TmpMatch.Index + TmpMatch.Length);
          Insert(TmpRefs, TmpDict, TmpAt);
        end
        else if TRegEx.IsMatch(TmpDict, '/Annots\s+\d+\s+\d+\s+R') then
          Fail('page ' + IntToStr(I + 1) +
            ' keeps its annotations in an object of their own')
        else
          Insert('/Annots[' + Trim(TmpRefs) + ']', TmpDict,
            Length(TmpDict) - 1);
        AddOffset(TmpPages[I], TmpGen);
        TmpOut := TmpOut + IntToStr(TmpPages[I]) + ' ' + IntToStr(TmpGen) +
          ' obj' + PDFEOL + TmpDict + PDFEOL + 'endobj' + PDFEOL;
      end;
      if Length(TmpObjNums) = 0 then
        Exit;

      TmpAt := TmpBase + Length(TmpOut);
      TmpOut := TmpOut + 'xref' + PDFEOL;
      for I := 0 to High(TmpObjNums) do
        { Twenty bytes an entry, end of line included, as the format
          insists. }
        TmpOut := TmpOut + IntToStr(TmpObjNums[I]) + ' 1' + PDFEOL +
          Format('%.10d %.5d n', [TmpObjOffsets[I], TmpObjGens[I]]) + PDFEOL;
      TmpOut := TmpOut + 'trailer' + PDFEOL + '<</Size ' +
        IntToStr(Max(TmpSize, TmpNext)) + TmpRoot + TmpInfo + '/Prev ' +
        IntToStr(TmpPrev) + '>>' + PDFEOL + 'startxref' + PDFEOL +
        IntToStr(TmpAt) + PDFEOL + '%%EOF' + PDFEOL;

      TmpBytes := TmpLatin.GetBytes(TmpOut);
      TmpStream.Seek(0, soEnd);
      TmpStream.WriteBuffer(TmpBytes[0], Length(TmpBytes));
    finally
      TmpStream.Free;
    end;
  finally
    TmpLatin.Free;
  end;
end;

{$ENDIF}

end.
