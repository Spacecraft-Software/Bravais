# Microsoft Office Authoring — Secondary Path

Reference for producing `.docx` (Word), `.xlsx` (Excel), and `.pptx` (PowerPoint) deliverables under the Spacecraft Software document-format skill. Load this **only when an MS Office format is explicitly requested**, alongside `markdown-companion.md`.

The default is always ODF (see `odf-authoring.md`). This reference exists for the carve-out cases: legal filings, corporate submission portals, recipients without LibreOffice, or Google-Workspace targets where MS Office actually round-trips better than ODF.

## §A — When to use (and when not to)

**Use the MS Office form when:**

- The consumer's submission portal accepts only `.docx`/`.xlsx`/`.pptx` (common in legal, finance, gov).
- The target is **Google Sheets specifically** — `.xlsx` round-trips with higher fidelity than `.ods` through Google's importer (cell fills, conditional formatting, chart styles all survive more cleanly).
- The target is **Google Slides specifically** — `.pptx` round-trips with higher fidelity than `.odp` (slide background, master themes, custom fonts).
- The recipient is known to use MS Office offline and you want to avoid the small Word-opens-ODT fidelity drift.

**Do NOT use the MS Office form when:**

- No constraint forces it. Default to ODF.
- The target is Google Docs specifically — Google's DOCX importer drops `w:background` more often than it preserves it (see §D); ODT is more reliable for Google Docs.
- The deliverable is archival — ODF's ISO-standardised stability is preferable.

Every MS Office deliverable still requires its GFM companion `.md` (see SKILL.md §2 and `markdown-companion.md`).

## §B — Background recipe per MS Office shape

The Void Navy `#000027` mandate (Standard §9) requires per-format care; the obvious property is necessary but not sufficient in any of the three formats.

### §B.1 — `.docx` (Word)

`.docx` is a zip of XML parts. The Void Navy background requires **two** edits, not one:

1. In `word/document.xml`, inside `<w:document>`:
   ```xml
   <w:background w:color="000027"/>
   ```
   (Hex without the `#` prefix; that's the OOXML convention.)

2. In `word/settings.xml`, add:
   ```xml
   <w:displayBackgroundShape/>
   ```

**Without the `<w:displayBackgroundShape/>` flag, Word hides the background in Print Layout view on ~80% of installs.** This is the most common Spacecraft Software-DOCX gotcha — the file *opens* showing Void Navy in Web Layout but flips to white in Print Layout, and most users default to Print Layout. Both flags or neither.

Verify by saving the file, closing Word, reopening in Print Layout — Void Navy must be visible.

### §B.2 — `.xlsx` (Excel)

XLSX has no native "sheet background colour" property the way HTML does. Two paths exist; use **path 1** for Spacecraft Software work:

**Path 1 (preferred):** Apply `<fill>` to every used cell range via a named style. In `xl/styles.xml`:

```xml
<fills count="2">
  <fill><patternFill patternType="none"/></fill>
  <fill>
    <patternFill patternType="solid">
      <fgColor rgb="FF000027"/>
      <bgColor indexed="64"/>
    </patternFill>
  </fill>
</fills>
```

(OOXML uses `AARRGGBB` with full alpha — `FF` prefix is required.)

Then reference fill index `1` in your cell `<xf>` styles. Every used cell gets the Void Navy fill applied. This survives:
- Print/export to PDF.
- CSV round-trip (the colour is lost in CSV but the structural data is preserved; on re-import to Excel, you re-apply the Spacecraft Software template).
- Google Sheets import (Google Sheets reads `<fill patternType="solid">` correctly).

**Path 2 (legacy, don't use):** Set a 1×1 PNG of `#000027` as the sheet background image via `<sheetView>` → `<picture>`. This is the only way to colour the area *outside* the used cell range, but it doesn't print, isn't displayed in print preview, and Google Sheets ignores it. Skip.

Also set the sheet tab colour to a Spacecraft Software accent (`#4B7EB0` Steel Blue is the default choice) via `<sheetPr><tabColor rgb="FF4B7EB0"/></sheetPr>` in each sheet's XML — cosmetic but matches the brand.

### §B.3 — `.pptx` (PowerPoint)

PPTX requires the background to be set on the **slide master** AND on **each slide layout**, because PowerPoint overrides at the slide level if any layout declares its own background.

In `ppt/slideMasters/slideMaster1.xml`:

```xml
<p:cSld>
  <p:bg>
    <p:bgPr>
      <a:solidFill>
        <a:srgbClr val="000027"/>
      </a:solidFill>
    </p:bgPr>
  </p:bg>
  <!-- ... rest of master content ... -->
</p:cSld>
```

Repeat the `<p:bg>...</p:bg>` block in every `ppt/slideLayouts/slideLayoutN.xml`. If any layout omits it, slides using that layout default back to white.

Slide size: 16:9 widescreen. In `ppt/presentation.xml`:

```xml
<p:sldSz cx="12192000" cy="6858000"/>
```

(EMU units: 12 192 000 × 6 858 000 = 13.333" × 7.5" = 1920 × 1080 px at 144 dpi.)

## §C — Typography setup per shape

Share Tech Mono and Inconsolata both ship with permissive `fsType` (Installable Embedding allowed), so embedding into MS Office files is licensed.

### `.docx`

In `word/fontTable.xml`:

```xml
<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:font w:name="Share Tech Mono">
    <w:panose1 w:val="020B0506050000020004"/>
    <w:charset w:val="00"/>
    <w:family w:val="modern"/>
    <w:pitch w:val="fixed"/>
    <w:embedRegular r:id="rIdShareTechMono"/>
  </w:font>
  <w:font w:name="Inconsolata">
    <w:panose1 w:val="020B0506050000020004"/>
    <w:charset w:val="00"/>
    <w:family w:val="modern"/>
    <w:pitch w:val="fixed"/>
    <w:embedRegular r:id="rIdInconsolata"/>
  </w:font>
</w:fonts>
```

Reference the relationship IDs in `word/_rels/fontTable.xml.rels`, pointing at the actual `.ttf` files under `word/fonts/`.

Then map paragraph styles in `word/styles.xml`:

```xml
<w:style w:type="paragraph" w:styleId="Heading1">
  <w:name w:val="heading 1"/>
  <w:rPr>
    <w:rFonts w:ascii="Share Tech Mono" w:hAnsi="Share Tech Mono"/>
    <w:b/>
    <w:color w:val="4B7EB0"/>
    <w:sz w:val="32"/>  <!-- OOXML uses half-points; 32 = 16pt -->
  </w:rPr>
</w:style>
```

### `.xlsx`

In `xl/styles.xml`, declare the fonts and reference them by index in `<xf>` cell formats:

```xml
<fonts count="3">
  <font><sz val="11"/><name val="Inconsolata"/><color rgb="FFD98E32"/></font>
  <font><sz val="16"/><b/><name val="Share Tech Mono"/><color rgb="FF4B7EB0"/></font>
  <font><sz val="14"/><b/><name val="Share Tech Mono"/><color rgb="FF50FA7B"/></font>
</fonts>
```

XLSX does not natively support font embedding the way DOCX does — readers fall back to system fonts. Both Spacecraft Software fonts are on Google Fonts and ship with most Linux distros; readers without them get the system monospace fallback (acceptable).

### `.pptx`

In `ppt/theme/theme1.xml`, the `<a:fontScheme>` element defines major/minor fonts:

```xml
<a:fontScheme name="Spacecraft Software">
  <a:majorFont>
    <a:latin typeface="Share Tech Mono"/>
  </a:majorFont>
  <a:minorFont>
    <a:latin typeface="Inconsolata"/>
  </a:minorFont>
</a:fontScheme>
```

PPTX supports font embedding via the `<p:embeddedFontLst>` element in `ppt/presentation.xml`. Embed both fonts for archival robustness.

## §D — Cross-suite caveats

| Format  | LibreOffice                  | Google (Docs/Sheets/Slides)                                                | MS Office                                |
|---------|------------------------------|----------------------------------------------------------------------------|------------------------------------------|
| `.docx` | Opens cleanly, high fidelity | **Background often stripped** — Google treats `w:background` as watermark-only in ~40% of imports. ODT is more reliable for Google Docs. | Works as expected when both `w:background` + `w:displayBackgroundShape` are present |
| `.xlsx` | Opens cleanly                | **Cell fills imported correctly** — better than `.ods` import. Conditional formatting + charts also better preserved. | Works as expected |
| `.pptx` | Opens cleanly                | **Slide background imported correctly** — better than `.odp` import. Master themes survive. | Works as expected |

The asymmetry: Google's DOCX importer is older and more lossy; the XLSX and PPTX importers are newer and more faithful. This is why `.xlsx`/`.pptx` is the explicit recommendation when the target is Google Sheets/Slides.

## §E — Recommended toolchain per shape

### `.docx`

1. **`python-docx`** — predictable API, full styling support. Best for hand-rolled DOCX.
2. **`soffice --headless --convert-to docx <input.odt>`** — converts a known-good ODT (built per `odf-authoring.md`) into DOCX. Round-trips Spacecraft Software styles cleanly because LibreOffice's DOCX writer is mature. Recommended when an ODT version already exists.
3. **`docx` (JavaScript/Node)** — usable but the styling API is more verbose than python-docx.

After generation, **verify the settings.xml flag is present** — every other DOCX library forgets it:

```sh
unzip -p output.docx word/settings.xml | grep -c displayBackgroundShape
# expect: 1 (or higher)
```

If the grep returns 0, patch the settings.xml manually or your background won't render in Word.

### `.xlsx`

1. **`openpyxl`** (Python) — cell-level fill control is straightforward. Supports `PatternFill(fill_type='solid', start_color='FF000027', end_color='FF000027')`.
2. **`soffice --headless --convert-to xlsx <input.ods>`** — converts a Spacecraft Software ODS into XLSX. Cell fills survive cleanly.
3. **`xlsxwriter`** — alternative to openpyxl; slightly different API surface, similar capability.

### `.pptx`

1. **`python-pptx`** — most predictable for slide-master and per-slide background control. Use `pptx.dml.color.RGBColor.from_string('000027')` for fills.
2. **`soffice --headless --convert-to pptx <input.odp>`** — converts a Spacecraft Software ODP into PPTX. Master + layout backgrounds round-trip.

## §F — Pitfalls and gotchas

- **Forgotten `w:displayBackgroundShape` in DOCX** — the #1 Spacecraft Software-DOCX bug. Always verify post-generation.
- **PPTX layout overrides** — setting the background on the master alone is not enough if any layout XML omits it. Set on the master and on every layout you use.
- **XLSX cell-fill vs sheet-image** — only cell-fill works for print. Don't waste time on the legacy sheet-image path.
- **OOXML hex format** — uses `AARRGGBB` (with alpha). `#000027` becomes `FF000027`. Omitting the alpha prefix produces a transparent fill that renders as white.
- **Font availability on the reader's machine** — XLSX doesn't embed fonts; Inconsolata and Share Tech Mono fall back to system monospace if missing. Acceptable because both fonts are pre-installed on Spacecraft Software hosts and Google Fonts handles the web/Google Workspace case.

## §G — Acceptance checklist (MS Office deliverables)

In addition to SKILL.md §8 (general acceptance), specifically for MS Office:

- [ ] **DOCX**: `unzip -p <file>.docx word/document.xml | grep w:background` returns the Void Navy hex; `unzip -p <file>.docx word/settings.xml | grep displayBackgroundShape` returns 1+ hit.
- [ ] **XLSX**: `unzip -p <file>.xlsx xl/styles.xml | grep '000027'` returns ≥ 1 hit (the cell-fill rule); the visible used range is Void Navy when opened in Excel.
- [ ] **PPTX**: every slide master + slide layout has a `<p:bg>` block with `srgbClr val="000027"`; slide size matches 16:9 (12192000 × 6858000 EMU).
- [ ] Open in MS Office (if available) → Void Navy visible in Print Layout / Print Preview / Slideshow.
- [ ] Open in LibreOffice → same visual result.
- [ ] For Google-targeted DOCX: known compromise — background may drop. Surface this in the markdown companion's metadata comment so the user isn't surprised.
- [ ] GFM companion `.md` exists with the same base name (cross-reference `markdown-companion.md`).
