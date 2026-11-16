{ : DUnitX tests for the page model (VCL.FNCCS4Print) and for the two
  things that had to become physical before printing could mean
  anything: a pen's line weight and the hatch spacing.

  The page model is a value and a handful of functions over it, which
  is exactly what a console runner can hold to account - no printer, no
  window, no canvas. The one test that does draw uses the recording
  backend from CADSys4.Tests.Graphics, so "did the page transform put
  the drawing where it said it would" is answered in device coordinates
  rather than by looking at a preview.

  The arithmetic in here is deliberately done with round numbers -
  A4 at 25.4 dpi is one pixel to the millimetre - so an assertion that
  fails says which number is wrong instead of by how much. }
unit CADSys4.Tests.Print;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Math, System.IOUtils,
  System.JSON,
  DUnitX.TestFramework,
  VCL.FNCCS4BaseTypes, VCL.FNCCS4Graphics, VCL.FNCCADSys4, VCL.FNCCS4Shapes,
  VCL.FNCCS4JSON, VCL.FNCCS4Views, VCL.FNCCS4Print, VCL.FNCCadSysRegister,
  CADSys4.Tests.Graphics;

type
  [TestFixture]
  TCADPageModelTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    { : A4 portrait, 10 mm margins - so the printable area is 190 x 277
      and every expected number below is a whole one. }
    function A4: TCADPageSetup;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure PaperSizes_AreTheStandardMillimetres;
    [Test]
    procedure Landscape_SwapsTheSheet;
    [Test]
    procedure PrintableSize_IsTheSheetLessTheMargins;
    [Test]
    procedure MarginsLargerThanTheSheet_AreRefused;
    [Test]
    procedure FitToPage_TakesTheAxisThatRunsOutOfPaperFirst;
    [Test]
    procedure FitToPage_CentresTheDrawingOnTheSheet;
    [Test]
    procedure FitToPage_IsAlwaysOnePage;
    [Test]
    procedure AScaledDrawingTooWideForOneSheet_IsTiled;
    [Test]
    procedure UntiledIsOnePageHoweverBigTheDrawing;
    [Test]
    procedure TiledPagesStartAtTheTopLeftAndRunRightThenDown;
    [Test]
    procedure AnEmptySetupTakesItsWindowFromTheDrawing;
    [Test]
    procedure PrintableRectInPixels_FollowsTheResolution;
    [Test]
    procedure APreviewBoxCentresTheSheetAndKeepsItsShape;
    [Test]
    procedure DrawPage_PutsTheDrawingInsideTheMargins;
    [Test]
    procedure DrawPage_ClipsToThePrintableArea;
    [Test]
    procedure DrawPage_LeavesAHiddenLayerOut;
    [Test]
    procedure DrawPage_LeavesTheCanvasScaleAsItFoundIt;
    [Test]
    procedure HiddenLayers_AreNotPrinted;
  end;

  { : The millimetre figures, which are what makes a print look like a
    drawing rather than like a fax. }
  [TestFixture]
  TPhysicalSizeTests = class(TObject)
  public
    [Test]
    procedure AWeightedPenTakesItsWidthFromTheDevice;
    [Test]
    procedure AWeightedPenOnAScreenChangesNothing;
    [Test]
    procedure AWeightThatWouldRoundToNothingStillDrawsOnePixel;
    [Test]
    procedure AssignGivesTheMillimetresTheLastWord;
    [Test]
    procedure AStoredPenKeepsItsWeightAndTouchesNoWidth;
    [Test]
    procedure HatchSpacingCanBeGivenPerCall;
    [Test]
    procedure SaveAndRestoreCarryTheWeight;
    [Test]
    procedure ClipsNestInnermostFirst;
    [Test]
    procedure AClipIsTrimmedToTheOneOutsideIt;
    [Test]
    procedure PopAllClipsGivesBackWhatIsLeft;
  end;

  { : A page setup is a value that has to survive being written down.

    The same shape as TCADViewSpecTests, because it is the same problem
    and the answers should not differ: a document with a kind, names
    rather than ordinals for the enumerations, and a drawing path that
    is relative in the file and absolute in memory. }
  [TestFixture]
  TCADPageSetupPersistenceTests = class(TObject)
  private
    fDir: String;
    function TempFile(const AName: String): String;
    { : A setup with nothing left at its default, so a field that fails
      to round-trip cannot hide behind one that happens to match. }
    function Populated: TCADPageSetup;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure EveryFieldSurvivesTheRoundTrip;
    [Test]
    procedure TheViewGoesInWholeAndComesBackWhole;
    [Test]
    procedure EnumerationsAreWrittenAsNamesNotOrdinals;
    [Test]
    procedure ADrawingDocumentIsNotAPageSetup;
    [Test]
    procedure AnUnknownPaperNameKeepsWhatWasThere;
    [Test]
    procedure TheDrawingPathIsRelativeInTheFileAndAbsoluteInMemory;
    [Test]
    procedure AFieldTheDocumentDoesNotMentionIsLeftAlone;
  end;

implementation

{ ==================================================================
  TCADPageModelTests
  ================================================================== }

procedure TCADPageModelTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
end;

procedure TCADPageModelTests.TearDown;
begin
  FCAD.Free;
  FCAD := nil;
end;

function TCADPageModelTests.A4: TCADPageSetup;
begin
  Result := TCADPageSetup.Default;
  Result.Paper := pkA4;
  Result.Orientation := pgoPortrait;
  Result.Margins := TCADPageMargins.Uniform(10);
end;

procedure TCADPageModelTests.PaperSizes_AreTheStandardMillimetres;
var
  TmpW, TmpH: TRealType;
begin
  CADPaperSizeMM(pkA4, TmpW, TmpH);
  Assert.AreEqual(210.0, TmpW, 0.001, 'A4 width');
  Assert.AreEqual(297.0, TmpH, 0.001, 'A4 height');
  CADPaperSizeMM(pkA3, TmpW, TmpH);
  Assert.AreEqual(297.0, TmpW, 0.001, 'A3 is A4 turned and doubled');
  Assert.AreEqual(420.0, TmpH, 0.001, 'A3 height');
  Assert.AreEqual('A3', CADPaperKindName(pkA3), 'and it has a name');
end;

procedure TCADPageModelTests.Landscape_SwapsTheSheet;
var
  TmpSetup: TCADPageSetup;
  TmpW, TmpH: TRealType;
begin
  TmpSetup := A4;
  TmpSetup.Orientation := pgoLandscape;
  TmpSetup.PaperSizeMM(TmpW, TmpH);
  Assert.AreEqual(297.0, TmpW, 0.001, 'landscape width');
  Assert.AreEqual(210.0, TmpH, 0.001, 'landscape height');
end;

procedure TCADPageModelTests.PrintableSize_IsTheSheetLessTheMargins;
var
  TmpSetup: TCADPageSetup;
  TmpW, TmpH: TRealType;
begin
  TmpSetup := A4;
  TmpSetup.PrintableSizeMM(TmpW, TmpH);
  Assert.AreEqual(190.0, TmpW, 0.001, '210 less two 10s');
  Assert.AreEqual(277.0, TmpH, 0.001, '297 less two 10s');
end;

procedure TCADPageModelTests.MarginsLargerThanTheSheet_AreRefused;
var
  TmpSetup: TCADPageSetup;
begin
  TmpSetup := A4;
  TmpSetup.Margins := TCADPageMargins.Uniform(200);
  Assert.WillRaise(
    procedure
    var
      TmpW, TmpH: TRealType;
      TmpLocal: TCADPageSetup;
    begin
      TmpLocal := TmpSetup;
      TmpLocal.PrintableSizeMM(TmpW, TmpH);
    end, ECADPageError, 'a sheet that is all margin has no page on it');
end;

procedure TCADPageModelTests.FitToPage_TakesTheAxisThatRunsOutOfPaperFirst;
var
  TmpSetup: TCADPageSetup;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfFitToPage;
  TmpSetup.KeepAspect := True;

  { 380 wide on 190 mm of paper is 2 units per millimetre; 277 tall on
    277 mm is 1. The wider one wins, or the drawing runs off the side. }
  TmpSetup.View.Window := Rect2D(0, 0, 380, 277);
  Assert.AreEqual(2.0, TmpSetup.EffectiveUnitsPerMM(FCAD), 0.0001,
    'width decides');

  TmpSetup.View.Window := Rect2D(0, 0, 190, 554);
  Assert.AreEqual(2.0, TmpSetup.EffectiveUnitsPerMM(FCAD), 0.0001,
    'and height decides when height is the tighter one');
end;

procedure TCADPageModelTests.FitToPage_CentresTheDrawingOnTheSheet;
var
  TmpSetup: TCADPageSetup;
  TmpWin: TRect2D;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfFitToPage;
  TmpSetup.KeepAspect := True;
  { A square drawing on a tall sheet: the page window has to grow
    downwards and upwards equally, or the drawing prints against one
    edge with all the white space at the other. }
  TmpSetup.View.Window := Rect2D(0, 0, 100, 100);
  TmpWin := TmpSetup.PageWindow(FCAD, 0);

  Assert.AreEqual(0.0, TmpWin.Left, 0.001, 'nothing added on the left');
  Assert.AreEqual(100.0, TmpWin.Right, 0.001, 'nor on the right');
  Assert.AreEqual(50.0, (TmpWin.Bottom + TmpWin.Top) / 2, 0.001,
    'the drawing stays in the middle');
  Assert.AreEqual(277.0 / 190.0, (TmpWin.Top - TmpWin.Bottom) /
    (TmpWin.Right - TmpWin.Left), 0.0001,
    'and the window comes out the paper''s shape');
end;

procedure TCADPageModelTests.FitToPage_IsAlwaysOnePage;
var
  TmpSetup: TCADPageSetup;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfFitToPage;
  TmpSetup.Tiled := True;
  TmpSetup.View.Window := Rect2D(0, 0, 10000, 10000);
  Assert.AreEqual(1, TmpSetup.PageCount(FCAD),
    'fitting to the page is what one page means');
end;

procedure TCADPageModelTests.AScaledDrawingTooWideForOneSheet_IsTiled;
var
  TmpSetup: TCADPageSetup;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := 1;
  TmpSetup.Tiled := True;
  { 380 units across 190 mm of printable width, at 1:1, is two sheets. }
  TmpSetup.View.Window := Rect2D(0, 0, 380, 277);
  Assert.AreEqual(2, TmpSetup.PagesAcross(FCAD), 'two across');
  Assert.AreEqual(1, TmpSetup.PagesDown(FCAD), 'one down');
  Assert.AreEqual(2, TmpSetup.PageCount(FCAD), 'two pages');

  { And exactly one sheet wide is exactly one sheet, not two. }
  TmpSetup.View.Window := Rect2D(0, 0, 190, 277);
  Assert.AreEqual(1, TmpSetup.PageCount(FCAD),
    'a drawing that just fits does not spill onto a second sheet');
end;

procedure TCADPageModelTests.UntiledIsOnePageHoweverBigTheDrawing;
var
  TmpSetup: TCADPageSetup;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := 1;
  TmpSetup.Tiled := False;
  TmpSetup.View.Window := Rect2D(0, 0, 3800, 2770);
  Assert.AreEqual(1, TmpSetup.PageCount(FCAD),
    'not tiled means one sheet and the rest off the edge');
end;

procedure TCADPageModelTests.TiledPagesStartAtTheTopLeftAndRunRightThenDown;
var
  TmpSetup: TCADPageSetup;
  TmpFirst, TmpSecond: TRect2D;
begin
  TmpSetup := A4;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := 1;
  TmpSetup.Tiled := True;
  TmpSetup.View.Window := Rect2D(0, 0, 380, 277);

  TmpFirst := TmpSetup.PageWindow(FCAD, 0);
  TmpSecond := TmpSetup.PageWindow(FCAD, 1);

  { Page one is the top-left corner of the drawing - which is the sheet
    a reader picks up first and the one they lay the others against. }
  Assert.AreEqual(0.0, TmpFirst.Left, 0.001, 'page 1 starts at the left');
  Assert.AreEqual(277.0, TmpFirst.Top, 0.001, 'and at the top');
  Assert.AreEqual(190.0, TmpFirst.Right, 0.001, 'one printable width across');
  Assert.AreEqual(190.0, TmpSecond.Left, 0.001,
    'page 2 carries on where page 1 stopped');
  Assert.AreEqual(380.0, TmpSecond.Right, 0.001, 'to the end of the drawing');
end;

procedure TCADPageModelTests.AnEmptySetupTakesItsWindowFromTheDrawing;
var
  TmpSetup: TCADPageSetup;
  TmpWin: TRect2D;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(60, 40)));
  TmpSetup := A4;
  { View.Window is left as Default leaves it.

    This is the test that caught TCADPageSetup.Default handing back
    TCADViewSpec.Default's window, which is -100..100 - a good place
    for a viewport to open and a silly thing to print. A setup nobody
    has pointed anywhere prints the drawing. }
  TmpWin := TmpSetup.EffectiveWindow(FCAD);
  Assert.AreEqual(0.0, TmpWin.Left, 0.001, 'the drawing''s own extension');
  Assert.AreEqual(60.0, TmpWin.Right, 0.001, 'right');
  Assert.AreEqual(40.0, TmpWin.Top, 0.001, 'top');
end;

procedure TCADPageModelTests.PrintableRectInPixels_FollowsTheResolution;
var
  TmpSetup: TCADPageSetup;
  TmpDevice: TCADPageDevice;
  TmpRect: TRect;
begin
  TmpSetup := A4;
  { 25.4 dots per inch is one dot per millimetre, so every number below
    is the millimetre figure and a wrong one is obvious. }
  TmpDevice := TCADPageDevice.FromDPI(25.4, 25.4);
  TmpRect := CADPrintableRectPx(TmpSetup, TmpDevice);
  Assert.AreEqual(10, TmpRect.Left, 'the left margin');
  Assert.AreEqual(10, TmpRect.Top, 'the top margin');
  Assert.AreEqual(200, TmpRect.Right, '210 less the right margin');
  Assert.AreEqual(287, TmpRect.Bottom, '297 less the bottom margin');

  { A printer's canvas starts at the printable area, so the sheet
    begins off the top-left of it - which is what the offsets are for. }
  TmpDevice.OffsetXPx := -12;
  TmpDevice.OffsetYPx := -12;
  TmpRect := CADPrintableRectPx(TmpSetup, TmpDevice);
  Assert.AreEqual(-2, TmpRect.Left,
    'a 10 mm margin on a sheet that starts 12 mm off the canvas');
end;

procedure TCADPageModelTests.APreviewBoxCentresTheSheetAndKeepsItsShape;
var
  TmpDevice: TCADPageDevice;
begin
  { A portrait sheet in a square box: height is the tight one, so the
    sheet fills it top to bottom and is centred left to right. }
  TmpDevice := TCADPageDevice.ToBox(210, 297, 400, 400);
  Assert.AreEqual(TmpDevice.PixelsPerMMX, TmpDevice.PixelsPerMMY, 0.000001,
    'one scale for both axes, or the sheet is not a sheet');
  Assert.AreEqual(400.0 / 297.0, TmpDevice.PixelsPerMMY, 0.0001,
    'the height fills the box');
  Assert.AreEqual(0, TmpDevice.OffsetYPx, 'nothing to spare vertically');
  Assert.IsTrue(TmpDevice.OffsetXPx > 0, 'and the sheet is centred across');
end;

procedure TCADPageModelTests.DrawPage_PutsTheDrawingInsideTheMargins;
var
  TmpSetup: TCADPageSetup;
  TmpDevice: TCADPageDevice;
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpLog: string;
begin
  { One millimetre to the pixel, 1:1, so a line from (10,10) to
    (100,50) in the drawing has to land inside the printable rectangle
    (10,10)-(200,287) - and near its bottom, because paper counts
    downwards and drawings count up. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(10, 10), Point2D(100, 50)));
  TmpSetup := A4;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := 1;
  TmpSetup.View.Window := Rect2D(0, 0, 190, 277);
  TmpDevice := TCADPageDevice.FromDPI(25.4, 25.4);

  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 210, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawPage(FCAD, TmpSetup, TmpDevice, 0, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    TmpLog := TmpRec.Log.Text;
    Assert.IsTrue(TmpRec.CountOf('LineTo') > 0, 'the line was drawn at all');
    { The Y flip is the part that is silently wrong if it is wrong: a
      drawing printed upside down still looks like a drawing. World Y 10
      is 10 mm off the bottom of a 277 mm page, so it belongs near
      device Y 277, not near 10. }
    Assert.IsTrue(TmpLog.Contains('276') or TmpLog.Contains('277'),
      'the bottom of the drawing is at the bottom of the page: ' + TmpLog);
    Assert.IsTrue(TmpLog.Contains('19,') or TmpLog.Contains('20,'),
      'and 10 mm in from a 10 mm margin is 20 mm across: ' + TmpLog);
  finally
    TmpRec.Free;
  end;
end;

procedure TCADPageModelTests.DrawPage_ClipsToThePrintableArea;
var
  TmpSetup: TCADPageSetup;
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpLog: string;
begin
  { Without this, a drawing spread over several sheets draws all of
    itself on every one of them - over the margins, off the paper, and
    on a preview control across the rest of the window. Found by looking
    at a tiled preview; nothing in the geometry was wrong.

    The transform's window cannot do the job: a shape uses it to decide
    whether to draw at all, and a line crossing the page boundary has to
    be drawn because part of it belongs here. Only the device can cut it
    at the edge, which is why TCADGraphics grew PushClip. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(-500, -500),
    Point2D(5000, 5000)));
  TmpSetup := A4;
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 210, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawPage(FCAD, TmpSetup, TCADPageDevice.FromDPI(25.4, 25.4), 0,
        TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    TmpLog := TmpRec.Log.Text;
    Assert.IsTrue(TmpLog.Contains('PushClip 10,10,200,287'),
      'clipped to the printable rectangle, not the paper or the surface: '
      + TmpLog);
    Assert.AreEqual(1, TmpRec.CountOf('PopClip'),
      'and given back - a clip left behind takes the next thing drawn '
      + 'with it');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADPageModelTests.DrawPage_LeavesAHiddenLayerOut;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpHidden: TObject2D;
begin
  { CS-U2, on the page route as well as the sheet's: a layer that is off
    does not print. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(100, 100)));
  TmpHidden := TLine2D.Create(-1, Point2D(0, 100), Point2D(100, 0));
  { After AddObject, which puts an object on the current layer. }
  FCAD.AddObject(-1, TmpHidden);
  TmpHidden.Layer := 1;
  FCAD.Layers[1].Visible := False;
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 210, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawPage(FCAD, A4, TCADPageDevice.FromDPI(25.4, 25.4), 0, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    Assert.AreEqual(1, TmpRec.CountOf('MoveTo'), 'only the visible line: ' +
      TmpRec.Log.Text);
  finally
    TmpRec.Free;
  end;
end;

procedure TCADPageModelTests.DrawPage_LeavesTheCanvasScaleAsItFoundIt;
var
  TmpSetup: TCADPageSetup;
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  { The canvas handed to CADDrawPage may well be a screen's, and a
    printer's millimetre scale left behind on it would make every line
    afterwards six times too thick. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(50, 50)));
  TmpSetup := A4;
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 210, 297));
  try
    TmpRec.PixelsPerMM := 0;
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawPage(FCAD, TmpSetup, TCADPageDevice.FromDPI(600, 600), 0,
        TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    Assert.AreEqual(0.0, TmpRec.PixelsPerMM, 0.000001,
      'the page put the screen''s scale back');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADPageModelTests.HiddenLayers_AreNotPrinted;
var
  TmpSetup: TCADPageSetup;
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpObj: TLine2D;
  TmpWithout, TmpWith: Integer;

  function DrawAndCount: Integer;
  begin
    TmpRec := TRecordingGraphics.Create(Rect(0, 0, 210, 297));
    try
      TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
      try
        CADDrawPage(FCAD, TmpSetup, TCADPageDevice.FromDPI(25.4, 25.4), 0,
          TmpCanvas);
      finally
        TmpCanvas.Free;
      end;
      Result := TmpRec.CountOf('LineTo');
    finally
      TmpRec.Free;
    end;
  end;

begin
  FCAD.CurrentLayer := 5;
  TmpObj := TLine2D.Create(-1, Point2D(10, 10), Point2D(100, 50));
  FCAD.AddObject(-1, TmpObj);

  TmpSetup := A4;
  TmpSetup.Fit := pfScale;
  TmpSetup.UnitsPerMM := 1;
  TmpSetup.View.Window := Rect2D(0, 0, 190, 277);

  TmpWithout := DrawAndCount;
  Assert.IsTrue(TmpWithout > 0, 'the line prints when nothing hides it');

  { The same override a saved view carries - which is the point of the
    setup holding a TCADViewSpec rather than a window of its own. }
  TmpSetup.View.UseLayerOverride := True;
  TmpSetup.View.HiddenLayers := [5];
  TmpWith := DrawAndCount;
  Assert.AreEqual(0, TmpWith, 'and not when its layer is hidden');
end;

{ ==================================================================
  TPhysicalSizeTests
  ================================================================== }

procedure TPhysicalSizeTests.AWeightedPenTakesItsWidthFromTheDevice;
var
  TmpRec: TRecordingGraphics;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.PixelsPerMM := 10;
    TmpRec.Pen.LineWeightMM := 0.5;
    Assert.AreEqual(5, TmpRec.Pen.Width, 'half a millimetre at 10 px/mm');
  finally
    TmpRec.Free;
  end;
end;

procedure TPhysicalSizeTests.AWeightedPenOnAScreenChangesNothing;
var
  TmpRec: TRecordingGraphics;
begin
  { PixelsPerMM is 0 on every surface that has not been told otherwise,
    which is every screen - and there the pixel width still rules.
    This is what makes the whole feature additive. }
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.Pen.Width := 3;
    TmpRec.Pen.LineWeightMM := 0.5;
    Assert.AreEqual(3, TmpRec.Pen.Width, 'the width the caller set');
    Assert.AreEqual(0.5, TmpRec.Pen.LineWeightMM, 0.0001,
      'and the weight is remembered for a device that can use it');
  finally
    TmpRec.Free;
  end;
end;

procedure TPhysicalSizeTests.AWeightThatWouldRoundToNothingStillDrawsOnePixel;
var
  TmpRec: TRecordingGraphics;
begin
  { A line nobody can see is not a thin line, it is a missing one. }
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.PixelsPerMM := 1;
    TmpRec.Pen.LineWeightMM := 0.05;
    Assert.AreEqual(1, TmpRec.Pen.Width, 'never thinner than a pixel');
  finally
    TmpRec.Free;
  end;
end;

procedure TPhysicalSizeTests.AssignGivesTheMillimetresTheLastWord;
var
  TmpRec: TRecordingGraphics;
  TmpStored: TCADSimplePen;
begin
  { A layer carries both: a pixel width for the screen and a weight for
    paper. On paper the weight has to win, and Assign copies the width
    first for exactly that reason. }
  TmpStored := TCADSimplePen.Create;
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpStored.Width := 1;
    TmpStored.LineWeightMM := 0.7;
    TmpRec.PixelsPerMM := 10;
    TmpRec.Pen.Assign(TmpStored);
    Assert.AreEqual(7, TmpRec.Pen.Width, '0.7 mm at 10 px/mm, not 1 pixel');
  finally
    TmpRec.Free;
    TmpStored.Free;
  end;
end;

procedure TPhysicalSizeTests.AStoredPenKeepsItsWeightAndTouchesNoWidth;
var
  TmpStored: TCADSimplePen;
begin
  { A layer's pen has no surface and no business guessing at one. }
  TmpStored := TCADSimplePen.Create;
  try
    TmpStored.Width := 2;
    TmpStored.LineWeightMM := 0.35;
    Assert.AreEqual(2, TmpStored.Width, 'the width is untouched');
    Assert.AreEqual(0.35, TmpStored.LineWeightMM, 0.0001, 'the weight is kept');
    Assert.IsTrue(TmpStored.OwnerGraphics = nil,
      'and it belongs to no graphics');
  finally
    TmpStored.Free;
  end;
end;

procedure TPhysicalSizeTests.HatchSpacingCanBeGivenPerCall;
var
  TmpPoly: array [0 .. 3] of TPoint;
  TmpWide, TmpTight: TCADHatchSegments;
begin
  TmpPoly[0] := Point(0, 0);
  TmpPoly[1] := Point(200, 0);
  TmpPoly[2] := Point(200, 200);
  TmpPoly[3] := Point(0, 200);
  TmpWide := CADHatchLines(TmpPoly, cbsHorizontal, 40);
  TmpTight := CADHatchLines(TmpPoly, cbsHorizontal, 10);
  Assert.IsTrue(Length(TmpTight) > Length(TmpWide),
    'a smaller spacing is more lines');
  { Which is the whole point on paper: the spacing stops being eight
    pixels and starts being two millimetres. }
  Assert.AreEqual(Length(CADHatchLines(TmpPoly, cbsHorizontal)),
    Length(CADHatchLines(TmpPoly, cbsHorizontal, 0)),
    'and zero means the pixel default, as it always did');
end;

procedure TPhysicalSizeTests.ClipsNestInnermostFirst;
var
  TmpRec: TRecordingGraphics;
begin
  { They did not, until sheets. A page clip with a viewport clip inside
    it is two levels, and the second one used to be dropped on the
    floor - which on paper is a viewport that paints over the rest of
    the sheet. }
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.PushClip(Rect(10, 10, 90, 90));
    Assert.AreEqual(1, TmpRec.ClipDepth, 'one down');
    TmpRec.PushClip(Rect(20, 20, 80, 80));
    Assert.AreEqual(2, TmpRec.ClipDepth, 'two down');
    TmpRec.PopClip;
    TmpRec.PopClip;
    Assert.AreEqual(0, TmpRec.ClipDepth, 'and both back');
    Assert.AreEqual(2, TmpRec.CountOf('PushClip'),
      'both clips reached the device');
    Assert.AreEqual(2, TmpRec.CountOf('PopClip'), 'and both were given back');
    Assert.IsTrue(TmpRec.Log.Text.Contains('PushClip 20,20,80,80'),
      'the inner one went down as itself: ' + TmpRec.Log.Text);
    { One more pop than push is a caller's mistake, not a device's. }
    TmpRec.PopClip;
    Assert.AreEqual(2, TmpRec.CountOf('PopClip'),
      'popping an empty stack asks the device for nothing');
  finally
    TmpRec.Free;
  end;
end;

procedure TPhysicalSizeTests.AClipIsTrimmedToTheOneOutsideIt;
var
  TmpRec: TRecordingGraphics;
begin
  { The intersection is done here rather than left to the backend
    because the backends disagree. GDI's IntersectClipRect narrows what
    is there; FNC's ClipRect replaces it, because GDI+'s SetClip
    combines by replacing. A viewport that asked for more than its page
    would get it on FMX and not on the VCL - the same drawing, two
    pictures, and only one of them on paper. }
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.PushClip(Rect(10, 10, 90, 90));
    TmpRec.PushClip(Rect(0, 0, 200, 200));
    Assert.IsTrue(TmpRec.Log.Text.Contains('PushClip 10,10,90,90'),
      'the inner clip was cut down to the outer one: ' + TmpRec.Log.Text);
    Assert.IsFalse(TmpRec.Log.Text.Contains('PushClip 0,0,200,200'),
      'and the device was never offered the larger rectangle');
  finally
    TmpRec.Free;
  end;
end;

procedure TPhysicalSizeTests.PopAllClipsGivesBackWhatIsLeft;
var
  TmpRec: TRecordingGraphics;
begin
  { What a backend calls when it is about to let go of the surface the
    clips belong to. On FMX an unbalanced canvas state is fatal rather
    than untidy - three of this port's FMX bugs were exactly that. }
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.PushClip(Rect(10, 10, 90, 90));
    TmpRec.PushClip(Rect(20, 20, 80, 80));
    TmpRec.PushClip(Rect(30, 30, 70, 70));
    TmpRec.PopAllClips;
    Assert.AreEqual(0, TmpRec.ClipDepth, 'nothing left in force');
    Assert.AreEqual(3, TmpRec.CountOf('PopClip'), 'and all three given back');
    TmpRec.PopAllClips;
    Assert.AreEqual(3, TmpRec.CountOf('PopClip'),
      'a second call has nothing to do');
  finally
    TmpRec.Free;
  end;
end;

procedure TPhysicalSizeTests.SaveAndRestoreCarryTheWeight;
var
  TmpRec: TRecordingGraphics;
  TmpState: TCADGraphicsState;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 100, 100));
  try
    TmpRec.PixelsPerMM := 10;
    TmpRec.Pen.LineWeightMM := 0.4;
    TmpState := TmpRec.SaveState;
    TmpRec.Pen.LineWeightMM := 2.0;
    Assert.AreEqual(20, TmpRec.Pen.Width, 'the new weight took effect');
    TmpRec.RestoreState(TmpState);
    Assert.AreEqual(4, TmpRec.Pen.Width, 'and the old one came back');
    Assert.AreEqual(0.4, TmpRec.Pen.LineWeightMM, 0.0001,
      'with the weight itself, not only the pixels');
  finally
    TmpRec.Free;
  end;
end;

{ ==================================================================
  TCADPageSetupPersistenceTests
  ================================================================== }

procedure TCADPageSetupPersistenceTests.Setup;
begin
  fDir := TPath.Combine(TPath.GetTempPath, 'cadsysfnc-pagesetup-'
    + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(fDir);
end;

procedure TCADPageSetupPersistenceTests.TearDown;
begin
  if (fDir <> '') and TDirectory.Exists(fDir) then
    TDirectory.Delete(fDir, True);
  fDir := '';
end;

function TCADPageSetupPersistenceTests.TempFile(const AName: String): String;
begin
  Result := TPath.Combine(fDir, AName);
end;

function TCADPageSetupPersistenceTests.Populated: TCADPageSetup;
begin
  Result := TCADPageSetup.Default;
  Result.Paper := pkA1;
  Result.Orientation := pgoLandscape;
  Result.Margins := TCADPageMargins.Sides(5, 6, 7, 8);
  Result.Fit := pfScale;
  Result.UnitsPerMM := 12.5;
  Result.KeepAspect := False;
  Result.Tiled := True;
  Result.View.Name := 'Ground floor';
  Result.View.DrawingFile := 'house.json';
  Result.View.Window := Rect2D(10, 20, 310, 220);
  Result.View.UseLayerOverride := True;
  Result.View.HiddenLayers := [3, 7, 255];
end;

procedure TCADPageSetupPersistenceTests.EveryFieldSurvivesTheRoundTrip;
var
  TmpSetup, TmpBack: TCADPageSetup;
  TmpDoc: TJSONObject;
begin
  TmpSetup := Populated;
  TmpBack := TCADPageSetup.Default;
  TmpDoc := TmpSetup.SaveToJSON;
  try
    TmpBack.LoadFromJSON(TmpDoc);
  finally
    TmpDoc.Free;
  end;

  Assert.IsTrue(TmpBack.Paper = pkA1, 'paper');
  Assert.IsTrue(TmpBack.Orientation = pgoLandscape, 'orientation');
  Assert.AreEqual(5.0, TmpBack.Margins.Left, 0.0001, 'left margin');
  Assert.AreEqual(6.0, TmpBack.Margins.Top, 0.0001, 'top margin');
  Assert.AreEqual(7.0, TmpBack.Margins.Right, 0.0001, 'right margin');
  Assert.AreEqual(8.0, TmpBack.Margins.Bottom, 0.0001, 'bottom margin');
  Assert.IsTrue(TmpBack.Fit = pfScale, 'fit');
  Assert.AreEqual(12.5, TmpBack.UnitsPerMM, 0.0001, 'the scale');
  Assert.IsFalse(TmpBack.KeepAspect, 'keep aspect');
  Assert.IsTrue(TmpBack.Tiled, 'tiled');
end;

procedure TCADPageSetupPersistenceTests.TheViewGoesInWholeAndComesBackWhole;
var
  TmpSetup, TmpBack: TCADPageSetup;
  TmpDoc: TJSONObject;
begin
  { The setup holds a TCADViewSpec rather than a copy of its fields, so
    what has to survive here is the view's own document nested inside
    this one - not a second, half-complete spelling of it. }
  TmpSetup := Populated;
  TmpBack := TCADPageSetup.Default;
  TmpDoc := TmpSetup.SaveToJSON;
  try
    TmpBack.LoadFromJSON(TmpDoc);
  finally
    TmpDoc.Free;
  end;

  Assert.AreEqual('Ground floor', TmpBack.View.Name, 'the view''s name');
  Assert.AreEqual(10.0, TmpBack.View.Window.Left, 0.0001, 'the window');
  Assert.AreEqual(220.0, TmpBack.View.Window.Top, 0.0001, 'and its top');
  Assert.IsTrue(TmpBack.View.UseLayerOverride, 'the layer override');
  Assert.IsTrue(3 in TmpBack.View.HiddenLayers, 'layer 3 is still hidden');
  Assert.IsTrue(255 in TmpBack.View.HiddenLayers, 'and so is 255');
  Assert.IsFalse(4 in TmpBack.View.HiddenLayers, 'and 4 was never hidden');
end;

procedure TCADPageSetupPersistenceTests.EnumerationsAreWrittenAsNamesNotOrdinals;
var
  TmpSetup: TCADPageSetup;
  TmpDoc: TJSONObject;
  TmpText: String;
begin
  { An ordinal is one insertion away from meaning something else. This
    is the test that notices if somebody writes Ord() into the file. }
  TmpSetup := Populated;
  TmpDoc := TmpSetup.SaveToJSON;
  try
    TmpText := JSONToText(TmpDoc);
  finally
    TmpDoc.Free;
  end;
  Assert.IsTrue(TmpText.Contains('"A1"'), 'the paper size by name: ' + TmpText);
  Assert.IsTrue(TmpText.Contains('landscape'), 'the orientation by name');
  Assert.IsTrue(TmpText.Contains('scale'), 'the fit by name');
  Assert.IsTrue(TmpText.Contains(CADPageSetupKind),
    'and the document says what kind of document it is');
end;

procedure TCADPageSetupPersistenceTests.ADrawingDocumentIsNotAPageSetup;
var
  TmpSetup: TCADPageSetup;
  TmpDoc: TJSONObject;
begin
  { Opening a drawing as a page setup should say so rather than produce
    a setup made of defaults. }
  TmpSetup := TCADPageSetup.Default;
  TmpDoc := TJSONObject.Create;
  try
    JSetStr(TmpDoc, 'format', CADSysJSONFormat);
    JSetStr(TmpDoc, 'version', CADSysJSONVersion);
    JSetStr(TmpDoc, 'kind', 'drawing');
    Assert.WillRaise(
      procedure
      var
        TmpLocal: TCADPageSetup;
      begin
        TmpLocal := TmpSetup;
        TmpLocal.LoadFromJSON(TmpDoc);
      end, ECADPageError, 'a drawing is refused as a page setup');
  finally
    TmpDoc.Free;
  end;
end;

procedure TCADPageSetupPersistenceTests.AnUnknownPaperNameKeepsWhatWasThere;
var
  TmpSetup: TCADPageSetup;
  TmpDoc: TJSONObject;
begin
  { A paper size this build has never heard of - written by a later
    version, or by hand - should not stop the file opening. Everything
    else in it is still worth having. }
  TmpSetup := TCADPageSetup.Default;
  TmpSetup.Paper := pkA3;
  TmpDoc := TJSONObject.Create;
  try
    JSetStr(TmpDoc, 'format', CADSysJSONFormat);
    JSetStr(TmpDoc, 'version', CADSysJSONVersion);
    JSetStr(TmpDoc, 'kind', CADPageSetupKind);
    JSetStr(TmpDoc, 'paper', 'A2andAHalf');
    JSetReal(TmpDoc, 'unitsPerMM', 4);
    TmpSetup.LoadFromJSON(TmpDoc);
  finally
    TmpDoc.Free;
  end;
  Assert.IsTrue(TmpSetup.Paper = pkA3,
    'the paper it already had, rather than whichever one is ordinal zero');
  Assert.AreEqual(4.0, TmpSetup.UnitsPerMM, 0.0001,
    'and the rest of the document was still read');
end;

procedure TCADPageSetupPersistenceTests.
  TheDrawingPathIsRelativeInTheFileAndAbsoluteInMemory;
var
  TmpSetup, TmpBack: TCADPageSetup;
  TmpSetupFile, TmpDrawing, TmpText: String;
begin
  { Relative to THIS file, not to the view's own. A setup saved beside
    its drawing and moved with it still finds it. }
  TmpSetupFile := TempFile('plan' + CADPageSetupExtension);
  TmpDrawing := TempFile('house.json');
  TmpSetup := TCADPageSetup.Default;
  TmpSetup.View.DrawingFile := TmpDrawing;
  TmpSetup.SaveToFile(TmpSetupFile);

  Assert.AreEqual(TmpDrawing, TmpSetup.View.DrawingFile,
    'saving left the setup in hand alone');

  TmpText := TFile.ReadAllText(TmpSetupFile);
  Assert.IsTrue(TmpText.Contains('house.json'), 'the drawing is named');
  Assert.IsFalse(TmpText.Contains(ExcludeTrailingPathDelimiter(fDir)),
    'but not by a path that only means something on this machine: '
    + TmpText);

  TmpBack := TCADPageSetup.Default;
  TmpBack.LoadFromFile(TmpSetupFile);
  Assert.AreEqual(TmpDrawing, TmpBack.View.DrawingFile,
    'and it comes back absolute');
end;

procedure TCADPageSetupPersistenceTests.AFieldTheDocumentDoesNotMentionIsLeftAlone;
var
  TmpSetup: TCADPageSetup;
  TmpDoc: TJSONObject;
begin
  { An older file loading into a newer setup keeps the fields it never
    heard of, rather than silently zeroing them. }
  TmpSetup := Populated;
  TmpDoc := TJSONObject.Create;
  try
    JSetStr(TmpDoc, 'format', CADSysJSONFormat);
    JSetStr(TmpDoc, 'version', CADSysJSONVersion);
    JSetStr(TmpDoc, 'kind', CADPageSetupKind);
    JSetStr(TmpDoc, 'paper', 'A4');
    TmpSetup.LoadFromJSON(TmpDoc);
  finally
    TmpDoc.Free;
  end;
  Assert.IsTrue(TmpSetup.Paper = pkA4, 'what the document did say');
  Assert.AreEqual(12.5, TmpSetup.UnitsPerMM, 0.0001,
    'and what it did not is untouched');
  Assert.IsTrue(TmpSetup.Tiled, 'including the flags');
end;

initialization

TDUnitX.RegisterTestFixture(TCADPageModelTests);
TDUnitX.RegisterTestFixture(TPhysicalSizeTests);
TDUnitX.RegisterTestFixture(TCADPageSetupPersistenceTests);

end.
