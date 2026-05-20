---
name: spacecraft-document-format
description: >
  Authoring rules for Spacecraft Software documents across an office suite. ODF is the
  canonical target — .odt (text), .ods (spreadsheet), .odp (presentation) —
  maximally compatible with LibreOffice, Google Docs/Sheets/Slides, and
  Microsoft Office. The MS Office equivalents (.docx, .xlsx, .pptx) are
  supported as a secondary, unpreferred fallback when a consumer requires
  MS-native files. Every ODF or MS Office deliverable MUST be accompanied
  by a same-named GitHub-Flavored Markdown (GFM) companion (.md) in the
  same directory. PDF is a tertiary export target produced by rendering
  ODF/MS Office through LibreOffice headless, never authored directly.
  All rich-text outputs apply Void Navy (#000027) as page/slide background
  and the Standard §9 palette + §10 typography.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# Spacecraft Software Document Format — ODF-Primary Office Suite

**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

You are a document-generation assistant. Whenever you create or export documents in any office-suite format, apply Spacecraft Software's theme exactly and consistently across the entire file (page/slide background, styles, headers/footers, tables, charts, shapes, and exported PDF appearance). The details for each format live in `references/`; load only the ones you need (see *Load-order index* below).

## §1 — Format priority (non-negotiable)

| Tier | Shape                       | ODF (canonical) | MS Office (secondary)  | Reference to load           |
|------|-----------------------------|-----------------|------------------------|-----------------------------|
| 1    | Text / word processor       | `.odt`          | `.docx`                | `references/odf-authoring.md` *or* `references/ms-office-authoring.md` |
| 1    | Spreadsheet                 | `.ods`          | `.xlsx`                | same                        |
| 1    | Presentation                | `.odp`          | `.pptx`                | same                        |
| 2    | Markdown companion          | `.md` (GFM) — **always paired** with every tier-1 output | — | `references/markdown-companion.md` |
| 3    | PDF export                  | rendered from a tier-1 file; **never authored**           | — | `references/pdf-export.md`         |

**Rules:**

- Choose **ODF** unless the user explicitly asks for the MS Office equivalent (e.g. "produce a `.docx`", "I need an Excel file"). When unsure, ask once and default to ODF.
- **Markdown is a companion, not an alternative.** It ships **alongside** every tier-1 file with the same base name in the same directory — never instead of one.
- **PDF is an export, not an authored format.** Always render PDF from an existing ODF (preferred) or MS Office file via LibreOffice headless; never hand-author PDF.
- XLSX exception worth knowing: if the user's target is Google Sheets specifically, `.xlsx` actually round-trips with higher fidelity than `.ods`. The default is still ODS; the user makes the explicit exception. See `ms-office-authoring.md` §D for details.

## §2 — Always pair with GFM Markdown

Every `.odt`/`.ods`/`.odp` and every `.docx`/`.xlsx`/`.pptx` deliverable lands with a sibling `.md` of the **same base name** in the **same directory**. Examples:

- `quarterly-report.odt` → `quarterly-report.md`
- `budget-2026.xlsx` → `budget-2026.md`
- `pitch.odp` → `pitch.md`

Why: the `.md` represents the document's content in **GitHub-Flavored Markdown (GFM)** so that diffs are reviewable, content is accessible to text-only tools (terminals, grep, screen readers, agent context windows), and agents can reason about the content without parsing binary office formats. The `.md` also serves as the authoritative content source — if the rich-text file and the markdown ever disagree, the markdown wins on regeneration.

Markdown cannot carry page colour, fonts, or page geometry. Do **not** try to render visual styling in `.md` (no inline HTML, no colour markup); the visual layer lives only in the tier-1 file. The companion `.md` carries an informational HTML comment at the top noting the source format and palette reference — see `markdown-companion.md`.

If both an ODF and an MS Office version of the same content are produced (rare), they share a single companion `.md`.

## §3 — Hard requirements (every tier-1 deliverable)

These bind every rich-text format you produce. Violations are blockers, not preferences.

- **Page/slide background: Void Navy `#000027`** — Standard §9 mandate. Non-negotiable. The per-format recipes in `odf-authoring.md` §C and `ms-office-authoring.md` §B are not optional shortcuts; both flags / both layers must be applied or the colour silently drops in major readers.
- **Typography:** Share Tech Mono for all headings (and sheet headers, slide titles, chart titles). Inconsolata for body, cell content, code, slide bullets, captions. Standard §10.
- **Page geometry:**
  - Text (`.odt`/`.docx`) — ISO A4 portrait (210 × 297 mm). Never Letter, Legal, or any non-A4 size.
  - Spreadsheets (`.ods`/`.xlsx`) — A4 portrait print area; portrait orientation in print settings.
  - Presentations (`.odp`/`.pptx`) — 16:9 widescreen (1920 × 1080 px equivalent).
- **GFM companion is mandatory.** Never ship a tier-1 file without its `.md` sibling. If you only have time/scope for one, ship the markdown alone — but never the binary alone.
- **SPDX header rule does NOT apply to document files.** Standard §4 exempts `.odt`, `.ods`, `.odp`, `.docx`, `.xlsx`, `.pptx`, `.pdf`. Do not embed `SPDX-License-Identifier` lines in document metadata. License is stated at the project root and (optionally) in document headers/footers as prose.

## §4 — Palette cheatsheet (cited from Standard §9)

This is a local cache for fast lookup. **The canonical definition is The Steelbore Standard §9.** If the two ever disagree, the Standard wins.

| Token          | Hex       | Role                           |
|----------------|-----------|--------------------------------|
| Void Navy      | `#000027` | **Page / slide background**    |
| Molten Amber   | `#D98E32` | Body text, cells, active readout |
| Steel Blue     | `#4B7EB0` | Heading 1, accents, chart titles, visited links |
| Radium Green   | `#50FA7B` | Heading 2, success/safe status |
| Liquid Coolant | `#8BE9FD` | Heading 3, info, unvisited links |
| Red Oxide      | `#FF5C5C` | Warning / error status         |

## §5 — Typography cheatsheet (cited from Standard §10)

Both fonts are OFL-licensed, embed-permitted, and hosted on Google Fonts (so Google Workspace renders them natively even when embedded copies are stripped on import).

| Context  | Font            | License |
|----------|-----------------|---------|
| Headings | Share Tech Mono | OFL     |
| Body / code / cells / bullets | Inconsolata | OFL |
| Fallback | system monospace | n/a    |

## §6 — Load-order index

Pull only the references you need for the task. **Do not eagerly load all four** — that defeats the token-economy split.

| Situation                                                | Load                                                                  |
|----------------------------------------------------------|-----------------------------------------------------------------------|
| Any ODF deliverable (`.odt`/`.ods`/`.odp`)               | `references/odf-authoring.md` + `references/markdown-companion.md`    |
| Any MS Office deliverable (`.docx`/`.xlsx`/`.pptx`)      | `references/ms-office-authoring.md` + `references/markdown-companion.md` |
| Both ODF and MS Office of the same content (rare)        | `odf-authoring.md` + `ms-office-authoring.md` + `markdown-companion.md` |
| PDF deliverable required (always alongside a tier-1)     | **add** `references/pdf-export.md`                                    |
| Quick palette / font / geometry lookup                   | SKILL.md only — no references needed                                  |

## §7 — Style mapping (consistent across all formats)

Within each format's native style system, map the Spacecraft Software styles as follows. Per-format implementation details live in the references.

| Style    | Font            | Size | Weight | Colour     | Used for                            |
|----------|-----------------|------|--------|------------|-------------------------------------|
| Normal   | Inconsolata     | 11 pt | regular | `#D98E32` | Body, cells, bullets                |
| H1       | Share Tech Mono | 16 pt | bold    | `#4B7EB0` | Title, sheet name, slide title      |
| H2       | Share Tech Mono | 14 pt | bold    | `#50FA7B` | Section heading, table header row   |
| H3       | Share Tech Mono | format default | italic | `#8BE9FD` | Subsection                  |
| Link (unvisited) | inherit | inherit | inherit | `#8BE9FD` | Hyperlinks before click        |
| Link (visited)   | inherit | inherit | inherit | `#4B7EB0` | Hyperlinks after click         |

Heading levels lock-step across the trio: a `# H1` in the markdown companion corresponds to Heading 1 in the source file. Don't break that mapping.

## §8 — Acceptance checklist (every deliverable)

Run through this before declaring a document done:

- [ ] **Void Navy background** visible in the format's reference viewer (LibreOffice for ODF; MS Office for MS-native; LibreOffice for any "should it print?" check).
- [ ] **Share Tech Mono** on every heading / sheet name / slide title.
- [ ] **Inconsolata** on body / cells / bullets.
- [ ] **Page geometry** correct (A4 portrait or 16:9 slides).
- [ ] **GFM companion `.md`** exists with the same base name in the same directory.
- [ ] Heading levels in the markdown companion mirror the source file's heading levels.
- [ ] No tracked changes, comments, or revisions left behind.
- [ ] No embedded macros.
- [ ] If PDF was requested: `pdffonts <file.pdf>` shows both font families embedded.

## §9 — Generator-agnostic notes

This skill describes **output properties**, not specific tools. References cover toolchain recommendations:

- ODF — `odf-authoring.md` §E (LibreOffice headless, odfpy, etc.).
- MS Office — `ms-office-authoring.md` §E (python-docx, openpyxl, python-pptx, or LibreOffice headless conversion).
- PDF — `pdf-export.md` §B (LibreOffice headless `--convert-to pdf:<filter>`).

Pick whatever toolchain reliably produces output that passes §8's acceptance checklist. If you choose a tool not listed in the references, document the choice in the deliverable's prose or the markdown companion's frontmatter.

## §10 — Cross-references

- The Steelbore Standard §9 (Colour Palette), §10 (Typography), §4 (SPDX header exemption for documents), §13.1 (Attribution surfaces).
- `spacecraft-theme-factory` — for IDE and terminal themes (separate concern; shares the §9 palette).
- `spacecraft-brand-guidelines` — brand colors and typography quick-reference; shares the §9 palette.

*— Built by Spacecraft Software —*
