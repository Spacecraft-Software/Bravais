---
name: spacecraft-brand-guidelines
description: Applies the Spacecraft Software brand — the Steelbore palette family (Standard §11) and the §12 FOSS-licensed typography — to any artifact that should carry the house look: slide decks, diagrams, SVGs, dashboards, marketing pages, READMEs, or UI mockups. Triggers on brand colours, house style, visual formatting, "make this on-brand", token roles (canvas, surface, foreground, accent, structure, status), or the Share Tech Mono / Inconsolata pairing. This skill names tokens and their roles; it never carries values — every hex, RGB triple, and contrast ratio is read from `steelbore-color-palette`'s `assets/steelbore.toml`, the single source (§11.4). Do NOT use it to generate editor or terminal themes (use `spacecraft-theme-factory`), to author documents (use `spacecraft-document-format`), or to pick an accessible variant (use `spacecraft-accessibility-support`).
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
> `steelbore-magnetar`, `steelbore-biolume`, `steelbore-navywhite`
> (light canvas), `tokyonight`, `steelbore-hanzosteel`, `steelbore-blackpinkpanther`,
> `steelbore-green` and `steelbore-greenalt`. Two **fidelity
> palettes** — `solarized-dark`
> and `solarized-light` — are registered verbatim but are **non-conforming**
> (§11.5) and may not be adopted as a project palette. All values live in the
> `steelbore-color-palette` skill's `assets/steelbore.toml`. A project uses one
> palette; never mix.
>
> **Accessible mode swaps a sibling, never the brand.** Every conforming palette
> ships a `<slug>-high-contrast` variant (§11.1.1) that lifts only the tokens
> below 7:1 on the canvas, plus the palette-independent `steelbore-mono` for
> 4-bit ANSI and `NO_COLOR`. Under §18.1 the variant is what renders — the
> canvas and the unlifted tokens carry over verbatim, so brand identity is
> unchanged. Selection is not this skill's call: `spacecraft-accessibility-support`
> owns the activation contract, and the lifted values live in
> `steelbore-color-palette`. Never lift a token by eye, and never use a variant
> hex outside its variant.
> All values here are canonical **Steelbore 2** generation tokens. Do not use any other
> color or font values for Spacecraft Software artifacts. The five v1.33 foreground
> tokens (Molten Amber, Steel Blue, Radium Green, Red Oxide, Liquid Coolant) and the
> old Steel Blue and Red Oxide lifts now belong to **Steelbore Classic** (§11.2), which is
> preserved as a family member — they are valid only inside that palette.
> Hex values are canonically served by the `steelbore-color-palette` skill.

## Color Palette — Steelbore 2 (WCAG 2.2 AA Compliant)

All foreground colors are verified for contrast against the Void Navy
background *and* against both surface tokens (see the §11.0.2 matrix in the Standard).

| Token          | Class      | Role                            |
|----------------|------------|---------------------------------|
| Void Navy      | Canvas     | **Background — all surfaces**   |
| Quantum Blue   | Surface    | Elevated panels / cards         |
| Deep Matrix    | Surface    | Code blocks / terminal wells    |
| Platinum Mist  | Foreground | Body text / default readout     |
| Plasma Orange  | Foreground | Primary accent / active readout |
| Pulse Violet   | Foreground | Structure / links / borders     |
| Acid Lime      | Foreground | Success / safe status / focus   |
| Mars Red       | Foreground | Error status                    |
| Plasma Magenta | Foreground | Warning / attention             |

**Void Navy is the mandatory canvas under Steelbore Modern**, the default palette —
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

- **Page background:** Void Navy — mandatory, non-negotiable
- **Page size:** ISO A4 (210 × 297 mm)
- **Body text:** Inconsolata, 11 pt, Platinum Mist
- **H1:** Share Tech Mono, 16 pt, bold, Plasma Orange
- **H2:** Share Tech Mono, 14 pt, bold, Acid Lime
- **H3:** Share Tech Mono, default size, italic, Pulse Violet
- **Links:** Pulse Violet (unvisited), Plasma Orange (visited)
- **Code blocks:** Deep Matrix fill, Platinum Mist text
- **Callout panels:** Quantum Blue fill, Pulse Violet border, Platinum Mist text

## UI / Visual Design

- **Steelbore Theme Standard:** When implementing colors and themes, always opt to create a named theme called `Steelbore` (Snake case `steelbore` for file/module names) that bundles these colors, rather than hardcoding hex values directly in UI/styling logic. This allows users to easily swap or customize themes by registering a new named theme without modifying application logic (Standard §11.1). The full role-token contract (including `surface`, `surface-alt`, `focus`, and `border`) is defined in §11.1.
- **Focus indicator:** Acid Lime (16.75:1) — satisfies WCAG 2.2 §2.4.11 on every background.
- Apply the palette to whichever component system §13 requires for the platform — **Material Design** for Flutter, web, mobile, and cross-platform GUI; **GNOME HIG** (libadwaita) for GTK 4; **KDE HIG** (Qt Quick Controls / Fusion) for Qt 6. The palette is system-agnostic: §13 chooses the widget vocabulary, §11 supplies the colors, and the binding is always through the named `steelbore` theme rather than the component library's own defaults.
- All new color pairings must pass WCAG 2.2 Level AA contrast verification before adoption, stating which pairing was measured (§13).
- For IDE and terminal themes, load the `spacecraft-theme-factory` skill.

*— Built by Spacecraft Software —*
