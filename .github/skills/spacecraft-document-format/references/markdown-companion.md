# Markdown Companion — GFM Required

Reference for the **always-paired** `.md` companion file that ships alongside every Spacecraft Software office-suite deliverable. Load this whenever you load `odf-authoring.md` or `ms-office-authoring.md`.

The Markdown flavour is **GitHub-Flavored Markdown (GFM)** — fixed by skill choice. No other dialect.

## §A — The pairing rule

Every tier-1 deliverable (any `.odt`/`.ods`/`.odp` or `.docx`/`.xlsx`/`.pptx`) MUST ship with a sibling `.md` of the **same base name** in the **same directory**.

| Source file        | Companion file   |
|--------------------|------------------|
| `quarterly-report.odt` | `quarterly-report.md` |
| `quarterly-report.docx` | `quarterly-report.md` |
| `budget-2026.ods`  | `budget-2026.md` |
| `budget-2026.xlsx` | `budget-2026.md` |
| `pitch.odp`        | `pitch.md`       |
| `pitch.pptx`       | `pitch.md`       |

If both ODF and MS-Office versions of the same content are produced (rare — only when a consumer explicitly requested both), they share **one** companion `.md`. The `.md` describes the *content*, not the binary file's format.

**Why pair:**

- Diffable in version control. Binary office files are opaque to `git diff`; markdown is plain text.
- Accessible to text-only tooling: terminals, `grep`, `rg`, screen readers, agent context windows.
- Agent-readable. LLMs reason about document content much better with markdown than by extracting text from a `.docx` blob.
- Source of truth for regeneration. If the rich-text file and the markdown ever diverge during edits, **the markdown wins** on the next regeneration pass.

**Never:**

- Ship a tier-1 file without its `.md` sibling.
- Ship a `.md` with a different base name from its source file.
- Put the `.md` in a separate directory from its source.

## §B — GFM scope

**In scope** (use freely):

- ATX-style headings (`# H1`, `## H2`, `### H3`) — never Setext (`===` / `---` underlines).
- **GFM tables** — pipe syntax with header row + separator row.
- Fenced code blocks with language hints (` ```python `, ` ```sh `, etc.).
- Task lists (`- [ ]` / `- [x]`).
- Strikethrough (`~~text~~`).
- Footnotes (`[^1]` / `[^1]: footnote body`).
- Autolinks (`<https://example.com>`).
- Emphasis (`*italic*` or `_italic_`) and strong (`**bold**` or `__bold__`).
- Blockquotes (`> …`) — used for speaker notes in slide companions, see §D.3.
- Unordered lists (`- ` preferred over `*`) and ordered lists (`1. `).
- Inline code (`` `code` ``).

**Out of scope** (don't use):

- Raw HTML beyond the single metadata comment in §C — keeps the markdown clean and portable.
- Math notation (LaTeX `$…$` etc.) — GFM doesn't render math universally; if the source doc has math, transcribe it as fenced code with a `math` lang hint or describe in prose.
- Inline styles or colour markup — markdown has no place for visual styling; the visual layer lives in the source rich-text file.
- Setext headings, hard line breaks via trailing double-space, indented (non-fenced) code blocks — all legacy CommonMark forms that GFM tolerates but render inconsistently.
- HTML tables — GFM tables are the only acceptable table syntax in Spacecraft Software markdown.

State the flavour explicitly in the metadata comment (§C) so renderers and reviewers know the target.

## §C — Mandatory metadata comment

Every Spacecraft Software companion `.md` begins with an HTML comment immediately after any optional YAML frontmatter:

```markdown
<!-- Spacecraft Software document — companion to quarterly-report.odt
     Palette: Standard §9 (Void Navy background, Molten Amber body)
     Typography: Share Tech Mono headings, Inconsolata body
     Format: GitHub-Flavored Markdown (GFM) -->

# Quarterly Report

...
```

The comment is **informational** — every GFM renderer ignores it; humans and agents reading the source see the source-file reference and the brand metadata. This is the only HTML the companion should contain.

For Google-Workspace-targeted DOCX (where the background drops on import — see `ms-office-authoring.md` §D), add a line to the comment so the user isn't surprised:

```
     Note: companion to a .docx targeted at Google Docs.
     Void Navy background may not survive Google's DOCX import; the .md is the
     authoritative content. Re-render via LibreOffice → ODT for full fidelity. -->
```

## §D — Content-shape mapping

The companion's structure mirrors the source content. Three shapes; three patterns.

### §D.1 — Text companion (for `.odt` / `.docx`)

Straightforward prose conversion. Heading levels lock-step (see §E):

```markdown
# Document Title          <!-- mirrors Heading 1 / first H1 in the source -->

## Section Heading        <!-- Heading 2 -->

### Subsection            <!-- Heading 3 -->

Body paragraph in plain prose, using Inconsolata in the source. Inline
`code` or **emphasis** as needed.

| Header A | Header B |
|----------|----------|
| Row 1 A  | Row 1 B  |
| Row 2 A  | Row 2 B  |

```python
# fenced code matches source's code blocks
def example(): pass
```

> Blockquote mirrors source's quote style.
```

### §D.2 — Spreadsheet companion (for `.ods` / `.xlsx`)

Each worksheet becomes one ATX `# Heading` (the sheet name), followed by a single GFM table representing the used cell range. Header row + separator row.

```markdown
# Sheet1 — Q1 Revenue

| Region | Jan      | Feb      | Mar      | Total    |
|--------|----------|----------|----------|----------|
| North  | 12,400   | 13,200   | 14,100   | 39,700   |
| South  | 8,900    | 9,400    | 9,800    | 28,100   |
| West   | 15,300   | 16,100   | 17,200   | 48,600   |

```formula
Total = SUM(Jan:Mar)
North!Q1 = 12400 + 13200 + 14100
```

# Sheet2 — Q1 Expenses

| Category | Jan    | Feb    | Mar    |
|----------|--------|--------|--------|
| Payroll  | 6,200  | 6,200  | 6,400  |
| Cloud    | 1,100  | 1,150  | 1,200  |
```

**Formulas** that matter to the reader go in a fenced code block (lang hint `formula` or `excel` — neither renders specially in GFM, both are clear to humans) immediately after the table. Don't try to encode them in the table cells; the rendered values are what most readers want.

**Charts** in the source spreadsheet don't translate to markdown. Describe them in prose under the sheet's heading: "Chart: clustered column of revenue by region, sorted by Q1 total descending." If the chart's data is in the table, the prose is enough.

### §D.3 — Presentation companion (for `.odp` / `.pptx`)

Each slide becomes one ATX `## Slide N: <title>` heading. Bullets become a GFM bullet list. Speaker notes go into a `> blockquote` immediately below the bullets.

```markdown
# Pitch — Spacecraft Software 2026

## Slide 1: The Problem

- Stale agent skills break consumer installs silently
- Manual bundle rebuilds get skipped under deadline pressure
- No single source of truth for cross-agent skill loading

> Speaker notes: open with the audit-failure incident from Q4 2025.
> Reference the 11-skill rebuild as a recurring time sink.

## Slide 2: Construct (the rebrand)

- Home Manager provisions per-harness skill paths declaratively
- Per-skill symlinks chain through the Nix store to `/spacecraft-software/construct/<skill>`
- Paths covered: `~/.claude/skills/`, `~/.codex/skills/`, `~/.ai/skills/`, `~/.agent/skills/`

> Speaker notes: Matrix reference for the brand. Walk through the
> symlink topology diagram in slide 3 before clicking through.

## Slide 3: Topology

![Symlink fan-out diagram showing Home Manager at the root, with
 per-harness skill paths each holding per-skill symlinks that
 resolve through the Nix store to /spacecraft-software/construct/.](slide-3-topology.png)
```

**Image slides** include a markdown image link with relative path (the image file ships alongside the deck) and alt text describing what's shown. Don't try to inline base64-encoded images — bloats the diff and most agents can't read them.

**Slide titles** in the source presentation map to the `## Slide N: <title>` heading. If the slide has no title, use `## Slide N` alone.

## §E — Heading-level lockstep

Heading levels in the markdown companion mirror the source file's heading levels exactly:

| Markdown | ODF/MS Office style | Notes |
|----------|---------------------|-------|
| `# H1`   | Heading 1 / Title / Sheet name / First-slide title | Top of the document |
| `## H2`  | Heading 2 / Section / Slide title | Major section |
| `### H3` | Heading 3 / Subsection | Subsection |
| `#### H4`+ | Heading 4+ | Discouraged but allowed if the source uses them |

**Never skip a level** in either direction. If the source has Heading 1 → Heading 3 with no Heading 2 between them, that's a source-file bug; flag it in the prose or fix the source.

**Document title vs. first heading**: in a text doc, the document title is the first `# H1` in the companion. In a spreadsheet companion, the file-level title (if any) is the document-level concept; each sheet gets a `# H1`. In a presentation companion, the deck title is a `# H1` and each slide is a `## H2` — see §D.3 example.

## §F — Optional YAML frontmatter

YAML frontmatter is **optional** and used only when the document is part of a longer documentation set with consistent metadata (e.g. a multi-deliverable project where authors / dates / versions need to be machine-readable across files). Don't add it for one-off deliverables.

When used, place it **before** the metadata HTML comment:

```markdown
---
title: Quarterly Report — Q1 2026
author: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
date: 2026-03-31
version: 1.0
source-format: odt
---

<!-- Spacecraft Software document — companion to quarterly-report.odt
     Palette: Standard §9 (Void Navy background, Molten Amber body)
     Typography: Share Tech Mono headings, Inconsolata body
     Format: GitHub-Flavored Markdown (GFM) -->

# Quarterly Report — Q1 2026
```

Date format follows Standard §12.1: ISO 8601 (`YYYY-MM-DD`).

## §G — Acceptance checklist (markdown companion)

In addition to SKILL.md §8 (general acceptance):

- [ ] File exists at `<source-basename>.md` in the same directory as the source.
- [ ] Opens with the mandatory HTML metadata comment naming the source file, palette, typography, and GFM format.
- [ ] Heading levels mirror the source file's structure exactly.
- [ ] Tables are GFM-syntax (pipe + separator), not HTML.
- [ ] No raw HTML beyond the metadata comment.
- [ ] No colour or inline-style markup.
- [ ] Renders cleanly on GitHub (drop the file into a gist if in doubt).
- [ ] All cross-references (footnotes, image links) resolve.
