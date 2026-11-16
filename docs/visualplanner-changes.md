<!-- Copied from VisualPlannerFNC\docs\library-changes\cadsysfnc_changes.md (its master), 2026-11-16.
     The status of each item is kept here. -->

| ID | Change | Priority | Status |
|---|---|---|---|
| CS-U1 | A layer can go back to not modified | Low | Done (ffed297) |
| CS-U2 | A hidden layer is hidden on paper too | High | Done (c97dd5e) |
| CS-U3 | A PDF whose pages differ by more than their sheet | Medium | Done (fa60770) |
# CADSysFNC - changes wanted by VisualPlanner

Specified here, made in the CADSysFNC repository. Numbers `CS-Un` are VisualPlanner's own, to keep them apart from the
`CS-nn` numbers in Masterplanner's list.

## CS-U1 - A layer can go back to not modified

**Why:** `TLayers.SaveToJSON` writes the layers whose private `fModified` is set, and nothing clears it. Undo of the first
change to a layer (decision 0010, VP-044) can give the layer its default values back, but the layer stays in what the document
writes. The drawing looks and works the same; the file has one more layer entry than before the edit, so after that undo the
JSON is not exactly what it was. `uvp.undo.SetLayersText` works around it, and the test `NewLayerGoesBackInValue` records this
behaviour.

**Wanted:** `TLayers.Reset(const AIndex: Byte)`, or `TLayer.Reset`: the defaults of `TLayer.Create` and `fModified` False.

**Exit check:** a test in CADSysFNC; in VisualPlanner `SetLayersText` calls it, and `NewLayerGoesBackInValue` then checks the
whole document with `CheckStep`.

**Priority:** low. Nothing is wrong for the user.

**Done as (`ffed297`):** `TLayer.Reset` and `TLayers.Reset(const AIndex: Byte)`: everything `TLayer.Create` gives a layer (name, pen with width, mode and line weight, brush with its gradient, pattern, Active, Visible, Opaque, Streamable, Tag) and `Modified` False, so `SaveToJSON` leaves the layer out again. The pen and brush stay the same instances. Tests in `CADSys4.Tests.Structures` (`TLayersTests.Reset_*`). Left for VisualPlanner: `SetLayersText` calls it and `NewLayerGoesBackInValue` checks the whole document.

## CS-U2 - A hidden layer is hidden on paper too

**Why:** Jacco (2026-11-16): in a paper view every layer is shown, also the ones switched off. The model view draws an object
only when `TLayers.SetCanvas` returns True (`TLayer.SetCanvas` answers the layer's `Visible`). On paper the answer is
dropped:

- `DrawSheetViewport` (`FMX.FNCCADSys4`, the model seen through a viewport) draws every object that is in the window and not
  in the view's `HiddenLayers` override, whatever the layer's own `Visible`;
- `CADDrawSheet` draws the sheet's own objects the same way.

Both go to the screen (the paper view), the print preview, the printer and the PDF writer, so a layer switched off in the
drawing still prints.

**Wanted:** in both loops `if ACAD.Layers.SetCanvas(ACanvas, TmpObj.Layer) then TmpObj.Draw(...)`, as the model view does.
A viewport's layer override (`UseLayerOverride`, `HiddenLayers`) keeps hiding more on top of that. Whether an override should
also be able to *show* a layer that is off in the drawing is not asked here (today it cannot either way on paper).

**Exit check:** a test in CADSysFNC: a sheet with a viewport and an object on a hidden layer draws nothing for it, on the
viewport and on the sheet; with the layer visible it does. In VisualPlanner: a paper view and its PDF of a drawing with a layer
switched off do not show that layer.

**Priority:** high. What is printed differs from what the user switched off.

**Done as (`c97dd5e`):** both loops as asked, and the same fault in `CADDrawPage` (a page of the model, to the printer and PDF) and in `CopyRectToCanvas` of the 2D and 3D viewports, which print too. Tests in `CADSys4.Tests.Sheets` and `CADSys4.Tests.Print` (recording canvas). Found on the way and not changed: a viewport that frames the whole drawing raises `ECADPageError` ("The drawing is empty") when every object is on a layer that is off, because `DrawingExtension` leaves hidden layers out. Not checked here: VisualPlanner's paper view and PDF with a layer off.

**Status:** done in CADSysFNC, c97dd5e (2026-11-16): the two loops and also the page route and `CopyRectToCanvas`, with tests;
CADSysFNC keeps VisualPlanner's list in `docs\visualplanner-changes.md`.

## CS-U3 - A PDF whose pages differ by more than their sheet

**Why:** decision 0013 (WP-10.1): VisualPlanner writes its scenes into one PDF, a page per scene. A scene is the same sheet (or
the same model window) on another date: the objects' appearance changes between pages. `CADSaveSheetsToPDF` and
`CADSavePagesToPDF` draw all pages in one call, with no moment for the caller to change the drawing between two pages, and
`CADSaveSheetsToPDF` takes each sheet once.

**Wanted:** a way to write a PDF page by page, the caller changing the drawing in between. For example a callback before each
page (`ABeforePage: reference to procedure(const AIndex: Integer)`) on both calls, and a way to give the same sheet (or the
same page setup) several times - or a small writer object: `Begin(AFileName)`, `AddSheet(ASheet)` /
`AddModelWindow(ARect, ASetup)` any number of times, `Finish`. The writer is the more general; either serves.

**Exit check:** a test in CADSysFNC: three pages of one sheet, the caller changing an object's colour before each, give a PDF
of three pages with the three colours. In VisualPlanner: *Scenes - Export...* to PDF writes one file with a page per scene.

**Priority:** medium. Until it is in, VisualPlanner writes a PDF per scene.

**Done as (`fa60770`):** the writer, `TCADPDFWriter` in `FNCCS4PDF`: `BeginDocument(AFileName)`, then `AddSheet(ASheet)`, `AddPage(ASetup, APage)` (a page setup's `View.Window` is the model window) and `AddSheetTile` any number of times, each page drawn as the drawing is at that moment and on its own paper, then `EndDocument`. `CADSaveSheetsToPDF`, `CADSavePagesToPDF` and `CADSaveSheetTiledToPDF` are now this writer in a loop; no callback was added to them. Freed without `EndDocument` (an exception) the file is closed but has no translucency or links; `EndDocument` with no page raises `ECADPageError`. Test in `CADSys4.Tests.GraphicsFNC` (`TCADPDFWriterTests`): three pages of one sheet, the layer colour changed before each, read back as red, green and blue in page order. Left for VisualPlanner: *Scenes - Export...* to PDF with one file.
