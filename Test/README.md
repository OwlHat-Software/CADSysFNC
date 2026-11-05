# CADSysFNC — DUnitX test suites

Two console DUnitX suites for the library units, built for **Delphi 12** with the
DUnitX that ships with the IDE (`$(BDS)\source\DUnitX`).

| Project | Covers | Last run |
|---|---|---|
| `CADSys4Tests` | the library: geometry, structures, shapes, JSON, DXF, the legacy reader, saved views, the page model, sheets, the drawing layer and its VCL backend | 739 found, 732 passed, 0 failed, 7 ignored |
| `CADSysFNCTests` | the FNC backend, drawn into a `TTMSFNCGraphics` bitmap | 75 / 75 |

Both need TMS FNC Core to compile: the main suite links the library's registration unit, which uses it.

## Running them

```
Tools\build-and-test.cmd [BDSVER]      default BDSVER is 23.0 (Delphi 12)
```

That regenerates the per-framework units, builds both runners and runs both,
writing `build.log`, `test.log`, `results.xml`, `build-fnc.log`, `test-fnc.log`
and `results-fnc.xml` into `Tools\logs\`.

To run one by hand:

```
CADSys4Tests.exe                              full run, console output
CADSys4Tests.exe --exitbehavior:Continue      for CI - no "press Enter" pause
CADSys4Tests.exe --xmloutput:results.xml      NUnit XML
```

The exit code is non-zero if anything failed.

**The projects compile against `..\Generated\VCL`, not `..\Sources`.** `Sources`
holds the master copy of each unit; `Tools\gen-units.cmd` writes the
per-framework trees, and that is what everything builds from. The build script
runs the generator first, so a hand-run of `msbuild` against a stale `Generated`
is the one way to test yesterday's code by accident.

`msbuild` is avoided in the script for an unrelated reason: it hands the compiler
the IDE's entire Win32 library search path on the command line, which with enough
TMS products installed exceeds Windows' 32000-character limit and dies with
MSB6003 before reading a line of Pascal. The script calls `dcc32` directly.

The Debug configuration does **not** turn on range or overflow checking. The
library's convention is range-checks-off, and three units now declare
`{$RANGECHECKS OFF}` themselves because `PVectPoints2D` is the
variable-length-array idiom. Turning them on project-wide is still worth doing
deliberately — it is how the `Word` capacity truncation and the draw-helper
overruns become visible at all — but expect `ERangeError` in places the library
has always been sloppy about, and triage each one rather than treating it as a
build break.

## What is in here

| Unit | Covers |
|---|---|
| `CADSys4.Tests.Geometry` | `FNCCS4BaseTypes` value types and every canvas-free geometry function in `FNCCADSys4`: vector algebra, homogeneous coordinates, the 2D/3D transform algebra, box algebra, distance and clipping helpers. |
| `CADSys4.Tests.Structures` | `TPointsSet2D`/`3D`, `TGraphicObjList` and its iterators, `TIndexedObjectList`, `TLayer`/`TLayers`, `TCADPrgParam` ownership. |
| `CADSys4.Tests.Shapes` | Eight 2D shape families: construction, `Assign` round-trips and independence, bounding boxes, the `BeginUseProfilePoints` protocol, `OnMe` hit-testing, curve precision. |
| `CADSys4.Tests.Persistence` | JSON: the `FNCCS4JSON` helpers, per-shape `SaveToJSON`/`CreateFromJSON`, whole-document round trips (layers, blocks, files, text) and the class registry. |
| `CADSys4.Tests.DXF` | DXF group-level round trips and one end-to-end import. |
| `CADSys4.Tests.Legacy` | The old binary `.CS2` reader, against synthesised streams. |
| `CADSys4.Tests.Views` | `TCADViewSpec`: defaults, the layer set, JSON and file round trips. |
| `CADSys4.Tests.Print` | The page model: paper and margin arithmetic, tiling, the fitted page window, millimetre line weights, the device clip, and a page setup's JSON round trip. |
| `CADSys4.Tests.Sheets` | Sheets: paper arithmetic, a viewport's fit-versus-scale window, the `sheets` array in a drawing, and `CADDrawSheet` against the recording backend - including the two clips nesting. |
| `CADSys4.Tests.Graphics` | The drawing layer: VCL backend pixel tests, and shapes drawn through a recording backend (which proves no `TCanvas` is needed). |
| `CADSys4.Tests.GraphicsFNC` | The FNC backend. In `CADSysFNCTests`, not the main suite. |
| `CADSys4.Tests.Regressions` | One test per defect from `docs/port/optimization-review.md`. |

## Two things to know before you read the results

**Some tests pin defects rather than correct behaviour.** The suite documents
what the library *currently does*, including where that is wrong. Those tests are
named and commented to make it obvious.

**Some findings cannot be reached from a console runner.** Anything behind the
interaction FSM or a live viewport — the pan double-free, the draw-helper
overruns, the GDI font churn — needs a window. `CADSys4.Tests.Regressions`
records them as `[Ignore]`d tests whose ignore message says why and how to verify
them by hand. That is most of the 8 ignored. The same applies to findings
deliberately left unfixed: the placeholder is there so the gap stays visible.

**The `.CS2` fixtures are synthesised, not inherited.** `Test\data` holds three
legacy drawings written by `Tools\make-legacy-fixtures.py` - the same small
drawing in the three combinations of character width and real width, since the
file records neither and the two are independent. The generator shares no code
with the library, which is the point: `TLegacyWriter` in
`CADSys4.Tests.Legacy` and the reader it feeds were written by the same hand
from the same reading of the format, and would agree with each other even if
both were wrong. Regenerate with `python Tools\make-legacy-fixtures.py`; if a
fixture changes, read the diff rather than committing it.

No drawing the *original* library wrote is in the repository, so nothing here
proves a real one loads. The reader was verified by hand against a 1.2 MB
customer drawing that cannot be published.

## Running it against a memory-leak check

Most of the review's findings are lifetime bugs, so the suite is most useful with
FastMM4 in full-debug mode. Add `FastMM4` as the first unit in the `.dpr` uses
clause, drop `FastMM_FullDebugMode.dll` beside the exe, and set:

```pascal
ReportMemoryLeaksOnShutdown := True;
```

Every fixture frees what it creates through `try/finally`, so a clean shutdown
report is the expected result. A leak report naming a library class is a real
finding.

## Adding to it

Fixtures self-register in each unit's `initialization` via
`TDUnitX.RegisterTestFixture`, so a new fixture needs no change to the `.dpr` —
only a new unit added to the project's `DCCReference` list if it lives in a new
file.

The house rule that produced this suite is worth keeping: check the declaration
in `..\Sources` before you call anything, and where a numeric result depends on
flattening detail or accumulated floating point, assert the invariant (the box
contains the points; the count grew by one) rather than a constant you computed
by hand.
