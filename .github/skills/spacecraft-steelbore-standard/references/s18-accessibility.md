<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
## §18 — Accessibility (Opt-In Mode Layer)

Spacecraft Software applications must be usable by people who navigate by screen
reader, by keyboard alone, or with low vision. This chapter is the accessibility
contract for **all** application classes — CLI, TUI, and GUI — and supersedes §13's
design-system framing wherever the two overlap.

**Two-sided rule.** Accessibility support is **mandatory for the developer to
implement** and **optional for the user to activate**:

- **Every** Spacecraft Software application **other than a project registered as
  a game (§18.5)** MUST ship a working accessible mode. This applies to new and
  existing projects alike — no new-projects-only phase-in.
- Accessible mode is **off by default**. The default experience is the `Steelbore`
  theme and standard rendering, entirely unchanged. Enabling accessibility never
  becomes a precondition for normal use, and shipping it never degrades the default.

**Normative targets.** **WCAG 2.2 Level AA** where the success criteria apply, and
**EN 301 549 clause 11 (non-web software)** as the anchor for CLI and TUI, which
WCAG addresses only indirectly. Clause 11 is the only normative text that speaks to
terminal software; the European Accessibility Act has been enforceable since
2025-06-28.

### §18.1 — Activation

Resolved once at startup from four sources. Precedence, highest first:

| Source | Form |
|--------|------|
| **1. Command-line flag** | `--accessible` / `--no-accessible` |
| **2. Environment** | `SPACECRAFT_A11Y=1` / `SPACECRAFT_A11Y=0` |
| **3. Configuration** | `[accessibility] enabled = true` in the project config |
| **4. Auto-detect hints** | `TERM=dumb`, `NO_COLOR`, or `GTK_MODULES` containing `gail:atk` |

- A hint (source 4) **may** enable accessible mode, but never from an ambiguous
  signal. An explicit `--no-accessible` / `SPACECRAFT_A11Y=0` always wins.
- Unset at every source ⇒ **standard `Steelbore` rendering, unchanged.** Silence is
  never read as consent to change the default presentation.
- The resolved state and the source that decided it must be reported under
  `--verbose`.
- The toggle is a **single switch** governing §18.2 and §18.3 together.
  Per-feature accessibility flags fragment the contract and are not a substitute.

### §18.2 — CLI & TUI Requirements

**The constraint that shapes everything here:** a terminal has no accessibility
tree. No ARIA, no roles, no live regions. A screen reader reads the emulator's
character grid, so a redraw-based interface produces re-reads and speech loops
rather than useful speech. No terminal UI library provides accessibility — the
application must supply a linear fallback itself.

#### §18.2.1 — Rules that apply in every mode

Not gated behind the toggle; correctness requirements for all output, always:

- **Color is never the sole carrier of meaning.** Every colored status carries a
  text tag: `[OK]`, `[ERROR]`, `[WARN]`, `[INFO]`. A red line reading only "failed
  to connect" is non-compliant; `[ERROR] failed to connect` is compliant.
- **No text on colored fills** unless that pair is verified per §11.
- **Diagnostics to `stderr`, results to `stdout`** — never interleaved into one
  visual block.
- **`NO_COLOR`, `FORCE_COLOR`, `CLICOLOR`, `TERM=dumb`** honored with the
  precedence defined by `spacecraft-cli-standard`.

#### §18.2.2 — Rules that apply in accessible mode

| Requirement | Rule |
|-------------|------|
| **No animation** | Spinners, marquees, blinking text, and progress animations become a single static line with monotonic progress (`Working… 40%`), rewritten at most once per second |
| **No decorative art** | ASCII art, banners, box-drawing decoration, figlet headers suppressed. Where art is *informational*, emit an equivalent text description — do not simply drop it |
| **Linear output** | Append-only, reads correctly top-to-bottom; blank lines separate logical sections for paragraph navigation |
| **Tabular fallback** | Every table offers a non-columnar rendering — one `field: value` per line — since alignment conveys nothing through speech |
| **Prompt legibility** | Prompts state question, choices, and default in plain text before awaiting input. Prompts relying on cursor positioning or redraw are non-compliant |

#### §18.2.3 — TUI linear mode

Any full-screen TUI MUST additionally provide a **non-redraw, append-only stream
mode** reachable through the same §18.1 toggle: new state written as new lines
rather than repainted regions, without taking over the alternate screen buffer.

Where a TUI would otherwise be the only way to perform an operation, an equivalent
**non-interactive CLI path** must exist — flags plus `--json` — so the operation
stays scriptable and reachable without navigating a visual grid. Per §8, document
it in the project's Texinfo manual alongside the interactive path.

### §18.3 — GUI Requirements

| UI stack | Required bridge |
|----------|-----------------|
| **Rust, custom-drawn UI** | **AccessKit** (Apache-2.0) — one API over UI Automation (Windows), NSAccessibility (macOS), AT-SPI (Linux). Integrated in egui, Slint, Bevy, Freya, Xilem, winit |
| **GTK 4** | `GtkAccessible` — WAI-ARIA roles and states over AT-SPI |
| **Flutter** | `Semantics` widgets and `SemanticsRole` |
| **Qt** | `QAccessible` |

Custom-drawn widgets are the failure case: a canvas-rendered control is invisible
to assistive technology unless the application publishes its role and state
explicitly. That is the gap AccessKit closes — hence required, not suggested, for
Rust GUI work (§3.1 already makes Rust the preferred language).

- Every interactive element carries an explicit accessible **name** and **role**.
  Decorative elements are explicitly marked decorative so they are skipped.
- State changes that matter to the user are **announced**, not merely repainted.
- System **reduced motion** and **high contrast** preferences are honored
  independently of the §18.1 toggle — the user already expressed them system-wide.
- Keyboard reachability and focus visibility follow §10.

### §18.4 — Verification & Remediation

**Verification** — an accessibility claim is not satisfied by inspection:

- **CLI/TUI:** pipe accessible-mode output through a speech synthesizer (e.g.
  `espeak-ng`) and confirm it is comprehensible heard rather than seen. Confirm the
  non-interactive path completes the same operations as the interactive one.
- **GUI:** exercise with a real screen reader — Orca (Linux), NVDA (Windows),
  VoiceOver (macOS) — confirming every interactive element announces name and role.
- **Contrast:** measure the actual pairings used, not just foreground-on-background,
  and record the ratios (§11).
- **Keyboard:** complete every primary task without a pointing device.

**Remediation for existing projects.** §18 applies to every project, and a project
that does not yet conform is not thereby excused. What changed at v2.07 is *when* the
paper trail falls due.

A project MUST carry a **dated remediation entry** in `PROJECTS.md` — recording its
accessibility state and intended remediation — from the moment it **cuts a release tag
or declares itself usable by anyone other than the maintainer**, and until it conforms.
An absent entry at that point is a compliance failure in its own right: a shipped
project may be unfinished, but it may not be silently unfinished.

**Before that point the entry is optional**, and this is a correction rather than a
relaxation. From v1.33 the obligation attached on adoption, so every pre-release
experiment owed a dated assessment for existing at all — and at v2.06 exactly one
project carried one while roughly fourteen owed one. A rule breached universally
reports nothing about the projects that breach it and buries the one that did the work.
**Projects registered as games (§18.5) are excluded** — they owe no remediation entry,
because they owe no conformance.

### §18.5 — Games Carve-Out

**Projects registered as games are exempt from §18 in full and from §10 in full.**
Accessibility features in a game are **optional**: none is required, nothing is
enforced, and their absence is never a compliance failure. A game may ship an
elaborate accessibility suite, a single option, or nothing at all — entirely at
the maintainer's discretion (§5.4).

**Rationale:** §18 is built on CLI, TUI, and GUI assumptions — a character grid,
or a widget tree with roles and names. Games satisfy neither. They are real-time
simulations rendering custom, non-widget interfaces where play itself is the
purpose, and the accessibility techniques that suit them (remappable controls,
colorblind-safe signalling, subtitles, difficulty options) are a different
discipline from the one §18 codifies.

This is the **only** carve-out in §18, and it is narrow: it applies to registered
projects, not to any project that merely has a playful or game-like interface.

#### §18.5.1 — Declaration & Registry

A project is a game for the purposes of this Standard when **both** hold — the
same declaration-plus-registry pattern as the §5.3 general-use carve-out:

- The declaration appears in the project's `README.md`, alongside the §5.2
  posture section.
- The project is listed in the registry below.

**Games registry** (keep in sync with `PROJECTS.md` and the §2.1 registry):

| Project | Class |
|---------|-------|
| Ironway | **Game** — exempt from §18 and §10 |
| (all other projects) | Standard — §18 and §10 apply in full |

#### §18.5.2 — Recommended for Games (never required)

**Suggestions**, offered because they are low-cost and widely expected in games.
A game may adopt any, all, or none; declining is not a compliance failure and
needs no justification:

- **Remappable controls** — already standard practice in games, independent of
  accessibility.
- **Leave screen-reader chords alone** — `Insert`, `CapsLock`, `KP_Insert`, and
  `Ctrl`+`Option` are claimed by NVDA, Orca, and VoiceOver. Capturing them
  collides with a screen reader the player may be running.
- **Colorblind-safe signalling** — pair hue with shape, icon, or text.
- **Subtitles and captions** for spoken or plot-critical audio.
- **Honor the system reduced-motion preference** where the engine exposes it.

#### §18.5.3 — Shared Vocabulary

If a game *chooses* to ship an accessibility toggle, it should use the §18.1
names (`--accessible`, `SPACECRAFT_A11Y`) and the §11.1.1 theme-variant names
rather than inventing its own. This constrains only the *naming* of features the
game already decided to build — it requires no feature to exist.

---

