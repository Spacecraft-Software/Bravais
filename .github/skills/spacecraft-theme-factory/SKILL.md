---
name: spacecraft-theme-factory
description: A specialized tool for generating high-quality Spacecraft Software-compliant themes for various IDEs, editors, and terminal environments. Use it when you need to extend Spacecraft Software support to a new platform.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# Spacecraft Software Theme Factory

**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad & Spacecraft Software | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

> **Source of truth:** The Steelbore Standard v1.39 (§11 Colour Palettes, §12 Typography)
> and the `spacecraft-brand-guidelines` skill. Themes may not introduce
> colors, fonts, or naming outside what these sources define. The palette below
> is the **Steelbore 2** generation; the five v1.33 foreground tokens and the old
> lifts are Classic's, not Modern's (§11.2) — Void Navy carries forward.
>
> **§11 is a palette family (v1.35).** Steelbore Modern is the default and is
> what you emit unless the requester names another. Six more are registered:
> `steelbore-classic`, `steelbore-blue`, `steelbore-blackpinkpanther`,
> `steelbore-matrixgreen`, `steelbore-navywhite`, and `tokyonight`; two
> **fidelity palettes** (`solarized-dark`, `solarized-light`) are registered but
> **non-conforming** and not adoptable (§11.5). **Read every value from the
> `steelbore-color-palette` skill's `assets/steelbore.toml`** — it carries all
> nine palettes, all 17 themes, and every measured matrix. Never mix tokens
> across palettes (§11.4).

## Color Palette — Steelbore 2 (WCAG 2.2 AA Compliant)

All foreground colors are verified for contrast **against the Void Navy (`#000027`)
background** — Platinum Mist 15.09:1, Plasma Orange 6.66:1, Pulse Violet 5.51:1,
Acid Lime 16.75:1, Mars Red 5.77:1, Plasma Magenta 6.41:1. All pass Level AA.
Per-surface ratios (vs Quantum Blue and Deep Matrix) are tabulated in Standard
§11.0.2 and in the canonical `steelbore.toml` (shipped by the
`steelbore-color-palette` skill at `assets/steelbore.toml`).

**This guarantee does not extend to unmeasured token-on-token pairings.** Most
foreground tokens paired with each other fall below the 3:1 floor (Acid Lime on
Platinum Mist is 1.11:1; Plasma Orange on Mars Red is 1.15:1). Never emit a theme
that places palette-colored text on a palette-colored fill unless you have
measured that specific pair at ≥4.5:1 (Standard §11). Two measured restrictions
carry over from §11.0.2: on Quantum Blue fills, Mars Red (4.12:1) and Pulse
Violet (3.93:1) may only be used for large text, icons, and non-text UI.

| Token          | Hex       | RGB                | Class      | Role                            |
|----------------|-----------|--------------------|------------|---------------------------------|
| Void Navy      | `#000027` | RGB(0, 0, 39)      | Canvas     | **Background — all surfaces**   |
| Quantum Blue   | `#0E2A47` | RGB(14, 42, 71)    | Surface    | Elevated panels / cards         |
| Deep Matrix    | `#0B1A12` | RGB(11, 26, 18)    | Surface    | Code blocks / terminal wells    |
| Platinum Mist  | `#D9DEE5` | RGB(217, 222, 229) | Foreground | Body text / default readout     |
| Plasma Orange  | `#FF5E00` | RGB(255, 94, 0)    | Foreground | Primary accent / active readout |
| Pulse Violet   | `#8A6CFF` | RGB(138, 108, 255) | Foreground | Structure / links / borders     |
| Acid Lime      | `#B4FF00` | RGB(180, 255, 0)   | Foreground | Success / safe status / focus   |
| Mars Red       | `#FF3B3B` | RGB(255, 59, 59)   | Foreground | Error status                    |
| Plasma Magenta | `#E445FF` | RGB(228, 69, 255)  | Foreground | Warning / attention             |

**`#000027` (Void Navy) is the mandatory canvas under Steelbore Modern**, the default palette —
documents, terminals, editor themes, application UIs. No alternative background is
permitted. Surface tokens are fills on Void Navy and are **never text colors**.

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
2. **Standard Theme Naming:** Always define the theme under the name `Steelbore` (file/module named `steelbore` in snake_case) and map the §11 palette into the platform's theme registry.
3. **Avoid Hardcoding:** Bundle colors into a named theme/config structure rather than hardcoding hex literals. This ensures the theme is easily replaceable so that users can add or swap custom themes without modifying application logic.
4. **Map the §11 palette** into the platform's color-key schema, preserving
   role semantics — Platinum Mist for body text, Plasma Orange for primary
   accent, Pulse Violet for structure/links/borders, Acid Lime for success
   states and the focus indicator, Mars Red for errors, Plasma Magenta for
   warnings, Quantum Blue for elevated panels, Deep Matrix for code/terminal
   wells. Never invent new color names or shift hex codes.
5. **Apply the §12 typography** (Share Tech Mono headings, Inconsolata body)
   wherever the platform supports font selection.
6. **Emit the accessibility variants alongside the default** (Standard §11.1.1)
   whenever the target platform supports more than one theme: the palette
   itself, its `<slug>-high-contrast` sibling, and `steelbore-mono` (4-bit
   ANSI, palette-independent, deferring to the user's terminal palette). For
   Modern the lifts are `accent` → `#FF8A3D`, `structure`/`border` →
   `#B3A1FF`, `error` → `#FF7A7A`, `warning` → `#EE7BFF`, with `foreground`
   and `success` verbatim; for every other palette take the lifts from
   `steelbore.toml`. `steelbore` remains the sole default; variants are
   additive siblings and never replace it. **The palette's own canvas stays
   the background in all its variants** — note NavyWhite's canvas is light and
   its high-contrast variant *darkens* foregrounds.
7. **Verify WCAG 2.2 AA contrast** against the palette's canvas — and against
   its two surface tokens for anything the theme places on a surface — for
   every color pair before shipping.
8. **Emit the platform's native config format** (JSON, XML, TOML, ini) with
   all hex codes verbatim from the canonical table.

## Output Targets

- **IDEs / editors**: VS Code, JetBrains, Helix, Zed, Neovim
- **Terminal emulators**: Kitty, Alacritty, WezTerm, Foot
- **Material Design GUI applications**
- **Document formats** (DOCX, PDF): force the declared palette's canvas as the
  page background (`#000027` under Modern, the default) and ISO
  A4 (210 × 297 mm) page size; apply palette text colors per
  `spacecraft-document-format`.

## Validation Checklist

Before shipping any generated theme:

- All hex codes match the emitted palette's entry in `steelbore.toml`
  verbatim — no near-matches, and no tokens borrowed from a *different*
  palette in the family (§11.4). Classic's tokens (`#D98E32`, `#4B7EB0`,
  `#50FA7B`, `#FF5C5C`, `#8BE9FD`, lifts `#7FAEDC` / `#FF8080`) are valid
  only inside `steelbore-classic`.
- All fonts are FOSS-licensed and listed in §12.
- Every foreground token against the palette's canvas passes WCAG 2.2 Level
  AA. (Scope the claim precisely — only that palette's measured matrix is
  covered; other token-on-token pairings mostly fail.)
- No generated theme places palette-colored text on a palette-colored fill
  without a measured ≥4.5:1 ratio for that specific pair. Honour each
  palette's restricted pairings: in Modern, no normal-size Mars Red or Pulse
  Violet text on Quantum Blue; in Blue, no normal-size Electric Blue
  `#0066FF` text anywhere (3.91:1 — large text, icons, and non-text UI only).
- Surface tokens are mapped only to background/fill keys — never to any text
  or foreground key.
- Where the platform supports multiple themes, the `<slug>-high-contrast`
  sibling and `steelbore-mono` are emitted alongside the palette, and
  `steelbore` is still the default.
- Output references only `spacecraft-brand-guidelines` (lowercase) for
  upstream brand context; no claims of `/themes`, `/scripts`, or
  `/templates` subdirectories (this skill ships as `SKILL.md` only).

*— Built by Spacecraft Software —*
