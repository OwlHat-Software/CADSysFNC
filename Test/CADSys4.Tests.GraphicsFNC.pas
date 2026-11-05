{ : DUnitX tests for the TMS FNC drawing backend (VCL.FNCCS4GraphicsFNC).

  Everything is drawn into a TTMSFNCGraphics bitmap canvas with
  anti-aliasing off, and pixels are read back from its TBitmap. Only pixels
  well inside a shape or well away from it are checked, so the tests do not
  depend on how FNC rasterises edges.

  Needs TMS FNC Core (VCL flavour) on the library path.
}
unit CADSys4.Tests.GraphicsFNC;

interface

uses
  Winapi.Windows, System.SysUtils, System.Types, System.Classes,
  System.UITypes, System.Math, Vcl.Graphics,
  DUnitX.TestFramework,
  VCL.TMSFNCGraphics, VCL.TMSFNCGraphicsTypes,
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCS4GraphicsFNC,
  VCL.FNCCADSys4, VCL.FNCCS4Shapes, VCL.FNCCadSysRegister,
  VCL.FNCCS4Paper, VCL.FNCCS4Image, Vcl.Imaging.pngimage, VCL.FNCCS4SVG,
  VCL.FNCCS4GDI, VCL.FNCCS4PDF, VCL.FNCCS4Print,VCL.FNCCS4GraphicsVCL, System.IOUtils, System.RegularExpressions, System.ZLib, Xml.XMLIntf, Xml.XMLDoc, Xml.xmldom, Xml.omnixmldom;

type
  { : CS-04: a sheet, or a rectangle of the model, as a PNG. Here rather
    than in the main suite because it draws through FNC onto a bitmap,
    which is what this suite is for. }
  [TestFixture]
  TCADImageExportTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    function SheetPNG(const ATransparent: Boolean): TPngImage;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ASheetImageIsThePaperAtTheResolution;
    [Test]
    procedure ASheetImageShowsTheSheet;
    [Test]
    procedure ATransparentSheetIsClearWhereNothingIsDrawn;
    [Test]
    procedure AModelRectangleIsTheRectangleAtTheScale;
    [Test]
    procedure TooLargeAnImageIsRefused;
  end;

  { : CS-05: a sheet as SVG. Here rather than in the main suite because
    the text is measured through FNC. Most of it draws on a
    TCADSVGGraphics directly and reads the text back; what has to be
    well-formed is parsed. }
  [TestFixture]
  TCADSVGExportTests = class(TObject)
  private
    FSVG: TCADSVGGraphics;
    FOldVendor: string;
    function Parse(const AText: string): IXMLDocument;
    function FindElement(const ANode: IXMLNode; const AName: string): IXMLNode;
    function ArialSpec(const AHeight: Integer): TCADFontSpec;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ASheetIsAnSVGOfThePaperSize;
    [Test]
    procedure LineToRunsBecomeOnePolyline;
    [Test]
    procedure APenChangeEndsTheRun;
    [Test]
    procedure ARectangleCarriesItsFillAndStroke;
    [Test]
    procedure ADashedPenIsDashedAtPaperSize;
    [Test]
    procedure OneGradientServesEveryShapeThatUsesIt;
    [Test]
    procedure AClipIsAGroupWithAClipPath;
    [Test]
    procedure AClipLeftOpenIsClosedInTheDocument;
    [Test]
    procedure TextIsEscapedAndReadsBack;
    [Test]
    procedure WordWrapMakesOneLinePerTspan;
    [Test]
    procedure CalcRectAgreesWithTheFNCBackend;
    [Test]
    procedure AnImageIsEmbeddedAsADataURI;
    [Test]
    procedure SeveralSheetsNeedAPattern;
  end;

  { : CS-06: the framework-free GDI backend, metafiles and the clipboard.
    Drawn into a DIB section and read back pixel by pixel; metafiles
    checked by their header and by playing them back. }
  [TestFixture]
  TCADGDIExportTests = class(TObject)
  private
    FDC: HDC;
    FBmp: HBITMAP;
    FOld: HGDIOBJ;
    FG: TCADGDIGraphics;
    function Px(const X, Y: Integer): COLORREF;
    function SheetCAD(out ASheet: TCADSheet): TFNCCADCmp2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure APenDrawsInItsColourAndWidth;
    [Test]
    procedure ARectangleIsFilledAndOutlined;
    [Test]
    procedure AGradientBlendsInsideTheShape;
    [Test]
    procedure AClipIsGivenBackWithThePenIntact;
    [Test]
    procedure TranslucentColoursAreFlattened;
    [Test]
    procedure TextIsMeasuredAndDrawn;
    [Test]
    procedure APictureIsDrawn;
    [Test]
    procedure ASheetMetafileIsThePaperSize;
    [Test]
    procedure ASheetMetafilePlaysBackTheSheet;
    [Test]
    procedure AModelRectMetafileIsTheRectAtTheScale;
    [Test]
    procedure AMetafileFileIsWritten;
    [Test]
    procedure AMetafileSpacesSmallTextAsItMeasuredIt;
    [Test]
    procedure TheClipboardHasTheMetafileTheSVGAndABitmap;
    [Test]
    procedure SheetsPrintEachInItsOwnOrientation;
  end;

  { : CS-08: link areas and font embedding in a PDF of sheets. }
  [TestFixture]
  TCADPDFExtrasTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FFile: string;
    FBefore, FAfter: Integer;
    function WriteAndRead(const ALinks: TCADPDFSheetLinksFunc): string;
    procedure CountHook(Sender: TObject; const AInfo: TCADSheetViewportDrawInfo;
      const APhase: TCADViewportDrawPhase);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ALinkBecomesAnAnnotationInPoints;
    [Test]
    procedure FontsAreEmbeddedByDefault;
    [Test]
    procedure FontsAreLeftOutWhenAskedTo;
    [Test]
    procedure TheViewportHookRunsOncePerPhase;
  end;

  { : CS-12 and CS-13: what the Masterplanner spike found wrong in a
    600 dpi PDF - a gradient that was not painted and turned text that
    landed in the wrong place. A sheet is written through
    CADSaveSheetsToPDF, the way an application writes it, and the page's
    content stream is read back: inflated and followed operator by
    operator, so that where the text ends up on the paper is computed
    rather than guessed. }
  [TestFixture]
  TCADPDFPaperTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FFile: string;
    function WritePage(const AResolution: Integer): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure AGradientIsPaintedInBandsInsideItsShape;
    [Test]
    procedure TurnedTextLandsWhereItIsAnchored;
  end;

  { : CS-21: a colour's alpha reaches the PDF. FNC's PDF library writes no
    transparency of its own, so these read back what the library adds:
    the gs in the content stream and the ExtGState on the page. If a new
    FNC Core renames the field TCADPDFGraphics reaches its writer through,
    the first of these is what fails. }
  [TestFixture]
  TCADPDFAlphaTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FFile: string;
    function AddProbe(const AMode: Integer): TCADSheet;
    function RawFile: string;
    function Alpha(const AName, AKey, ARaw: string): Double;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ATranslucentFillPenAndTextCarryTheirAlpha;
    [Test]
    procedure AnOpaquePageWritesNoGraphicsState;
    [Test]
    procedure AGradientInterpolatesItsAlphaPerBand;
    [Test]
    procedure LinksAndAlphaGoOnTheSamePage;
    [Test]
    procedure ThePageRouteCarriesAlphaToo;
  end;

  { : CS-10: text that has to come out the same on every device -
    turned labels, and word-wrapped text measured before it is drawn. }
  [TestFixture]
  TCADTextAgreementTests = class(TObject)
  private
    function Spec(const AHeight, AEscapement: Integer): TCADFontSpec;
    function FNCInk(const AW, AH: Integer; const AText: string;
      const AFont: TCADFontSpec; const R: TRect; const AFlags: Cardinal;
      out ABottom: Integer): TPointF;
    function GDIInk(const AW, AH: Integer; const AText: string;
      const AFont: TCADFontSpec; const R: TRect;
      const AFlags: Cardinal): TPointF;
  public
    [Test]
    procedure ATurnedLabelIsTheLevelLabelTurned;
    [Test]
    procedure AnFNCTurnedLabelIsTheLevelLabelTurned;
    [Test]
    procedure ALongTurnedLabelIsDrawnWhole;
    [Test]
    procedure AWrappedLabelIsCentredOnEveryBackend;
    [Test]
    procedure SVGLaysTurnedTextOutAsFNCDoes;
    [Test]
    procedure WrappedTextIsAsTallAsItWasMeasured;
  end;

  [TestFixture]
  TCADFNCGraphicsTests = class(TObject)
  private
    FG: TTMSFNCGraphics;
    FCnv: TDecorativeCanvas;
    FFNC: TCADFNCGraphics;
    function Pixel(const X, Y: Integer): TColor;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Pen_StateIsKeptByTheBackend;
    [Test]
    procedure Pen_ColourReachesTheFNCStroke;
    [Test]
    procedure Pen_ClearStyle_DisablesTheStroke;
    [Test]
    procedure Pen_XorMode_DrawsInXorColor;
    [Test]
    procedure Pen_Alpha_BecomesStrokeOpacity;
    [Test]
    procedure Brush_Alpha_BecomesFillOpacity;
    [Test]
    procedure Brush_Gradient_BecomesAGradientFill;
    [Test]
    procedure Brush_Gradient_BlendsAcrossARectangle;
    [Test]
    procedure Brush_ZeroAlpha_DisablesTheFill;
    [Test]
    procedure Brush_ClearStyle_DisablesTheFill;
    [Test]
    procedure ClipRect_IsTheBounds;
    [Test]
    procedure DecorativeCanvas_HasNoVCLCanvas;
    [Test]
    procedure APolygonDrawsItsClosingEdge;
    [Test]
    procedure Polygon_FillsWithTheBrush;
    [Test]
    procedure Polyline_DoesNotFill;
    [Test]
    procedure Polyline_RestoresTheFill;
    [Test]
    procedure MoveToLineTo_DrawsALine;
    [Test]
    procedure FillRect_DoesNotChangeThePen;
    [Test]
    procedure DrawText_CalcRect_GrowsTheRectangle;
    [Test]
    procedure DrawText_PutsInkInTheRectangle;
    [Test]
    procedure Polygon2D_RendersThroughTheFNCBackend;
    [Test]
    procedure FontHeight_ConvertsToPositiveSize;
    [Test]
    procedure Color_SystemColourIsResolved;
  end;

implementation

const
  W = 60;
  H = 60;

procedure TCADFNCGraphicsTests.Setup;
begin
  FG := TTMSFNCGraphics.CreateBitmapCanvas(W, H);
  FG.BeginScene;
  FG.Context.SetAntiAliasing(False);
  FG.Fill.Kind := gfkSolid;
  FG.Fill.Color := gcWhite;
  FG.Stroke.Kind := gskNone;
  FG.DrawRectangle(RectF(0, 0, W, H));
  FFNC := TCADFNCGraphics.Create(FG, Rect(0, 0, W, H), False);
  FCnv := TDecorativeCanvas.Create(FFNC, True);
end;

procedure TCADFNCGraphicsTests.TearDown;
begin
  FCnv.Free; // frees FFNC, which does not own FG
  FFNC := nil;
  FG.Free;
end;

function TCADFNCGraphicsTests.Pixel(const X, Y: Integer): TColor;
begin
  { Flush the scene, read, and reopen it for further drawing. }
  FG.EndScene;
  try
    Result := ColorToRGB(FG.Bitmap.Canvas.Pixels[X, Y]);
  finally
    FG.BeginScene;
  end;
end;

procedure TCADFNCGraphicsTests.Pen_StateIsKeptByTheBackend;
begin
  FCnv.Pen.Color := cadclRed;
  FCnv.Pen.Width := 3;
  FCnv.Pen.Style := cpsDash;
  FCnv.Pen.Mode := cpmXor;
  Assert.AreEqual<Cardinal>(Cardinal(cadclRed), Cardinal(FCnv.Pen.Color));
  Assert.AreEqual(3, FCnv.Pen.Width);
  Assert.IsTrue(FCnv.Pen.Style = cpsDash);
  Assert.IsTrue(FCnv.Pen.Mode = cpmXor);
end;

procedure TCADFNCGraphicsTests.Pen_ColourReachesTheFNCStroke;
begin
  FCnv.Pen.Color := cadclBlue;
  FCnv.Pen.Width := 2;
  Assert.AreEqual(TColor(clBlue), TColor(FG.Stroke.Color));
  Assert.IsTrue(Abs(FG.Stroke.Width - 2) < 0.01, 'width');
  Assert.IsTrue(FG.Stroke.Kind = gskSolid, 'kind');
end;

procedure TCADFNCGraphicsTests.Pen_ClearStyle_DisablesTheStroke;
begin
  FCnv.Pen.Style := cpsClear;
  Assert.IsTrue(FG.Stroke.Kind = gskNone);
  FCnv.Pen.Style := cpsDot;
  Assert.IsTrue(FG.Stroke.Kind = gskDot);
end;

procedure TCADFNCGraphicsTests.Pen_XorMode_DrawsInXorColor;
begin
  FFNC.XorColor := cadclFuchsia;
  FCnv.Pen.Color := cadclRed;
  FCnv.Pen.Mode := cpmXor;
  Assert.AreEqual(TColor(clFuchsia), TColor(FG.Stroke.Color));
  FCnv.Pen.Mode := cpmCopy;
  Assert.AreEqual(TColor(clRed), TColor(FG.Stroke.Color));
end;

procedure TCADFNCGraphicsTests.Pen_Alpha_BecomesStrokeOpacity;
begin
  { FNC on VCL has no alpha in the colour, so it travels as opacity. }
  FCnv.Pen.Color := CADColorSetAlpha(cadclRed, 128);
  Assert.AreEqual(TColor(clRed), TColor(FG.Stroke.Color), 'colour');
  Assert.IsTrue(Abs(FG.Stroke.Opacity - 128 / 255) < 0.01,
    'opacity ' + FloatToStr(FG.Stroke.Opacity));
  FCnv.Pen.Color := cadclRed;
  Assert.IsTrue(Abs(FG.Stroke.Opacity - 1) < 0.01, 'opaque again');
end;

procedure TCADFNCGraphicsTests.Brush_Alpha_BecomesFillOpacity;
begin
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := CADColorSetAlpha(cadclLime, 64);
  Assert.IsTrue(FG.Fill.Kind = gfkSolid, 'kind');
  Assert.AreEqual(TColor(clLime), TColor(FG.Fill.Color), 'colour');
  Assert.IsTrue(Abs(FG.Fill.Opacity - 64 / 255) < 0.01,
    'opacity ' + FloatToStr(FG.Fill.Opacity));
end;

procedure TCADFNCGraphicsTests.Brush_ZeroAlpha_DisablesTheFill;
const
  Pts: array[0..3] of TPoint = ((X: 10; Y: 10), (X: 50; Y: 10),
    (X: 50; Y: 50), (X: 10; Y: 50));
begin
  FCnv.Pen.Style := cpsClear;
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := CADColorSetAlpha(cadclLime, 0);
  Assert.IsTrue(FG.Fill.Kind = gfkNone, 'nothing to fill with');
  FCnv.Polygon(@Pts[0], 4);
  Assert.AreEqual(TColor(clWhite), Pixel(30, 30), 'so nothing is drawn');
end;

{ The red and blue of a colour as it is on the screen - ColorToRGB
  resolves a system colour - without WinAPI.Windows for GetRValue. }
function RedOf(const AColor: TColor): Byte;
begin
  Result := ColorToRGB(AColor) and $FF;
end;

function BlueOf(const AColor: TColor): Byte;
begin
  Result := (ColorToRGB(AColor) shr 16) and $FF;
end;

procedure TCADFNCGraphicsTests.Brush_Gradient_BecomesAGradientFill;
begin
  FCnv.Brush.Color := cadclRed;
  FCnv.Brush.Color2 := cadclBlue;
  FCnv.Brush.GradientVertical := True;
  FCnv.Brush.Style := cbsGradient;
  Assert.IsTrue(FG.Fill.Kind = gfkGradient, 'kind');
  Assert.AreEqual(TColor(clRed), TColor(FG.Fill.Color), 'from');
  Assert.AreEqual(TColor(clBlue), TColor(FG.Fill.ColorTo), 'to');
  Assert.IsTrue(FG.Fill.Orientation = gfoVertical, 'top to bottom');
  FCnv.Brush.GradientVertical := False;
  Assert.IsTrue(FG.Fill.Orientation = gfoHorizontal,
    'and a change reaches the fill at once');
end;

procedure TCADFNCGraphicsTests.Brush_Gradient_BlendsAcrossARectangle;
begin
  FCnv.Pen.Style := cpsClear;
  FCnv.Brush.Color := cadclRed;
  FCnv.Brush.Color2 := cadclBlue;
  FCnv.Brush.GradientVertical := False;
  FCnv.Brush.Style := cbsGradient;
  FCnv.Graphics.Rectangle(0, 0, W, H);
  Assert.IsTrue(RedOf((Pixel(2, H div 2))) > 180, 'red at the left');
  Assert.IsTrue(BlueOf((Pixel(W - 3, H div 2))) > 180,
    'blue at the right');
end;

procedure TCADFNCGraphicsTests.Brush_ClearStyle_DisablesTheFill;
begin
  FCnv.Brush.Style := cbsClear;
  Assert.IsTrue(FG.Fill.Kind = gfkNone);
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := cadclLime;
  Assert.IsTrue(FG.Fill.Kind = gfkSolid);
  Assert.AreEqual(TColor(clLime), TColor(FG.Fill.Color));
end;

procedure TCADFNCGraphicsTests.ClipRect_IsTheBounds;
var
  R: TRect;
begin
  R := FCnv.ClipRect;
  Assert.AreEqual(0, R.Left);
  Assert.AreEqual(0, R.Top);
  Assert.AreEqual(W, R.Right);
  Assert.AreEqual(H, R.Bottom);
end;

procedure TCADFNCGraphicsTests.APolygonDrawsItsClosingEdge;
var
  TmpPts: array [0 .. 3] of TPoint;

  function AnyInk(const AX, AY: Integer): Boolean;
  var
    D: Integer;
  begin
    { A one pixel line sits on a half-pixel boundary - see PixelOffset -
      so the row it lands on is not worth being dogmatic about. }
    Result := False;
    for D := -1 to 1 do
      Result := Result or (Pixel(AX, AY + D) <> clWhite);
  end;

begin
  { The closing edge of a polygon is the one nobody draws.

    Three of the four edges are between points the caller gave; the
    fourth is implied, and whether it appears depends entirely on what
    the backend does with a path it was not told to close. On screen
    FNC closes it. Its PDF engine ends the path with the operator B,
    which fills as though the path were closed and strokes as though it
    were not - so every polygon in a PDF was missing one edge, and
    nothing else showed it.

    The outline only, so the fill cannot be mistaken for the edge. }
  FCnv.Pen.Color := cadclRed;
  FCnv.Pen.Width := 1;
  FCnv.Pen.Style := cpsSolid;
  FCnv.Brush.Style := cbsClear;

  TmpPts[0] := Point(10, 50);
  TmpPts[1] := Point(10, 10);
  TmpPts[2] := Point(50, 10);
  TmpPts[3] := Point(50, 50);
  FCnv.Graphics.Polygon(TmpPts);

  Assert.IsTrue(AnyInk(30, 10),
    'the top edge, which is between two given points, was drawn');
  Assert.IsTrue(AnyInk(30, 50),
    'and so was the bottom one, which is the closing edge nobody asked ' +
    'for by name');
  Assert.AreEqual(clWhite, Pixel(30, 30),
    'with a clear brush the inside is still paper, so what was measured ' +
    'above is the outline and not the fill');
end;

procedure TCADFNCGraphicsTests.DecorativeCanvas_HasNoVCLCanvas;
begin
  Assert.IsNull(FCnv.Canvas);
end;

procedure TCADFNCGraphicsTests.Polygon_FillsWithTheBrush;
const
  Pts: array[0..3] of TPoint = ((X: 10; Y: 10), (X: 50; Y: 10),
    (X: 50; Y: 50), (X: 10; Y: 50));
begin
  FCnv.Pen.Color := cadclLime;
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := cadclLime;
  FCnv.Polygon(@Pts[0], 4);
  Assert.AreEqual(TColor(clLime), Pixel(30, 30), 'inside');
  Assert.AreEqual(TColor(clWhite), Pixel(3, 3), 'outside');
end;

procedure TCADFNCGraphicsTests.Polyline_DoesNotFill;
const
  Pts: array[0..4] of TPoint = ((X: 10; Y: 10), (X: 50; Y: 10),
    (X: 50; Y: 50), (X: 10; Y: 50), (X: 10; Y: 10));
begin
  FCnv.Pen.Color := cadclRed;
  FCnv.Brush.Style := cbsSolid;
  FCnv.Brush.Color := cadclLime;
  FCnv.Polyline(@Pts[0], 5);
  Assert.AreEqual(TColor(clWhite), Pixel(30, 30), 'inside');
  Assert.AreEqual(TColor(clRed), Pixel(30, 10), 'edge');
end;

procedure TCADFNCGraphicsTests.Polyline_RestoresTheFill;
const
  Pts: array[0..1] of TPoint = ((X: 1; Y: 1), (X: 5; Y: 5));
begin
  FCnv.Brush.Style := cbsSolid;
  FCnv.Polyline(@Pts[0], 2);
  Assert.IsTrue(FG.Fill.Kind = gfkSolid);
end;

procedure TCADFNCGraphicsTests.MoveToLineTo_DrawsALine;
begin
  FCnv.Pen.Color := cadclBlue;
  FCnv.Pen.Width := 1;
  FCnv.MoveTo(5, 30);
  FCnv.LineTo(55, 30);
  Assert.AreEqual(TColor(clBlue), Pixel(30, 30), 'on the line');
  Assert.AreEqual(TColor(clWhite), Pixel(30, 34), 'below the line');
end;

procedure TCADFNCGraphicsTests.FillRect_DoesNotChangeThePen;
begin
  FCnv.Pen.Color := cadclRed;
  FCnv.Brush.Color := cadclYellow;
  FFNC.FillRect(Rect(20, 20, 40, 40));
  Assert.IsTrue(FG.Stroke.Kind = gskSolid);
  Assert.AreEqual(TColor(clRed), TColor(FG.Stroke.Color));
  Assert.AreEqual(TColor(clYellow), Pixel(30, 30));
end;

procedure TCADFNCGraphicsTests.DrawText_CalcRect_GrowsTheRectangle;
var
  R: TRect;
  F: TCADFontSpec;
begin
  F := TCADFontSpec.Default;
  F.Height := -14;
  FFNC.SelectFont(F);
  R := Rect(5, 5, 5, 5);
  FFNC.DrawText('CADSys', R, CAD_DT_CALCRECT);
  FFNC.ResetFont;
  Assert.IsTrue(R.Right > 5 + 10, 'width ' + IntToStr(R.Width));
  Assert.IsTrue(R.Bottom > 5 + 5, 'height ' + IntToStr(R.Height));
  Assert.AreEqual(5, R.Left);
  Assert.AreEqual(5, R.Top);
end;

procedure TCADFNCGraphicsTests.DrawText_PutsInkInTheRectangle;
var
  R: TRect;
  F: TCADFontSpec;
  X, Y, Ink: Integer;
begin
  F := TCADFontSpec.Default;
  F.Height := -20;
  F.Weight := 700;
  FFNC.FontColor := cadclBlack;
  FFNC.Transparent := True;
  FFNC.SelectFont(F);
  R := Rect(2, 2, 58, 30);
  FFNC.DrawText('MMM', R, CAD_DT_LEFT or CAD_DT_TOP or CAD_DT_SINGLELINE);
  FFNC.ResetFont;
  FG.EndScene;
  try
    Ink := 0;
    for Y := 2 to 29 do
      for X := 2 to 57 do
        if ColorToRGB(FG.Bitmap.Canvas.Pixels[X, Y]) <> clWhite then
          Inc(Ink);
    Assert.IsTrue(Ink > 20, 'ink pixels: ' + IntToStr(Ink));
    Ink := 0;
    for Y := 40 to 59 do
      for X := 0 to 59 do
        if ColorToRGB(FG.Bitmap.Canvas.Pixels[X, Y]) <> clWhite then
          Inc(Ink);
    Assert.AreEqual(0, Ink, 'nothing drawn below the text rectangle');
  finally
    FG.BeginScene;
  end;
end;

procedure TCADFNCGraphicsTests.Polygon2D_RendersThroughTheFNCBackend;
var
  P: TPolygon2D;
begin
  P := TPolygon2D.Create(1, [Point2D(10, 10), Point2D(50, 10),
    Point2D(50, 50), Point2D(10, 50)]);
  try
    FCnv.Pen.Color := cadclNavy;
    FCnv.Brush.Style := cbsSolid;
    FCnv.Brush.Color := cadclAqua;
    P.Draw(IdentityTransf2D, FCnv, Rect2D(0, 0, W, H), DRAWMODE_NORMAL);
  finally
    P.Free;
  end;
  Assert.AreEqual(TColor(clAqua), Pixel(30, 30));
end;

procedure TCADFNCGraphicsTests.FontHeight_ConvertsToPositiveSize;
begin
  { -16 px character height = 12 pt at 96 DPI. }
  Assert.IsTrue(Abs(CADFontHeightToFNCSize(-16) - 12) < 0.01);
  Assert.IsTrue(CADFontHeightToFNCSize(20) > 0);
  Assert.IsTrue(CADFontHeightToFNCSize(0) >= 1);
end;

procedure TCADFNCGraphicsTests.Color_SystemColourIsResolved;
begin
  { A system colour is resolved on the way into the drawing layer, so
    what reaches FNC is a plain RGB value. }
  Assert.AreEqual(ColorToRGB(clBtnFace),
    TColor(CADToFNCColor(TColorToCADColor(ColorToRGB(clBtnFace)))));
  Assert.AreEqual(TColor(clRed), TColor(CADToFNCColor(cadclRed)));
  Assert.IsTrue(Abs(CADToFNCOpacity(cadclRed) - 1) < 0.001, 'opaque');
  Assert.IsTrue(Abs(CADToFNCOpacity(CADColorSetAlpha(cadclRed, 0))) < 0.001,
    'transparent');
end;

{ ==================================================================
  TCADImageExportTests
  ================================================================== }

procedure TCADImageExportTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(100, 50)));
  { A3 landscape, 420 x 297 mm, and at 25.4 dpi one pixel to the
    millimetre - every number below is a millimetre. }
  FSheet := FCAD.Sheets.Add('Plate');
  FSheet.AddObject(TFrame2D.Create(-1, Point2D(10, 10), Point2D(410, 287)));
end;

procedure TCADImageExportTests.TearDown;
begin
  FCAD.Free;
end;

function TCADImageExportTests.SheetPNG(const ATransparent: Boolean)
  : TPngImage;
var
  TmpStream: TMemoryStream;
begin
  TmpStream := TMemoryStream.Create;
  try
    CADSaveSheetToPNGStream(FCAD, FSheet, TmpStream, 25, ATransparent);
    Assert.IsTrue(TmpStream.Size > 0, 'something was written');
    TmpStream.Position := 0;
    Result := TPngImage.Create;
    try
      Result.LoadFromStream(TmpStream);
    except
      Result.Free;
      Raise;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TCADImageExportTests.ASheetImageIsThePaperAtTheResolution;
var
  TmpPNG: TPngImage;
  TmpSize: TPoint;
begin
  TmpSize := CADSheetImageSize(FSheet, 300);
  Assert.AreEqual(4961, TmpSize.X, 'A3 across at 300 dpi');
  Assert.AreEqual(3508, TmpSize.Y, 'and down');
  TmpPNG := SheetPNG(False);
  try
    Assert.AreEqual(CADSheetImageSize(FSheet, 25).X, TmpPNG.Width, 'width');
    Assert.AreEqual(CADSheetImageSize(FSheet, 25).Y, TmpPNG.Height, 'height');
  finally
    TmpPNG.Free;
  end;
end;

procedure TCADImageExportTests.ASheetImageShowsTheSheet;
var
  TmpPNG: TPngImage;
  TmpInk, X, Y: Integer;
begin
  TmpPNG := SheetPNG(False);
  try
    Assert.AreEqual(TColor(clWhite), ColorToRGB(TmpPNG.Pixels[TmpPNG.Width div 2,
      TmpPNG.Height div 2]), 'white paper in the middle');
    { The frame's left edge, 10 mm in: some ink in the column around it. }
    TmpInk := 0;
    for Y := TmpPNG.Height div 4 to TmpPNG.Height div 2 do
      for X := 7 to 12 do
        if ColorToRGB(TmpPNG.Pixels[X, Y]) <> clWhite then
          Inc(TmpInk);
    Assert.IsTrue(TmpInk > 10, 'the frame is drawn: ' + IntToStr(TmpInk));
  finally
    TmpPNG.Free;
  end;
end;

procedure TCADImageExportTests.ATransparentSheetIsClearWhereNothingIsDrawn;
var
  TmpPNG: TPngImage;
  TmpOpaque, X, Y: Integer;
begin
  TmpPNG := SheetPNG(True);
  try
    Assert.AreEqual(0, Integer(TmpPNG.AlphaScanline[TmpPNG.Height div 2]
      ^[TmpPNG.Width div 2]), 'clear where the paper is empty');
    TmpOpaque := 0;
    for Y := TmpPNG.Height div 4 to TmpPNG.Height div 2 do
      for X := 7 to 12 do
        if TmpPNG.AlphaScanline[Y]^[X] > 128 then
          Inc(TmpOpaque);
    Assert.IsTrue(TmpOpaque > 10, 'and solid where the frame is: ' +
      IntToStr(TmpOpaque));
  finally
    TmpPNG.Free;
  end;
end;

procedure TCADImageExportTests.AModelRectangleIsTheRectangleAtTheScale;
var
  TmpStream: TMemoryStream;
  TmpPNG: TPngImage;
  TmpSize: TPoint;
  TmpInk, X, Y: Integer;
begin
  { 200 x 100 units at 2 units to the millimetre is 100 x 50 mm. }
  TmpSize := CADModelRectImageSize(Rect2D(0, 0, 200, 100), 2, 254);
  Assert.AreEqual(1000, TmpSize.X, '100 mm at 254 dpi');
  Assert.AreEqual(500, TmpSize.Y);
  TmpStream := TMemoryStream.Create;
  TmpPNG := TPngImage.Create;
  try
    CADSaveModelRectToPNGStream(FCAD, Rect2D(0, 0, 100, 50), 1, TmpStream, 254);
    TmpStream.Position := 0;
    TmpPNG.LoadFromStream(TmpStream);
    Assert.AreEqual(1000, TmpPNG.Width, 'width');
    Assert.AreEqual(500, TmpPNG.Height, 'height');
    { The line runs corner to corner, so it passes through the middle -
      within a pixel or two, a one-pixel line being anti-aliased across
      the pixel-centre half-pixel. }
    TmpInk := 0;
    for Y := 245 to 255 do
      for X := 495 to 505 do
        if ColorToRGB(TmpPNG.Pixels[X, Y]) <> clWhite then
          Inc(TmpInk);
    if TmpInk = 0 then
    begin
      { Where the ink is, if not where it was expected: the number that
        says whether this is a placement or nothing drawn at all. }
      for Y := 0 to TmpPNG.Height - 1 do
        for X := 0 to TmpPNG.Width - 1 do
          if ColorToRGB(TmpPNG.Pixels[X, Y]) <> clWhite then
            Assert.Fail(Format('no ink at the middle; first ink at %d,%d',
              [X, Y]));
      Assert.Fail('no ink in the image at all');
    end;
    Assert.AreEqual(TColor(clWhite), ColorToRGB(TmpPNG.Pixels[900, 100]),
      'and paper away from it');
  finally
    TmpPNG.Free;
    TmpStream.Free;
  end;
end;

procedure TCADImageExportTests.TooLargeAnImageIsRefused;
var
  TmpOld: Int64;
  TmpRaised: Boolean;
  TmpStream: TMemoryStream;
begin
  TmpOld := CADImageMaxPixels;
  CADImageMaxPixels := 1000;
  TmpStream := TMemoryStream.Create;
  try
    TmpRaised := False;
    try
      CADSaveSheetToPNGStream(FCAD, FSheet, TmpStream, 300);
    except
      on ECADPageError do
        TmpRaised := True;
    end;
    Assert.IsTrue(TmpRaised, 'refused, with a reason');
    Assert.AreEqual(Int64(0), TmpStream.Size, 'and nothing written');
  finally
    TmpStream.Free;
    CADImageMaxPixels := TmpOld;
  end;
end;

{ ==================================================================
  TCADSVGExportTests
  ================================================================== }

function CountOf(const ASub, AText: string): Integer;
var
  P: Integer;
begin
  Result := 0;
  P := Pos(ASub, AText);
  while P > 0 do
  begin
    Inc(Result);
    P := Pos(ASub, AText, P + Length(ASub));
  end;
end;

procedure TCADSVGExportTests.Setup;
begin
  { 1000 x 500 dots at 600 dpi. }
  FSVG := TCADSVGGraphics.Create(1000, 500, 600 / 25.4);
  { Parse switches the DOM vendor; put back whatever was there. }
  FOldVendor := DefaultDOMVendor;
end;

procedure TCADSVGExportTests.TearDown;
begin
  DefaultDOMVendor := FOldVendor;
  FSVG.Free;
end;

function TCADSVGExportTests.Parse(const AText: string): IXMLDocument;
var
  TmpStream: TBytesStream;
begin
  { OmniXML rather than MSXML: no COM to initialise in a console
    runner. }
  DefaultDOMVendor := sOmniXmlVendor;
  TmpStream := TBytesStream.Create(TEncoding.UTF8.GetBytes(AText));
  try
    Result := TXMLDocument.Create(nil);
    Result.LoadFromStream(TmpStream);
    Result.Active := True;
  finally
    TmpStream.Free;
  end;
end;

function TCADSVGExportTests.FindElement(const ANode: IXMLNode;
  const AName: string): IXMLNode;
var
  I: Integer;
begin
  Result := nil;
  if ANode = nil then
    Exit;
  if ANode.NodeName = AName then
    Exit(ANode);
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    Result := FindElement(ANode.ChildNodes[I], AName);
    if Result <> nil then
      Exit;
  end;
end;

function TCADSVGExportTests.ArialSpec(const AHeight: Integer): TCADFontSpec;
begin
  Result := TCADFontSpec.Default;
  Result.FaceName := 'Arial';
  Result.Height := AHeight;
end;

procedure TCADSVGExportTests.ASheetIsAnSVGOfThePaperSize;
var
  TmpCAD: TFNCCADCmp2D;
  TmpSheet: TCADSheet;
  TmpStream: TBytesStream;
  TmpText: string;
  TmpDoc: IXMLDocument;
  TmpDevice: TCADPageDevice;
begin
  TmpCAD := TFNCCADCmp2D.Create(nil);
  TmpStream := TBytesStream.Create;
  try
    TmpCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(100, 50)));
    TmpSheet := TmpCAD.Sheets.Add('Plate');
    TmpSheet.AddObject(TFrame2D.Create(-1, Point2D(10, 10),
      Point2D(410, 287)));
    CADSaveSheetToSVGStream(TmpCAD, TmpSheet, TmpStream);
    Assert.IsTrue(TmpStream.Size > 0, 'something was written');
    TmpText := TEncoding.UTF8.GetString(TmpStream.Bytes, 0, TmpStream.Size);
    TmpDoc := Parse(TmpText);
    Assert.AreEqual('svg', TmpDoc.DocumentElement.NodeName, 'an SVG');
    Assert.AreEqual('420mm', string(TmpDoc.DocumentElement.Attributes['width']),
      'A3 landscape across');
    Assert.AreEqual('297mm', string(TmpDoc.DocumentElement.Attributes['height']),
      'and down');
    TmpDevice := TCADPageDevice.FromDPI(600, 600);
    Assert.AreEqual(Format('0 0 %d %d', [TmpDevice.MMToPxX(420),
      TmpDevice.MMToPxY(297)]),
      string(TmpDoc.DocumentElement.Attributes['viewBox']),
      'laid out in 600 dpi dots');
    Assert.IsTrue(CountOf('<polyline', TmpText) + CountOf('<polygon', TmpText)
      + CountOf('<rect', TmpText) > 0, 'the frame is drawn');
  finally
    TmpStream.Free;
    TmpCAD.Free;
  end;
end;

procedure TCADSVGExportTests.LineToRunsBecomeOnePolyline;
var
  TmpText: string;
begin
  FSVG.MoveTo(10, 10);
  FSVG.LineTo(100, 10);
  FSVG.LineTo(100, 100);
  { A MoveTo to where the run ends does not break it. }
  FSVG.MoveTo(100, 100);
  FSVG.LineTo(10, 100);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(1, CountOf('<polyline', TmpText), TmpText);
  Assert.IsTrue(Pos('points="10,10 100,10 100,100 10,100"', TmpText) > 0,
    TmpText);
  Assert.IsTrue(Pos('fill="none"', TmpText) > 0, 'a line is not filled');
end;

procedure TCADSVGExportTests.APenChangeEndsTheRun;
var
  TmpText: string;
begin
  FSVG.MoveTo(0, 0);
  FSVG.LineTo(10, 0);
  FSVG.Pen.Color := cadclRed;
  FSVG.LineTo(10, 10);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(2, CountOf('<polyline', TmpText), TmpText);
  Assert.IsTrue(Pos('points="0,0 10,0" fill="none" stroke="#000000"',
    TmpText) > 0, TmpText);
  Assert.IsTrue(Pos('points="10,0 10,10" fill="none" stroke="#FF0000"',
    TmpText) > 0, TmpText);
end;

procedure TCADSVGExportTests.ARectangleCarriesItsFillAndStroke;
var
  TmpText: string;
begin
  FSVG.Brush.Style := cbsSolid;
  FSVG.Brush.Color := cadclRed;
  FSVG.Pen.Color := cadclBlue;
  FSVG.Pen.Width := 3;
  FSVG.Rectangle(10, 20, 30, 50);
  FSVG.Brush.Color := CADColorSetAlpha(cadclLime, 128);
  FSVG.FillRect(Rect(40, 40, 60, 60));
  TmpText := FSVG.SVGText;
  Assert.IsTrue(Pos('<rect x="10" y="20" width="20" height="30" ' +
    'fill="#FF0000" stroke="#0000FF" stroke-width="3"/>', TmpText) > 0,
    TmpText);
  Assert.IsTrue(Pos('<rect x="40" y="40" width="20" height="20" ' +
    'fill="#00FF00" fill-opacity="0.502" stroke="none"/>', TmpText) > 0,
    TmpText);
end;

procedure TCADSVGExportTests.ADashedPenIsDashedAtPaperSize;
var
  TmpText: string;
begin
  FSVG.Pen.Style := cpsDash;
  FSVG.Pen.Width := 1;
  FSVG.Polyline([Point(0, 0), Point(500, 0)]);
  TmpText := FSVG.SVGText;
  { GDI's 18 on, 6 off, in screen pixels - 600/96 dots each. }
  Assert.IsTrue(Pos('stroke-dasharray="112.5,37.5"', TmpText) > 0, TmpText);
end;

procedure TCADSVGExportTests.OneGradientServesEveryShapeThatUsesIt;
var
  TmpText: string;
begin
  FSVG.Brush.Style := cbsGradient;
  FSVG.Brush.Color := cadclRed;
  FSVG.Brush.Color2 := cadclBlue;
  FSVG.Rectangle(0, 0, 100, 20);
  FSVG.Rectangle(0, 30, 100, 50);
  FSVG.Ellipse(0, 60, 100, 80);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(1, CountOf('<linearGradient', TmpText), TmpText);
  Assert.AreEqual(3, CountOf('fill="url(#grad1)"', TmpText), TmpText);
  Assert.IsTrue(Pos('x2="1" y2="0"', TmpText) > 0, 'left to right');
  Assert.IsTrue(Pos('stop-color="#FF0000"', TmpText) > 0, 'from red');
  Assert.IsTrue(Pos('stop-color="#0000FF"', TmpText) > 0, 'to blue');

  FSVG.Brush.GradientVertical := True;
  FSVG.Rectangle(0, 90, 100, 110);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(2, CountOf('<linearGradient', TmpText),
    'top to bottom is another gradient');
  Assert.IsTrue(Pos('x2="0" y2="1"', TmpText) > 0, TmpText);
  Parse(TmpText);
end;

procedure TCADSVGExportTests.AClipIsAGroupWithAClipPath;
var
  TmpText: string;
  TmpGroup, TmpRect, TmpEnd: Integer;
begin
  FSVG.PushClip(Rect(10, 10, 200, 100));
  FSVG.Rectangle(0, 0, 300, 300);
  FSVG.PopClip;
  TmpText := FSVG.SVGText;
  Assert.AreEqual(1, CountOf('<clipPath', TmpText), TmpText);
  Assert.IsTrue(Pos('<rect x="10" y="10" width="190" height="90"/>',
    TmpText) > 0, TmpText);
  TmpGroup := Pos('<g clip-path="url(#clip1)">', TmpText);
  TmpRect := Pos('<rect x="0"', TmpText);
  TmpEnd := Pos('</g>', TmpText);
  Assert.IsTrue((TmpGroup > 0) and (TmpGroup < TmpRect) and
    (TmpRect < TmpEnd), 'the rectangle is inside the clipped group');
  Assert.AreEqual(0, FSVG.ClipDepth, 'balanced');
  Parse(TmpText);
end;

procedure TCADSVGExportTests.AClipLeftOpenIsClosedInTheDocument;
var
  TmpText: string;
begin
  FSVG.PushClip(Rect(0, 0, 500, 400));
  FSVG.PushClip(Rect(10, 10, 200, 100));
  FSVG.Rectangle(0, 0, 300, 300);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(2, CountOf('</g>', TmpText), TmpText);
  Parse(TmpText);
  FSVG.PopAllClips;
  Assert.AreEqual(2, CountOf('</g>', FSVG.SVGText), 'and not twice');
end;

procedure TCADSVGExportTests.TextIsEscapedAndReadsBack;
var
  TmpR: TRect;
  TmpDoc: IXMLDocument;
  TmpText: IXMLNode;
begin
  FSVG.SelectFont(ArialSpec(-40));
  FSVG.FontColor := cadclRed;
  TmpR := Rect(0, 0, 900, 100);
  FSVG.DrawText('a < b & "c"', TmpR, CAD_DT_SINGLELINE or CAD_DT_NOPREFIX);
  TmpDoc := Parse(FSVG.SVGText);
  TmpText := FindElement(TmpDoc.DocumentElement, 'text');
  Assert.IsTrue(TmpText <> nil, 'a text element');
  Assert.AreEqual('40', string(TmpText.Attributes['font-size']), 'em size');
  Assert.IsTrue(Pos('Arial', string(TmpText.Attributes['font-family'])) > 0,
    'family');
  Assert.AreEqual('#FF0000', string(TmpText.Attributes['fill']), 'colour');
  Assert.AreEqual('a < b & "c"', FindElement(TmpText, 'tspan').Text,
    'the words, unharmed');
end;

procedure TCADSVGExportTests.WordWrapMakesOneLinePerTspan;
var
  TmpOne, TmpR: TRect;
  TmpText: string;
begin
  FSVG.SelectFont(ArialSpec(-40));
  TmpOne := Rect(0, 0, 0, 0);
  FSVG.DrawText('one two', TmpOne, CAD_DT_CALCRECT or CAD_DT_SINGLELINE);
  Assert.IsTrue(TmpOne.Right > 0, 'measured');
  { Room for 'one two' and not a word more. }
  TmpR := Rect(0, 0, TmpOne.Right + 5, 1000);
  FSVG.DrawText('one two one two one two', TmpR, CAD_DT_WORDBREAK);
  TmpText := FSVG.SVGText;
  Assert.AreEqual(3, CountOf('<tspan', TmpText), TmpText);
  Assert.AreEqual(3, CountOf('>one two</tspan>', TmpText), TmpText);

  TmpR := Rect(0, 0, TmpOne.Right + 5, 1000);
  FSVG.DrawText('one two one two one two', TmpR, CAD_DT_WORDBREAK or
    CAD_DT_CALCRECT);
  Assert.AreEqual(3 * TmpOne.Bottom, TmpR.Bottom, 'three lines tall');
end;

procedure TCADSVGExportTests.CalcRectAgreesWithTheFNCBackend;
var
  TmpG: TTMSFNCGraphics;
  TmpFNC: TCADFNCGraphics;
  TmpA, TmpB: TRect;
begin
  TmpG := TTMSFNCGraphics.CreateBitmapCanvas(16, 16, False, False);
  try
    TmpG.BeginScene;
    try
      TmpFNC := TCADFNCGraphics.Create(TmpG, Rect(0, 0, 16, 16), False);
      try
        TmpFNC.SelectFont(ArialSpec(-30));
        TmpA := Rect(0, 0, 0, 0);
        TmpFNC.DrawText('Hello world', TmpA, CAD_DT_CALCRECT or
          CAD_DT_SINGLELINE);
      finally
        TmpFNC.Free;
      end;
    finally
      TmpG.EndScene;
    end;
  finally
    TmpG.Free;
  end;
  FSVG.SelectFont(ArialSpec(-30));
  TmpB := Rect(0, 0, 0, 0);
  FSVG.DrawText('Hello world', TmpB, CAD_DT_CALCRECT or CAD_DT_SINGLELINE);
  Assert.AreEqual(TmpA.Right, TmpB.Right, 'as wide');
  Assert.AreEqual(TmpA.Bottom, TmpB.Bottom, 'as tall');
end;

procedure TCADSVGExportTests.AnImageIsEmbeddedAsADataURI;
var
  TmpPNG: TPngImage;
  TmpStream: TBytesStream;
  TmpImage: TCADImage;
  TmpText: string;
begin
  TmpImage := TCADImage.Create;
  TmpStream := TBytesStream.Create;
  try
    TmpPNG := TPngImage.CreateBlank(COLOR_RGB, 8, 4, 4);
    try
      TmpPNG.SaveToStream(TmpStream);
    finally
      TmpPNG.Free;
    end;
    TmpImage.SetData(Copy(TmpStream.Bytes, 0, TmpStream.Size));
    FSVG.DrawImage(Rect(10, 10, 110, 60), TmpImage, 0);
    TmpText := FSVG.SVGText;
    Assert.IsTrue(Pos('<image x="10" y="10" width="100" height="50"',
      TmpText) > 0, TmpText);
    { The PNG signature, base64 encoded. }
    Assert.IsTrue(Pos('xlink:href="data:image/png;base64,iVBORw0KGgo',
      TmpText) > 0, 'the PNG itself');
    Parse(TmpText);
  finally
    TmpStream.Free;
    TmpImage.Free;
  end;
end;

procedure TCADSVGExportTests.SeveralSheetsNeedAPattern;
var
  TmpCAD: TFNCCADCmp2D;
  TmpA, TmpB: TCADSheet;
  TmpDir: string;
begin
  TmpDir := TPath.Combine(TPath.GetTempPath, 'CADSysSVGTest');
  TDirectory.CreateDirectory(TmpDir);
  TmpCAD := TFNCCADCmp2D.Create(nil);
  try
    TmpA := TmpCAD.Sheets.Add('A');
    TmpB := TmpCAD.Sheets.Add('B');
    Assert.WillRaise(
      procedure
      begin
        CADSaveSheetsToSVG(TmpCAD, [TmpA, TmpB],
          TPath.Combine(TmpDir, 'plate.svg'));
      end, ECADPageError, 'one name for two files');
    CADSaveSheetsToSVG(TmpCAD, [TmpA, TmpB],
      TPath.Combine(TmpDir, 'plate-%d.svg'));
    Assert.IsTrue(TFile.Exists(TPath.Combine(TmpDir, 'plate-1.svg')), 'first');
    Assert.IsTrue(TFile.Exists(TPath.Combine(TmpDir, 'plate-2.svg')), 'second');
  finally
    TmpCAD.Free;
    TDirectory.Delete(TmpDir, True);
  end;
end;

{ ==================================================================
  TCADGDIExportTests
  ================================================================== }

const
  GDIW = 200;
  GDIH = 100;

procedure TCADGDIExportTests.Setup;
var
  TmpInfo: TBitmapInfo;
  TmpBits: Pointer;
begin
  FDC := CreateCompatibleDC(0);
  FillChar(TmpInfo, SizeOf(TmpInfo), 0);
  TmpInfo.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  TmpInfo.bmiHeader.biWidth := GDIW;
  TmpInfo.bmiHeader.biHeight := -GDIH;
  TmpInfo.bmiHeader.biPlanes := 1;
  TmpInfo.bmiHeader.biBitCount := 32;
  TmpInfo.bmiHeader.biCompression := BI_RGB;
  FBmp := CreateDIBSection(FDC, TmpInfo, DIB_RGB_COLORS, TmpBits, 0, 0);
  FOld := SelectObject(FDC, FBmp);
  PatBlt(FDC, 0, 0, GDIW, GDIH, WHITENESS);
  FG := TCADGDIGraphics.Create(FDC, 0);
end;

procedure TCADGDIExportTests.TearDown;
begin
  FG.Free;
  SelectObject(FDC, FOld);
  DeleteObject(FBmp);
  DeleteDC(FDC);
end;

function TCADGDIExportTests.Px(const X, Y: Integer): COLORREF;
begin
  GdiFlush;
  Result := GetPixel(FDC, X, Y);
end;

{ : The box round the dark pixels of a 32-bit top-down DIB; an empty
  rect for none. }
function DIBInkBox(const ABits: Pointer; const AW, AH: Integer): TRect;
var
  P: PCardinal;
  X, Y: Integer;
begin
  Result := Rect(MaxInt, MaxInt, -1, -1);
  P := ABits;
  for Y := 0 to AH - 1 do
    for X := 0 to AW - 1 do
    begin
      if ((P^ and $FF) < 160) and (((P^ shr 16) and $FF) < 160) then
      begin
        Result.Left := Min(Result.Left, X);
        Result.Top := Min(Result.Top, Y);
        Result.Right := Max(Result.Right, X + 1);
        Result.Bottom := Max(Result.Bottom, Y + 1);
      end;
      Inc(P);
    end;
  if Result.Right < 0 then
    Result := Rect(0, 0, 0, 0);
end;

type
  TDIBPaint = reference to procedure(const ADC: HDC);

{ : AW by AH white pixels, APaint on them, and the box round the ink. }
function PaintedInkBox(const AW, AH: Integer; const APaint: TDIBPaint): TRect;
var
  TmpDC: HDC;
  TmpBmp: HBITMAP;
  TmpOld: HGDIOBJ;
  TmpInfo: TBitmapInfo;
  TmpBits: Pointer;
begin
  TmpDC := CreateCompatibleDC(0);
  FillChar(TmpInfo, SizeOf(TmpInfo), 0);
  TmpInfo.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  TmpInfo.bmiHeader.biWidth := AW;
  TmpInfo.bmiHeader.biHeight := -AH;
  TmpInfo.bmiHeader.biPlanes := 1;
  TmpInfo.bmiHeader.biBitCount := 32;
  TmpInfo.bmiHeader.biCompression := BI_RGB;
  TmpBmp := CreateDIBSection(TmpDC, TmpInfo, DIB_RGB_COLORS, TmpBits, 0, 0);
  TmpOld := SelectObject(TmpDC, TmpBmp);
  try
    PatBlt(TmpDC, 0, 0, AW, AH, WHITENESS);
    APaint(TmpDC);
    GdiFlush;
    Result := DIBInkBox(TmpBits, AW, AH);
  finally
    SelectObject(TmpDC, TmpOld);
    DeleteObject(TmpBmp);
    DeleteDC(TmpDC);
  end;
end;

{ : The mean glyph advance, in the metafile's own units, of a line of
  small text recorded at ADPI (0: the default) - read from the dx
  arrays of its EMR_EXTTEXTOUTW records. GDI stores each advance as a
  whole number of those units. }
function MetafileMeanAdvance(const ADPI: Integer): Double;
const
  EMR_EXTTEXTOUTW = 84;
  EMR_EOF = 14;
var
  TmpCAD: TFNCCADCmp2D;
  TmpSheet: TCADSheet;
  TmpEMF: HENHMETAFILE;
  TmpBytes: TBytes;
  TmpOff, TmpType, TmpSize, TmpChars, TmpDx, I, N: Cardinal;
  TmpSum: Int64;
begin
  TmpCAD := TFNCCADCmp2D.Create(nil);
  try
    TmpSheet := TmpCAD.Sheets.Add('Text');
    TmpSheet.Paper := pkA5;
    TmpSheet.Orientation := pgoLandscape;
    { 2.5 mm text: the size at which the spike saw words come apart. }
    TmpSheet.AddObject(TText2D.Create(-1, Rect2D(10, 70, 200, 72.5), 2.5,
      'Aanbesteden Realisatiecontract - Opstellen vraagspecificatie'));
    TmpEMF := CADSheetToEMF(TmpCAD, TmpSheet, ADPI);
    try
      SetLength(TmpBytes, GetEnhMetaFileBits(TmpEMF, 0, nil));
      GetEnhMetaFileBits(TmpEMF, Length(TmpBytes), @TmpBytes[0]);
    finally
      DeleteEnhMetaFile(TmpEMF);
    end;
  finally
    TmpCAD.Free;
  end;
  TmpSum := 0;
  N := 0;
  TmpOff := 0;
  while TmpOff + 8 <= Cardinal(Length(TmpBytes)) do
  begin
    TmpType := PCardinal(@TmpBytes[TmpOff])^;
    TmpSize := PCardinal(@TmpBytes[TmpOff + 4])^;
    if (TmpType = EMR_EOF) or (TmpSize = 0) then
      Break;
    if TmpType = EMR_EXTTEXTOUTW then
    begin
      { EMRTEXT at 36: reference point, nChars, offString, options,
        rcl, offDx - offsets from the record's start. }
      TmpChars := PCardinal(@TmpBytes[TmpOff + 44])^;
      TmpDx := PCardinal(@TmpBytes[TmpOff + 72])^;
      if (TmpDx <> 0) and (TmpChars > 0) then
        for I := 0 to TmpChars - 1 do
        begin
          Inc(TmpSum, PInteger(@TmpBytes[TmpOff + TmpDx + I * 4])^);
          Inc(N);
        end;
    end;
    Inc(TmpOff, TmpSize);
  end;
  Assert.IsTrue(N > 20, 'the text was recorded: ' + IntToStr(N) + ' glyphs');
  Result := TmpSum / N;
end;

function TCADGDIExportTests.SheetCAD(out ASheet: TCADSheet): TFNCCADCmp2D;
begin
  Result := TFNCCADCmp2D.Create(nil);
  Result.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(100, 50)));
  { A3 landscape, 420 x 297 mm, with a frame 10 mm in. }
  ASheet := Result.Sheets.Add('Plate');
  ASheet.AddObject(TFrame2D.Create(-1, Point2D(10, 10), Point2D(410, 287)));
end;

procedure TCADGDIExportTests.APenDrawsInItsColourAndWidth;
begin
  FG.Pen.Color := cadclRed;
  FG.Pen.Width := 5;
  FG.MoveTo(10, 50);
  FG.LineTo(190, 50);
  Assert.AreEqual(COLORREF($0000FF), Px(100, 50), 'red on the line');
  Assert.AreEqual(COLORREF($0000FF), Px(100, 52), 'five pixels wide');
  Assert.AreEqual(COLORREF($FFFFFF), Px(100, 56), 'and no wider');
end;

procedure TCADGDIExportTests.ARectangleIsFilledAndOutlined;
begin
  FG.Brush.Style := cbsSolid;
  FG.Brush.Color := cadclBlue;
  FG.Pen.Color := cadclBlack;
  FG.Rectangle(10, 10, 60, 60);
  Assert.AreEqual(COLORREF($FF0000), Px(35, 35), 'blue inside');
  Assert.AreEqual(COLORREF($000000), Px(10, 35), 'black edge');
  Assert.AreEqual(COLORREF($FFFFFF), Px(70, 35), 'white outside');
end;

procedure TCADGDIExportTests.AGradientBlendsInsideTheShape;
var
  TmpLeft, TmpRight: COLORREF;
begin
  FG.Pen.Style := cpsClear;
  FG.Brush.Style := cbsGradient;
  FG.Brush.Color := cadclRed;
  FG.Brush.Color2 := cadclBlue;
  FG.Rectangle(0, 0, 100, 100);
  TmpLeft := Px(2, 50);
  TmpRight := Px(97, 50);
  Assert.IsTrue(GetRValue(TmpLeft) > 200, 'red at the left');
  Assert.IsTrue(GetBValue(TmpRight) > 200, 'blue at the right');
  FG.Ellipse(100, 0, 200, 100);
  Assert.AreEqual(COLORREF($FFFFFF), Px(102, 2), 'the corner is outside');
  Assert.AreNotEqual(COLORREF($FFFFFF), Px(150, 50), 'the middle is not');
end;

procedure TCADGDIExportTests.AClipIsGivenBackWithThePenIntact;
begin
  FG.Pen.Color := cadclRed;
  FG.Pen.Width := 3;
  FG.Brush.Style := cbsSolid;
  FG.Brush.Color := cadclBlack;
  FG.PushClip(Rect(0, 0, 100, 100));
  FG.FillRect(Rect(0, 0, GDIW, GDIH));
  FG.PopClip;
  Assert.AreEqual(0, FG.ClipDepth, 'balanced');
  Assert.AreEqual(COLORREF($000000), Px(50, 50), 'filled inside the clip');
  Assert.AreEqual(COLORREF($FFFFFF), Px(150, 50), 'not outside it');
  FG.MoveTo(110, 20);
  FG.LineTo(190, 20);
  Assert.AreEqual(COLORREF($0000FF), Px(150, 20),
    'the pen is still the red one');
end;

procedure TCADGDIExportTests.TranslucentColoursAreFlattened;
begin
  FG.BlendBackground := cadclWhite;
  FG.Brush.Style := cbsSolid;
  FG.Brush.Color := CADColorSetAlpha(cadclBlack, 128);
  FG.FillRect(Rect(0, 0, 50, 50));
  Assert.IsTrue((GetRValue(Px(25, 25)) > 115) and
    (GetRValue(Px(25, 25)) < 140), 'half black on white is grey');
end;

procedure TCADGDIExportTests.TextIsMeasuredAndDrawn;
var
  TmpSpec: TCADFontSpec;
  TmpR: TRect;
  TmpInk, X, Y: Integer;
begin
  TmpSpec := TCADFontSpec.Default;
  TmpSpec.FaceName := 'Arial';
  TmpSpec.Height := -20;
  FG.SelectFont(TmpSpec);
  TmpR := Rect(0, 0, 0, 0);
  FG.DrawText('Hello', TmpR, CAD_DT_CALCRECT or CAD_DT_SINGLELINE);
  Assert.IsTrue(TmpR.Right > 20, 'measured across');
  Assert.IsTrue(TmpR.Bottom >= 18, 'and down');
  FG.FontColor := cadclBlack;
  TmpR := Rect(5, 5, 195, 95);
  FG.DrawText('Hello', TmpR, CAD_DT_SINGLELINE);
  FG.ResetFont;
  TmpInk := 0;
  for Y := 5 to 35 do
    for X := 5 to 100 do
      if Px(X, Y) <> $FFFFFF then
        Inc(TmpInk);
  Assert.IsTrue(TmpInk > 20, 'ink: ' + IntToStr(TmpInk));
end;

procedure TCADGDIExportTests.APictureIsDrawn;
var
  TmpPNG: TPngImage;
  TmpStream: TBytesStream;
  TmpImage: TCADImage;
begin
  TmpImage := TCADImage.Create;
  TmpStream := TBytesStream.Create;
  try
    TmpPNG := TPngImage.CreateBlank(COLOR_RGB, 8, 4, 4);
    try
      TmpPNG.Canvas.Brush.Color := clRed;
      TmpPNG.Canvas.FillRect(Rect(0, 0, 4, 4));
      TmpPNG.SaveToStream(TmpStream);
    finally
      TmpPNG.Free;
    end;
    TmpImage.SetData(Copy(TmpStream.Bytes, 0, TmpStream.Size));
    FG.DrawImage(Rect(20, 20, 60, 60), TmpImage, 0);
    Assert.AreEqual(COLORREF($0000FF), Px(40, 40), 'the red picture');
    Assert.AreEqual(COLORREF($FFFFFF), Px(70, 40), 'where it was put');
  finally
    TmpStream.Free;
    TmpImage.Free;
  end;
end;

procedure TCADGDIExportTests.ASheetMetafileIsThePaperSize;
var
  TmpCAD: TFNCCADCmp2D;
  TmpSheet: TCADSheet;
  TmpEMF: HENHMETAFILE;
  TmpHeader: TEnhMetaHeader;
begin
  TmpCAD := SheetCAD(TmpSheet);
  try
    TmpEMF := CADSheetToEMF(TmpCAD, TmpSheet);
    Assert.IsTrue(TmpEMF <> 0, 'a metafile');
    try
      GetEnhMetaFileHeader(TmpEMF, SizeOf(TmpHeader), @TmpHeader);
      { Hundredths of a millimetre. }
      Assert.IsTrue(Abs(TmpHeader.rclFrame.Right - 42000) <= 5,
        'A3 across: ' + IntToStr(TmpHeader.rclFrame.Right));
      Assert.IsTrue(Abs(TmpHeader.rclFrame.Bottom - 29700) <= 5,
        'and down: ' + IntToStr(TmpHeader.rclFrame.Bottom));
      Assert.IsTrue(TmpHeader.nRecords > 10, 'something was drawn');
    finally
      DeleteEnhMetaFile(TmpEMF);
    end;
  finally
    TmpCAD.Free;
  end;
end;

procedure TCADGDIExportTests.ASheetMetafilePlaysBackTheSheet;
var
  TmpCAD: TFNCCADCmp2D;
  TmpSheet: TCADSheet;
  TmpEMF: HENHMETAFILE;
  TmpDC: HDC;
  TmpBmp: HBITMAP;
  TmpOld: HGDIOBJ;
  TmpInfo: TBitmapInfo;
  TmpBits: Pointer;
  TmpR: TRect;
  TmpInk, X, Y: Integer;
begin
  TmpCAD := SheetCAD(TmpSheet);
  TmpEMF := CADSheetToEMF(TmpCAD, TmpSheet);
  { Played back at one pixel to the millimetre. }
  TmpDC := CreateCompatibleDC(0);
  FillChar(TmpInfo, SizeOf(TmpInfo), 0);
  TmpInfo.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  TmpInfo.bmiHeader.biWidth := 420;
  TmpInfo.bmiHeader.biHeight := -297;
  TmpInfo.bmiHeader.biPlanes := 1;
  TmpInfo.bmiHeader.biBitCount := 32;
  TmpInfo.bmiHeader.biCompression := BI_RGB;
  TmpBmp := CreateDIBSection(TmpDC, TmpInfo, DIB_RGB_COLORS, TmpBits, 0, 0);
  TmpOld := SelectObject(TmpDC, TmpBmp);
  try
    PatBlt(TmpDC, 0, 0, 420, 297, WHITENESS);
    TmpR := Rect(0, 0, 420, 297);
    Assert.IsTrue(PlayEnhMetaFile(TmpDC, TmpEMF, TmpR), 'played');
    GdiFlush;
    { The frame's left edge, 10 mm in. }
    TmpInk := 0;
    for Y := 74 to 148 do
      for X := 7 to 13 do
        if GetPixel(TmpDC, X, Y) <> $FFFFFF then
          Inc(TmpInk);
    Assert.IsTrue(TmpInk > 10, 'the frame is where it is on paper: ' +
      IntToStr(TmpInk));
    Assert.AreEqual(COLORREF($FFFFFF), GetPixel(TmpDC, 200, 150),
      'white paper in the middle');
  finally
    SelectObject(TmpDC, TmpOld);
    DeleteObject(TmpBmp);
    DeleteDC(TmpDC);
    DeleteEnhMetaFile(TmpEMF);
    TmpCAD.Free;
  end;
end;

procedure TCADGDIExportTests.AModelRectMetafileIsTheRectAtTheScale;
var
  TmpCAD: TFNCCADCmp2D;
  TmpSheet: TCADSheet;
  TmpEMF: HENHMETAFILE;
  TmpHeader: TEnhMetaHeader;
begin
  TmpCAD := SheetCAD(TmpSheet);
  try
    { 100 x 50 drawing units at 2 units to the millimetre: 50 x 25 mm. }
    TmpEMF := CADModelRectToEMF(TmpCAD, Rect2D(0, 0, 100, 50), 2);
    Assert.IsTrue(TmpEMF <> 0, 'a metafile');
    try
      GetEnhMetaFileHeader(TmpEMF, SizeOf(TmpHeader), @TmpHeader);
      Assert.IsTrue(Abs(TmpHeader.rclFrame.Right - 5000) <= 5,
        'across: ' + IntToStr(TmpHeader.rclFrame.Right));
      Assert.IsTrue(Abs(TmpHeader.rclFrame.Bottom - 2500) <= 5,
        'down: ' + IntToStr(TmpHeader.rclFrame.Bottom));
    finally
      DeleteEnhMetaFile(TmpEMF);
    end;
  finally
    TmpCAD.Free;
  end;
end;

procedure TCADGDIExportTests.AMetafileFileIsWritten;
var
  TmpCAD: TFNCCADCmp2D;
  TmpSheet: TCADSheet;
  TmpName: string;
  TmpBytes: TBytes;
begin
  TmpName := TPath.Combine(TPath.GetTempPath, 'CADSysGDITest.emf');
  TmpCAD := SheetCAD(TmpSheet);
  try
    CADSaveSheetToEMF(TmpCAD, TmpSheet, TmpName);
    Assert.IsTrue(TFile.Exists(TmpName), 'written');
    TmpBytes := TFile.ReadAllBytes(TmpName);
    Assert.IsTrue(Length(TmpBytes) > 88, 'more than a header');
    Assert.AreEqual(1, Integer(PCardinal(@TmpBytes[0])^), 'EMR_HEADER first');
    { ' EMF' in the header's signature field. }
    Assert.AreEqual(Integer($464D4520), Integer(PCardinal(@TmpBytes[40])^),
      'an enhanced metafile');
  finally
    TmpCAD.Free;
    if TFile.Exists(TmpName) then
      TFile.Delete(TmpName);
  end;
end;

procedure TCADGDIExportTests.AMetafileSpacesSmallTextAsItMeasuredIt;
var
  TmpDefault, TmpCoarse: Double;
  TmpLogs: string;
begin
  { CS-17. Small text recorded at 600 dpi played back - in Windows and in
    PowerPoint - with gaps inside words and past its box: GDI keeps each
    glyph's advance as a whole number of the recording's units, and at
    600 dpi a glyph of 2.5 mm text is only a couple of dozen of them.
    Recorded by default, a glyph must be fifty or more, so that the
    rounding stays under a percent. }
  TmpDefault := MetafileMeanAdvance(0);
  TmpCoarse := MetafileMeanAdvance(600);
  TmpLogs := TPath.GetFullPath(ExtractFilePath(ParamStr(0)) + '..\..\logs');
  if TDirectory.Exists(TmpLogs) then
    TFile.WriteAllText(TPath.Combine(TmpLogs, 'emf-text-advance.txt'),
      Format('mean glyph advance: default %.1f, at 600 dpi %.1f units',
      [TmpDefault, TmpCoarse]));
  Assert.IsTrue(TmpDefault >= 50, Format('a glyph is %.1f units by ' +
    'default (%.1f at 600 dpi)', [TmpDefault, TmpCoarse]));
end;

procedure TCADGDIExportTests.TheClipboardHasTheMetafileTheSVGAndABitmap;
var
  TmpCAD: TFNCCADCmp2D;
  TmpSheet: TCADSheet;
  TmpHandle: THandle;
  TmpPtr: PAnsiChar;
  TmpHead: AnsiString;
begin
  { This replaces whatever was on the clipboard of whoever runs it. }
  TmpCAD := SheetCAD(TmpSheet);
  try
    CADCopySheetToClipboardWin(TmpCAD, TmpSheet);
    Assert.IsTrue(IsClipboardFormatAvailable(CF_ENHMETAFILE), 'the metafile');
    Assert.IsTrue(IsClipboardFormatAvailable(CF_DIB), 'the bitmap');
    { CS-18: Office pastes a PNG before a metafile, so none by default. }
    Assert.IsFalse(IsClipboardFormatAvailable(RegisterClipboardFormat('PNG')),
      'no PNG');
    Assert.IsTrue(IsClipboardFormatAvailable(RegisterClipboardFormat
      ('image/svg+xml')), 'the SVG');
    Assert.IsTrue(OpenClipboard(0), 'open the clipboard');
    try
      TmpHandle := GetClipboardData(RegisterClipboardFormat('image/svg+xml'));
      Assert.IsTrue(TmpHandle <> 0, 'SVG data');
      TmpPtr := GlobalLock(TmpHandle);
      try
        SetString(TmpHead, TmpPtr, Min(400, Integer(GlobalSize(TmpHandle))));
      finally
        GlobalUnlock(TmpHandle);
      end;
    finally
      CloseClipboard;
    end;
    Assert.IsTrue(Pos(AnsiString('<svg'), TmpHead) > 0, string(TmpHead));

    CADClipboardPNG := True;
    try
      CADCopySheetToClipboardWin(TmpCAD, TmpSheet);
      Assert.IsTrue(IsClipboardFormatAvailable(RegisterClipboardFormat('PNG')),
        'the PNG, when asked for');
    finally
      CADClipboardPNG := False;
    end;
    CADCopyModelRectToClipboardWin(TmpCAD, Rect2D(0, 0, 100, 50), 2);
    Assert.IsTrue(IsClipboardFormatAvailable(RegisterClipboardFormat
      ('image/svg+xml')), 'the SVG of a model rectangle');
  finally
    TmpCAD.Free;
  end;
end;

procedure TCADGDIExportTests.SheetsPrintEachInItsOwnOrientation;
const
  PDFPrinter = 'Microsoft Print to PDF';
var
  TmpCAD: TFNCCADCmp2D;
  TmpSheet: TCADSheet;
  TmpIC: HDC;
  TmpName, TmpText, TmpBoxes: string;
  TmpBytes: TBytes;
  TmpMatch: TMatch;
  TmpW, TmpH: Double;
  TmpPortrait, TmpLandscape, I: Integer;
begin
  TmpIC := CreateIC('WINSPOOL', PDFPrinter, nil, nil);
  if TmpIC = 0 then
  begin
    Assert.Pass(PDFPrinter + ' is not installed here');
    Exit;
  end;
  DeleteDC(TmpIC);
  TmpName := TPath.Combine(TPath.GetTempPath, 'CADSysPrintTest.pdf');
  if TFile.Exists(TmpName) then
    TFile.Delete(TmpName);
  TmpCAD := TFNCCADCmp2D.Create(nil);
  try
    TmpSheet := TmpCAD.Sheets.Add('Upright');
    TmpSheet.Paper := pkA4;
    TmpSheet.Orientation := pgoPortrait;
    TmpSheet.AddObject(TFrame2D.Create(-1, Point2D(10, 10), Point2D(200, 287)));
    TmpSheet := TmpCAD.Sheets.Add('Wide');
    TmpSheet.Paper := pkA4;
    TmpSheet.Orientation := pgoLandscape;
    TmpSheet.AddObject(TFrame2D.Create(-1, Point2D(10, 10), Point2D(287, 200)));
    CADPrintSheetsWin(TmpCAD, TmpCAD.Sheets, PDFPrinter, 'CADSys print test',
      0, -1, TmpName);
  finally
    TmpCAD.Free;
  end;
  { The spooler writes the file after EndDoc, in its own time. }
  for I := 1 to 100 do
  begin
    if TFile.Exists(TmpName) then
      try
        TmpBytes := TFile.ReadAllBytes(TmpName);
        if (Length(TmpBytes) > 0) and
          (Pos('%%EOF', TEncoding.ANSI.GetString(TmpBytes)) > 0) then
          Break;
      except
        { Still being written. }
      end;
    Sleep(100);
  end;
  try
    Assert.IsTrue(Length(TmpBytes) > 0, 'the printer wrote the file');
    TmpText := TEncoding.ANSI.GetString(TmpBytes);
    Assert.IsTrue(Copy(TmpText, 1, 5) = '%PDF-', 'a PDF');
    TmpPortrait := 0;
    TmpLandscape := 0;
    TmpBoxes := '';
    for TmpMatch in TRegEx.Matches(TmpText,
      '/MediaBox\s*\[\s*[-\d.]+\s+[-\d.]+\s+([\d.]+)\s+([\d.]+)') do
    begin
      TmpW := StrToFloat(TmpMatch.Groups[1].Value, TFormatSettings.Invariant);
      TmpH := StrToFloat(TmpMatch.Groups[2].Value, TFormatSettings.Invariant);
      TmpBoxes := TmpBoxes + ' ' + TmpMatch.Value;
      if TmpW < TmpH then
        Inc(TmpPortrait)
      else if TmpW > TmpH then
        Inc(TmpLandscape);
    end;
    Assert.IsTrue((TmpPortrait > 0) and (TmpLandscape > 0),
      'one page each way:' + TmpBoxes);
  finally
    if TFile.Exists(TmpName) then
      TFile.Delete(TmpName);
  end;
end;

{ ==================================================================
  TCADPDFExtrasTests
  ================================================================== }

procedure TCADPDFExtrasTests.Setup;
var
  TmpSheet: TCADSheet;
  TmpText: TText2D;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  TmpSheet := FCAD.Sheets.Add('Plate');
  TmpSheet.Paper := pkA4;
  TmpSheet.Orientation := pgoPortrait;
  TmpText := TText2D.Create(-1, Rect2D(20, 250, 120, 262), 8, 'Hello');
  TmpSheet.AddObject(TmpText);
  FFile := TPath.Combine(TPath.GetTempPath, 'CADSysPDFExtras.pdf');
end;

procedure TCADPDFExtrasTests.TearDown;
begin
  FCAD.Free;
  if TFile.Exists(FFile) then
    TFile.Delete(FFile);
end;

function TCADPDFExtrasTests.WriteAndRead(const ALinks
  : TCADPDFSheetLinksFunc): string;
begin
  CADSaveSheetsToPDF(FCAD, FCAD.Sheets, FFile, 0, -1, ALinks);
  Assert.IsTrue(TFile.Exists(FFile), 'written');
  Result := TEncoding.ANSI.GetString(TFile.ReadAllBytes(FFile));
end;

procedure TCADPDFExtrasTests.ALinkBecomesAnAnnotationInPoints;
var
  TmpText: string;
begin
  TmpText := WriteAndRead(
    function(const ASheet: TCADSheet; const AIndex: Integer): TCADPDFLinks
    begin
      Result := [TCADPDFLink.Create(Rect2D(10, 20, 60, 40),
        'https://example.com/plan')];
    end);
  Assert.IsTrue(Pos('/URI(https://example.com/plan)', TmpText) > 0,
    'the URL');
  { 10, 20, 60, 40 mm from the bottom-left corner, in points. }
  Assert.IsTrue(Pos('/Rect[28.35 56.69 170.08 113.39]', TmpText) > 0,
    'where it is');
  Assert.IsTrue(Pos('/Subtype/Link', TmpText) > 0, 'a link annotation');
end;

procedure TCADPDFExtrasTests.CountHook(Sender: TObject;
  const AInfo: TCADSheetViewportDrawInfo; const APhase: TCADViewportDrawPhase);
begin
  if APhase = vdpBeforeModel then
    Inc(FBefore)
  else
    Inc(FAfter);
end;

procedure TCADPDFExtrasTests.TheViewportHookRunsOncePerPhase;
var
  TmpVP: TCADSheetViewport;
begin
  { Something for the viewport to show: a fitted viewport on an empty
    drawing is refused. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(100, 50)));
  TmpVP := FCAD.Sheets[0].AddViewport;
  TmpVP.RectMM := Rect2D(20, 20, 190, 200);
  TmpVP.ContentInsetMM := Rect2D(20, 0, 0, 10);
  FCAD.OnDrawSheetViewport := CountHook;
  WriteAndRead(nil);
  Assert.AreEqual(1, FBefore, 'before the model, once');
  Assert.AreEqual(1, FAfter, 'after it, once');
end;

procedure TCADPDFExtrasTests.FontsAreEmbeddedByDefault;
begin
  Assert.IsTrue(CADPDFEmbedFonts, 'the default');
  Assert.IsTrue(Pos('/FontFile2', WriteAndRead(nil)) > 0,
    'a TrueType font program in the file');
end;

procedure TCADPDFExtrasTests.FontsAreLeftOutWhenAskedTo;
begin
  CADPDFEmbedFonts := False;
  try
    Assert.IsTrue(Pos('/FontFile2', WriteAndRead(nil)) = 0,
      'no font program in the file');
  finally
    CADPDFEmbedFonts := True;
  end;
end;

{ ==================================================================
  TCADPDFPaperTests
  ================================================================== }

type
  { : Paints the CS-12/CS-13 page: four gradient shapes and four turned
    labels, at fixed places in the sheet's millimetres. A line, so that
    its box covers the page and the sheet draws it. }
  TPDFPaperProbe2D = class(TLine2D)
  public
    procedure Draw(const VT: TTransf2D; const Cnv: TDecorativeCanvas;
      const ClipRect2D: TRect2D; const DrawMode: Integer); override;
  end;

const
  { Label centres in mm (origin bottom-left) and their turns. }
  PDFProbeLabels: array [0 .. 3] of record X, Y: Double; Angle: Integer;
    end = ((X: 60; Y: 130; Angle: 0), (X: 150; Y: 130; Angle: 45),
    (X: 60; Y: 60; Angle: 90), (X: 150; Y: 60; Angle: 270));
  PDFProbeText = 'Milestone label';

procedure TPDFPaperProbe2D.Draw(const VT: TTransf2D;
  const Cnv: TDecorativeCanvas; const ClipRect2D: TRect2D;
  const DrawMode: Integer);

  function P(const X, Y: Double): TPoint;
  begin
    Result := Point2DToPoint(TransformPoint2D(Point2D(X, Y), VT));
  end;

var
  G: TCADGraphics;
  TmpPPMM: Double;
  TmpSpec: TCADFontSpec;
  TmpC: TPoint;
  TmpR: TRect;
  TmpW, TmpH: Integer;
  I: Integer;
begin
  G := Cnv.Graphics;
  TmpPPMM := PointDistance2D(TransformPoint2D(Point2D(0, 0), VT),
    TransformPoint2D(Point2D(0, 1), VT));
  G.Pen.Style := cpsClear;
  G.Brush.Style := cbsGradient;
  G.Brush.Color := cadclRed;
  G.Brush.Color2 := cadclBlue;
  G.Brush.GradientVertical := False;
  G.Rectangle(P(20, 270).X, P(20, 270).Y, P(100, 250).X, P(100, 250).Y);
  G.Polygon([P(20, 200), P(100, 200), P(60, 240)]);
  G.Brush.GradientVertical := True;
  G.Rectangle(P(120, 270).X, P(120, 270).Y, P(190, 250).X, P(190, 250).Y);
  G.Ellipse(P(120, 240).X, P(120, 240).Y, P(190, 200).X, P(190, 200).Y);
  G.Brush.Style := cbsClear;
  G.Pen.Style := cpsSolid;

  TmpSpec := TCADFontSpec.Default;
  TmpSpec.FaceName := 'Arial';
  TmpSpec.Height := -Round(5 * TmpPPMM);
  G.FontColor := cadclBlack;
  G.Transparent := True;
  { The rectangle a caller sizes for the text laid level - 60 by 8 mm -
    centred on the anchor. }
  TmpW := Round(30 * TmpPPMM);
  TmpH := Round(4 * TmpPPMM);
  for I := Low(PDFProbeLabels) to High(PDFProbeLabels) do
  begin
    TmpSpec.Escapement := PDFProbeLabels[I].Angle * 10;
    G.SelectFont(TmpSpec);
    TmpC := P(PDFProbeLabels[I].X, PDFProbeLabels[I].Y);
    TmpR := Rect(TmpC.X - TmpW, TmpC.Y - TmpH, TmpC.X + TmpW, TmpC.Y + TmpH);
    G.DrawText(PDFProbeText, TmpR, CAD_DT_SINGLELINE or CAD_DT_CENTER or
      CAD_DT_VCENTER or CAD_DT_NOCLIP);
  end;
  G.ResetFont;
end;

type
  TPDFMatrix = array [0 .. 5] of Double;

  { : A text run on the page: where its origin is, in points from the
    bottom-left corner, and which way its baseline runs, in degrees. }
  TPDFRun = record
    X, Y, Angle: Double;
    { Characters in its string - glyph ids, for an embedded font. }
    Glyphs: Integer;
  end;

function PDFMul(const A, B: TPDFMatrix): TPDFMatrix;
begin
  { A then B, as PDF composes: [a b c d e f]. }
  Result[0] := A[0] * B[0] + A[1] * B[2];
  Result[1] := A[0] * B[1] + A[1] * B[3];
  Result[2] := A[2] * B[0] + A[3] * B[2];
  Result[3] := A[2] * B[1] + A[3] * B[3];
  Result[4] := A[4] * B[0] + A[5] * B[2] + B[4];
  Result[5] := A[4] * B[1] + A[5] * B[3] + B[5];
end;

const
  PDFIdentity: TPDFMatrix = (1, 0, 0, 1, 0, 0);

{ : The content streams of a PDF - not fonts, not images - inflated and
  run together. }
function PDFContent(const AFile: string): string;
var
  TmpBytes, TmpData, TmpOut: TBytes;
  TmpRaw, TmpDict: string;
  TmpAt, TmpStart, TmpEnd, TmpObj: Integer;
  TmpLatin1: TEncoding;
begin
  Result := '';
  TmpBytes := TFile.ReadAllBytes(AFile);
  { Latin-1: one character per byte, so a position in the string is a
    position in the file. }
  TmpLatin1 := TEncoding.GetEncoding(28591);
  try
    TmpRaw := TmpLatin1.GetString(TmpBytes);
  finally
    TmpLatin1.Free;
  end;
  TmpAt := 1;
  while True do
  begin
    TmpStart := Pos('stream', TmpRaw, TmpAt);
    if TmpStart = 0 then
      Break;
    { 'endstream' contains 'stream' too. }
    if (TmpStart > 3) and (Copy(TmpRaw, TmpStart - 3, 3) = 'end') then
    begin
      TmpAt := TmpStart + 6;
      Continue;
    end;
    TmpObj := TmpStart;
    while (TmpObj > 1) and (Copy(TmpRaw, TmpObj, 3) <> 'obj') do
      Dec(TmpObj);
    TmpDict := Copy(TmpRaw, TmpObj, TmpStart - TmpObj);
    TmpEnd := Pos('endstream', TmpRaw, TmpStart);
    if TmpEnd = 0 then
      Break;
    TmpAt := TmpEnd + 9;
    if (Pos('/FlateDecode', TmpDict) = 0) or (Pos('/Length1', TmpDict) > 0) or
      (Pos('/Subtype', TmpDict) > 0) or (Pos('/Type', TmpDict) > 0) then
      Continue;
    Inc(TmpStart, 6);
    if TmpRaw[TmpStart] = #13 then
      Inc(TmpStart);
    if TmpRaw[TmpStart] = #10 then
      Inc(TmpStart);
    { The end of line before endstream is not part of the data, and
      zlib will not have anything after its own end. }
    while (TmpEnd > TmpStart) and CharInSet(TmpRaw[TmpEnd - 1], [#13, #10]) do
      Dec(TmpEnd);
    { Back to zero-based bytes. }
    TmpData := Copy(TmpBytes, TmpStart - 1, TmpEnd - TmpStart);
    try
      ZDecompress(TmpData, TmpOut);
      Result := Result + TEncoding.ANSI.GetString(TmpOut) + #10;
    except
      { Not a stream this reads: leave it out. }
    end;
  end;
end;

{ : Follows q, Q, cm, BT, Td, Tm and Tj/TJ through AContent and gives
  each text run's origin and direction on the page. }
function PDFTextRuns(const AContent: string): TArray<TPDFRun>;
var
  TmpStack: TArray<TPDFMatrix>;
  TmpCTM, TmpTm, TmpTlm, TmpTrm: TPDFMatrix;
  TmpNums: TArray<Double>;
  TmpTok: string;
  I, N, TmpDepth: Integer;
  TmpRun: TPDFRun;
  TmpV: Double;
  TmpFS: TFormatSettings;
  TmpLast, TmpFrom: Integer;

  function Num(const AIndex: Integer): Double;
  begin
    Result := TmpNums[Length(TmpNums) - AIndex];
  end;

  function M6: TPDFMatrix;
  var
    K: Integer;
  begin
    for K := 0 to 5 do
      Result[K] := TmpNums[Length(TmpNums) - 6 + K];
  end;

begin
  SetLength(Result, 0);
  TmpFS := TFormatSettings.Invariant;
  TmpCTM := PDFIdentity;
  TmpTm := PDFIdentity;
  TmpTlm := PDFIdentity;
  SetLength(TmpStack, 0);
  SetLength(TmpNums, 0);
  N := Length(AContent);
  TmpLast := 0;
  I := 1;
  while I <= N do
  begin
    case AContent[I] of
      #0 .. ' ':
        begin
          Inc(I);
          Continue;
        end;
      '(':
        begin
          TmpFrom := I;
          TmpDepth := 0;
          repeat
            if AContent[I] = '\' then
              Inc(I)
            else if AContent[I] = '(' then
              Inc(TmpDepth)
            else if AContent[I] = ')' then
              Dec(TmpDepth);
            Inc(I);
          until (TmpDepth = 0) or (I > N);
          TmpLast := I - TmpFrom - 2;
          Continue;
        end;
      '<':
        begin
          TmpFrom := I;
          while (I <= N) and (AContent[I] <> '>') do
            Inc(I);
          { Four hex digits a glyph: FNC embeds fonts as two-byte CIDs. }
          TmpLast := (I - TmpFrom - 1) div 4;
          Inc(I);
          Continue;
        end;
      '[', ']':
        begin
          Inc(I);
          Continue;
        end;
    end;
    TmpTok := '';
    while (I <= N) and not CharInSet(AContent[I], [#0 .. ' ', '(', '<', '[',
      ']']) do
    begin
      TmpTok := TmpTok + AContent[I];
      Inc(I);
    end;
    if TmpTok = '' then
    begin
      Inc(I);
      Continue;
    end;
    if TryStrToFloat(TmpTok, TmpV, TmpFS) then
    begin
      TmpNums := TmpNums + [TmpV];
      Continue;
    end;
    if TmpTok = 'q' then
      TmpStack := TmpStack + [TmpCTM]
    else if TmpTok = 'Q' then
    begin
      if Length(TmpStack) > 0 then
      begin
        TmpCTM := TmpStack[High(TmpStack)];
        SetLength(TmpStack, Length(TmpStack) - 1);
      end;
    end
    else if (TmpTok = 'cm') and (Length(TmpNums) >= 6) then
      TmpCTM := PDFMul(M6, TmpCTM)
    else if TmpTok = 'BT' then
    begin
      TmpTm := PDFIdentity;
      TmpTlm := PDFIdentity;
    end
    else if (TmpTok = 'Td') and (Length(TmpNums) >= 2) then
    begin
      TmpTrm := PDFIdentity;
      TmpTrm[4] := Num(2);
      TmpTrm[5] := Num(1);
      TmpTlm := PDFMul(TmpTrm, TmpTlm);
      TmpTm := TmpTlm;
    end
    else if (TmpTok = 'Tm') and (Length(TmpNums) >= 6) then
    begin
      TmpTlm := M6;
      TmpTm := TmpTlm;
    end
    else if (TmpTok = 'Tj') or (TmpTok = 'TJ') then
    begin
      TmpTrm := PDFMul(TmpTm, TmpCTM);
      TmpRun.X := TmpTrm[4];
      TmpRun.Y := TmpTrm[5];
      TmpRun.Angle := RadToDeg(ArcTan2(TmpTrm[1], TmpTrm[0]));
      TmpRun.Glyphs := TmpLast;
      Result := Result + [TmpRun];
    end;
    SetLength(TmpNums, 0);
  end;
end;

procedure TCADPDFPaperTests.Setup;
var
  TmpSheet: TCADSheet;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  TmpSheet := FCAD.Sheets.Add('Paper');
  TmpSheet.Paper := pkA4;
  TmpSheet.Orientation := pgoPortrait;
  TmpSheet.AddObject(TPDFPaperProbe2D.Create(-1, Point2D(1, 1),
    Point2D(209, 296)));
  FFile := TPath.Combine(TPath.GetTempPath, 'CADSysPDFPaper.pdf');
end;

procedure TCADPDFPaperTests.TearDown;
begin
  FCAD.Free;
  if TFile.Exists(FFile) then
    TFile.Delete(FFile);
end;

function TCADPDFPaperTests.WritePage(const AResolution: Integer): string;
var
  TmpOld: Integer;
  TmpLogs: string;
begin
  TmpOld := CADPDFResolution;
  CADPDFResolution := AResolution;
  try
    CADSaveSheetsToPDF(FCAD, FCAD.Sheets, FFile);
  finally
    CADPDFResolution := TmpOld;
  end;
  Assert.IsTrue(TFile.Exists(FFile), 'written');
  { A copy beside the build logs, to look at. }
  TmpLogs := TPath.GetFullPath(ExtractFilePath(ParamStr(0)) +
    '..\..\logs');
  if TDirectory.Exists(TmpLogs) then
    TFile.Copy(FFile, TPath.Combine(TmpLogs, Format('pdf-paper-%d.pdf',
      [AResolution])), True);
  Result := PDFContent(FFile);
end;

procedure TCADPDFPaperTests.AGradientIsPaintedInBandsInsideItsShape;
var
  TmpText: string;
begin
  TmpText := WritePage(600);
  { No shading pattern - FNC's lies in the wrong space at 600 dpi. }
  Assert.AreEqual(0, CountOf(' scn', TmpText), 'no pattern fill');
  { Red to blue is 255 steps; four shapes of them. }
  Assert.IsTrue(CountOf(' rg', TmpText) >= 4 * 200,
    Format('bands: %d colours set', [CountOf(' rg', TmpText)]));
  { Each inside its own outline. }
  Assert.IsTrue(CountOf('W n', TmpText) >= 4,
    Format('%d clips', [CountOf('W n', TmpText)]));
  { The first band is red, a middle one a blend. }
  Assert.IsTrue(Pos('1 0 0 rg', TmpText) > 0, 'red at the start');
  Assert.IsTrue(Pos('0 0 1 rg', TmpText) > 0, 'blue at the end');
end;

procedure TCADPDFPaperTests.TurnedTextLandsWhereItIsAnchored;
const
  PT = 72 / 25.4;
var
  TmpFine, TmpCoarse: TArray<TPDFRun>;
  I: Integer;
  TmpWant, TmpGot: Double;
begin
  TmpFine := PDFTextRuns(WritePage(600));
  TmpCoarse := PDFTextRuns(WritePage(72));
  Assert.AreEqual(Length(PDFProbeLabels), Length(TmpFine),
    'one run per label at 600 dpi');
  Assert.AreEqual(Length(PDFProbeLabels), Length(TmpCoarse),
    'one run per label at 72 dpi');
  for I := Low(PDFProbeLabels) to High(PDFProbeLabels) do
  begin
    { Turned the right way. }
    TmpWant := PDFProbeLabels[I].Angle;
    if TmpWant > 180 then
      TmpWant := TmpWant - 360;
    TmpGot := TmpFine[I].Angle;
    Assert.IsTrue(Abs(TmpGot - TmpWant) < 1,
      Format('label %d turned %.1f, wanted %.1f', [I, TmpGot, TmpWant]));
    { The whole of it - drawn level, FNC cuts short a line longer than
      its box, and a 90 degree label's box is the narrow way round. }
    Assert.AreEqual(Length(PDFProbeText), TmpFine[I].Glyphs,
      Format('label %d is all there', [I]));
    { Its baseline starts within half a label of its anchor - the label
      is under 60 mm long - so it is on its own part of the page, not
      mid-page or off it. }
    Assert.IsTrue(Hypot(TmpFine[I].X - PDFProbeLabels[I].X * PT,
      TmpFine[I].Y - PDFProbeLabels[I].Y * PT) < 35 * PT,
      Format('label %d at %.1f, %.1f pt; anchored at %.1f, %.1f',
      [I, TmpFine[I].X, TmpFine[I].Y, PDFProbeLabels[I].X * PT,
      PDFProbeLabels[I].Y * PT]));
    { And the same place at either resolution, within two points: the
      font size is rounded to a whole unit, which at 72 dpi is a whole
      point, so the label's length differs by a percent or so. The
      fault this guards against was hundreds of points. }
    Assert.IsTrue(Hypot(TmpFine[I].X - TmpCoarse[I].X,
      TmpFine[I].Y - TmpCoarse[I].Y) < 2,
      Format('label %d: %.1f, %.1f at 600 dpi, %.1f, %.1f at 72',
      [I, TmpFine[I].X, TmpFine[I].Y, TmpCoarse[I].X, TmpCoarse[I].Y]));
  end;
end;

{ ==================================================================
  TCADTextAgreementTests
  ================================================================== }

{ ==================================================================
  TCADPDFAlphaTests
  ================================================================== }

type
  { : Paints what CS-21 asks about. Mode 0: a black line under a 50 % grey
    rectangle at alpha $38, a pen at alpha $80 and text at alpha $40.
    Mode 1: the same, opaque. Mode 2: a gradient from alpha $20 to $E0. }
  TPDFAlphaProbe2D = class(TLine2D)
  public
    Mode: Integer;
    procedure Draw(const VT: TTransf2D; const Cnv: TDecorativeCanvas;
      const ClipRect2D: TRect2D; const DrawMode: Integer); override;
  end;

procedure TPDFAlphaProbe2D.Draw(const VT: TTransf2D;
  const Cnv: TDecorativeCanvas; const ClipRect2D: TRect2D;
  const DrawMode: Integer);

  function P(const X, Y: Double): TPoint;
  begin
    Result := Point2DToPoint(TransformPoint2D(Point2D(X, Y), VT));
  end;

  function A(const AAlpha: Byte): Byte;
  begin
    if Mode = 1 then
      Result := 255
    else
      Result := AAlpha;
  end;

var
  G: TCADGraphics;
  TmpSpec: TCADFontSpec;
  TmpR: TRect;
begin
  G := Cnv.Graphics;
  if Mode = 2 then
  begin
    G.Pen.Style := cpsClear;
    G.Brush.Style := cbsGradient;
    G.Brush.Color := CADColor($20, 255, 0, 0);
    G.Brush.Color2 := CADColor($E0, 255, 0, 0);
    G.Brush.GradientVertical := False;
    G.Rectangle(P(20, 270).X, P(20, 270).Y, P(190, 200).X, P(190, 200).Y);
    G.Brush.Style := cbsClear;
    G.Pen.Style := cpsSolid;
    Exit;
  end;
  { The line the rectangle has to let through. }
  G.Brush.Style := cbsClear;
  G.Pen.Style := cpsSolid;
  G.Pen.Width := 20;
  G.Pen.Color := cadclBlack;
  G.MoveTo(P(20, 250).X, P(20, 250).Y);
  G.LineTo(P(190, 250).X, P(190, 250).Y);
  G.Pen.Style := cpsClear;
  G.Brush.Style := cbsSolid;
  G.Brush.Color := CADColor(A($38), 128, 128, 128);
  G.Rectangle(P(60, 270).X, P(60, 270).Y, P(150, 230).X, P(150, 230).Y);
  G.Brush.Style := cbsClear;
  { The pen. }
  G.Pen.Style := cpsSolid;
  G.Pen.Color := CADColor(A($80), 0, 0, 255);
  G.MoveTo(P(20, 200).X, P(20, 200).Y);
  G.LineTo(P(190, 200).X, P(190, 200).Y);
  { The text. }
  TmpSpec := TCADFontSpec.Default;
  TmpSpec.FaceName := 'Arial';
  TmpSpec.Height := -200;
  G.SelectFont(TmpSpec);
  G.FontColor := CADColor(A($40), 0, 0, 0);
  G.Transparent := True;
  TmpR := Rect(P(20, 180).X, P(20, 180).Y, P(190, 150).X, P(190, 150).Y);
  G.DrawText('Translucent', TmpR, CAD_DT_SINGLELINE);
  G.ResetFont;
end;

function TCADPDFAlphaTests.AddProbe(const AMode: Integer): TCADSheet;
var
  TmpProbe: TPDFAlphaProbe2D;
begin
  Result := FCAD.Sheets.Add('Paper');
  Result.Paper := pkA4;
  Result.Orientation := pgoPortrait;
  TmpProbe := TPDFAlphaProbe2D.Create(-1, Point2D(1, 1), Point2D(209, 296));
  TmpProbe.Mode := AMode;
  Result.AddObject(TmpProbe);
end;

function TCADPDFAlphaTests.RawFile: string;
begin
  Assert.IsTrue(TFile.Exists(FFile), 'written');
  Result := TEncoding.ANSI.GetString(TFile.ReadAllBytes(FFile));
end;

{ : The value under AKey of the graphics state AName in the file's
  resources; a failure when there is none. }
function TCADPDFAlphaTests.Alpha(const AName, AKey, ARaw: string): Double;
var
  TmpMatch: TMatch;
begin
  TmpMatch := TRegEx.Match(ARaw, '/' + AName + '\s*<<[^>]*/' + AKey +
    '\s+([0-9.]+)');
  Assert.IsTrue(TmpMatch.Success, AName + ' is in the resources');
  Result := StrToFloat(TmpMatch.Groups[1].Value, TFormatSettings.Invariant);
end;

procedure TCADPDFAlphaTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FFile := TPath.Combine(TPath.GetTempPath, 'CADSysPDFAlpha.pdf');
end;

procedure TCADPDFAlphaTests.TearDown;
begin
  FCAD.Free;
  if TFile.Exists(FFile) then
    TFile.Delete(FFile);
end;

procedure TCADPDFAlphaTests.ATranslucentFillPenAndTextCarryTheirAlpha;
var
  TmpContent, TmpRaw, TmpLogs: string;
begin
  AddProbe(0);
  CADSaveSheetsToPDF(FCAD, FCAD.Sheets, FFile);
  { A copy beside the build logs, to render and look at. }
  TmpLogs := TPath.GetFullPath(ExtractFilePath(ParamStr(0)) + '..\..\logs');
  if TDirectory.Exists(TmpLogs) then
    TFile.Copy(FFile, TPath.Combine(TmpLogs, 'pdf-alpha.pdf'), True);
  TmpContent := PDFContent(FFile);
  TmpRaw := RawFile;
  { Each inside a q of its own, so that it ends with its shape. }
  Assert.IsTrue(TRegEx.IsMatch(TmpContent, 'q\s+/CADf38 gs'), 'the fill');
  Assert.IsTrue(TRegEx.IsMatch(TmpContent, 'q\s+/CADs80 gs'), 'the pen');
  Assert.IsTrue(TRegEx.IsMatch(TmpContent, 'q\s+/CADf40 gs'), 'the text');
  Assert.IsTrue(Abs(Alpha('CADf38', 'ca', TmpRaw) - 0.22) <= 0.005,
    'the fill''s /ca');
  Assert.IsTrue(Abs(Alpha('CADs80', 'CA', TmpRaw) - 0.502) <= 0.005,
    'the pen''s /CA');
  Assert.IsTrue(Abs(Alpha('CADf40', 'ca', TmpRaw) - 0.251) <= 0.005,
    'the text''s /ca');
  Assert.AreEqual(1, CountOf('/ExtGState<<', TmpRaw), 'on the one page');
end;

procedure TCADPDFAlphaTests.AnOpaquePageWritesNoGraphicsState;
var
  TmpRaw: string;
begin
  AddProbe(1);
  CADSaveSheetsToPDF(FCAD, FCAD.Sheets, FFile);
  TmpRaw := RawFile;
  Assert.AreEqual(0, CountOf(' gs', PDFContent(FFile)), 'no gs');
  Assert.AreEqual(0, CountOf('/ExtGState', TmpRaw), 'no resource');
  Assert.AreEqual(1, CountOf('%%EOF', TmpRaw), 'and no update of the file');
end;

procedure TCADPDFAlphaTests.AGradientInterpolatesItsAlphaPerBand;
var
  TmpContent: string;
  TmpMatch: TMatch;
  TmpSeen: TStringList;
begin
  AddProbe(2);
  CADSaveSheetsToPDF(FCAD, FCAD.Sheets, FFile);
  TmpContent := PDFContent(FFile);
  Assert.IsTrue(Pos('/CADf20 gs', TmpContent) > 0, 'the first band''s alpha');
  Assert.IsTrue(Pos('/CADfE0 gs', TmpContent) > 0, 'the last band''s alpha');
  TmpSeen := TStringList.Create;
  try
    TmpSeen.Sorted := True;
    TmpSeen.Duplicates := dupIgnore;
    for TmpMatch in TRegEx.Matches(TmpContent, '/CADf[0-9A-F]{2} gs') do
      TmpSeen.Add(TmpMatch.Value);
    Assert.IsTrue(TmpSeen.Count > 100,
      Format('%d alphas across the bands', [TmpSeen.Count]));
  finally
    TmpSeen.Free;
  end;
end;

procedure TCADPDFAlphaTests.LinksAndAlphaGoOnTheSamePage;
var
  TmpRaw: string;
begin
  AddProbe(0);
  CADSaveSheetsToPDF(FCAD, FCAD.Sheets, FFile, 0, -1,
    function(const ASheet: TCADSheet; const AIndex: Integer): TCADPDFLinks
    begin
      Result := [TCADPDFLink.Create(Rect2D(10, 20, 60, 40),
        'https://example.com/plan')];
    end);
  TmpRaw := RawFile;
  Assert.AreEqual(2, CountOf('%%EOF', TmpRaw), 'one update for the two');
  { The page as updated carries both: a reader takes the newest. }
  Assert.IsTrue(TRegEx.IsMatch(TmpRaw,
    '/Type/Page(?!s)[^\r\n]*/Annots\[[^\]]*\d+ 0 R[^\r\n]*/ExtGState<<'),
    'the link and the alpha on one page dictionary');
end;

procedure TCADPDFAlphaTests.ThePageRouteCarriesAlphaToo;
var
  TmpProbe: TPDFAlphaProbe2D;
begin
  TmpProbe := TPDFAlphaProbe2D.Create(-1, Point2D(1, 1), Point2D(209, 296));
  TmpProbe.Mode := 0;
  FCAD.AddObject(-1, TmpProbe);
  CADSavePagesToPDF(FCAD, TCADPageSetup.Default, FFile);
  Assert.IsTrue(Pos('/CADf38 gs', PDFContent(FFile)) > 0, 'the gs');
  Assert.IsTrue(Abs(Alpha('CADf38', 'ca', RawFile) - 0.22) <= 0.005,
    'the resource');
end;

function TCADTextAgreementTests.Spec(const AHeight,
  AEscapement: Integer): TCADFontSpec;
begin
  Result := TCADFontSpec.Default;
  Result.FaceName := 'Arial';
  Result.Height := AHeight;
  Result.Escapement := AEscapement;
end;

function TCADTextAgreementTests.FNCInk(const AW, AH: Integer;
  const AText: string; const AFont: TCADFontSpec; const R: TRect;
  const AFlags: Cardinal; out ABottom: Integer): TPointF;
var
  TmpG: TTMSFNCGraphics;
  TmpFNC: TCADFNCGraphics;
  TmpR: TRect;
  X, Y, N: Integer;
  SX, SY: Double;
begin
  TmpG := TTMSFNCGraphics.CreateBitmapCanvas(AW, AH, False, False);
  try
    TmpG.BeginScene;
    try
      TmpG.Fill.Kind := gfkSolid;
      TmpG.Fill.Color := gcWhite;
      TmpG.Stroke.Kind := gskNone;
      TmpG.DrawRectangle(RectF(0, 0, AW, AH), gcrmNone);
      TmpFNC := TCADFNCGraphics.Create(TmpG, Rect(0, 0, AW, AH), False);
      try
        TmpFNC.SelectFont(AFont);
        TmpFNC.FontColor := cadclBlack;
        TmpFNC.Transparent := True;
        TmpR := R;
        TmpFNC.DrawText(AText, TmpR, AFlags);
      finally
        TmpFNC.Free;
      end;
    finally
      TmpG.EndScene;
    end;
    N := 0;
    SX := 0;
    SY := 0;
    ABottom := -1;
    for Y := 0 to AH - 1 do
      for X := 0 to AW - 1 do
        if RedOf(TmpG.Bitmap.Canvas.Pixels[X, Y]) < 160 then
        begin
          Inc(N);
          SX := SX + X;
          SY := SY + Y;
          ABottom := Y;
        end;
    Assert.IsTrue(N > 30, 'FNC drew something: ' + IntToStr(N));
    Result := PointF(SX / N, SY / N);
  finally
    TmpG.Free;
  end;
end;

function TCADTextAgreementTests.GDIInk(const AW, AH: Integer;
  const AText: string; const AFont: TCADFontSpec; const R: TRect;
  const AFlags: Cardinal): TPointF;
var
  TmpDC: HDC;
  TmpBmp: HBITMAP;
  TmpOld: HGDIOBJ;
  TmpInfo: TBitmapInfo;
  TmpBits: Pointer;
  TmpG: TCADGDIGraphics;
  TmpR: TRect;
  X, Y, N: Integer;
  SX, SY: Double;
begin
  TmpDC := CreateCompatibleDC(0);
  FillChar(TmpInfo, SizeOf(TmpInfo), 0);
  TmpInfo.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  TmpInfo.bmiHeader.biWidth := AW;
  TmpInfo.bmiHeader.biHeight := -AH;
  TmpInfo.bmiHeader.biPlanes := 1;
  TmpInfo.bmiHeader.biBitCount := 32;
  TmpInfo.bmiHeader.biCompression := BI_RGB;
  TmpBmp := CreateDIBSection(TmpDC, TmpInfo, DIB_RGB_COLORS, TmpBits, 0, 0);
  TmpOld := SelectObject(TmpDC, TmpBmp);
  try
    PatBlt(TmpDC, 0, 0, AW, AH, WHITENESS);
    TmpG := TCADGDIGraphics.Create(TmpDC, 0);
    try
      TmpG.SelectFont(AFont);
      TmpG.FontColor := cadclBlack;
      TmpG.Transparent := True;
      TmpR := R;
      TmpG.DrawText(AText, TmpR, AFlags);
    finally
      TmpG.Free;
    end;
    GdiFlush;
    N := 0;
    SX := 0;
    SY := 0;
    for Y := 0 to AH - 1 do
      for X := 0 to AW - 1 do
        if GetRValue(GetPixel(TmpDC, X, Y)) < 160 then
        begin
          Inc(N);
          SX := SX + X;
          SY := SY + Y;
        end;
    Assert.IsTrue(N > 30, 'GDI drew something: ' + IntToStr(N));
    Result := PointF(SX / N, SY / N);
  finally
    SelectObject(TmpDC, TmpOld);
    DeleteObject(TmpBmp);
    DeleteDC(TmpDC);
  end;
end;

procedure TCADTextAgreementTests.ATurnedLabelIsTheLevelLabelTurned;
const
  R: TRect = (Left: 100; Top: 180; Right: 300; Bottom: 220);
var
  TmpLevel, TmpTurned, TmpWant: TPointF;
  TmpC, TmpS, TmpDX, TmpDY: Double;
begin
  { The rule every output follows for turned text - FNC's PDF engine,
    the SVG, the metafile and the printer: lay the text out level in R's
    bounding box once turned (CADRotatedTextRect), then turn the lot
    about R's middle. Checked on GDI by drawing the label level in that
    box and turning its ink centre by hand. A label at 45 degrees,
    left-aligned: where turning about the line's start, as GDI does on
    its own, comes out furthest from it. }
  TmpLevel := GDIInk(400, 400, 'Milestone label', Spec(-22, 0),
    CADRotatedTextRect(R, 45), CAD_DT_SINGLELINE or CAD_DT_NOPREFIX);
  TmpTurned := GDIInk(400, 400, 'Milestone label', Spec(-22, 450), R,
    CAD_DT_SINGLELINE or CAD_DT_NOPREFIX);
  TmpC := Cos(DegToRad(45));
  TmpS := Sin(DegToRad(45));
  TmpDX := TmpLevel.X - 200;
  TmpDY := TmpLevel.Y - 200;
  { Counter-clockwise on the page, Y down. }
  TmpWant := PointF(200 + TmpDX * TmpC + TmpDY * TmpS,
    200 - TmpDX * TmpS + TmpDY * TmpC);
  { Within a few pixels: GDI hints turned glyphs differently from level
    ones. Turned about the line's start instead, it is twenty out. }
  Assert.IsTrue((Abs(TmpWant.X - TmpTurned.X) < 6) and
    (Abs(TmpWant.Y - TmpTurned.Y) < 6), Format('turned ink centre %.1f, ' +
    '%.1f; the level one turned %.1f, %.1f', [TmpTurned.X, TmpTurned.Y,
    TmpWant.X, TmpWant.Y]));
end;

{ : The box round the ink of AText drawn through the FNC backend onto an
  AW by AH bitmap. }
function FNCInkBox(const AW, AH: Integer; const AText: string;
  const AFont: TCADFontSpec; const R: TRect; const AFlags: Cardinal): TRect;
var
  TmpG: TTMSFNCGraphics;
  TmpFNC: TCADFNCGraphics;
  TmpR: TRect;
  X, Y: Integer;
begin
  Result := Rect(MaxInt, MaxInt, -1, -1);
  TmpG := TTMSFNCGraphics.CreateBitmapCanvas(AW, AH, False, False);
  try
    TmpG.BeginScene;
    try
      TmpG.Fill.Kind := gfkSolid;
      TmpG.Fill.Color := gcWhite;
      TmpG.Stroke.Kind := gskNone;
      TmpG.DrawRectangle(RectF(0, 0, AW, AH), gcrmNone);
      TmpFNC := TCADFNCGraphics.Create(TmpG, Rect(0, 0, AW, AH), False);
      try
        TmpFNC.SelectFont(AFont);
        TmpFNC.FontColor := cadclBlack;
        TmpFNC.Transparent := True;
        TmpR := R;
        TmpFNC.DrawText(AText, TmpR, AFlags);
      finally
        TmpFNC.Free;
      end;
    finally
      TmpG.EndScene;
    end;
    for Y := 0 to AH - 1 do
      for X := 0 to AW - 1 do
        if RedOf(TmpG.Bitmap.Canvas.Pixels[X, Y]) < 160 then
        begin
          Result.Left := Min(Result.Left, X);
          Result.Top := Min(Result.Top, Y);
          Result.Right := Max(Result.Right, X + 1);
          Result.Bottom := Max(Result.Bottom, Y + 1);
        end;
  finally
    TmpG.Free;
  end;
  Assert.IsTrue(Result.Right > 0, 'FNC drew something');
end;

procedure TCADTextAgreementTests.AnFNCTurnedLabelIsTheLevelLabelTurned;
const
  R: TRect = (Left: 100; Top: 180; Right: 300; Bottom: 220);
var
  TmpLevel, TmpTurned, TmpWant: TPointF;
  TmpBottom: Integer;
  TmpC, TmpS, TmpDX, TmpDY: Double;
begin
  { CS-15: the FNC backend follows the same rule as the rest - the
    label laid out level in CADRotatedTextRect, then turned about R's
    middle. Left-aligned, where any other pivot shows. }
  TmpLevel := FNCInk(400, 400, 'Milestone label', Spec(-22, 0),
    CADRotatedTextRect(R, 45), CAD_DT_SINGLELINE or CAD_DT_NOPREFIX,
    TmpBottom);
  TmpTurned := FNCInk(400, 400, 'Milestone label', Spec(-22, 450), R,
    CAD_DT_SINGLELINE or CAD_DT_NOPREFIX, TmpBottom);
  TmpC := Cos(DegToRad(45));
  TmpS := Sin(DegToRad(45));
  TmpDX := TmpLevel.X - 200;
  TmpDY := TmpLevel.Y - 200;
  TmpWant := PointF(200 + TmpDX * TmpC + TmpDY * TmpS,
    200 - TmpDX * TmpS + TmpDY * TmpC);
  Assert.IsTrue((Abs(TmpWant.X - TmpTurned.X) < 6) and
    (Abs(TmpWant.Y - TmpTurned.Y) < 6), Format('turned ink centre %.1f, ' +
    '%.1f; the level one turned %.1f, %.1f', [TmpTurned.X, TmpTurned.Y,
    TmpWant.X, TmpWant.Y]));
end;

procedure TCADTextAgreementTests.ALongTurnedLabelIsDrawnWhole;
const
  { Sized for the caption laid level: 300 by 20. }
  R: TRect = (Left: 50; Top: 190; Right: 350; Bottom: 210);
  Caption = 'Nieuwbouw ZS Reijerswaard';
var
  TmpLevel, TmpBox: TRect;
begin
  { CS-15: at 90 degrees FNC's own layout box is as narrow as the text is
    tall, and on FMX its text layout cut the caption down to its middle.
    The ink must be as long as the caption is when level. }
  TmpLevel := FNCInkBox(400, 400, Caption, Spec(-20, 0), R,
    CAD_DT_SINGLELINE or CAD_DT_CENTER or CAD_DT_VCENTER);
  TmpBox := FNCInkBox(400, 400, Caption, Spec(-20, 900), R,
    CAD_DT_SINGLELINE or CAD_DT_CENTER or CAD_DT_VCENTER);
  Assert.IsTrue(Abs((TmpBox.Bottom - TmpBox.Top) - (TmpLevel.Right -
    TmpLevel.Left)) <= 3, Format('turned %d tall, level %d long',
    [TmpBox.Bottom - TmpBox.Top, TmpLevel.Right - TmpLevel.Left]));
  Assert.IsTrue(TmpBox.Right - TmpBox.Left <= 30, 'and upright: ' +
    IntToStr(TmpBox.Right - TmpBox.Left));
  Assert.IsTrue(Abs((TmpBox.Top + TmpBox.Bottom) / 2 - 200) <= 3,
    Format('centred on R: %d..%d', [TmpBox.Top, TmpBox.Bottom]));
  { Left-aligned, the line starts at the level box's left edge - 10
    pixels left of the middle - which turned is 10 below it, and runs
    up. }
  TmpBox := FNCInkBox(400, 400, Caption, Spec(-20, 900), R,
    CAD_DT_SINGLELINE or CAD_DT_VCENTER);
  Assert.IsTrue(Abs(TmpBox.Bottom - 210) <= 4, Format('starts at %d, ' +
    'wanted 210', [TmpBox.Bottom]));
end;

procedure TCADTextAgreementTests.AWrappedLabelIsCentredOnEveryBackend;
const
  R: TRect = (Left: 50; Top: 50; Right: 250; Bottom: 350);
  Text = 'Opstellen vraagspecificatie Realisatiecontract Reijerswaard';
  Flags = CAD_DT_WORDBREAK or CAD_DT_CENTER or CAD_DT_VCENTER;
var
  TmpGDI, TmpVCL, TmpFNC: TRect;
  TmpBmp: Vcl.Graphics.TBitmap;
  TmpVG: TCADVCLGraphics;
  TmpR: TRect;
  X, Y: Integer;
begin
  { CS-16: GDI centres only a single line; wrapped, the label sat at the
    top of its box in the metafile and on the printer. }
  TmpGDI := PaintedInkBox(300, 400,
    procedure(const ADC: HDC)
    var
      TmpG: TCADGDIGraphics;
      TmpR: TRect;
    begin
      TmpG := TCADGDIGraphics.Create(ADC, 0);
      try
        TmpG.SelectFont(Spec(-20, 0));
        TmpG.FontColor := cadclBlack;
        TmpG.Transparent := True;
        TmpR := R;
        TmpG.DrawText(Text, TmpR, Flags);
      finally
        TmpG.Free;
      end;
    end);
  Assert.IsTrue(TmpGDI.Bottom - TmpGDI.Top > 40, 'wrapped: ' +
    IntToStr(TmpGDI.Bottom - TmpGDI.Top));
  Assert.IsTrue(Abs((TmpGDI.Top + TmpGDI.Bottom) / 2 - 200) <= 6,
    Format('GDI ink %d..%d, box 50..350', [TmpGDI.Top, TmpGDI.Bottom]));

  TmpBmp := Vcl.Graphics.TBitmap.Create;
  try
    TmpBmp.SetSize(300, 400);
    TmpBmp.Canvas.Brush.Color := clWhite;
    TmpBmp.Canvas.FillRect(Rect(0, 0, 300, 400));
    TmpVG := TCADVCLGraphics.Create(TmpBmp.Canvas);
    try
      TmpVG.SelectFont(Spec(-20, 0));
      TmpVG.FontColor := cadclBlack;
      TmpVG.Transparent := True;
      TmpR := R;
      TmpVG.DrawText(Text, TmpR, Flags);
    finally
      TmpVG.Free;
    end;
    TmpVCL := Rect(MaxInt, MaxInt, -1, -1);
    for Y := 0 to 399 do
      for X := 0 to 299 do
        if RedOf(TmpBmp.Canvas.Pixels[X, Y]) < 160 then
        begin
          TmpVCL.Top := Min(TmpVCL.Top, Y);
          TmpVCL.Bottom := Max(TmpVCL.Bottom, Y + 1);
        end;
  finally
    TmpBmp.Free;
  end;
  Assert.IsTrue(Abs((TmpVCL.Top + TmpVCL.Bottom) / 2 - 200) <= 6,
    Format('VCL ink %d..%d, box 50..350', [TmpVCL.Top, TmpVCL.Bottom]));

  TmpFNC := FNCInkBox(300, 400, Text, Spec(-20, 0), R, Flags);
  Assert.IsTrue(Abs((TmpFNC.Top + TmpFNC.Bottom) / 2 - 200) <= 6,
    Format('FNC ink %d..%d, box 50..350', [TmpFNC.Top, TmpFNC.Bottom]));
end;

procedure TCADTextAgreementTests.SVGLaysTurnedTextOutAsFNCDoes;
var
  TmpSVG: TCADSVGGraphics;
  TmpR: TRect;
  TmpText: string;
begin
  TmpSVG := TCADSVGGraphics.Create(400, 400, 0);
  try
    TmpSVG.SelectFont(Spec(-20, 900));
    TmpR := Rect(0, 0, 200, 40);
    TmpSVG.DrawText('Up', TmpR, CAD_DT_SINGLELINE);
    TmpText := TmpSVG.SVGText;
  finally
    TmpSVG.Free;
  end;
  { A quarter turn about the middle (100, 20); laid out left-aligned in
    the turned box, which is 40 wide and starts at x 80. }
  Assert.IsTrue(Pos('rotate(-90 100 20)', TmpText) > 0, TmpText);
  Assert.IsTrue(Pos('<tspan x="80"', TmpText) > 0, TmpText);
end;

procedure TCADTextAgreementTests.WrappedTextIsAsTallAsItWasMeasured;
const
  Text = 'The quick brown fox jumps over the lazy dog, and then over the ' +
    'lazy dog again, and once more for luck.';
var
  TmpG: TTMSFNCGraphics;
  TmpFNC: TCADFNCGraphics;
  TmpMeasured, TmpLine: TRect;
  TmpBottom: Integer;
begin
  { At a 600 dpi size: a 2.5 mm font is about 60 dots. }
  TmpG := TTMSFNCGraphics.CreateBitmapCanvas(16, 16, False, False);
  try
    TmpG.BeginScene;
    try
      TmpFNC := TCADFNCGraphics.Create(TmpG, Rect(0, 0, 16, 16), False);
      try
        TmpFNC.SelectFont(Spec(-60, 0));
        TmpMeasured := Rect(0, 0, 900, 0);
        TmpFNC.DrawText(Text, TmpMeasured, CAD_DT_WORDBREAK or
          CAD_DT_CALCRECT);
        TmpLine := Rect(0, 0, 0, 0);
        TmpFNC.DrawText('Wg', TmpLine, CAD_DT_SINGLELINE or CAD_DT_CALCRECT);
      finally
        TmpFNC.Free;
      end;
    finally
      TmpG.EndScene;
    end;
  finally
    TmpG.Free;
  end;
  Assert.IsTrue(TmpMeasured.Bottom > 2 * TmpLine.Bottom,
    'measured as several lines');
  FNCInk(1000, 1200, Text, Spec(-60, 0), Rect(0, 0, 900, 1200),
    CAD_DT_WORDBREAK, TmpBottom);
  { The ink of the last line ends inside the measured height, and below
    the line above it. }
  Assert.IsTrue((TmpBottom <= TmpMeasured.Bottom + 2) and
    (TmpBottom > TmpMeasured.Bottom - TmpLine.Bottom), Format('ink ends at ' +
    '%d, measured %d, a line is %d', [TmpBottom, TmpMeasured.Bottom,
    TmpLine.Bottom]));
end;

initialization

TDUnitX.RegisterTestFixture(TCADImageExportTests);
TDUnitX.RegisterTestFixture(TCADTextAgreementTests);
TDUnitX.RegisterTestFixture(TCADPDFExtrasTests);
TDUnitX.RegisterTestFixture(TCADPDFPaperTests);
TDUnitX.RegisterTestFixture(TCADPDFAlphaTests);
TDUnitX.RegisterTestFixture(TCADGDIExportTests);
TDUnitX.RegisterTestFixture(TCADSVGExportTests);
TDUnitX.RegisterTestFixture(TCADFNCGraphicsTests);

end.
