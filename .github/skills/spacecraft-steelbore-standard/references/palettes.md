<!--
SPDX-License-Identifier: GPL-3.0-or-later
Copyright (C) 2026 Mohamed Hammad & Spacecraft Software
-->

# §11 — Color Palettes (full text)

Split out of `SKILL.md` for on-demand loading; this is the normative §11
text, unaltered. The skill body carries the gating rules and points here
for the palettes themselves, their role tokens, and the contrast work.

Machine-readable values live in the `steelbore-color-palette` skill's
`assets/steelbore.toml` — §11.4 requires values be read from there, never
retyped into application code.

---

## §11 — Spacecraft Software Color Palettes (WCAG-Compliant)

Spacecraft Software ships a **palette family**. Every palette declares exactly
one **canvas**, a full set of §11.1 role tokens, and a verified contrast
matrix.

**`Steelbore Modern` is the default and canonical palette.** Every artifact
uses Modern unless its project explicitly declares an alternate under §11.4.

| Theme slug | Palette | Canvas | Polarity | Status |
|---|---|---|---|---|
| `steelbore` | Steelbore Modern | Void Navy | Dark | **Default** — all artifacts unless declared |
| `steelbore-classic` | Steelbore Classic | Void Navy | Dark | Legacy contract (§11.2) |
| `steelbore-blue` | Steelbore Blue | Orbit Navy | Dark | Alternate (§11.3) |
| `steelbore-magnetar` | Steelbore Magnetar | Core Black | Dark | Alternate (§11.3) |
| `steelbore-biolume` | Steelbore Biolume | Circuit Navy | Dark | Alternate (§11.3) |
| `steelbore-navywhite` | Steelbore NavyWhite | Pearl Silver | **Light** | Alternate (§11.3) — the family's only light canvas |
| `tokyonight` | Tokyo Night | Night | Dark | Alternate (§11.3) |
| `steelbore-hanzosteel` | Steelbore Hanzo Steel | Sumi Black | Dark | Alternate (§11.3) |
| `steelbore-blackpinkpanther` | Steelbore BlackPinkPanther | Runway Black | Dark | Alternate (§11.3) — slug reused at v2.08 |
| `steelbore-green` | Steelbore Green | Vampire Black | Dark | Alternate (§11.3) |
| `steelbore-greenalt` | Steelbore Green Alt | Vampire Black | Dark | Alternate (§11.3) |

**Polarity** is normative content: §11.6.2 pairs a dark palette with a light one
so an application can follow the platform's color-scheme preference.

### §11.0 — Steelbore Modern (canonical palette)

The permitted colors for Steelbore Modern (the **Steelbore 2** generation):

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

**Void Navy is the mandatory canvas for every surface under
Steelbore Modern**, and Modern is the default, so Void Navy is the background
of every artifact that has not declared an alternate under §11.4. Within a
palette the canvas is non-negotiable: surface-class tokens are *fills placed
on* the canvas, never replacements for it. Mixing tokens across palettes is
forbidden (§11.4).

### §11.0.1 — The Surface Class

New in Steelbore 2. Surface tokens carry the following hard rules:

- Surface tokens are **never text colors**. Quantum Blue is 1.40:1 and Deep
  Matrix 1.14:1 against Void Navy — both are illegible as foregrounds anywhere.
- A surface's edge against the canvas (1.40:1 / 1.14:1) does not meet the 3:1
  non-text floor. Where the boundary is meaningful, it **must** be drawn — a
  Pulse Violet border (5.51:1 vs canvas) is the canonical edge.
- Surfaces never nest on each other without a measured boundary.

### §11.0.2 — Scope of the Contrast Guarantee

Every foreground token is verified with the WCAG relative-luminance formula
against all three backgrounds it may legally appear on. AA floors: **4.5:1**
normal text (1.4.3); **3:1** large text and non-text UI (1.4.3, 1.4.11).
EN 301 549 V4.1.1 clause 11 (11.1.4.3, 11.1.4.11) inherits the same criteria
for non-web software; the EAA has been enforceable since 2025-06-28.

| Foreground     | vs Void Navy | vs Quantum Blue | vs Deep Matrix |
|----------------|--------------|-----------------|----------------|
| Platinum Mist  | 15.09:1      | 10.78:1         | 13.27:1        |
| Plasma Orange  | 6.66:1       | 4.76:1          | 5.85:1         |
| Pulse Violet   | 5.51:1       | **3.93:1** †    | 4.84:1         |
| Acid Lime      | 16.75:1      | 11.97:1         | 14.73:1        |
| Mars Red       | 5.77:1       | **4.12:1** †    | 5.07:1         |
| Plasma Magenta | 6.41:1       | 4.58:1          | 5.63:1         |

† **Restricted pairings.** On Quantum Blue, Pulse Violet and Mars Red fall
below 4.5:1 and are limited to **large text (≥18.66 px bold / ≥24 px regular),
icons, and non-text UI** (≥3:1). Normal-size error prose on a surface is set in
Platinum Mist carrying the mandatory `[ERROR]` tag (§18.2), with Mars Red as
border or icon accent only.

The guarantee covers the eighteen pairings in the matrix above **only**, and
only for Steelbore Modern. **Every palette carries its own verified matrix** —
§11.2 for Classic, §11.3 for the alternates — measured the same way against
that palette's own canvas and surfaces. Foreground tokens paired with *each
other* mostly fail the 3:1 floor (Acid Lime on Platinum Mist is 1.11:1; Plasma
Orange on Mars Red is 1.15:1). Therefore:

- Rendering palette-colored **text on a palette-colored fill** (chip, badge,
  filled button, selected row) is **forbidden** unless that specific pair is
  measured at ≥4.5:1 for text, or ≥3:1 for non-text boundaries.
- Color may never be the **sole** carrier of meaning — every colored status
  also carries a text tag or symbol (§18.2). `[OK]` `[WARN]` `[ERROR]` `[INFO]`.
- The visible **focus indicator** is Acid Lime (16.75:1) — comfortably above
  the 3:1 indicator floor, satisfying WCAG 2.2 §2.4.11 on every background.

For document/file generation → load the `spacecraft-document-format` skill.
For IDE/terminal themes → load the `spacecraft-theme-factory` skill.

### §11.1 — Steelbore Theme (Application Theming Standard)

When building a new Spacecraft Software application (GUI, TUI, or web), all palette
references **must** be accessed through a named theme called **`Steelbore`** rather than
referenced as bare hex literals. The `Steelbore` theme is the canonical color contract:

| Theme token   | Maps to palette token |
|---------------|-----------------------|
| `background`  | Void Navy             |
| `surface`     | Quantum Blue          |
| `surface-alt` | Deep Matrix           |
| `foreground`  | Platinum Mist         |
| `accent`      | Plasma Orange         |
| `structure`   | Pulse Violet          |
| `success`     | Acid Lime             |
| `error`       | Mars Red              |
| `warning`     | Plasma Magenta        |
| `focus`       | Acid Lime             |
| `border`      | Pulse Violet          |

**Rationale:** isolating palette references behind the `Steelbore` theme name makes it
trivial for end users to substitute a custom theme without touching application logic —
swap the theme, not every hex literal.

- The theme file/module **must** be named `steelbore` (snake_case) in the project's
  theme registry, configuration layer, or equivalent (e.g., `themes/steelbore.json`,
  `steelbore.toml`, a Rust `Theme::Steelbore` variant).
- Hard-coding palette hex values directly in UI logic is **forbidden** for new apps.
  Use theme tokens exclusively.
- Existing apps are encouraged but not required to migrate; new apps are required.
  Apps still shipping the v1.33 six-token palette remain compliant until their
  next minor release, after which the Steelbore 2 contract applies.

#### §11.1.1 — Accessibility Variants (additive siblings)

`steelbore` is and remains the **sole default theme**. The variants below are
**additive siblings** in the same registry, selected only by explicit user action
or by the §18.1 accessible-mode toggle. They never alter, replace, or take
precedence over `steelbore`, and the §11 canonical palette is unchanged.

| Variant | Selected by | Behavior |
|---------|-------------|----------|
| `steelbore` | **Default** — always, unless overridden | Canonical §11 palette, unchanged |
| `<palette>-high-contrast` | §18.1 accessible mode, or explicit selection | Every foreground role token lifted to ≥7:1 (WCAG AAA) on that palette's canvas |
| `steelbore-mono` | Explicit selection, or `NO_COLOR` | 4-bit ANSI only — defers to the user's terminal palette |

`steelbore-high-contrast` lifts **only the four tokens that need it**; tokens
already ≥7:1 carry over untouched:

| Theme token  | Base token     | Variant token           | Contrast vs Void Navy |
|--------------|----------------|-------------------------|-----------------------|
| `background` | Void Navy      | (unchanged)             | (canvas)              |
| `foreground` | Platinum Mist  | (unchanged)             | 15.09:1               |
| `accent`     | Plasma Orange  | **Plasma Orange Lift**  | 8.70:1                |
| `structure`  | Pulse Violet   | **Pulse Violet Lift**   | 9.19:1                |
| `success`    | Acid Lime      | (unchanged)             | 16.75:1               |
| `error`      | Mars Red       | **Mars Red Lift**       | 8.08:1                |
| `warning`    | Plasma Magenta | **Plasma Magenta Lift** | 8.66:1                |

Only `accent`, `structure`, `error`, and `warning` shift; the other tokens are
§11 values verbatim, with alias tokens following their bases (`focus` stays
Acid Lime; `border` follows `structure` to Pulse Violet Lift, keeping every
foreground-class role token ≥7:1). In the variant, all four lifted tokens also clear 4.5:1
on both surfaces (weakest pairing: `error` Mars Red Lift on Quantum Blue, 5.77:1),
so the §11.0.2 † restrictions do not apply under high contrast. **Void Navy
remains the background in every variant** — high contrast comes from lifting
foregrounds, never from abandoning the canvas. The lifted hexes are
accessibility-derived lifts of existing role tokens, not new brand colors, and
may not be used outside the variant.

### §11.2 — Steelbore Classic Color Palette

The original six-token palette, **preserved as a named family member** — not
retired. (It was briefly retired at v1.34; v1.35 reinstates it.) Shares Void
Navy with Modern, keeps its **legacy six-role contract**, and defines **no
surface class**, so §11.0.1 does not apply and every foreground is measured
against Void Navy alone.

| Role         | Token          | vs Void Navy |
|--------------|----------------|--------------|
| `background` | Void Navy      | (canvas)     |
| `foreground` | Molten Amber   | 7.64:1       |
| `accent`     | Steel Blue     | 4.77:1       |
| `success`    | Radium Green   | 14.87:1      |
| `error`      | Red Oxide      | 6.74:1       |
| `info`       | Liquid Coolant | 14.74:1      |

`steelbore-classic-high-contrast` lifts `accent` → Steel Blue Lift (8.73:1) and
`error` → Red Oxide Lift (8.41:1); the other four are already ≥7:1. Classic's
token-on-token failures are severe — Molten Amber on Red Oxide 1.13:1,
Radium Green on Liquid Coolant 1.01:1.

### §11.3 — Alternate Palettes

Nine alternates, each anchored on two colors that never change, each verified
against its own canvas and surfaces. Full role tables and three-background
matrices live in the `steelbore-color-palette` skill's
`assets/steelbore.toml`; every token clears 4.5:1 on all three of its
backgrounds unless marked †.

| Palette | Slug | Canvas | Accent anchor | Note |
|---------|------|--------|---------------|------|
| Steelbore Blue | `steelbore-blue` | Orbit Navy | Electric Blue | Electric Blue is **†restricted** (3.91:1) — large text, icons, non-text UI only |
| Steelbore Magnetar | `steelbore-magnetar` | Core Black | Plasma Magenta | No restricted pairings. Renamed from BlackPinkPanther at v2.08 — the palette is violet, not pink |
| Steelbore Biolume | `steelbore-biolume` | Circuit Navy | Solar Lime | `surface-alt` (Ambient Black) is darker than the canvas — permitted. Renamed from MatrixGreen at v2.08 |
| Steelbore NavyWhite | `steelbore-navywhite` | Pearl Silver | Lunar Navy (foreground) | **Light canvas**; high contrast *darkens*. Lighter source tints are non-text fills only |
| Tokyo Night | `tokyonight` | Night | Tokyo Blue | Verbatim from the upstream editor theme; no restricted pairings. `surface` is the Storm background Storm, `surface-alt` the Night `bg_dark` Night Deep (darker than the canvas — permitted) |

#### §11.3.5 — Tokyo Night

Registered verbatim from [enkia/tokyo-night-vscode-theme](https://github.com/enkia/tokyo-night-vscode-theme).
It needed **no Spacecraft-derived substitutes** — every role token clears 4.5:1
on all three backgrounds — so it is a conforming alternate, not a §11.5 fidelity
palette: `foreground` Starlight 10.59:1, `accent` Tokyo Blue 6.79:1, `structure`
Neon Purple 7.39:1, `success` Signal Green 9.35:1, `error` Sakura Red 6.46:1,
`warning` Lantern Yellow 8.55:1, `focus` Ice Cyan 9.96:1 (vs canvas).

`tokyonight-high-contrast` lifts the two tokens below 7:1 on the canvas —
`accent` → Tokyo Blue Lift (8.44:1) and `error` → Sakura Lift (8.22:1); the other six
carry over verbatim. The upstream comment tone Comment Slate (upstream) (2.76:1) clears neither
the 4.5:1 text floor nor the 3:1 non-text floor and is **not bindable to a role
token**; boundaries are drawn in `structure` per §11.0.1.

#### §11.3.6 — Steelbore Hanzo Steel

Anchored on **Sumi Black** and **Hanzo Gold**, with colors drawn from the poster
art for *Kill Bill Vol. 1*. The name is the standard's own — a palette name is
published prose, and a film title is a trademark this project has no licence to
use as a label. Sumi Black is the family's **only pure-black canvas**; every
other member, light or dark, tints its ground.

Role tokens vs canvas: `foreground` Bone White 18.49:1, `accent` Hanzo Gold
14.77:1, `structure` Tempered Gold 11.79:1, `success` Mint Signal 13.02:1,
`error` Crimson Edge 5.77:1, `warning` Gold Leaf 14.01:1, `focus` Hanzo Gold
14.77:1, `border` Tempered Gold 11.79:1. Surfaces are Scabbard Slate (1.19:1)
and Ink Well (1.06:1). **No restricted pairings** — every foreground clears
4.5:1 on all three backgrounds, weakest `error` on `surface` at 4.85:1.

**Crimson Edge is a deepened hue, and the section says so.** The poster's red
measures 4.03:1 on Sumi Black and 3.39:1 on Scabbard Slate — under the 4.5:1
text floor on the canvas, and under it on the surface by enough that error prose
would have been unreadable at normal size. It is deepened for the same reason
§11.3.4 deepens NavyWhite's status hues: a conforming alternate is not a §11.5
fidelity palette, so nothing obliges it to reproduce a source value that misses
the floor. Shipping the verbatim red would have bought fidelity to a poster with
an `error` token no application could set in body text.

Three golds carry three distinct roles — `accent`, `warning`, `structure` —
separated by luminance rather than hue. That is legible but not sufficient
alone, which is precisely what §18.2.1 exists for: every colored status in this
palette carries its `[WARN]` or `[ERROR]` tag.

`steelbore-hanzosteel-high-contrast` lifts `error` alone, to Ember Lift
(9.58:1); every other token already clears 7:1 on the canvas and carries over
verbatim.

#### §11.3.7 — Steelbore BlackPinkPanther

**This slug changed meaning at v2.08.** Until v2.07 it named the violet palette
now called Steelbore Magnetar (§11.3.2). A consumer pinned to it renders
different colours with no error — the break is deliberate and documented here
rather than hidden.

Anchored on **Runway Black** and **Hot Pink**: black, white
and hot pink after the Victoria's Secret *main* brand, neon and cool rather than
the softer sub-brand pink. Role tokens vs canvas: `foreground` Runway White
21.00:1, `accent` Hot Pink 5.36:1, `structure`/`border` Flamingo Pink 6.71:1,
`success` Mint Signal 13.02:1, `error` Ember Red 7.57:1, `warning` Solar Amber
13.65:1. **No restricted pairings** — weakest is `accent` on `surface` at
4.72:1. Glowing Pink is the pressed state, not a role token.

**The surfaces are pink-tinted rather than neutral black, deliberately.** In the
storefronts this palette is drawn from, backlit pink is the dominant *field* and
glossy black is the frame around it — so a near-black panel would invert the
relationship the palette exists to capture. Backlit Rose is the
boldest surface that still keeps Hot Pink above the text floor on it; one step
pinker and `accent` falls to 4.47:1 and the palette acquires its first
restricted pairing.

`steelbore-blackpinkpanther-high-contrast` lifts `accent` to Hot Pink Lift
(7.65:1) and `structure`/`border` to Flamingo Lift (8.31:1).

#### §11.3.8 — Steelbore Green

Anchored on **Vampire Black** and **Erin**. The Matrix
palette, and the one place in the family where the brand hue is the *body text*:
**Erin carries `foreground`, not `accent`**, because green-on-black terminal
text is the thing being reproduced. Steelbore Classic sets the precedent for a
non-neutral foreground (Molten Amber). **Rain Head** — the bright
leading glyph of the digital rain — carries `accent` and `focus`.

Role tokens vs canvas: `foreground` Erin 14.94:1, `accent` Rain Head 19.42:1,
`structure`/`border` Lucky Green 6.09:1, `success` Cascade Green 6.79:1, `error`
Ember Red 7.35:1, `warning` Solar Amber 13.26:1. No restricted pairings;
weakest is `structure` on `surface` at 5.47:1.

**Cascade Green is a deepened hue.** Islam Green measures 4.80:1 on
the canvas and 4.31:1 on the surface — under the text floor where it matters —
so it ships deepened, for the same reason §11.3.4 deepens NavyWhite's status
hues. Dark Green (Traditional), Australia Green and Islam
Green are carried as **non-role fills**: none reaches the text floor, and the
section says so rather than letting an implementor discover it.

`steelbore-green-high-contrast` lifts `structure`/`border` to Lucky Lift
(7.87:1) and `success` to Cascade Lift (7.65:1).

#### §11.3.9 — Steelbore Green Alt

The same colours as §11.3.8 with the two brightest roles swapped: `foreground`
is **Rain Wash**, a near-white with a green cast, and **Erin** becomes
`accent` and `focus`. Long prose then reads in a neutral rather than in
saturated green, and the Matrix green draws the eye instead of carrying every
paragraph.

Canvas, surfaces, status tones, non-role fills and both high-contrast lifts are
identical to Steelbore Green. `foreground` Rain Wash 17.51:1, `accent` Erin
14.94:1. A project declares one or the other, never both (§11.4).

### §11.4 — Palette Selection

- **Modern is the default.** An artifact that declares nothing uses
  `steelbore`; no declaration is needed to be compliant.
- **One palette per project**, declared in `README.md` beside the §5.2
  posture section. That palette is the project's **default** (§11.6.3), not the
  only theme it may render — §11.6.1 requires registering the family. Tokens are
  never **combined in one interface** — the contrast guarantees are computed
  per-palette and do not survive mixing. Replacing one palette's tokens with
  another's, whole-surface and at once, is not combining; §11.6.2 governs it.
- **Every palette ships its `<slug>-high-contrast` sibling** as the §18.1
  accessible-mode target. `steelbore-mono` is palette-independent.
- **A project may declare a light/dark pair.** `steelbore` is the family's dark
  default and `steelbore-navywhite` its light one (§11.3.4 is the only
  light-canvas member), or declare `light = none` with a stated reason to ship
  dark-only. §11.6.2 defines how the pair is used.
- **The canvas is mandatory within its palette.** Substituting a different
  background for a declared palette is non-compliant. The rule binds whichever
  palette is *in force*: when §11.6.2 switches, the new canvas comes with it.
- **Values are read, never retyped** — from `assets/steelbore.toml`. An
  OS-supplied theme registry (§11.6.4) is advisory, never authoritative.
- **Fidelity palettes are not adoptable.** The §11.5 palettes are registered for
  interoperability only; a project may not declare one, and they ship no
  high-contrast sibling.
- **Palettes have reference names** (§11.4.1) alongside their slugs. The slug
  stays the machine identifier.

#### §11.4.1 — Reference Names

Additive. The slug remains the machine identifier used by theme lookups and
`steelbore.toml` keys; the reference name is for prose and conversation. Both
ship in the canonical file, the reference name as each palette's `reference` key.

| Slug | Reference name |
|------|----------------|
| `steelbore` | `steelbore-color-palette` |
| `steelbore-classic` | `steelboreclassic-color-palette` |
| `steelbore-blue` | `blue-color-palette` |
| `steelbore-magnetar` | `magnetar-color-palette` |
| `steelbore-biolume` | `biolume-color-palette` |
| `steelbore-navywhite` | `navywhite-color-palette` |
| `tokyonight` | `tokyonight-color-palette` |
| `steelbore-hanzosteel` | `hanzosteel-color-palette` |
| `steelbore-blackpinkpanther` | `blackpinkpanther-color-palette` |
| `steelbore-green` | `green-color-palette` |
| `steelbore-greenalt` | `greenalt-color-palette` |
| `solarized-dark` | `solarizeddark-color-palette` |
| `solarized-light` | `solarizedlight-color-palette` |

### §11.5 — Fidelity Palettes (registered, non-conforming)

A **fidelity palette** reproduces a widely used external theme **exactly**, so
Spacecraft Software tooling can meet a user who already works in it. Values are
copied verbatim; no token is substituted, deepened, or lifted to make a number
pass. The consequence is stated plainly: **a fidelity palette is not required to
satisfy §11's contrast guarantee, and neither registered one does.** The ratios
below are *the measurement, not a target*.

| Palette | Slug | Canvas | Body text | Worst pairings |
|---------|------|--------|-----------|----------------|
| Solarized Dark | `solarized-dark` | `base03` base03 | `base0` 4.75:1 | 12 below 4.5:1; `structure`/`border` 2.97:1 and `error` 2.81:1 below 3:1 on `base02` |
| Solarized Light | `solarized-light` | `base3` base3 | `base00` **4.13:1 — under the AA floor** | `success` 2.97:1, `warning` 2.98:1, `focus` 2.93:1 below 3:1 — status cannot be signalled by color at all |

Rules:

- A project **MUST NOT** adopt a fidelity palette as its declared §11.4 palette.
  §13 (WCAG 2.2 AA) and §18 (accessible mode) are unaffected by this section.
- Offered as a *user-selectable* theme, a conforming palette stays the default
  and `steelbore-mono` (§11.1.1) stays the accessible-mode path.
- **No `-high-contrast` sibling.** Lifting the tokens would change the values the
  palette exists to reproduce.
- Recorded in `steelbore.toml` under `meta.fidelity-palettes`, with
  `conformance = "non-conforming"` in each theme's `rules` table.
- † marks a worst pairing of 3:1–4.5:1 (large text, icons, non-text UI only);
  ‡ marks below 3:1, which carries no legible use at any size.

Solarized (Ethan Schoonover, [ethanschoonover.com/solarized](https://ethanschoonover.com/solarized/))
defines one elevated tone per mode, so `surface-alt` shares `surface`.

### §11.6 — System Theme Declaration & Resolution

Added in v1.45. §11.1 says *how* to reference a color; §11.4 says *which* palette
is yours; §11.6 says **which member of the family renders on this machine, right
now** — and how an OS declares that.

**Scope.** Every application under the two §6.4 namespaces
(`github.com/Spacecraft-Software`, `github.com/UnbreakableMJ`), in **GUI, TUI and
CLI alike**. A CLI is not exempt: it already honors `NO_COLOR` (§18.2.1) and
already emits ANSI, so it already has a theme. Artifacts with no user-facing
output record §11.6 as N/A. **Games are not exempt** — §18.5 carves out §18 and
§10, never §11 — but a game satisfies §11.6 in its menus, HUD and settings
chrome, not in the world it simulates.

#### §11.6.1 — Shipping the family

A project **authors** against one palette and **registers** several. §11.4's
one-palette rule governs only the first.

| Obligation | Themes | Why |
|---|---|---|
| **MUST register** | The ten conforming palettes — `steelbore`, `steelbore-blue`, `steelbore-magnetar`, `steelbore-biolume`, `steelbore-navywhite`, `tokyonight`, `steelbore-hanzosteel`, `steelbore-blackpinkpanther`, `steelbore-green`, `steelbore-greenalt` — each with its `-high-contrast` sibling, plus `steelbore-mono`. **Twenty-one themes** | All bind the same eleven role tokens, so a layer that reads `steelbore.toml` registers them in a loop, and a declaration can always be answered |
| **MAY register** | `steelbore-classic`, `steelbore-classic-high-contrast` | Classic keeps the legacy six-role contract (§11.2), defines no surface class, and carries an `info` token that is not one of §11.1's eleven roles — registrable only by an app that implements that contract too |
| **MUST NOT register** | A §11.5 fidelity palette, except as an explicitly user-selectable extra | §11.5 bars adoption; this section is not a route around it |

Three of the twenty-one were already required (§11.4, §11.1.1), so this adds eighteen —
all already written out in `steelbore.toml`.

**Registering is not defaulting.** The default stays the project's §11.4 palette
(§11.6.3 source 5).

#### §11.6.2 — Light and dark

`steelbore-navywhite` (§11.3.4) is the family's only light-canvas member, so a
platform light preference can only be answered by rendering a **different
palette**.

**Switching is not mixing.** §11.4 forbids *combining* tokens from two palettes;
a color-scheme switch combines nothing — the whole token set is replaced at once,
the new canvas comes with it unaltered, and no frame ever carries a token from
two palettes. Two hard rules:

- **The switch is atomic and whole-surface.** One panel light and another dark,
  or a canvas cached from the previous palette, is non-compliant. An app that
  cannot re-theme atomically MUST resolve once at startup and hold.
- **The canvas travels with the palette.** A light background under a dark
  palette is the non-compliance §11.4 already names; it is not a light mode.

| Platform preference | Family default | With a declared pair |
|---|---|---|
| Prefer dark | `steelbore` | The declared dark member |
| Prefer light | `steelbore-navywhite` | The declared light counterpart |
| No preference | Source 4 does not fire | Source 4 does not fire |

- **A dark-only project declares it.** `light = none` plus a stated reason in
  `README.md` — a documented exception on the §14.2.1 footing, reported under
  `--verbose`. It does **not** get to ignore §18.
- **Solarized is not the pair it looks like.** §11.5 bars both from adoption, so
  neither is ever a source-4 target. Selected by a user at source 1 it stands as
  a preference, not conformance.
- Polarity and counterpart are recorded in `steelbore.toml` — read, never
  retyped (§11.4).

#### §11.6.3 — Resolution order

Two stages: a **base palette**, then a **variant overlay**. Keeping them apart is
what makes this composable — §18.1 and `NO_COLOR` choose a *sibling*, never a
palette, so an accessibility signal can never silently change the brand.

**Stage 1 — base palette**, highest first:

| Source | Form |
|---|---|
| **1. In-app selection** | `--theme=<slug>`, or `[theme] name = "<slug>"` in the project config |
| **2. Environment** | `SPACECRAFT_THEME=<slug>` — a slug, never a boolean |
| **3. System declaration** | the `active` key of the highest-precedence §11.6.4 file |
| **4. Platform color scheme** | the platform light/dark preference, mapped through §11.6.2 |
| **5. Project default** | the project's declared §11.4 palette — `steelbore` where it declares none |

- **An unusable slug is skipped, never fatal.** A non-conforming or unregistered
  slug is discarded and resolution continues one source lower. A typo in `/etc`
  never leaves a machine without a working interface (§3.1, graceful degradation).
- **Fidelity slugs resolve only at source 1** — a system declaration is adoption,
  and §11.5 bars it.
- **Source 4 is graphical only.** A terminal exposes no portable color-scheme
  query; probing for one is neither required nor relied upon. That is precisely
  why source 3 exists.
- Resolved theme, deciding stage-1 source, and stage-2 overlay MUST be reported
  under `--verbose`.

**Stage 2 — variant overlay.** Chooses which sibling of the stage-1 palette
renders; never changes the palette.

| Signal | Renders | Note |
|---|---|---|
| **1. Pinned variant** | as named | The user named a `-high-contrast`/`-mono` slug at stage-1 source 1 or 2. An explicit pin outranks every inferred signal |
| **2. `NO_COLOR`** | `steelbore-mono` | Mono is the only variant that surrenders color outright, so it outranks high contrast |
| **3. §18.1 accessible mode** | `<base>-high-contrast` | Resolved by §18.1, whose precedence this section neither restates nor modifies |
| **4. Platform high contrast** | `<base>-high-contrast` | Read from the platform independently of the §18.1 toggle (§18.3) |
| **5. None** | the stage-1 palette | The §11.1.1 default, unchanged |

- `NO_COLOR` is **a color instruction, not an accessibility instruction**. It
  selects mono whether or not it also enabled accessible mode as a §18.1
  source-4 hint, and `SPACECRAFT_A11Y=0` does not undo it.
- `steelbore-mono` is palette-independent, so the stage-1 palette does not
  render under it — but it is still resolved and still reported.
- A declaration's `high-contrast` key enters at signal 4 and selects a **theme
  sibling only**. It MUST NOT be read as enabling accessible mode; §18.1 is the
  sole switch.

#### §11.6.4 — The system declaration

Steelbore OS MUST let a **running** application read the active theme. The
mechanism is a plain file, deliberately: it has to work for a CLI in a text
console — no session bus, no portal, no daemon.

| Path | Role |
|---|---|
| `$XDG_CONFIG_HOME/steelbore/theme.toml` | Per-user declaration (`$XDG_CONFIG_HOME` defaults to `~/.config`) |
| `/etc/steelbore/theme.toml` | System declaration, written by the OS configuration |

Keys are read from the highest-precedence file that supplies them — a per-user
file setting only `active` does not erase the system file's `light`/`dark`.
**Absence of both files is no declaration** (resolution moves to source 4); a
file saying `active = "steelbore"` **is** a declaration *of Modern*, and the
distinction matters because a system may need to pin Modern rather than inherit
whatever the default later becomes.

```toml
# /etc/steelbore/theme.toml -- The Steelbore Standard, section 11.6
[theme]
active              = "steelbore"            # required: a conforming slug
dark                = "steelbore"            # optional: the dark member
light               = "steelbore-navywhite"  # optional: the light member
follow-color-scheme = true                   # optional, default true
high-contrast       = false                  # optional, default false

[meta]
standard = "11.6"                            # the clause this file targets
source   = "bravais"                         # optional: what wrote it
```

- **The declaration carries slugs, never colors.** An OS declares *which* theme;
  values come from `steelbore.toml` via the application's own copy (§11.4). Same
  division §13 draws for component systems: the platform chooses the vocabulary,
  never the colors.
- An OS MAY install a resolved registry at `/etc/steelbore/themes.json`. It is
  **advisory** — an app MUST NOT require it, and the app's own `steelbore.toml`
  governs on disagreement.
- `follow-color-scheme = false` disables source 4 for that scope.
- An unparseable file, or one with unknown keys, is **ignored with a warning**
  and the next source decides. Never fatal. `[meta] standard` lets a reader
  recognize a later revision and fall back conservatively.
- The variable is **`SPACECRAFT_THEME`**, in the same umbrella-wide
  `SPACECRAFT_` namespace as §18.1's `SPACECRAFT_A11Y`, carrying a **slug**.
  `STEELBORE_THEME` is **not** a Standard interface and MUST NOT be given slug
  semantics — it is already a boolean shell flag, and overloading it would make
  `STEELBORE_THEME=true` resolve to a nonexistent theme and fall through
  silently.
- Per-role color environment variables (`SPACECRAFT_BACKGROUND` and the like) are
  **not** a Standard interface. A conforming app reads role values from
  `steelbore.toml`, not the environment.

#### §11.6.5 — Obligations on the declaring side

Steelbore OS — every flavor: NixOS (Bravais), GNU Guix System (Ginx), or any
successor — MUST:

- **Render §11.6.4's declaration from its own theme selection**, so the one word
  that themes the machine is the word applications read. Generated, never
  hand-maintained alongside the selection.
- **Export `SPACECRAFT_THEME`** into the session environment, reaching graphical
  sessions and system services — not login shells alone.
- **Keep the platform color-scheme preference in agreement** with the declared
  palette's polarity. Declaring a light canvas while telling toolkits to prefer
  dark is internally inconsistent, and third-party apps read only the platform
  preference.
- **Validate the slug at configuration-evaluation time**, so an unknown theme
  fails the build rather than the boot.

An OS with a theme-switching command SHOULD also write the per-user declaration,
so a switch takes effect without a rebuild.
