{ : This help file explain all the classes defined for DXF handling
  for the CADSys 4.0 library for both the 2D and 3D use.

  These classes are defined in the VCL.FNCCS4DXFModule unit file
  that you must include in the <B=uses> clause in all of your units
  that access the types mentioned here.

  <B=Note>: The DXF module given here is not yet completed
  for the DXF documentation is lack to be completed and
  easy to understant (at least to me). Thanks to
  <Code=Vincenzo Siviero (esiviero@@tin.it)> for his help.
  Thanks also to <Code=Giuseppe Staltieri (sgs@@elios.net)>
  for his invaluable support and beta testing.
}
unit VCL.FNCCS4DXFModule;

{$I VCL.FNCCADSys.inc}

Interface

uses
{$IFDEF CADSYS_LCL}
  SysUtils,
  Classes,
{$ELSE}
  System.SysUtils,
  System.Classes,
{$ENDIF}
  VCL.FNCCADSys4,
  VCL.FNCCS4BaseTypes,
  VCL.FNCCS4Graphics,
  VCL.FNCCS4Shapes;

type
  // -----===== Starting Cs4DXFReadWrite.pas =====-----
  TSections = (scHeader, scClasses, scObjects, scThumbinalImage, scTables,
    scBlocks, scEntities, scUnknow);

  { Used to store readed groups from 0 group to 0 group. }
  TGroupTable = array [0 .. 512] of Variant;

  { : One vertex of an LWPOLYLINE. Bulge is the tangent of a quarter of the
    arc's angle from this vertex to the next: 0 for a straight segment, and
    positive when the arc turns anticlockwise. }
  TDXFPolyVertex = record
    X, Y, Bulge: Double;
  end;

  TDXFRead = class(TObject)
  private
    fStream: TextFile;
    { An LWPOLYLINE repeats groups 10, 20 and 42 once per vertex, and a
      TGroupTable has one slot per code, so they are kept here as well. }
    fVertices: TArray<TDXFPolyVertex>;
    { CS4-FIX (X2): per-instance format settings, so DXF parsing never writes
      the process-global FormatSettings. }
    fFS: TFormatSettings;
    { CS4-FIX: a DXF is two lines per group, and the default TextFile buffer is
      128 bytes. Must be a field, never a stack local - the file record keeps a
      pointer to it for the lifetime of the handle. }
    fTextBuf: array [0 .. 65535] of Byte;
    fCurrentSection: TSections;
    fGroupCode: Word;
    fGroupValue: Variant;
    fOnProgress: TCADProgressEvent;
    fGroupsRead: Int64;

    procedure DoProgress;
  public
    constructor Create(FileName: String);
    destructor Destroy; override;
    procedure Rewind;
    { Return False if EOF. }
    function ConsumeGroup: Boolean;
    procedure NextSection;
    function ReadAnEntry(GroupDel: Word; var Values: TGroupTable): Word;

    property GroupCode: Word read fGroupCode;
    property GroupValue: Variant read fGroupValue;
    property CurrentSection: TSections read fCurrentSection;
    { : The vertices of the entry just read, when it was an LWPOLYLINE. }
    property Vertices: TArray<TDXFPolyVertex> read fVertices;
    { : Called every so often while the file is read, so the application
      can show progress. It used to be a TProgressBar, which the library
      cannot know about any more; wire this to whatever you use.

      The position is a count of groups read and the maximum is 0, because
      a DXF is a text file whose length in groups is not known until it
      ends - which is why the old TProgressBar never had a Max either.
    }
    property OnProgress: TCADProgressEvent read fOnProgress write fOnProgress;
  end;

  TDXFWrite = class(TObject)
  private
    fStream: TextFile;
    { CS4-FIX (X2): per-instance format settings, so DXF parsing never writes
      the process-global FormatSettings. }
    fFS: TFormatSettings;
    { CS4-FIX: a DXF is two lines per group, and the default TextFile buffer is
      128 bytes. Must be a field, never a stack local - the file record keeps a
      pointer to it for the lifetime of the handle. }
    fTextBuf: array [0 .. 65535] of Byte;
  public
    constructor Create(FileName: String);
    destructor Destroy; override;

    procedure Reset;
    procedure BeginSection(Sect: TSections);
    procedure EndSection({%H-}Sect: TSections);
    procedure WriteGroup(GroupCode: Word; GroupValue: Variant);
    procedure WriteAnEntry(var Values: TGroupTable);
  end;

  EDXFException = Exception;
  EDXFEndOfFile = EAbort;
  EDXFInvalidDXF = EDXFException;

  // -----===== Starting Cs4DXF2DConverter.pas =====-----

  TDXF2DImport = class(TObject)
  private
    fTextFont: TVectFont;
    fDXFRead: TDXFRead;
    fScale: TRealType;
    fHasExtension, fUnableToReadAll, fVerbose: Boolean;
    fSetLayers: Boolean;
    // Se True i layers letti modificano quelli del CAD in base all'ordine di recupero.
    fCADCmp2D: TFNCCADCmp2D;
    fAngleDir: TArcDirection;
    fExtension: TRect2D;
    fLayerList: TStringList;
    { Contain the name of the layers and the layer itself. }
    fBlockList: TStringList;
    { Contain the name of the blocks and the block itself. }
    fOnMapObjectClass: TCADMapObjectClassEvent;

    procedure ReadEntitiesAsContainer(const Container: TContainer2D);
    { Hands AObj to OnMapObjectClass and, when the handler chooses
      another class, returns the object recreated as that class, freeing
      AObj. }
    function MapEntity(const AObj: TObject2D): TObject2D;
    { Read the DXF blocks. }
    procedure ReadBlocks;
    { Read the DXF entities. }
    procedure ReadEntities;
  protected
    // Leggono le entità
    function ReadLine2D(Entry: TGroupTable): TLine2D;
    function ReadTrace2D(Entry: TGroupTable): TPolyline2D;
    function ReadSolid2D(Entry: TGroupTable): TPolyline2D;
    function ReadArc2D(Entry: TGroupTable): TArc2D;
    function ReadCircle2D(Entry: TGroupTable): TEllipse2D;
    function ReadEllipse2D(Entry: TGroupTable): TCurve2D;
    function ReadPolyline2D(Entry: TGroupTable): TPolyline2D;
    function ReadLWPolyline2D(Entry: TGroupTable): TPolyline2D;
    function ReadText2D(Entry: TGroupTable): TJustifiedVectText2D;
    function ReadSourceBlock(Entry: TGroupTable): TSourceBlock2D;
    function ReadBlock(Entry: TGroupTable): TBlock2D;
    function ReadEntity(IgnoreBlock: Boolean): TObject2D;

    function GoToSection(Sect: TSections): Boolean;

    property DXFRead: TDXFRead read fDXFRead;
  public
    constructor Create(const FileName: String; const CAD: TFNCCADCmp2D);
    destructor Destroy; override;

    procedure SetTextFont(F: TVectFont);

    { Read the DXF header. }
    procedure ReadHeader;
    { Read the DXF tables. }
    procedure ReadTables;

    { Read the DXF informations. }
    procedure ReadDXF;
    { Read the DXF informations as a block. }
    function ReadDXFAsSourceBlock(const Name: TSourceBlockName): TSourceBlock2D;
    { Read the DXF informations as a container. }
    function ReadDXFAsContainer: TContainer2D;

    property HasExtension: Boolean read fHasExtension;
    property Extension: TRect2D read fExtension;
    property BlockList: TStringList read fBlockList;
    property LayerList: TStringList read fLayerList;
    property Scale: TRealType read fScale write fScale;
    property SetLayers: Boolean read fSetLayers write fSetLayers;
    property UnableToReadAllTheFile: Boolean read fUnableToReadAll;
    property Verbose: Boolean read fVerbose write fVerbose;
    { : Chooses the class each entity is created as - the same event a
      drawing has for loading (see <See Type=TCADMapObjectClassEvent>),
      so that one handler can serve both, and an import gives the
      application its own classes directly instead of a drawing to
      convert afterwards.

      <I=ATypeName> is the class the reader made, and <I=AClass>
      arrives as that class. A different class gets the entity
      recreated as that class, through the entity's own JSON - so a
      replacement must read what the original writes, which in practice
      means a descendant of it. Leaving it unchanged, or setting it to
      nil, keeps the entity as it was read.

      Applied to everything an import reads, block contents included,
      except block instances and containers themselves: they hold
      references to other objects that a round trip would have to
      resolve again. }
    property OnMapObjectClass: TCADMapObjectClassEvent read fOnMapObjectClass
      write fOnMapObjectClass;
  end;

  TDXF2DExport = class(TObject)
  private
    FDXFWrite: TDXFWrite;
    fCADCmp2D: TFNCCADCmp2D;
  protected
    procedure WriteLine2D(Line: TLine2D);
    procedure WriteFrame2D(Frm: TFrame2D);
    procedure WriteCurve2D(Curve: TCurve2D);
    procedure WriteOutline2D(Poly: TOutline2D);
    procedure WriteJVText2D(Text: TJustifiedVectText2D);
    procedure WriteText2D(Text: TText2D);
    procedure WriteBlock(Block: TBlock2D);
    procedure WriteEntity(Obj: TObject2D);
  public
    constructor Create(const FileName: String; const CAD: TFNCCADCmp2D);
    destructor Destroy; override;

    { Write the DXF headers. }
    procedure WriteHeader;
    { Write the DXF tables. }
    procedure WriteTables;
    { Write the DXF blocks. }
    procedure WriteBlocks;
    { Write the DXF entities. }
    procedure WriteEntities;
    { Write the DXF informations. }
    procedure WriteDXF;
  end;

  // -----===== Starting Cs4DXF3DConverter.pas =====-----

  TDXF3DImport = class(TObject)
  private
    fTextFont: TVectFont;
    fScale: TRealType;
    fDXFRead: TDXFRead;
    FCADCmp3D: TFNCCADCmp3D;
    fAngleDir: TArcDirection;
    fExtension: TRect3D;
    fSetLayers: Boolean;
    // Se True i layers letti modificano quelli del CAD in base all'ordine di recupero.
    fHasExtension, fAllowEmptyBlocks, fUnableToReadAll, fVerbose: Boolean;
    fLayerList: TStringList;
    { Contain the name of the layers and the layer itself. }
    fBlockList: TStringList;
    { Contain the name of the blocks and the block itself. }

    procedure ReadEntitiesAsContainer(const Container: TContainer3D);
    { Read the DXF blocks. }
    procedure ReadBlocks;
    { Read the DXF entities. }
    procedure ReadEntities;
  protected
    function ReadLine3D(Entry: TGroupTable): TLine3D;
    function ReadCircle3D(Entry: TGroupTable): TEllipse3D;
    function ReadEllipse3D(Entry: TGroupTable): TPlanarCurve3D;
    function ReadArc3D(Entry: TGroupTable): TArc3D;
    function ReadTrace3D(Entry: TGroupTable): TPolyline3D;
    function ReadText3D(Entry: TGroupTable): TJustifiedVectText3D;
    function ReadPolyline3D(Entry: TGroupTable): TPrimitive3D;
    function ReadLWPolyline3D(Entry: TGroupTable): TPolyline3D;
    function ReadPlanarFace3D(Entry: TGroupTable): TPlanarFace3D;
    function ReadSourceBlock(Entry: TGroupTable): TSourceBlock3D;
    function ReadBlock(Entry: TGroupTable): TBlock3D; virtual;
    function ReadEntity(IgnoreBlock: Boolean): TObject3D; virtual;
  public
    constructor Create(const FileName: String; const CAD: TFNCCADCmp3D);
    destructor Destroy; override;

    function GoToSection(Sect: TSections): Boolean;
    procedure SetTextFont(F: TVectFont);

    { Read the DXF headers. }
    procedure ReadHeader;
    { Read the DXF tables. }
    procedure ReadTables;
    { Read the DXF informations. }
    procedure ReadDXF;
    { Read the DXF informations as a block. }
    function ReadDXFAsSourceBlock(const Name: TSourceBlockName): TSourceBlock3D;
    { Read the DXF informations as a container. }
    function ReadDXFAsContainer: TContainer3D;

    property DXFRead: TDXFRead read fDXFRead;
    property Extension: TRect3D read fExtension;
    property HasExtension: Boolean read fHasExtension;
    property BlockList: TStringList read fBlockList;
    property LayerList: TStringList read fLayerList;
    property Scale: TRealType read fScale write fScale;
    property SetLayers: Boolean read fSetLayers write fSetLayers;
    property UnableToReadAllTheFile: Boolean read fUnableToReadAll;
    { If TRUE empty blocks are read anyway. Default is True. }
    property AllowEmptyBlocks: Boolean read fAllowEmptyBlocks
      write fAllowEmptyBlocks;
    property Verbose: Boolean read fVerbose write fVerbose;
  end;

var
  { : The 256 AutoCAD colour indices as drawing-layer colours. }
  Colors: array [0 .. 255] of TCADColor;

Implementation

uses
{$IFDEF CADSYS_LCL}
  Math, Variants, fpjson;
{$ELSE}
  System.Math, System.Variants, System.JSON;
{$ENDIF}

// function body

// -----===== Starting Cs4DXFReadWrite.pas =====-----

function ColorToIndex(Col: TCADColor; Active: Boolean): Integer;
begin
  Result := 7;
  { Compared opaque: DXF has no alpha, so a translucent layer exports as
    its colour. }
  case CADColorSetAlpha(Col, $FF) of
    cadclBlack, cadclWhite:
      Result := 7;
    cadclRed:
      Result := 1;
    cadclYellow:
      Result := 2;
    cadclLime:
      Result := 3;
    cadclAqua:
      Result := 4;
    cadclBlue:
      Result := 5;
    cadclFuchsia:
      Result := 6;
    cadclGray:
      Result := 8;
    cadclSilver:
      Result := 9;
  end;
  if not Active then
    Result := -1 * Result;
end;

procedure TDXFRead.DoProgress;
begin
  { Throttled: one call per group would cost more than the parsing. }
  if Assigned(fOnProgress) and (fGroupsRead mod 256 = 0) then
    fOnProgress(Self, fGroupsRead, 0);
end;

constructor TDXFRead.Create(FileName: String);
begin
  inherited Create;
  fOnProgress := nil;
  fGroupsRead := 0;
  fFS := FormatSettings;
  fFS.DecimalSeparator := '.';
  fFS.ThousandSeparator := #0;
  AssignFile(fStream, FileName);
  SetTextBuf(fStream, fTextBuf);
  Reset(fStream);
  ConsumeGroup;
  NextSection;
end;

destructor TDXFRead.Destroy;
begin
  CloseFile(fStream);
  inherited Destroy;
end;

procedure TDXFRead.Rewind;
begin
  SetTextBuf(fStream, fTextBuf);
  Reset(fStream);
  fGroupsRead := 0;
  if Assigned(fOnProgress) then
    fOnProgress(Self, 0, 0);
  ConsumeGroup;
  NextSection;
end;

function TDXFRead.ConsumeGroup;
var
  TxtLine: String;
begin
  { CS4-FIX (X2): this used to save, overwrite and restore
    FormatSettings.DecimalSeparator - a process-global - around every parsed
    group. That is not thread-safe against the library's own painting thread,
    and an exception escaping between the writes left the application's locale
    altered. DXF is always '.'-decimal, so sniffing the separator was pointless
    to begin with; fFS pins it per instance. }
  ReadLn(fStream, fGroupCode);
  ReadLn(fStream, TxtLine);
  if EOF(fStream) then
  begin
    Result := False;
    Exit;
  end;
  Inc(fGroupsRead);
  DoProgress;
  case fGroupCode of
    0 .. 9, 999, 1000 .. 1009:
      fGroupValue := Trim(TxtLine);
    10 .. 59, 140 .. 147, 210 .. 239, 1010 .. 1059:
      try
        fGroupValue := StrToFloat(Trim(TxtLine), fFS);
      except
        { CS4-FIX (X6): this used to assign 'varEmpty', which is a TVarType
          constant equal to 0 - so it stored the *value* zero and VarType()
          never reported varEmpty. Every 'VarType(Entry[n]) <> varEmpty' guard
          in this unit was therefore defeated on the parse-failure path, and an
          unreadable coordinate silently became 0.0 at the origin. }
        VarClear(fGroupValue);
      end;
    60 .. 79, 170 .. 175, 1060 .. 1079:
      try
        fGroupValue := StrToInt(Trim(TxtLine));
      except
        VarClear(fGroupValue);
      end;
  else
    fGroupValue := TxtLine;
  end;
  Result := True;
end;

procedure TDXFRead.NextSection;
begin
  fCurrentSection := scUnknow;
  while not((fGroupCode = 0) and (fGroupValue = 'SECTION')) do
    if ConsumeGroup = False then
      Exit;
  ConsumeGroup;
  if fGroupValue = 'HEADER' then
    fCurrentSection := scHeader
  else if fGroupValue = 'CLASSES' then
    fCurrentSection := scClasses
  else if fGroupValue = 'OBJECTS' then
    fCurrentSection := scObjects
  else if fGroupValue = 'THUMBNAILIMAGE' then
    fCurrentSection := scThumbinalImage
  else if fGroupValue = 'TABLES' then
    fCurrentSection := scTables
  else if fGroupValue = 'BLOCKS' then
    fCurrentSection := scBlocks
  else if fGroupValue = 'ENTITIES' then
    fCurrentSection := scEntities;
  ConsumeGroup;
end;

{ GroupDel = Group delimiter }
function TDXFRead.ReadAnEntry(GroupDel: Word; var Values: TGroupTable): Word;
var
  I: Integer;
  TmpCollect: Boolean;
begin
  Result := 0;
  SetLength(fVertices, 0);
  { CS4-FIX: Values was never cleared between entities, so every slot the
    current entity does not define kept the *previous* entity's value. In
    ReadPolyline2D the same LocalEntry is reused for the whole VERTEX loop, so
    a vertex omitting group 10 or 20 silently repeated the previous vertex's
    coordinate, and the 'VarType(...) <> varEmpty' guards throughout this unit
    were reading stale data rather than detecting an absent group. }
  for I := Low(Values) to High(Values) do
    VarClear(Values[I]);
  { Find the start of the entry. }
  while (fGroupCode <> GroupDel) and (fGroupCode <> 0) do
    if ConsumeGroup = False then
      Exit;
  if (fGroupCode = 0) and (fGroupCode <> GroupDel) then
    Exit;
  TmpCollect := (fGroupCode = 0) and (VarToStr(fGroupValue) = 'LWPOLYLINE');
  { Read all values. }
  repeat
    if TmpCollect and (VarType(fGroupValue) <> varEmpty) then
      case fGroupCode of
        10:
          begin
            SetLength(fVertices, Length(fVertices) + 1);
            fVertices[High(fVertices)].X := fGroupValue;
            fVertices[High(fVertices)].Y := 0;
            fVertices[High(fVertices)].Bulge := 0;
          end;
        20:
          if Length(fVertices) > 0 then
            fVertices[High(fVertices)].Y := fGroupValue;
        42:
          if Length(fVertices) > 0 then
            fVertices[High(fVertices)].Bulge := fGroupValue;
      end;
    if fGroupCode < 256 then
      Values[fGroupCode] := fGroupValue
    { The extended data types are remapped from 256=1000. }
    { CS4-FIX: the upper bound was missing, so a group code above 1256 wrote
      a Variant past the end of TGroupTable - and every caller declares that
      table as a stack local. }
    else if (fGroupCode >= 1000) and (fGroupCode <= 1256) then
      Values[fGroupCode - 744] := fGroupValue;
    ConsumeGroup;
  until (fGroupCode = GroupDel) or (fGroupCode = 0);
  Result := GroupDel;
end;

{ --================== DXFWriter ==================-- }

constructor TDXFWrite.Create(FileName: String);
begin
  inherited Create;
  fFS := FormatSettings;
  fFS.DecimalSeparator := '.';
  fFS.ThousandSeparator := #0;
  AssignFile(fStream, FileName);
  SetTextBuf(fStream, fTextBuf);
  Rewrite(fStream);
end;

destructor TDXFWrite.Destroy;
begin
  CloseFile(fStream);
  inherited Destroy;
end;

procedure TDXFWrite.Reset;
begin
  SetTextBuf(fStream, fTextBuf);
  Rewrite(fStream);
end;

procedure TDXFWrite.WriteGroup(GroupCode: Word; GroupValue: Variant);
var
  TxtLine: String;
begin
  { CS4-FIX (X2): see TDXFRead.ConsumeGroup - the global FormatSettings is no
    longer written; fFS carries the '.'-decimal DXF requires. }
  WriteLn(fStream, Format('%3d', [GroupCode]));
  case GroupCode of
    0 .. 9, 999, 1000 .. 1009:
      TxtLine := Copy(GroupValue, 1, 255);
    10 .. 59, 140 .. 147, 210 .. 239, 1010 .. 1059:
      TxtLine := Format('%.6f', [Double(GroupValue)], fFS);
    60 .. 79, 170 .. 175, 1060 .. 1079:
      TxtLine := Format('%6d', [Integer(GroupValue)], fFS);
  else
    TxtLine := '';
  end;
  WriteLn(fStream, TxtLine);
end;

procedure TDXFWrite.BeginSection(Sect: TSections);
begin
  WriteGroup(0, 'SECTION');
  case Sect of
    scHeader:
      WriteGroup(2, 'HEADER');
    scTables:
      WriteGroup(2, 'TABLES');
    scBlocks:
      WriteGroup(2, 'BLOCKS');
    scEntities:
      WriteGroup(2, 'ENTITIES');
  end;
end;

procedure TDXFWrite.EndSection(Sect: TSections);
begin
  WriteGroup(0, 'ENDSEC');
end;

{ Table Index => DXF file group value
  0-255       => 0-255
  256-512     => 1000-1255 }
procedure TDXFWrite.WriteAnEntry(var Values: TGroupTable);
var
  Cont: Word;
begin
  for Cont := 0 to 255 do
    if VarType(Values[Cont]) > 0 then
      WriteGroup(Cont, Values[Cont]);
  for Cont := 1000 to 1255 do
    if VarType(Values[Cont - 744]) > 0 then
      WriteGroup(Cont, Values[Cont - 744]);
end;

// -----===== Starting Cs4DXF2DConverter.pas =====-----

{ --================ DXF2DImport ==================-- }

procedure TDXF2DImport.SetTextFont(F: TVectFont);
begin
  fTextFont := F;
end;

function TDXF2DImport.ReadLine2D(Entry: TGroupTable): TLine2D;
begin
  Result := TLine2D.Create(0, Point2D(Entry[10], Entry[20]),
    Point2D(Entry[11], Entry[21]));
end;

function TDXF2DImport.ReadCircle2D(Entry: TGroupTable): TEllipse2D;
begin
  Result := TEllipse2D.Create(0, Point2D(Entry[10] - Entry[40],
    Entry[20] - Entry[40]), Point2D(Entry[10] + Entry[40],
    Entry[20] + Entry[40]));
end;

function TDXF2DImport.ReadEllipse2D(Entry: TGroupTable): TCurve2D;
var
  CenterPt, MajorAx: TPoint2D;
  MinorLen, MajorLen, SA, EA, RotA: TRealType;
begin
  CenterPt := Point2D(Entry[10], Entry[20]);
  MajorAx := Point2D(Entry[11], Entry[21]);
  MinorLen := Entry[40];
  MajorLen := PointDistance2D(CenterPt, MajorAx);
  SA := Entry[41];
  EA := Entry[42];
  RotA := ArcTan2(MajorAx.Y - CenterPt.Y, MajorAx.X - CenterPt.X);

  if (SA = 0.0) and (EA = 2 * Pi) then
    // Ellisse completa
    Result := TEllipse2D.Create(0, CenterPt, CenterPt)
  else
    // Arco di ellisse
    Result := TArc2D.Create(0, CenterPt, CenterPt, SA, EA);
  with Result do
  begin
    Points[0] := Point2D(CenterPt.X - MajorLen, CenterPt.X - MinorLen);
    Points[1] := Point2D(CenterPt.X + MajorLen, CenterPt.X + MinorLen);
    if RotA <> 0 then
      ModelTransform := Rotate2D(RotA);
  end;
end;

function TDXF2DImport.ReadArc2D(Entry: TGroupTable): TArc2D;
var
  SA, EA: TRealType;
begin
  SA := DegToRad(Entry[50]);
  EA := DegToRad(Entry[51]);
  Result := TArc2D.Create(0, Point2D(Entry[10] - Entry[40],
    Entry[20] - Entry[40]), Point2D(Entry[10] + Entry[40], Entry[20] + Entry[40]
    ), SA, EA);
  Result.Direction := fAngleDir;
end;

function TDXF2DImport.ReadTrace2D(Entry: TGroupTable): TPolyline2D;
begin
  Result := TPolyline2D.Create(0, [Point2D(Entry[10], Entry[20]),
    Point2D(Entry[11], Entry[21]), Point2D(Entry[12], Entry[22]),
    Point2D(Entry[13], Entry[23])]);
end;

function TDXF2DImport.ReadSolid2D(Entry: TGroupTable): TPolyline2D;
begin
  if VarType(Entry[13]) = varEmpty then
    Result := TPolyline2D.Create(0, [Point2D(Entry[10], Entry[20]),
      Point2D(Entry[11], Entry[21]), Point2D(Entry[12], Entry[22]),
      Point2D(Entry[10], Entry[20])])
  else
    Result := TPolyline2D.Create(0, [Point2D(Entry[10], Entry[20]),
      Point2D(Entry[11], Entry[21]), Point2D(Entry[12], Entry[22]),
      Point2D(Entry[13], Entry[23]), Point2D(Entry[10], Entry[20])]);
end;

function TDXF2DImport.ReadText2D(Entry: TGroupTable): TJustifiedVectText2D;
var
  TmpRect: TRect2D;
begin
  Result := nil;
  if fTextFont = nil then
    Exit;
  TmpRect.FirstEdge := Point2D(Entry[10], Entry[20]);
  TmpRect.SecondEdge := Point2D(Entry[10], Entry[20] + Entry[40]);
  Result := TJustifiedVectText2D.Create(0, fTextFont, TmpRect, Entry[40],
    VarToStr(Entry[1]));
  if Entry[1] = 'F' then
  begin
    Result.DrawBox := True;
  end;
  if VarType(Entry[72]) <> 0 then
  begin
    case Entry[72] of
      1:
        Result.HorizontalJust := jhCenter;
      2:
        Result.HorizontalJust := jhRight;
    end;
    case Entry[73] of
      1:
        Result.VerticalJust := jvBottom;
      2:
        Result.VerticalJust := jvCenter;
    end;
    if (Entry[72] > 0) or (Entry[73] > 0) then
      Result.Points[1] := Point2D(Entry[11], Entry[21]);
  end;
  if VarType(Entry[50]) <> 0 then
  begin
    Result.Transform(Translate2D(-Result.Points[1].X, -Result.Points[1].Y));
    Result.Transform(Rotate2D(DegToRad(Entry[50])));
    Result.Transform(Translate2D(Result.Points[1].X, Result.Points[1].Y));
  end;
  Result.DrawBox := False;
end;

{ : The outline of an LWPOLYLINE: its vertices, with each bulge laid out as
  short straight pieces, since a polyline holds points only. A closed one
  ends back on its first vertex, as a closed POLYLINE does here, and the
  last vertex's bulge is the arc back to the first. An open one's last bulge
  leads nowhere and is ignored. }
function DXFExpandPolyVertices(const AVertices: array of TDXFPolyVertex;
  const AClosed: Boolean): TArray<TPoint2D>;
const
  { No piece turns more than this. On a radius R it leaves the chord less
    than R / 1000 from the true arc. }
  ARC_STEP = 5 * Pi / 180;
var
  TmpCount, I, J, TmpN: Integer;
  TmpNext: TDXFPolyVertex;
  TmpDX, TmpDY, TmpChord, TmpOff, TmpCX, TmpCY, TmpR, TmpStart, TmpSweep,
    TmpBulge: Double;

  procedure Add(const X, Y: Double);
  begin
    if TmpCount = Length(Result) then
      SetLength(Result, Max(16, TmpCount * 2));
    Result[TmpCount] := Point2D(X, Y);
    Inc(TmpCount);
  end;

begin
  SetLength(Result, 0);
  TmpCount := 0;
  for I := 0 to High(AVertices) do
  begin
    Add(AVertices[I].X, AVertices[I].Y);
    if I < High(AVertices) then
      TmpNext := AVertices[I + 1]
    else if AClosed then
      TmpNext := AVertices[0]
    else
      Break;
    TmpBulge := AVertices[I].Bulge;
    TmpDX := TmpNext.X - AVertices[I].X;
    TmpDY := TmpNext.Y - AVertices[I].Y;
    TmpChord := Sqrt(TmpDX * TmpDX + TmpDY * TmpDY);
    if (TmpBulge = 0) or (TmpChord = 0) then
      Continue;
    { The centre is on the perpendicular through the chord's middle, to the
      left of the direction of travel when the arc is under a half circle. }
    TmpOff := (1 - TmpBulge * TmpBulge) / (4 * TmpBulge);
    TmpCX := (AVertices[I].X + TmpNext.X) / 2 - TmpDY * TmpOff;
    TmpCY := (AVertices[I].Y + TmpNext.Y) / 2 + TmpDX * TmpOff;
    TmpR := TmpChord * (1 + TmpBulge * TmpBulge) / (4 * Abs(TmpBulge));
    TmpStart := ArcTan2(AVertices[I].Y - TmpCY, AVertices[I].X - TmpCX);
    TmpSweep := 4 * ArcTan(TmpBulge);
    TmpN := Max(2, Ceil(Abs(TmpSweep) / ARC_STEP));
    for J := 1 to TmpN - 1 do
      Add(TmpCX + TmpR * Cos(TmpStart + TmpSweep * J / TmpN),
        TmpCY + TmpR * Sin(TmpStart + TmpSweep * J / TmpN));
  end;
  if AClosed and (Length(AVertices) > 0) then
    Add(AVertices[0].X, AVertices[0].Y);
  SetLength(Result, TmpCount);
end;

function DXFLWIsClosed(const AEntry: TGroupTable): Boolean;
begin
  Result := (VarType(AEntry[70]) <> varEmpty) and ((AEntry[70] and 1) = 1);
end;

{ : An extrusion of 0,0,-1 is the outline seen from behind: X runs the other
  way. Other directions are not followed here. }
function DXFLWIsMirrored(const AEntry: TGroupTable): Boolean;
begin
  Result := (VarType(AEntry[230]) <> varEmpty) and (AEntry[230] < 0);
end;

function TDXF2DImport.ReadLWPolyline2D(Entry: TGroupTable): TPolyline2D;
var
  TmpPts: TArray<TPoint2D>;
  I: Integer;
begin
  Result := nil;
  if Length(fDXFRead.Vertices) < 2 then
    Exit;
  TmpPts := DXFExpandPolyVertices(fDXFRead.Vertices, DXFLWIsClosed(Entry));
  if DXFLWIsMirrored(Entry) then
    for I := 0 to High(TmpPts) do
      TmpPts[I].X := -TmpPts[I].X;
  Result := TPolyline2D.Create(0, TmpPts);
end;

function TDXF2DImport.ReadPolyline2D(Entry: TGroupTable): TPolyline2D;
var
  LocalEntry: TGroupTable;
  IsClosedInM, IsSpline2D: Boolean;
begin
  // Considera le polilinee 2D e 3D alla stessa maniera.
  // Determina i flags della polilinea.
  if VarType(Entry[70]) <> varEmpty then
  begin
    IsClosedInM := Entry[70] and 1 = 1;
    IsSpline2D := (Entry[70] and 2 = 2) or (Entry[70] and 4 = 4);
  end
  else
  begin
    IsClosedInM := False;
    IsSpline2D := False;
  end;

  if IsSpline2D then
  begin // Leggo la spline2D
    Result := TPolyline2D.Create(0, [Point2D(0, 0)]);
    Result.Points.Delete(0);
    // Leggo soli punti aggiunti, quindi gruppo 70 con bit 8.
    fDXFRead.ReadAnEntry(0, {%H-}LocalEntry);
    while LocalEntry[0] = 'VERTEX' do
    begin
      if (VarType(LocalEntry[70]) <> varEmpty) and (LocalEntry[70] and 8 = 8)
      then
        Result.Points.Add(Point2D(LocalEntry[10], LocalEntry[20]));
      fDXFRead.ReadAnEntry(0, LocalEntry);
    end;
    if Result.Points.Count = 0 then
    begin // La spline è stata creata senza i punti aggiuntivi.
      Result.Free;
      Result := nil;
      fUnableToReadAll := True;
      if fVerbose then
        CADSysWarn('Spline without spline-fitting isn''t supported.');
    end;
  end
  else
  begin // Leggo la polilinea2D
    Result := TPolyline2D.Create(0, [Point2D(0, 0)]);
    Result.Points.Delete(0);
    // Leggo tutti i punti.
    fDXFRead.ReadAnEntry(0, LocalEntry);
    while LocalEntry[0] = 'VERTEX' do
    begin
      Result.Points.Add(Point2D(LocalEntry[10], LocalEntry[20]));
      fDXFRead.ReadAnEntry(0, LocalEntry);
    end;
    if IsClosedInM then // la chiudo.
      Result.Points.Add(Result.Points[0]);
  end;
  if (LocalEntry[0] <> 'SEQEND') then
  begin
    fUnableToReadAll := True;
    { CS4-FIX: Result holds a fully built polyline here and nobody owns a
      function result until the function returns normally, so raising dropped
      the only reference to it. }
    FreeAndNil(Result);
    Raise EDXFInvalidDXF.Create('Invalid DXF file.');
  end;
end;

function TDXF2DImport.ReadEntity(IgnoreBlock: Boolean): TObject2D;
var
  Entry: TGroupTable;
  NLayer: Integer;
begin
  Result := nil;
  fDXFRead.ReadAnEntry(0, {%H-}Entry);
  NLayer := fLayerList.IndexOf(Entry[8]);
  if NLayer > -1 then
    fCADCmp2D.CurrentLayer := NLayer;
  if Entry[0] = 'LINE' then
    Result := ReadLine2D(Entry)
  else if Entry[0] = 'ARC' then
    Result := ReadArc2D(Entry)
  else if Entry[0] = 'TRACE' then
    Result := ReadTrace2D(Entry)
  else if Entry[0] = 'SOLID' then
    Result := ReadSolid2D(Entry)
  else if Entry[0] = 'CIRCLE' then
    Result := ReadCircle2D(Entry)
  else if Entry[0] = 'ELLIPSE' then
    Result := ReadEllipse2D(Entry)
  else if Entry[0] = 'POLYLINE' then
    Result := ReadPolyline2D(Entry)
  else if Entry[0] = 'LWPOLYLINE' then
    Result := ReadLWPolyline2D(Entry)
  else if Entry[0] = 'TEXT' then
    Result := ReadText2D(Entry)
  else if (not IgnoreBlock) and (Entry[0] = 'INSERT') then
    Result := ReadBlock(Entry);
  { Here, where every entity passes - the drawing's, a block's and a
    container's alike. }
  Result := MapEntity(Result);
end;

function TDXF2DImport.MapEntity(const AObj: TObject2D): TObject2D;
var
  TmpClass: TGraphicObjectClass;
  TmpJSON: TJSONObject;
  TmpNew: TGraphicObject;
begin
  Result := AObj;
  if (AObj = nil) or not Assigned(fOnMapObjectClass) then
    Exit;
  if (AObj is TBlock2D) or (AObj is TContainer2D) then
    Exit;
  TmpClass := TGraphicObjectClass(AObj.ClassType);
  fOnMapObjectClass(Self, AObj.ClassName, TmpClass);
  if (TmpClass = nil) or (TmpClass = AObj.ClassType) then
    Exit;
  if not TmpClass.InheritsFrom(TObject2D) then
    Raise EDXFException.CreateFmt
      ('OnMapObjectClass: %s is not a 2D object class', [TmpClass.ClassName]);
  { Through the entity's JSON rather than Assign: CreateFromJSON is the
    one constructor that is virtual, so it is the only way to have the
    replacement class's own constructor run. Create(ID) is not virtual,
    and an object made through it on a class reference has only the base
    class's fields set up. }
  TmpJSON := CADSysObjectToJSON(AObj);
  try
    TmpNew := TmpClass.CreateFromJSON(TmpJSON);
  finally
    TmpJSON.Free;
  end;
  TmpNew.UpdateExtension(TmpNew);
  AObj.Free;
  Result := TObject2D(TmpNew);
end;

function TDXF2DImport.ReadBlock(Entry: TGroupTable): TBlock2D;
var
  TmpSource: TSourceBlock2D;
  TmpTransf, ScaleTransf, RotTransf: TTransf2D;
begin
  Result := nil;
  try
    TmpSource := fCADCmp2D.FindSourceBlock(StringToBlockName(Entry[2]));
  except
    fUnableToReadAll := True;
    if fVerbose then
      CADSysWarn('Some blocks cannot be read.');
    Exit;
  end;
  if TmpSource <> nil then
  begin
    Result := TBlock2D.Create(0, TmpSource);
    // Rotation
    if VarType(Entry[50]) <> varEmpty then
      RotTransf := Rotate2D(DegToRad(Entry[50]))
    else
      RotTransf := IdentityTransf2D;
    // Scale.
    ScaleTransf := IdentityTransf2D;
    if VarType(Entry[41]) <> varEmpty then
      ScaleTransf[1, 1] := Entry[41];
    if VarType(Entry[42]) <> varEmpty then
      ScaleTransf[2, 2] := Entry[42];
    TmpTransf := MultiplyTransform2D(ScaleTransf, RotTransf);
    TmpTransf := MultiplyTransform2D(TmpTransf,
      Translate2D(Entry[10], Entry[20]));
    Result.ModelTransform := TmpTransf;
    Result.ApplyTransform;
    Result.UpdateExtension(Self);
  end;
end;

procedure TDXF2DImport.ReadEntitiesAsContainer(const Container: TContainer2D);
var
  Tmp: TObject2D;
  ID: Integer;
begin
  ID := 0;
  while DXFRead.GroupValue <> 'ENDSEC' do
  begin
    Tmp := ReadEntity(True);
    if Assigned(Tmp) then
    begin
      Tmp.Transform(Scale2D(fScale, fScale));
      Tmp.ApplyTransform;
      Tmp.ID := ID;
      Container.Objects.Add(Tmp);
      Inc(ID)
    end
    else
      fUnableToReadAll := True;
  end;
  Container.UpdateExtension(Self);
end;

constructor TDXF2DImport.Create(const FileName: String; const CAD: TFNCCADCmp2D);
begin
  inherited Create;
  fDXFRead := TDXFRead.Create(FileName);
  fCADCmp2D := CAD;
  fLayerList := TStringList.Create;
  fBlockList := TStringList.Create;
  fSetLayers := True;
  fScale := 1.0;
  fHasExtension := False;
  fUnableToReadAll := False;
end;

destructor TDXF2DImport.Destroy;
begin
  fDXFRead.Free;
  fLayerList.Free;
  fBlockList.Free;
  inherited Destroy;
end;

function TDXF2DImport.GoToSection(Sect: TSections): Boolean;
begin
  fDXFRead.Rewind;
  while (fDXFRead.CurrentSection <> scUnknow) and
    (fDXFRead.CurrentSection <> Sect) do
    fDXFRead.NextSection;
  Result := fDXFRead.CurrentSection = Sect;
end;

procedure TDXF2DImport.ReadDXF;
begin
  if fCADCmp2D = nil then
    Exit;
  fUnableToReadAll := False;
  fDXFRead.Rewind;
  while (fDXFRead.CurrentSection <> scUnknow) do
  begin
    case fDXFRead.CurrentSection of
      scHeader:
        ReadHeader;
      scTables:
        ReadTables;
      scBlocks:
        ReadBlocks;
      scEntities:
        ReadEntities;
    end;
    fDXFRead.NextSection;
  end;
end;

function TDXF2DImport.ReadDXFAsSourceBlock(const Name: TSourceBlockName)
  : TSourceBlock2D;
begin
  fUnableToReadAll := False;
  ReadHeader;
  ReadBlocks;
  Result := TSourceBlock2D.Create(0, Name, [nil]);
  try
    fDXFRead.Rewind;
    while (fDXFRead.CurrentSection <> scUnknow) do
    begin
      if fDXFRead.CurrentSection = scEntities then
        ReadEntitiesAsContainer(Result);
      fDXFRead.NextSection;
    end;
    Result.UpdateExtension(Self);
  except
    on Exception do
    begin
      Result.Free;
      Result := nil;
    end;
  end;
end;

function TDXF2DImport.ReadDXFAsContainer: TContainer2D;
begin
  fUnableToReadAll := False;
  ReadHeader;
  ReadBlocks;
  Result := TContainer2D.Create(0, [nil]);
  try
    fDXFRead.Rewind;
    while (fDXFRead.CurrentSection <> scUnknow) do
    begin
      if fDXFRead.CurrentSection = scEntities then
        ReadEntitiesAsContainer(Result);
      fDXFRead.NextSection;
    end;
    Result.UpdateExtension(Self);
  except
    on Exception do
    begin
      Result.Free;
      Result := nil;
    end;
  end;
end;

procedure TDXF2DImport.ReadHeader;
var
  Entry: TGroupTable;
begin
  fHasExtension := False;
  fExtension.Right := 1000;
  fExtension.Top := 1000;
  fExtension.W1 := 1.0;
  fExtension.Left := -1000;
  fExtension.Bottom := -1000;
  fExtension.W2 := 1.0;
  fAngleDir := adCounterClockwise;
  while fDXFRead.ReadAnEntry(9, {%H-}Entry) <> 0 do
  begin
    if Entry[9] = '$ANGDIR' then
    begin
      if Entry[70] = 1 then
        fAngleDir := adClockwise
      else
        fAngleDir := adCounterClockwise;
    end
    else if Entry[9] = '$EXTMAX' then
    begin
      fExtension.Right := Entry[10];
      fExtension.Top := Entry[20];
      fHasExtension := True;
    end
    else if Entry[9] = '$EXTMIN' then
    begin
      fExtension.Left := Entry[10];
      fExtension.Bottom := Entry[20];
      fHasExtension := True;
    end;
  end;
  { A file nobody worked the extents out for says so with a minimum above
    its maximum (1E+20 and -1E+20): that is no extent at all, and reordered
    it would be the largest one there is. }
  if (fExtension.Left > fExtension.Right) or
    (fExtension.Bottom > fExtension.Top) then
    fHasExtension := False;
  if fHasExtension then
    fExtension := ReOrderRect2D(fExtension);
end;

procedure TDXF2DImport.ReadTables;
var
  Entry: TGroupTable;
begin
  if fCADCmp2D = nil then
    Exit;
{%H-}fDXFRead.ReadAnEntry(0, {%H-}Entry);
  while fDXFRead.GroupValue <> 'ENDSEC' do
  begin
    if Entry[0] = 'LAYER' then
    begin
      if fSetLayers then
        with fCADCmp2D.Layers[fLayerList.Count] do
        begin
          Pen.Color := Colors[Abs(Round(Real(Entry[62])))];
          Brush.Style := cbsClear;
          Active := Entry[62] >= 0;
          Name := VarToStr(Entry[2]);
        end;
      fLayerList.AddObject(Entry[2], fCADCmp2D.Layers[fLayerList.Count]);
    end;
    fDXFRead.ReadAnEntry(0, Entry);
  end;
end;

procedure TDXF2DImport.ReadEntities;
var
  Tmp: TObject2D;
begin
  if fCADCmp2D = nil then
    Exit;
  while DXFRead.GroupValue <> 'ENDSEC' do
  begin
    Tmp := ReadEntity(False);
    if Assigned(Tmp) then
    begin
      Tmp.Transform(Scale2D(fScale, fScale));
      Tmp.ApplyTransform;
      fCADCmp2D.AddObject(-1, Tmp);
    end
    else
      fUnableToReadAll := True;
  end;
end;

procedure TDXF2DImport.ReadBlocks;
var
  Entry: TGroupTable;
  Tmp: TSourceBlock2D;
  NLayer: Integer;
begin
  if fCADCmp2D = nil then
    Exit;
  while DXFRead.GroupValue <> 'ENDSEC' do
  begin
    fDXFRead.ReadAnEntry(0, {%H-}Entry);
    NLayer := fLayerList.IndexOf(Entry[8]);
    if NLayer > -1 then
      fCADCmp2D.CurrentLayer := NLayer;
    if Entry[0] = 'BLOCK' then
    begin
      Tmp := ReadSourceBlock(Entry);
      if Assigned(Tmp) then
      begin
        fCADCmp2D.AddSourceBlock(Tmp);
        { Entry[2] contains the name of the block for future ref. }
        fBlockList.AddObject(Entry[2], Tmp);
      end;
    end;
  end;
end;

function TDXF2DImport.ReadSourceBlock(Entry: TGroupTable): TSourceBlock2D;
var
  BasePoint: TPoint2D;
  Tmp: TObject2D;
  TmpName: TSourceBlockName;
begin
  Result := nil;
  if (Entry[70] and $4) or (Entry[70] and $1) then
    { XRef and anonymous are not allowed. }
    Exit;
  BasePoint.X := Entry[10];
  BasePoint.Y := Entry[20];
  BasePoint.W := 1.0;
  if Entry[2] = '' then
    TmpName := StringToBlockName(Format('BLOCK%d',
      [fCADCmp2D.SourceBlocksCount]))
  else
    TmpName := StringToBlockName(Entry[2]);
  Result := TSourceBlock2D.Create(0, TmpName, [nil]);
  while fDXFRead.GroupValue <> 'ENDBLK' do
  begin
    Tmp := ReadEntity(False);
    if Assigned(Tmp) then
      Result.Objects.Add(Tmp);
  end;
  if Result.Objects.Count > 0 then
  begin
    Result.Transform(Translate2D(-BasePoint.X, -BasePoint.Y));
    Result.ApplyTransform;
    Result.UpdateExtension(Self);
  end
  else
  begin
    Result.Free;
    Result := nil;
  end;
end;

{ --================ DXF2DExport ==================-- }

constructor TDXF2DExport.Create(const FileName: String; const CAD: TFNCCADCmp2D);
begin
  inherited Create;
  FDXFWrite := TDXFWrite.Create(FileName);
  fCADCmp2D := CAD;
end;

destructor TDXF2DExport.Destroy;
begin
  FDXFWrite.WriteGroup(0, 'EOF');
  FDXFWrite.Free;
  inherited Destroy;
end;

procedure TDXF2DExport.WriteDXF;
begin
  if fCADCmp2D = nil then
    Exit;
  FDXFWrite.Reset;
  WriteHeader;
  WriteTables;
  WriteBlocks;
  WriteEntities;
end;

procedure TDXF2DExport.WriteHeader;
var
  TmpInt: Integer;
begin
  if fCADCmp2D = nil then
    Exit;
  with FDXFWrite do
  begin
    BeginSection(scHeader);
    { Angle direction, Default CounterClockWise }
    WriteGroup(9, '$ANGDIR');
    TmpInt := 0;
    WriteGroup(70, TmpInt);
    { Extension of the drawing }
    WriteGroup(9, '$EXTMAX');
    WriteGroup(10, fCADCmp2D.DrawingExtension.Right);
    WriteGroup(20, fCADCmp2D.DrawingExtension.Top);
    WriteGroup(30, 0);
    WriteGroup(9, '$EXTMIN');
    WriteGroup(10, fCADCmp2D.DrawingExtension.Left);
    WriteGroup(20, fCADCmp2D.DrawingExtension.Bottom);
    WriteGroup(30, 0);
    WriteGroup(9, '$CECOLOR');
    WriteGroup(62, 256);
    WriteGroup(9, '$CELTYPE');
    WriteGroup(6, 'BYLAYER');
    { End Header Section }
    EndSection(scHeader);
  end;
end;

procedure TDXF2DExport.WriteTables;
var
  Count: Integer;
begin
  if fCADCmp2D = nil then
    Exit;
  with FDXFWrite do
  begin
    { Begin Tables Section }
    BeginSection(scTables);
    WriteGroup(0, 'TABLE');
    WriteGroup(2, 'LTYPE');
    WriteGroup(70, 1);
    WriteGroup(0, 'LTYPE');
    WriteGroup(2, 'CONTINUOUS');
    WriteGroup(70, 64);
    WriteGroup(3, 'Solid line');
    WriteGroup(72, 65);
    WriteGroup(73, 0);
    WriteGroup(40, 0.0);
    WriteGroup(0, 'ENDTAB');
    WriteGroup(0, 'TABLE');
    WriteGroup(2, 'LAYER');
    WriteGroup(70, 257);
    WriteGroup(0, 'LAYER');
    WriteGroup(2, '0');
    WriteGroup(70, 64);
    WriteGroup(62, 7);
    WriteGroup(6, 'CONTINUOUS');
    for Count := 0 to 255 do
      with fCADCmp2D.Layers[Count] do
        if Modified then
        begin
          WriteGroup(0, 'LAYER');
          WriteGroup(2, Name);
          WriteGroup(70, 64);
          WriteGroup(62, ColorToIndex(Pen.Color, Active));
          WriteGroup(6, 'CONTINUOUS');
        end;
    WriteGroup(0, 'ENDTAB');
    { End Tables Section }
    EndSection(scTables);
  end;
end;

procedure TDXF2DExport.WriteEntities;
var
  TmpIter: TGraphicObjIterator;
  TmpObj: TObject2D;
begin
  if fCADCmp2D = nil then
    Exit;
  FDXFWrite.BeginSection(scEntities);
  TmpIter := fCADCmp2D.ObjectsIterator;
  try
    TmpObj := TmpIter.First as TObject2D;
    while TmpObj <> nil do
    begin
      WriteEntity(TmpObj);
      TmpObj := TmpIter.Next as TObject2D;
    end;
  finally
    TmpIter.Free;
    FDXFWrite.EndSection(scEntities);
  end;
end;

procedure TDXF2DExport.WriteBlocks;
var
  TmpIter: TGraphicObjIterator;
  TmpObj: TObject2D;
begin
  if fCADCmp2D = nil then
    Exit;
  FDXFWrite.BeginSection(scBlocks);
  TmpIter := fCADCmp2D.SourceBlocksIterator;
  try
    TmpObj := TmpIter.First as TObject2D;
    while TmpObj <> nil do
    begin
      WriteEntity(TmpObj);
      TmpObj := TmpIter.Next as TObject2D;
    end;
  finally
    TmpIter.Free;
    FDXFWrite.EndSection(scBlocks);
  end;
end;

procedure TDXF2DExport.WriteLine2D(Line: TLine2D);
var
  TmpPnt: TPoint2D;
begin
  with FDXFWrite, Line do
  begin
    TmpPnt := TransformPoint2D(Points[0], ModelTransform);
    WriteGroup(10, TmpPnt.X);
    WriteGroup(20, TmpPnt.Y);
    WriteGroup(30, 0);
    TmpPnt := TransformPoint2D(Points[1], ModelTransform);
    WriteGroup(11, TmpPnt.X);
    WriteGroup(21, TmpPnt.Y);
    WriteGroup(31, 0);
  end;
end;

procedure TDXF2DExport.WriteFrame2D(Frm: TFrame2D);
var
  TmpPnt: TPoint2D;
begin
  with FDXFWrite, Frm do
  begin
    WriteGroup(66, 1);
    WriteGroup(10, 0);
    WriteGroup(20, 0);
    WriteGroup(30, 0); // Questo setta l'elevazione.
    WriteGroup(0, 'VERTEX');
    WriteGroup(8, fCADCmp2D.Layers[Frm.Layer].Name);
    TmpPnt := TransformPoint2D(Points[0], ModelTransform);
    WriteGroup(10, TmpPnt.X);
    WriteGroup(20, TmpPnt.Y);
    WriteGroup(30, 0);
    WriteGroup(0, 'VERTEX');
    WriteGroup(8, fCADCmp2D.Layers[Frm.Layer].Name);
    TmpPnt := TransformPoint2D(Point2D(Points[0].X, Points[1].Y),
      ModelTransform);
    WriteGroup(10, TmpPnt.X);
    WriteGroup(20, TmpPnt.Y);
    WriteGroup(30, 0);
    WriteGroup(0, 'VERTEX');
    WriteGroup(8, fCADCmp2D.Layers[Frm.Layer].Name);
    TmpPnt := TransformPoint2D(Points[1], ModelTransform);
    WriteGroup(10, TmpPnt.X);
    WriteGroup(20, TmpPnt.Y);
    WriteGroup(30, 0);
    WriteGroup(0, 'VERTEX');
    WriteGroup(8, fCADCmp2D.Layers[Frm.Layer].Name);
    TmpPnt := TransformPoint2D(Point2D(Points[1].X, Points[0].Y),
      ModelTransform);
    WriteGroup(10, TmpPnt.X);
    WriteGroup(20, TmpPnt.Y);
    WriteGroup(30, 0);
    WriteGroup(0, 'VERTEX');
    WriteGroup(8, fCADCmp2D.Layers[Frm.Layer].Name);
    TmpPnt := TransformPoint2D(Points[0], ModelTransform);
    WriteGroup(10, TmpPnt.X);
    WriteGroup(20, TmpPnt.Y);
    WriteGroup(30, 0);
    WriteGroup(0, 'SEQEND');
  end;
end;

procedure TDXF2DExport.WriteJVText2D(Text: TJustifiedVectText2D);
var
  TmpPnt, TmpPnt1: TPoint2D;
  InsPnt: TPoint2D;
  AllPnt: TPoint2D;
  TmpAngle: Single;
begin
  with FDXFWrite, Text do
  begin
    WriteGroup(1, Text);
    WriteGroup(40, Height);
    TmpPnt := TransformPoint2D(Points[0], ModelTransform);
    AllPnt := TransformPoint2D(Points[1], ModelTransform);
    InsPnt := TransformPoint2D(Point2D(Points[0].X, Points[1].Y - Height),
      ModelTransform);
    WriteGroup(10, InsPnt.X);
    WriteGroup(20, InsPnt.Y);
    WriteGroup(30, 0);
    // I compute the angle of the Text from the rotation of it.
    TmpPnt := TransformPoint2D(Point2D(0, 0), ModelTransform);
    TmpPnt1 := TransformPoint2D(Point2D(10, 0), ModelTransform);
    TmpAngle := ArcTan2(TmpPnt1.Y - TmpPnt.Y, TmpPnt1.X - TmpPnt.X);
    WriteGroup(50, RadToDeg(TmpAngle));
    case HorizontalJust of
      jhCenter:
        begin
          WriteGroup(11, AllPnt.X - InsPnt.X);
          WriteGroup(21, AllPnt.Y - InsPnt.Y);
          WriteGroup(31, 0);
          WriteGroup(72, 1);
        end;
      jhRight:
        begin
          WriteGroup(11, AllPnt.X);
          WriteGroup(21, AllPnt.Y);
          WriteGroup(31, 0);
          WriteGroup(72, 2);
        end;
    end;
  end;
end;

procedure TDXF2DExport.WriteText2D(Text: TText2D);
begin
  with FDXFWrite, Text do
  begin
    WriteGroup(1, Text);
    WriteGroup(40, Height);
    WriteGroup(10, Points[0].X);
    WriteGroup(20, Points[0].Y);
    WriteGroup(30, 0);
    WriteGroup(50, 0);
    WriteGroup(72, 0);
  end;
end;

procedure TDXF2DExport.WriteCurve2D(Curve: TCurve2D);
var
  Count: Integer;
  TmpPnt: TPoint2D;
begin
  with FDXFWrite, Curve do
  begin
    BeginUseProfilePoints;
    try
      WriteGroup(66, 1);
      WriteGroup(10, 0);
      WriteGroup(20, 0);
      WriteGroup(30, 0); // Questo setta l'elevazione.
      for Count := 0 to ProfilePoints.Count - 1 do
      begin
        WriteGroup(0, 'VERTEX');
        WriteGroup(8, fCADCmp2D.Layers[Curve.Layer].Name);
        TmpPnt := TransformPoint2D(ProfilePoints[Count], ModelTransform);
        WriteGroup(10, TmpPnt.X);
        WriteGroup(20, TmpPnt.Y);
        WriteGroup(30, 0);
      end;
      WriteGroup(0, 'SEQEND');
    finally
      EndUseProfilePoints;
    end;
  end;
end;

procedure TDXF2DExport.WriteOutline2D(Poly: TOutline2D);
var
  Count: Integer;
  TmpPnt: TPoint2D;
begin
  with FDXFWrite, Poly do
  begin
    WriteGroup(66, 1);
    WriteGroup(10, 0);
    WriteGroup(20, 0);
    WriteGroup(30, 0); // Questo setta l'elevazione.
    for Count := 0 to Points.Count - 1 do
    begin
      WriteGroup(0, 'VERTEX');
      WriteGroup(8, fCADCmp2D.Layers[Poly.Layer].Name);
      TmpPnt := TransformPoint2D(Points[Count], ModelTransform);
      WriteGroup(10, TmpPnt.X);
      WriteGroup(20, TmpPnt.Y);
      WriteGroup(30, 0);
    end;
    WriteGroup(0, 'SEQEND');
  end;
end;

procedure TDXF2DExport.WriteBlock(Block: TBlock2D);
begin
  with FDXFWrite, Block do
  begin
    WriteGroup(2, Format('%s', [SourceName]));
    WriteGroup(10, ModelTransform[3, 1]);
    WriteGroup(20, ModelTransform[3, 2]);
    WriteGroup(30, 0);
    WriteGroup(41, sqrt(sqr(ModelTransform[1, 1]) + sqr(ModelTransform[1, 2])));
    WriteGroup(42, sqrt(sqr(ModelTransform[2, 1]) + sqr(ModelTransform[2, 2])));
    WriteGroup(50, RadToDeg(ArcTan2(ModelTransform[1, 2],
      ModelTransform[1, 1])));
  end;
end;

procedure TDXF2DExport.WriteEntity(Obj: TObject2D);
var
  sb: TSourceBlock2D;
  TmpIter: TGraphicObjIterator;
  TmpObj: TObject2D;
begin
  with FDXFWrite do
    if Obj is TLine2D then
    begin
      WriteGroup(0, 'LINE');
      WriteGroup(8, fCADCmp2D.Layers[Obj.Layer].Name);
      WriteLine2D(Obj as TLine2D);
    end
    else if Obj is TFrame2D then
    begin
      WriteGroup(0, 'POLYLINE');
      WriteGroup(8, fCADCmp2D.Layers[Obj.Layer].Name);
      WriteFrame2D(Obj as TFrame2D);
    end
    else if Obj is TCurve2D then
    begin
      WriteGroup(0, 'POLYLINE');
      WriteGroup(8, fCADCmp2D.Layers[Obj.Layer].Name);
      WriteCurve2D(Obj as TCurve2D);
    end
    else if Obj is TOutline2D then
    begin
      WriteGroup(0, 'POLYLINE');
      WriteGroup(8, fCADCmp2D.Layers[Obj.Layer].Name);
      WriteOutline2D(Obj as TOutline2D);
    end
    else if Obj is TJustifiedVectText2D then
    begin
      WriteGroup(0, 'TEXT');
      WriteGroup(8, fCADCmp2D.Layers[Obj.Layer].Name);
      WriteJVText2D(Obj as TJustifiedVectText2D);
    end
    else if Obj is TBlock2D then
    begin
      WriteGroup(0, 'INSERT');
      WriteGroup(8, fCADCmp2D.Layers[Obj.Layer].Name);
      WriteBlock(Obj as TBlock2D);
    end
    else if Obj is TSourceBlock2D then
    begin
      sb := TSourceBlock2D(Obj);
      WriteGroup(0, 'BLOCK');
      WriteGroup(8, fCADCmp2D.Layers[Obj.Layer].Name);
      WriteGroup(62, 0);
      WriteGroup(2, Format('%s', [sb.Name]));
      WriteGroup(70, 0);
      WriteGroup(10, 0.0);
      WriteGroup(20, 0.0);
      WriteGroup(30, 0.0);
      WriteGroup(3, Format('%s', [sb.Name]));
      WriteGroup(1, '');
      TmpIter := sb.Objects.GetIterator;
      try
        TmpObj := TmpIter.First as TObject2D;
        while TmpObj <> nil do
        begin
          WriteEntity(TmpObj);
          TmpObj := TmpIter.Next as TObject2D;
        end;
      finally
        TmpIter.Free;
      end;
      WriteGroup(0, 'ENDBLK');
    end
    else if Obj is TText2D then
    begin
      WriteGroup(0, 'TEXT');
      WriteGroup(8, fCADCmp2D.Layers[Obj.Layer].Name);
      WriteText2D(Obj as TText2D);
    end;
end;

// -----===== Starting Cs4DXF3DConverter.pas =====-----

{ --================ DXF3DImport ==================-- }

constructor TDXF3DImport.Create(const FileName: String; const CAD: TFNCCADCmp3D);
begin
  inherited Create;
  try
    fTextFont := CADSysFindFontByIndex(0);
  except
  end;
  fDXFRead := TDXFRead.Create(FileName);
  FCADCmp3D := CAD;
  fLayerList := TStringList.Create;
  fBlockList := TStringList.Create;
  fHasExtension := False;
  fScale := 1.0;
  fSetLayers := True;
  fUnableToReadAll := False;
end;

destructor TDXF3DImport.Destroy;
begin
  fDXFRead.Free;
  fLayerList.Free;
  fBlockList.Free;
  inherited Destroy;
end;

function TDXF3DImport.GoToSection(Sect: TSections): Boolean;
begin
  fDXFRead.Rewind;
  while (fDXFRead.CurrentSection <> scUnknow) and
    (fDXFRead.CurrentSection <> Sect) do
    fDXFRead.NextSection;
  Result := fDXFRead.CurrentSection = Sect;
end;

procedure TDXF3DImport.SetTextFont(F: TVectFont);
begin
  fTextFont := F;
end;

procedure TDXF3DImport.ReadDXF;
begin
  if FCADCmp3D = nil then
    Exit;
  fDXFRead.Rewind;
  while (fDXFRead.CurrentSection <> scUnknow) do
  begin
    case fDXFRead.CurrentSection of
      scHeader:
        ReadHeader;
      scTables:
        ReadTables;
      scBlocks:
        ReadBlocks;
      scEntities:
        ReadEntities;
    end;
    fDXFRead.NextSection;
  end;
end;

procedure TDXF3DImport.ReadEntitiesAsContainer(const Container: TContainer3D);
var
  Tmp: TObject3D;
  ID: Integer;
begin
  ID := 0;
  while DXFRead.GroupValue <> 'ENDSEC' do
  begin
    Tmp := ReadEntity(True);
    if Assigned(Tmp) then
    begin
      Tmp.Transform(Scale3D(fScale, fScale, fScale));
      Tmp.ApplyTransform;
      Tmp.ID := ID;
      Container.Objects.Add(Tmp);
      Inc(ID)
    end
    else
      fUnableToReadAll := True;
  end;
  Container.UpdateExtension(Self);
end;

function TDXF3DImport.ReadDXFAsSourceBlock(const Name: TSourceBlockName)
  : TSourceBlock3D;
begin
  ReadHeader;
  Result := TSourceBlock3D.Create(0, Name, [nil]);
  try
    fDXFRead.Rewind;
    while (fDXFRead.CurrentSection <> scUnknow) do
    begin
      if fDXFRead.CurrentSection = scEntities then
        ReadEntitiesAsContainer(Result);
      fDXFRead.NextSection;
    end;
    Result.UpdateExtension(Self);
  except
    on Exception do
    begin
      Result.Free;
      Result := nil;
    end;
  end;
end;

function TDXF3DImport.ReadDXFAsContainer: TContainer3D;
begin
  ReadHeader;
  Result := TContainer3D.Create(0, [nil]);
  try
    fDXFRead.Rewind;
    while (fDXFRead.CurrentSection <> scUnknow) do
    begin
      if fDXFRead.CurrentSection = scEntities then
        ReadEntitiesAsContainer(Result);
      fDXFRead.NextSection;
    end;
    Result.UpdateExtension(Self);
  except
    on Exception do
    begin
      Result.Free;
      Result := nil;
    end;
  end;
end;

procedure TDXF3DImport.ReadHeader;
var
  Entry: TGroupTable;
begin
  fHasExtension := False;
  fAngleDir := adCounterClockwise;
  while fDXFRead.ReadAnEntry(9, {%H-}Entry) <> 0 do
  begin
    if Entry[9] = '$ANGDIR' then
    begin
      if Entry[70] = 1 then
        fAngleDir := adClockwise
      else
        fAngleDir := adCounterClockwise
    end
    else if Entry[9] = '$EXTMAX' then
    begin
      fExtension.Right := Entry[10];
      fExtension.Top := Entry[20];
      fExtension.Front := Entry[30];
      fHasExtension := True;
    end
    else if Entry[9] = '$EXTMIN' then
    begin
      fExtension.Left := Entry[10];
      fExtension.Bottom := Entry[20];
      fExtension.Back := Entry[30];
      fHasExtension := True;
    end;
  end;
  { See TDXF2DImport.ReadHeader. }
  if fHasExtension and ((fExtension.Left > fExtension.Right) or
    (fExtension.Bottom > fExtension.Top)) then
    fHasExtension := False;
  if fHasExtension then
    fExtension := ReOrderRect3D(fExtension);
end;

procedure TDXF3DImport.ReadTables;
var
  Entry: TGroupTable;
begin
  if FCADCmp3D = nil then
    Exit;
  fDXFRead.ReadAnEntry(0, {%H-}Entry);
  while fDXFRead.GroupValue <> 'ENDSEC' do
  begin
    if Entry[0] = 'LAYER' then
    begin
      if fSetLayers then
        with FCADCmp3D.Layers[fLayerList.Count] do
        begin
          Pen.Color := Colors[Abs(Round(Double(Entry[62])))];
          Brush.Style := cbsClear;
          Active := Entry[62] >= 0;
          Name := VarToStr(Entry[2]);
        end;
      fLayerList.AddObject(Entry[2], FCADCmp3D.Layers[fLayerList.Count]);
    end;
    fDXFRead.ReadAnEntry(0, Entry);
  end;
end;

procedure TDXF3DImport.ReadEntities;
var
  Tmp: TObject3D;
begin
  if FCADCmp3D = nil then
    Exit;
  while DXFRead.GroupValue <> 'ENDSEC' do
  begin
    Tmp := ReadEntity(False);
    if Assigned(Tmp) then
    begin
      Tmp.Transform(Scale3D(fScale, fScale, fScale));
      Tmp.ApplyTransform;
      FCADCmp3D.AddObject(-1, Tmp);
    end
    else
      fUnableToReadAll := True;
  end;
end;

procedure TDXF3DImport.ReadBlocks;
var
  Entry: TGroupTable;
  Tmp: TSourceBlock3D;
  NLayer: Integer;
begin
  if FCADCmp3D = nil then
    Exit;
  while DXFRead.GroupValue <> 'ENDSEC' do
  begin
    fDXFRead.ReadAnEntry(0, {%H-}Entry);
    NLayer := fLayerList.IndexOf(Entry[8]);
    if NLayer > -1 then
      FCADCmp3D.CurrentLayer := NLayer;
    if (Entry[0] = 'BLOCK') then
    begin
      Tmp := ReadSourceBlock(Entry);
      if Assigned(Tmp) then
        FCADCmp3D.AddSourceBlock(Tmp);
    end;
  end;
end;

function TDXF3DImport.ReadLine3D(Entry: TGroupTable): TLine3D;
begin
  Result := TLine3D.Create(-1, Point3D(Entry[10], Entry[20], Entry[30]),
    Point3D(Entry[11], Entry[21], Entry[31]));
end;

function TDXF3DImport.ReadEllipse3D(Entry: TGroupTable): TPlanarCurve3D;
var
  CenterPt, MajorAx: TPoint3D;
  XAx, YAx, NAx: TVector3D;
  MinorLen, MajorLen, SA, EA: TRealType;
begin
  CenterPt := Point3D(Entry[10], Entry[20], Entry[30]);
  MajorAx := Point3D(Entry[11], Entry[21], Entry[31]);
  MinorLen := Entry[40];
  MajorLen := PointDistance3D(CenterPt, MajorAx);
  SA := Entry[41];
  EA := Entry[42];

  XAx := Direction3D(CenterPt, MajorAx);
  if VarType(Entry[210]) <> 0 then
    NAx := Versor3D(Entry[210], Entry[220], Entry[230])
  else
    NAx := Versor3D(0, 0, 1);
  YAx := CrossProd3D(NAx, XAx);

  if (SA = 0.0) and (EA = 2 * Pi) then
    // Ellisse completa
    Result := TEllipse3D.Create(0, CenterPt, XAx, YAx, CenterPt, CenterPt)
  else
    // Arco di ellisse
    Result := TArc3D.Create(0, CenterPt, XAx, YAx, CenterPt, CenterPt, SA, EA);
  with Result do
  begin
    MajorAx := ExtrudePoint3D(CenterPt, XAx, -MajorLen);
    MajorAx := ExtrudePoint3D(MajorAx, YAx, -MinorLen);
    Points[0] := Result.WorldToObject(MajorAx);
    MajorAx := ExtrudePoint3D(CenterPt, XAx, MajorLen);
    MajorAx := ExtrudePoint3D(MajorAx, YAx, MinorLen);
    Points[1] := Result.WorldToObject(MajorAx);
  end;
end;

function TDXF3DImport.ReadCircle3D(Entry: TGroupTable): TEllipse3D;
var
  CenterPt, P1, P2: TPoint3D;
  XAx, YAx, NAx: TVector3D;
  Radious: TRealType;
begin
  CenterPt := Point3D(Entry[10], Entry[20], Entry[30]);
  Radious := Entry[40];
  if VarType(Entry[210]) <> 0 then
    NAx := Versor3D(Entry[210], Entry[220], Entry[230])
  else
    NAx := Versor3D(0, 0, 1);
  XAx := Versor3D(1, 0, 0);
  YAx := CrossProd3D(NAx, XAx);

  P1 := ExtrudePoint3D(CenterPt, XAx, -Radious);
  P1 := ExtrudePoint3D(P1, YAx, -Radious);
  P2 := ExtrudePoint3D(CenterPt, XAx, Radious);
  P2 := ExtrudePoint3D(P2, YAx, Radious);
  Result := TEllipse3D.Create(-1, CenterPt, XAx, YAx, Point3D(0, 0, 0),
    Point3D(10, 10, 0));
  // I punti di controllo sono in coordinate oggetto.
  Result.Points[0] := Result.WorldToObject(Result.Points[0]);
  Result.Points[1] := Result.WorldToObject(Result.Points[1]);
end;

function TDXF3DImport.ReadArc3D(Entry: TGroupTable): TArc3D;
var
  CenterPt, P1, P2: TPoint3D;
  XAx, YAx, NAx: TVector3D;
  SA, EA, Radious: TRealType;
begin
  CenterPt := Point3D(Entry[10], Entry[20], Entry[30]);
  Radious := Entry[40];
  SA := Entry[50];
  EA := Entry[51];
  if VarType(Entry[210]) <> 0 then
    NAx := Versor3D(Entry[210], Entry[220], Entry[230])
  else
    NAx := Versor3D(0, 0, 1);
  XAx := Versor3D(1, 0, 0);
  YAx := CrossProd3D(NAx, XAx);

  P1 := ExtrudePoint3D(CenterPt, XAx, -Radious);
  P1 := ExtrudePoint3D(P1, YAx, -Radious);
  P2 := ExtrudePoint3D(CenterPt, XAx, Radious);
  P2 := ExtrudePoint3D(P2, YAx, Radious);

  Result := TArc3D.Create(-1, CenterPt, XAx, YAx, Point3D(0, 0, 0),
    Point3D(10, 10, 0), SA, EA);
  // I punti di controllo sono in coordinate oggetto.
  Result.Points[0] := Result.WorldToObject(Result.Points[0]);
  Result.Points[1] := Result.WorldToObject(Result.Points[1]);
  Result.Direction := fAngleDir;
end;

function TDXF3DImport.ReadTrace3D(Entry: TGroupTable): TPolyline3D;
var
  P1, P2, P3, P4: TPoint3D;
begin
  P1 := Point3D(Entry[10], Entry[20], Entry[30]);
  P2 := Point3D(Entry[11], Entry[21], Entry[31]);
  P3 := Point3D(Entry[12], Entry[22], Entry[32]);
  P4 := Point3D(Entry[13], Entry[23], Entry[33]);
  Result := TPolyline3D.Create(0, [P1, P2, P3, P4]);
end;

function TDXF3DImport.ReadText3D(Entry: TGroupTable): TJustifiedVectText3D;
var
  TmpRect: TRect2D;
  YAx, NAx: TVector3D;
  P: TPoint3D;
begin
  Result := nil;
  if fTextFont = nil then
    Exit;
  // Trova i parametri del piano.
  if VarType(Entry[210]) <> 0 then
    NAx := Versor3D(Entry[210], Entry[220], Entry[230])
  else
    NAx := Versor3D(0, 0, 1);
  if IsSameVector3D(CrossProd3D(NAx, Versor3D(0, 1, 0)), Versor3D(0, 0, 0)) then
    YAx := Versor3D(1, 0, 0)
  else
    YAx := Versor3D(0, 1, 0);
  P := Point3D(Entry[10], Entry[20], Entry[30]);
  TmpRect.FirstEdge := Point2D(0, 0);
  TmpRect.SecondEdge := Point2D(0, 0);
  Result := TJustifiedVectText3D.Create(-1, P, NAx, YAx, fTextFont, TmpRect,
    Entry[40], VarToStr(Entry[1]));
  if VarType(Entry[72]) <> 0 then
  begin
    case Entry[72] of
      1:
        Result.HorizontalJust := jhCenter;
      2:
        Result.HorizontalJust := jhRight;
    end;
    case Entry[73] of
      1:
        Result.VerticalJust := jvBottom;
      2:
        Result.VerticalJust := jvCenter;
    end;
  end;
  if VarType(Entry[50]) <> varEmpty then
    Result.Transform(RotateOnAxis3D(P, NAx, Entry[50]));
end;

function TDXF3DImport.ReadPolyline3D(Entry: TGroupTable): TPrimitive3D;
var
  LocalEntry: TGroupTable;
  IsClosedInM, IsMesh3D, IsPolyFace3D, IsSpline3D: Boolean;
  V1, V2, V3, V4, Cont: Integer;
begin
  // Considera le polilinee 2D e 3D alla stessa maniera.
  // Determina i flags della polilinea.
  if VarType(Entry[70]) <> varEmpty then
  begin
    IsClosedInM := (Entry[70] and 1) = 1;
    IsMesh3D := (Entry[70] and 16) = 16;
    IsPolyFace3D := (Entry[70] and 64) = 64;
    IsSpline3D := ((Entry[70] and 2) = 2) or ((Entry[70] and 4) = 4);
  end
  else
  begin
    IsClosedInM := False;
    IsMesh3D := False;
    IsSpline3D := False;
    IsPolyFace3D := False;
  end;

  if IsPolyFace3D then
  begin
    Result := TPolyface3D.Create(-1, Entry[71], Entry[72], [Point3D(0, 0, 0)]);
    Result.Points.Delete(0);
    Cont := 0;
    // Leggo i punti della polyface.
    fDXFRead.ReadAnEntry(0, {%H-}LocalEntry);
    while LocalEntry[0] = 'VERTEX' do
      with TPolyface3D(Result) do
      begin
        if (VarType(LocalEntry[70]) <> varEmpty) and
          ((LocalEntry[70] and 128) = 128) then
        begin
          if ((LocalEntry[70] and 64) = 64) then
            Points.Add(Point3D(LocalEntry[10], LocalEntry[20], LocalEntry[30]))
          else
          begin
            if VarType(LocalEntry[71]) <> varEmpty then
              V1 := LocalEntry[71]
            else
              V1 := 0;
            if VarType(LocalEntry[72]) <> varEmpty then
              V2 := LocalEntry[72]
            else
              V2 := 0;
            if VarType(LocalEntry[73]) <> varEmpty then
              V3 := LocalEntry[73]
            else
              V3 := 0;
            if VarType(LocalEntry[74]) <> varEmpty then
              V4 := LocalEntry[74]
            else
              V4 := 0;
            AddFace(Cont, V1, V2, V3, V4);
            Inc(Cont);
          end;
        end;
        fDXFRead.ReadAnEntry(0, LocalEntry);
      end;
  end
  else if IsSpline3D then
  begin // Leggo la spline3D
    Result := TPolyline3D.Create(0, [Point3D(0, 0, 0)]);
    Result.Points.Delete(0);
    // Leggo soli punti aggiunti, quindi gruppo 70 con bit 8.
    fDXFRead.ReadAnEntry(0, LocalEntry);
    while LocalEntry[0] = 'VERTEX' do
    begin
      if (VarType(LocalEntry[70]) <> varEmpty) and ((LocalEntry[70] and 1) = 1)
        or ((LocalEntry[70] and 8) = 8) then
        Result.Points.Add(Point3D(LocalEntry[10], LocalEntry[20],
          LocalEntry[30]));
      fDXFRead.ReadAnEntry(0, LocalEntry);
    end;
    if Result.Points.Count = 0 then
    begin // La spline è stata creata senza i punti aggiuntivi.
      Result.Free;
      Result := nil;
      if fVerbose then
        CADSysWarn('Spline without spline-fitting isn''t supported.');
    end;
  end
  else if IsMesh3D then
  begin // Leggo la mesh3D
    Result := TMesh3D.Create(-1, Entry[71], Entry[72], [Point3D(0, 0, 0)]);
    Result.Points.Delete(0);
    // Leggo i punti della mesh.
    fDXFRead.ReadAnEntry(0, LocalEntry);
    while LocalEntry[0] = 'VERTEX' do
    begin
      if (VarType(LocalEntry[70]) <> varEmpty) and ((LocalEntry[70] and 64) = 64)
      then
        Result.Points.Add(Point3D(LocalEntry[10], LocalEntry[20],
          LocalEntry[30]));
      fDXFRead.ReadAnEntry(0, LocalEntry);
    end;
  end
  else
  begin // Leggo la polilinea3D
    Result := TPolyline3D.Create(0, [Point3D(0, 0, 0)]);
    Result.Points.Delete(0);
    // Leggo tutti i punti.
    fDXFRead.ReadAnEntry(0, LocalEntry);
    while LocalEntry[0] = 'VERTEX' do
    begin
      Result.Points.Add(Point3D(LocalEntry[10], LocalEntry[20],
        LocalEntry[30]));
      fDXFRead.ReadAnEntry(0, LocalEntry);
    end;
    if IsClosedInM then // la chiudo.
      Result.Points.Add(Result.Points[0]);
  end;
  if (LocalEntry[0] <> 'SEQEND') then
    Raise EDXFInvalidDXF.Create('Invalid DXF file.');
end;

function TDXF3DImport.ReadLWPolyline3D(Entry: TGroupTable): TPolyline3D;
var
  TmpPts: TArray<TPoint2D>;
  TmpElevation: Double;
  I: Integer;
begin
  Result := nil;
  if Length(fDXFRead.Vertices) < 2 then
    Exit;
  TmpElevation := 0;
  if VarType(Entry[38]) <> varEmpty then
    TmpElevation := Entry[38];
  TmpPts := DXFExpandPolyVertices(fDXFRead.Vertices, DXFLWIsClosed(Entry));
  Result := TPolyline3D.Create(0, [Point3D(0, 0, 0)]);
  Result.Points.Delete(0);
  for I := 0 to High(TmpPts) do
    if DXFLWIsMirrored(Entry) then
      Result.Points.Add(Point3D(-TmpPts[I].X, TmpPts[I].Y, -TmpElevation))
    else
      Result.Points.Add(Point3D(TmpPts[I].X, TmpPts[I].Y, TmpElevation));
end;

function TDXF3DImport.ReadPlanarFace3D(Entry: TGroupTable): TPlanarFace3D;
var
  TmpVect: TPointsSet3D;
  XDir, YDir: TVector3D;
begin
  TmpVect := TPointsSet3D.Create(4);
  try
    TmpVect.Add(Point3D(Entry[10], Entry[20], Entry[30]));
    if not IsSamePoint3D(TmpVect[0], Point3D(Entry[11], Entry[21], Entry[31]))
    then
      TmpVect.Add(Point3D(Entry[11], Entry[21], Entry[31]));
    if not IsSamePoint3D(TmpVect[1], Point3D(Entry[12], Entry[22], Entry[32]))
    then
      TmpVect.Add(Point3D(Entry[12], Entry[22], Entry[32]));
    if VarType(Entry[13]) <> varEmpty then
    begin
      if not IsSamePoint3D(TmpVect[2], Point3D(Entry[13], Entry[23], Entry[33]))
      then
        TmpVect.Add(Point3D(Entry[13], Entry[23], Entry[33]));
    end;
    case TmpVect.Count of
      1, 2:
        Result := nil;
      3:
        begin
          XDir := Direction3D(TmpVect[0], TmpVect[1]);
          YDir := CrossProd3D(GetVectNormal(TmpVect.PointsReference,
            TmpVect.Count), XDir);
          Result := TPlanarFace3D.Create(0, TmpVect[0], XDir, YDir,
            [TmpVect[0]]);
          // I punti di controllo sono in coordinate oggetto.
          Result.Points.Clear;
          Result.Points.Add(Result.WorldToObject(TmpVect[0]));
          Result.Points.Add(Result.WorldToObject(TmpVect[1]));
          Result.Points.Add(Result.WorldToObject(TmpVect[2]));
        end;
      4:
        begin
          XDir := Direction3D(TmpVect[0], TmpVect[1]);
          YDir := CrossProd3D(GetVectNormal(TmpVect.PointsReference,
            TmpVect.Count), XDir);
          Result := TPlanarFace3D.Create(0, TmpVect[0], XDir, YDir,
            [TmpVect[0]]);
          // I punti di controllo sono in coordinate oggetto.
          Result.Points.Clear;
          Result.Points.Add(Result.WorldToObject(TmpVect[0]));
          Result.Points.Add(Result.WorldToObject(TmpVect[1]));
          Result.Points.Add(Result.WorldToObject(TmpVect[2]));
          Result.Points.Add(Result.WorldToObject(TmpVect[3]));
        end;
    else
      Result := nil;
    end;
  finally
    TmpVect.Free;
  end;
end;

function TDXF3DImport.ReadBlock(Entry: TGroupTable): TBlock3D;
var
  TmpSource: TSourceBlock3D;
  TmpTransf: TTransf3D;
  InsertPt: TPoint3D;
  XScl, YScl, ZScl, RotAng, ColSpace, RowSpace: TRealType;
  XAx, YAx, NAx: TVector3D;
  ColCont, RowCont, C, R: Integer;
begin
  Result := nil;
  TmpSource := FCADCmp3D.FindSourceBlock(StringToBlockName(Entry[2]));
  if TmpSource <> nil then
  begin
    InsertPt := Point3D(Entry[10], Entry[20], Entry[30]);
    if VarType(Entry[41]) <> varEmpty then
      XScl := Entry[41]
    else
      XScl := 1.0;
    if VarType(Entry[41]) <> varEmpty then
      YScl := Entry[42]
    else
      YScl := 1.0;
    if VarType(Entry[41]) <> varEmpty then
      ZScl := Entry[43]
    else
      ZScl := 1.0;
    RotAng := Entry[50];
    if VarType(Entry[70]) <> varEmpty then
      ColCont := Entry[70]
    else
      ColCont := 1;
    if VarType(Entry[71]) <> varEmpty then
      RowCont := Entry[71]
    else
      RowCont := 1;
    ColSpace := Entry[44];
    RowSpace := Entry[45];
    if VarType(Entry[210]) <> 0 then
      NAx := Versor3D(Entry[210], Entry[220], Entry[230])
    else
      NAx := Versor3D(0, 0, 1);
    XAx := Versor3D(1, 0, 0);
    YAx := CrossProd3D(NAx, XAx);
    // Creazione trasformazione.
    TmpTransf := Scale3D(XScl, YScl, ZScl);
    TmpTransf := MultiplyTransform3D(TmpTransf, RotateOnAxis3D(InsertPt,
      NAx, RotAng));
    // Creazione oggetti.
    for R := 1 to RowCont do
    begin
      for C := 1 to ColCont do
      begin
        Result := TBlock3D.Create(0, TmpSource);
        Result.ModelTransform := TmpTransf;
        Result.ApplyTransform;
        Result.UpdateExtension(Self);
        TmpTransf := MultiplyTransform3D(TmpTransf,
          Translate3D(XAx.X * ColSpace, XAx.Y * ColSpace, XAx.Z * ColSpace));
      end;
      TmpTransf := MultiplyTransform3D(TmpTransf, Translate3D(YAx.X * RowSpace,
        YAx.Y * RowSpace, YAx.Z * RowSpace));
    end;
  end;
end;

function TDXF3DImport.ReadEntity(IgnoreBlock: Boolean): TObject3D;
var
  Entry: TGroupTable;
  NLayer: Integer;
begin
  Result := nil;
  fDXFRead.ReadAnEntry(0, {%H-}Entry);
  NLayer := fLayerList.IndexOf(Entry[8]);
  if NLayer > -1 then
    FCADCmp3D.CurrentLayer := NLayer;
  if Entry[0] = 'LINE' then
    Result := ReadLine3D(Entry)
  else if Entry[0] = 'ELLIPSE' then
    Result := ReadEllipse3D(Entry)
  else if Entry[0] = 'CIRCLE' then
    Result := ReadCircle3D(Entry)
  else if Entry[0] = 'ARC' then
    Result := ReadArc3D(Entry)
  else if Entry[0] = 'TEXT' then
    Result := ReadText3D(Entry)
  else if Entry[0] = 'TRACE' then
    Result := ReadTrace3D(Entry)
  else if Entry[0] = 'POLYLINE' then
    Result := ReadPolyline3D(Entry)
  else if Entry[0] = 'LWPOLYLINE' then
    Result := ReadLWPolyline3D(Entry)
  else if Entry[0] = '3DFACE' then
    Result := ReadPlanarFace3D(Entry)
  else if (not IgnoreBlock) and (Entry[0] = 'INSERT') then
    Result := ReadBlock(Entry);
end;

function TDXF3DImport.ReadSourceBlock(Entry: TGroupTable): TSourceBlock3D;
var
  BasePoint: TPoint3D;
  Tmp: TObject3D;
  TmpName: TSourceBlockName;
begin
  Result := nil;
  if (Entry[70] and $4 = $4) then
    Exit;
  BasePoint.X := Entry[10];
  BasePoint.Y := Entry[20];
  BasePoint.Z := Entry[30];
  BasePoint.W := 1.0;
  if Entry[2] = '' then
    TmpName := StringToBlockName(Format('BLOCK%d',
      [FCADCmp3D.SourceBlocksCount]))
  else
    TmpName := StringToBlockName(Entry[2]);
  Result := TSourceBlock3D.Create(0, TmpName, [nil]);
  while fDXFRead.GroupValue <> 'ENDBLK' do
  begin
    Tmp := ReadEntity(False);
    if Assigned(Tmp) then
      Result.Objects.Add(Tmp);
  end;
  if fAllowEmptyBlocks or (Result.Objects.Count > 0) then
  begin
    Result.Transform(Translate3D(-BasePoint.X, -BasePoint.Y, -BasePoint.Z));
    Result.ApplyTransform;
    Result.UpdateExtension(Self);
  end
  else
  begin
    Result.Free;
    Result := nil;
  end;
end;

const
  ColArray1: array [1 .. 4] of Byte = (0, 63, 127, 191);
  ColArray2: array [1 .. 4] of Byte = (127, 159, 191, 223);

var
  Cont: Byte;

initialization

// Settaggio colori per DXF.
// Colori base.
Colors[0] := CADColor($FF, 255, 255, 255);
Colors[1] := CADColor($FF, 255, 0, 0);
Colors[2] := CADColor($FF, 255, 255, 0);
Colors[3] := CADColor($FF, 0, 255, 0);
Colors[4] := CADColor($FF, 0, 255, 255);
Colors[5] := CADColor($FF, 0, 0, 255);
Colors[6] := CADColor($FF, 255, 0, 255);
Colors[7] := CADColor($FF, 0, 0, 0);
Colors[8] := CADColor($FF, 134, 134, 134);
Colors[9] := CADColor($FF, 187, 187, 187);
// Toni di grigio.
Colors[250] := CADColor($FF, 0, 0, 0);
Colors[251] := CADColor($FF, 45, 45, 45);
Colors[252] := CADColor($FF, 91, 91, 91);
Colors[253] := CADColor($FF, 137, 137, 137);
Colors[254] := CADColor($FF, 183, 183, 183);
Colors[255] := CADColor($FF, 179, 179, 179);
// Altre tonalità
for Cont := 1 to 4 do
begin
  Colors[Cont * 10] := CADColor($FF, 255, ColArray1[Cont], 0);
  Colors[40 + Cont * 10] := CADColor($FF, ColArray1[5 - Cont], 255, 0);
  Colors[80 + Cont * 10] := CADColor($FF, 0, 255, ColArray1[Cont]);
  Colors[120 + Cont * 10] := CADColor($FF, 0, ColArray1[5 - Cont], 255);
  Colors[160 + Cont * 10] := CADColor($FF, ColArray1[Cont], 0, 255);
end;
Colors[210] := CADColor($FF, 255, 0, 255);
Colors[220] := CADColor($FF, 255, 0, 191);
Colors[230] := CADColor($FF, 255, 0, 127);
Colors[240] := CADColor($FF, 255, 0, 63);
for Cont := 1 to 4 do
begin
  Colors[Cont * 10 + 1] := CADColor($FF, 255, ColArray2[Cont], 127);
  Colors[41 + Cont * 10] := CADColor($FF, ColArray2[5 - Cont], 255, 127);
  Colors[81 + Cont * 10] := CADColor($FF, 127, 255, ColArray2[Cont]);
  Colors[121 + Cont * 10] := CADColor($FF, 127, ColArray2[5 - Cont], 255);
  Colors[161 + Cont * 10] := CADColor($FF, ColArray2[Cont], 127, 255);
end;
Colors[211] := CADColor($FF, 255, 127, 255);
Colors[221] := CADColor($FF, 255, 127, 223);
Colors[231] := CADColor($FF, 255, 127, 191);
Colors[241] := CADColor($FF, 255, 127, 159);

// Gli altri sono tutti zero per ora.
end.
