# PDF Export — Tertiary Target

Reference for producing PDF deliverables under the Spacecraft Software document-format skill. Load this **only when a PDF is requested**, in addition to whichever authoring reference produced the source file.

PDF is **not an authored format** in Spacecraft Software. Always render PDF from an existing tier-1 file (preferably ODF; alternatively MS Office) via LibreOffice headless.

## §A — Why PDF is export-only

- Hand-authoring PDF (e.g. via `reportlab`, raw PDF op streams) loses the structural/style mapping that the source file enforces — embedded font references, accessibility tags, and the Standard §9 palette become decorative-only.
- LibreOffice's PDF exporter is mature: it preserves the page/slide background, embeds OFL fonts, supports PDF/A archival profiles, and produces tagged PDF for accessibility.
- A regenerated PDF always traces back to a versionable source file (the `.odt`/`.ods`/`.odp` or its MS-Office equivalent). Hand-authored PDF has no clean re-edit path.

The companion GFM `.md` for the **source file** is still mandatory (SKILL.md §2). The PDF is an additional deliverable, not a replacement for either the source file or the markdown companion.

## §B — Export commands per shape

LibreOffice headless converts via shape-specific export filters. The filter name encodes the application (Writer / Calc / Impress); pick the right one for the source shape or you get LibreOffice's heuristic guess (which is usually right but not always).

### `.odt` / `.docx` → PDF

```sh
soffice --headless --convert-to pdf:writer_pdf_Export \
        --outdir build/ \
        report.odt
```

Produces `build/report.pdf`. The `writer_pdf_Export` filter preserves page background, page geometry, embedded fonts, and hyperlinks. Heading styles become PDF bookmarks (navigation tree on the left in most readers).

### `.ods` / `.xlsx` → PDF

```sh
soffice --headless --convert-to pdf:calc_pdf_Export \
        --outdir build/ \
        budget-2026.ods
```

Each used range becomes one PDF page. Set the print area in the source file (via LibreOffice GUI or `<table:database-range>` XML) before exporting if you want to constrain which cells appear. Without a print area, LibreOffice exports the entire used range, paginating as needed.

### `.odp` / `.pptx` → PDF

```sh
soffice --headless --convert-to pdf:impress_pdf_Export \
        --outdir build/ \
        pitch.odp
```

One slide → one PDF page. 16:9 slide geometry maps cleanly to a landscape PDF page. Speaker notes are NOT included by default; pass the `ExportNotes` filter option (see §C) to include them.

## §C — PDF/A flag (archival contexts)

For long-term archival (regulatory filings, board minutes, anything that must survive a decade unchanged), use the PDF/A subset:

```sh
soffice --headless \
        --convert-to 'pdf:writer_pdf_Export:{"SelectPdfVersion":{"type":"long","value":"1"}}' \
        --outdir build/ \
        report.odt
```

PDF version values for the `SelectPdfVersion` key:

| Value | Profile         | Notes                                          |
|-------|-----------------|------------------------------------------------|
| `0`   | PDF 1.x default | LibreOffice default; not archival              |
| `1`   | PDF/A-1         | Older archival profile; widely supported       |
| `2`   | PDF/A-2         | More features (layers, JPEG 2000); preferred for new work |
| `3`   | PDF/A-3         | Allows embedded source files (the original `.odt`/`.xlsx` inside the PDF) |

For Spacecraft Software archival deliverables, **PDF/A-2** is the default. Use PDF/A-3 only when you want to embed the source file alongside the PDF (useful for fully-self-contained legal submissions; otherwise unnecessary overhead).

Other useful filter options (combine with the JSON above using a comma-separated key/value list):

| Key                  | Type    | Purpose                                         |
|----------------------|---------|-------------------------------------------------|
| `ExportNotes`        | boolean | Include presenter notes (for Impress only)      |
| `ExportNotesPages`   | boolean | Render speaker-notes as separate pages          |
| `Tagged`             | boolean | Produce tagged (accessible) PDF — set `true`    |
| `EmbedStandardFonts` | boolean | Force embedding of the 14 standard PDF fonts even if not strictly necessary — set `true` for archival |
| `UseLosslessCompression` | boolean | Preserve image fidelity (recommended for slide decks with diagrams) |

Example for an archival Impress deck with notes:

```sh
soffice --headless \
        --convert-to 'pdf:impress_pdf_Export:{"SelectPdfVersion":{"type":"long","value":"2"},"ExportNotesPages":{"type":"boolean","value":"true"},"Tagged":{"type":"boolean","value":"true"}}' \
        --outdir build/ \
        pitch.odp
```

## §D — Font embedding verification

LibreOffice embeds fonts in PDF by default, but always verify post-export:

```sh
pdffonts build/report.pdf
```

Expected output (excerpt):

```
name                                 type              encoding         emb sub uni
------------------------------------ ----------------- ---------------- --- --- ---
ABCDEF+ShareTechMono                 TrueType          WinAnsi          yes yes yes
GHIJKL+Inconsolata                   TrueType          WinAnsi          yes yes yes
```

The `emb yes` column on both Share Tech Mono and Inconsolata is the pass condition. If either reads `no`, the PDF will render with a fallback font on systems missing the originals — visually wrong on Spacecraft Software deliverables.

If a font shows `emb no`, re-export with `EmbedStandardFonts` set true, or check that the source file actually embeds the font (per `odf-authoring.md` §D / `ms-office-authoring.md` §C). Source-file font references that point at system paths instead of bundled `.ttf` files break embedding silently.

## §E — Page/slide background fidelity in PDF

- **From ODF**: Void Navy survives the export verbatim. Verify visually on page 1.
- **From DOCX**: requires both `w:background` and `w:displayBackgroundShape` to be present in the source DOCX. If LibreOffice opens the DOCX with a blank background (because the source lacks `displayBackgroundShape`), the PDF also has a blank background. Fix the source, not the PDF.
- **From XLSX**: cell fills survive; the area outside the used range is blank (white) in the PDF. Set a print area that exactly covers the Void Navy cells.
- **From PPTX**: slide-master + per-layout backgrounds survive. If a single slide renders blank, the corresponding slide-layout XML is missing the `<p:bg>` block (see `ms-office-authoring.md` §B.3).

On older LibreOffice releases (< 7.0), MS-Office backgrounds sometimes flatten to a foreground rectangle behind text in the PDF export. Verify visually; upgrade LibreOffice if it persists.

## §F — Acceptance checklist (PDF export)

In addition to SKILL.md §8 (general acceptance):

- [ ] `pdffonts <file.pdf>` shows `emb yes` for both Share Tech Mono and Inconsolata.
- [ ] Visual check: Void Navy visible on every page / slide.
- [ ] If archival: PDF/A profile selected (`pdfinfo <file.pdf>` shows `PDF version: 1.4` or `1.7` with conformance noted; alternatively `verapdf` for strict PDF/A validation).
- [ ] If tagged: accessibility tree present (open in Acrobat or `pdftotext -layout` produces clean reading order).
- [ ] No fallback-font warnings in the LibreOffice export log.
- [ ] The source file (`.odt` / `.ods` / etc.) and its GFM companion `.md` are still committed alongside the PDF — the PDF is an addition, not a replacement.
