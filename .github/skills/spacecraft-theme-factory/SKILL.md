---
name: spacecraft-theme-factory
description: A specialized tool for generating high-quality Spacecraft Software-compliant themes for various IDEs, editors, and terminal environments. Use it when you need to extend Spacecraft Software support to a new platform.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# Spacecraft Software Theme Factory

**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

> **Source of truth:** The Steelbore Standard v1.9 (§9 Colors, §10 Typography)
> and the `spacecraft-brand-guidelines` skill. Themes may not introduce
> colors, fonts, or naming outside what these sources define.

## Color Palette (WCAG 2.1 AA Compliant)

All colors are verified for contrast against the Void Navy (`#000027`) background.

| Token          | Hex       | RGB                | Role                          |
|----------------|-----------|--------------------|-------------------------------|
| Void Navy      | `#000027` | RGB(0, 0, 39)      | **Background / Canvas**       |
| Molten Amber   | `#D98E32` | RGB(217, 142, 50)  | Primary Text / Active Readout |
| Steel Blue     | `#4B7EB0` | RGB(75, 126, 176)  | Primary Accent / Structural   |
| Radium Green   | `#50FA7B` | RGB(80, 250, 123)  | Success / Safe Status         |
| Red Oxide      | `#FF5C5C` | RGB(255, 92, 92)   | Warning / Error Status        |
| Liquid Coolant | `#8BE9FD` | RGB(139, 233, 253) | Info / Links                  |

**`#000027` (Void Navy) is the mandatory background for ALL Spacecraft Software surfaces** —
documents, terminals, editor themes, application UIs. No alternative background is permitted.

## Typography

Only FOSS-licensed fonts are permitted. Acceptable licenses: OFL, Apache 2.0, Ubuntu Font License, CC0-1.0.

| Context        | Font              | License | Source       |
|----------------|-------------------|---------|--------------|
| Headings       | Share Tech Mono   | OFL     | Google Fonts |
| Body / Code    | Inconsolata       | OFL     | Google Fonts |
| Fallback       | monospace (system)| N/A     | System       |

Never use proprietary fonts. Outfit, Inter, Roboto, and similar non-OFL fonts are **not permitted**.

## Theme Generation Workflow

1. **Select a target platform** — VS Code, JetBrains, terminal emulator, Material UI app, etc.
2. **Map the §9 palette** into the platform's color-key schema, preserving
   role semantics — Molten Amber for primary text, Steel Blue for structural
   accent, Radium Green for success states, Red Oxide for errors, Liquid
   Coolant for info/links. Never invent new color names or shift hex codes.
3. **Apply the §10 typography** (Share Tech Mono headings, Inconsolata body)
   wherever the platform supports font selection.
4. **Verify WCAG 2.1 AA contrast** against Void Navy for every color pair
   before shipping.
5. **Emit the platform's native config format** (JSON, XML, TOML, ini) with
   all hex codes verbatim from the canonical table.

## Output Targets

- **IDEs / editors**: VS Code, JetBrains, Helix, Zed, Neovim
- **Terminal emulators**: Kitty, Alacritty, WezTerm, Foot
- **Material Design GUI applications**
- **Document formats** (DOCX, PDF): force `#000027` page background and ISO
  A4 (210 × 297 mm) page size; apply palette text colors per
  `spacecraft-document-format`.

## Validation Checklist

Before shipping any generated theme:

- All hex codes match §9 verbatim — no variants, no near-matches.
- All fonts are FOSS-licensed and listed in §10.
- Every color pair against Void Navy passes WCAG 2.1 Level AA.
- Output references only `spacecraft-brand-guidelines` (lowercase) for
  upstream brand context; no claims of `/themes`, `/scripts`, or
  `/templates` subdirectories (this skill ships as `SKILL.md` only).

*— Built by Spacecraft Software —*
