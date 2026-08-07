---
name: spacecraft-brand-guidelines
description: Applies Spacecraft Software's official brand colors and typography to any sort of artifact that may benefit from having Spacecraft Software's look-and-feel. Use it when brand colors or style guidelines, visual formatting, or project design standards apply.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# Spacecraft Software Brand Guidelines

**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad & Spacecraft Software | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

> **Source of truth:** The Steelbore Standard — **§11** (Colour Palettes) and
> **§12** (Typography). This skill tracks those two sections, not the document
> version: a release that touches neither leaves this skill current, so no
> version is pinned here to go stale. When §11 or §12 changes, this skill
> changes with it.
>
> **§11 is a palette family.** The tables below are **Steelbore Modern**, the
> default — use it unless the project declares an alternate in its `README.md`
> (§11.4). Also registered: `steelbore-classic`, `steelbore-blue`,
> `steelbore-blackpinkpanther`, `steelbore-matrixgreen`, `steelbore-navywhite`
> (light canvas), and `tokyonight`. Two **fidelity palettes** — `solarized-dark`
> and `solarized-light` — are registered verbatim but are **non-conforming**
> (§11.5) and may not be adopted as a project palette. All values live in the
> `steelbore-color-palette` skill's `assets/steelbore.toml`. A project uses one
> palette; never mix.
> All values here are canonical **Steelbore 2** generation tokens. Do not use any other
> color or font values for Spacecraft Software artifacts. The five v1.33 foreground
> tokens (Molten Amber, Steel Blue, Radium Green, Red Oxide, Liquid Coolant) and the
> old `#7FAEDC`/`#FF8080` lifts now belong to **Steelbore Classic** (§11.2), which is
> preserved as a family member — they are valid only inside that palette.
> Hex values are canonically served by the `steelbore-color-palette` skill.

## Color Palette — Steelbore 2 (WCAG 2.2 AA Compliant)

All foreground colors are verified for contrast against the Void Navy (`#000027`)
background *and* against both surface tokens (see the §11.0.2 matrix in the Standard).

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
documents, terminals, editor themes, application UIs. No alternative background is permitted.
Surface tokens are fills *placed on* Void Navy, never replacements for it, and are
**never text colors** (Quantum Blue 1.40:1, Deep Matrix 1.14:1 — illegible as foregrounds).

**Restricted pairings (§11.0.2 †):** on Quantum Blue surfaces, Mars Red (4.12:1) and
Pulse Violet (3.93:1) are limited to large text, icons, and non-text UI. Normal-size
error prose on a surface is Platinum Mist with the `[ERROR]` tag; Mars Red is border
or icon accent only. All other matrix pairings pass 4.5:1.

## Typography

Only FOSS-licensed fonts are permitted. Acceptable licenses: OFL, Apache 2.0, Ubuntu Font License, CC0-1.0.

| Context        | Font              | License | Source       |
|----------------|-------------------|---------|--------------|
| Headings       | Share Tech Mono   | OFL     | Google Fonts |
| Body / Code    | Inconsolata       | OFL     | Google Fonts |
| Fallback       | monospace (system)| N/A     | System       |

Never use proprietary fonts. Outfit, Inter, Roboto, and similar non-OFL fonts are **not permitted**.

## Document Creation (DOCX / PDF)

For full document styling rules, load the `spacecraft-document-format` skill.
Quick reference:

- **Page background:** `#000027` (Void Navy) — mandatory, non-negotiable
- **Page size:** ISO A4 (210 × 297 mm)
- **Body text:** Inconsolata, 11 pt, Platinum Mist `#D9DEE5`
- **H1:** Share Tech Mono, 16 pt, bold, Plasma Orange `#FF5E00`
- **H2:** Share Tech Mono, 14 pt, bold, Acid Lime `#B4FF00`
- **H3:** Share Tech Mono, default size, italic, Pulse Violet `#8A6CFF`
- **Links:** Pulse Violet `#8A6CFF` (unvisited), Plasma Orange `#FF5E00` (visited)
- **Code blocks:** Deep Matrix `#0B1A12` fill, Platinum Mist text
- **Callout panels:** Quantum Blue `#0E2A47` fill, Pulse Violet border, Platinum Mist text

## UI / Visual Design

- **Steelbore Theme Standard:** When implementing colors and themes, always opt to create a named theme called `Steelbore` (Snake case `steelbore` for file/module names) that bundles these colors, rather than hardcoding hex values directly in UI/styling logic. This allows users to easily swap or customize themes by registering a new named theme without modifying application logic (Standard §11.1). The full role-token contract (including `surface`, `surface-alt`, `focus`, and `border`) is defined in §11.1.
- **Focus indicator:** Acid Lime `#B4FF00` (16.75:1) — satisfies WCAG 2.2 §2.4.11 on every background.
- Apply the palette to whichever component system §13 requires for the platform — **Material Design** for Flutter, web, mobile, and cross-platform GUI; **GNOME HIG** (libadwaita) for GTK 4; **KDE HIG** (Qt Quick Controls / Fusion) for Qt 6. The palette is system-agnostic: §13 chooses the widget vocabulary, §11 supplies the colors, and the binding is always through the named `steelbore` theme rather than the component library's own defaults.
- All new color pairings must pass WCAG 2.2 Level AA contrast verification before adoption, stating which pairing was measured (§13).
- For IDE and terminal themes, load the `spacecraft-theme-factory` skill.

*— Built by Spacecraft Software —*
