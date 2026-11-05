# Getting a drawing out

Every route below draws through the same routines the screen uses -
`CADDrawSheet` for a sheet, `CADDrawPage` for a page of the model - so a sheet
looks the same in the preview, on paper and in every file. What differs is the
surface underneath.

| Output | Unit | Frameworks | Routines |
|---|---|---|---|
| PDF | `FNCCS4PDF` | VCL, FMX, LCL | `CADSaveSheetsToPDF`, `CADSavePagesToPDF`, `CADAddPDFLinks` |
| PNG | `FNCCS4Image` | VCL, FMX | `CADSaveSheetToImage`, `CADSaveSheetToPNGStream`, `CADSaveModelRectToImage`, `CADSaveModelRectToPNGStream` |
| SVG | `FNCCS4SVG` | VCL, FMX, LCL | `CADSaveSheetsToSVG`, `CADSaveSheetToSVGStream`, `TCADSVGGraphics` |
| EMF | `FNCCS4GDI` | VCL, FMX (Windows) | `CADSheetToEMF`, `CADModelRectToEMF`, `CADSaveSheetToEMF` |
| Clipboard | `FNCCS4GDI` | VCL, FMX (Windows) | `CADCopySheetToClipboardWin`, `CADCopyModelRectToClipboardWin` |
| Printer | `FNCCS4GDI` | VCL, FMX (Windows) | `CADPrintSheetsWin`, `CADPrintPagesWin` |
| Printer | `FNCCS4PrintFMX` | FMX | `CADPrintSheetsFMX`, `CADPrintPagesFMX`, `CADFMXPrinterPageDevice` |
| Printer, clipboard bitmap | `FNCCS4ExportVCL` | VCL | `CADPrintSheets`, `CADPrintPages` (Vcl.Printers), `CADCopyToClipboard` |

The unit names carry the framework prefix of the tree they were generated
into: `VCL.FNCCS4SVG`, `FMX.FNCCS4SVG`.

## Resolution

The drawing layer works in whole device pixels, so a file is laid out at a
resolution of its own and scaled: 600 dpi for the PDF (`CADPDFResolution`)
and the SVG (`CADSVGResolution`), where a coordinate is then rounded to a
twenty-fourth of a millimetre, and 2400 dpi for the EMF (`CADEMFResolution`,
or the `ADPI` parameter), because a metafile also rounds every glyph's advance
to a whole unit. A PNG is made at the
resolution asked for, 300 dpi by default, and refuses anything larger than
`CADImageMaxPixels` (80 million pixels) rather than run out of memory.

## PDF

One page per sheet, each at its sheet's own paper size and orientation. Fonts
are embedded and subset while `CADPDFEmbedFonts` is True; a font that is not
installed is replaced by the first of `CADPDFFontFallbacks` that is.

Link areas come from an optional function, asked once per sheet:

```pascal
CADSaveSheetsToPDF(CAD, CAD.Sheets, 'plan.pdf', 0, -1,
  function(const ASheet: TCADSheet; const AIndex: Integer): TCADPDFLinks
  begin
    { mm on the sheet, from its bottom-left corner }
    Result := [TCADPDFLink.Create(Rect2D(10, 20, 60, 40), 'https://example.com/plan')];
  end);
```

They are added to the finished file as an incremental update - see the header
of `FNCCS4PDF` for why.

Three things FNC's PDF engine gets wrong at 600 dpi are drawn by the library
instead: a dashed pen, as solid pieces whose length scales with the pen; a
gradient, as up to 256 bands of solid colour inside the shape's outline; and
turned text, rotated about its rectangle's centre in the page's own
coordinates. On paper and on screen they look as they should. A program that
edits the PDF sees bands, not one gradient object.

A colour's alpha reaches the page: a translucent fill, pen or text is drawn with
a graphics state of its own, and the rest of the page is as it would be. A
gradient's alpha is worked out per band, from the one colour's to the other's.

## PNG

On FMX the bitmap's own alpha is used, so a transparent image is exact. On the
VCL the drawing is made twice, on white and on black, and the alpha worked
out from the difference. A model rectangle is drawn at `AUnitsPerMM` drawing
units to the millimetre, as large as it would be on paper.

## SVG

The viewBox is the sheet in 600 dpi dots, and width and height carry the paper
size in millimetres. Runs of lines become one polyline, and gradients and clip
paths are shared through `defs`. SVG has no word wrap, so wrapped text is laid
out by the exporter, measured through FNC, one `tspan` per line. Pictures are
embedded as data URIs. The paper itself is not painted.

## EMF, the clipboard and printing on Windows

`TCADGDIGraphics` draws on a raw device context with no VCL in between, so FMX
gets the same metafile and printing the VCL has always had.

- **Metafile:** laid out at 2400 dpi and mapped onto a frame the paper's size.
  At 600 dpi small text played back with gaps inside words: GDI stores each
  glyph's advance as a whole number of the recording's units. A wrapped label
  that asks to be centred or bottom-aligned is measured and placed by the
  library, since GDI aligns only a single line.
  A one-pixel pen is a hairline that stays one pixel wherever the picture is
  played; wider pens are drawn to scale.
- **Clipboard:** the metafile, an SVG under `image/svg+xml` (while
  `CADClipboardSVG`; Office 365 pastes it first and renders it most
  faithfully) and a CF_DIB at `CADClipboardBitmapDPI` (150). No PNG unless
  `CADClipboardPNG` is set: Office pastes a PNG in preference to the
  metafile, so with one there a plain paste gave a bitmap.
- **Printing:** draws each page on the printer's own device context and sets
  each sheet's orientation and standard paper on its page, so portrait and
  landscape sheets print as one job. `AOutputFile` sends the output to a file
  instead, which a printer such as Microsoft Print to PDF saves without asking.
  `CADPrintSheetsFMX` prints on FMX's active printer through the same
  routines; copies and other settings made on FMX's printer object are not
  carried over.

## The viewport draw hook

`TFNCCADCmp2D.OnDrawSheetViewport` is called on every one of these routes, so
an application's per-viewport furniture (timescales, lane headers) appears in
all of them. See paper-space.md, section 11.
