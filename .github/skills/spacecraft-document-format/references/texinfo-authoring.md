# Texinfo — Canonical Prose Format (router note)

Texinfo is the canonical format for Spacecraft Software prose — manuals, references, guides, reports, specs, and books (SKILL.md §1, Standard §8). One `.texi` source compiles to plain text/Info, HTML, and PDF and converts to GFM, so structure and brand are defined once.

**The how-to is owned by the [`spacecraft-texinfo-document`](../../spacecraft-texinfo-document/SKILL.md) skill — load it.**
That skill is the execution layer beneath this router and covers everything mechanical:

- **Authoring** the canonical skeleton (`@dircategory`/`@direntry`, `@copying`, `@titlepage`, `@node Top`/`@top`, per-chapter `@menu`), with ready templates (`assets/template.texi`, `assets/software-manual.texi`).
- **Building** to Info/HTML/PDF (`makeinfo`/`texi2any`, `texi2pdf`) and the three `Makefile` targets.
- **Brand output** — the bundled `assets/spacecraft.css` (Void Navy `#000027`, Share Tech Mono headings, Inconsolata body, palette links) for HTML, and A4 + colour caveats for PDF.
- **Linting** node/menu errors, **converting** Markdown↔Texinfo, **packaging** (`install-info` hooks), and the Texinfo acceptance checklist.

This file carries only the **routing decisions** this skill (`spacecraft-document-format`) owns; do
not duplicate the `spacecraft-texinfo-document` how-to here.

## §A — When a Texinfo manual is the deliverable (Standard §8.1)

The router's call — *whether* a deliverable should be a manual at all:

| Project type | Requirement |
|---|---|
| CLI / TUI / GUI app with substantive user-facing functionality | **MUST** ship a Texinfo manual (invocation, options, concepts, examples) |
| Library with a public API | **SHOULD** ship a Texinfo reference manual covering all public interfaces |
| Simple script / internal tooling | **MAY** skip — a well-structured `README.md` suffices |

For software projects the manual lives at `doc/<project>.texi` (Standard §8.2). For standalone
document deliverables (a report, a book), place the `.texi` wherever the deliverable is organized.

## §B — Document-format glue (defer detail to the skill)

- **No mandatory `.md` companion.** A `.texi` is already diffable plain text, so the GFM-companion
  rule that binds ODF/MS-Office deliverables does **not** apply (SKILL.md §2). GFM is an *optional*
  generated output (`pandoc -f texinfo -t gfm`); produce it only on request.
- **Document-class licence.** A manual defaults to **`CC-BY-SA-4.0`**; **`GFDL-1.3-or-later`** is the
  permitted alternative when shipping alongside GPL software for GNU-collection compatibility
  (Standard §8.5). Details and the `@copying`/SPDX templates live in `spacecraft-texinfo-document`
  (`references/house-style.md`).
