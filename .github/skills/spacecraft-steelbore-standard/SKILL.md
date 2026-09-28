---
name: spacecraft-steelbore-standard
description: >
  The authoritative compliance reference for ALL work on Spacecraft Software-umbrella projects and
  subprojects (Zamak, Bravais, Ferrocast, Craton, Ironway, Caliper, Mawaqit, and any future
  projects). ALWAYS load this skill before writing code, documentation, specifications,
  architecture decisions, UI designs, naming choices, or any other artifact for a
  Spacecraft Software-umbrella project — even if the user doesn't explicitly mention the Standard.
  If the user mentions "Spacecraft Software", a Spacecraft Software subproject name, or asks you to work on
  anything in the Spacecraft Software ecosystem, consult this skill immediately. It encodes
  The Steelbore Standard v2.09 (§19-§26 assurance + requirements + V&V; §13 design systems; §3.1.1 TypeScript; §5.7 AGENTS.md; §6.4 contribution targets; §5.6 skill packaging; §11 palettes + §11.6 system theme; §18 accessibility; §17 progress reporting; §3.3 security-by-design) so
  you never need to ask for it or have it attached to a prompt again.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# The Steelbore Standard — Compliance Reference

**Version:** 2.09 | **Date:** 2026-09-27 | **Author:** Mohamed Hammad
**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** Copyright (C) 2026 Mohamed Hammad & Spacecraft Software | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

This skill encodes The Steelbore Standard in full. Apply every applicable section
to any artifact you produce under the standard. The compliance checklist
in §16 is your audit gate — run through it mentally before finalising any output.

> **License note:** This skill is `GPL-3.0-or-later` (skills are software-class, §4.1.1).
> The *published* Standard document it encodes is licensed `CC-BY-SA-4.0`.

**Changelog:** see [`references/CHANGELOG.md`](references/CHANGELOG.md) for the full version history.

---

## §1 — Preamble

The Steelbore Standard defines the engineering principles, compliance requirements, and design conventions that govern all software produced under Spacecraft Software. The umbrella encompasses two categories of work: **Steelbore OS** — the operating system and all OS-specific artifacts (configurations, themes, OS tooling) — and **independent Spacecraft Software projects** such as Zamak, Ironway, Ferrocast, and Caliper, which are designed to work with Steelbore OS but are not OS-specific and may run on any compliant platform. Both categories are full citizens of Spacecraft Software and subject to this standard in full. Where a project-specific specification conflicts with this standard, the stricter of the two requirements shall prevail.

**Precedence over guidance skills.** This Standard is the supreme authority for every Spacecraft Software project. The convention- and language-guidance skills — `gnu-coding-standards`, the `*-guidelines` language skills, and the like — are **subordinate**: they supply idiom, craft, and (for `gnu-coding-standards`) GNU interoperability conventions where this Standard is silent, and **where any of them conflicts with this Standard, this Standard prevails**. The one deliberate exception is an artifact whose goal is to be **GNU-compliant** — an official GNU package, upstreamed to GNU/FSF, or hosted on Savannah — whose GNU/FSF requirements flatly oppose this Standard's *identity* clauses (§2 naming, §11–§12 branding, §15 attribution, GitHub hosting). Such an artifact MAY adopt the **free-software/GNU posture** (the self-sufficient `gnu-free-software` skill); under it those identity clauses yield, while this Standard's GNU-silent clauses — §6.3 signed commits, §14 UTC dates, §3.3 security-by-design — still apply and stack. Absent that posture (the default for every Spacecraft project), this Standard governs in full and GNU conventions are adopted only where they aid interoperability (the GNU-*compatible* posture; see `gnu-coding-standards`).

**Standard name vs. project naming.** "The Steelbore Standard" is the canonical, stable name of *this standard*. It is independent of the projects it governs and of the umbrella organization name — the standard retains this name regardless of any future renames. The v1.7 umbrella rename (Steelbore → Spacecraft Software) and the v1.8 reinstatement of this standard's name are recorded in the changelog. Versioning of project codenames (see §2) and versioning of the standard are separate concerns.

---

## How to use this skill

This file is the core of the skill: the masthead, §1, and the sections that bear
on nearly every task — §3, §17, §16 and the Skill Cross-References — reproduced
in full, plus the short §11 and §19–§26 stubs, whose full text lives in
`references/palettes.md` and `references/engineering-process.md`. Every other
section lives, verbatim, in its own file under `references/`; the index below
maps each section to its file.

- **Load the reference file for the section in play** before acting on it — the
  §4 file before choosing a license header, the §14 file before writing a
  timestamp, the §11 palette reference before choosing a colour.
- **For an audit, load §16 (below) plus every section it cites.** Each checklist
  line names its sections; the index resolves each one to its file.
- Section numbers are the Standard's own, so a citation such as "§5.6" in another
  skill or document resolves through the index to the file that carries it.

## Section Index

| § | Title | File | Scope (in the section's own words) |
|---|-------|------|-------------------------------------|
| §1 | Preamble | core (above) | The Steelbore Standard defines the engineering principles, compliance requirements, and design conventions that govern all software produced under Spacecraft Software. |
| §2 | Aerospace, Sci-Fi & AI Naming Convention | [`references/s02-naming.md`](references/s02-naming.md) | All **new** project codenames, module identifiers, and public-facing component names **must** draw from one of the following domains: Real aerospace and astronomy; Science-fiction franchises with space / AI / cybernetic themes; Generic sci-fi / AI vocabulary. Legacy Metallurgical Registry (pre-v1.2); Skill IDs are functional, not codenamed |
| §3 | Priority Hierarchy (Non-Negotiable Order) | core (below) | A higher-numbered priority **may never compromise** a lower-numbered one. |
| §4 | Licensing & Compliance | [`references/s04-licensing.md`](references/s04-licensing.md) | Project License (GPL-3.0-or-later or AGPL-3.0-or-later); Upstream License Compliance (preserve what you build on); SPDX & REUSE Compliance |
| §5 | Project Posture | [`references/s05-posture.md`](references/s05-posture.md) | Default Posture (Personal / Hobby); Required Posture Files (per project); General-Use Carve-Out; Maintainer Discretion; Package Distribution Requirements; Skill Packaging Requirements; Agent Context Files |
| §6 | Platform & Systems Requirements | [`references/s06-platform.md`](references/s06-platform.md) | POSIX Compliance; Post-Quantum Cryptography; Signed & Verified Commits (Non-Negotiable); Authorized Contribution Targets (Non-Negotiable); Text File Format (LF, UTF-8, final newline) |
| §7 | Shell Environment | [`references/s07-shell.md`](references/s07-shell.md) | Spacecraft Software tooling, documentation, and CI pipelines target **four first-class shell environments**: **Nushell**, **Ion**, **Brush**, and **Bash**. |
| §8 | Documentation (Texinfo) | [`references/s08-documentation.md`](references/s08-documentation.md) | Spacecraft Software user-facing projects should ship a **Texinfo manual** as the canonical technical reference. |
| §9 | Privacy-Friendly Application (PFA) Policy | [`references/s09-privacy.md`](references/s09-privacy.md) | No Tracking/No Ads; Minimal Permissions; Local Storage; No Third-Party Subresources |
| §10 | Key Bindings | [`references/s10-key-bindings.md`](references/s10-key-bindings.md) | CUA; Vim; Remappability (mandatory); Reserved assistive-technology chords |
| §11 | Spacecraft Software Color Palettes (WCAG-Compliant) | [`references/palettes.md`](references/palettes.md) (stub: core, below) | **Full text: [`references/palettes.md`](references/palettes.md).** Load it before any color, theme, contrast, or palette-token decision. |
| §12 | Typography (FOSS-Licensed Fonts Only) | [`references/s12-typography.md`](references/s12-typography.md) | Acceptable font licenses: **OFL, Apache 2.0, Ubuntu Font License, CC0-1.0** |
| §13 | UI/UX Design System | [`references/s13-design-system.md`](references/s13-design-system.md) | **Every graphical application declares exactly one component system**, named in its `README.md` beside the §5.2 posture section, and themes it with the §11 palette. |
| §14 | Date, Time & Units | [`references/s14-date-time-units.md`](references/s14-date-time-units.md) | Date & Time Format Rules; UTC Z Timezone Policy; Domain Exception: Inherently Local-Time-Bound Projects; Local Time as Optional Companion; Duration Format; Rust Implementation Guidance |
| §15 | Attribution, Maintainer & Contact | [`references/s15-attribution.md`](references/s15-attribution.md) | Project Pages; Mandatory Attribution in Project Outputs; Third-Party Attribution; Authoring Model Attribution; Agent Work Log (`.agent-log.jsonl`) |
| §17 | Development Progress Tracking & Reporting | core (below) | When implementing features or writing code based on a Product Requirements Document (PRD) or project plan, coding assistants and developers must continuously track and report progress. |
| §18 | Accessibility (Opt-In Mode Layer) | [`references/s18-accessibility.md`](references/s18-accessibility.md) | Spacecraft Software applications must be usable by people who navigate by screen reader, by keyboard alone, or with low vision. Activation; CLI & TUI Requirements; GUI Requirements; Verification & Remediation; Games Carve-Out |
| §19–§26 | Assurance, Requirements, V&V and Operations | [`references/engineering-process.md`](references/engineering-process.md) (stub: core, below) | **Full text: [`references/engineering-process.md`](references/engineering-process.md).** Load it when doing assurance, requirements, verification, interface-control, baseline, or operations work. |
| §16 | Compliance Checklist (Audit Gate) | core (below) | Before finalising **any** Spacecraft Software artifact, mentally verify: |
| — | Skill Cross-References | core (below) | Task → Load this skill |

---

## §3 — Priority Hierarchy (Non-Negotiable Order)

A higher-numbered priority **may never compromise** a lower-numbered one.

### §3.1 — Priority 1: Stability
Software must behave predictably and remain correct under sustained and adverse
conditions. Stability is the foremost priority. **Memory safety is the single most
important contributor to stability and the primary means of achieving it — but it is
not the whole of Priority 1.**

**Memory safety (primary lever):**
- **Preferred language: Rust** — governed by the Spacecraft Software Rust Guidelines.
  → Always load the `microsoft-rust-guidelines` skill before writing any Rust code.
- When Rust is not viable (Flutter/Dart, Zig, etc.), **mandatory mitigations**:
  - **ASLR** (Address Space Layout Randomization) on all compiled binaries
  - **CFI** (Control-Flow Integrity) wherever the toolchain supports it
- Memory-Safe Languages (MSLs) are always preferred. If an MSL alternative exists,
  it must be chosen unless a documented technical exemption is filed.

**Beyond memory safety, stability also requires:**
- **Robust error handling** — failures must be surfaced and handled, never silently
  swallowed; no panics / `unwrap` / `expect` on untrusted or fallible input in production paths.
- **Fault tolerance and graceful degradation** — components must survive partial failure,
  degrade gracefully under load or dependency loss, and recover rather than crash.
- **Verified** — stability properties must be backed by evidence under §21, at the level
  §21.2 requires for the project's assurance category (§19), gating CI and traced to the
  requirement it discharges (§21.3). Tests (unit, integration, and fuzz/property where
  applicable) are the default method, never the only admissible one, and no property is
  asserted by inspection alone unless inspection is its declared method.

### §3.1.1 — TypeScript over JavaScript

JavaScript is not a preferred language under §3.1: it is dynamically typed, so whole classes
of defect that a compiler would reject survive into production and surface as run-time
failures. The memory-safety lever does not apply — the runtime is memory-safe either way —
so **type safety is the stability lever available here**, and the standard requires it be pulled.

Where a memory-safe alternative exists (Rust compiled to WebAssembly, Rust or Go for a server,
Flutter/Dart for an application UI), it must be chosen per §3.1. **Where the JavaScript runtime
is genuinely required** — a browser page, a Node/Deno/Bun program, an Electron application, an
npm-distributed tool, a VS Code extension — the source language MUST be **TypeScript**. Plain
JavaScript source is a documented exemption, not a default.

- **Strict mode is mandatory.** `tsconfig.json` sets `"strict": true`, and additionally
  `noUncheckedIndexedAccess`, `noImplicitOverride`, and `exactOptionalPropertyTypes`.
  A configuration that relaxes `strict` is a Priority 1 regression.
- **No silent escape hatches.** `any` and non-null assertions (`!`) are prohibited in
  production paths; use `unknown` plus narrowing. `@ts-ignore` is prohibited outright —
  where a suppression is unavoidable, use `@ts-expect-error` with a comment naming the
  reason, so the suppression fails the build once it becomes unnecessary.
- **Validate at the boundary.** Data crossing a trust boundary (network responses, files,
  environment, IPC, user input) is `unknown` until parsed by a run-time validator. A type
  annotation is a compile-time claim, not a check — asserting a shape that was never verified
  is exactly the silent-failure mode §3.1 forbids.
- **Compiled output is not source.** Emitted `.js` (and its source maps) in a build directory
  is a *derived artifact* and is outside this rule. The rule governs what is authored and committed.
- **The build must typecheck.** `tsc --noEmit` (or the equivalent project-wide check) gates CI.
  A project that only transpiles — stripping types without checking them, as esbuild, SWC, and
  Bun do by default — has not satisfied this section.
- **Load the guidelines skill** — `spacecraft-typescript-guidelines` — before writing or
  reviewing any TypeScript.

**Exemptions.** Plain JavaScript remains acceptable, without filing, only where TypeScript
cannot express the artifact: a tool's own configuration file that must be `.js` (e.g.
`eslint.config.js` where no TypeScript loader is available), a vendored or upstream-derived
file carried under §4.2, and generated output. Anything else — including "it is only a small
script" — requires a documented technical exemption in the project's README or architecture
notes, in the same manner as the §3.1 memory-safe-language exemption.

### §3.2 — Priority 2: Performance
Performance is the foremost priority after stability. Modern hardware universally provides
**multi-core, multi-thread** capability; harnessing that concurrency is the primary means of
achieving performance. Concurrency is not an afterthought — it must be **considered from the
ground up**, throughout architecture design: data ownership, thread boundaries, synchronization
points, and parallelism opportunities must be identified during design, not discovered during
optimization.

Concurrency is adopted where it genuinely advances performance. It is **abandoned** where it
degrades performance (synchronization overhead, lock contention, or inherently serial / small
workloads) or where it would compromise Priority 1 (Stability). When a serial or simpler
approach outperforms or is safer, it must be chosen and the trade-off documented.
- Release builds should use CPU-optimized flags — `-march=native`, LTO, PGO —
  **where the toolchain and target support them reliably.** **Every applied flag must
  be explicitly noted** (e.g., a comment in the build file or a build-time message);
  **every disabled flag and the reason for disabling must be equally noted.** Visible
  flag state at compile time makes errors traceable to a specific flag. Any flag known
  to break or destabilize a build on a given platform/toolchain/linker (e.g., LTO
  under certain NixOS, cross-compilation, or static-linking setups) MUST be disabled.
  Stability (P1) outranks Performance (P2) — never ship a broken build for the sake
  of a flag.
- Performance figures are measured against declared budgets and margins (§22), so that a
  benchmark answers whether the figure is **acceptable** and not only whether it moved.
  Benchmarking is **mandatory** before and after any optimization work; regressions must
  be documented and justified — and it is the evidence by which the concurrency-vs-serial
  trade-off above is decided.

### §3.2.1 — Platform-Specific Compiler & Linker Flag Caveats

Compiler and linker optimization flags are **not universally portable** across operating
systems and distributions. Just as systemd-specific settings do not apply to non-systemd
distros (e.g., GNU Guix System, Void Linux, Gentoo with OpenRC), linker and LTO flags
must be adapted to the target platform's toolchain layout.

**NixOS / Steelbore OS Bravais:** Because NixOS isolates packages in the `/nix/store`,
GCC's LTO plugin is not on the standard linker search path. When using `-flto` (Link Time
Optimization) on NixOS, you **must** explicitly point GCC's linker to the GCC LTO plugin
via `-fuse-ld=mold` (preferred) or `-fuse-ld=bfd` (fallback). Without this, LTO-enabled
builds will fail to link.

> **Rule:** Whenever recommending or applying compiler/linker flags — especially `-flto`,
> `-march=native`, or PGO — verify whether the target OS requires supplementary flags or
> alternative linker selection. Document the OS-specific requirements alongside the flags.

### §3.3 — Priority 3: Security by Design
- Kernel hardening (XanMod, grsecurity profiles) where applicable.
- Sandboxing and privilege separation for all network-facing components.
- **Post-Quantum Cryptography (PQC) readiness**: all crypto subsystems must support
  PQC migration paths. Use hybrid schemes (classical + PQC candidate) where library
  support exists. Adopt NIST-finalized PQC standards within one major release cycle.
  - Current targets: ML-KEM-768, ML-DSA-65 (as used in Ferrocast)
- Dependency auditing: `cargo-audit` or equivalent before any third-party crate inclusion.

**Cardinal Rule:** Any optimization that weakens **stability (including memory safety)** or
security hardening **must be rejected**, no exceptions.

---

## §11 — Spacecraft Software Color Palettes (WCAG-Compliant)

**Full text: [`references/palettes.md`](references/palettes.md).** Load it
before any color, theme, contrast, or palette-token decision.

Spacecraft Software ships a **palette family** — thirteen palettes, each declaring
one canvas, a full set of §11.1 role tokens, and a verified contrast guarantee.
`references/palettes.md` carries §11.0 through §11.6 in full: Modern and
Classic, the nine alternates, the two Solarized fidelity palettes, the
accessibility variants, and the system-theme contract.

The rules that gate everyday work, and hold without loading the reference:

- **One palette per project.** A project adopts exactly one and never mixes
  tokens across palettes.
- **Every reference goes through a named theme** — never a raw hex in
  application code.
- **Values are read, never retyped** (§11.4), from the
  `steelbore-color-palette` skill's `assets/steelbore.toml`. That file is the
  machine-readable form; an OS-supplied theme registry (§11.6.4) is advisory,
  never authoritative.
- **`steelbore` (Modern) is the default.** Classic, Blue, Magnetar, Biolume,
  NavyWhite, Tokyo Night, Hanzo Steel, BlackPinkPanther, Green and Green Alt
  are opt-in (§11.4). **`steelbore-blackpinkpanther` changed meaning at v2.08** —
  it named the violet palette now called Magnetar.
- **Fidelity palettes are not adoptable.** The §11.5 Solarized pair is
  registered for interoperability only and ships no high-contrast sibling.

---

## §17 — Development Progress Tracking & Reporting

When implementing features or writing code based on a Product Requirements Document (PRD) or project plan, coding assistants and developers must continuously track and report progress. This reporting ensures transparency, early detection of drift, and alignment on the implementation status of key milestones.

### §17.1 — Progress Reporting Format

A progress report is a block of labelled rows, one row per tracked track. Every row carries its own 20-cell bar and its own percentage, so each figure is legible on its own line rather than compressed into a shared summary line.

**Format template:**
```
M0:   [████████████░░░░░░░░]  60%
M1:   [████████████░░░░░░░░]  60%
M2:   [████████████░░░░░░░░]  60%
M3:   [████████████░░░░░░░░]  60%
M4:   [████████████░░░░░░░░]  60%
MVP:  [██████████████░░░░░░]  70%
TODO: [████████████░░░░░░░░]  60%
PLAN: [████████████░░░░░░░░]  60%
PRD:  [████████████░░░░░░░░]  60%
```

**Percentages have a denominator.** Where the project maintains a requirement set (§20), each figure is the fraction of that milestone's baselined requirements whose status is `verified` (§20.3), read from the traceability matrix (§21.3) rather than estimated. Where no requirement set exists — Category D work, or a project below the §19.3 threshold — the figure is the maintainer's estimate and is understood as one. A percentage that cannot name what it is a fraction of is an impression, and impressions are what §17 exists to replace.

**Row order** is fixed: milestone rows `M0`…`Mn` in ascending order, then `MVP`, then `TODO`, then `PLAN`, then `PRD`.

**Only applicable rows are emitted.** The milestone rows match the milestones the plan actually defines — there is no fixed count, and `M0`–`M4` in the template above is an illustration, not a required set. `TODO`, `PLAN`, and `PRD` each appear only when the task is driven by such an artifact. `MVP` is always present. A row is never padded in at 0% to fill out the block: a fabricated track reports progress against nothing and misrepresents the work.

### §17.2 — Progress Bar Style

Every bar is a static, 20-cell, high-visibility Unicode bar. Legacy ASCII characters — `#`, `-`, `=` — are forbidden in any bar.

A single cell style applies to every row — milestones, `MVP`, `TODO`, `PLAN`, and `PRD` alike: filled cells are `█` (U+2588), empty cells are `░` (U+2591), and the brackets are tight, with no space inside either bracket.

**Column alignment is normative.** With one style shared by every row, alignment follows from three rules:

- On every row, the label and its colon are left-aligned in a six-character field, followed immediately by `[`.
- That places the first bar cell in column 8, so every bar occupies columns 8 through 27 and the closing bracket lands in column 28.
- The percentage is right-aligned in a five-character field immediately after the closing bracket, so its `%` sign lands in column 33 whether the value is one, two, or three digits. The separator never drops below one space — at exactly 100% the number consumes one of the two separator spaces — and the block stays aligned at every value.

**Cell count.** The number of filled cells is the percentage scaled to twenty cells and rounded to the nearest cell. Two saturation rules override the rounding: a bar shows twenty filled cells **only** at exactly 100%, and zero filled cells **only** at exactly 0%. Rounding 99% up to a visually complete bar reports work as finished that is not, which is the drift this chapter exists to catch.

### §17.3 — Reporting Cadence

Progress must be reported:
- At the start of a coding task (initial estimate/baseline)
- At the completion of each logical component or milestone task
- When summarizing the work done at the end of a turn/message

### §17.4 — Closing TL;DR

§17.1 through §17.3 govern the report a reader consults when they want the
numbers. This section governs the two lines a reader gets when they want nothing
else.

**Every turn that hands control back to the user ends with a TL;DR block** —
work finished, work stopped part-way, or a question that blocks further
progress. The block is the last thing in the turn, after the prose and after any
§17.1 progress block, and it is **exactly two lines** opening with the marker
`TL;DR:`.

**Two closing shapes, and the distinction is normative:**

| Outcome | Closing line |
|---------|--------------|
| Work complete | The second line ends with a plain statement that the work is finished — `Job is done.` or an equivalent in the same register. No question mark, because nothing is being asked. |
| Input required | The second line ends with a **question mark**, and the question is the actual decision the user has to make — named, answerable, and specific enough to answer in one word or one sentence. "Let me know how you want to proceed?" names nothing and does not satisfy this. A turn that stops without a question mark is asserting that nothing is blocked on the user, so a turn that needs an answer and ends in a period will simply not get one. |

**Simplified English is a requirement, not a preference.** The two lines use
short, common words and short sentences. Project jargon, unexplained
abbreviations, section numbers, identifiers, and file paths stay in the prose
above; a reader who skipped the entire turn must still understand what happened
from the TL;DR alone. It is a summary for a person who is not reading closely,
which is the condition under which most end-of-turn text is actually read.

**`Job is done` is a claim about the work, not a closing pleasantry.** It is
written only when the work is genuinely finished and verified — the same honesty
rule §17.2 applies to a saturated bar, which shows twenty filled cells only at
exactly 100%. Work that is partly done says so and says what remains. A TL;DR
that reports completion the prose above it does not support is worse than no
TL;DR at all, because it is the part the reader trusts.

**Format template:**

```
TL;DR: The build is fixed and all tests pass.
Job is done.
```

```
TL;DR: I can rename the module, but two projects still import the old name.
Should I update those imports too?
```

**The TL;DR never replaces what it summarizes.** It is added to the turn, never
substituted for the detail, the file list, the caveats, or the §17.1 progress
block. Two lines cannot carry a hand-off, and a turn that answers with a TL;DR
alone has reported nothing.

---

## §19–§26 — Assurance, Requirements, V&V and Operations

**Full text: [`references/engineering-process.md`](references/engineering-process.md).**
Load it when doing assurance, requirements, verification, interface-control,
baseline, or operations work.

§3 fixes the priority order for every artifact; it does not say how much
*evidence* a given artifact owes. §19–§26 answer that, and the reference
carries them in full:

| §   | Covers |
|-----|--------|
| §19 | Assurance categories, tailoring, and how conformance is claimed |
| §20 | Requirements engineering |
| §21 | Verification, validation & traceability |
| §22 | Resource budgets & margins |
| §23 | Interface control |
| §24 | Reuse & third-party qualification |
| §25 | Baselines, anomalies & release acceptance |
| §26 | Operations, maintenance & support |

The entry point is §19: an artifact's **assurance category** determines the
evidence it owes, a project may **tailor** with a justified register, and the
conformance claim in `README.md` names the standard version, the category, and
whether the claim is full or tailored. Everything downstream follows from that
category — read §19 before assuming a §20–§26 obligation applies.

---

## §16 — Compliance Checklist (Audit Gate)

Before finalising **any** Spacecraft Software artifact, mentally verify:

- [ ] **§2** Aerospace/Sci-Fi/AI naming convention applied to all **new** identifiers; legacy (pre-v1.2) names preserved unless explicitly renamed
- [ ] **§3.1** Stability: memory safety (Rust, or ASLR+CFI documented); robust error handling, fault tolerance, and test-verified
- [ ] **§3.1.1** Where the JavaScript runtime is required, source is **TypeScript** under `"strict": true` (plus `noUncheckedIndexedAccess`, `noImplicitOverride`, `exactOptionalPropertyTypes`); no `any` / `!` / `@ts-ignore` in production paths; boundary data validated at run time; `tsc --noEmit` gates CI; any plain-JavaScript source outside the listed exemptions is documented — N/A for projects with no JavaScript runtime
- [ ] **§3.2** Performance: concurrency considered throughout architecture design; adopted where it advances performance, abandoned where it degrades performance or compromises Stability; serial trade-off documented; compiler optimization flags applied/disabled with explicit notation; benchmarking before/after
- [ ] **§3.3** Hardened security; PQC readiness addressed
- [ ] **§4.1** License is `GPL-3.0-or-later` or `AGPL-3.0-or-later` (AGPL for network-facing; per §4.1)
- [ ] **§4.2** Upstream copyright notices, license texts, and `NOTICE`/`AUTHORS` preserved verbatim; upstream licenses shipped in `LICENSES/`
- [ ] **§4.3** REUSE-compliant: two-tag SPDX header (`SPDX-FileCopyrightText` + `SPDX-License-Identifier`) on every file (or `.license` sidecar / `REUSE.toml` entry); `LICENSES/` directory present; root `LICENSE` carries the canonical license text and `LICENSES/<SPDX-id>.txt` symlinks to it (never two independent copies); license files named per §4.3 (`LICENSE` with no extension, `LICENSE.<TAG>` per license when more than one applies, `COPYING` only ever a symlink); `reuse lint` passes
- [ ] **§5** Project Posture: README/NOTICE/CONTRIBUTING present; default personal-hobby stance applied; general-use carve-outs declared in project README
- [ ] **§5.5** Package distribution: `packaging/guix.scm`, `packaging/default.nix`, and `packaging/PKGBUILD` present, buildable, and carrying correct version + SHA-256 checksum (in each package manager's native format) before any release tag is pushed
- [ ] **§5.6** Skill packaging: every `SKILL.md` `description` measures ≤ 1000 rendered characters (folded scalars counted as the loader sees them, not as raw lines); the cap is enforced by CI *and* by the command that produces the bundle, not only by a local git hook; every skill directory carries a `LICENSE` (§4.3 naming, byte-identical to the repo root, a regular file) and every bundle ships it — N/A for projects that ship no skills
- [ ] **§5.7** Agent context files: `AGENTS.md` and `CLAUDE.md` both present at the repository root and version-controlled; `CLAUDE.md` is an `@AGENTS.md` import plus Claude-only content and restates nothing; neither file is gitignored; no credentials, private hostnames, or personal filesystem paths in either; managed blocks rendered into `AGENTS.md` only
- [ ] **§6.1** POSIX-compliant CLI/system tools
- [ ] **§6.5** Text files are LF-terminated, UTF-8 without BOM, and end with a newline; `.gitattributes` (`* text=auto eol=lf`) and `.editorconfig` (`charset`, `end_of_line`, `insert_final_newline`) present at the repository root; CI fails on a CR byte in a tracked text file; CRLF exceptions (vendored upstream, `cmd.exe` scripts) pinned explicitly in `.gitattributes`
- [ ] **§7** Shell scripts are POSIX-compatible; Nushell/Ion native variants provided where shell-native idioms are required; no Bashisms in shared scripts
- [ ] **§8** Texinfo manual present for user-facing programs (`doc/<project>.texi`); builds to `.info`, `.html`, and `.pdf`; `install-info` hook present in all three package manifests (§5.5) — N/A for scripts and internal tooling
- [ ] **§9** PFA: no tracking, minimal permissions, local storage default; **§9.1** no third-party subresources — fonts declared `local()`-first and bundled only if fidelity requires it, other assets shipped beside the artifact, nothing fetched from a host the project does not control, with any unavoidable exception declared in `README.md`
- [ ] **§10** CUA + Vim-like key bindings planned/implemented; bindings user-remappable; assistive-technology modifier chords (NVDA/Orca/VoiceOver) not captured — N/A for projects registered as games (§18.5)
- [ ] **§11** A registered palette is used — Steelbore Modern by default, or exactly one declared alternate (§11.4), never a mix; that palette's canvas is used unaltered; surface tokens are fills only, never text (§11.0.1); token-on-token pairings outside the palette's verified matrix measured before use; new apps expose colors via a named `Steelbore` theme binding the §11.1 role tokens — no bare hex literals in UI logic — and ship the palette's `-high-contrast` sibling
- [ ] **§11.6** Theme resolution implemented in two stages — base palette (in-app selection, then `SPACECRAFT_THEME`, then the §11.6.4 system declaration, then the platform color scheme, then the project's §11.4 default), then variant overlay (a pinned variant, then `NO_COLOR` ⇒ `steelbore-mono`, then §18.1 accessible mode, then platform high contrast); the registered set covers §11.6.1's twenty-one eleven-role themes; an unknown or unregistered slug falls through rather than failing; palette switches are atomic and whole-surface and carry the new canvas; resolved theme and deciding source reported under `--verbose`; no dependence on per-role environment variables — Steelbore OS additionally renders `/etc/steelbore/theme.toml`, exports `SPACECRAFT_THEME`, and keeps the platform color-scheme preference in agreement with the declared polarity (§11.6.5) — N/A for artifacts with no user-facing output
- [ ] **§12** FOSS-licensed fonts only (Share Tech Mono / Inconsolata)
- [ ] **§13** Exactly one component system declared in `README.md` and followed — Material Design for Flutter/web/mobile/cross-platform, GNOME HIG for GTK 4, KDE HIG for Qt 6; themed through the `steelbore` theme (§11.1); WCAG 2.2 AA verified, stating which pairing was measured
- [ ] **§14** ISO 8601 dates; 24h time; UTC Z is the default primary timestamp (companion local time with UTC offset permitted, never a replacement) — unless the project filed the §14.2.1 domain exception for inherently local-time-bound data; ISO 8601 durations; metric units
- [ ] **§15** Attribution present: maintainer name (`Mohamed Hammad`), contact (`Mohamed.Hammad@SpacecraftSoftware.org`), and project URL in `--version` / README / About
- [ ] **§15.3** Third-party work credited in `CREDITS.md` at project/skill root when triggers apply; deeper `references/ATTRIBUTION.md` present where reference content is adapted from external sources
- [ ] **§17** Development progress tracked and reported continuously as the §17.1 labelled-row block — one 20-cell bar per track, milestone rows then MVP then TODO/PLAN/PRD, only the rows that apply; every row set in `█`/`░` with tight brackets, columns aligned, no ASCII bars
- [ ] **§17.4** Every turn that hands control back to the user ends with a two-line `TL;DR:` block in simplified English, placed last: a plain statement of completion when the work is finished and verified, or a question mark naming the actual decision when the user's input is required; never substituted for the detail or the §17.1 block
- [ ] **§18** Accessible mode implemented and off by default; §18.1 toggle honored with correct precedence; status never color-only; no animation or decorative art in accessible mode; TUI ships a linear mode and a non-interactive CLI path; GUI publishes accessible names and roles (AccessKit for Rust); verified with a real screen reader; a project that has cut a release or declared itself usable carries a dated remediation entry in `PROJECTS.md` until it conforms, and a pre-release project owes none (§18.4) — N/A for projects registered as games (§18.5), which are exempt in full
- [ ] **§19** Assurance category (A/B/C/D) declared in `README.md`, `AGENTS.md`, and `PROJECTS.md`, with any raised subsystem named; every *Recommended* obligation of §19.3 that is not implemented carries a dated tailoring-register entry (§19.5) in `COMPLIANCE.md` for Category A and B, or in `README.md` for C and D; the three gates of §19.4 passed with their evidence; the §19.6 conformance claim in `README.md` names the standard version, the category, and whether the claim is full or tailored
- [ ] **§20** Requirements written at the level §19.3 requires (Texinfo `Requirements` node for A and B, `AGENTS.md` list for C); each carries a permanent identifier, rationale, source, priority, verification method, and status; §20.2 verbal forms used, with `shall` carrying obligation; the §20.4 characteristics gate run over each requirement and over the set; no unmeasurable adjective, open-ended clause, or escape hatch in requirement text (§20.5) — N/A for Category D
- [ ] **§21** Every requirement declares one of the four §21.1 methods; verification evidence meets the §21.2 floor for the category; the traceability matrix is generated by tooling on every CI run, fails on an unverified requirement or an unknown identifier, and ships with the release; independence obtained from a §21.4 mechanism for Category A and B; validation performed at G3 against the needs, on the target platform, from installed packaging, and recorded (§21.5)
- [ ] **§22** Budget ceilings declared at G2 for every applicable resource, each naming its reference machine and workload; measurement automated in CI; margins reported with their band; no red band at the release gate for Category A or B, and no ceiling re-baselined without a dated justification — N/A for Category D
- [ ] **§23** Interface inventory complete across all seven classes; ICD present as an `Interfaces` node with identity, version, contract, error behaviour, stability class, committed schema, and known consumers; breaking changes carried in a major version after a deprecation period (§26.3); the ICD baselined at G3 — N/A for a project exposing no interface
- [ ] **§24** Dependencies qualified at the depth §19.3 requires, with purpose, provenance, maintenance, security history, unsafe posture, transitive weight, alternatives, and exit plan recorded; `cargo audit` and `cargo deny` gate CI, not just adoption; lockfile and toolchain pinned; no unqualified software on a Category A path; an SBOM generated from the locked inputs in the release CI run and shipped with a checksum
- [ ] **§25** Baselines cut at all three gates covering source, dependencies, toolchain, requirements, budgets, and interfaces; anomalies classified S1–S4 by consequence, S1 and S2 closed only by a committed regression test citing the anomaly, and open anomalies listed in the release notes; release manifest assembled with identity, artifacts and checksums, provenance, verification and validation summaries, budgets, known issues, and the conformance claim; installation verified from each of the three §5.5 package definitions in a clean environment before the tag is pushed
- [ ] **§26** `SECURITY.md` present with reporting channel, acknowledgement target, scope, supported versions, disclosure terms, and credit policy; advisories published for fixed vulnerabilities and citing the SBOM; deprecations announced in `CHANGELOG.md`, the ICD, and at run time, with the notice period the category requires and a named replacement; support window stated for the project's posture; an ended project taken through the §26.4 EOL procedure rather than left silent
- [ ] **§6.3** All commits to Spacecraft Software Git remotes cryptographically signed with the `Mohamed.Hammad@SpacecraftSoftware.org` key and showing "Verified" on the hosting platform; rewrites preserve signatures; programmatic and assistant-driven commits signed too
- [ ] **§6.4** No commit, pull request, patch, issue, or package publication sent to a namespace outside `Spacecraft-Software` / `UnbreakableMJ` without explicit per-contribution maintainer authorization; automation, CI, and assistant-driven work never initiate an outbound contribution

If any item is not applicable to the current artifact type (e.g., color palette
for a pure Rust library), note it as N/A rather than silently skipping it.

---

## Skill Cross-References

| Task                                  | Load this skill                                    |
|---------------------------------------|----------------------------------------------------|
| Writing any Rust code                 | `microsoft-rust-guidelines`                        |
| Writing any TypeScript (§3.1.1)       | `spacecraft-typescript-guidelines`                 |
| Writing or reviewing shell scripts    | `spacecraft-cli-shell` + `spacecraft-cli-preference` |
| Generating DOCX / ODT / PDF on demand | `spacecraft-document-format`                       |
| Authoring or building a Texinfo manual | `spacecraft-texinfo-document`                              |
| Writing GTK 4 / GNOME desktop code (§13) | `spacecraft-gtk-guidelines`                     |
| Writing Qt 6 / KDE desktop code (§13) | `spacecraft-qt-guidelines`                         |
| Creating IDE / terminal themes        | `spacecraft-theme-factory`                         |
| Resolving or declaring the system theme (§11.6) | `steelbore-color-palette`                |
| Implementing or auditing accessibility (§18) | `spacecraft-accessibility-support`          |
| Authoring `AGENTS.md` / `CLAUDE.md` (§5.7) | `spacecraft-agentic-cli`                     |
| All other Spacecraft Software work    | `spacecraft-steelbore-standard`                 |

---

*— Built by Spacecraft Software —*
