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

> **Source of truth:** The Steelbore Standard — §11 (Colour Palettes) and §12
> (Typography), tracked as sections rather than pinned to a document version,
> which would go stale on any unrelated release —
> and the `spacecraft-brand-guidelines` skill. Themes may not introduce
> colors, fonts, or naming outside what these sources define. The palette below
> is the **Steelbore 2** generation; the five v1.33 foreground tokens and the old
> lifts are Classic's, not Modern's (§11.2) — Void Navy carries forward.
>
> **§11 is a palette family (v2.08).** Steelbore Modern is the default and is
> what you emit unless the requester names another. Ten more are registered:
> `steelbore-classic`, `steelbore-blue`, `steelbore-blackpinkpanther`,
> `steelbore-biolume`, `steelbore-navywhite`, `tokyonight`,
> `steelbore-hanzosteel`, `steelbore-blackpinkpanther`, `steelbore-green` and
> `steelbore-greenalt`; two
> **fidelity palettes** (`solarized-dark`, `solarized-light`) are registered but
> **non-conforming** and not adoptable (§11.5). **Read every value from the
> `steelbore-color-palette` skill's `assets/steelbore.toml`** — it carries all
> thirteen palettes, all 25 themes, and every measured matrix. Never mix tokens
> across palettes (§11.4).

## Color Palette — Steelbore 2 (WCAG 2.2 AA Compliant)

All foreground colors are verified for contrast **against the Void Navy
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

1. **Select a target platform** — VS Code, JetBrains, terminal emulator, Material UI app, GTK 4 desktop, Qt 6 desktop, etc.
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
6. **Emit the §11.6.1 registered set** whenever the target platform supports
   more than one theme — not just the declared palette and its variants. The
   must-emit list is `[meta] registered-set` in `steelbore.toml`: the ten
   conforming palettes, each with its `-high-contrast` sibling, plus
   `steelbore-mono` (4-bit ANSI, palette-independent, deferring to the user's
   terminal palette). Twenty-one themes; read them in a loop rather than writing
   them out. Classic is **not** in the set — it binds the legacy six-role
   contract (§11.2) and carries an `info` token that is not one of §11.1's
   eleven roles, so emit it only for a platform whose schema fits that
   contract. Emitting is not defaulting: `steelbore` stays the default, and the
   platform's theme-selection key must name it. Where the emitted config or its
   launcher reads a theme from the environment, the variable is
   **`SPACECRAFT_THEME`**, carrying a slug — never `STEELBORE_THEME`, which is
   already a boolean shell flag, so `STEELBORE_THEME=true` would resolve to a
   nonexistent theme and fall through in silence (§11.6). Where the platform can follow
   the system color scheme, pair the themes per `[resolution.pair]` so a light
   preference resolves to `steelbore-navywhite` (§11.6.2) — read the pairing,
   never hardcode it. For
   Modern the lifts are `accent` → Plasma Orange Lift, `structure`/`border` →
   Pulse Violet Lift, `error` → Mars Red Lift, `warning` → Plasma Magenta Lift, with `foreground`
   and `success` verbatim; for every other palette take the lifts from
   `steelbore.toml`. `steelbore` remains the sole default; variants are
   additive siblings and never replace it. **The palette's own canvas stays
   the background in all its variants** — note NavyWhite's canvas is light and
   its high-contrast variant *darkens* foregrounds.
7. **Verify WCAG 2.2 AA contrast** against the palette's canvas — and against
   its two surface tokens for anything the theme places on a surface — for
   every color pair before shipping.
8. **Emit the platform's native config format** (JSON, XML, TOML, ini, CSS, QSS) with
   all hex codes verbatim from the canonical table.

## Output Targets

- **IDEs / editors**: VS Code, JetBrains, Helix, Zed, Neovim
- **Terminal emulators**: Kitty, Alacritty, WezTerm, Foot
- **Material Design GUI applications**
- **GTK 4 desktop applications** — emit `steelbore.css` as a token file of
  GTK `@define-color` declarations (`@define-color steelbore_accent …`), loaded
  through a `GtkCssProvider` at `STYLE_PROVIDER_PRIORITY_APPLICATION`. Widget
  rules reference the tokens (`color: @steelbore_foreground;`) and never a hex
  literal. Emit the `<slug>-high-contrast` sibling as a second CSS file so
  accessible mode is a provider swap. See `spacecraft-gtk-guidelines`.
- **Qt 6 desktop applications** — emit two coupled artifacts: a `steelbore.qss`
  stylesheet with the palette substituted into token placeholders, and a
  `QPalette` builder mapping tokens onto Qt's colour roles (`Window` ←
  `background`, `Base` ← `surface-alt`, `AlternateBase` ← `surface`,
  `WindowText`/`Text` ← `foreground`, `Highlight` ← `accent`, `Link` ←
  `structure`, `Mid` ← `border`). QML targets take a generated `Theme.qml`
  singleton of `readonly property color` bindings instead of the QSS. See
  `spacecraft-qt-guidelines`.
- **Document formats** (DOCX, PDF): force the declared palette's canvas as the
  page background (Void Navy under Modern, the default) and ISO
  A4 (210 × 297 mm) page size; apply palette text colors per
  `spacecraft-document-format`.

## Validation Checklist

Before shipping any generated theme:

- All hex codes match the emitted palette's entry in `steelbore.toml`
  verbatim — no near-matches, and no tokens borrowed from a *different*
  palette in the family (§11.4). Classic's tokens (Molten Amber, Steel Blue,
  Radium Green, Red Oxide, Liquid Coolant, plus the Steel Blue and Red Oxide lifts) are valid
  only inside `steelbore-classic`.
- All fonts are FOSS-licensed and listed in §12.
- Every foreground token against the palette's canvas passes WCAG 2.2 Level
  AA. (Scope the claim precisely — only that palette's measured matrix is
  covered; other token-on-token pairings mostly fail.)
- No generated theme places palette-colored text on a palette-colored fill
  without a measured ≥4.5:1 ratio for that specific pair. Honour each
  palette's restricted pairings: in Modern, no normal-size Mars Red or Pulse
  Violet text on Quantum Blue; in Blue, no normal-size Electric Blue text anywhere (3.91:1 — large text, icons, and non-text UI only).
- Surface tokens are mapped only to background/fill keys — never to any text
  or foreground key.
- Where the platform supports multiple themes, the `<slug>-high-contrast`
  sibling and `steelbore-mono` are emitted alongside the palette, and
  `steelbore` is still the default.
- Output references only `spacecraft-brand-guidelines` (lowercase) for
  upstream brand context; no claims of `/themes`, `/scripts`, or
  `/templates` subdirectories (this skill ships as `SKILL.md` only).

*— Built by Spacecraft Software —*
