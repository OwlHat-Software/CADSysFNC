{ : DUnitX tests for sheets - paper space (unit VCL.FNCCADSys4).

  Scope: TCADSheet and TCADSheetViewport as a model - the paper they
  sit on, the arithmetic that turns a viewport rectangle into a window
  of the drawing, and the round trip through the drawing's own JSON.

  CADDrawSheet is here too, against the recording canvas from
  CADSys4.Tests.Graphics - the only thing in this suite that can watch
  drawing happen. What it can watch is which calls were made in which
  order, not what the picture looks like; the demos are for that.
}
unit CADSys4.Tests.Sheets;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.JSON,
  DUnitX.TestFramework,
  VCL.FNCCS4BaseTypes,
  VCL.FNCCS4JSON,
  VCL.FNCCS4Paper,
  VCL.FNCCS4Views,
  VCL.FNCCADSys4,
  VCL.FNCCS4Shapes,
  VCL.FNCCS4Tasks,
  VCL.FNCCS4Graphics,
  VCL.FNCCS4Print,
  VCL.FNCCadSysRegister,
  CADSys4.Tests.Graphics;

type
  [TestFixture]
  TCADSheetModelTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ANewSheetIsA3Landscape;
    [Test]
    procedure TheMarginsComeOffTheSheetTheRightWayUp;
    [Test]
    procedure ACustomSheetTakesItsOwnSize;
    [Test]
    procedure AFittedViewportTakesTheLargerOfTheTwoRatios;
    [Test]
    procedure AFittedViewportCentresWhatItFrames;
    [Test]
    procedure AScaledViewportIgnoresTheWindowSize;
    [Test]
    procedure AViewportThatFramesNothingUsesTheDrawing;
    [Test]
    procedure AViewportWithNoAreaIsRefused;
    [Test]
    procedure AnEmptyDrawingIsRefusedRatherThanGuessed;
  end;

  [TestFixture]
  TCADSheetPersistenceTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    function Reload: TFNCCADCmp2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ADrawingWithoutSheetsWritesNoSheetsMember;
    [Test]
    procedure APaperSetupSurvivesTheRoundTrip;
    [Test]
    procedure AViewportKeepsItsRectangleScaleAndView;
    [Test]
    procedure AnnotationTravelsWithTheSheet;
    [Test]
    procedure LoadingADrawingReplacesTheSheetsItHad;
    [Test]
    procedure PaperIsWrittenAsANameNotANumber;
    [Test]
    procedure AssignCopiesEverySheetField;
  end;

  [TestFixture]
  TCADSheetEditingTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    { What the drawing reported, in the order it reported it. }
    FLog: TStringList;
    procedure SheetObjectChanged(Sender: TObject; const ASheet: TCADSheet;
      const AObj: TGraphicObject; const AChange: TCADSheetChange);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure AddingToASheetTellsTheDrawing;
    [Test]
    procedure TheEventNamesTheSheetItHappenedOn;
    [Test]
    procedure AddingToTheModelDoesNotFireTheSheetEvent;
    [Test]
    procedure ASheetKeepsItsOwnIdCounter;
    [Test]
    procedure AnObjectOnASheetStillBelongsToTheDrawing;
    [Test]
    procedure DeletingFromASheetTellsTheDrawing;
    [Test]
    procedure SayingAnObjectChangedTellsTheDrawing;
    [Test]
    procedure ClearingASheetReportsOnceWithNoObject;
    [Test]
    procedure DeletingSomethingThatIsNotThereRaises;
  end;

  { : TCADSpace2D - the pair that says which space an operation works
    in - and the two things that depend on it being right: where a new
    object lands, and which object an identifier means. }
  [TestFixture]
  TCADSpaceTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ModelSpaceIsTheDrawingsList;
    [Test]
    procedure PaperSpaceIsTheSheetsList;
    [Test]
    procedure AddingToPaperSpaceLeavesTheModelAlone;
    [Test]
    procedure TheSpaceAssignsTheIdentifier;
    [Test]
    procedure AGivenIdentifierIsKeptAndMovesTheCounterPastIt;
    [Test]
    procedure TheSameIdentifierMeansTwoDifferentObjects;
    [Test]
    procedure ASheetReloadsWithTheIdentifiersItWasSavedWith;
    [Test]
    procedure DeletingThroughASpaceTakesItFromThatSpace;
    [Test]
    procedure RemovingHandsTheObjectToTheCaller;
    [Test]
    procedure AnObjectMovesBetweenSpacesByRemoveAndAdd;
    [Test]
    procedure MovingChangesTheOrderTheSpaceIsDrawnIn;
  end;

  { : The explode family, which until now put its pieces in the drawing
    whatever space the original was in. }
  [TestFixture]
  TCADExplodeTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    { A three-sided polygon, not yet in any space. }
    function NewTriangle: TPolygon2D;
    { The first object in AList that is not ASource - the piece, when
      the only other thing in the space is the object that was
      exploded. Not "the first TPolyline2D": TPolygon2D descends from
      TPolyline2D, so asking by class finds the source itself and the
      test passes whether anything was added or not. }
    function OtherThan(const AList: TGraphicObjList;
      const ASource: TGraphicObject): TGraphicObject;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ExplodingOnASheetLeavesThePiecesOnThePaper;
    [Test]
    procedure ExplodingInTheModelStillLandsInTheModel;
    [Test]
    procedure APieceKeepsTheSourcesLayerInEitherSpace;
    [Test]
    procedure ThePiecesGetIdentifiersFromTheSpaceTheyLandIn;
  end;

  { : A stand-in for an application's own registered classes. The
    legend box VisualPlanner puts on a sheet is exactly this shape: a
    TFrame2D descendant with a field of its own, registered by the
    application rather than by the library.

    The two JSON hooks are the whole contract a custom class has to
    meet - the base writes the type name, the identifier and the
    geometry, and the descendant adds its own. }
  TTestLegendBox = class(TFrame2D)
  private
    fCaption: String;
  public
    constructor CreateFromJSON(const AJSON: TJSONObject); override;
    procedure SaveToJSON(const AJSON: TJSONObject); override;
    property Caption: String read fCaption write fCaption;
  end;

  { : Sheet persistence through the class registry: an application's own
    classes have to survive a sheet round trip exactly as the library's
    own do, because a title block is made of them. }
  [TestFixture]
  TCADSheetCustomClassTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    function NewBox(const ACaption: String): TTestLegendBox;
    { The drawing reloaded through its own JSON text. Caller frees. }
    function Reload: TFNCCADCmp2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ACustomClassOnASheetRoundTrips;
    [Test]
    procedure TheSheetGoesThroughTheSameRegistryAsTheModel;
    [Test]
    procedure AnUnknownClassIsSkippedWithAWarning;
  end;

  { : The viewport stand-in: one TObject2D on the sheet representing a
    rectangle that is not an object, so that the ordinary picking,
    moving and edit-point machinery can work on it. }
  [TestFixture]
  TCADSheetViewportProxyTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    FViewport: TCADSheetViewport;
    FLog: TStringList;
    procedure SheetObjectChanged(Sender: TObject; const ASheet: TCADSheet;
      const AObj: TGraphicObject; const AChange: TCADSheetChange);
    function Device: TCADPageDevice;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ShowingTheHandlesAddsOnePerViewport;
    [Test]
    procedure TheHandleIsTheViewportsRectangle;
    [Test]
    procedure DraggingTheHandleMovesTheViewport;
    [Test]
    procedure MovingACornerResizesTheViewport;
    [Test]
    procedure RefreshPullsTheRectangleBackFromTheViewport;
    [Test]
    procedure AHandleIsNotSavedWithTheSheet;
    [Test]
    procedure PuttingTheHandlesOnIsNotAChangeToTheDrawing;
    [Test]
    procedure DeletingAViewportTakesItsHandleWithIt;
    [Test]
    procedure AHandleIsNotDrawnOnPaper;
    [Test]
    procedure TheViewportUnderAPointInMillimetres;
    [Test]
    procedure AHandleIsPickableOnItsEdgesAndItsCorners;
  end;

  { : The viewport's own numbers: where it looks, how far in, and what a
    point on the paper means in the model. }
  [TestFixture]
  TCADSheetViewportViewTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    FViewport: TCADSheetViewport;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ZoomingInHalvesTheUnitsPerMillimetre;
    [Test]
    procedure ZoomingAFittedViewportStartsFromTheScaleItWasFittedTo;
    [Test]
    procedure ZoomingKeepsWhatWasInTheMiddleInTheMiddle;
    [Test]
    procedure PanningMovesTheCentreAndNothingElse;
    [Test]
    procedure APointOnThePaperIsAPointInTheModel;
    [Test]
    procedure ADegenerateViewportAnswersWithThePointItWasGiven;
  end;

  { : Named views: parts of the drawing kept in the drawing, with an
    identity of their own for sheet viewports to link to. }
  [TestFixture]
  TCADNamedViewTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    function Framing(const AL, AB, AR, AT: TRealType): TCADViewSpec;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure EachViewHasAnIdentifierOfItsOwn;
    [Test]
    procedure RenamingAViewKeepsItsIdentifier;
    [Test]
    procedure AViewIsFoundByIdentifierAndByName;
    [Test]
    procedure ADrawingWithoutViewsWritesNoViewsMember;
    [Test]
    procedure ViewsComeBackWithTheirIdentifiers;
    [Test]
    procedure LoadingTheSameViewsTwiceKeepsOneOfEach;
  end;

  { : A sheet viewport linked to a named view: shared framing, its own
    scale. }
  [TestFixture]
  TCADViewLinkTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    FDetail: TCADNamedView;
    FFirst, FSecond: TCADSheetViewport;
    function Framing(const AL, AB, AR, AT: TRealType): TCADViewSpec;
    function Device: TCADPageDevice;
    function LinesDrawn: Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ALinkedViewportShowsTheNamedView;
    [Test]
    procedure ChangingTheNamedViewMovesEveryViewportLinkedToIt;
    [Test]
    procedure PanningOneLinkedViewportMovesTheOthers;
    [Test]
    procedure TheScaleStaysWithTheViewport;
    [Test]
    procedure AssigningAViewEndsTheLink;
    [Test]
    procedure DeletingTheNamedViewLeavesItsViewportsShowingWhatTheyShowed;
    [Test]
    procedure ALinkSurvivesSaveAndLoad;
    [Test]
    procedure TheFileCarriesAnUpToDateCopyForReadersWithoutLinks;
    [Test]
    procedure ALinkThatFindsNothingFallsBackToTheOwnCopy;
    [Test]
    procedure TheLinkedViewsHiddenLayersAreHiddenOnTheSheet;
  end;

  { : Making a view from what the user selected. }
  [TestFixture]
  TCADViewFromSelectionTests = class(TObject)
  public
    [Test]
    procedure AnAreaBecomesAWindowWithAMargin;
    [Test]
    procedure ObjectsBecomeTheUnionOfTheirBoxes;
    [Test]
    procedure AFlatSelectionStillFramesSomething;
    [Test]
    procedure NothingSelectedIsRefused;
    [Test]
    procedure APointIsRefused;
  end;

  { : CS-01 and CS-02 of docs\masterplanner-changes.md: a viewport's
    content inset, the per-viewport draw hook, and the application's
    own data on a viewport and a sheet. }
  [TestFixture]
  TCADViewportInsetTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    FViewport: TCADSheetViewport;
    FCalls: TArray<string>;
    FLastInfo: TCADSheetViewportDrawInfo;
    function Device: TCADPageDevice;
    procedure RecordHook(Sender: TObject;
      const AInfo: TCADSheetViewportDrawInfo;
      const APhase: TCADViewportDrawPhase);
    procedure CarelessHook(Sender: TObject;
      const AInfo: TCADSheetViewportDrawInfo;
      const APhase: TCADViewportDrawPhase);
    function DrawSheetLog: TStringList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure WithoutAnInsetTheContentIsTheRectangle;
    [Test]
    procedure TheContentRectangleIsTheRectangleLessTheInset;
    [Test]
    procedure AnInsetLargerThanTheRectangleLeavesNoContent;
    [Test]
    procedure TheFitIsIntoTheContent;
    [Test]
    procedure PointsMapIntoAndOutOfTheContent;
    [Test]
    procedure TheDrawingTransformLandsOnTheContentPixels;
    [Test]
    procedure TheModelIsNotDrawnInTheInset;
    [Test]
    procedure TheHookIsCalledBeforeAndAfterTheModel;
    [Test]
    procedure TheHookIsToldWhereTheViewportIs;
    [Test]
    procedure ACarelessHookCannotSpoilTheSheet;
    [Test]
    procedure InsetAndAppDataRoundTrip;
    [Test]
    procedure NothingNewIsWrittenWhenNothingIsSet;
    [Test]
    procedure AssignCopiesInsetAndAppData;
  end;

  [TestFixture]
  TCADSheetDrawingTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    FViewport: TCADSheetViewport;
    { : A3 landscape at 25.4 dpi - one device pixel to the millimetre,
      so every number in these tests is a millimetre and can be read
      off the sheet with a ruler. }
    function Device: TCADPageDevice;
    { : Draws the sheet to a canvas that has never been drawn on
      before. ALines is how many lines came out of it - a TLine2D
      draws itself with MoveTo and LineTo, so its MoveTo is the count -
      and AText the whole log. }
    procedure DrawSheetNow(out ALines: Integer; out AText: String);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure AViewportRectangleFlipsIntoDeviceRows;
    [Test]
    procedure TheViewportClipSitsInsideTheSheetClip;
    [Test]
    procedure TheModelIsDrawnThroughTheViewportAndTheAnnotationOverIt;
    [Test]
    procedure ABorderlessViewportDrawsNoOutline;
    [Test]
    procedure TheBorderIsDrawnOverTheModel;
    [Test]
    procedure TheCanvasScaleIsPutBack;
    [Test]
    procedure AnObjectAddedToTheModelIsThereOnTheNextDraw;
    [Test]
    procedure AnObjectMovedInTheModelIsDrawnWhereItNowIs;
  end;

  [TestFixture]
  TCADSheetHitTestTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    FViewport: TCADSheetViewport;
    function Device: TCADPageDevice;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure APointOnThePaperIsMillimetres;
    [Test]
    procedure MillimetresAndPixelsAreEachOthersInverse;
    [Test]
    procedure AViewportIsFoundByItsRectangle;
    [Test]
    procedure TheViewportOnTopIsTheOneThatAnswers;
    [Test]
    procedure TheCentreOfAViewportIsTheCentreOfWhatItShows;
    [Test]
    procedure APointSurvivesTheRoundTripThroughTheModel;
    [Test]
    procedure APointOutsideAViewportStillTransforms;

  end;

type
  { : CS-20: one sheet over smaller pages. 25.4 dpi, one pixel to the
    millimetre, so that what the recording canvas logs reads as millimetres
    on the page. }
  [TestFixture]
  TCADSheetTilingTests = class(TObject)
  private
    FCAD: TFNCCADCmp2D;
    FSheet: TCADSheet;
    function Device: TCADPageDevice;
    function DrawTile(const ATiling: TCADSheetTiling;
      const AIndex: Integer): string;
    function TextOf(const ALog: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure AnA1SheetOnA4TakesFiveByThree;
    [Test]
    procedure TheTilesOverlapByTheOverlapAndCoverTheSheet;
    [Test]
    procedure AnA4SheetOnA4IsAnOrdinaryPrint;
    [Test]
    procedure TheSheetLandsInThePrintableArea;
    [Test]
    procedure TheNameSaysWhichTileOfWhichSheet;
    [Test]
    procedure MarksComeOnlyOnTheSidesWithANeighbour;
    [Test]
    procedure MarksAreOnThePageAndNotOnTheSheet;
    [Test]
    procedure MarksCanBeLeftOff;
    [Test]
    procedure APrintersEdgeRaisesTheMargins;
    [Test]
    procedure AnOverlapLargerThanThePageIsRefused;
    [Test]
    procedure AWiderAlphabetOfColumnsGoesOnToAA;
  end;

implementation

{ ==================================================================
  TCADSheetModelTests
  ================================================================== }

procedure TCADSheetModelTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
end;

procedure TCADSheetModelTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADSheetModelTests.ANewSheetIsA3Landscape;
var
  TmpSheet: TCADSheet;
  TmpW, TmpH: TRealType;
begin
  TmpSheet := FCAD.Sheets.Add('Layout 1');
  Assert.AreEqual(1, FCAD.Sheets.Count, 'the drawing has one sheet');
  Assert.AreEqual(0, FCAD.Sheets.IndexOfName('layout 1'),
    'found by name, whatever the case');
  TmpSheet.SizeMM(TmpW, TmpH);
  { The table is portrait and the orientation swaps it - one routine
    does that for a sheet and for a page setup both. }
  Assert.AreEqual(420.0, TmpW, 1E-6, 'A3 landscape is 420 wide');
  Assert.AreEqual(297.0, TmpH, 1E-6, 'and 297 tall');
end;

procedure TCADSheetModelTests.TheMarginsComeOffTheSheetTheRightWayUp;
var
  TmpSheet: TCADSheet;
  TmpRect: TRect2D;
begin
  TmpSheet := FCAD.Sheets.Add;
  TmpSheet.Margins := TCADPageMargins.Sides(5, 6, 7, 8);
  Assert.AreEqual(0.0, TmpSheet.PaperRect2D.Left, 1E-6,
    'the paper starts at its own origin');
  TmpRect := TmpSheet.PrintableRect2D;
  { Y is upwards on a sheet, as it is in the model, so the TOP margin
    comes off the top of the paper - which is the high Y, not the low
    one. Getting this backwards is invisible with uniform margins,
    which is why these four differ. }
  Assert.AreEqual(5.0, TmpRect.Left, 1E-6, 'left margin');
  Assert.AreEqual(8.0, TmpRect.Bottom, 1E-6, 'bottom margin');
  Assert.AreEqual(413.0, TmpRect.Right, 1E-6, '420 less the right margin');
  Assert.AreEqual(291.0, TmpRect.Top, 1E-6, '297 less the top margin');
end;

procedure TCADSheetModelTests.ACustomSheetTakesItsOwnSize;
var
  TmpSheet: TCADSheet;
  TmpW, TmpH: TRealType;
begin
  TmpSheet := FCAD.Sheets.Add;
  TmpSheet.Paper := pkCustom;
  TmpSheet.CustomWidthMM := 500;
  TmpSheet.CustomHeightMM := 300;
  TmpSheet.Orientation := pgoPortrait;
  TmpSheet.SizeMM(TmpW, TmpH);
  Assert.AreEqual(500.0, TmpW, 1E-6, 'the custom width, unswapped');
  TmpSheet.Orientation := pgoLandscape;
  TmpSheet.SizeMM(TmpW, TmpH);
  Assert.AreEqual(300.0, TmpW, 1E-6,
    'and landscape swaps a custom size like any other');
  Assert.AreEqual(500.0, TmpH, 1E-6, 'the other way round');
end;

procedure TCADSheetModelTests.AFittedViewportTakesTheLargerOfTheTwoRatios;
var
  TmpVP: TCADSheetViewport;
  TmpView: TCADViewSpec;
begin
  TmpVP := FCAD.Sheets.Add.AddViewport;
  TmpVP.RectMM := Rect2D(0, 0, 100, 50);
  TmpView := TmpVP.View;
  { 200 units across 100 mm is 2; 50 units down 50 mm is 1. All of it
    has to fit, so the answer is 2 - the smaller would run the drawing
    off the sides of the viewport. }
  TmpView.Window := Rect2D(0, 0, 200, 50);
  TmpVP.View := TmpView;
  Assert.AreEqual(2.0, TmpVP.EffectiveUnitsPerMM(FCAD), 1E-9,
    'the ratio that makes everything fit');
end;

procedure TCADSheetModelTests.AFittedViewportCentresWhatItFrames;
var
  TmpVP: TCADSheetViewport;
  TmpView: TCADViewSpec;
  TmpWin: TRect2D;
begin
  TmpVP := FCAD.Sheets.Add.AddViewport;
  TmpVP.RectMM := Rect2D(0, 0, 100, 50);
  TmpView := TmpVP.View;
  TmpView.Window := Rect2D(0, 0, 200, 50);
  TmpVP.View := TmpView;
  TmpWin := TmpVP.ModelWindow(FCAD);
  { At 2 units to the millimetre the viewport holds 200 x 100 units.
    The window it was given is 200 x 50, centred on (100, 25), so the
    50 spare units are split evenly above and below rather than all
    falling on one side. }
  Assert.AreEqual(200.0, TmpWin.Right - TmpWin.Left, 1E-9,
    'as wide as the viewport can hold');
  Assert.AreEqual(100.0, TmpWin.Top - TmpWin.Bottom, 1E-9, 'and as tall');
  Assert.AreEqual(100.0, (TmpWin.Left + TmpWin.Right) / 2, 1E-9,
    'centred on the window it was given');
  Assert.AreEqual(25.0, (TmpWin.Bottom + TmpWin.Top) / 2, 1E-9,
    'in both directions');
  { And the shape of the window is the shape of the rectangle, which is
    what lets the transform be a plain stretch. }
  Assert.AreEqual((TmpWin.Right - TmpWin.Left) / (TmpWin.Top - TmpWin.Bottom),
    TmpVP.WidthMM / TmpVP.HeightMM, 1E-9, 'same proportions as the paper');
end;

procedure TCADSheetModelTests.AScaledViewportIgnoresTheWindowSize;
var
  TmpVP: TCADSheetViewport;
  TmpView: TCADViewSpec;
  TmpWin: TRect2D;
begin
  TmpVP := FCAD.Sheets.Add.AddViewport;
  TmpVP.RectMM := Rect2D(0, 0, 100, 50);
  TmpVP.UnitsPerMM := 10;
  TmpView := TmpVP.View;
  TmpView.Window := Rect2D(0, 0, 200, 50);
  TmpVP.View := TmpView;
  TmpWin := TmpVP.ModelWindow(FCAD);
  { 1:10 of a millimetre-drawn plan. The window it was given decides
    where it looks, not how big the picture is. }
  Assert.AreEqual(1000.0, TmpWin.Right - TmpWin.Left, 1E-9,
    '100 mm at ten units each');
  Assert.AreEqual(500.0, TmpWin.Top - TmpWin.Bottom, 1E-9, 'and 50 mm');
  Assert.AreEqual(100.0, (TmpWin.Left + TmpWin.Right) / 2, 1E-9,
    'still looking where it was pointed');
end;

procedure TCADSheetModelTests.AViewportThatFramesNothingUsesTheDrawing;
var
  TmpVP: TCADSheetViewport;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  TmpVP := FCAD.Sheets.Add.AddViewport;
  TmpVP.RectMM := Rect2D(0, 0, 100, 50);
  { A new viewport frames nothing - deliberately, because
    TCADViewSpec.Default's -100..100 is a viewport's opening view and
    has no business on paper. An empty window means "the drawing". }
  Assert.AreEqual(3.0, TmpVP.EffectiveUnitsPerMM(FCAD), 1E-9,
    '300 units across 100 mm');
end;

procedure TCADSheetModelTests.AViewportWithNoAreaIsRefused;
var
  TmpVP: TCADSheetViewport;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  TmpVP := FCAD.Sheets.Add.AddViewport;
  { A rectangle nobody ever positioned. Dividing by it would give
    infinity and draw nothing, silently. }
  Assert.WillRaise(
    procedure
    begin
      TmpVP.ModelWindow(FCAD);
    end, ECADPageError, 'a viewport with no area cannot show anything');
end;

procedure TCADSheetModelTests.AnEmptyDrawingIsRefusedRatherThanGuessed;
var
  TmpVP: TCADSheetViewport;
begin
  TmpVP := FCAD.Sheets.Add.AddViewport;
  TmpVP.RectMM := Rect2D(0, 0, 100, 50);
  Assert.WillRaise(
    procedure
    begin
      TmpVP.ModelWindow(FCAD);
    end, ECADPageError, 'nothing to frame, and no made-up window either');
end;

{ ==================================================================
  TCADSheetPersistenceTests
  ================================================================== }

procedure TCADSheetPersistenceTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
end;

procedure TCADSheetPersistenceTests.TearDown;
begin
  FCAD.Free;
end;

function TCADSheetPersistenceTests.Reload: TFNCCADCmp2D;
begin
  { Through the text, not through the object tree: a round trip that
    never becomes characters proves less than it looks. }
  Result := TFNCCADCmp2D.Create(nil);
  try
    Result.LoadFromJSONString(FCAD.SaveToJSONString);
  except
    Result.Free;
    Raise;
  end;
end;

procedure TCADSheetPersistenceTests.ADrawingWithoutSheetsWritesNoSheetsMember;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(10, 10)));
  { A drawing with no paper space writes the file it wrote before
    sheets existed. Old readers keep working and old files keep
    comparing equal. }
  Assert.IsFalse(FCAD.SaveToJSONString.Contains('"sheets"'),
    'no empty array for a drawing that has none');
end;

procedure TCADSheetPersistenceTests.APaperSetupSurvivesTheRoundTrip;
var
  TmpSheet: TCADSheet;
  TmpBack: TFNCCADCmp2D;
begin
  TmpSheet := FCAD.Sheets.Add('Plan');
  TmpSheet.Paper := pkA1;
  TmpSheet.Orientation := pgoPortrait;
  TmpSheet.Margins := TCADPageMargins.Sides(5, 6, 7, 8);
  TmpBack := Reload;
  try
    Assert.AreEqual(1, TmpBack.Sheets.Count, 'one sheet came back');
    Assert.AreEqual('Plan', TmpBack.Sheets[0].Name, 'by name');
    Assert.AreEqual(Ord(pkA1), Ord(TmpBack.Sheets[0].Paper), 'paper');
    Assert.AreEqual(Ord(pgoPortrait), Ord(TmpBack.Sheets[0].Orientation),
      'orientation');
    Assert.AreEqual(6.0, TmpBack.Sheets[0].Margins.Top, 1E-9,
      'and each margin on its own side');
    Assert.AreEqual(8.0, TmpBack.Sheets[0].Margins.Bottom, 1E-9, 'bottom');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADSheetPersistenceTests.AViewportKeepsItsRectangleScaleAndView;
var
  TmpVP: TCADSheetViewport;
  TmpView: TCADViewSpec;
  TmpBack: TFNCCADCmp2D;
begin
  TmpVP := FCAD.Sheets.Add('Plan').AddViewport;
  TmpVP.Name := 'Detail';
  TmpVP.RectMM := Rect2D(20, 30, 220, 130);
  TmpVP.UnitsPerMM := 50;
  TmpVP.ShowBorder := False;
  TmpView := TmpVP.View;
  TmpView.Window := Rect2D(-10, -20, 90, 80);
  TmpView.UseLayerOverride := True;
  TmpView.HiddenLayers := [3, 7];
  TmpVP.View := TmpView;

  TmpBack := Reload;
  try
    Assert.AreEqual(1, TmpBack.Sheets[0].ViewportCount, 'one viewport');
    TmpVP := TmpBack.Sheets[0].Viewports[0];
    Assert.AreEqual('Detail', TmpVP.Name, 'name');
    Assert.AreEqual(20.0, TmpVP.RectMM.Left, 1E-9, 'where it sits');
    Assert.AreEqual(130.0, TmpVP.RectMM.Top, 1E-9, 'and how big it is');
    Assert.AreEqual(50.0, TmpVP.UnitsPerMM, 1E-9, 'its scale');
    Assert.IsFalse(TmpVP.ShowBorder, 'and its border');
    { The view travels whole, as a page setup's does. }
    Assert.AreEqual(-10.0, TmpVP.View.Window.Left, 1E-9, 'the view window');
    Assert.IsTrue(TmpVP.View.UseLayerOverride, 'the layer override');
    Assert.IsTrue(7 in TmpVP.View.HiddenLayers, 'and which layers it hides');
    Assert.IsFalse(4 in TmpVP.View.HiddenLayers, 'and which it does not');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADSheetPersistenceTests.AnnotationTravelsWithTheSheet;
var
  TmpSheet: TCADSheet;
  TmpBack: TFNCCADCmp2D;
  TmpIter: TGraphicObjIterator;
  TmpObj: TGraphicObject;
begin
  TmpSheet := FCAD.Sheets.Add('Plan');
  { A title block is ordinary shapes in the sheet's millimetres - which
    is the whole reason a sheet holds TObject2D rather than a format of
    its own. }
  TmpSheet.AddObject(TLine2D.Create(-1, Point2D(10, 10), Point2D(410, 10)));
  TmpSheet.AddObject(TLine2D.Create(-1, Point2D(410, 10), Point2D(410, 287)));
  Assert.AreEqual(2, TmpSheet.ObjectsCount, 'two lines on the sheet');
  { And they are the sheet's, not the drawing's. }
  Assert.AreEqual(0, FCAD.ObjectsCount, 'the model itself is still empty');

  TmpBack := Reload;
  try
    Assert.AreEqual(2, TmpBack.Sheets[0].ObjectsCount, 'both came back');
    TmpIter := TmpBack.Sheets[0].ObjectsIterator;
    try
      TmpObj := TmpIter.First;
      Assert.IsTrue(TmpObj is TLine2D, 'as the class they were');
      Assert.AreEqual(10.0, TLine2D(TmpObj).Points[0].X, 1E-9,
        'in the millimetres they were drawn in');
    finally
      TmpIter.Free;
    end;
  finally
    TmpBack.Free;
  end;
end;

procedure TCADSheetPersistenceTests.LoadingADrawingReplacesTheSheetsItHad;
var
  TmpText: String;
begin
  FCAD.Sheets.Add('First');
  TmpText := FCAD.SaveToJSONString;
  FCAD.Sheets.Add('Second');
  Assert.AreEqual(2, FCAD.Sheets.Count, 'two before');
  { DeleteAllObjects does not touch paper space - a sheet is not one of
    the drawing's objects - so LoadFromJSON has to clear it itself.
    Without that, opening a drawing twice doubles its sheets. }
  FCAD.LoadFromJSONString(TmpText);
  Assert.AreEqual(1, FCAD.Sheets.Count, 'and one after');
  Assert.AreEqual('First', FCAD.Sheets[0].Name, 'the one in the file');
end;

procedure TCADSheetPersistenceTests.PaperIsWrittenAsANameNotANumber;
var
  TmpSheet: TCADSheet;
  TmpText: String;
begin
  TmpSheet := FCAD.Sheets.Add('Plan');
  TmpSheet.Paper := pkA1;
  TmpText := FCAD.SaveToJSONString;
  { An ordinal is one insertion away from meaning something else: put
    an A7 between A5 and A4 and every saved sheet changes paper. }
  Assert.IsTrue(TmpText.Contains('"A1"'), 'the paper is named: ' + TmpText);
end;

procedure TCADSheetPersistenceTests.AssignCopiesEverySheetField;
var
  TmpSource, TmpCopy: TCADSheet;
begin
  TmpSource := FCAD.Sheets.Add('Plan');
  TmpSource.Paper := pkA2;
  TmpSource.Margins := TCADPageMargins.Uniform(15);
  TmpSource.AddObject(TLine2D.Create(-1, Point2D(1, 2), Point2D(3, 4)));
  TmpSource.AddViewport.RectMM := Rect2D(0, 0, 100, 50);

  TmpCopy := FCAD.Sheets.Add('Copy');
  TmpCopy.Assign(TmpSource);
  { Assign goes through the file format on purpose - it is the one
    place that already knows every field and every class of object
    that can be on a sheet. }
  Assert.AreEqual(Ord(pkA2), Ord(TmpCopy.Paper), 'the paper');
  Assert.AreEqual(15.0, TmpCopy.Margins.Left, 1E-9, 'the margins');
  Assert.AreEqual(1, TmpCopy.ViewportCount, 'the viewports');
  Assert.AreEqual(1, TmpCopy.ObjectsCount, 'and the annotation');
  Assert.AreEqual('Plan', TmpCopy.Name,
    'including the name - a copy of a sheet is a copy');
end;

{ ==================================================================
  TCADSheetEditingTests
  ================================================================== }

procedure TCADSheetEditingTests.SheetObjectChanged(Sender: TObject;
  const ASheet: TCADSheet; const AObj: TGraphicObject;
  const AChange: TCADSheetChange);
var
  TmpWhat: String;
begin
  case AChange of
    scoAdded:
      TmpWhat := 'added';
    scoRemoved:
      TmpWhat := 'removed';
  else
    TmpWhat := 'changed';
  end;
  { AObj is documented as possibly nil - a change that is not about one
    object - so the log says so rather than dereferencing it. }
  if AObj <> nil then
    FLog.Add(Format('%s %s %s', [TmpWhat, ASheet.Name, AObj.ClassName]))
  else
    FLog.Add(Format('%s %s', [TmpWhat, ASheet.Name]));
end;

procedure TCADSheetEditingTests.Setup;
begin
  { The log first: the handler is live from the next line on. }
  FLog := TStringList.Create;
  FCAD := TFNCCADCmp2D.Create(nil);
  FCAD.OnSheetObjectChange := SheetObjectChanged;
  FSheet := FCAD.Sheets.Add('Plan');
end;

procedure TCADSheetEditingTests.TearDown;
begin
  FCAD.Free;
  FLog.Free;
end;

procedure TCADSheetEditingTests.AddingToASheetTellsTheDrawing;
begin
  { The notification is fired by TCADSheet.AddObject rather than by the
    viewport's AddObjectToActiveSpace, for two reasons: a sheet edited
    in code says so too, and it can be tested at all. Nothing in this
    suite can instantiate a TFNCCADViewport2D - an FNC control wants a
    window and a canvas, which a console test runner has no business
    creating - so a notification raised in the control would have been
    untestable here and verified by hand or not at all. }
  FSheet.AddObject(TLine2D.Create(-1, Point2D(0, 0), Point2D(10, 0)));
  Assert.AreEqual(1, FLog.Count, 'one notification for one object');
  Assert.AreEqual('added Plan TLine2D', FLog[0],
    'and it says what happened, where, and to what');
end;

procedure TCADSheetEditingTests.TheEventNamesTheSheetItHappenedOn;
var
  TmpSecond: TCADSheet;
begin
  { Which space it happened in is the thing OnAddObject cannot tell an
    application, and with two sheets it is not enough to know that it
    was 'a sheet'. }
  TmpSecond := FCAD.Sheets.Add('Detail');
  FSheet.AddObject(TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 0)));
  TmpSecond.AddObject(TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 0)));
  Assert.AreEqual('added Plan TLine2D', FLog[0], 'the first sheet');
  Assert.AreEqual('added Detail TLine2D', FLog[1], 'and the second');
end;

procedure TCADSheetEditingTests.AddingToTheModelDoesNotFireTheSheetEvent;
begin
  { Deliberately separate from OnAddObject: a handler written before
    sheets existed assumes its object is in the display list, and would
    be wrong about one on a sheet. The two channels do not cross. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(10, 0)));
  Assert.AreEqual(0, FLog.Count,
    'the model has its own event and does not borrow this one');
end;

procedure TCADSheetEditingTests.ASheetKeepsItsOwnIdCounter;
var
  TmpA, TmpB: TObject2D;
begin
  { A sheet numbers its objects from zero, independently of the model -
    which is why an object cannot simply be moved from one space to the
    other without being re-added. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 0)));
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 0)));
  TmpA := FSheet.AddObject(TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 0)));
  TmpB := FSheet.AddObject(TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 0)));
  Assert.AreEqual(0, TmpA.ID, 'the sheet starts at zero whatever the model did');
  Assert.AreEqual(1, TmpB.ID, 'and counts on from there');
end;

procedure TCADSheetEditingTests.AnObjectOnASheetStillBelongsToTheDrawing;
var
  TmpObj: TObject2D;
begin
  { OwnerCAD stays the drawing: a shape on a sheet is part of the
    document, and anything that walks back to its owner - a layer
    lookup, UpdateExtension - has to find the drawing there. }
  TmpObj := FSheet.AddObject(TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 0)));
  Assert.AreSame(FCAD, TmpObj.OwnerCAD,
    'the sheet holds it, the drawing owns it');
end;

procedure TCADSheetDrawingTests.AnObjectAddedToTheModelIsThereOnTheNextDraw;
var
  TmpBefore, TmpAfter: Integer;
  TmpText: String;
begin
  DrawSheetNow(TmpBefore, TmpText);
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(10, 10), Point2D(290, 140)));
  DrawSheetNow(TmpAfter, TmpText);
  { A viewport is a window on the model, not a picture of it taken
    once: every draw walks the drawing's list again. Nothing here
    invalidates a cache, because there is no cache to invalidate - and
    this is the test that says so. }
  Assert.AreEqual(TmpBefore + 1, TmpAfter,
    'the new line came through the viewport: ' + TmpText);
end;

procedure TCADSheetDrawingTests.AnObjectMovedInTheModelIsDrawnWhereItNowIs;
var
  TmpLines: Integer;
  TmpFirst, TmpSecond: String;
  TmpObj: TObject2D;
  TmpSpec: TCADViewSpec;
begin
  { A fixed window and a fixed scale. Left fitting, the viewport would
    re-frame the one object it can see and draw the moved line in
    exactly the same place - a true answer to the wrong question. }
  TmpSpec := TCADViewSpec.Default;
  TmpSpec.Window := Rect2D(0, 0, 300, 150);
  FViewport.View := TmpSpec;
  FViewport.UnitsPerMM := 3;
  DrawSheetNow(TmpLines, TmpFirst);
  TmpObj := TObject2D(FCAD.GetObject(0));
  Assert.IsNotNull(TmpObj, 'the model line is there to move');
  TmpObj.Transform(Translate2D(50, 25));
  DrawSheetNow(TmpLines, TmpSecond);
  { Same number of lines, different coordinates: the viewport drew the
    object where it is now and not where it was when the sheet was
    first painted. }
  Assert.AreEqual(1, TmpLines, 'still one line');
  Assert.AreNotEqual(TmpFirst, TmpSecond,
    'and it moved on the paper: ' + TmpSecond);
end;

{ ==================================================================
  TCADSheetViewportProxyTests
  ================================================================== }

function TCADSheetViewportProxyTests.Device: TCADPageDevice;
begin
  { One device pixel to the millimetre, as the drawing tests use. }
  Result := TCADPageDevice.FromDPI(CADMMPerInch, CADMMPerInch);
end;

procedure TCADSheetViewportProxyTests.SheetObjectChanged(Sender: TObject;
  const ASheet: TCADSheet; const AObj: TGraphicObject;
  const AChange: TCADSheetChange);
begin
  if AObj <> nil then
    FLog.Add(AObj.ClassName)
  else
    FLog.Add('(none)');
end;

procedure TCADSheetViewportProxyTests.Setup;
begin
  FLog := TStringList.Create;
  FCAD := TFNCCADCmp2D.Create(nil);
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  FSheet := FCAD.Sheets.Add('Plan');
  FViewport := FSheet.AddViewport;
  FViewport.RectMM := Rect2D(10, 10, 110, 60);
end;

procedure TCADSheetViewportProxyTests.TearDown;
begin
  FCAD.Free;
  FLog.Free;
end;

procedure TCADSheetViewportProxyTests.ShowingTheHandlesAddsOnePerViewport;
begin
  FSheet.AddViewport.RectMM := Rect2D(150, 10, 250, 60);
  Assert.AreEqual(2, CADSheetShowViewportProxies(FSheet), 'one each');
  Assert.AreEqual(2, FSheet.ObjectsCount, 'on the sheet');
  { Asking twice is what an application does on every click of a
    toolbar button, and it must not pile them up. }
  Assert.AreEqual(0, CADSheetShowViewportProxies(FSheet), 'and no more');
  Assert.AreEqual(2, FSheet.ObjectsCount, 'still two');
  Assert.AreEqual(2, CADSheetHideViewportProxies(FSheet), 'both went');
  Assert.AreEqual(0, FSheet.ObjectsCount, 'and the sheet is empty again');
end;

procedure TCADSheetViewportProxyTests.TheHandleIsTheViewportsRectangle;
var
  TmpProxy: TCADSheetViewportProxy2D;
begin
  CADSheetShowViewportProxies(FSheet);
  TmpProxy := CADSheetViewportProxy(FSheet, FViewport);
  Assert.IsNotNull(TmpProxy, 'there is one');
  Assert.AreSame(TObject(FViewport), TmpProxy.StandsFor,
    'and it says what it stands for');
  Assert.AreEqual(10.0, TmpProxy.Box.Left, 1E-9, 'left');
  Assert.AreEqual(10.0, TmpProxy.Box.Bottom, 1E-9, 'bottom');
  Assert.AreEqual(110.0, TmpProxy.Box.Right, 1E-9, 'right');
  Assert.AreEqual(60.0, TmpProxy.Box.Top, 1E-9, 'top');
end;

procedure TCADSheetViewportProxyTests.DraggingTheHandleMovesTheViewport;
var
  TmpProxy: TCADSheetViewportProxy2D;
begin
  CADSheetShowViewportProxies(FSheet);
  TmpProxy := CADSheetViewportProxy(FSheet, FViewport);
  { What TCAD2DMoveObjects does to a selected object, and nothing more:
    the point of the stand-in is that the move task needs no knowledge
    of viewports at all. }
  TmpProxy.Transform(Translate2D(10, 5));
  Assert.AreEqual(20.0, FViewport.RectMM.Left, 1E-9, 'the viewport moved');
  Assert.AreEqual(15.0, FViewport.RectMM.Bottom, 1E-9, 'in both axes');
  Assert.AreEqual(120.0, FViewport.RectMM.Right, 1E-9, 'and kept its width');
  Assert.AreEqual(65.0, FViewport.RectMM.Top, 1E-9, 'and its height');
end;

procedure TCADSheetViewportProxyTests.MovingACornerResizesTheViewport;
var
  TmpProxy: TCADSheetViewportProxy2D;
begin
  CADSheetShowViewportProxies(FSheet);
  TmpProxy := CADSheetViewportProxy(FSheet, FViewport);
  { What TCAD2DEditPrimitive does: it moves a control point. A frame's
    two control points are its corners, which is the whole reason the
    stand-in is a frame. }
  TmpProxy.Points[1] := Point2D(210, 110);
  Assert.AreEqual(210.0, FViewport.RectMM.Right, 1E-9, 'wider');
  Assert.AreEqual(110.0, FViewport.RectMM.Top, 1E-9, 'and taller');
  Assert.AreEqual(10.0, FViewport.RectMM.Left, 1E-9,
    'with the other corner where it was');
end;

procedure TCADSheetViewportProxyTests.RefreshPullsTheRectangleBackFromTheViewport;
var
  TmpProxy: TCADSheetViewportProxy2D;
begin
  CADSheetShowViewportProxies(FSheet);
  TmpProxy := CADSheetViewportProxy(FSheet, FViewport);
  { The other direction: an application that moved the viewport in code
    while the handles were showing. }
  FViewport.RectMM := Rect2D(5, 5, 55, 30);
  CADSheetRefreshViewportProxies(FSheet);
  Assert.AreEqual(5.0, TmpProxy.Box.Left, 1E-9, 'the handle followed');
  Assert.AreEqual(55.0, TmpProxy.Box.Right, 1E-9, 'all of it');
  Assert.AreEqual(30.0, TmpProxy.Box.Top, 1E-9, 'both corners');
end;

procedure TCADSheetViewportProxyTests.AHandleIsNotSavedWithTheSheet;
var
  TmpText: String;
  TmpBack: TFNCCADCmp2D;
begin
  FSheet.AddObject(TLine2D.Create(-1, Point2D(1, 1), Point2D(2, 2)));
  CADSheetShowViewportProxies(FSheet);
  TmpText := FCAD.SaveToJSONString;
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    TmpBack.LoadFromJSONString(TmpText);
    { The title block, and not the handle: the viewport is already in
      the file, and a saved handle would come back as an ordinary
      rectangle drawn over it that nobody asked for. }
    Assert.AreEqual(1, TmpBack.Sheets[0].ObjectsCount, 'the real object only');
    Assert.AreEqual(1, TmpBack.Sheets[0].ViewportCount, 'the viewport is there');
    Assert.IsFalse(TmpText.Contains('TCADSheetViewportProxy2D'),
      'and the class name is nowhere in the file');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADSheetViewportProxyTests.PuttingTheHandlesOnIsNotAChangeToTheDrawing;
begin
  FCAD.OnSheetObjectChange := SheetObjectChanged;
  CADSheetShowViewportProxies(FSheet);
  CADSheetHideViewportProxies(FSheet);
  { An application that marks a file modified when it hears this event
    would mark it on a toolbar click that changed nothing in the
    document. }
  Assert.AreEqual(0, FLog.Count, 'nothing was reported: ' + FLog.Text);
  { And a real object still reports, so the silence above is about
    stand-ins and not about the event being broken. }
  FSheet.AddObject(TLine2D.Create(-1, Point2D(1, 1), Point2D(2, 2)));
  Assert.AreEqual(1, FLog.Count, 'a real object still reports');
end;

procedure TCADSheetViewportProxyTests.DeletingAViewportTakesItsHandleWithIt;
begin
  CADSheetShowViewportProxies(FSheet);
  Assert.AreEqual(1, FSheet.ObjectsCount, 'the handle is there');
  FSheet.DeleteViewport(0);
  { Otherwise the handle outlives the viewport holding a dangling
    reference, and the next drag writes through a freed pointer. }
  Assert.AreEqual(0, FSheet.ObjectsCount, 'and went with it');
end;

procedure TCADSheetViewportProxyTests.AHandleIsNotDrawnOnPaper;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  CADSheetShowViewportProxies(FSheet);
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    { One polyline, the viewport's own border. The handle is a frame
      and would draw as a second polyline over it - on the screen that
      is the point, on a printer and in a PDF it is a line that is not
      part of the drawing. }
    Assert.AreEqual(1, TmpRec.CountOf('Polyline'),
      'the border and not the handle: ' + TmpRec.Log.Text);
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetViewportProxyTests.TheViewportUnderAPointInMillimetres;
var
  TmpSecond: TCADSheetViewport;
begin
  Assert.AreSame(TObject(FViewport), TObject(FSheet.ViewportAt(Point2D(50, 30))),
    'inside');
  Assert.IsNull(FSheet.ViewportAt(Point2D(5, 5)), 'outside is nil');
  { Two overlapping, and the later one is drawn on top, so a click
    belongs to the one the user can see. }
  TmpSecond := FSheet.AddViewport;
  TmpSecond.RectMM := Rect2D(50, 20, 150, 70);
  Assert.AreSame(TObject(TmpSecond), TObject(FSheet.ViewportAt(Point2D(60, 30))),
    'the one on top');
  Assert.AreEqual(0, FSheet.ViewportIndexAt(Point2D(20, 15)),
    'and where they do not overlap, the first');
end;

procedure TCADSheetViewportProxyTests.AHandleIsPickableOnItsEdgesAndItsCorners;
var
  TmpProxy: TCADSheetViewportProxy2D;
  TmpDist: TRealType;
begin
  CADSheetShowViewportProxies(FSheet);
  TmpProxy := CADSheetViewportProxy(FSheet, FViewport);
  { The rectangle is 10,10 to 110,60. An aperture of 3 mm, which is
    about what five pixels comes to on a sheet on the screen. }

  TmpDist := 0;
  Assert.AreEqual(PICK_ONOBJECT,
    TmpProxy.OnMe(Point2D(60, 10.5), 3, TmpDist),
    'the middle of an edge');

  TmpDist := 0;
  Assert.AreEqual(PICK_INBBOX,
    TmpProxy.OnMe(Point2D(60, 35), 3, TmpDist),
    'the middle of the rectangle is in the box and on nothing');

  { Diagonally outside a corner. The library measures a point against a
    line by projecting it onto the segment, so past the end of one it
    counts as on neither of the two that meet there - and a corner is
    exactly where somebody reaches to resize. This is the case the
    demo found by hand: a click at 405,54, 39,34 against a corner at
    405, 40 came back PICK_INBBOX and selected nothing. }
  TmpDist := 0;
  Assert.AreEqual(PICK_ONOBJECT,
    TmpProxy.OnMe(Point2D(110.6, 9.4), 3, TmpDist),
    'and just outside a corner');

  TmpDist := 0;
  Assert.AreEqual(PICK_NOOBJECT,
    TmpProxy.OnMe(Point2D(130, 80), 3, TmpDist),
    'well away from it, nothing');
end;

{ ==================================================================
  TCADSheetViewportViewTests
  ================================================================== }

procedure TCADSheetViewportViewTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FSheet := FCAD.Sheets.Add('Plan');
  FViewport := FSheet.AddViewport;
  { 100 mm by 50 mm of paper. }
  FViewport.RectMM := Rect2D(10, 10, 110, 60);
end;

procedure TCADSheetViewportViewTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADSheetViewportViewTests.ZoomingInHalvesTheUnitsPerMillimetre;
begin
  FViewport.UnitsPerMM := 4;
  FViewport.View := TCADViewSpec.Default;
  FViewport.ZoomBy(FCAD, 2);
  { Zooming in shows less of the drawing on the same paper: fewer
    drawing units to a millimetre. }
  Assert.AreEqual(2.0, FViewport.UnitsPerMM, 1E-9, 'in');
  FViewport.ZoomBy(FCAD, 0.5);
  Assert.AreEqual(4.0, FViewport.UnitsPerMM, 1E-9, 'and out again');
  FViewport.ZoomBy(FCAD, 0);
  Assert.AreEqual(4.0, FViewport.UnitsPerMM, 1E-9,
    'and a factor of nothing does nothing');
end;

procedure TCADSheetViewportViewTests.ZoomingAFittedViewportStartsFromTheScaleItWasFittedTo;
var
  TmpSpec: TCADViewSpec;
  TmpFitted: TRealType;
begin
  { A 300-unit-wide window in a 100 mm viewport is three units to the
    millimetre, fitted. }
  TmpSpec := TCADViewSpec.Default;
  TmpSpec.Window := Rect2D(0, 0, 300, 150);
  FViewport.View := TmpSpec;
  FViewport.UnitsPerMM := 0;
  TmpFitted := FViewport.EffectiveUnitsPerMM(FCAD);
  Assert.AreEqual(3.0, TmpFitted, 1E-9, 'fitted at three');
  FViewport.ZoomBy(FCAD, 2);
  { Not to some other scale entirely: the first zoom of a fitted
    viewport has to move by the factor asked for. }
  Assert.AreEqual(1.5, FViewport.UnitsPerMM, 1E-9, 'and in by two from there');
end;

procedure TCADSheetViewportViewTests.ZoomingKeepsWhatWasInTheMiddleInTheMiddle;
var
  TmpSpec: TCADViewSpec;
  TmpBefore, TmpAfter: TPoint2D;
begin
  TmpSpec := TCADViewSpec.Default;
  TmpSpec.Window := Rect2D(100, 100, 400, 250);
  FViewport.View := TmpSpec;
  FViewport.UnitsPerMM := 0;
  TmpBefore := FViewport.ModelCentre(FCAD);
  FViewport.ZoomBy(FCAD, 4);
  TmpAfter := FViewport.ModelCentre(FCAD);
  Assert.AreEqual(TmpBefore.X, TmpAfter.X, 1E-9, 'the centre held in X');
  Assert.AreEqual(TmpBefore.Y, TmpAfter.Y, 1E-9, 'and in Y');
end;

procedure TCADSheetViewportViewTests.PanningMovesTheCentreAndNothingElse;
var
  TmpSpec: TCADViewSpec;
  TmpCentre: TPoint2D;
begin
  TmpSpec := TCADViewSpec.Default;
  TmpSpec.Window := Rect2D(0, 0, 300, 150);
  FViewport.View := TmpSpec;
  FViewport.UnitsPerMM := 3;
  FViewport.PanModelBy(FCAD, 30, -15);
  TmpCentre := FViewport.ModelCentre(FCAD);
  Assert.AreEqual(180.0, TmpCentre.X, 1E-9, 'the centre moved');
  Assert.AreEqual(60.0, TmpCentre.Y, 1E-9, 'both ways');
  Assert.AreEqual(3.0, FViewport.UnitsPerMM, 1E-9, 'and the scale did not');
end;

procedure TCADSheetViewportViewTests.APointOnThePaperIsAPointInTheModel;
var
  TmpSpec: TCADViewSpec;
  TmpModel, TmpBack: TPoint2D;
begin
  TmpSpec := TCADViewSpec.Default;
  TmpSpec.Window := Rect2D(0, 0, 300, 150);
  FViewport.View := TmpSpec;
  FViewport.UnitsPerMM := 3;
  { The bottom-left corner of the paper rectangle is the bottom-left of
    the window, and the middle is the middle. }
  TmpModel := FViewport.PointMMToModel(FCAD, Point2D(10, 10));
  Assert.AreEqual(0.0, TmpModel.X, 1E-6, 'the corner is the corner');
  Assert.AreEqual(0.0, TmpModel.Y, 1E-6, 'in both axes');
  TmpModel := FViewport.PointMMToModel(FCAD, Point2D(60, 35));
  Assert.AreEqual(150.0, TmpModel.X, 1E-6, 'and the middle the middle');
  Assert.AreEqual(75.0, TmpModel.Y, 1E-6, 'there too');
  { And back again, which is the property that matters to a drag: a
    point picked and put down must not drift. }
  TmpBack := FViewport.ModelToPointMM(FCAD, TmpModel);
  Assert.AreEqual(60.0, TmpBack.X, 1E-6, 'the round trip holds');
  Assert.AreEqual(35.0, TmpBack.Y, 1E-6, 'in both axes');
end;

procedure TCADSheetViewportViewTests.ADegenerateViewportAnswersWithThePointItWasGiven;
begin
  FViewport.RectMM := Rect2D(10, 10, 10, 10);
  { The same answer CADSheetViewportTransform gives by handing back the
    identity: an honest failure rather than a plausible wrong number. }
  Assert.AreEqual(42.0, FViewport.PointMMToModel(FCAD, Point2D(42, 7)).X, 1E-9,
    'no area, no conversion');
  Assert.AreEqual(7.0, FViewport.PointMMToModel(FCAD, Point2D(42, 7)).Y, 1E-9,
    'in both axes');
end;

{ ==================================================================
  TCADNamedViewTests
  ================================================================== }

function TCADNamedViewTests.Framing(const AL, AB, AR, AT: TRealType)
  : TCADViewSpec;
begin
  Result := TCADViewSpec.Default;
  Result.Window := Rect2D(AL, AB, AR, AT);
end;

procedure TCADNamedViewTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
end;

procedure TCADNamedViewTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADNamedViewTests.EachViewHasAnIdentifierOfItsOwn;
var
  TmpA, TmpB: TCADNamedView;
begin
  TmpA := FCAD.Views.Add('Detail A', Framing(0, 0, 10, 10));
  TmpB := FCAD.Views.Add('Detail A', Framing(0, 0, 10, 10));
  { The same name and the same window, and still two views: names are
    for people, and the identifier is what a link holds on to. }
  Assert.IsTrue(TmpA.Id <> '', 'it has one');
  Assert.IsTrue(TmpA.Id <> TmpB.Id, 'and it is its own');
end;

procedure TCADNamedViewTests.RenamingAViewKeepsItsIdentifier;
var
  TmpView: TCADNamedView;
  TmpId: String;
begin
  TmpView := FCAD.Views.Add('Detial A', Framing(0, 0, 10, 10));
  TmpId := TmpView.Id;
  TmpView.Name := 'Detail A';
  { The reason links are by identifier: correcting a typo must not break
    every sheet the detail is on. }
  Assert.AreEqual(TmpId, TmpView.Id, 'the same view');
  Assert.AreEqual('Detail A', TmpView.Spec.Name, 'one name, not two');
end;

procedure TCADNamedViewTests.AViewIsFoundByIdentifierAndByName;
var
  TmpView: TCADNamedView;
begin
  FCAD.Views.Add('Plan', Framing(0, 0, 100, 100));
  TmpView := FCAD.Views.Add('Section B-B', Framing(0, 0, 10, 10));
  Assert.AreSame(TObject(TmpView), TObject(FCAD.Views.FindById(TmpView.Id)),
    'by identifier');
  Assert.AreSame(TObject(TmpView),
    TObject(FCAD.Views.FindByName('section b-b')), 'by name, any case');
  Assert.IsNull(FCAD.Views.FindById('{not-a-view}'), 'nothing is nil');
  Assert.IsNull(FCAD.Views.FindById(''), 'and no identifier is nothing');
end;

procedure TCADNamedViewTests.ADrawingWithoutViewsWritesNoViewsMember;
begin
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(10, 10)));
  { Exactly the file it wrote before named views existed. }
  Assert.IsFalse(FCAD.SaveToJSONString.Contains('"views"'),
    'no empty array for a drawing that has none');
end;

procedure TCADNamedViewTests.ViewsComeBackWithTheirIdentifiers;
var
  TmpView: TCADNamedView;
  TmpBack: TFNCCADCmp2D;
  TmpFound: TCADNamedView;
begin
  TmpView := FCAD.Views.Add('Detail A', Framing(10, 20, 30, 40));
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    TmpBack.LoadFromJSONString(FCAD.SaveToJSONString);
    Assert.AreEqual(1, TmpBack.Views.Count, 'one view');
    TmpFound := TmpBack.Views.FindById(TmpView.Id);
    Assert.IsNotNull(TmpFound, 'found by the identifier it was saved with');
    Assert.AreEqual('Detail A', TmpFound.Name, 'with its name');
    Assert.AreEqual(10.0, TmpFound.Spec.Window.Left, 1E-9, 'and its window');
    Assert.AreEqual(40.0, TmpFound.Spec.Window.Top, 1E-9, 'all of it');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADNamedViewTests.LoadingTheSameViewsTwiceKeepsOneOfEach;
var
  TmpArray: TJSONArray;
begin
  FCAD.Views.Add('Detail A', Framing(0, 0, 10, 10));
  TmpArray := FCAD.Views.SaveToJSON;
  try
    { What merging a drawing into itself does. Two views with one
      identifier would leave a link two views to choose between. }
    FCAD.Views.LoadFromJSON(TmpArray);
    Assert.AreEqual(1, FCAD.Views.Count, 'still one');
  finally
    TmpArray.Free;
  end;
end;

{ ==================================================================
  TCADViewLinkTests
  ================================================================== }

function TCADViewLinkTests.Framing(const AL, AB, AR, AT: TRealType)
  : TCADViewSpec;
begin
  Result := TCADViewSpec.Default;
  Result.Window := Rect2D(AL, AB, AR, AT);
end;

function TCADViewLinkTests.Device: TCADPageDevice;
begin
  Result := TCADPageDevice.FromDPI(CADMMPerInch, CADMMPerInch);
end;

function TCADViewLinkTests.LinesDrawn: Integer;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    Result := TmpRec.CountOf('MoveTo');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADViewLinkTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  { One line across a 300 by 150 model. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  FSheet := FCAD.Sheets.Add('Plan');
  { The detail: the bottom-left corner of the model. }
  FDetail := FCAD.Views.Add('Detail A', Framing(0, 0, 100, 50));
  { Two viewports on it, the same shape, one 100 mm wide and one 50. }
  FFirst := FSheet.AddViewport;
  FFirst.RectMM := Rect2D(10, 10, 110, 60);
  FFirst.LinkTo(FDetail);
  FSecond := FSheet.AddViewport;
  FSecond.RectMM := Rect2D(150, 10, 200, 35);
  FSecond.LinkTo(FDetail);
end;

procedure TCADViewLinkTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADViewLinkTests.ALinkedViewportShowsTheNamedView;
var
  TmpCentre: TPoint2D;
begin
  Assert.IsTrue(FFirst.IsLinked, 'linked');
  Assert.AreSame(TObject(FDetail), TObject(FFirst.LinkedView(FCAD)),
    'to the detail');
  TmpCentre := FFirst.ModelCentre(FCAD);
  Assert.AreEqual(50.0, TmpCentre.X, 1E-9, 'centred on the detail');
  Assert.AreEqual(25.0, TmpCentre.Y, 1E-9, 'in both axes');
end;

procedure TCADViewLinkTests.ChangingTheNamedViewMovesEveryViewportLinkedToIt;
var
  TmpSpec: TCADViewSpec;
begin
  { The point of a link: redefine "Detail A" once and every sheet it is
    on follows. }
  TmpSpec := FDetail.Spec;
  TmpSpec.Window := Rect2D(200, 100, 300, 150);
  FDetail.Spec := TmpSpec;
  Assert.AreEqual(250.0, FFirst.ModelCentre(FCAD).X, 1E-9, 'the first moved');
  Assert.AreEqual(250.0, FSecond.ModelCentre(FCAD).X, 1E-9,
    'and so did the second');
end;

procedure TCADViewLinkTests.PanningOneLinkedViewportMovesTheOthers;
begin
  FFirst.PanModelBy(FCAD, 20, 10);
  { What is looked at is shared. }
  Assert.AreEqual(70.0, FSecond.ModelCentre(FCAD).X, 1E-9,
    'the other viewport moved with it');
  Assert.AreEqual(35.0, FSecond.ModelCentre(FCAD).Y, 1E-9, 'both ways');
  Assert.AreEqual(70.0, FDetail.Spec.Window.Left + 50, 1E-9,
    'because the named view itself moved');
end;

procedure TCADViewLinkTests.TheScaleStaysWithTheViewport;
var
  TmpSecondScale: TRealType;
begin
  TmpSecondScale := FSecond.EffectiveUnitsPerMM(FCAD);
  FFirst.ZoomBy(FCAD, 4);
  { What is not shared: how big it is on the paper. A detail can be at
    1:5 in one place and 1:20 in another and still be the same detail. }
  Assert.AreEqual(TmpSecondScale, FSecond.EffectiveUnitsPerMM(FCAD), 1E-9,
    'the other viewport kept its scale');
  Assert.AreEqual(50.0, FSecond.ModelCentre(FCAD).X, 1E-9,
    'and its centre, because a zoom does not move the window');
end;

procedure TCADViewLinkTests.AssigningAViewEndsTheLink;
begin
  FFirst.View := Framing(0, 100, 50, 150);
  Assert.IsFalse(FFirst.IsLinked, 'unlinked');
  Assert.AreEqual(25.0, FFirst.ModelCentre(FCAD).X, 1E-9,
    'showing what it was given');
  Assert.AreEqual(50.0, FSecond.ModelCentre(FCAD).X, 1E-9,
    'and the other viewport, and the named view, are untouched');
end;

procedure TCADViewLinkTests.DeletingTheNamedViewLeavesItsViewportsShowingWhatTheyShowed;
var
  TmpSpec: TCADViewSpec;
begin
  { Moved after linking, so the viewports' own copies are stale until
    the delete brings them up to date - which is the case that would
    blank or jump a sheet if it did not. }
  TmpSpec := FDetail.Spec;
  TmpSpec.Window := Rect2D(200, 100, 300, 150);
  FDetail.Spec := TmpSpec;
  FCAD.Views.Delete(FCAD.Views.IndexOfId(FDetail.Id));
  Assert.IsFalse(FFirst.IsLinked, 'unlinked');
  Assert.AreEqual(250.0, FFirst.ModelCentre(FCAD).X, 1E-9,
    'and still showing where the detail was');
  Assert.AreEqual(250.0, FSecond.ModelCentre(FCAD).X, 1E-9, 'both of them');
end;

procedure TCADViewLinkTests.ALinkSurvivesSaveAndLoad;
var
  TmpBack: TFNCCADCmp2D;
  TmpSpec: TCADViewSpec;
begin
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    TmpBack.LoadFromJSONString(FCAD.SaveToJSONString);
    Assert.AreEqual(FDetail.Id, TmpBack.Sheets[0].Viewports[0].ViewLink,
      'the link came back');
    { And still a link, not a copy: change the reloaded named view and
      the reloaded viewport follows. }
    TmpSpec := TmpBack.Views[0].Spec;
    TmpSpec.Window := Rect2D(200, 100, 300, 150);
    TmpBack.Views[0].Spec := TmpSpec;
    Assert.AreEqual(250.0,
      TmpBack.Sheets[0].Viewports[0].ModelCentre(TmpBack).X, 1E-9,
      'a live link');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADViewLinkTests.TheFileCarriesAnUpToDateCopyForReadersWithoutLinks;
var
  TmpSpec: TCADViewSpec;
  TmpBack: TFNCCADCmp2D;
begin
  TmpSpec := FDetail.Spec;
  TmpSpec.Window := Rect2D(200, 100, 300, 150);
  FDetail.Spec := TmpSpec;
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    TmpBack.LoadFromJSONString(FCAD.SaveToJSONString);
    { The viewport's own view, as written - what a reader that knows
      nothing of links shows. It has to be the detail as it is now, not
      as it was when the viewport was linked. }
    Assert.AreEqual(200.0, TmpBack.Sheets[0].Viewports[0].View.Window.Left,
      1E-9, 'the copy was brought up to date before saving');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADViewLinkTests.ALinkThatFindsNothingFallsBackToTheOwnCopy;
begin
  { A sheet copied in from another drawing: the identifier is there and
    the view is not. }
  FFirst.ViewLink := '{00000000-0000-0000-0000-000000000000}';
  Assert.IsTrue(FFirst.IsLinked, 'it still says it is linked');
  Assert.IsNull(FFirst.LinkedView(FCAD), 'to nothing');
  Assert.AreEqual(50.0, FFirst.ModelCentre(FCAD).X, 1E-9,
    'and shows its own copy rather than the whole drawing');
end;

procedure TCADViewLinkTests.TheLinkedViewsHiddenLayersAreHiddenOnTheSheet;
var
  TmpSpec: TCADViewSpec;
begin
  { One viewport is enough for this. }
  FSheet.DeleteViewport(1);
  Assert.AreEqual(1, LinesDrawn, 'the model line, through the viewport');
  TmpSpec := FDetail.Spec;
  TmpSpec.UseLayerOverride := True;
  TmpSpec.HiddenLayers := [0];
  FDetail.Spec := TmpSpec;
  { Changed on the named view, not on the viewport: a detail that hides
    a layer hides it on every sheet it is placed on. }
  Assert.AreEqual(0, LinesDrawn, 'hidden by the linked view');
end;

{ ==================================================================
  TCADViewFromSelectionTests
  ================================================================== }

procedure TCADViewFromSelectionTests.AnAreaBecomesAWindowWithAMargin;
var
  TmpView: TCADViewSpec;
begin
  { Dragged from the top-right to the bottom-left, as people do. }
  TmpView := CADViewFromArea(Rect2D(100, 50, 0, 0), 0.1);
  Assert.AreEqual(-10.0, TmpView.Window.Left, 1E-9, 'a tenth of 100 left');
  Assert.AreEqual(-10.0, TmpView.Window.Bottom, 1E-9,
    'and the same below - the margin comes from the larger side');
  Assert.AreEqual(110.0, TmpView.Window.Right, 1E-9, 'right');
  Assert.AreEqual(60.0, TmpView.Window.Top, 1E-9, 'top');
  Assert.IsFalse(TmpView.UseLayerOverride,
    'and it leaves the layers alone');
end;

procedure TCADViewFromSelectionTests.ObjectsBecomeTheUnionOfTheirBoxes;
var
  TmpList: TGraphicObjList;
  TmpView: TCADViewSpec;
begin
  TmpList := TGraphicObjList.Create;
  try
    TmpList.FreeOnClear := True;
    TmpList.Add(TLine2D.Create(1, Point2D(10, 10), Point2D(20, 20)));
    TmpList.Add(TLine2D.Create(2, Point2D(50, 0), Point2D(60, 30)));
    TmpView := CADViewFromObjects(TmpList, 0);
    Assert.AreEqual(10.0, TmpView.Window.Left, 1E-9, 'left of the first');
    Assert.AreEqual(0.0, TmpView.Window.Bottom, 1E-9, 'bottom of the second');
    Assert.AreEqual(60.0, TmpView.Window.Right, 1E-9, 'right of the second');
    Assert.AreEqual(30.0, TmpView.Window.Top, 1E-9, 'top of the second');
  finally
    TmpList.Free;
  end;
end;

procedure TCADViewFromSelectionTests.AFlatSelectionStillFramesSomething;
var
  TmpView: TCADViewSpec;
begin
  { One horizontal line: a box with no height, which a viewport would
    read as "frames nothing" and fill with the whole drawing. }
  TmpView := CADViewFromArea(Rect2D(0, 5, 100, 5), 0.05);
  Assert.IsTrue(TmpView.Window.Top - TmpView.Window.Bottom > 0,
    'it has a height');
  Assert.AreEqual(10.0, TmpView.Window.Top - TmpView.Window.Bottom, 1E-9,
    'twice the margin of the long side');
end;

procedure TCADViewFromSelectionTests.NothingSelectedIsRefused;
begin
  Assert.WillRaise(
    procedure
    var
      TmpList: TGraphicObjList;
      TmpView: TCADViewSpec;
    begin
      TmpList := TGraphicObjList.Create;
      try
        TmpView := CADViewFromObjects(TmpList, 0.05);
        Assert.Fail('unreachable: ' + TmpView.Name);
      finally
        TmpList.Free;
      end;
    end, ECADPageError, 'a detail of nothing');
end;

procedure TCADViewFromSelectionTests.APointIsRefused;
begin
  Assert.WillRaise(
    procedure
    var
      TmpView: TCADViewSpec;
    begin
      TmpView := CADViewFromArea(Rect2D(5, 5, 5, 5), 0.05);
      Assert.Fail('unreachable: ' + TmpView.Name);
    end, ECADPageError, 'no margin rescues a point');
end;

{ ==================================================================
  TCADSheetDrawingTests
  ================================================================== }

function TCADSheetDrawingTests.Device: TCADPageDevice;
begin
  Result := TCADPageDevice.FromDPI(CADMMPerInch, CADMMPerInch);
end;

procedure TCADSheetDrawingTests.DrawSheetNow(out ALines: Integer;
  out AText: String);
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    ALines := TmpRec.CountOf('MoveTo');
    AText := TmpRec.Log.Text;
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetDrawingTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  { A model 300 units wide, and a viewport 100 mm wide to look at it
    through: three units to the millimetre, and nothing round about
    the numbers by accident. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  FSheet := FCAD.Sheets.Add('Plan');
  FViewport := FSheet.AddViewport;
  FViewport.RectMM := Rect2D(10, 10, 110, 60);
end;

procedure TCADSheetDrawingTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADSheetDrawingTests.AViewportRectangleFlipsIntoDeviceRows;
var
  TmpRect: TRect;
begin
  TmpRect := CADSheetViewportRectPx(FSheet, FViewport, Device);
  { The sheet is 297 mm tall and its Y runs upwards; the device's runs
    down. So the viewport's top edge at 60 mm is device row 237, and
    its bottom edge at 10 mm is row 287. Taking the corners the other
    way round gives an inside-out rectangle, which clips away to
    nothing and draws a blank sheet without a word of complaint.

    Whole millimetres onto whole pixels, the same arithmetic the
    sheet's own rectangle uses. Through the sheet's visual transform
    this came out a pixel smaller, because that transform is laid out
    on pixel centres - right for drawing, wrong for two rectangles
    that have to meet. }
  Assert.AreEqual(10, TmpRect.Left, 'left');
  Assert.AreEqual(237, TmpRect.Top, '297 less the 60 mm top edge');
  Assert.AreEqual(110, TmpRect.Right, 'right');
  Assert.AreEqual(287, TmpRect.Bottom, '297 less the 10 mm bottom edge');
end;

procedure TCADSheetDrawingTests.TheViewportClipSitsInsideTheSheetClip;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpLog: String;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    TmpLog := TmpRec.Log.Text;
    { Two levels, and this is the whole reason PushClip had to learn to
      nest. Before it did, the second push was dropped and a viewport
      was free to paint over the rest of the sheet. }
    Assert.IsTrue(TmpLog.Contains('PushClip 0,0,420,297'),
      'the sheet was clipped to the paper: ' + TmpLog);
    Assert.IsTrue(TmpLog.Contains('PushClip 10,237,110,287'),
      'and the viewport to its own rectangle: ' + TmpLog);
    Assert.AreEqual(2, TmpRec.CountOf('PushClip'), 'two clips went down');
    Assert.AreEqual(2, TmpRec.CountOf('PopClip'), 'and both came back');
    Assert.AreEqual(0, TmpRec.ClipDepth, 'nothing left in force');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetDrawingTests.TheModelIsDrawnThroughTheViewportAndTheAnnotationOverIt;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpIdxViewport, TmpIdxAnnotation: Integer;
begin
  FSheet.AddObject(TLine2D.Create(-1, Point2D(10, 287), Point2D(410, 287)));
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    { One polyline - the viewport's border. A TLine2D draws itself
      with MoveTo and LineTo, not as a polyline, so the two lines are
      counted by their MoveTo. }
    Assert.AreEqual(1, TmpRec.CountOf('Polyline'),
      'the viewport border, and only that: ' + TmpRec.Log.Text);
    Assert.AreEqual(2, TmpRec.CountOf('MoveTo'),
      'the model line and the sheet''s own line: ' + TmpRec.Log.Text);

    { The annotation was placed at 287 mm up a 297 mm sheet, so it
      lands on device row 10 - which is the Y flip proved by where it
      came out rather than by arithmetic repeated in the test. }
    TmpIdxAnnotation := TmpRec.Log.IndexOf('MoveTo 10,10');
    Assert.IsTrue(TmpIdxAnnotation >= 0,
      'the annotation was drawn in the sheet''s millimetres: '
      + TmpRec.Log.Text);
    TmpIdxViewport := TmpRec.Log.IndexOf('PopClip');
    { After the viewport gave its clip back, which is what puts a
      title block in front of the drawing rather than behind it. }
    Assert.IsTrue(TmpIdxAnnotation > TmpIdxViewport,
      'the annotation came after the viewport: ' + TmpRec.Log.Text);
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetDrawingTests.TheBorderIsDrawnOverTheModel;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
  TmpIdxModel, TmpIdxPop, TmpIdxBorder, Cont: Integer;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    TmpIdxModel := -1;
    TmpIdxPop := -1;
    TmpIdxBorder := -1;
    for Cont := 0 to TmpRec.Log.Count - 1 do
    begin
      if (TmpIdxModel < 0) and TmpRec.Log[Cont].StartsWith('MoveTo') then
        TmpIdxModel := Cont;
      if (TmpIdxPop < 0) and (TmpRec.Log[Cont] = 'PopClip') then
        TmpIdxPop := Cont;
      if (TmpIdxBorder < 0) and TmpRec.Log[Cont].StartsWith('Polyline') then
        TmpIdxBorder := Cont;
    end;
    Assert.IsTrue((TmpIdxModel >= 0) and (TmpIdxBorder >= 0),
      'both were drawn: ' + TmpRec.Log.Text);
    { The clip is the border's own rectangle, so a filled shape running
      off the edge of the viewport paints over a border drawn before
      it - which is what a sheet with a filled rectangle cut by a
      detail viewport showed: a border with a corner missing. }
    Assert.IsTrue(TmpIdxBorder > TmpIdxModel,
      'the border after the model: ' + TmpRec.Log.Text);
    Assert.IsTrue(TmpIdxBorder > TmpIdxPop,
      'and outside the viewport''s clip, so none of it is cut: '
      + TmpRec.Log.Text);
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetDrawingTests.ABorderlessViewportDrawsNoOutline;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  FViewport.ShowBorder := False;
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    { Nothing left but the model line, which draws itself with MoveTo
      and LineTo. And a rectangle was never drawn: the border is a
      polyline on purpose, because a rectangle is filled with the
      brush and would hide what the viewport is for. }
    Assert.AreEqual(0, TmpRec.CountOf('Polyline'), 'no border');
    Assert.AreEqual(1, TmpRec.CountOf('MoveTo'), 'the model, still drawn');
    Assert.AreEqual(0, TmpRec.CountOf('Rectangle'),
      'and nothing that fills');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetDrawingTests.TheCanvasScaleIsPutBack;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpRec.PixelsPerMM := 0;
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    { The canvas may well be the screen's, and leaving a printer's
      millimetre scale on it makes every line drawn afterwards several
      times too thick. }
    Assert.AreEqual(0.0, TmpRec.PixelsPerMM, 1E-9,
      'the scale went back to what it was');
  finally
    TmpRec.Free;
  end;
end;

{ ==================================================================
  TCADSheetHitTestTests
  ================================================================== }

function TCADSheetHitTestTests.Device: TCADPageDevice;
begin
  { One device pixel to the millimetre, so every number below is a
    millimetre of A3 landscape paper. }
  Result := TCADPageDevice.FromDPI(CADMMPerInch, CADMMPerInch);
end;

procedure TCADSheetHitTestTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  FSheet := FCAD.Sheets.Add('Plan');
  FViewport := FSheet.AddViewport;
  { 100 x 50 mm of paper over a 300 x 150 model: three units to the
    millimetre, so one device pixel here is three model units and the
    tolerances below are written in those. }
  FViewport.RectMM := Rect2D(10, 10, 110, 60);
end;

procedure TCADSheetHitTestTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADSheetHitTestTests.APointOnThePaperIsMillimetres;
var
  TmpPt: TPoint2D;
begin
  { Device row 287 on a 297 mm sheet is 10 mm up from the bottom edge,
    because the paper's Y runs upwards and the device's runs down.
    This is where a click on a title block has to land. }
  TmpPt := CADSheetPointToMM(FSheet, Device, Point(10, 287));
  Assert.AreEqual(10.0, TmpPt.X, 1E-9, 'ten millimetres in');
  Assert.AreEqual(10.0, TmpPt.Y, 1E-9, 'and ten up, not 287 down');

  TmpPt := CADSheetPointToMM(FSheet, Device, Point(410, 10));
  Assert.AreEqual(410.0, TmpPt.X, 1E-9, 'the far corner across');
  Assert.AreEqual(287.0, TmpPt.Y, 1E-9, 'and up');
end;

procedure TCADSheetHitTestTests.MillimetresAndPixelsAreEachOthersInverse;
var
  TmpPt: TPoint;
begin
  TmpPt := CADSheetMMToPoint(FSheet, Device, Point2D(15, 40));
  { The same arithmetic the viewport's own clip rectangle comes from -
    which is the point of writing it out rather than inverting the
    drawing transform, because that one is laid out on pixel centres
    and would disagree with the rectangle by half a pixel. }
  Assert.AreEqual(15, TmpPt.X, 'across');
  Assert.AreEqual(257, TmpPt.Y, '297 less 40');
  Assert.AreEqual(15.0, CADSheetPointToMM(FSheet, Device, TmpPt).X, 1E-9,
    'and back again');
  Assert.AreEqual(40.0, CADSheetPointToMM(FSheet, Device, TmpPt).Y, 1E-9,
    'both ways');
end;

procedure TCADSheetHitTestTests.AViewportIsFoundByItsRectangle;
begin
  { The viewport is 10..110 mm across and 10..60 up, so on the device
    it is rows 237..287. }
  Assert.AreEqual(0, CADSheetViewportIndexAt(FSheet, Device, Point(60, 262)),
    'the middle of it');
  Assert.AreEqual(-1, CADSheetViewportIndexAt(FSheet, Device, Point(60, 100)),
    'well above it - and the paper is not a viewport');
  Assert.AreEqual(-1, CADSheetViewportIndexAt(FSheet, Device, Point(200, 262)),
    'and to the right of it');
  Assert.IsNotNull(CADSheetViewportAt(FSheet, Device, Point(60, 262)),
    'the object form answers too');
  Assert.IsNull(CADSheetViewportAt(FSheet, Device, Point(400, 20)),
    'and nil where there is nothing');
end;

procedure TCADSheetHitTestTests.TheViewportOnTopIsTheOneThatAnswers;
var
  TmpSecond: TCADSheetViewport;
begin
  TmpSecond := FSheet.AddViewport;
  TmpSecond.RectMM := Rect2D(50, 30, 150, 80);
  { CADDrawSheet draws them in order, so the second one is painted over
    the first. A hit test that answered with the first would hand the
    user the viewport they cannot see. }
  Assert.AreEqual(1, CADSheetViewportIndexAt(FSheet, Device, Point(60, 250)),
    'where they overlap, the one on top');
  Assert.AreEqual(0, CADSheetViewportIndexAt(FSheet, Device, Point(20, 280)),
    'and the one underneath where it is alone');
end;

procedure TCADSheetHitTestTests.TheCentreOfAViewportIsTheCentreOfWhatItShows;
var
  TmpPt: TPoint2D;
begin
  { The model is 300 x 150 and the viewport frames all of it, so the
    middle of the rectangle is the middle of the drawing. Within a
    device pixel, which here is three model units - the transform is
    laid out on pixel centres and this test is not the place to
    re-derive that half pixel. }
  TmpPt := CADSheetPointToModel(FCAD, FSheet, FViewport, Device,
    Point(60, 262));
  Assert.AreEqual(150.0, TmpPt.X, 3.0, 'halfway across the drawing');
  Assert.AreEqual(75.0, TmpPt.Y, 3.0, 'and halfway up it');
end;

procedure TCADSheetHitTestTests.APointSurvivesTheRoundTripThroughTheModel;
var
  TmpBack: TPoint;
  TmpModel: TPoint2D;
begin
  { Device to model and back. A round trip is worth more than either
    direction checked against arithmetic repeated in the test: it
    cannot agree with a mistake unless the mistake cancels itself. }
  TmpModel := CADSheetPointToModel(FCAD, FSheet, FViewport, Device,
    Point(37, 251));
  TmpBack := CADSheetModelToPoint(FCAD, FSheet, FViewport, Device, TmpModel);
  Assert.AreEqual(37, TmpBack.X, 'the same pixel across');
  Assert.AreEqual(251, TmpBack.Y, 'and the same row');
end;

procedure TCADSheetHitTestTests.APointOutsideAViewportStillTransforms;
var
  TmpPt: TPoint2D;
begin
  { Deliberate: a drag that leaves the viewport is still a drag in that
    viewport's model, and the library has no business deciding that a
    point which is off the paper means nothing. Asking which viewport a
    point is in is a separate question with a separate routine. }
  TmpPt := CADSheetPointToModel(FCAD, FSheet, FViewport, Device,
    Point(160, 262));
  Assert.IsTrue(TmpPt.X > 300.0,
    'fifty millimetres past the right edge, at three units each');
end;

procedure TCADSheetEditingTests.DeletingFromASheetTellsTheDrawing;
var
  TmpLine: TObject2D;
begin
  TmpLine := FSheet.AddObject(TLine2D.Create(-1, Point2D(1, 1),
    Point2D(2, 2)));
  FLog.Clear;
  FSheet.DeleteObject(TmpLine.ID);
  Assert.AreEqual(1, FLog.Count, 'one report');
  { Named, because the report goes out before the object is freed: a
    handler that wants to put it on an undo stack has to be able to
    look at it. }
  Assert.AreEqual('removed Plan TLine2D', FLog[0], 'what went');
  Assert.AreEqual(0, FSheet.ObjectsCount, 'and it is off the sheet');
end;

procedure TCADSheetEditingTests.SayingAnObjectChangedTellsTheDrawing;
var
  TmpLine: TObject2D;
begin
  TmpLine := FSheet.AddObject(TLine2D.Create(-1, Point2D(1, 1),
    Point2D(2, 2)));
  FLog.Clear;
  { A sheet cannot notice a transform by itself - whoever did it says
    so. This is the channel an application marking a file modified
    listens on. }
  FSheet.ObjectChanged(TmpLine);
  Assert.AreEqual(1, FLog.Count, 'one report');
  Assert.AreEqual('changed Plan TLine2D', FLog[0], 'and what it says');
end;

procedure TCADSheetEditingTests.ClearingASheetReportsOnceWithNoObject;
begin
  FSheet.AddObject(TLine2D.Create(-1, Point2D(1, 1), Point2D(2, 2)));
  FSheet.AddObject(TLine2D.Create(-1, Point2D(3, 3), Point2D(4, 4)));
  FLog.Clear;
  FSheet.DeleteAllObjects;
  { Not one report per object: the event documents a nil object as a
    change that is not about one of them, and this is that. }
  Assert.AreEqual(1, FLog.Count, 'once for the lot');
  Assert.AreEqual('removed Plan', FLog[0], 'with no object named');
end;

procedure TCADSheetEditingTests.DeletingSomethingThatIsNotThereRaises;
begin
  { The drawing's own answer, so that an application handles one case
    and not two. }
  Assert.WillRaise(
    procedure
    begin
      FSheet.DeleteObject(42);
    end, ECADListObjNotFound, 'nothing with that identifier');
end;

{ ==================================================================
  TTestLegendBox and TCADSheetCustomClassTests
  ================================================================== }

const
  { : Where an application's classes start, per the library's own
    advice. Registered in Setup and taken out again in TearDown, so
    that the rest of the suite runs with the registry it expects. }
  CADTestLegendBoxIndex = 150;

var
  { : The last warning the library reported. CADSysOnWarning is a plain
    procedure variable, not an event, so this cannot be a field on the
    fixture. }
  TestLastWarning: String;

procedure CaptureWarning(const AMessage: String);
begin
  TestLastWarning := AMessage;
end;

constructor TTestLegendBox.CreateFromJSON(const AJSON: TJSONObject);
begin
  inherited;
  fCaption := JGetStr(AJSON, 'caption');
end;

procedure TTestLegendBox.SaveToJSON(const AJSON: TJSONObject);
begin
  inherited SaveToJSON(AJSON);
  JSetStr(AJSON, 'caption', fCaption);
end;

procedure TCADSheetCustomClassTests.Setup;
begin
  CADSysRegisterClass(CADTestLegendBoxIndex, TTestLegendBox);
  FCAD := TFNCCADCmp2D.Create(nil);
  FSheet := FCAD.Sheets.Add('Plan');
end;

procedure TCADSheetCustomClassTests.TearDown;
begin
  FCAD.Free;
  CADSysUnregisterClass(CADTestLegendBoxIndex);
  CADSysOnWarning := nil;
  TestLastWarning := '';
end;

function TCADSheetCustomClassTests.NewBox(const ACaption: String)
  : TTestLegendBox;
begin
  Result := TTestLegendBox.Create(-1, Point2D(10, 10), Point2D(90, 40));
  Result.Caption := ACaption;
end;

function TCADSheetCustomClassTests.Reload: TFNCCADCmp2D;
begin
  { Through the text, as the other persistence tests do. }
  Result := TFNCCADCmp2D.Create(nil);
  try
    Result.LoadFromJSONString(FCAD.SaveToJSONString);
  except
    Result.Free;
    Raise;
  end;
end;

procedure TCADSheetCustomClassTests.ACustomClassOnASheetRoundTrips;
var
  TmpBack: TFNCCADCmp2D;
  TmpObj: TObject2D;
begin
  FSheet.AddObject(NewBox('Drawn by'), 4);
  TmpBack := Reload;
  try
    Assert.AreEqual(1, TmpBack.Sheets[0].ObjectsCount, 'one object');
    TmpObj := TmpBack.Sheets[0].GetObject(4);
    Assert.IsNotNull(TmpObj, 'and it kept its identifier');
    { The class, not just something frame-shaped: the registry is what
      turns the saved type name back into the application's own class,
      and a sheet has to go through it like the model. }
    Assert.IsTrue(TmpObj.ClassType = TTestLegendBox,
      'reloaded as itself, not as a ' + TmpObj.ClassName);
    Assert.AreEqual('Drawn by', TTestLegendBox(TmpObj).Caption,
      'with its own field');
    Assert.AreEqual(10.0, TmpObj.Box.Left, 1E-9, 'and its geometry');
    Assert.AreEqual(90.0, TmpObj.Box.Right, 1E-9, 'both corners');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADSheetCustomClassTests.TheSheetGoesThroughTheSameRegistryAsTheModel;
var
  TmpBack: TFNCCADCmp2D;
begin
  { One registry, two spaces. If the sheet had its own loading path
    this is where it would show. }
  FCAD.AddObject(-1, NewBox('In the model'));
  FSheet.AddObject(NewBox('On the paper'));
  TmpBack := Reload;
  try
    Assert.AreEqual(1, TmpBack.ObjectsCount, 'the model''s one');
    Assert.AreEqual(1, TmpBack.Sheets[0].ObjectsCount, 'the sheet''s one');
    Assert.AreEqual('On the paper',
      TTestLegendBox(TmpBack.Sheets[0].GetObject(0)).Caption,
      'and each kept its own caption');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADSheetCustomClassTests.AnUnknownClassIsSkippedWithAWarning;
var
  TmpText: String;
  TmpBack: TFNCCADCmp2D;
begin
  FSheet.AddObject(NewBox('Drawn by'));
  TmpText := FCAD.SaveToJSONString;
  { Opened somewhere the application's classes are not registered -
    another program, or this one with a plug-in missing. The drawing
    has to open anyway, without the object and with something said
    about it. }
  CADSysUnregisterClass(CADTestLegendBoxIndex);
  CADSysOnWarning := CaptureWarning;
  TestLastWarning := '';
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    TmpBack.LoadFromJSONString(TmpText);
    Assert.AreEqual(1, TmpBack.Sheets.Count, 'the sheet is still there');
    Assert.AreEqual(0, TmpBack.Sheets[0].ObjectsCount,
      'without the object it could not make');
    Assert.IsTrue(TestLastWarning <> '', 'and it said so');
  finally
    TmpBack.Free;
    { Put it back: TearDown takes it out again. }
    CADSysRegisterClass(CADTestLegendBoxIndex, TTestLegendBox);
  end;
end;

{ ==================================================================
  TCADSpaceTests
  ================================================================== }

procedure TCADSpaceTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FSheet := FCAD.Sheets.Add('Plan');
end;

procedure TCADSpaceTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADSpaceTests.ModelSpaceIsTheDrawingsList;
var
  TmpList: TGraphicObjList;
begin
  Assert.IsFalse(CADSpaceIsPaper(CADSpace(FCAD)), 'no sheet, no paper');
  { TFNCCADCmp.ObjectList is protected, which is the reason
    CADSpaceObjects exists: the list is identified by what it contains
    rather than by comparing references. }
  TmpList := CADSpaceObjects(CADSpace(FCAD));
  Assert.IsNotNull(TmpList, 'model space has a list');
  Assert.IsFalse(TmpList = FSheet.ObjectList, 'and it is not the sheet''s');
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(10, 10)));
  Assert.AreEqual(FCAD.ObjectsCount, Integer(TmpList.Count),
    'it is the drawing''s own display list');
end;

procedure TCADSpaceTests.PaperSpaceIsTheSheetsList;
begin
  Assert.IsTrue(CADSpaceIsPaper(CADSpace(FCAD, FSheet)), 'a sheet is paper');
  Assert.AreSame(FSheet.ObjectList, CADSpaceObjects(CADSpace(FCAD, FSheet)),
    'the sheet''s own objects');
end;

procedure TCADSpaceTests.AddingToPaperSpaceLeavesTheModelAlone;
begin
  CADSpaceAddObject(CADSpace(FCAD, FSheet), -1,
    TLine2D.Create(-1, Point2D(0, 0), Point2D(10, 10)));
  Assert.AreEqual(1, FSheet.ObjectsCount, 'on the paper');
  Assert.AreEqual(0, FCAD.ObjectsCount, 'and not in the model');
end;

procedure TCADSpaceTests.TheSpaceAssignsTheIdentifier;
var
  TmpFirst, TmpSecond: TObject2D;
begin
  { A negative identifier is what a caller that does not care passes,
    and the answer comes back on the object: the sheet's counter starts
    at zero and has nothing to do with the drawing's. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(2, 2)));
  TmpFirst := CADSpaceAddObject(CADSpace(FCAD, FSheet), -1,
    TLine2D.Create(-1, Point2D(0, 0), Point2D(3, 3)));
  TmpSecond := CADSpaceAddObject(CADSpace(FCAD, FSheet), -1,
    TLine2D.Create(-1, Point2D(0, 0), Point2D(4, 4)));
  Assert.AreEqual(0, TmpFirst.ID, 'the sheet numbers from zero');
  Assert.AreEqual(1, TmpSecond.ID, 'and counts up on its own');
end;

procedure TCADSpaceTests.AGivenIdentifierIsKeptAndMovesTheCounterPastIt;
var
  TmpGiven, TmpNext: TObject2D;
begin
  { The drawing's rule, so that a sheet can be reloaded with the
    identifiers it was saved with. }
  TmpGiven := CADSpaceAddObject(CADSpace(FCAD, FSheet), 7,
    TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  TmpNext := CADSpaceAddObject(CADSpace(FCAD, FSheet), -1,
    TLine2D.Create(-1, Point2D(0, 0), Point2D(2, 2)));
  Assert.AreEqual(7, TmpGiven.ID, 'the one it was given');
  Assert.AreEqual(8, TmpNext.ID, 'and the counter is past it');
end;

procedure TCADSpaceTests.TheSameIdentifierMeansTwoDifferentObjects;
var
  TmpSpace: TCADSpace2D;
begin
  { The trap this lookup exists for. Both spaces number from zero, so
    an application that asks the drawing for object 0 while the user is
    looking at a sheet gets the model's object 0 - a different shape,
    silently. }
  FCAD.AddObject(0, TLine2D.Create(0, Point2D(0, 0), Point2D(10, 10)));
  FSheet.AddObject(TFrame2D.Create(-1, Point2D(0, 0), Point2D(50, 20)));
  Assert.IsTrue(FCAD.GetObject(0) is TLine2D, 'the model''s nought');
  Assert.IsTrue(FSheet.GetObject(0) is TFrame2D, 'the sheet''s nought');

  TmpSpace := CADSpace(FCAD, FSheet);
  Assert.IsTrue(CADSpaceGetObject(TmpSpace, 0) is TFrame2D,
    'and the space is asked, not the drawing');
  Assert.IsTrue(CADSpaceGetObject(CADSpace(FCAD), 0) is TLine2D,
    'model space answers for itself');
  Assert.IsNull(FSheet.GetObject(99), 'nothing found is nil, not an error');
end;

procedure TCADSpaceTests.ASheetReloadsWithTheIdentifiersItWasSavedWith;
var
  TmpText: String;
  TmpBack: TFNCCADCmp2D;
begin
  CADSpaceAddObject(CADSpace(FCAD, FSheet), 5,
    TLine2D.Create(-1, Point2D(0, 0), Point2D(10, 10)));
  CADSpaceAddObject(CADSpace(FCAD, FSheet), 9,
    TFrame2D.Create(-1, Point2D(0, 0), Point2D(50, 20)));
  TmpText := FCAD.SaveToJSONString;

  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    TmpBack.LoadFromJSONString(TmpText);
    { Renumbering on load would break anything that keeps an ID: a
      selection, an undo entry, an application's own reference to the
      box it drew. }
    Assert.IsTrue(TmpBack.Sheets[0].GetObject(5) is TLine2D,
      'five is still five');
    Assert.IsTrue(TmpBack.Sheets[0].GetObject(9) is TFrame2D,
      'and nine is still nine');
    Assert.IsNull(TmpBack.Sheets[0].GetObject(0),
      'and nothing was renumbered to nought');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADSpaceTests.DeletingThroughASpaceTakesItFromThatSpace;
begin
  { Both spaces hold an object numbered nought, which is the whole
    trap: deleting "object nought" has to mean the one in the space the
    user is looking at. }
  FCAD.AddObject(0, TLine2D.Create(0, Point2D(0, 0), Point2D(10, 10)));
  FSheet.AddObject(TFrame2D.Create(-1, Point2D(0, 0), Point2D(50, 20)));

  CADSpaceDeleteObject(CADSpace(FCAD, FSheet), 0);
  Assert.AreEqual(0, FSheet.ObjectsCount, 'off the paper');
  Assert.AreEqual(1, FCAD.ObjectsCount, 'and the model''s nought is still there');

  CADSpaceDeleteObject(CADSpace(FCAD), 0);
  Assert.AreEqual(0, FCAD.ObjectsCount, 'and now it is not');
end;

procedure TCADSpaceTests.RemovingHandsTheObjectToTheCaller;
var
  TmpLine: TObject2D;
begin
  TmpLine := FSheet.AddObject(TLine2D.Create(-1, Point2D(1, 1),
    Point2D(2, 2)));
  CADSpaceRemoveObject(CADSpace(FCAD, FSheet), TmpLine.ID);
  Assert.AreEqual(0, FSheet.ObjectsCount, 'off the sheet');
  Assert.IsNull(TmpLine.OwnerCAD, 'and answering to nobody');
  { Ours now - the sheet would have freed it, a remove does not. }
  TmpLine.Free;
end;

procedure TCADSpaceTests.AnObjectMovesBetweenSpacesByRemoveAndAdd;
var
  TmpLine: TObject2D;
begin
  { There is no one call for this on purpose: the two spaces number
    independently, so the object has to be given an identifier by the
    one it arrives in. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  TmpLine := FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(2, 2),
    Point2D(3, 3))) as TObject2D;
  Assert.AreEqual(1, TmpLine.ID, 'the drawing''s one');

  CADSpaceRemoveObject(CADSpace(FCAD), TmpLine.ID);
  CADSpaceAddObject(CADSpace(FCAD, FSheet), -1, TmpLine);

  Assert.AreEqual(1, FCAD.ObjectsCount, 'gone from the model');
  Assert.AreEqual(1, FSheet.ObjectsCount, 'and on the paper');
  Assert.AreEqual(0, TmpLine.ID, 'renumbered by the space it arrived in');
  Assert.AreSame(TObject(FCAD), TObject(TmpLine.OwnerCAD),
    'still the drawing''s own object');
end;

procedure TCADSpaceTests.MovingChangesTheOrderTheSpaceIsDrawnIn;
var
  TmpIter: TGraphicObjIterator;
  TmpFirst: LongInt;
begin
  { List order is drawing order, and a move puts the object in front of
    the insertion point in the list - that is, behind it on the paper.
    So this sends one behind nought, and one comes out first. }
  FSheet.AddObject(TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  FSheet.AddObject(TLine2D.Create(-1, Point2D(2, 2), Point2D(3, 3)));
  CADSpaceMoveObject(CADSpace(FCAD, FSheet), 1, 0);
  TmpIter := FSheet.ObjectsIterator;
  try
    TmpFirst := TmpIter.First.ID;
  finally
    TmpIter.Free;
  end;
  Assert.AreEqual(1, Integer(TmpFirst), 'one is drawn first now');
  Assert.AreEqual(2, FSheet.ObjectsCount, 'and nothing was lost');
end;

{ ==================================================================
  TCADExplodeTests
  ================================================================== }

procedure TCADExplodeTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FSheet := FCAD.Sheets.Add('Plan');
end;

procedure TCADExplodeTests.TearDown;
begin
  FCAD.Free;
end;

function TCADExplodeTests.NewTriangle: TPolygon2D;
begin
  Result := TPolygon2D.Create(-1, [Point2D(0, 0), Point2D(10, 0),
    Point2D(10, 10)]);
end;

function TCADExplodeTests.OtherThan(const AList: TGraphicObjList;
  const ASource: TGraphicObject): TGraphicObject;
var
  TmpIter: TGraphicObjIterator;
begin
  Result := nil;
  TmpIter := AList.GetIterator;
  try
    TmpIter.First;
    while TmpIter.Current <> nil do
    begin
      if TmpIter.Current <> ASource then
      begin
        Result := TmpIter.Current;
        Exit;
      end;
      TmpIter.Next;
    end;
  finally
    TmpIter.Free;
  end;
end;

procedure TCADExplodeTests.ExplodingOnASheetLeavesThePiecesOnThePaper;
var
  TmpPoly: TPolygon2D;
  TmpPiece: TGraphicObject;
begin
  TmpPoly := TPolygon2D(FSheet.AddObject(NewTriangle));
  { The destination, not the source's owner: a title block on a sheet
    has the drawing as its OwnerCAD, which is how the pieces used to
    end up in the model where nobody could see them. }
  Explode(TmpPoly, CADSpace(FCAD, FSheet));
  Assert.AreEqual(2, FSheet.ObjectsCount,
    'the polygon and the polyline it became');
  Assert.AreEqual(0, FCAD.ObjectsCount, 'and nothing in the model');
  TmpPiece := OtherThan(FSheet.ObjectList, TmpPoly);
  Assert.IsNotNull(TmpPiece, 'something was added');
  { The exact class: TPolygon2D is itself a TPolyline2D, so 'is' would
    be true of the source as well. }
  Assert.IsTrue(TmpPiece.ClassType = TPolyline2D,
    'a polygon explodes into a polyline, not a ' + TmpPiece.ClassName);
end;

procedure TCADExplodeTests.ExplodingInTheModelStillLandsInTheModel;
var
  TmpPoly: TPolygon2D;
begin
  TmpPoly := TPolygon2D(FCAD.AddObject(-1, NewTriangle));
  Explode(TmpPoly, CADSpace(FCAD));
  Assert.AreEqual(2, FCAD.ObjectsCount, 'the polygon and its polyline');
  Assert.AreEqual(0, FSheet.ObjectsCount, 'the sheet is not involved');
end;

procedure TCADExplodeTests.APieceKeepsTheSourcesLayerInEitherSpace;
var
  TmpPoly: TPolygon2D;
  TmpPiece: TGraphicObject;
begin
  { A drawing puts whatever it is handed on its current layer, so a
    piece has to be put back on the source's layer after the add. The
    current layer is set to something else here on purpose: without the
    correction the model's piece would come out on layer 4. }
  FCAD.CurrentLayer := 4;
  TmpPoly := TPolygon2D(FSheet.AddObject(NewTriangle));
  TmpPoly.Layer := 3;
  Explode(TmpPoly, CADSpace(FCAD, FSheet));
  TmpPiece := OtherThan(FSheet.ObjectList, TmpPoly);
  Assert.IsNotNull(TmpPiece, 'the piece is there');
  Assert.AreEqual(3, Integer(TmpPiece.Layer), 'on the paper');

  TmpPoly := TPolygon2D(FCAD.AddObject(-1, NewTriangle));
  TmpPoly.Layer := 3;
  Explode(TmpPoly, CADSpace(FCAD));
  TmpPiece := OtherThan(CADSpaceObjects(CADSpace(FCAD)), TmpPoly);
  Assert.IsNotNull(TmpPiece, 'and in the model');
  Assert.AreEqual(3, Integer(TmpPiece.Layer),
    'not the drawing''s current layer');
end;

procedure TCADExplodeTests.ThePiecesGetIdentifiersFromTheSpaceTheyLandIn;
var
  TmpPoly: TPolygon2D;
  TmpPiece: TGraphicObject;
begin
  { The model is given a couple of objects first, so that a piece
    carrying a drawing identifier onto the paper would show up as the
    wrong number rather than coincidentally the right one. }
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(2, 2)));
  TmpPoly := TPolygon2D(FSheet.AddObject(NewTriangle));
  Assert.AreEqual(0, TmpPoly.ID, 'the polygon is the sheet''s nought');
  Explode(TmpPoly, CADSpace(FCAD, FSheet));
  TmpPiece := OtherThan(FSheet.ObjectList, TmpPoly);
  Assert.IsNotNull(TmpPiece, 'the piece is there');
  Assert.AreEqual(1, Integer(TmpPiece.ID),
    'and it is the sheet''s one, not the drawing''s two');
end;

{ ==================================================================
  TCADViewportInsetTests
  ================================================================== }

function TCADViewportInsetTests.Device: TCADPageDevice;
begin
  { One device pixel to the millimetre, so every number is a
    millimetre - as in TCADSheetDrawingTests. }
  Result := TCADPageDevice.FromDPI(CADMMPerInch, CADMMPerInch);
end;

procedure TCADViewportInsetTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(300, 150)));
  FSheet := FCAD.Sheets.Add('Plan');
  FViewport := FSheet.AddViewport;
  { 100 by 50 mm; the inset tests take 20 off the left and 10 off the
    top, leaving 80 by 40. }
  FViewport.RectMM := Rect2D(10, 10, 110, 60);
  FCalls := nil;
end;

procedure TCADViewportInsetTests.TearDown;
begin
  FCAD.Free;
end;

procedure TCADViewportInsetTests.RecordHook(Sender: TObject;
  const AInfo: TCADSheetViewportDrawInfo;
  const APhase: TCADViewportDrawPhase);
begin
  if APhase = vdpBeforeModel then
    FCalls := FCalls + ['before ' + AInfo.Viewport.Name]
  else
    FCalls := FCalls + ['after ' + AInfo.Viewport.Name];
  FLastInfo := AInfo;
end;

procedure TCADViewportInsetTests.CarelessHook(Sender: TObject;
  const AInfo: TCADSheetViewportDrawInfo;
  const APhase: TCADViewportDrawPhase);
begin
  { Everything a handler should not leave behind. }
  AInfo.Canvas.Graphics.PushClip(Rect(0, 0, 5, 5));
  AInfo.Canvas.Graphics.PushClip(Rect(0, 0, 2, 2));
  AInfo.Canvas.Pen.Width := 17;
end;

function TCADViewportInsetTests.DrawSheetLog: TStringList;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  Result := TStringList.Create;
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 420, 297));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    Result.Assign(TmpRec.Log);
    Assert.AreEqual(0, TmpRec.ClipDepth, 'every clip came back');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADViewportInsetTests.WithoutAnInsetTheContentIsTheRectangle;
var
  TmpContent: TRect2D;
begin
  TmpContent := FViewport.ContentRectMM;
  Assert.AreEqual(10.0, TmpContent.Left, 1E-9);
  Assert.AreEqual(10.0, TmpContent.Bottom, 1E-9);
  Assert.AreEqual(110.0, TmpContent.Right, 1E-9);
  Assert.AreEqual(60.0, TmpContent.Top, 1E-9);
  Assert.AreEqual(3.0, FViewport.EffectiveUnitsPerMM(FCAD), 1E-9,
    'and the fit is the one it always was');
end;

procedure TCADViewportInsetTests.TheContentRectangleIsTheRectangleLessTheInset;
var
  TmpContent: TRect2D;
begin
  { Left 20, top 10, right 5, bottom 2 - the four fields by their own
    names. }
  FViewport.ContentInsetMM := Rect2D(20, 2, 5, 10);
  TmpContent := FViewport.ContentRectMM;
  Assert.AreEqual(30.0, TmpContent.Left, 1E-9, 'left');
  Assert.AreEqual(12.0, TmpContent.Bottom, 1E-9, 'bottom');
  Assert.AreEqual(105.0, TmpContent.Right, 1E-9, 'right');
  Assert.AreEqual(50.0, TmpContent.Top, 1E-9, 'top');
end;

procedure TCADViewportInsetTests.AnInsetLargerThanTheRectangleLeavesNoContent;
var
  TmpContent: TRect2D;
begin
  FViewport.ContentInsetMM := Rect2D(70, 0, 70, 0);
  TmpContent := FViewport.ContentRectMM;
  Assert.AreEqual(0.0, TmpContent.Right - TmpContent.Left, 1E-9,
    'no width, and not a negative one');
  Assert.WillRaise(
    procedure
    begin
      FViewport.EffectiveUnitsPerMM(FCAD);
    end, ECADPageError, 'nothing to fit into');
end;

procedure TCADViewportInsetTests.TheFitIsIntoTheContent;
begin
  FViewport.ContentInsetMM := Rect2D(20, 0, 0, 10);
  { 300 x 150 into 80 x 40: 3.75 either way. }
  Assert.AreEqual(3.75, FViewport.EffectiveUnitsPerMM(FCAD), 1E-9);
end;

procedure TCADViewportInsetTests.PointsMapIntoAndOutOfTheContent;
var
  TmpPt, TmpBack: TPoint2D;
begin
  FViewport.ContentInsetMM := Rect2D(20, 0, 0, 10);
  { The model window fills the content exactly, so its corners are the
    content's corners. }
  TmpPt := FViewport.ModelToPointMM(FCAD, Point2D(0, 0));
  Assert.AreEqual(30.0, TmpPt.X, 1E-6, 'the model origin at the content''s left');
  Assert.AreEqual(10.0, TmpPt.Y, 1E-6, 'and its bottom');
  TmpPt := FViewport.ModelToPointMM(FCAD, Point2D(300, 150));
  Assert.AreEqual(110.0, TmpPt.X, 1E-6, 'the far corner at the right');
  Assert.AreEqual(50.0, TmpPt.Y, 1E-6, 'and under the top inset');
  TmpBack := FViewport.PointMMToModel(FCAD, Point2D(70, 30));
  TmpPt := FViewport.ModelToPointMM(FCAD, TmpBack);
  Assert.AreEqual(70.0, TmpPt.X, 1E-6, 'and back again');
  Assert.AreEqual(30.0, TmpPt.Y, 1E-6);
end;

procedure TCADViewportInsetTests.TheDrawingTransformLandsOnTheContentPixels;
var
  TmpContent: TRect;
  TmpPt: TPoint2D;
begin
  FViewport.ContentInsetMM := Rect2D(20, 0, 0, 10);
  TmpContent := CADSheetViewportContentRectPx(FSheet, FViewport, Device);
  { 297 mm tall: content 30..110 across and 10..50 up is rows 247..287. }
  Assert.AreEqual(30, TmpContent.Left, 'left');
  Assert.AreEqual(247, TmpContent.Top, 'top');
  Assert.AreEqual(110, TmpContent.Right, 'right');
  Assert.AreEqual(287, TmpContent.Bottom, 'bottom');
  TmpPt := CartesianPoint2D(TransformPoint2D(Point2D(0, 150),
    CADSheetViewportTransform(FCAD, FSheet, FViewport, Device)));
  { Within a pixel: the transform is laid out on pixel centres. }
  Assert.AreEqual(30.0, TmpPt.X, 1.0, 'the model''s top-left at the content''s');
  Assert.AreEqual(247.0, TmpPt.Y, 1.0);
end;

procedure TCADViewportInsetTests.TheModelIsNotDrawnInTheInset;
var
  TmpLog: TStringList;
begin
  FViewport.ContentInsetMM := Rect2D(20, 0, 0, 10);
  TmpLog := DrawSheetLog;
  try
    Assert.IsTrue(TmpLog.IndexOf('PushClip 30,247,110,287') >= 0,
      'the model is clipped to the content: ' + TmpLog.Text);
  finally
    TmpLog.Free;
  end;
end;

procedure TCADViewportInsetTests.TheHookIsCalledBeforeAndAfterTheModel;
var
  TmpSecond: TCADSheetViewport;
  TmpLog: TStringList;
begin
  FViewport.Name := 'A';
  TmpSecond := FSheet.AddViewport;
  TmpSecond.Name := 'B';
  TmpSecond.RectMM := Rect2D(150, 10, 250, 60);
  FCAD.OnDrawSheetViewport := RecordHook;
  TmpLog := DrawSheetLog;
  try
    Assert.AreEqual(4, Length(FCalls), 'twice per viewport');
    Assert.AreEqual('before A', FCalls[0]);
    Assert.AreEqual('after A', FCalls[1]);
    Assert.AreEqual('before B', FCalls[2]);
    Assert.AreEqual('after B', FCalls[3]);
  finally
    TmpLog.Free;
  end;
end;

procedure TCADViewportInsetTests.TheHookIsToldWhereTheViewportIs;
var
  TmpLog: TStringList;
begin
  FViewport.ContentInsetMM := Rect2D(20, 0, 0, 10);
  FCAD.OnDrawSheetViewport := RecordHook;
  TmpLog := DrawSheetLog;
  try
    Assert.AreSame(TObject(FViewport), TObject(FLastInfo.Viewport));
    Assert.AreSame(TObject(FSheet), TObject(FLastInfo.Sheet));
    Assert.AreEqual(10, FLastInfo.OuterPx.Left, 'outer left');
    Assert.AreEqual(237, FLastInfo.OuterPx.Top, 'outer top');
    Assert.AreEqual(30, FLastInfo.ContentPx.Left, 'content left');
    Assert.AreEqual(247, FLastInfo.ContentPx.Top, 'content top');
    Assert.AreEqual(300.0, FLastInfo.ModelWindow.Right -
      FLastInfo.ModelWindow.Left, 1E-6, 'the window it shows');
    Assert.AreEqual(1.0, FLastInfo.PixelsPerMM, 1E-6, 'and the device');
  finally
    TmpLog.Free;
  end;
end;

procedure TCADViewportInsetTests.ACarelessHookCannotSpoilTheSheet;
var
  TmpLog: TStringList;
begin
  { DrawSheetLog asserts that the clip depth is back to nothing. }
  FCAD.OnDrawSheetViewport := CarelessHook;
  TmpLog := DrawSheetLog;
  TmpLog.Free;
  Assert.Pass('the two clips the handler left were popped for it');
end;

procedure TCADViewportInsetTests.InsetAndAppDataRoundTrip;
var
  TmpBack: TFNCCADCmp2D;
  TmpPort: TCADSheetViewport;
begin
  FViewport.ContentInsetMM := Rect2D(20, 2, 5, 10);
  FViewport.AppData := '{"lanes":[3,9],"from":"2026-01-01"}';
  FSheet.AppData := '{"series":"A","number":2}';
  TmpBack := TFNCCADCmp2D.Create(nil);
  try
    TmpBack.LoadFromJSONString(FCAD.SaveToJSONString);
    TmpPort := TmpBack.Sheets[0].Viewports[0];
    Assert.AreEqual(20.0, TmpPort.ContentInsetMM.Left, 1E-9, 'left');
    Assert.AreEqual(10.0, TmpPort.ContentInsetMM.Top, 1E-9, 'top');
    Assert.AreEqual(5.0, TmpPort.ContentInsetMM.Right, 1E-9, 'right');
    Assert.AreEqual(2.0, TmpPort.ContentInsetMM.Bottom, 1E-9, 'bottom');
    Assert.AreEqual('{"lanes":[3,9],"from":"2026-01-01"}', TmpPort.AppData,
      'the viewport''s data, untouched');
    Assert.AreEqual('{"series":"A","number":2}', TmpBack.Sheets[0].AppData,
      'and the sheet''s');
  finally
    TmpBack.Free;
  end;
end;

procedure TCADViewportInsetTests.NothingNewIsWrittenWhenNothingIsSet;
var
  TmpText: string;
begin
  TmpText := FCAD.SaveToJSONString;
  Assert.IsFalse(TmpText.Contains('contentInset'), 'no inset member');
  Assert.IsFalse(TmpText.Contains('appData'), 'no data member');
end;

procedure TCADViewportInsetTests.AssignCopiesInsetAndAppData;
var
  TmpCopy: TCADSheetViewport;
begin
  FViewport.ContentInsetMM := Rect2D(1, 2, 3, 4);
  FViewport.AppData := 'mine';
  TmpCopy := TCADSheetViewport.Create;
  try
    TmpCopy.Assign(FViewport);
    Assert.AreEqual(1.0, TmpCopy.ContentInsetMM.Left, 1E-9);
    Assert.AreEqual(4.0, TmpCopy.ContentInsetMM.Top, 1E-9);
    Assert.AreEqual('mine', TmpCopy.AppData);
  finally
    TmpCopy.Free;
  end;
end;

{ ==================================================================
  TCADSheetTilingTests
  ================================================================== }

function TCADSheetTilingTests.Device: TCADPageDevice;
begin
  Result := TCADPageDevice.FromPixelsPerMM(1);
end;

procedure TCADSheetTilingTests.Setup;
begin
  FCAD := TFNCCADCmp2D.Create(nil);
  FSheet := FCAD.Sheets.Add('Overview');
  FSheet.Paper := pkA1;
  FSheet.Orientation := pgoLandscape;
  { A line on the sheet, at 200 and 500 mm from its bottom-left corner. }
  FSheet.AddObject(TLine2D.Create(-1, Point2D(200, 500), Point2D(300, 500)));
end;

procedure TCADSheetTilingTests.TearDown;
begin
  FCAD.Free;
end;

function TCADSheetTilingTests.DrawTile(const ATiling: TCADSheetTiling;
  const AIndex: Integer): string;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 2000, 2000));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheetTile(FCAD, FSheet, ATiling, Device, AIndex, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    Result := TmpRec.Log.Text;
  finally
    TmpRec.Free;
  end;
end;

function TCADSheetTilingTests.TextOf(const ALog: string): string;
var
  TmpList: TStringList;
  I: Integer;
begin
  Result := '';
  TmpList := TStringList.Create;
  try
    TmpList.Text := ALog;
    for I := 0 to TmpList.Count - 1 do
      if TmpList[I].StartsWith('DrawText ') then
        Result := Result + TmpList[I].Substring(9);
  finally
    TmpList.Free;
  end;
end;

procedure TCADSheetTilingTests.AnA1SheetOnA4TakesFiveByThree;
var
  TmpAcross, TmpDown: Integer;
  TmpWin: TRect2D;
begin
  CADSheetTileCount(FSheet, TCADSheetTiling.Default, Device, TmpAcross,
    TmpDown);
  Assert.AreEqual(5, TmpAcross, 'across');
  Assert.AreEqual(3, TmpDown, 'down');
  { Tile 0 is the top left, 190 x 277 of it. }
  TmpWin := CADSheetTileWindow(FSheet, TCADSheetTiling.Default, Device, 0);
  Assert.AreEqual(0.0, Double(TmpWin.Left), 1E-6, 'left');
  Assert.AreEqual(594.0, Double(TmpWin.Top), 1E-6, 'top');
  Assert.AreEqual(190.0, Double(TmpWin.Right), 1E-6, 'right');
  Assert.AreEqual(594.0 - 277.0, Double(TmpWin.Bottom), 1E-6, 'bottom');
end;

procedure TCADSheetTilingTests.TheTilesOverlapByTheOverlapAndCoverTheSheet;
var
  TmpAcross, TmpDown, I: Integer;
  TmpA, TmpB: TRect2D;
begin
  CADSheetTileCount(FSheet, TCADSheetTiling.Default, Device, TmpAcross,
    TmpDown);
  for I := 0 to TmpAcross - 2 do
  begin
    TmpA := CADSheetTileWindow(FSheet, TCADSheetTiling.Default, Device, I);
    TmpB := CADSheetTileWindow(FSheet, TCADSheetTiling.Default, Device, I + 1);
    Assert.AreEqual(10.0, Double(TmpA.Right - TmpB.Left), 1E-6,
      Format('across, tile %d', [I]));
  end;
  for I := 0 to TmpDown - 2 do
  begin
    TmpA := CADSheetTileWindow(FSheet, TCADSheetTiling.Default, Device,
      I * TmpAcross);
    TmpB := CADSheetTileWindow(FSheet, TCADSheetTiling.Default, Device,
      (I + 1) * TmpAcross);
    Assert.AreEqual(10.0, Double(TmpB.Top - TmpA.Bottom), 1E-6,
      Format('down, row %d', [I]));
  end;
  { The last one reaches the far corner, and no further. }
  TmpA := CADSheetTileWindow(FSheet, TCADSheetTiling.Default, Device,
    TmpAcross * TmpDown - 1);
  Assert.AreEqual(841.0, Double(TmpA.Right), 1E-6, 'the sheet''s right edge');
  Assert.AreEqual(0.0, Double(TmpA.Bottom), 1E-6, 'the sheet''s bottom edge');
  Assert.WillRaise(
    procedure
    begin
      CADSheetTileWindow(FSheet, TCADSheetTiling.Default, Device,
        TmpAcross * TmpDown);
    end, ECADPageError, 'no tile past the last');
end;

procedure TCADSheetTilingTests.AnA4SheetOnA4IsAnOrdinaryPrint;
var
  TmpAcross, TmpDown: Integer;
  TmpLog: string;
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  FSheet.Paper := pkA4;
  FSheet.Orientation := pgoPortrait;
  CADSheetTileCount(FSheet, TCADSheetTiling.Default, Device, TmpAcross,
    TmpDown);
  Assert.AreEqual(1, TmpAcross * TmpDown, 'one page');
  TmpLog := DrawTile(TCADSheetTiling.Default, 0);
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 2000, 2000));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    Assert.AreEqual(TmpRec.Log.Text, TmpLog, 'the same as drawing the sheet');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetTilingTests.TheSheetLandsInThePrintableArea;
var
  TmpTiling: TCADSheetTiling;
  TmpLog: string;
  TmpList: TStringList;
  I, TmpX, TmpY: Integer;
  TmpParts: TArray<string>;
begin
  TmpTiling := TCADSheetTiling.Default;
  TmpTiling.Marks := False;
  { The second tile starts 180 mm along the sheet. }
  TmpLog := DrawTile(TmpTiling, 1);
  Assert.IsTrue(TmpLog.StartsWith('PushClip 10,10,200,287'),
    'clipped to the printable area: ' + TmpLog);
  TmpList := TStringList.Create;
  try
    TmpList.Text := TmpLog;
    TmpX := -1;
    TmpY := -1;
    for I := 0 to TmpList.Count - 1 do
      if TmpList[I].StartsWith('MoveTo ') then
      begin
        TmpParts := TmpList[I].Substring(7).Split([',']);
        TmpX := StrToInt(TmpParts[0]);
        TmpY := StrToInt(TmpParts[1]);
        Break;
      end;
  finally
    TmpList.Free;
  end;
  { 200 mm on the sheet, 180 of them on the tile before: 20 in from a
    margin of 10. 500 up a sheet of 594: 94 down from a margin of 10. }
  Assert.IsTrue(Abs(TmpX - 30) <= 1, Format('X is %d', [TmpX]));
  Assert.IsTrue(Abs(TmpY - 104) <= 1, Format('Y is %d', [TmpY]));
end;

procedure TCADSheetTilingTests.TheNameSaysWhichTileOfWhichSheet;
var
  TmpText: string;
begin
  TmpText := TextOf(DrawTile(TCADSheetTiling.Default, 0));
  Assert.IsTrue(TmpText.StartsWith('A1 '), 'the first: ' + TmpText);
  Assert.IsTrue(TmpText.Contains('A1 - E3'), 'the grid: ' + TmpText);
  Assert.IsTrue(TmpText.Contains('Overview'), 'the sheet: ' + TmpText);
  { Second column, second row, with five to a row. }
  TmpText := TextOf(DrawTile(TCADSheetTiling.Default, 6));
  Assert.IsTrue(TmpText.StartsWith('B2 '), 'a middle one: ' + TmpText);
  TmpText := TextOf(DrawTile(TCADSheetTiling.Default, 14));
  Assert.IsTrue(TmpText.StartsWith('E3 '), 'the last: ' + TmpText);
end;

procedure TCADSheetTilingTests.MarksComeOnlyOnTheSidesWithANeighbour;

  { A dash of the cut line down the page, at this X: 190 for a page that
    is 190 wide less 10 of overlap, from a margin of 10. }
  function HasCutDown(const ALog: string): Boolean;
  begin
    Result := ALog.Contains('MoveTo 190,10' + sLineBreak + 'LineTo 190,13');
  end;

  function HasCutAcross(const ALog: string): Boolean;
  begin
    Result := ALog.Contains('MoveTo 10,277' + sLineBreak + 'LineTo 13,277');
  end;

var
  TmpLog: string;
begin
  TmpLog := DrawTile(TCADSheetTiling.Default, 0);
  Assert.IsTrue(HasCutDown(TmpLog), 'tile 0, down its right: ' + TmpLog);
  Assert.IsTrue(HasCutAcross(TmpLog), 'tile 0, across its bottom: ' + TmpLog);
  { The last tile has nothing to go under. }
  TmpLog := DrawTile(TCADSheetTiling.Default, 14);
  Assert.IsFalse(HasCutDown(TmpLog), 'tile 14, right');
  Assert.IsFalse(HasCutAcross(TmpLog), 'tile 14, bottom');
  { But it does have the crosses of the ones it goes over. }
  Assert.IsTrue(TmpLog.Contains('MoveTo 8,10'), 'a cross in its corner');
end;

procedure TCADSheetTilingTests.MarksAreOnThePageAndNotOnTheSheet;
var
  TmpRec: TRecordingGraphics;
  TmpCanvas: TDecorativeCanvas;
begin
  TmpRec := TRecordingGraphics.Create(Rect(0, 0, 2000, 2000));
  try
    TmpCanvas := TDecorativeCanvas.Create(TmpRec, False);
    try
      CADDrawSheet(FCAD, FSheet, Device, TmpCanvas);
    finally
      TmpCanvas.Free;
    end;
    Assert.AreEqual(0, TmpRec.CountOf('DrawText'), 'no name on the sheet');
    Assert.AreEqual(1, TmpRec.CountOf('MoveTo'), 'only its own line');
  finally
    TmpRec.Free;
  end;
end;

procedure TCADSheetTilingTests.MarksCanBeLeftOff;
var
  TmpTiling: TCADSheetTiling;
begin
  TmpTiling := TCADSheetTiling.Default;
  TmpTiling.Marks := False;
  Assert.AreEqual('', TextOf(DrawTile(TmpTiling, 0)), 'no name');
end;

procedure TCADSheetTilingTests.APrintersEdgeRaisesTheMargins;
var
  TmpDevice: TCADPageDevice;
  TmpTiling: TCADSheetTiling;
  TmpWin: TRect2D;
begin
  TmpDevice := Device;
  { A printer whose canvas starts 15 mm in, more than the margin. }
  TmpDevice.OffsetXPx := -15;
  TmpDevice.OffsetYPx := -15;
  TmpTiling := TCADSheetTiling.Default;
  TmpWin := CADSheetTileWindow(FSheet, TmpTiling, TmpDevice, 0);
  Assert.AreEqual(180.0, Double(TmpWin.Right - TmpWin.Left), 1E-6, 'width');
  Assert.AreEqual(267.0, Double(TmpWin.Top - TmpWin.Bottom), 1E-6, 'height');
end;

procedure TCADSheetTilingTests.AnOverlapLargerThanThePageIsRefused;
var
  TmpTiling: TCADSheetTiling;
  TmpAcross, TmpDown: Integer;
begin
  TmpTiling := TCADSheetTiling.Default;
  TmpTiling.OverlapMM := 200;
  Assert.WillRaise(
    procedure
    begin
      CADSheetTileCount(FSheet, TmpTiling, Device, TmpAcross, TmpDown);
    end, ECADPageError, 'nothing would be gained per page');
end;

procedure TCADSheetTilingTests.AWiderAlphabetOfColumnsGoesOnToAA;
var
  TmpTiling: TCADSheetTiling;
  TmpText: string;
begin
  FSheet.Paper := pkCustom;
  FSheet.CustomWidthMM := 6000;
  FSheet.CustomHeightMM := 100;
  FSheet.Orientation := pgoPortrait;
  TmpTiling := TCADSheetTiling.Default;
  { The 27th column, on the first row. }
  TmpText := TextOf(DrawTile(TmpTiling, 26));
  Assert.IsTrue(TmpText.StartsWith('AA1 '), TmpText);
end;

initialization

TDUnitX.RegisterTestFixture(TCADViewportInsetTests);
TDUnitX.RegisterTestFixture(TCADSheetHitTestTests);
TDUnitX.RegisterTestFixture(TCADSheetModelTests);
TDUnitX.RegisterTestFixture(TCADSheetPersistenceTests);
TDUnitX.RegisterTestFixture(TCADSheetEditingTests);
TDUnitX.RegisterTestFixture(TCADSpaceTests);
TDUnitX.RegisterTestFixture(TCADExplodeTests);
TDUnitX.RegisterTestFixture(TCADSheetCustomClassTests);
TDUnitX.RegisterTestFixture(TCADSheetViewportProxyTests);
TDUnitX.RegisterTestFixture(TCADSheetViewportViewTests);
TDUnitX.RegisterTestFixture(TCADNamedViewTests);
TDUnitX.RegisterTestFixture(TCADViewLinkTests);
TDUnitX.RegisterTestFixture(TCADViewFromSelectionTests);
TDUnitX.RegisterTestFixture(TCADSheetDrawingTests);
TDUnitX.RegisterTestFixture(TCADSheetTilingTests);

end.
