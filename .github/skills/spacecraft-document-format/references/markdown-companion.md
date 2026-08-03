# Markdown Companion — Pairing Policy

Reference for the **always-paired** `.md` companion that ships alongside every Spacecraft Software
office-suite deliverable. Load this whenever you load `odf-authoring.md` or `ms-office-authoring.md`.

**GFM element syntax/scope is owned by the
[`spacecraft-markdown-document`](../../spacecraft-markdown-document/SKILL.md) skill — load it** for
element-level rules (headings, tables, task lists, fenced code, links, the audit checklist; details in
its `references/gfm-elements.md`). The flavour is **GitHub-Flavored Markdown (GFM)**, no other dialect.

This file defines only the **companion-pairing policy** that `spacecraft-document-format` owns: which
file pairs with which, the canonical metadata comment, and how office content shapes map to GFM.

## §A — The pairing rule

Every tier-1 deliverable (any `.odt`/`.ods`/`.odp` or `.docx`/`.xlsx`/`.pptx`) MUST ship with a
sibling `.md` of the **same base name** in the **same directory**.

| Source file        | Companion file   |
|--------------------|------------------|
| `quarterly-report.odt` / `.docx` | `quarterly-report.md` |
| `budget-2026.ods` / `.xlsx`  | `budget-2026.md` |
| `pitch.odp` / `.pptx`        | `pitch.md`       |

If both ODF and MS-Office versions of the same content are produced (rare — only when a consumer
explicitly requested both), they share **one** companion `.md`. The `.md` describes the *content*,
not the binary's format.

**Why pair:** diffable in version control (binary office files are opaque to `git diff`); accessible
to text-only tooling (terminals, `rg`, screen readers, agent context windows); agent-readable; and the
**source of truth on regeneration — if the rich-text file and the markdown diverge, the markdown wins.**

**Never:** ship a tier-1 file without its `.md` sibling; give the `.md` a different base name; or put
it in a separate directory from its source.

## §B — Canonical companion metadata comment

Every Spacecraft Software companion `.md` opens with this HTML comment (immediately after any optional
YAML frontmatter). **This is the single authoritative companion-comment format** — the
`spacecraft-markdown-document` skill (§5) defers to it:

```markdown
<!-- Spacecraft Software document — companion to quarterly-report.odt
     Palette: Standard §11 (Void Navy background, Platinum Mist body)
     Typography: Share Tech Mono headings, Inconsolata body
     Format: GitHub-Flavored Markdown (GFM) -->

# Quarterly Report
```

The comment is informational (every GFM renderer ignores it) and is the **only** HTML the companion
should contain. For Google-Workspace-targeted DOCX (where the background drops on import — see
`ms-office-authoring.md` §D), add a line noting that the `.md` is the authoritative content and full
fidelity comes from re-rendering via LibreOffice → ODT.

## §C — Content-shape mapping (office → GFM)

The companion mirrors the source content. Three shapes:

- **Text** (`.odt`/`.docx`) — straight prose conversion; heading levels lock-step with the source
  (§D). Body paragraphs, GFM tables, fenced code, and blockquotes mirror the source.
- **Spreadsheet** (`.ods`/`.xlsx`) — each worksheet becomes one `#` heading (the sheet name) followed
  by a single GFM table of the used cell range. Formulas that matter go in a fenced block (lang hint
  `formula`/`excel`) after the table; charts are described in prose under the sheet heading.
- **Presentation** (`.odp`/`.pptx`) — deck title is `# H1`; each slide is `## Slide N: <title>`;
  bullets become a GFM list; **speaker notes go in a `>` blockquote** below the bullets; image slides
  use a markdown image link (relative path, meaningful alt text), never inline base64.

## §D — Heading-level lockstep

Heading levels in the companion mirror the source exactly: `# H1` = Heading 1 / Title / Sheet name /
first-slide title; `## H2` = Heading 2 / Section / Slide title; `### H3` = Heading 3 / Subsection;
`####`+ discouraged but allowed if the source uses them. **Never skip a level** — if the source jumps
Heading 1 → Heading 3, that's a source bug; flag it or fix the source.

## §E — Acceptance checklist (companion)

In addition to SKILL.md §8 (general acceptance):

- [ ] File exists at `<source-basename>.md` in the same directory as the source.
- [ ] Opens with the §B canonical metadata comment (source file, palette, typography, GFM format).
- [ ] Heading levels mirror the source structure exactly.
- [ ] Tables are GFM-syntax (pipe + separator), not HTML; no raw HTML beyond the metadata comment.
- [ ] No colour or inline-style markup.
- [ ] Element-level GFM conformance per `spacecraft-markdown-document` (renders cleanly on GitHub).
- [ ] All cross-references (footnotes, image links) resolve.
