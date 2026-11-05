

https://github.com/user-attachments/assets/c203cd46-20ad-4896-9019-69c6d5ddcc64

# CADSysFNC

A 2D/3D vector graphics and CAD library for Delphi, built on **TMS FNC** so that
one set of sources serves VCL and FMX from the same code.

CADSysFNC is a port of Piero Valagussa's **CADSys 4.2**. The geometry, the shape
hierarchy, the display list and the interaction model are his; what changed is
everything underneath them — drawing now goes through a backend rather than
straight onto a `TCanvas`, the persisted format is JSON, colours carry alpha, and
the controls descend from `TTMSFNCCustomControl`. See
[docs/migrating.md](docs/migrating.md) if you are coming from CADSys 4.2.

## What you get

* A **display list** of shapes in floating-point world coordinates — lines, arcs,
  ellipses, curves, splines, polygons, outlines, vector and bitmap text, images,
  containers and reusable source blocks — on 256 layers.
* A **viewport** control that draws it, with zoom, pan, a grid, snapping and
  hit-testing, plus horizontal and vertical rulers.
* An **interaction engine** (`TFNCCADPrg`) built from small state classes:
  select, move, rotate, edit control points, draw each primitive. Writing a new
  tool means writing a state, not touching the viewport.
* **Printing and PDF**, with a page model that knows about paper: standard
  sizes, margins, fit-to-page or a stated scale, and multi-page tiling. The
  preview control, the printer and the PDF writer all draw through the same
  routine, so they cannot drift. Line weights can be given in millimetres, which
  is what makes a print look like a drawing rather than a fax.
* **Sheets** — paper space. A drawing carries sheets of paper with viewports cut
  into them, each viewport showing part of the model at its own scale. A sheet's
  own objects are in millimetres of paper, and they are ordinary shapes, so a
  title block is drawn with the same primitives, fonts and DXF import as
  everything else. Sheets are saved with the drawing, previewed by the same
  control, and printed or exported to PDF by the same routines.
* **Import/export**: JSON (the native format), DXF in and out, the legacy binary
  `.CS2` format for reading old drawings, and — on VCL — printing and clipboard.
* Everything is source. New shapes and new operations are the intended way to use
  it, not a last resort.

## Status

| Framework | State |
|---|---|
| **VCL** | Complete. Test suites green, demo verified across a 240 DPI and a 96 DPI display. |
| **FMX** | Complete. Drawing, zoom, grid, rulers, snap, selection, editing, DXF, saved views — all verified by hand on Windows at both display scales. |
| **Lazarus / LCL** | Sources carry the LCL branches, but nothing has been built. Blocked on TMS FNC Core for FPC. |

Only Windows has been exercised. Nothing in the library is Windows-specific any
more except `VCL.FNCCS4GraphicsVCL` and `VCL.FNCCS4ExportVCL`, which are VCL-only
by design — but "should compile" is not "has run", and no other platform has been
tried.

## Requirements

* **Delphi 12** (BDS 23.0). Earlier versions are untested; nothing knowingly
  depends on a 12-only feature.
* **TMS FNC Core 4.4** or later, installed for the frameworks you intend to use.
* Windows, for now.

## Installing

```
git clone https://github.com/OwlHatSoftware/CADSysFNC
cd CADSysFNC
Tools\gen-units.cmd
```

**That second step is not optional.** `Sources` holds one master copy of each
unit, named `VCL.*`; the generator writes the per-framework copies into
`Generated\VCL`, `Generated\FMX` and `Generated\LCL`, which is what everything
compiles against. `Generated\` is not in the repository, so a fresh clone
compiles nothing until you have run it once — and again after you edit anything
in `Sources`.

Then build the packages in `Packages\delphi`, **runtime first**:

| Order | Package | |
|---|---|---|
| 1 | `FNCCadSysVCL` | runtime, VCL — build, do not install |
| 2 | `FNCCadSysFMX` | runtime, FMX — build, do not install |
| 3 | `FNCCadSysDEVCL` | design-time, VCL palette — build and **install** |
| 4 | `FNCCadSysDEFMX` | design-time, FMX palette — build and **install** |

The design-time packages only register what the runtime packages contain, so
installing one built against a stale runtime BPL fails in ways that do not name
the cause. Build 1 and 2 before 3 and 4, every time.

Add `<repo>\Generated\VCL` (or `\FMX`) to the library path of any project that
uses the units directly.

> **About the unit names.** `VCL.FNCCADSys4`, `VCL.FNCCS4Shapes`, and so on:
> `FNCC` is the stem every unit shares so the generator can turn one tree into
> three with a single substitution, and the `VCL.` / `FMX.` / `LCL` prefix is
> which tree you are looking at. Unlovely, and load-bearing.

Both palettes can be installed at once, and both appear on a palette page called
**FNCCadSys**: `TFNCCADCmp2D`, `TFNCCADViewport2D` and `TFNCCADPrg2D`.

`Tools\build-packages.cmd [BDSVER]` builds all four from the command line into
`Tools\build\pkg` without touching what the IDE has installed — useful for
checking a change compiles, not a substitute for installing.

## A minimal program

Three components. The *document* holds the shapes, the *viewport* draws it, the
*program* turns mouse and keyboard into operations on it.

```pascal
uses
  VCL.FNCCADSys4, VCL.FNCCS4Shapes, VCL.FNCCS4Tasks,
  VCL.FNCCadSysRegister;   // its initialization fills the class registry

procedure TForm1.FormCreate(Sender: TObject);
begin
  fCAD := TFNCCADCmp2D.Create(Self);

  fView := TFNCCADViewport2D.Create(Self);
  fView.Parent := Self;
  fView.Align := alClient;
  fView.CADCmp := fCAD;
  fView.GridDeltaX := 10.0;
  fView.GridDeltaY := 10.0;

  fPrg := TFNCCADPrg2D.Create(Self);
  fPrg.Viewport2D := fView;

  // world coordinates, not pixels
  fCAD.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(100, 50)));
  fCAD.AddObject(-1, TEllipse2D.Create(-1, Point2D(0, 0), Point2D(60, 60)));
  fView.ZoomToExtension;

  // let the user draw another line: a state class, plus a parameter
  // object carrying the shape it should build
  fPrg.StartOperation(TCAD2DDrawSizedPrimitive,
    TCAD2DDrawSizedPrimitiveParam.Create(nil,
      TLine2D.Create(-1, Point2D(0, 0), Point2D(0, 0)), 0, True));
end;
```

`VCL.FNCCadSysRegister` must be in the uses clause of every application, not only
in the packages: its `initialization` is what fills the class registry, and
without it `LoadFromFile` has no class to map a stored shape onto.

On FMX the same code reads `FMX.FNCCADSys4`, `TAlignLayout.Client`, and so on —
the API is identical.

## Demos

| | |
|---|---|
| `Demos\CAD2D\VCL` | The full demo: drawing, editing, layers, DXF, saved views, printing. |
| `Demos\CAD2D\FMX` | **The same program**, written for FMX. Diff the two `MainFrm.pas` — around 300 lines of 1,030 differ, and all of it is framework spelling. |
| `Demos\CADCmpDemo\VCL` | The document without a viewport. |
| `Demos\PointsVectDemo\VCL` | The point and vector primitives on their own. |

Each CAD2D demo writes an unbuffered step log beside its executable, which is
there to survive a hard crash rather than to be pretty.

## Tests

Two DUnitX console suites under `Test`, run together by
`Tools\build-and-test.cmd [BDSVER]`:

* `CADSys4Tests` — geometry, structures, shapes, JSON persistence, DXF, saved
  views, the page model, sheets, and the drawing layer with its VCL backend.
  576 tests.
* `CADSysFNCTests` — the FNC backend drawn into a `TTMSFNCGraphics` bitmap. Kept
  separate so the main suite does not need FNC to run.

`Tools\build-vcl.cmd` and `Tools\build-fmx.cmd` build the two demos; the FMX one
also compiles `Test\CADSysFMXCheck.dpr`, which links every unit and runs nothing.
All four scripts regenerate the per-framework units first and write to
`Tools\logs\`. Run all four before believing a change that touches shared code:
`build.cmd` in the root does that, packages included, and ends with
`BUILD OK, TESTS PASSED`. They look for TMS FNC beside this folder; set
`CADSYS_TMS` to the `Products` folder when it is elsewhere.

## Repository layout

```
Sources\        the master units (VCL.*) and the framework include files
Generated\      per-framework copies - build output, not in the repository
Packages\       delphi\ (four packages) and Lazarus\ (unbuilt)
Demos\          four demo programs; CAD2D exists twice, once per framework
Test\           the two DUnitX suites
Tools\          the generator and the build scripts
docs\           format reference, migration guide, and the port history
Documentations\ the original CADSys 4.2 help file and change log
```

## Known limitations

* The palette icons in `Packages\delphi\FNCCadSys.dcr` are still keyed to the old
  class names, so the components show the default icon until the resource is
  rebuilt.
* An opaque hatch pattern no longer fills the gaps between its lines.
* `CopingFrequency` no longer shows partial results during a long repaint.
* The print **preview** and **PDF output** work on VCL and FMX alike. Sending
  pages to a **printer** is VCL-only, because that path wants a `TPrinter` and a
  GDI device context; the page model underneath is framework-free, so an FMX
  printer is a unit to write rather than a design to redo.
* A sheet is drawn, printed and exported, but not yet **edited through**: you
  build one in code and look at it. Clicking into a viewport to work on the
  model in paper space is not there. `CADSheetViewportRectPx` is public so an
  application can work out which viewport was clicked.
* Printing several sheets at once takes its orientation from the first of them,
  because `Vcl.Printers` gives the orientation to the document rather than to
  the page. PDF has no such limit — each page carries its own size.
* Everything the library measures other than a line weight is still in pixels —
  the pick aperture, control-point handles, ruler ticks. Only pen weight and
  hatch spacing have a physical size.
* No drawing made by the original library is in the repository - the `.CS2`
  fixtures in `Test\data` were synthesised from the format description, not
  written by a pre-port CADSys.

## Documentation

* [docs/migrating.md](docs/migrating.md) — what changed from CADSys 4.2, and what
  existing code has to change.
* [docs/paper-space.md](docs/paper-space.md) — editable paper space: the two
  spaces, what an application calls to draw, select, delete and group on a
  sheet, and how a viewport is taken hold of.
* [docs/json-format.md](docs/json-format.md) — the persisted document format.
* [docs/drawing-speed.md](docs/drawing-speed.md) — what the viewport does to stay
  quick with a large drawing: small objects as dots, and pan and zoom from the
  picture already drawn.
* [docs/port/](docs/port/) — the port history and the pre-port code review. These
  are a record of how the library got here, not a user guide, and they are kept
  because several of the traps in them are still traps.
* `Documentations\CADSYS42.HLP` — Piero Valagussa's original help file. The class
  and method documentation in it is still accurate wherever this port did not
  change the signature.

## Licence

MIT — see [LICENSE](LICENSE).

CADSys 4.2 is copyright © 2001 Piero Valagussa, who gave permission for it to be
released under the MIT licence; that happened in
[michalgw/CADSys42](https://github.com/michalgw/CADSys42), from which this port
was taken. The FNC port is copyright © 2026 OwlHatSoftware and is MIT on the same
terms. Both notices are in `LICENSE` and both have to stay there.
