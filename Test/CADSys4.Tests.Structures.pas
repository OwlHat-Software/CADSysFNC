{ : DUnitX tests for the core data structures of CADSys 4.2 (unit VCL.FNCCADSys4).

  Scope: TPointsSet2D / TPointsSet3D, TGraphicObjList and its iterators,
  TIndexedObjectList, TLayer / TLayers and TCADPrgParam.

  Nothing here touches a TCanvas, a window handle or a viewport: no Draw*
  method is ever called and no TFNCCADViewport* is ever instantiated.

  Every assertion below was written against the staged sources; the behaviour
  pinned is the behaviour the code actually has, not the behaviour the doc
  comments describe (the two differ in a few places, and those places are
  called out in the test names).
}
unit CADSys4.Tests.Structures;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  Vcl.Graphics,
  DUnitX.TestFramework,
  VCL.FNCCS4BaseTypes,
  VCL.FNCCADSys4,
  VCL.FNCCS4Shapes,
  VCL.FNCCS4Graphics,
  VCL.FNCCadSysRegister;

type
  { : A minimal concrete TGraphicObject.

    TGraphicObject declares one abstract method, _UpdateExtension, so this is
    the smallest possible instantiable descendant. It counts its own
    destructions in a unit-level counter so ownership contracts
    (FreeOnClear, Delete vs Remove) can be asserted directly.

    NOTE: TGraphicObject descends from TInterfacedObject. Instances of this
    class are never assigned to an interface variable, so the reference count
    stays 0 and Free/BeforeDestruction behave normally.
  }
  TSentinelGraphicObject = class(TGraphicObject)
  protected
    procedure _UpdateExtension; override;
  public
    destructor Destroy; override;
  end;

  { : A plain TObject that counts its own destructions. Used for
    TIndexedObjectList and for TCADPrgParam.UserObject.
  }
  TDestructionSentinel = class(TObject)
  public
    destructor Destroy; override;
  end;

  { : One recorded call to TPointsSet2D.Put. }
  TPutCall = record
    PutIndex: Integer;
    ItemIndex: Integer;
  end;

  { : A TPointsSet2D descendant that records every (PutIndex, ItemIndex) pair
    the virtual Put receives, so the shift contract documented around
    VCL.FNCCADSys4.pas:848-860 can be pinned exactly.
  }
  TRecordingPointsSet2D = class(TPointsSet2D)
  private
    fCalls: array of TPutCall;
  protected
    procedure Put(PutIndex, ItemIndex: Word; const Item: TPoint2D); override;
  public
    procedure ResetLog;
    function CallCount: Integer;
    function PutIndexAt(const Idx: Integer): Integer;
    function ItemIndexAt(const Idx: Integer): Integer;
  end;

  { ---------------------------------------------------------------- }

  [TestFixture]
  TPointsSet2DTests = class(TObject)
  private
    FSet: TPointsSet2D;
    FChangeCount: Integer;
    procedure HandleChange(Sender: TObject);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Create_SetsCapacityCountAndDefaults;
    [Test]
    procedure Add_AppendsAndRaisesCount;
    [Test]
    procedure Add_FiresOnChangeOncePerPoint;
    [Test]
    procedure AddPoints_OpenArray_FiresOnChangeOnlyOnce;
    [Test]
    procedure AddPoints_SourceSet_AppendsAndFiresOnce;
    [Test]
    procedure Clear_ResetsCountButKeepsCapacityAndFiresNoEvent;
    [Test]
    procedure DisableEvents_SuppressesOnChange;
    [Test]
    procedure Get_BeyondCount_RaisesECADOutOfBound;
    [Test]
    procedure GrowingDisabled_AddPastCapacity_RaisesECADOutOfBound;
    [Test]
    procedure GrowingEnabled_AddPastCapacity_ExpandsToDoublePlusOne;
    [Test]
    procedure PutProp_BeyondCount_ExtendsCountToIndexPlusOne;
    [Test]
    procedure Extension_OfEmptySet_IsDegenerateAtOrigin;
    [Test]
    procedure Extension_IsBoundingBoxOfPoints;
    [Test]
    procedure TransformPoints_TranslatesAllPointsAndFiresOnce;
    [Test]
    procedure Copy_CopiesRangeAndFiresOnce;
    [Test]
    procedure Copy_PastSourceEnd_SwallowsErrorButStillFiresOnChange;
    [Test]
    procedure PointsReference_IsNotNil;
    [Test]
    procedure AddPointsOpenArray_GuardIsOffByOne_CapacityGrowsAnyway;
    [Test]
    procedure AddPointsOpenArray_WellPastCapacity_RaisesECADOutOfBound;
    [Test]
    procedure AddPointsSourceSet_GrowingDisabledAndTooBig_Raises;
  end;

  { ---------------------------------------------------------------- }

  [TestFixture]
  TPointsSet2DPutContractTests = class(TObject)
  private
    FSet: TRecordingPointsSet2D;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Delete_PutReceivesItemIndexEqualToPutIndexPlusOne;
    [Test]
    procedure Delete_ShiftsPointsDownAndDecrementsCount;
    [Test]
    procedure Delete_OfLastPoint_IssuesNoPutCalls;
    [Test]
    procedure Delete_BeyondCount_RaisesECADOutOfBound;
    [Test]
    procedure Insert_PutSequenceIsAppendThenShiftDownThenStore;
    [Test]
    procedure Insert_ShiftsPointsUpAndIncrementsCount;
    [Test]
    procedure Insert_AtCount_RaisesECADOutOfBound;
    [Test]
    procedure DirectWrite_PutReceivesEqualIndexes;
  end;

  { ---------------------------------------------------------------- }

  [TestFixture]
  TPointsSet3DTests = class(TObject)
  private
    FSet: TPointsSet3D;
    FChangeCount: Integer;
    procedure HandleChange(Sender: TObject);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Create_SetsCapacityCountAndDefaults;
    [Test]
    procedure Add_FiresOnChangeOncePerPoint;
    [Test]
    procedure AddPoints_OpenArray_FiresOnChangeOnlyOnce;
    [Test]
    procedure Extension_IsBoundingBoxOfPoints;
    [Test]
    procedure GrowingEnabled_AddPastCapacity_Expands;
    [Test]
    procedure GrowingDisabled_AddPastCapacity_RaisesECADOutOfBound;
    [Test]
    procedure Delete_ShiftsPointsDown;
    [Test]
    procedure Insert_ShiftsPointsUp;
    [Test]
    procedure TransformPoints_TranslatesAllPoints;
    [Test]
    procedure Copy_PastSourceEnd_SwallowsErrorAndSuppressesOnChange;
  end;

  { ---------------------------------------------------------------- }

  [TestFixture]
  TGraphicObjListTests = class(TObject)
  private
    FList: TGraphicObjList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Create_IsEmptyAndOwnsItsObjects;
    [Test]
    procedure Add_RaisesCount;
    [Test]
    procedure Find_ReturnsObjectWithMatchingID;
    [Test]
    procedure Find_UnknownID_ReturnsNil;
    [Test]
    procedure Delete_FreesObjectWhenFreeOnClear;
    [Test]
    procedure Delete_DoesNotFreeObjectWhenNotFreeOnClear;
    [Test]
    procedure Delete_UnknownID_RaisesECADListObjNotFound;
    [Test]
    procedure Remove_DetachesWithoutFreeing;
    [Test]
    procedure Clear_FreesObjectsWhenFreeOnClear;
    [Test]
    procedure Clear_DoesNotFreeObjectsWhenFreeOnClearIsFalse;
    [Test]
    procedure Destroy_FreesObjectsWhenFreeOnClear;
    [Test]
    procedure Insert_PlacesObjectBeforeTheInsertionPoint;
    [Test]
    procedure Insert_IntoEmptyList_RaisesECADSysException;
    [Test]
    procedure Insert_UnknownInsertionPoint_RaisesECADListObjNotFound;
    [Test]
    procedure AddFromList_AppendsAllObjectsOfTheOtherList;
    [Test]
    procedure Move_ReordersTheList;
    [Test]
    procedure AcceptsRealShapes_TLine2D;
  end;

  { ---------------------------------------------------------------- }

  [TestFixture]
  TGraphicObjIteratorTests = class(TObject)
  private
    FList: TGraphicObjList;
    FA, FB, FC: TSentinelGraphicObject;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure GetIterator_IncrementsIteratorCount_FreeDecrementsIt;
    [Test]
    procedure NewIterator_StartsPositionedOnTheHead;
    [Test]
    procedure ForwardWalk_FirstNextNext_ThenNilAtTheEnd;
    [Test]
    procedure BackwardWalk_LastPrevPrev_ThenNilAtTheStart;
    [Test]
    procedure Iterator_Count_MirrorsListCount;
    [Test]
    procedure Search_MovesCurrentToTheFoundObject;
    [Test]
    procedure Search_UnknownID_ReturnsNilAndLeavesCurrent;
    [Test]
    procedure DefaultProperty_IndexesByIDNotByPosition;
    [Test]
    procedure SourceList_IsTheOriginatingList;
    [Test]
    procedure IteratorOnEmptyList_FirstLastAndNextAreNil;
    [Test]
    procedure TwoPlainIterators_CanCoexist;
    [Test]
    procedure ExclusiveIterator_SetsHasExclusiveIterators;
    [Test]
    procedure ExclusiveIterator_BlocksGetIterator;
    [Test]
    procedure PlainIterator_BlocksGetExclusiveIterator;
    [Test]
    procedure MutatingAListWithAnExclusiveIterator_RaisesECADListBlocked;
    [Test]
    procedure MutatingAListWithAPlainIterator_RaisesECADListBlocked;
    [Test]
    procedure GetPrivilegedIterator_IgnoresPendingIterators;
    [Test]
    procedure RemoveAllIterators_UnblocksTheList;
    [Test]
    procedure DeleteCurrent_FreesTheObjectAndAdvances;
    [Test]
    procedure RemoveCurrent_DetachesWithoutFreeingAndAdvances;
  end;

  { ---------------------------------------------------------------- }

  [TestFixture]
  TIndexedObjectListTests = class(TObject)
  private
    FList: TIndexedObjectList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Create_SetsNumberOfObjectsAndNilsEverySlot;
    [Test]
    procedure Create_DefaultsToFreeOnClear;
    [Test]
    procedure PutAndGet_RoundTrip;
    [Test]
    procedure Get_AtNumberOfObjects_RaisesECADOutOfBound;
    [Test]
    procedure Put_AtNumberOfObjects_RaisesECADOutOfBound;
    [Test]
    procedure Clear_FreesObjectsAndNilsSlotsWhenFreeOnClear;
    [Test]
    procedure Clear_IsANoOpWhenFreeOnClearIsFalse;
    [Test]
    procedure Growing_NumberOfObjects_AddsNilSlots;
    [Test]
    procedure Shrinking_NumberOfObjects_FreesTheDroppedObjects;
  end;

  { ---------------------------------------------------------------- }

  [TestFixture]
  TLayerTests = class(TObject)
  private
    FLayer: TLayer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Create_SetsDocumentedDefaults;
    [Test]
    procedure Create_SetsDefaultPenAndBrush;
    [Test]
    procedure Create_HasADecorativePen;
    [Test]
    procedure ChangingPenColor_SetsModified;
    [Test]
    procedure ChangingPenStyle_SetsModified;
    [Test]
    procedure ChangingBrushColor_SetsModified;
    [Test]
    procedure ChangingName_SetsModified;
    [Test]
    procedure AssigningTheSameName_LeavesModifiedAlone;
    [Test]
    procedure AssigningPen_CopiesTheValuesAndKeepsTheOwnPenInstance;
    [Test]
    procedure AssigningNilPen_IsIgnored;
    [Test]
    procedure AssigningNilBrush_IsIgnored;
    [Test]
    procedure PlainFlags_AreWritableAndDoNotTouchModified;
  end;

  { ---------------------------------------------------------------- }

  [TestFixture]
  TLayersTests = class(TObject)
  private
    FLayers: TLayers;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Create_BuildsTwoHundredFiftySixNamedLayers;
    [Test]
    procedure LayerByName_FindsTheLayer;
    [Test]
    procedure LayerByName_UnknownName_ReturnsNil;
    [Test]
    procedure RestoreLayers_ResetsNamePenBrushFlagsAndModified;
    [Test]
    procedure RestoreLayers_KeepsTheSameBrushInstance;
    [Test]
    procedure RestoreLayers_KeepsBrushModificationTrackingAlive;
    [Test]
    procedure RestoreLayers_KeepsPenModificationTrackingAlive;
    [Test]
    procedure Reset_GivesTheDefaultsBackAndClearsModified;
    [Test]
    procedure Reset_LeavesTheLayerOutOfTheJSONAgain;
    [Test]
    procedure Reset_KeepsThePenAndBrushAndTheirTracking;
    [Test]
    procedure Reset_LeavesTheOtherLayersAlone;
  end;

  { ---------------------------------------------------------------- }

  { : Containers built from an open array of objects. }
  [TestFixture]
  TContainer2DTests = class(TObject)
  public
    [Test]
    procedure CreatedFromAnEmptyArray_IsEmpty;
    [Test]
    procedure CreatedFromObjects_HoldsThem;
  end;

  { ---------------------------------------------------------------- }

  [TestFixture]
  TCADPrgParamTests = class(TObject)
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Create_StoresAfterStateAndLeavesUserObjectNil;
    [Test]
    procedure Create_WithNilAfterState;
    [Test]
    procedure AfterState_IsWritable;
    [Test]
    procedure Destroy_FreesTheUserObject;
    [Test]
    procedure Destroy_WithNoUserObject_IsHarmless;
    [Test]
    procedure DetachingUserObject_TransfersOwnershipBackToTheCaller;
  end;

implementation

var
  { Number of TSentinelGraphicObject instances destroyed so far. }
  GDestroyedGraphicObjects: Integer = 0;
  { Number of TDestructionSentinel instances destroyed so far. }
  GDestroyedSentinels: Integer = 0;

  { ================================================================== }
  { TSentinelGraphicObject }
  { ================================================================== }

procedure TSentinelGraphicObject._UpdateExtension;
begin
  { Nothing to update: this object has no geometry. }
end;

destructor TSentinelGraphicObject.Destroy;
begin
  Inc(GDestroyedGraphicObjects);
  inherited;
end;

{ ================================================================== }
{ TDestructionSentinel }
{ ================================================================== }

destructor TDestructionSentinel.Destroy;
begin
  Inc(GDestroyedSentinels);
  inherited;
end;

{ ================================================================== }
{ TRecordingPointsSet2D }
{ ================================================================== }

procedure TRecordingPointsSet2D.Put(PutIndex, ItemIndex: Word;
  const Item: TPoint2D);
var
  L: Integer;
begin
  L := Length(fCalls);
  SetLength(fCalls, L + 1);
  fCalls[L].PutIndex := PutIndex;
  fCalls[L].ItemIndex := ItemIndex;
  inherited Put(PutIndex, ItemIndex, Item);
end;

procedure TRecordingPointsSet2D.ResetLog;
begin
  SetLength(fCalls, 0);
end;

function TRecordingPointsSet2D.CallCount: Integer;
begin
  Result := Length(fCalls);
end;

function TRecordingPointsSet2D.PutIndexAt(const Idx: Integer): Integer;
begin
  Result := fCalls[Idx].PutIndex;
end;

function TRecordingPointsSet2D.ItemIndexAt(const Idx: Integer): Integer;
begin
  Result := fCalls[Idx].ItemIndex;
end;

{ ================================================================== }
{ TPointsSet2DTests }
{ ================================================================== }

procedure TPointsSet2DTests.HandleChange(Sender: TObject);
begin
  Inc(FChangeCount);
end;

procedure TPointsSet2DTests.Setup;
begin
  FChangeCount := 0;
  FSet := TPointsSet2D.Create(4);
end;

procedure TPointsSet2DTests.TearDown;
begin
  FSet.Free;
  FSet := nil;
end;

procedure TPointsSet2DTests.Create_SetsCapacityCountAndDefaults;
begin
  Assert.AreEqual(4, Integer(FSet.Capacity), 'Capacity');
  Assert.AreEqual(0, Integer(FSet.Count), 'Count');
  Assert.IsTrue(FSet.GrowingEnabled, 'GrowingEnabled defaults to True');
  Assert.IsFalse(FSet.DisableEvents, 'DisableEvents defaults to False');
  Assert.AreEqual(0, FSet.Tag, 'Tag');
end;

procedure TPointsSet2DTests.Add_AppendsAndRaisesCount;
begin
  FSet.Add(Point2D(1.0, 2.0));
  FSet.Add(Point2D(3.0, 4.0));
  Assert.AreEqual(2, Integer(FSet.Count), 'Count');
  Assert.AreEqual(1.0, FSet[0].X, 1E-9);
  Assert.AreEqual(2.0, FSet[0].Y, 1E-9);
  Assert.AreEqual(3.0, FSet[1].X, 1E-9);
  Assert.AreEqual(4.0, FSet[1].Y, 1E-9);
  { Point2D always sets the homogeneous coordinate to 1. }
  Assert.AreEqual(1.0, FSet[1].W, 1E-9);
end;

procedure TPointsSet2DTests.Add_FiresOnChangeOncePerPoint;
begin
  FSet.OnChange := HandleChange;
  FSet.Add(Point2D(0.0, 0.0));
  FSet.Add(Point2D(1.0, 0.0));
  FSet.Add(Point2D(2.0, 0.0));
  Assert.AreEqual(3, FChangeCount, 'Add fires OnChange for every single point');
end;

procedure TPointsSet2DTests.AddPoints_OpenArray_FiresOnChangeOnlyOnce;
begin
  FSet.OnChange := HandleChange;
  FSet.AddPoints([Point2D(0.0, 0.0), Point2D(1.0, 0.0), Point2D(2.0, 0.0)]);
  Assert.AreEqual(3, Integer(FSet.Count), 'Count');
  Assert.AreEqual(1, FChangeCount, 'AddPoints batches into a single OnChange');
end;

procedure TPointsSet2DTests.AddPoints_SourceSet_AppendsAndFiresOnce;
var
  Src: TPointsSet2D;
begin
  Src := TPointsSet2D.Create(2);
  try
    Src.Add(Point2D(5.0, 6.0));
    Src.Add(Point2D(7.0, 8.0));
    FSet.Add(Point2D(1.0, 1.0));
    FSet.OnChange := HandleChange;
    FSet.AddPoints(Src);
    Assert.AreEqual(3, Integer(FSet.Count), 'Count');
    Assert.AreEqual(5.0, FSet[1].X, 1E-9);
    Assert.AreEqual(7.0, FSet[2].X, 1E-9);
    Assert.AreEqual(1, FChangeCount, 'One OnChange for the whole batch');
  finally
    Src.Free;
  end;
end;

procedure TPointsSet2DTests.Clear_ResetsCountButKeepsCapacityAndFiresNoEvent;
begin
  FSet.Add(Point2D(1.0, 1.0));
  FSet.Add(Point2D(2.0, 2.0));
  FSet.OnChange := HandleChange;
  FSet.Clear;
  Assert.AreEqual(0, Integer(FSet.Count), 'Count is reset');
  Assert.AreEqual(4, Integer(FSet.Capacity), 'Capacity (memory) is kept');
  Assert.AreEqual(0, FChangeCount, 'Clear does not fire OnChange');
end;

procedure TPointsSet2DTests.DisableEvents_SuppressesOnChange;
begin
  FSet.OnChange := HandleChange;
  FSet.DisableEvents := True;
  FSet.Add(Point2D(1.0, 1.0));
  FSet.Add(Point2D(2.0, 2.0));
  Assert.AreEqual(0, FChangeCount, 'No event while disabled');
  Assert.IsTrue(FSet.DisableEvents, 'The flag stays set');
  FSet.DisableEvents := False;
  FSet.Add(Point2D(3.0, 3.0));
  Assert.AreEqual(1, FChangeCount, 'Events resume once re-enabled');
end;

procedure TPointsSet2DTests.Get_BeyondCount_RaisesECADOutOfBound;
begin
  FSet.Add(Point2D(1.0, 1.0));
  Assert.WillRaise(
    procedure
    var
      P: TPoint2D;
    begin
      P := FSet[1];
    end, ECADOutOfBound, 'Reading at Count must raise');
end;

procedure TPointsSet2DTests.GrowingDisabled_AddPastCapacity_RaisesECADOutOfBound;
var
  Small: TPointsSet2D;
begin
  Small := TPointsSet2D.Create(2);
  try
    Small.GrowingEnabled := False;
    Small.Add(Point2D(1.0, 1.0));
    Small.Add(Point2D(2.0, 2.0));
    Assert.AreEqual(2, Integer(Small.Count), 'Filled to capacity');
    Assert.WillRaise(
      procedure
      begin
        Small.Add(Point2D(3.0, 3.0));
      end, ECADOutOfBound, 'Third Add must raise');
    Assert.AreEqual(2, Integer(Small.Count), 'Count unchanged after the raise');
  finally
    Small.Free;
  end;
end;

procedure TPointsSet2DTests.GrowingEnabled_AddPastCapacity_ExpandsToDoublePlusOne;
var
  Small: TPointsSet2D;
begin
  Small := TPointsSet2D.Create(2);
  try
    Small.Add(Point2D(1.0, 1.0));
    Small.Add(Point2D(2.0, 2.0));
    Small.Add(Point2D(3.0, 3.0));
    Assert.AreEqual(3, Integer(Small.Count), 'Count');
    { Put grows to MaxIntValue([PutIndex + 1, Capacity * 2 + 1]) = Max(3, 5). }
    Assert.AreEqual(5, Integer(Small.Capacity), 'Capacity * 2 + 1');
    Assert.AreEqual(3.0, Small[2].X, 1E-9);
  finally
    Small.Free;
  end;
end;

procedure TPointsSet2DTests.PutProp_BeyondCount_ExtendsCountToIndexPlusOne;
begin
  FSet.Add(Point2D(1.0, 1.0));
  Assert.AreEqual(1, Integer(FSet.Count), 'Precondition');
  { Capacity is 4, so index 3 is inside the buffer: Put stores it and pushes
    Count out to PutIndex + 1, leaving the hole at index 1..2 unwritten. }
  FSet[3] := Point2D(9.0, 9.0);
  Assert.AreEqual(4, Integer(FSet.Count), 'Count is pushed to Index + 1');
  Assert.AreEqual(9.0, FSet[3].X, 1E-9);
end;

procedure TPointsSet2DTests.Extension_OfEmptySet_IsDegenerateAtOrigin;
var
  R: TRect2D;
begin
  R := FSet.Extension;
  Assert.AreEqual(0.0, R.Left, 1E-9, 'Left');
  Assert.AreEqual(0.0, R.Bottom, 1E-9, 'Bottom');
  Assert.AreEqual(0.0, R.Right, 1E-9, 'Right');
  Assert.AreEqual(0.0, R.Top, 1E-9, 'Top');
end;

procedure TPointsSet2DTests.Extension_IsBoundingBoxOfPoints;
var
  R: TRect2D;
begin
  FSet.AddPoints([Point2D(0.0, 0.0), Point2D(10.0, 5.0), Point2D(-3.0, 7.0)]);
  R := FSet.Extension;
  Assert.AreEqual(-3.0, R.Left, 1E-9, 'Left');
  Assert.AreEqual(0.0, R.Bottom, 1E-9, 'Bottom');
  Assert.AreEqual(10.0, R.Right, 1E-9, 'Right');
  Assert.AreEqual(7.0, R.Top, 1E-9, 'Top');
end;

procedure TPointsSet2DTests.TransformPoints_TranslatesAllPointsAndFiresOnce;
begin
  FSet.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0)]);
  FSet.OnChange := HandleChange;
  FSet.TransformPoints(Translate2D(10.0, 20.0));
  Assert.AreEqual(11.0, FSet[0].X, 1E-6);
  Assert.AreEqual(21.0, FSet[0].Y, 1E-6);
  Assert.AreEqual(12.0, FSet[1].X, 1E-6);
  Assert.AreEqual(22.0, FSet[1].Y, 1E-6);
  Assert.AreEqual(1, FChangeCount, 'One OnChange for the whole transform');
end;

procedure TPointsSet2DTests.Copy_CopiesRangeAndFiresOnce;
var
  Src: TPointsSet2D;
  Dst: TPointsSet2D;
begin
  Src := TPointsSet2D.Create(4);
  Dst := TPointsSet2D.Create(1);
  try
    Src.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0), Point2D(3.0, 3.0)]);
    Dst.OnChange := HandleChange;
    Dst.Copy(Src, 0, 2);
    Assert.AreEqual(3, Integer(Dst.Count), 'Count');
    Assert.AreEqual(1.0, Dst[0].X, 1E-9);
    Assert.AreEqual(2.0, Dst[1].X, 1E-9);
    Assert.AreEqual(3.0, Dst[2].X, 1E-9);
    Assert.AreEqual(1, FChangeCount, 'One OnChange for the whole copy');
  finally
    Dst.Free;
    Src.Free;
  end;
end;

procedure TPointsSet2DTests.Copy_PastSourceEnd_SwallowsErrorButStillFiresOnChange;
var
  Src: TPointsSet2D;
  Dst: TPointsSet2D;
begin
  Src := TPointsSet2D.Create(4);
  Dst := TPointsSet2D.Create(1);
  try
    Src.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0), Point2D(3.0, 3.0)]);
    Dst.OnChange := HandleChange;
    { EndIdx 4 walks off the end of Src; TPointsSet2D.Copy wraps the whole
      loop in a bare try..except, so nothing escapes and the points that did
      fit are kept. CallOnChange sits AFTER the except block, so it still runs. }
    Dst.Copy(Src, 0, 4);
    Assert.AreEqual(3, Integer(Dst.Count), 'Only the available points landed');
    Assert.AreEqual(3.0, Dst[2].X, 1E-9);
    Assert.AreEqual(1, FChangeCount, 'OnChange still fires after the swallow');
  finally
    Dst.Free;
    Src.Free;
  end;
end;

procedure TPointsSet2DTests.PointsReference_IsNotNil;
begin
  Assert.IsTrue(FSet.PointsReference <> nil,
    'The buffer is allocated by the constructor');
end;

procedure TPointsSet2DTests.AddPointsOpenArray_GuardIsOffByOne_CapacityGrowsAnyway;
var
  Small: TPointsSet2D;
begin
  Small := TPointsSet2D.Create(3);
  try
    Small.GrowingEnabled := False;
    { The guard compares Count + High(Items) - Low(Items) (i.e. N - 1) against
      Capacity, so four points into a capacity-3 set slips past it, and the
      unconditional Expand() that follows grows the buffer regardless of
      GrowingEnabled. Pinned as-is. }
    Small.AddPoints([Point2D(1.0, 0.0), Point2D(2.0, 0.0), Point2D(3.0, 0.0),
      Point2D(4.0, 0.0)]);
    Assert.AreEqual(4, Integer(Small.Count), 'Count');
    Assert.AreEqual(4, Integer(Small.Capacity),
      'Expand() bypasses the GrowingEnabled flag');
    Assert.AreEqual(4.0, Small[3].X, 1E-9);
  finally
    Small.Free;
  end;
end;

procedure TPointsSet2DTests.AddPointsOpenArray_WellPastCapacity_RaisesECADOutOfBound;
var
  Small: TPointsSet2D;
begin
  Small := TPointsSet2D.Create(3);
  try
    Small.GrowingEnabled := False;
    Assert.WillRaise(
      procedure
      begin
        Small.AddPoints([Point2D(1.0, 0.0), Point2D(2.0, 0.0),
          Point2D(3.0, 0.0), Point2D(4.0, 0.0), Point2D(5.0, 0.0)]);
      end, ECADOutOfBound, 'Five points into a capacity-3 set must raise');
    Assert.AreEqual(0, Integer(Small.Count), 'Nothing was added');
  finally
    Small.Free;
  end;
end;

procedure TPointsSet2DTests.AddPointsSourceSet_GrowingDisabledAndTooBig_Raises;
var
  Small, Src: TPointsSet2D;
begin
  Small := TPointsSet2D.Create(2);
  Src := TPointsSet2D.Create(3);
  try
    Src.AddPoints([Point2D(1.0, 0.0), Point2D(2.0, 0.0), Point2D(3.0, 0.0)]);
    Small.GrowingEnabled := False;
    { This overload's guard is the exact one: Count + SourceSet.Count > Capacity. }
    Assert.WillRaise(
      procedure
      begin
        Small.AddPoints(Src);
      end, ECADOutOfBound);
    Assert.AreEqual(0, Integer(Small.Count), 'Nothing was added');
  finally
    Src.Free;
    Small.Free;
  end;
end;

{ ================================================================== }
{ TPointsSet2DPutContractTests }
{ ================================================================== }

procedure TPointsSet2DPutContractTests.Setup;
begin
  FSet := TRecordingPointsSet2D.Create(4);
end;

procedure TPointsSet2DPutContractTests.TearDown;
begin
  FSet.Free;
  FSet := nil;
end;

procedure TPointsSet2DPutContractTests.Delete_PutReceivesItemIndexEqualToPutIndexPlusOne;
begin
  FSet.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0), Point2D(3.0, 3.0),
    Point2D(4.0, 4.0)]);
  FSet.ResetLog;

  FSet.Delete(1);

  { Delete shifts every later point down by one, issuing Count - 1 - Index
    Put calls, each of them with ItemIndex = PutIndex + 1. }
  Assert.AreEqual(2, FSet.CallCount, 'Number of Put calls');
  Assert.AreEqual(1, FSet.PutIndexAt(0), 'call 0 PutIndex');
  Assert.AreEqual(2, FSet.ItemIndexAt(0), 'call 0 ItemIndex');
  Assert.AreEqual(2, FSet.PutIndexAt(1), 'call 1 PutIndex');
  Assert.AreEqual(3, FSet.ItemIndexAt(1), 'call 1 ItemIndex');
end;

procedure TPointsSet2DPutContractTests.Delete_ShiftsPointsDownAndDecrementsCount;
begin
  FSet.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0), Point2D(3.0, 3.0),
    Point2D(4.0, 4.0)]);
  FSet.Delete(1);
  Assert.AreEqual(3, Integer(FSet.Count), 'Count');
  Assert.AreEqual(1.0, FSet[0].X, 1E-9);
  Assert.AreEqual(3.0, FSet[1].X, 1E-9);
  Assert.AreEqual(4.0, FSet[2].X, 1E-9);
end;

procedure TPointsSet2DPutContractTests.Delete_OfLastPoint_IssuesNoPutCalls;
begin
  FSet.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0), Point2D(3.0, 3.0)]);
  FSet.ResetLog;
  FSet.Delete(2);
  Assert.AreEqual(0, FSet.CallCount, 'Nothing to shift');
  Assert.AreEqual(2, Integer(FSet.Count), 'Count');
end;

procedure TPointsSet2DPutContractTests.Delete_BeyondCount_RaisesECADOutOfBound;
begin
  FSet.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0)]);
  Assert.WillRaise(
    procedure
    begin
      FSet.Delete(2);
    end, ECADOutOfBound, 'Delete at Count must raise');
  Assert.AreEqual(2, Integer(FSet.Count), 'Count unchanged');
end;

procedure TPointsSet2DPutContractTests.Insert_PutSequenceIsAppendThenShiftDownThenStore;
begin
  FSet.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0), Point2D(3.0, 3.0)]);
  FSet.ResetLog;

  FSet.Insert(1, Point2D(9.0, 9.0));

  { Insert first appends the new item at Count (which bumps Count), then walks
    backwards shifting each point up by one with ItemIndex = PutIndex - 1, and
    finally stores the item at Index with ItemIndex = PutIndex. }
  Assert.AreEqual(4, FSet.CallCount, 'Number of Put calls');

  Assert.AreEqual(3, FSet.PutIndexAt(0), 'call 0 PutIndex (append)');
  Assert.AreEqual(3, FSet.ItemIndexAt(0), 'call 0 ItemIndex (append)');

  Assert.AreEqual(3, FSet.PutIndexAt(1), 'call 1 PutIndex (shift up)');
  Assert.AreEqual(2, FSet.ItemIndexAt(1), 'call 1 ItemIndex (shift up)');

  Assert.AreEqual(2, FSet.PutIndexAt(2), 'call 2 PutIndex (shift up)');
  Assert.AreEqual(1, FSet.ItemIndexAt(2), 'call 2 ItemIndex (shift up)');

  Assert.AreEqual(1, FSet.PutIndexAt(3), 'call 3 PutIndex (store)');
  Assert.AreEqual(1, FSet.ItemIndexAt(3), 'call 3 ItemIndex (store)');
end;

procedure TPointsSet2DPutContractTests.Insert_ShiftsPointsUpAndIncrementsCount;
begin
  FSet.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0), Point2D(3.0, 3.0)]);
  FSet.Insert(1, Point2D(9.0, 9.0));
  Assert.AreEqual(4, Integer(FSet.Count), 'Count');
  Assert.AreEqual(1.0, FSet[0].X, 1E-9);
  Assert.AreEqual(9.0, FSet[1].X, 1E-9);
  Assert.AreEqual(2.0, FSet[2].X, 1E-9);
  Assert.AreEqual(3.0, FSet[3].X, 1E-9);
end;

procedure TPointsSet2DPutContractTests.Insert_AtCount_RaisesECADOutOfBound;
begin
  FSet.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0)]);
  { Insert only accepts Index < Count - it cannot be used to append. }
  Assert.WillRaise(
    procedure
    begin
      FSet.Insert(2, Point2D(9.0, 9.0));
    end, ECADOutOfBound);
  Assert.AreEqual(2, Integer(FSet.Count), 'Count unchanged');
end;

procedure TPointsSet2DPutContractTests.DirectWrite_PutReceivesEqualIndexes;
begin
  FSet.AddPoints([Point2D(1.0, 1.0), Point2D(2.0, 2.0)]);
  FSet.ResetLog;
  FSet[0] := Point2D(7.0, 7.0);
  Assert.AreEqual(1, FSet.CallCount, 'One Put call');
  Assert.AreEqual(0, FSet.PutIndexAt(0), 'PutIndex');
  Assert.AreEqual(0, FSet.ItemIndexAt(0), 'ItemIndex equals PutIndex');
  Assert.AreEqual(7.0, FSet[0].X, 1E-9);
end;

{ ================================================================== }
{ TPointsSet3DTests }
{ ================================================================== }

procedure TPointsSet3DTests.HandleChange(Sender: TObject);
begin
  Inc(FChangeCount);
end;

procedure TPointsSet3DTests.Setup;
begin
  FChangeCount := 0;
  FSet := TPointsSet3D.Create(4);
end;

procedure TPointsSet3DTests.TearDown;
begin
  FSet.Free;
  FSet := nil;
end;

procedure TPointsSet3DTests.Create_SetsCapacityCountAndDefaults;
begin
  Assert.AreEqual(4, Integer(FSet.Capacity), 'Capacity');
  Assert.AreEqual(0, Integer(FSet.Count), 'Count');
  Assert.IsTrue(FSet.GrowingEnabled, 'GrowingEnabled defaults to True');
  Assert.IsFalse(FSet.DisableEvents, 'DisableEvents defaults to False');
  Assert.IsTrue(FSet.PointsReference <> nil, 'Buffer allocated');
end;

procedure TPointsSet3DTests.Add_FiresOnChangeOncePerPoint;
begin
  FSet.OnChange := HandleChange;
  FSet.Add(Point3D(1.0, 2.0, 3.0));
  FSet.Add(Point3D(4.0, 5.0, 6.0));
  Assert.AreEqual(2, Integer(FSet.Count), 'Count');
  Assert.AreEqual(2, FChangeCount, 'One event per Add');
  Assert.AreEqual(3.0, FSet[0].Z, 1E-9);
  Assert.AreEqual(1.0, FSet[0].W, 1E-9);
end;

procedure TPointsSet3DTests.AddPoints_OpenArray_FiresOnChangeOnlyOnce;
begin
  FSet.OnChange := HandleChange;
  FSet.AddPoints([Point3D(1.0, 0.0, 0.0), Point3D(2.0, 0.0, 0.0),
    Point3D(3.0, 0.0, 0.0)]);
  Assert.AreEqual(3, Integer(FSet.Count), 'Count');
  Assert.AreEqual(1, FChangeCount, 'Batched into one OnChange');
end;

procedure TPointsSet3DTests.Extension_IsBoundingBoxOfPoints;
var
  R: TRect3D;
begin
  FSet.AddPoints([Point3D(0.0, 0.0, 0.0), Point3D(10.0, 5.0, -2.0),
    Point3D(-3.0, 7.0, 4.0)]);
  R := FSet.Extension;
  Assert.AreEqual(-3.0, R.Left, 1E-9, 'Left');
  Assert.AreEqual(0.0, R.Bottom, 1E-9, 'Bottom');
  Assert.AreEqual(-2.0, R.Front, 1E-9, 'Front');
  Assert.AreEqual(10.0, R.Right, 1E-9, 'Right');
  Assert.AreEqual(7.0, R.Top, 1E-9, 'Top');
  Assert.AreEqual(4.0, R.Back, 1E-9, 'Back');
end;

procedure TPointsSet3DTests.GrowingEnabled_AddPastCapacity_Expands;
var
  Small: TPointsSet3D;
begin
  Small := TPointsSet3D.Create(2);
  try
    Small.Add(Point3D(1.0, 0.0, 0.0));
    Small.Add(Point3D(2.0, 0.0, 0.0));
    Small.Add(Point3D(3.0, 0.0, 0.0));
    Assert.AreEqual(3, Integer(Small.Count), 'Count');
    Assert.AreEqual(5, Integer(Small.Capacity), 'Capacity * 2 + 1');
    Assert.AreEqual(3.0, Small[2].X, 1E-9);
  finally
    Small.Free;
  end;
end;

procedure TPointsSet3DTests.GrowingDisabled_AddPastCapacity_RaisesECADOutOfBound;
var
  Small: TPointsSet3D;
begin
  Small := TPointsSet3D.Create(2);
  try
    Small.GrowingEnabled := False;
    Small.Add(Point3D(1.0, 0.0, 0.0));
    Small.Add(Point3D(2.0, 0.0, 0.0));
    Assert.WillRaise(
      procedure
      begin
        Small.Add(Point3D(3.0, 0.0, 0.0));
      end, ECADOutOfBound);
    Assert.AreEqual(2, Integer(Small.Count), 'Count unchanged');
  finally
    Small.Free;
  end;
end;

procedure TPointsSet3DTests.Delete_ShiftsPointsDown;
begin
  FSet.AddPoints([Point3D(1.0, 0.0, 0.0), Point3D(2.0, 0.0, 0.0),
    Point3D(3.0, 0.0, 0.0)]);
  FSet.Delete(0);
  Assert.AreEqual(2, Integer(FSet.Count), 'Count');
  Assert.AreEqual(2.0, FSet[0].X, 1E-9);
  Assert.AreEqual(3.0, FSet[1].X, 1E-9);
end;

procedure TPointsSet3DTests.Insert_ShiftsPointsUp;
begin
  FSet.AddPoints([Point3D(1.0, 0.0, 0.0), Point3D(2.0, 0.0, 0.0),
    Point3D(3.0, 0.0, 0.0)]);
  FSet.Insert(1, Point3D(9.0, 0.0, 0.0));
  Assert.AreEqual(4, Integer(FSet.Count), 'Count');
  Assert.AreEqual(1.0, FSet[0].X, 1E-9);
  Assert.AreEqual(9.0, FSet[1].X, 1E-9);
  Assert.AreEqual(2.0, FSet[2].X, 1E-9);
  Assert.AreEqual(3.0, FSet[3].X, 1E-9);
end;

procedure TPointsSet3DTests.TransformPoints_TranslatesAllPoints;
begin
  FSet.AddPoints([Point3D(1.0, 1.0, 1.0), Point3D(2.0, 2.0, 2.0)]);
  FSet.OnChange := HandleChange;
  FSet.TransformPoints(Translate3D(10.0, 20.0, 30.0));
  Assert.AreEqual(11.0, FSet[0].X, 1E-6);
  Assert.AreEqual(21.0, FSet[0].Y, 1E-6);
  Assert.AreEqual(31.0, FSet[0].Z, 1E-6);
  Assert.AreEqual(12.0, FSet[1].X, 1E-6);
  Assert.AreEqual(1, FChangeCount, 'One OnChange for the whole transform');
end;

procedure TPointsSet3DTests.Copy_PastSourceEnd_SwallowsErrorAndSuppressesOnChange;
var
  Src: TPointsSet3D;
  Dst: TPointsSet3D;
begin
  Src := TPointsSet3D.Create(4);
  Dst := TPointsSet3D.Create(1);
  try
    Src.AddPoints([Point3D(1.0, 0.0, 0.0), Point3D(2.0, 0.0, 0.0),
      Point3D(3.0, 0.0, 0.0)]);
    Dst.OnChange := HandleChange;
    { Unlike the 2D version, TPointsSet3D.Copy has CallOnChange INSIDE the
      try..except, so a short source silently skips the notification. }
    Dst.Copy(Src, 0, 4);
    Assert.AreEqual(3, Integer(Dst.Count), 'Only the available points landed');
    Assert.AreEqual(3.0, Dst[2].X, 1E-9);
    Assert.AreEqual(0, FChangeCount,
      '3D Copy suppresses OnChange when the range overruns the source');
  finally
    Dst.Free;
    Src.Free;
  end;
end;

{ ================================================================== }
{ TGraphicObjListTests }
{ ================================================================== }

procedure TGraphicObjListTests.Setup;
begin
  GDestroyedGraphicObjects := 0;
  FList := TGraphicObjList.Create;
end;

procedure TGraphicObjListTests.TearDown;
begin
  FList.Free;
  FList := nil;
end;

procedure TGraphicObjListTests.Create_IsEmptyAndOwnsItsObjects;
begin
  Assert.AreEqual(0, Integer(FList.Count), 'Count');
  Assert.IsTrue(FList.FreeOnClear, 'FreeOnClear defaults to True');
  Assert.IsFalse(FList.HasIterators, 'HasIterators');
  Assert.IsFalse(FList.HasExclusiveIterators, 'HasExclusiveIterators');
end;

procedure TGraphicObjListTests.Add_RaisesCount;
begin
  FList.Add(TSentinelGraphicObject.Create(1));
  FList.Add(TSentinelGraphicObject.Create(2));
  Assert.AreEqual(2, Integer(FList.Count), 'Count');
end;

procedure TGraphicObjListTests.Find_ReturnsObjectWithMatchingID;
var
  B: TSentinelGraphicObject;
begin
  FList.Add(TSentinelGraphicObject.Create(1));
  B := TSentinelGraphicObject.Create(2);
  FList.Add(B);
  FList.Add(TSentinelGraphicObject.Create(3));
  Assert.IsTrue(FList.Find(2) = B, 'Find returns the object with that ID');
end;

procedure TGraphicObjListTests.Find_UnknownID_ReturnsNil;
begin
  FList.Add(TSentinelGraphicObject.Create(1));
  Assert.IsTrue(FList.Find(99) = nil, 'Find returns nil, it does not raise');
end;

procedure TGraphicObjListTests.Delete_FreesObjectWhenFreeOnClear;
begin
  FList.Add(TSentinelGraphicObject.Create(1));
  FList.Add(TSentinelGraphicObject.Create(2));
  Assert.IsTrue(FList.Delete(1), 'Delete returns True');
  Assert.AreEqual(1, Integer(FList.Count), 'Count');
  Assert.AreEqual(1, GDestroyedGraphicObjects, 'The object was freed');
end;

procedure TGraphicObjListTests.Delete_DoesNotFreeObjectWhenNotFreeOnClear;
var
  A: TSentinelGraphicObject;
begin
  A := TSentinelGraphicObject.Create(1);
  FList.Add(A);
  FList.FreeOnClear := False;
  Assert.IsTrue(FList.Delete(1), 'Delete returns True');
  Assert.AreEqual(0, Integer(FList.Count), 'Count');
  Assert.AreEqual(0, GDestroyedGraphicObjects,
    'Delete honours FreeOnClear = False');
  A.Free;
end;

procedure TGraphicObjListTests.Delete_UnknownID_RaisesECADListObjNotFound;
begin
  FList.Add(TSentinelGraphicObject.Create(1));
  Assert.WillRaise(
    procedure
    begin
      FList.Delete(99);
    end, ECADListObjNotFound, 'Delete raises rather than returning False');
  Assert.AreEqual(1, Integer(FList.Count), 'Count unchanged');
end;

procedure TGraphicObjListTests.Remove_DetachesWithoutFreeing;
var
  A: TSentinelGraphicObject;
begin
  A := TSentinelGraphicObject.Create(1);
  FList.Add(A);
  FList.Add(TSentinelGraphicObject.Create(2));
  { Remove is explicitly NOT affected by FreeOnClear, which is True here. }
  Assert.IsTrue(FList.Remove(1), 'Remove returns True');
  Assert.AreEqual(1, Integer(FList.Count), 'Count');
  Assert.AreEqual(0, GDestroyedGraphicObjects, 'Remove never frees');
  A.Free;
end;

procedure TGraphicObjListTests.Clear_FreesObjectsWhenFreeOnClear;
begin
  FList.Add(TSentinelGraphicObject.Create(1));
  FList.Add(TSentinelGraphicObject.Create(2));
  FList.Clear;
  Assert.AreEqual(0, Integer(FList.Count), 'Count');
  Assert.AreEqual(2, GDestroyedGraphicObjects, 'Both objects were freed');
end;

procedure TGraphicObjListTests.Clear_DoesNotFreeObjectsWhenFreeOnClearIsFalse;
var
  A, B: TSentinelGraphicObject;
begin
  A := TSentinelGraphicObject.Create(1);
  B := TSentinelGraphicObject.Create(2);
  FList.Add(A);
  FList.Add(B);
  FList.FreeOnClear := False;
  FList.Clear;
  Assert.AreEqual(0, Integer(FList.Count), 'The list is emptied');
  Assert.AreEqual(0, GDestroyedGraphicObjects,
    'FreeOnClear = False must leave the objects alive');
  { Ownership stayed with us. }
  A.Free;
  B.Free;
  Assert.AreEqual(2, GDestroyedGraphicObjects, 'Freed by the caller');
end;

procedure TGraphicObjListTests.Destroy_FreesObjectsWhenFreeOnClear;
var
  Tmp: TGraphicObjList;
begin
  Tmp := TGraphicObjList.Create;
  Tmp.Add(TSentinelGraphicObject.Create(1));
  Tmp.Add(TSentinelGraphicObject.Create(2));
  Tmp.Free;
  Assert.AreEqual(2, GDestroyedGraphicObjects,
    'The destructor frees the contained objects');
end;

procedure TGraphicObjListTests.Insert_PlacesObjectBeforeTheInsertionPoint;
var
  Iter: TGraphicObjIterator;
  Obj: TGraphicObject;
begin
  FList.Add(TSentinelGraphicObject.Create(1));
  FList.Add(TSentinelGraphicObject.Create(2));
  { Despite the doc comment, the implementation links the new block in
    front of the insertion point. }
  FList.Insert(2, TSentinelGraphicObject.Create(3));
  Assert.AreEqual(3, Integer(FList.Count), 'Count');

  Iter := FList.GetIterator;
  try
    Obj := Iter.First;
    Assert.AreEqual(1, Obj.ID, 'first');
    Obj := Iter.Next;
    Assert.AreEqual(3, Obj.ID, 'second - the inserted one');
    Obj := Iter.Next;
    Assert.AreEqual(2, Obj.ID, 'third - the former insertion point');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjListTests.Insert_IntoEmptyList_RaisesECADSysException;
var
  Orphan: TSentinelGraphicObject;
begin
  Orphan := TSentinelGraphicObject.Create(1);
  try
    Assert.WillRaise(
      procedure
      begin
        FList.Insert(1, Orphan);
      end, ECADSysException, 'Insert guards against an empty list');
  finally
    Orphan.Free;
  end;
end;

procedure TGraphicObjListTests.Insert_UnknownInsertionPoint_RaisesECADListObjNotFound;
var
  Orphan: TSentinelGraphicObject;
begin
  FList.Add(TSentinelGraphicObject.Create(1));
  Orphan := TSentinelGraphicObject.Create(2);
  try
    Assert.WillRaise(
      procedure
      begin
        FList.Insert(99, Orphan);
      end, ECADListObjNotFound);
    Assert.AreEqual(1, Integer(FList.Count), 'Count unchanged');
  finally
    Orphan.Free;
  end;
end;

procedure TGraphicObjListTests.AddFromList_AppendsAllObjectsOfTheOtherList;
var
  Other: TGraphicObjList;
begin
  Other := TGraphicObjList.Create;
  try
    { Other must not own the objects: they end up shared with FList, which
      is the one that frees them in TearDown. }
    Other.FreeOnClear := False;
    Other.Add(TSentinelGraphicObject.Create(10));
    Other.Add(TSentinelGraphicObject.Create(11));

    FList.Add(TSentinelGraphicObject.Create(1));
    FList.AddFromList(Other);

    Assert.AreEqual(3, Integer(FList.Count), 'Count');
    Assert.IsTrue(FList.Find(10) <> nil, 'first imported object');
    Assert.IsTrue(FList.Find(11) <> nil, 'second imported object');
  finally
    Other.Free;
  end;
end;

procedure TGraphicObjListTests.Move_ReordersTheList;
var
  Iter: TGraphicObjIterator;
begin
  FList.Add(TSentinelGraphicObject.Create(1));
  FList.Add(TSentinelGraphicObject.Create(2));
  FList.Add(TSentinelGraphicObject.Create(3));
  { Move object 3 so that it sits immediately before object 1. }
  FList.Move(3, 1);
  Assert.AreEqual(3, Integer(FList.Count), 'Count is unchanged by Move');

  Iter := FList.GetIterator;
  try
    Assert.AreEqual(3, Iter.First.ID, 'first');
    Assert.AreEqual(1, Iter.Next.ID, 'second');
    Assert.AreEqual(2, Iter.Next.ID, 'third');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjListTests.AcceptsRealShapes_TLine2D;
var
  Line: TLine2D;
begin
  Line := TLine2D.Create(7, Point2D(0.0, 0.0), Point2D(10.0, 10.0));
  FList.Add(Line);
  Assert.AreEqual(1, Integer(FList.Count), 'Count');
  Assert.IsTrue(FList.Find(7) = Line, 'The registered shape is found by ID');
  { FList owns it and frees it in TearDown. }
end;

{ ================================================================== }
{ TGraphicObjIteratorTests }
{ ================================================================== }

procedure TGraphicObjIteratorTests.Setup;
begin
  GDestroyedGraphicObjects := 0;
  FList := TGraphicObjList.Create;
  FA := TSentinelGraphicObject.Create(1);
  FB := TSentinelGraphicObject.Create(2);
  FC := TSentinelGraphicObject.Create(3);
  FList.Add(FA);
  FList.Add(FB);
  FList.Add(FC);
end;

procedure TGraphicObjIteratorTests.TearDown;
begin
  FList.Free;
  FList := nil;
end;

procedure TGraphicObjIteratorTests.GetIterator_IncrementsIteratorCount_FreeDecrementsIt;
var
  Iter: TGraphicObjIterator;
begin
  Assert.IsFalse(FList.HasIterators, 'before');
  Iter := FList.GetIterator;
  try
    Assert.IsTrue(FList.HasIterators, 'while alive');
    Assert.IsFalse(FList.HasExclusiveIterators, 'a plain iterator is not exclusive');
  finally
    Iter.Free;
  end;
  Assert.IsFalse(FList.HasIterators, 'after Free');
end;

procedure TGraphicObjIteratorTests.NewIterator_StartsPositionedOnTheHead;
var
  Iter: TGraphicObjIterator;
begin
  Iter := FList.GetIterator;
  try
    Assert.IsTrue(Iter.Current = FA, 'Create positions Current on the head');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.ForwardWalk_FirstNextNext_ThenNilAtTheEnd;
var
  Iter: TGraphicObjIterator;
begin
  Iter := FList.GetIterator;
  try
    Assert.IsTrue(Iter.First = FA, 'First');
    Assert.IsTrue(Iter.Current = FA, 'Current after First');
    Assert.IsTrue(Iter.Next = FB, 'Next -> B');
    Assert.IsTrue(Iter.Next = FC, 'Next -> C');
    Assert.IsTrue(Iter.Next = nil, 'Next past the tail returns nil');
    Assert.IsTrue(Iter.Current = nil, 'and clears Current');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.BackwardWalk_LastPrevPrev_ThenNilAtTheStart;
var
  Iter: TGraphicObjIterator;
begin
  Iter := FList.GetIterator;
  try
    Assert.IsTrue(Iter.Last = FC, 'Last');
    Assert.IsTrue(Iter.Current = FC, 'Current after Last');
    Assert.IsTrue(Iter.Prev = FB, 'Prev -> B');
    Assert.IsTrue(Iter.Prev = FA, 'Prev -> A');
    Assert.IsTrue(Iter.Prev = nil, 'Prev past the head returns nil');
    Assert.IsTrue(Iter.Current = nil, 'and clears Current');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.Iterator_Count_MirrorsListCount;
var
  Iter: TGraphicObjIterator;
begin
  Iter := FList.GetIterator;
  try
    Assert.AreEqual(3, Integer(Iter.Count), 'Iterator.Count');
    Assert.AreEqual(Integer(FList.Count), Integer(Iter.Count), 'same as the list');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.Search_MovesCurrentToTheFoundObject;
var
  Iter: TGraphicObjIterator;
begin
  Iter := FList.GetIterator;
  try
    Assert.IsTrue(Iter.Search(3) = FC, 'Search returns the object');
    Assert.IsTrue(Iter.Current = FC, 'and moves the cursor onto it');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.Search_UnknownID_ReturnsNilAndLeavesCurrent;
var
  Iter: TGraphicObjIterator;
begin
  Iter := FList.GetIterator;
  try
    Iter.Last;
    Assert.IsTrue(Iter.Search(99) = nil, 'nil for an unknown ID');
    Assert.IsTrue(Iter.Current = FC, 'the cursor is left where it was');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.DefaultProperty_IndexesByIDNotByPosition;
var
  Iter: TGraphicObjIterator;
begin
  Iter := FList.GetIterator;
  try
    { Items[] is wired to Search, so the "index" is an object ID. }
    Assert.IsTrue(Iter[1] = FA, 'Items[1] is the object whose ID is 1');
    Assert.IsTrue(Iter[3] = FC, 'Items[3] is the object whose ID is 3');
    Assert.IsTrue(Iter[0] = nil, 'no object has ID 0');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.SourceList_IsTheOriginatingList;
var
  Iter: TGraphicObjIterator;
begin
  Iter := FList.GetIterator;
  try
    Assert.IsTrue(Iter.SourceList = FList, 'SourceList');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.IteratorOnEmptyList_FirstLastAndNextAreNil;
var
  Empty: TGraphicObjList;
  Iter: TGraphicObjIterator;
begin
  Empty := TGraphicObjList.Create;
  try
    Iter := Empty.GetIterator;
    try
      Assert.IsTrue(Iter.Current = nil, 'Current');
      Assert.IsTrue(Iter.First = nil, 'First');
      Assert.IsTrue(Iter.Last = nil, 'Last');
      Assert.IsTrue(Iter.Next = nil, 'Next');
      Assert.AreEqual(0, Integer(Iter.Count), 'Count');
    finally
      Iter.Free;
    end;
  finally
    Empty.Free;
  end;
end;

procedure TGraphicObjIteratorTests.TwoPlainIterators_CanCoexist;
var
  I1, I2: TGraphicObjIterator;
begin
  I1 := FList.GetIterator;
  try
    I2 := FList.GetIterator;
    try
      Assert.IsTrue(FList.HasIterators, 'two iterators are alive');
      I1.First;
      I2.Last;
      Assert.IsTrue(I1.Current = FA, 'the cursors are independent (I1)');
      Assert.IsTrue(I2.Current = FC, 'the cursors are independent (I2)');
    finally
      I2.Free;
    end;
    Assert.IsTrue(FList.HasIterators, 'one is still alive');
  finally
    I1.Free;
  end;
  Assert.IsFalse(FList.HasIterators, 'both released');
end;

procedure TGraphicObjIteratorTests.ExclusiveIterator_SetsHasExclusiveIterators;
var
  Iter: TExclusiveGraphicObjIterator;
begin
  Iter := FList.GetExclusiveIterator;
  try
    Assert.IsTrue(FList.HasExclusiveIterators, 'HasExclusiveIterators');
    Assert.IsTrue(FList.HasIterators, 'it also counts as an iterator');
  finally
    Iter.Free;
  end;
  Assert.IsFalse(FList.HasExclusiveIterators, 'cleared on Free');
  Assert.IsFalse(FList.HasIterators, 'and the counter is decremented');
end;

procedure TGraphicObjIteratorTests.ExclusiveIterator_BlocksGetIterator;
var
  Iter: TExclusiveGraphicObjIterator;
begin
  Iter := FList.GetExclusiveIterator;
  try
    Assert.WillRaise(
      procedure
      var
        Other: TGraphicObjIterator;
      begin
        Other := FList.GetIterator;
        Other.Free;
      end, ECADListBlocked);
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.PlainIterator_BlocksGetExclusiveIterator;
var
  Iter: TGraphicObjIterator;
begin
  Iter := FList.GetIterator;
  try
    Assert.WillRaise(
      procedure
      var
        Other: TExclusiveGraphicObjIterator;
      begin
        Other := FList.GetExclusiveIterator;
        Other.Free;
      end, ECADListBlocked);
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.MutatingAListWithAnExclusiveIterator_RaisesECADListBlocked;
var
  Iter: TExclusiveGraphicObjIterator;
  Orphan: TSentinelGraphicObject;
begin
  Orphan := TSentinelGraphicObject.Create(4);
  try
    Iter := FList.GetExclusiveIterator;
    try
      { Every mutating method on the list itself checks fIterators > 0, and an
        exclusive iterator counts towards that. Mutation goes through the
        iterator (DeleteCurrent / RemoveCurrent), never through the list. }
      Assert.WillRaise(
        procedure
        begin
          FList.Add(Orphan);
        end, ECADListBlocked, 'Add');
      Assert.WillRaise(
        procedure
        begin
          FList.Clear;
        end, ECADListBlocked, 'Clear');
      Assert.WillRaise(
        procedure
        begin
          FList.Delete(1);
        end, ECADListBlocked, 'Delete');
      Assert.WillRaise(
        procedure
        begin
          FList.Remove(1);
        end, ECADListBlocked, 'Remove');
    finally
      Iter.Free;
    end;
    Assert.AreEqual(3, Integer(FList.Count), 'The list is untouched');
  finally
    Orphan.Free;
  end;
end;

procedure TGraphicObjIteratorTests.MutatingAListWithAPlainIterator_RaisesECADListBlocked;
var
  Iter: TGraphicObjIterator;
  Orphan: TSentinelGraphicObject;
begin
  Orphan := TSentinelGraphicObject.Create(4);
  Iter := FList.GetIterator;
  try
    Assert.WillRaise(
      procedure
      begin
        FList.Add(Orphan);
      end, ECADListBlocked, 'a plain iterator blocks Add too');
  finally
    Iter.Free;
  end;
  { Once released, the same call goes through. Orphan then belongs to FList,
    which frees it in TearDown. }
  FList.Add(Orphan);
  Assert.AreEqual(4, Integer(FList.Count), 'Count');
end;

procedure TGraphicObjIteratorTests.GetPrivilegedIterator_IgnoresPendingIterators;
var
  Plain: TGraphicObjIterator;
  Privileged: TExclusiveGraphicObjIterator;
begin
  Plain := FList.GetIterator;
  try
    { GetExclusiveIterator would raise here; the privileged one does not check. }
    Privileged := FList.GetPrivilegedIterator;
    try
      Assert.IsTrue(FList.HasExclusiveIterators, 'HasExclusiveIterators');
      Assert.IsTrue(Privileged.First = FA, 'it is a working iterator');
    finally
      Privileged.Free;
    end;
    Assert.IsFalse(FList.HasExclusiveIterators, 'cleared again');
    Assert.IsTrue(FList.HasIterators, 'the plain iterator is still counted');
  finally
    Plain.Free;
  end;
  Assert.IsFalse(FList.HasIterators, 'all released');
end;

procedure TGraphicObjIteratorTests.RemoveAllIterators_UnblocksTheList;
var
  Iter: TExclusiveGraphicObjIterator;
begin
  Iter := FList.GetExclusiveIterator;
  try
    Assert.IsTrue(FList.HasIterators, 'blocked');
    FList.RemoveAllIterators;
    Assert.IsFalse(FList.HasIterators, 'the semaphore is reset');
    Assert.IsFalse(FList.HasExclusiveIterators, 'and so is the exclusive flag');
    { The list is mutable again even though the iterator object still exists. }
    FList.Add(TSentinelGraphicObject.Create(4));
    Assert.AreEqual(4, Integer(FList.Count), 'Count');
  finally
    { Freeing the stale iterator decrements below zero; the destructor clamps
      the counter back to zero. }
    Iter.Free;
  end;
  Assert.IsFalse(FList.HasIterators, 'the counter is clamped, not negative');
end;

procedure TGraphicObjIteratorTests.DeleteCurrent_FreesTheObjectAndAdvances;
var
  Iter: TExclusiveGraphicObjIterator;
begin
  Iter := FList.GetExclusiveIterator;
  try
    Iter.First;
    Iter.DeleteCurrent;
    Assert.AreEqual(2, Integer(FList.Count), 'Count');
    Assert.AreEqual(1, GDestroyedGraphicObjects,
      'DeleteCurrent honours FreeOnClear = True');
    Assert.IsTrue(Iter.Current = FB, 'the cursor moved to the next object');
  finally
    Iter.Free;
  end;
end;

procedure TGraphicObjIteratorTests.RemoveCurrent_DetachesWithoutFreeingAndAdvances;
var
  Iter: TExclusiveGraphicObjIterator;
begin
  Iter := FList.GetExclusiveIterator;
  try
    Iter.First;
    Iter.RemoveCurrent;
    Assert.AreEqual(2, Integer(FList.Count), 'Count');
    Assert.AreEqual(0, GDestroyedGraphicObjects,
      'RemoveCurrent never frees, whatever FreeOnClear says');
    Assert.IsTrue(Iter.Current = FB, 'the cursor moved to the next object');
  finally
    Iter.Free;
  end;
  { FA is ours again. }
  FA.Free;
  Assert.AreEqual(1, GDestroyedGraphicObjects, 'freed by the caller');
end;

{ ================================================================== }
{ TIndexedObjectListTests }
{ ================================================================== }

procedure TIndexedObjectListTests.Setup;
begin
  GDestroyedSentinels := 0;
  FList := TIndexedObjectList.Create(3);
end;

procedure TIndexedObjectListTests.TearDown;
begin
  FList.Free;
  FList := nil;
end;

procedure TIndexedObjectListTests.Create_SetsNumberOfObjectsAndNilsEverySlot;
begin
  Assert.AreEqual(3, FList.NumberOfObjects, 'NumberOfObjects');
  Assert.IsTrue(FList[0] = nil, 'slot 0');
  Assert.IsTrue(FList[1] = nil, 'slot 1');
  Assert.IsTrue(FList[2] = nil, 'slot 2');
end;

procedure TIndexedObjectListTests.Create_DefaultsToFreeOnClear;
begin
  Assert.IsTrue(FList.FreeOnClear, 'FreeOnClear defaults to True');
end;

procedure TIndexedObjectListTests.PutAndGet_RoundTrip;
var
  O: TDestructionSentinel;
begin
  O := TDestructionSentinel.Create;
  FList[1] := O;
  Assert.IsTrue(FList[1] = O, 'round trip');
  Assert.IsTrue(FList[0] = nil, 'the other slots are untouched');
end;

procedure TIndexedObjectListTests.Get_AtNumberOfObjects_RaisesECADOutOfBound;
begin
  Assert.WillRaise(
    procedure
    var
      O: TObject;
    begin
      O := FList[3];
    end, ECADOutOfBound, 'the valid range is 0 .. NumberOfObjects - 1');
end;

procedure TIndexedObjectListTests.Put_AtNumberOfObjects_RaisesECADOutOfBound;
begin
  Assert.WillRaise(
    procedure
    begin
      FList[3] := nil;
    end, ECADOutOfBound, 'the valid range is 0 .. NumberOfObjects - 1');
end;

procedure TIndexedObjectListTests.Clear_FreesObjectsAndNilsSlotsWhenFreeOnClear;
begin
  FList[0] := TDestructionSentinel.Create;
  FList[1] := TDestructionSentinel.Create;
  FList.Clear;
  Assert.AreEqual(2, GDestroyedSentinels, 'both were freed');
  Assert.IsTrue(FList[0] = nil, 'slot 0 was nilled');
  Assert.IsTrue(FList[1] = nil, 'slot 1 was nilled');
  Assert.AreEqual(3, FList.NumberOfObjects, 'Clear does not resize');
end;

procedure TIndexedObjectListTests.Clear_IsANoOpWhenFreeOnClearIsFalse;
var
  O: TDestructionSentinel;
begin
  O := TDestructionSentinel.Create;
  FList[0] := O;
  FList.FreeOnClear := False;
  FList.Clear;
  Assert.AreEqual(0, GDestroyedSentinels, 'nothing was freed');
  Assert.IsTrue(FList[0] = O, 'and the slot was not even cleared');
  { Ownership never left us. }
  O.Free;
end;

procedure TIndexedObjectListTests.Growing_NumberOfObjects_AddsNilSlots;
begin
  FList[0] := TDestructionSentinel.Create;
  FList.NumberOfObjects := 5;
  Assert.AreEqual(5, FList.NumberOfObjects, 'NumberOfObjects');
  Assert.IsTrue(FList[0] <> nil, 'existing entries survive');
  Assert.IsTrue(FList[3] = nil, 'new slot 3 is nil');
  Assert.IsTrue(FList[4] = nil, 'new slot 4 is nil');
  Assert.AreEqual(0, GDestroyedSentinels, 'growing frees nothing');
end;

procedure TIndexedObjectListTests.Shrinking_NumberOfObjects_FreesTheDroppedObjects;
begin
  FList[0] := TDestructionSentinel.Create;
  FList[1] := TDestructionSentinel.Create;
  FList[2] := TDestructionSentinel.Create;
  FList.NumberOfObjects := 1;
  Assert.AreEqual(1, FList.NumberOfObjects, 'NumberOfObjects');
  Assert.AreEqual(2, GDestroyedSentinels,
    'the two dropped objects were freed because FreeOnClear is True');
  Assert.IsTrue(FList[0] <> nil, 'the surviving entry is intact');
  { The last one is freed by TearDown through the destructor's Clear. }
end;

{ ================================================================== }
{ TLayerTests }
{ ================================================================== }

procedure TLayerTests.Setup;
begin
  FLayer := TLayer.Create(7);
end;

procedure TLayerTests.TearDown;
begin
  FLayer.Free;
  FLayer := nil;
end;

procedure TLayerTests.Create_SetsDocumentedDefaults;
begin
  Assert.AreEqual('Layer 7', String(FLayer.Name), 'Name');
  Assert.AreEqual(7, Integer(FLayer.LayerIndex), 'LayerIndex');
  Assert.IsTrue(FLayer.Active, 'Active');
  Assert.IsTrue(FLayer.Visible, 'Visible');
  Assert.IsFalse(FLayer.Opaque, 'Opaque');
  Assert.IsTrue(FLayer.Streamable, 'Streamable');
  Assert.IsFalse(FLayer.Modified, 'Modified');
  Assert.AreEqual(0, FLayer.Tag, 'Tag');
end;

procedure TLayerTests.Create_SetsDefaultPenAndBrush;
begin
  Assert.IsTrue(FLayer.Pen <> nil, 'Pen');
  Assert.IsTrue(FLayer.Brush <> nil, 'Brush');
  Assert.AreEqual<Cardinal>(Cardinal(cadclBlack), Cardinal(FLayer.Pen.Color), 'Pen.Color');
  Assert.IsTrue(FLayer.Pen.Style = cpsSolid, 'Pen.Style');
  Assert.AreEqual<Cardinal>(Cardinal(cadclWhite), Cardinal(FLayer.Brush.Color), 'Brush.Color');
  Assert.IsTrue(FLayer.Brush.Style = cbsSolid, 'Brush.Style');
end;

procedure TLayerTests.Create_HasADecorativePen;
begin
  Assert.IsTrue(FLayer.DecorativePen <> nil, 'DecorativePen is created too');
end;

procedure TLayerTests.ChangingPenColor_SetsModified;
begin
  Assert.IsFalse(FLayer.Modified, 'precondition');
  FLayer.Pen.Color := TColorToCADColor(clRed);
  Assert.IsTrue(FLayer.Modified,
    'TLayer.Changed is wired to Pen.OnChange in the constructor');
end;

procedure TLayerTests.ChangingPenStyle_SetsModified;
begin
  FLayer.Pen.Style := cpsDash;
  Assert.IsTrue(FLayer.Modified, 'Modified');
end;

procedure TLayerTests.ChangingBrushColor_SetsModified;
begin
  Assert.IsFalse(FLayer.Modified, 'precondition');
  FLayer.Brush.Color := TColorToCADColor(clRed);
  Assert.IsTrue(FLayer.Modified,
    'TLayer.Changed is wired to Brush.OnChange in the constructor');
end;

procedure TLayerTests.ChangingName_SetsModified;
begin
  FLayer.Name := 'Walls';
  Assert.AreEqual('Walls', String(FLayer.Name), 'Name');
  Assert.IsTrue(FLayer.Modified, 'Modified');
end;

procedure TLayerTests.AssigningTheSameName_LeavesModifiedAlone;
begin
  FLayer.Name := 'Layer 7';
  Assert.IsFalse(FLayer.Modified,
    'SetName only marks the layer when the value really changes');
end;

procedure TLayerTests.AssigningPen_CopiesTheValuesAndKeepsTheOwnPenInstance;
var
  Tmp: TCADSimplePen;
begin
  Tmp := TCADSimplePen.Create;
  try
    Tmp.Color := TColorToCADColor(clRed);
    Tmp.Width := 3;
    FLayer.Pen := Tmp;
    Assert.AreEqual<Cardinal>(TColorToCADColor(clRed), Cardinal(FLayer.Pen.Color), 'Color copied');
    Assert.AreEqual(3, FLayer.Pen.Width, 'Width copied');
    Assert.IsFalse(FLayer.Pen = Tmp,
      'SetPen assigns into the layer''s own pen, it does not take ownership');
    Assert.IsTrue(FLayer.Modified, 'Modified');
  finally
    Tmp.Free;
  end;
end;

procedure TLayerTests.AssigningNilPen_IsIgnored;
begin
  FLayer.Pen := nil;
  Assert.IsTrue(FLayer.Pen <> nil, 'the layer still has its pen');
  Assert.IsFalse(FLayer.Modified, 'and nothing was marked as modified');
end;

procedure TLayerTests.AssigningNilBrush_IsIgnored;
begin
  FLayer.Brush := nil;
  Assert.IsTrue(FLayer.Brush <> nil, 'the layer still has its brush');
  Assert.IsFalse(FLayer.Modified, 'and nothing was marked as modified');
end;

procedure TLayerTests.PlainFlags_AreWritableAndDoNotTouchModified;
begin
  FLayer.Active := False;
  FLayer.Visible := False;
  FLayer.Opaque := True;
  FLayer.Streamable := False;
  FLayer.Tag := 42;
  Assert.IsFalse(FLayer.Active, 'Active');
  Assert.IsFalse(FLayer.Visible, 'Visible');
  Assert.IsTrue(FLayer.Opaque, 'Opaque');
  Assert.IsFalse(FLayer.Streamable, 'Streamable');
  Assert.AreEqual(42, FLayer.Tag, 'Tag');
  Assert.IsFalse(FLayer.Modified,
    'only name, pen and brush feed the Modified flag');
end;

{ ================================================================== }
{ TLayersTests }
{ ================================================================== }

procedure TLayersTests.Setup;
begin
  FLayers := TLayers.Create;
end;

procedure TLayersTests.TearDown;
begin
  FLayers.Free;
  FLayers := nil;
end;

procedure TLayersTests.Create_BuildsTwoHundredFiftySixNamedLayers;
begin
  Assert.IsTrue(FLayers[0] <> nil, 'layer 0 exists');
  Assert.IsTrue(FLayers[255] <> nil, 'layer 255 exists');
  Assert.AreEqual('Layer 0', String(FLayers[0].Name), 'name of layer 0');
  Assert.AreEqual('Layer 255', String(FLayers[255].Name), 'name of layer 255');
  Assert.AreEqual(9, Integer(FLayers[9].LayerIndex), 'LayerIndex');
  Assert.IsFalse(FLayers[9].Modified, 'a fresh layer is not modified');
end;

procedure TLayersTests.LayerByName_FindsTheLayer;
var
  Lay: TLayer;
begin
  Lay := FLayers.LayerByName['Layer 9'];
  Assert.IsTrue(Lay <> nil, 'found');
  Assert.IsTrue(Lay = FLayers[9], 'and it is the very same instance');
end;

procedure TLayersTests.LayerByName_UnknownName_ReturnsNil;
begin
  Assert.IsTrue(FLayers.LayerByName['No Such Layer'] = nil, 'nil, not an error');
end;

procedure TLayersTests.RestoreLayers_ResetsNamePenBrushFlagsAndModified;
var
  Lay: TLayer;
begin
  Lay := FLayers[3];
  Lay.Name := 'Dimensions';
  Lay.Pen.Color := TColorToCADColor(clRed);
  Lay.Brush.Color := TColorToCADColor(clRed);
  Lay.Active := False;
  Lay.Visible := False;
  Lay.Opaque := True;
  Lay.Streamable := False;
  Lay.Tag := 99;
  Assert.IsTrue(Lay.Modified, 'precondition: the layer is dirty');

  FLayers.RestoreLayers;

  Assert.AreEqual('Layer 3', String(Lay.Name), 'Name');
  Assert.AreEqual<Cardinal>(Cardinal(cadclBlack), Cardinal(Lay.Pen.Color), 'Pen.Color');
  Assert.IsTrue(Lay.Pen.Style = cpsSolid, 'Pen.Style');
  Assert.AreEqual<Cardinal>(Cardinal(cadclWhite), Cardinal(Lay.Brush.Color), 'Brush.Color');
  Assert.IsTrue(Lay.Brush.Style = cbsSolid, 'Brush.Style');
  Assert.IsTrue(Lay.Active, 'Active');
  Assert.IsTrue(Lay.Visible, 'Visible');
  Assert.IsFalse(Lay.Opaque, 'Opaque');
  Assert.IsTrue(Lay.Streamable, 'Streamable');
  Assert.AreEqual(0, Lay.Tag, 'Tag');
  Assert.IsFalse(Lay.Modified,
    'Modified is cleared last, after the pen/brush writes that set it');
end;

procedure TLayersTests.RestoreLayers_KeepsTheSameBrushInstance;
var
  Lay: TLayer;
  BrushBefore: TCADSimpleBrush;
  PenBefore: TCADSimplePen;
begin
  Lay := FLayers[3];
  BrushBefore := Lay.Brush;
  PenBefore := Lay.Pen;
  FLayers.RestoreLayers;
  Assert.IsTrue(Lay.Brush = BrushBefore,
    'RestoreLayers reuses the existing brush instead of allocating a new one');
  Assert.IsTrue(Lay.Pen = PenBefore, 'and the same holds for the pen');
end;

procedure TLayersTests.RestoreLayers_KeepsBrushModificationTrackingAlive;
var
  Lay: TLayer;
begin
  Lay := FLayers[3];
  FLayers.RestoreLayers;
  Assert.IsFalse(Lay.Modified, 'precondition');
  Lay.Brush.Color := TColorToCADColor(clRed);
  Assert.IsTrue(Lay.Modified,
    'the brush OnChange handler must survive RestoreLayers');
end;

procedure TLayersTests.RestoreLayers_KeepsPenModificationTrackingAlive;
var
  Lay: TLayer;
begin
  Lay := FLayers[3];
  FLayers.RestoreLayers;
  Assert.IsFalse(Lay.Modified, 'precondition');
  Lay.Pen.Color := TColorToCADColor(clRed);
  Assert.IsTrue(Lay.Modified,
    'the pen OnChange handler must survive RestoreLayers');
end;

procedure TLayersTests.Reset_GivesTheDefaultsBackAndClearsModified;
var
  Lay, Fresh: TLayer;
begin
  Lay := FLayers[3];
  Lay.Name := 'Dimensions';
  Lay.Pen.Color := TColorToCADColor(clRed);
  Lay.Pen.Width := 4;
  Lay.Pen.Style := cpsDash;
  Lay.Pen.LineWeightMM := 0.5;
  Lay.Brush.Color := TColorToCADColor(clRed);
  Lay.Brush.Color2 := TColorToCADColor(clBlue);
  Lay.Brush.Style := cbsGradient;
  Lay.DecorativePen.SetPenStyle('1100');
  Lay.Active := False;
  Lay.Visible := False;
  Lay.Opaque := True;
  Lay.Streamable := False;
  Lay.Tag := 99;
  Assert.IsTrue(Lay.Modified, 'precondition');

  FLayers.Reset(3);

  Fresh := TLayer.Create(3);
  try
    Assert.AreEqual(String(Fresh.Name), String(Lay.Name), 'Name');
    Assert.AreEqual<Cardinal>(Cardinal(Fresh.Pen.Color), Cardinal(Lay.Pen.Color), 'Pen.Color');
    Assert.AreEqual(Fresh.Pen.Width, Lay.Pen.Width, 'Pen.Width');
    Assert.IsTrue(Fresh.Pen.Style = Lay.Pen.Style, 'Pen.Style');
    Assert.IsTrue(Fresh.Pen.Mode = Lay.Pen.Mode, 'Pen.Mode');
    Assert.AreEqual(Fresh.Pen.LineWeightMM, Lay.Pen.LineWeightMM, 'Pen.LineWeightMM');
    Assert.AreEqual<Cardinal>(Cardinal(Fresh.Brush.Color), Cardinal(Lay.Brush.Color), 'Brush.Color');
    Assert.AreEqual<Cardinal>(Cardinal(Fresh.Brush.Color2), Cardinal(Lay.Brush.Color2), 'Brush.Color2');
    Assert.IsTrue(Fresh.Brush.Style = Lay.Brush.Style, 'Brush.Style');
    Assert.AreEqual(Fresh.DecorativePen.PatternLenght, Lay.DecorativePen.PatternLenght, 'pattern');
    Assert.IsTrue(Lay.Active, 'Active');
    Assert.IsTrue(Lay.Visible, 'Visible');
    Assert.IsFalse(Lay.Opaque, 'Opaque');
    Assert.IsTrue(Lay.Streamable, 'Streamable');
    Assert.AreEqual(0, Lay.Tag, 'Tag');
    Assert.IsFalse(Lay.Modified, 'Modified');
  finally
    Fresh.Free;
  end;
end;

procedure TLayersTests.Reset_LeavesTheLayerOutOfTheJSONAgain;
var
  TmpBefore, TmpAfter: TJSONArray;
  TmpTextBefore: string;
begin
  { CS-U1: undo of the first change to a layer gives the same JSON back. }
  TmpBefore := FLayers.SaveToJSON;
  try
    TmpTextBefore := TmpBefore.ToJSON;
  finally
    TmpBefore.Free;
  end;
  FLayers[7].Pen.Color := TColorToCADColor(clRed);
  FLayers[7].Name := 'Walls';
  FLayers.Reset(7);
  TmpAfter := FLayers.SaveToJSON;
  try
    Assert.AreEqual(TmpTextBefore, TmpAfter.ToJSON, 'the same as before the edit');
    Assert.AreEqual(0, TmpAfter.Count, 'no layer written');
  finally
    TmpAfter.Free;
  end;
end;

procedure TLayersTests.Reset_KeepsThePenAndBrushAndTheirTracking;
var
  Lay: TLayer;
  PenBefore: TCADSimplePen;
  BrushBefore: TCADSimpleBrush;
begin
  Lay := FLayers[3];
  PenBefore := Lay.Pen;
  BrushBefore := Lay.Brush;
  Lay.Reset;
  Assert.IsTrue(Lay.Pen = PenBefore, 'the same pen');
  Assert.IsTrue(Lay.Brush = BrushBefore, 'the same brush');
  Lay.Brush.Color := TColorToCADColor(clRed);
  Assert.IsTrue(Lay.Modified, 'a change after Reset still counts');
end;

procedure TLayersTests.Reset_LeavesTheOtherLayersAlone;
begin
  FLayers[2].Name := 'Kept';
  FLayers[3].Name := 'Gone';
  FLayers.Reset(3);
  Assert.AreEqual('Kept', String(FLayers[2].Name), 'layer 2');
  Assert.IsTrue(FLayers[2].Modified, 'layer 2 still written');
  Assert.AreEqual('Layer 3', String(FLayers[3].Name), 'layer 3');
end;

{ ================================================================== }
{ TContainer2DTests }

function CountIn(const ACont: TContainer2D): Integer;
var
  TmpIter: TGraphicObjIterator;
  TmpObj: TGraphicObject;
begin
  Result := 0;
  TmpIter := ACont.Objects.GetIterator;
  try
    TmpObj := TmpIter.First;
    while TmpObj <> nil do
    begin
      Inc(Result);
      TmpObj := TmpIter.Next;
    end;
  finally
    TmpIter.Free;
  end;
end;

procedure TContainer2DTests.CreatedFromAnEmptyArray_IsEmpty;
var
  TmpCont: TContainer2D;
begin
  { This crashed. An empty open array has High() = -1; the loop counter
    was a Word, which turns that into 65535, so the constructor walked
    65536 entries of a zero-length array with range checking off and
    added whatever it found. Nothing passed an empty array until the
    legacy reader did, and then it took down the whole import with no
    exception to catch - the list was full of rubbish pointers long
    before anything tried to use them. }
  TmpCont := TContainer2D.Create(0, []);
  try
    Assert.AreEqual(0, CountIn(TmpCont), 'an empty container is empty');
  finally
    TmpCont.Free;
  end;
end;

procedure TContainer2DTests.CreatedFromObjects_HoldsThem;
var
  TmpCont: TContainer2D;
begin
  TmpCont := TContainer2D.Create(0,
    [TLine2D.Create(1, Point2D(0, 0), Point2D(1, 1)),
    TLine2D.Create(2, Point2D(2, 2), Point2D(3, 3))]);
  try
    Assert.AreEqual(2, CountIn(TmpCont), 'both objects went in');
  finally
    TmpCont.Free;
  end;
end;

{ TCADPrgParamTests }
{ ================================================================== }

procedure TCADPrgParamTests.Setup;
begin
  GDestroyedSentinels := 0;
end;

procedure TCADPrgParamTests.Create_StoresAfterStateAndLeavesUserObjectNil;
var
  Param: TCADPrgParam;
begin
  Param := TCADPrgParam.Create(TCADState);
  try
    Assert.IsTrue(Param.AfterState = TCADState, 'AfterState');
    Assert.IsTrue(Param.UserObject = nil, 'UserObject starts out nil');
  finally
    Param.Free;
  end;
end;

procedure TCADPrgParamTests.Create_WithNilAfterState;
var
  Param: TCADPrgParam;
begin
  Param := TCADPrgParam.Create(nil);
  try
    Assert.IsTrue(Param.AfterState = nil, 'AfterState');
  finally
    Param.Free;
  end;
end;

procedure TCADPrgParamTests.AfterState_IsWritable;
var
  Param: TCADPrgParam;
begin
  Param := TCADPrgParam.Create(nil);
  try
    Param.AfterState := TCADState;
    Assert.IsTrue(Param.AfterState = TCADState, 'AfterState');
  finally
    Param.Free;
  end;
end;

procedure TCADPrgParamTests.Destroy_FreesTheUserObject;
var
  Param: TCADPrgParam;
begin
  Param := TCADPrgParam.Create(nil);
  { Assigning UserObject hands ownership to the parameter: its destructor
    frees whatever UserObject points at. Callers must not free it themselves
    and must not share the instance with another parameter. }
  Param.UserObject := TDestructionSentinel.Create;
  Assert.AreEqual(0, GDestroyedSentinels, 'still alive while the param lives');
  Param.Free;
  Assert.AreEqual(1, GDestroyedSentinels,
    'TCADPrgParam.Destroy owns and frees UserObject');
end;

procedure TCADPrgParamTests.Destroy_WithNoUserObject_IsHarmless;
var
  Param: TCADPrgParam;
begin
  Param := TCADPrgParam.Create(nil);
  Assert.IsTrue(Param.UserObject = nil, 'precondition');
  { Destroy tests Assigned(fUserObject) before freeing, so this must not fault. }
  Param.Free;
  Assert.AreEqual(0, GDestroyedSentinels, 'nothing to free');
end;

procedure TCADPrgParamTests.DetachingUserObject_TransfersOwnershipBackToTheCaller;
var
  Param: TCADPrgParam;
  Owned: TDestructionSentinel;
begin
  Owned := TDestructionSentinel.Create;
  Param := TCADPrgParam.Create(nil);
  Param.UserObject := Owned;
  { Nilling the property before destruction is the only way to keep the
    object alive past the parameter. }
  Param.UserObject := nil;
  Param.Free;
  Assert.AreEqual(0, GDestroyedSentinels, 'the detached object survived');
  Owned.Free;
  Assert.AreEqual(1, GDestroyedSentinels, 'and the caller has to free it');
end;

initialization

TDUnitX.RegisterTestFixture(TPointsSet2DTests);
TDUnitX.RegisterTestFixture(TPointsSet2DPutContractTests);
TDUnitX.RegisterTestFixture(TPointsSet3DTests);
TDUnitX.RegisterTestFixture(TGraphicObjListTests);
TDUnitX.RegisterTestFixture(TGraphicObjIteratorTests);
TDUnitX.RegisterTestFixture(TIndexedObjectListTests);
TDUnitX.RegisterTestFixture(TLayerTests);
TDUnitX.RegisterTestFixture(TLayersTests);
TDUnitX.RegisterTestFixture(TContainer2DTests);
TDUnitX.RegisterTestFixture(TCADPrgParamTests);

end.
