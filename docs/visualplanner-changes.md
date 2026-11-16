<!-- Copied from VisualPlannerFNC\docs\library-changes\cadsysfnc_changes.md (its master), 2026-11-16.
     The status of each item is kept here. -->

| ID | Change | Priority | Status |
|---|---|---|---|
| CS-U1 | A layer can go back to not modified | Low | Open |
| CS-U2 | A hidden layer is hidden on paper too | High | Done (c97dd5e) |
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
