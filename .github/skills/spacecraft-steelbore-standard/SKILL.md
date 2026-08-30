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
  The Steelbore Standard v1.51 (§13 design systems; §3.1.1 TypeScript; §5.7 AGENTS.md; §6.4 contribution targets; §5.6 skill packaging; §11 palettes + §11.6 system theme; §18 accessibility; §17 progress reporting; §3.2 compiler flags; concurrency; §3.3 security-by-design) so
  you never need to ask for it or have it attached to a prompt again.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# The Steelbore Standard — Compliance Reference

**Version:** 1.51 | **Date:** 2026-08-29 | **Author:** Mohamed Hammad
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

## §2 — Aerospace, Sci-Fi & AI Naming Convention

All **new** project codenames, module identifiers, and public-facing component names
**must** draw from one of the following domains:

- **Real aerospace and astronomy** — orbital mechanics terms, propulsion concepts,
  named missions/programs, stellar objects and phenomena, observatories.
- **Science-fiction franchises with space / AI / cybernetic themes** — naming is
  meant to be enjoyable as well as fitting. The following are explicitly endorsed
  canonical sources:
  - *2001: A Space Odyssey*, *The Matrix*, *Terminator* — the original canonical trio
  - *The Hitchhiker's Guide to the Galaxy* — also a rich vein for in-jokes (Vogon,
    Marvin, 42, Babel fish, Heart of Gold)
  - *Hackers* (1995)
  - Spielberg films (*Close Encounters of the Third Kind*, *E.T. the Extra-Terrestrial*,
    *A.I. Artificial Intelligence*, *Minority Report*, *Ready Player One*, etc.)
  - *Ghost in the Shell*
  - *Equilibrium*
  - *Dune*
  - *Æon Flux*
  - *Super 8*
  - *LOST* (TV series)
  - *Cloverfield* films
  - Robot / android names from any sci-fi film or franchise (e.g., HAL, Data, Bishop,
    T-800, GERTY, TARS, Marvin)

  Other franchises (e.g., *Alien*, *Blade Runner*, *Ex Machina*) remain acceptable
  if they fit the space-machine-AI register.
- **Generic sci-fi / AI vocabulary** — hyperspace, neural, cybernetic, synthetic,
  sentinel, oracle, daemon, vector, lattice (the lowercase common noun), etc.

| Category  | Examples                            | Domain                          |
|-----------|-------------------------------------|---------------------------------|
| Projects  | Apollo, Discovery, Skynet, Trinity  | Missions / Ships / AI Machines  |
| Modules   | Apogee, HAL, Cortex, Sentinel       | Subsystems / AI Cores           |
| Utilities | Boost, Throttle, Trace, Telemetry   | Operational Verbs / Telemetry   |
| Releases  | Vega, Pulsar, Quasar, Nebula        | Stellar Phenomena               |

Names must be **fitting for space-related and futuristic AI machines** — the
test is whether the name would feel at home on the hull of a spacecraft or in
the boot banner of an AI machine. Reject proposed names that don't pass this test.

### §2.1 — Legacy Metallurgical Registry (pre-v1.2)

Projects named before the v1.2 convention drew from metallurgy, materials science,
and industrial forging. These names are **preserved as-is** unless explicitly
renamed by the maintainer. The v1.2 convention applies prospectively — no forced
back-rename.

| Codename    | Status                | Description                                                    |
|-------------|-----------------------|----------------------------------------------------------------|
| `Steelbore` | Renamed to Spacecraft Software (umbrella, v1.7) | Former umbrella organization name. Renamed 2026-05-15 under the v1.7 brand consolidation. The OS line (`Steelbore OS`, `Steelbore OS Bravais`, `Steelbore OS Lattice`) retains the Steelbore name. |
| `Aetheric`  | Deprecated            | Next-generation extensible text editor (Pulsar + Quasar + Nebula IPC). Superseded by another project. |
| `Zamak`     | Active                | Rust bootloader (Limine rewrite)                               |
| `Bravais`   | Completed (renamed)   | NixOS flake configuration. Renamed from `Lattice` due to collision with Lattice OS. `Bravais` is still a metallurgical-era name (Bravais lattice) and predates the v1.2 convention. |
| `Ferrocast` | Deprecated            | Rust PowerShell rewrite (16-crate workspace). Superseded by another project.                   |
| `Craton`    | Reserved              | Rust universal package manager — codename registered; no work started yet. |
| `Ironway`   | Active                | Rust OpenTTD rewrite                                           |
| `Caliper`   | Active                | Rust raster-to-vector tracing engine (CLI+TUI)                 |
| `Mawaqit`   | Planning (**Pending rename**) | Islamic prayer times app (Flutter + Rust CLI + libmawaqit). To be renamed under the v1.2 aerospace/sci-fi/AI convention. |
| `Anvil`     | Completed             | Rust workspace; benches and CHANGELOG; legacy forging-tool name.                |
| `Flux`      | Completed             | Rust workspace; CHANGELOG and deny.toml; legacy metallurgical-flux name.        |
| `Pearlite`  | Active                | Rust workspace; audit.toml, clippy.toml, CHANGELOG; steel microstructure name.  |
| `Ferrite_OS`| Active                | Custom OS / DOS-emulation experiments; ferrite (iron-based material) name.      |
| `Forge`     | Active                | Production flavor tooling (forge-cli, forge-build, forge-activate); forging-tool name. |

Existing legacy-named projects MAY be renamed under the v1.2 convention at the
maintainer's discretion — renames are optional. When a rename happens, update
this table and §15.1's subdomain table in the same commit.

### §2.2 — Skill IDs are functional, not codenamed

Skill directory names and SKILL.md `name` fields are **functional identifiers**
(e.g., `spacecraft-steelbore-standard`, `spacecraft-document-format`) and are not subject to
the §2 codename convention. §2 reserves codenames for projects/modules/utilities/releases,
not for skill identifiers.

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
- **Verified by testing** — stability properties must be backed by tests (unit, integration,
  and fuzz/property where applicable) gating CI, not asserted by inspection alone.

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
- Benchmarking is **mandatory** before and after any optimization work; regressions must
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

## §4 — Licensing & Compliance

### §4.1 — Project License (GPL-3.0-or-later or AGPL-3.0-or-later)

- **License:** strong copyleft — each project chooses **`GPL-3.0-or-later`** or
  **`AGPL-3.0-or-later`**, whichever fits the project better:
  - Use **`AGPL-3.0-or-later`** when the software is **network-facing** — anything
    users interact with primarily over a network (servers, web services, SaaS,
    hosted APIs, multiplayer/network daemons). AGPL closes the "SaaS loophole."
  - Use **`GPL-3.0-or-later`** for everything else (local CLIs, libraries,
    desktop/TUI apps, OS components, bootloaders).
  - GPLv3 and AGPLv3 are mutually compatible by design — an umbrella mixing both is fine.
- No proprietary, closed-source, or permissive-only license for core project code.
- **Review & migrate (existing projects).** Not merely prospective: existing projects are
  to be **reviewed and relicensed** to whichever of `GPL-3.0-or-later` / `AGPL-3.0-or-later`
  best fits them (AGPL for network-facing). Migration is the maintainer's per-project
  decision on that project's own signed commit; a deliberately retained non-best-fit
  license must be documented.

#### §4.1.1 — Artifact license classes

The GPL/AGPL choice above governs **software**. License by artifact class:

| Artifact class | Default license |
|----------------|-----------------|
| **Software** — code, manifests, build tooling, and **skills** | `GPL-3.0-or-later` (or `AGPL-3.0-or-later` if network-facing, §4.1) |
| **Documents** — specifications, prose guides, books, and document deliverables (per `spacecraft-document-format`), incl. the published Standard | `CC-BY-SA-4.0` by default (`CC-BY-4.0` when intended for maximal reuse) |
| **Third-party-derived artifacts** | Preserve the **upstream** license per §4.2 (e.g., `MIT`, `GFDL-1.3-or-later`) — never relicensed to the project default |

Skills are **software-class** → `GPL-3.0-or-later` (no skill is network-facing → no AGPL).
Deliberate split for the Standard: the **published Standard document** is `CC-BY-SA-4.0`,
while this `spacecraft-steelbore-standard` **skill** encoding is `GPL-3.0-or-later`.

### §4.2 — Upstream License Compliance (preserve what you build on)

When a project incorporates, adapts, or links third-party code, it MUST satisfy that
upstream's license in full — independent of the project's own GPL/AGPL choice:

- **Preserve verbatim** all upstream copyright notices, license texts,
  `NOTICE`/`AUTHORS` files, and in-file license headers — never strip, rewrite, or
  relicense them.
- **Ship** each distinct upstream license text in the project's `LICENSES/` directory (§4.3).
- **Verify compatibility** of the upstream license with the project's GPL/AGPL license
  before inclusion.
- This is the legal/mechanical obligation; §15.3's `CREDITS.md` is the human-readable
  narrative counterpart. When both are triggered, both apply.

### §4.3 — SPDX & REUSE Compliance

Spacecraft Software follows the **[REUSE specification](https://reuse.software)** for
unambiguous, machine-readable license and copyright metadata. Every project MUST be
`reuse lint`-clean.

**Every file carries two SPDX tags** — copyright *and* license:
```
// SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
// SPDX-License-Identifier: GPL-3.0-or-later
```
(Substitute the project's actual license — `GPL-3.0-or-later` or `AGPL-3.0-or-later` —
and the correct comment syntax for the file type.)

- **Software source files** (`.rs`, `.ts`, `.js`, `.py`, `.sh`, `.ps1`, `.go`, etc.)
  and project manifests (`Cargo.toml`, `package.json`, `flake.nix`, etc.) carry both
  tags as an inline header.
- **Files that cannot carry an inline header** — documents (`.odt`, `.ods`, `.odp`,
  `.docx`, `.xlsx`, `.pptx`, `.pdf`, …), images, binary assets, generated files —
  are covered by a `.license` sidecar file
  **or** an entry in the repo-root `REUSE.toml`. No file is left uncovered (this
  replaces the former blanket "documents are exempt" rule).
- **`LICENSES/` directory:** verbatim text of every license used lives in
  `LICENSES/<SPDX-id>.txt` (e.g., `LICENSES/GPL-3.0-or-later.txt`,
  `LICENSES/AGPL-3.0-or-later.txt`, plus any upstream licenses per §4.2).
- **Root `LICENSE` holds the text; `LICENSES/` links to it.** GitHub reads a
  repository's license from a root `LICENSE` file; REUSE requires the verbatim texts
  under `LICENSES/`. Both are satisfied from a single source of truth: the root
  `LICENSE` is a **regular file** carrying the verbatim text of the project's primary
  license, and `LICENSES/<SPDX-id>.txt` for that same license is a **symbolic link**
  to it. Every project MUST ship both.

  ```sh
  cp <canonical license text> LICENSE
  ln -s ../LICENSE LICENSES/GPL-3.0-or-later.txt
  git add LICENSE LICENSES/GPL-3.0-or-later.txt
  ```

  The direction matters. `reuse` reads the working tree through the filesystem, so it
  follows the link and lints clean. GitHub's detector reads **git blobs**, and a
  symlink's blob is the target *path*, not the license text — so a symlinked root
  `LICENSE` is reported as `NOASSERTION` and the project shows no identified license.
  Any secondary license in `LICENSES/` (§4.2 upstream texts, a differently-licensed
  tooling class per §4.1.1) stays a regular file; only the primary license is linked.

  The root text MUST be a **canonical, unmodified** copy of the license as published
  (the FSF text for the GPL family, the Creative Commons text for CC-BY-SA-4.0, or the
  corresponding [choosealicense.com](https://choosealicense.com) copy). Reflowed,
  Markdown-formatted, or otherwise reformatted license texts defeat GitHub's detection
  even when the wording is intact.

  Two independently maintained copies of the same license text are **non-compliant**:
  they drift, and a stale root `LICENSE` misreports the project's license to every
  GitHub visitor.
- **License file naming.** The canonical filename is `LICENSE` — **no extension**.
  `LICENSE.md` and `LICENSE.txt` are non-compliant. GitHub's detector ranks an
  extensionless `LICENSE` above every extended form, and a canonical plain-text copy
  matches on that detector's exact matcher rather than falling through to a fuzzy one;
  a Markdown-formatted copy is in any case already excluded by the verbatimness rule
  above.

  `COPYING` MAY additionally be provided at the project root, as a **symbolic link** to
  `LICENSE`, by projects that want the GNU convention alongside the GitHub-detected
  name. It MUST NOT be a second regular copy of the text. It MUST NOT appear inside a
  distributable sub-unit: archivers dereference symbolic links by default, so a linked
  `COPYING` inside a bundle ships the whole license text a second time.

  **More than one license.** Where an artifact is offered under more than one license —
  a dual-licensed §4.2 upstream import, for example — each license text gets its own
  file, named `LICENSE.<TAG>` (`LICENSE.GPL`, `LICENSE.MIT`), after GNU's
  `COPYING.LESSER` and `COPYING.RUNTIME` convention. License texts are never
  concatenated into one file. The authoritative statement of *which* licenses apply, and
  of their exact versions, remains the SPDX expression in the file header or the
  repo-root `REUSE.toml`; the filename tag is a human-facing label, not a version claim.
- **CI gate:** `reuse lint` MUST pass before shipping.

When writing or reviewing any file, confirm REUSE coverage; when generating a new file,
add the two-tag header (or the `.license` sidecar / `REUSE.toml` entry for files that
can't carry one).

---

## §5 — Project Posture

Spacecraft Software is a personal hobby project. This posture is the **default** for every
project under the umbrella and is non-negotiable. Individual projects may
adopt a more open posture (see §5.3) but never a more closed one.

§4 defines the formal license; this section defines the **stated stance** that
sits alongside it. License says what the user *may* do; posture says what they
should *expect* from the maintainer.

### §5.1 — Default Posture (Personal / Hobby)

| Aspect         | Default                                                        |
|----------------|----------------------------------------------------------------|
| Audience       | Maintainer's own use case                                      |
| Pace           | Hobby pace; no service-level commitments                       |
| Warranty       | None — provided AS IS                                          |
| Liability      | None — see project `NOTICE.md`                                 |
| Contributions  | Welcome but not guaranteed to be accepted                      |
| Forking        | Encouraged                                                     |
| License        | GPL-3.0-or-later or AGPL-3.0-or-later, per §4.1 (formal terms govern in any conflict) |

### §5.2 — Required Posture Files (per project)

Every Spacecraft Software project repository **must** ship the following files at its
root, derived from the canonical Spacecraft Software templates:

| File              | Purpose                                                     |
|-------------------|-------------------------------------------------------------|
| `README.md`       | Includes a "Project Posture" section linking to the two below |
| `NOTICE.md`       | Full no-warranty / no-liability statement; defers to the project's GPL/AGPL license (§4.1) for binding terms |
| `CONTRIBUTING.md` | Contribution scope, PR-acceptance discretion, sign-off, security reporting, license-of-contributions |
| `LICENSES/`       | REUSE license directory (§4.3): verbatim text of every license used (`GPL-3.0-or-later` or `AGPL-3.0-or-later`, plus any upstream licenses per §4.2). |
| `LICENSE`         | Verbatim, canonical text of the project's primary license, as a regular file (§4.3). `LICENSES/<SPDX-id>.txt` for that license is a symbolic link back to it — `ln -s ../LICENSE LICENSES/GPL-3.0-or-later.txt` — so the text exists once. |

Customize only the project name, scope, and any project-specific carve-outs.

### §5.3 — General-Use Carve-Out

A project may declare itself **intended for general use**. When it does:

- The declaration MUST appear in that project's `README.md` posture section.
- The no-warranty / no-liability stance from §5.1 still applies in full —
  general-use status changes audience and intent, **not** legal terms.
- General-use projects must hold a higher release-quality bar:
  semantic versioning, maintained `CHANGELOG.md`, deprecation policy, and a
  documented support window for the current major version.

**General-use registry** (keep in sync with §15.1 subdomain table):

| Project      | Posture       |
|--------------|---------------|
| Anvil-SSH    | General-use   |
| (all others) | Personal      |

### §5.4 — Maintainer Discretion

PR acceptance, feature scope, naming, architecture, and roadmap are at the
maintainer's sole discretion. This is stated openly so contributors can
calibrate effort accordingly. Rejection reflects fit, not quality.

### §5.5 — Package Distribution Requirements

Every released package **must** ship first-party package definitions for the following package managers, committed alongside the release:

| File                    | Package manager / format            |
|-------------------------|-------------------------------------|
| `packaging/guix.scm`    | GNU Guix — Scheme package definition |
| `packaging/default.nix` | Nix — Nix flake / derivation        |
| `packaging/PKGBUILD`    | Arch Linux — `makepkg`-compatible   |

**Rules:**

- All three files MUST be present and buildable before a release tag is pushed.
- Each file must reference the exact release version and source archive SHA-256 checksum so that the package can be built reproducibly from the tagged release. Use the format native to each package manager:
  - **Guix (`guix.scm`):** `(sha256 (base32 "<nix-base32-hash>"))` inside the `origin` stanza.
  - **Nix (`default.nix`):** `sha256 = "<sri-or-hex-hash>";` inside the `fetchurl` or `fetchFromGitHub` call.
  - **Arch (`PKGBUILD`):** `sha256sums=('<hex-hash>')` array variable alongside `source=()`.
- The `packaging/` directory is tracked in the project's version-control repository alongside the source code.
- These files are software-class artifacts and inherit the project's GPL/AGPL license (§4.1); each file must carry the standard SPDX two-tag header (§4.3).
- If a package manager's ecosystem imposes a stricter naming scheme or directory layout, comply with that scheme while still meeting the above requirements.

### §5.6 — Skill Packaging Requirements

Skills are software-class artifacts (§4.1.1) distributed as `SKILL.md` bundles.
The loading agent imposes hard limits that a bundle only discovers at install
time, when the upload is rejected and the packing work is already done. Those
limits are therefore enforced **before packing**, not after a failure.

**Mandatory rules — violation blocks shipping:**

| Rule | Detail |
|------|--------|
| Description cap | A skill's frontmatter `description` MUST NOT exceed **1000 rendered characters**. The consuming loader's absolute limit is **1024**; 1000 is the deliberate 24-character margin for encoding and trailing-newline edge cases. |
| Rendered, not raw | "Rendered" means the string the loader sees. A YAML folded scalar (`description: >`) joins its wrapped lines with single spaces and retains a trailing newline, so the raw line lengths are not the measurement. Block (`>` / `\|`) and single-line plain or quoted forms alike are measured after folding. |
| Machine-enforced | The cap MUST be checked by an automated gate that runs both in the skill repository's CI on every pull request and push to the default branch, and in whatever command produces the distributable bundle. A developer-installed git hook is a convenience, never the gate — hooks are opt-in per clone and cannot be relied on. |
| Over-limit skills do not ship | A skill whose description exceeds the cap MUST NOT be packed, committed, or published. Trim the description; do not raise the cap. |

**License carriage.** A bundle is a distribution in its own right. Consumers install
the `.zip` or `.skill` without ever seeing the source repository, so the repo-root
`LICENSE` never reaches them. A copyleft license obliges the distributor to give every
recipient a copy of the license along with the work; the bundle is where that
obligation lands.

| Rule | Detail |
|------|--------|
| `LICENSE` in every skill | Each skill directory MUST contain a `LICENSE` file named per §4.3, and every bundle built from that directory MUST include it. A bundle carrying no license text does not satisfy the distribution terms of any copyleft license the skill is under. |
| Byte-identical to the root | Where the skill and the repository name the same license, the skill's `LICENSE` MUST be byte-identical to the repo-root `LICENSE`, and an automated gate MUST verify it. §4.3 forbids two independently maintained copies of a license text; enforced equality is what keeps these one maintained text rather than two. |
| Regular file, never a link | The skill's `LICENSE` MUST be a regular file. A parent-relative symbolic link (`../LICENSE`) dangles the moment the directory is packaged on its own — which is precisely what bundling and per-skill Nix packaging do — and a within-directory link is dereferenced by the archiver, duplicating the payload instead of saving it. |
| Multi-licensed skills | A skill offered under more than one license carries one `LICENSE.<TAG>` file per license (§4.3) in place of a single `LICENSE`, and every one of them ships in the bundle. |

### §5.7 — Agent Context Files

Coding agents load a project's root context file into their window at the start
of every session. Different harnesses read different filenames — `AGENTS.md` is
the cross-vendor convention (Codex CLI, Cursor, Aider, OpenCode, Goose, Gemini
CLI), while Claude Code reads `CLAUDE.md`. Maintaining both as parallel prose
guarantees drift: the two copies are edited in different sessions, diverge, and
the agent that reads the stale one is misinformed. This section fixes a single
source of truth.

**`AGENTS.md` is the authority.** Every project **must** ship an `AGENTS.md` at
its root, in addition to the §5.2 posture files. It is harness-neutral: it
carries the project's build, test, and lint commands, architectural invariants,
forbidden patterns, repository layout, and any fact an agent cannot infer from
the code itself.

**`CLAUDE.md` is a thin overlay, and is also required.** Claude Code reads
`CLAUDE.md` and does *not* read `AGENTS.md`, so a project shipping only an
`AGENTS.md` gives a Claude session no project context at all. The file **must**
consist of an `@AGENTS.md` import followed only by content that is meaningless
to a non-Claude harness — Skill-tool invocations, `.claude/` paths, Claude Code
slash commands, and Claude-client MCP configuration. It **must not** restate,
summarize, or mirror `AGENTS.md`. Where there is nothing Claude-only to say, the
import and its note are the whole file:

```markdown
# CLAUDE.md

@AGENTS.md

> Record project knowledge in `AGENTS.md`, not here. This file holds
> only Claude-Code-only context.
```

**Mandatory rules:**

| Rule | Detail |
|------|--------|
| Write to `AGENTS.md` | New project knowledge — a build command, an invariant, a gotcha — MUST be written to `AGENTS.md`. An agent or maintainer adds to `CLAUDE.md` only when the fact is meaningless to a harness that is not Claude Code. "Update the context file" always means `AGENTS.md`. |
| No duplication | A rule stated in `AGENTS.md` MUST NOT be restated in `CLAUDE.md`. Instructions of the form "keep these two files in sync" are evidence the split is wrong and MUST be removed rather than honored. |
| Both tracked | Both files are version-controlled artifacts, not agent-local scratch, and both are required. A `.gitignore` entry for either one breaks the `@AGENTS.md` import on a fresh clone and hides project knowledge from every contributor who did not author it. |
| No secrets | Because they are tracked and published, context files are subject to the same hygiene as any other repository file: no credentials, tokens, keys, private hostnames or network topology, or personal filesystem paths. A context file that was previously ignored MUST be reviewed for sensitive content **before** it is un-ignored. |
| Generated blocks | Tooling that renders managed regions into context files (rule synchronizers, task systems) MUST target `AGENTS.md` only. Writing the same block into both files reintroduces the duplication the import exists to remove. |

A relative import resolves against the file containing it, never against the
working directory, so each project's `CLAUDE.md` reaches its own `AGENTS.md`.
Claude Code walks up the directory tree and concatenates every `CLAUDE.md` it
finds, so a project nested under another inherits the ancestor's context in
addition to its own — which is why an ancestor file must not restate what a
child already says.

Other harness-specific files (`GEMINI.md`, `.cursorrules`, and similar) follow
the `CLAUDE.md` pattern: import or reference `AGENTS.md`, then add only what is
specific to that harness.

---

## §6 — Platform & Systems Requirements

### §6.1 — POSIX Compliance
All CLI tools, daemons, and system utilities must be **POSIX-compliant**.
Platform-specific extensions go behind feature flags and must not be required
for core functionality.

### §6.2 — Post-Quantum Cryptography
Crypto subsystems must have migration paths to post-quantum algorithms.
Current implementations should use hybrid schemes where library support exists.

### §6.3 — Signed & Verified Commits (Non-Negotiable)

Every commit pushed to a Spacecraft Software-controlled Git remote **must** be
cryptographically signed and show "Verified" on the hosting platform's
commit/PR view (GitHub today; Gitway or any future Spacecraft Software host inherits
the same rule).

**Mandatory rules — violation blocks shipping:**

| Rule | Detail |
|------|--------|
| All commits signed | `commit.gpgsign=true` configured globally. SSH signing (`gpg.format=ssh`) is the current default; GPG is acceptable. The signing key MUST be registered as a **Signing** key on the hosting platform — Authentication-only keys do not validate signatures. |
| Authorized signing identity | All commits from v1.12 onwards must be signed with the `Mohamed.Hammad@SpacecraftSoftware.org` key. The committer email and the signing key identity must both resolve to `Mohamed.Hammad@SpacecraftSoftware.org`. Commits predating v1.12 are exempt from this requirement. |
| Hosting-platform "Verified" required | Every commit on a Spacecraft Software remote must show "Verified" on the platform's commit/PR view. Unsigned or "Unverified" commits MUST be remediated (re-signed via rebase or amend by the original author) before merge to a default branch. |
| Programmatic commits signed too | Bots, CI pipelines, scripted commits, and assistant-driven commits inherit the same rule — no `--no-gpg-sign`, no signing-disabled subshells. The signing pipeline runs unattended. |
| Rewrites preserve signatures | Rebase, amend, cherry-pick, and squash MUST re-sign each resulting commit. Don't push history that lost signatures through rewriting. |
| Local verification is best-effort | `git log --show-signature` may report "No signature" on a given host when `~/.ssh/allowed_signers` is not populated — this is a local-verifier gap, not a signing failure. The hosting platform's "Verified" badge is authoritative. |

**Algorithm note:** Ed25519 SSH signing is the current default. §6.2 calls
for PQC readiness across the cryptographic surface; commit-signing
algorithm migration is gated on hosting-platform support for post-quantum
key formats. When GitHub (or Spacecraft Software's own Gitway) accepts PQC signing
keys, Spacecraft Software commits migrate accordingly.

### §6.4 — Authorized Contribution Targets (Non-Negotiable)

Spacecraft Software work is published only to namespaces Spacecraft Software
controls. Two are authorized today:
[github.com/Spacecraft-Software](https://github.com/Spacecraft-Software) (the
umbrella organization) and
[github.com/UnbreakableMJ](https://github.com/UnbreakableMJ) (the maintainer's
personal namespace). A future Spacecraft Software-controlled host — Gitway, or
any successor — inherits the same standing. Every other destination is
**outbound** and gated.

§6.3 says how a commit must be signed on a Spacecraft Software remote; this
section says which remotes those are, and what it takes to send anything
anywhere else.

**Mandatory rules — violation blocks shipping:**

| Rule | Detail |
|------|--------|
| Default-deny outbound | No `git push`, pull or merge request, patch series, or mailing-list submission to any Git remote outside the authorized namespaces. Silence is a denial, not permission. |
| Automation never initiates | Bots, CI pipelines, scripted workflows, and assistant-driven sessions MUST NEVER open an outbound contribution. Authorization for one contribution does not carry to the next task, session, or repository. |
| Maintainer-only exception | Only Mohamed Hammad, acting explicitly and per contribution, may authorize an outbound submission (§5.4 maintainer discretion). The authorization names the destination and the change; it does not generalize. |
| Registries and trackers included | Publishing to a package registry under a namespace Spacecraft Software does not control (`crates.io`, npm, PyPI, AUR, Nixpkgs, Guix, Flathub, and the like), and filing issues, bug reports, or patches on an external tracker or mailing list, are outbound contributions under this same rule. |
| Forks are inbound-only | A fork under an authorized namespace may be created and pushed to freely — that is our namespace. Turning a fork branch into an upstream pull request is the gated act, not the fork itself. |
| Prefer carrying the patch | When an upstream change is needed, carry the patch in-tree (§4.2 preserves upstream copyright, license texts, and notices) rather than upstreaming it, unless the maintainer authorizes upstreaming. |
| GNU posture does not exempt | An artifact under the free-software/GNU posture (§1) still requires explicit maintainer authorization before anything is sent to GNU, the FSF, or Savannah. That posture yields this standard's identity clauses (§2, §11–§12, §15); it does not yield this one. |
| Withdraw mistakes promptly | An outbound submission made without authorization MUST be closed or withdrawn as soon as it is discovered, and the incident recorded. |

### §6.5 — Text File Format (LF, UTF-8, final newline)

Every text file in a Spacecraft Software source tree is a **POSIX text file**:
UTF-8 encoded, LF-terminated, and ending with a newline. §6.1 requires POSIX
compliance of the tools; this section requires it of the files those tools are
written in.

**Mandatory rules — violation blocks shipping:**

| Rule | Detail |
|------|--------|
| LF line endings | Lines terminate with **LF** (U+000A). CRLF and a lone CR are prohibited — in source, configuration, scripts, documentation, and CI definitions alike. |
| Final newline | Every text file ends with a newline. A file whose last line is unterminated is not a POSIX text file, and it makes every diff that touches the last line carry a spurious `\ No newline at end of file`. |
| UTF-8, no BOM | Text files are encoded UTF-8. A byte-order mark is prohibited: it breaks shebang lines, `#`-comment parsing, and every config reader that expects the first byte of the file to be content. |
| `.gitattributes` required | Every repository MUST ship `.gitattributes` at its root containing `* text=auto eol=lf`. This is the only mechanism that holds regardless of a contributor's `core.autocrlf` setting — which defaults to `true` on Windows and rewrites the working tree on checkout. Relying on per-clone Git configuration is not compliance. |
| `.editorconfig` required | Every repository MUST ship `.editorconfig` at its root with `root = true` and, under `[*]`, at minimum `charset = utf-8`, `end_of_line = lf`, and `insert_final_newline = true`. It carries the rule to editors that never consult Git. |
| CI gate | CI MUST fail when a tracked text file contains a CR byte. Both config files are advisory to the tools that read them; the gate is what makes the rule binding. `git grep -Il` needs no exclusion list — it skips binaries and honors `.gitattributes`, so a pinned exception is invisible to it. |
| Exceptions | Vendored upstream files keep their upstream line endings (§4.2 — preserve what you build on). Windows-native scripts invoked by `cmd.exe` (`.bat`, `.cmd`) MAY use CRLF where the interpreter requires it. A format whose specification mandates CRLF keeps it. Every such exception is pinned explicitly in `.gitattributes` (`*.bat text eol=crlf`) rather than left to chance. Binary files are unaffected — `text=auto` never touches them. |

**Scope note.** This section governs *files on disk*, not *bytes on a socket*.
The CRLF that HTTP, SMTP, and the other line-oriented wire protocols require in
their framing is unaffected — a protocol implementation emits what its
specification demands.

This is codification of existing practice rather than a new constraint: `anvil`
and `bravais` already carry `* text=auto eol=lf`, and `loran` and `caliper`
already carry the three `.editorconfig` keys. What §6.5 adds is that the
convention is now uniform and enforced rather than rediscovered one repository
at a time.

---

## §7 — Shell Environment

Spacecraft Software tooling, documentation, and CI pipelines target **four first-class shell environments**: **Nushell**, **Ion**, **Brush**, and **Bash**. All four are equally supported; none is deprecated or downgraded.

### §7.1 — Script Portability Policy

| Rule | Detail |
|------|--------|
| Default: POSIX-compatible | Shell scripts in source trees, CI pipelines, `Makefile` targets, and documentation examples **must** be written to the POSIX sh subset unless a shell-native feature is required. POSIX scripts run correctly in Bash and Brush without modification. |
| Nushell / Ion native variants when needed | When a task cannot be expressed cleanly in POSIX sh (structured data pipelines, typed parameters, Nushell modules), provide a Nushell (`.nu`) and/or Ion-native variant alongside the POSIX version. Do not force POSIX-only idioms that degrade the Nushell or Ion experience. |
| No Bashisms in shared scripts | Bash-only extensions (`[[ ]]`, `(( ))`, process substitution `<(...)`, `${var^^}`, indexed arrays) are prohibited in files intended for all four shells. Bash-specific scripts are permitted only when explicitly scoped (e.g., `#!/usr/bin/env bash` shebang, clearly labeled). |
| Graceful shell detection | Tools that need runtime shell detection must inform the user or degrade gracefully rather than silently failing in non-Bash environments. |

---

## §8 — Documentation (Texinfo)

Spacecraft Software user-facing projects should ship a **Texinfo manual** as the canonical technical reference. Texinfo is the preferred format for reference documentation that accompanies distributed software, following GNU project conventions.

### §8.1 — When a Texinfo Manual Is Required

| Project type | Requirement |
|---|---|
| CLI / TUI / GUI application with substantive user-facing functionality | **MUST** ship a Texinfo manual covering invocation, options, concepts, and examples |
| Library with a public API | **SHOULD** ship a Texinfo reference manual covering all public interfaces |
| Simple script / internal tooling | **MAY** skip; a well-structured `README.md` suffices |

### §8.2 — Source Format and File Layout

- Source files use the `.texi` extension (Texinfo 7.x+).
- Manuals live at `doc/<project>.texi` in the project root.
- The project's top-level `Makefile` must expose three targets: `make info`, `make html`, `make pdf`.

### §8.3 — Required Structural Elements

Every Texinfo manual must include the following elements:

| Element | Purpose |
|---|---|
| `@dircategory` / `@direntry` | Registers the manual in the Info directory |
| `@copying` block | License statement and copyright notice |
| `@titlepage` | Title, version, author, and copyright |
| `@node Top` + `@top` | Required top-level node for Info readers |
| `@menu` per chapter | Navigation structure |

### §8.4 — Output Formats

Build and ship all three output formats:

| Format | Tool | Purpose |
|---|---|---|
| `.info` | `makeinfo` / `texi2any` | Info readers (Emacs, standalone `info`) |
| `.html` | `makeinfo --html` | Project documentation website |
| `.pdf` | `texi2pdf` | Printable reference |

Install `.info` files using `install-info` at package install time so they appear in the system Info directory.

### §8.5 — Licensing

Texinfo manuals are **document-class** artifacts (§4.1.1) and default to **CC-BY-SA-4.0**. **GFDL-1.3-or-later** is a permitted alternative when the manual is distributed alongside GPL-licensed software and compatibility with GNU documentation collections is desired. Include the chosen license in `LICENSES/` per §4.3.

### §8.6 — Packaging Integration

Package manifests must install the `.info` file and register it with `install-info`:

| Package manager | Requirements |
|---|---|
| **Guix** (`packaging/guix.scm`) | Add `texinfo` as a native input; run `install-info` in the install phase |
| **Nix** (`packaging/default.nix`) | Add `texinfo` to `nativeBuildInputs`; standard Autoconf/Make `installPhase` handles `install-info` automatically |
| **PKGBUILD** (`packaging/PKGBUILD`) | Add `texinfo` to `makedepends`; `install -Dm644` for `.info` files; call `install-info` in `post_install` |

---

## §9 — Privacy-Friendly Application (PFA) Policy

Every Spacecraft Software application must satisfy **all three** PFA requirements:

| Requirement        | Rule                                                                     |
|--------------------|--------------------------------------------------------------------------|
| No Tracking/No Ads | Zero advertising, tracking, analytics SDKs, or telemetry beacons        |
| Minimal Permissions| Only essential permissions; requested lazily at point of use, never eagerly |
| Local Storage      | User data stored locally by default; sync is strictly opt-in, E2E encrypted |

When reviewing or designing any feature that touches data handling, permissions,
or networking, verify all three PFA requirements are met.

---

## §10 — Key Bindings

All interactive applications must support **both**:

**Scope.** This chapter does **not** apply to projects registered as **games**
under §18.5 — games are exempt from §10 in full, including the CUA and Vim rows
below. Modal editing and text-editor chords are a poor fit for real-time play; a
game's control scheme is entirely at the maintainer's discretion. §18.5 restates
the useful parts as recommendations a game may decline.

| Scheme    | Requirement                                                              |
|-----------|--------------------------------------------------------------------------|
| **CUA**   | Standard bindings (Ctrl+C/X/V/Z/S) must work in all text input contexts  |
| **Vim**   | Modal editing layer (Normal / Insert / Visual mode) as opt-in feature. Minimum: hjkl navigation where full Vim layer is impractical |

**Remappability (mandatory).** Every binding must be user-remappable through the
project's configuration layer — a fixed, non-configurable keymap is non-compliant.

**Reserved assistive-technology chords.** These are claimed by screen readers and
**must not** be captured by a Spacecraft Software application:

| Chord | Claimed by |
|-------|------------|
| `Insert` / `CapsLock` | NVDA (Windows) — the NVDA modifier key |
| `Insert` / `KP_Insert` | Orca (GNOME/Linux) — the screen reader's own modifier |
| `Ctrl`+`Option` | VoiceOver (macOS) — the "VO" modifier |

Every action reachable by pointer must also be reachable by keyboard; focus order
must be linear and the focused element visibly indicated. See §18.

---

## §11 — Spacecraft Software Color Palettes (WCAG-Compliant)

Spacecraft Software ships a **palette family**. Every palette declares exactly
one **canvas**, a full set of §11.1 role tokens, and a verified contrast
matrix.

**`Steelbore Modern` is the default and canonical palette.** Every artifact
uses Modern unless its project explicitly declares an alternate under §11.4.

| Theme slug | Palette | Canvas | Polarity | Status |
|---|---|---|---|---|
| `steelbore` | Steelbore Modern | `#000027` | Dark | **Default** — all artifacts unless declared |
| `steelbore-classic` | Steelbore Classic | `#000027` | Dark | Legacy contract (§11.2) |
| `steelbore-blue` | Steelbore Blue | `#0A1024` | Dark | Alternate (§11.3) |
| `steelbore-blackpinkpanther` | Steelbore BlackPinkPanther | `#141418` | Dark | Alternate (§11.3) |
| `steelbore-matrixgreen` | Steelbore MatrixGreen | `#0C1A2B` | Dark | Alternate (§11.3) |
| `steelbore-navywhite` | Steelbore NavyWhite | `#E7E5E0` | **Light** | Alternate (§11.3) — the family's only light canvas |
| `tokyonight` | Tokyo Night | `#1A1B26` | Dark | Alternate (§11.3) |

**Polarity** is normative content: §11.6.2 pairs a dark palette with a light one
so an application can follow the platform's color-scheme preference.

### §11.0 — Steelbore Modern (canonical palette)

The permitted colors for Steelbore Modern (the **Steelbore 2** generation):

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

**`#000027` (Void Navy) is the mandatory canvas for every surface under
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

| Theme token   | Maps to palette token | Hex       |
|---------------|-----------------------|-----------|
| `background`  | Void Navy             | `#000027` |
| `surface`     | Quantum Blue          | `#0E2A47` |
| `surface-alt` | Deep Matrix           | `#0B1A12` |
| `foreground`  | Platinum Mist         | `#D9DEE5` |
| `accent`      | Plasma Orange         | `#FF5E00` |
| `structure`   | Pulse Violet          | `#8A6CFF` |
| `success`     | Acid Lime             | `#B4FF00` |
| `error`       | Mars Red              | `#FF3B3B` |
| `warning`     | Plasma Magenta        | `#E445FF` |
| `focus`       | Acid Lime             | `#B4FF00` |
| `border`      | Pulse Violet          | `#8A6CFF` |

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

| Theme token  | Base token     | Variant hex | Contrast vs Void Navy |
|--------------|----------------|-------------|-----------------------|
| `background` | Void Navy      | `#000027`   | (canvas)              |
| `foreground` | Platinum Mist  | `#D9DEE5`   | 15.09:1               |
| `accent`     | Plasma Orange  | **`#FF8A3D`** | 8.70:1              |
| `structure`  | Pulse Violet   | **`#B3A1FF`** | 9.19:1              |
| `success`    | Acid Lime      | `#B4FF00`   | 16.75:1               |
| `error`      | Mars Red       | **`#FF7A7A`** | 8.08:1              |
| `warning`    | Plasma Magenta | **`#EE7BFF`** | 8.66:1              |

Only `accent`, `structure`, `error`, and `warning` shift; the other tokens are
§11 values verbatim, with alias tokens following their bases (`focus` stays
Acid Lime `#B4FF00`; `border` follows `structure` to `#B3A1FF`, keeping every
foreground-class role token ≥7:1). In the variant, all four lifted tokens also clear 4.5:1
on both surfaces (weakest pairing: `error` `#FF7A7A` on Quantum Blue, 5.77:1),
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

| Role | Token | Hex | vs Void Navy |
|------|-------|-----|--------------|
| `background` | Void Navy | `#000027` | (canvas) |
| `foreground` | Molten Amber | `#D98E32` | 7.64:1 |
| `accent` | Steel Blue | `#4B7EB0` | 4.77:1 |
| `success` | Radium Green | `#50FA7B` | 14.87:1 |
| `error` | Red Oxide | `#FF5C5C` | 6.74:1 |
| `info` | Liquid Coolant | `#8BE9FD` | 14.74:1 |

`steelbore-classic-high-contrast` lifts `accent` → `#7FAEDC` (8.73:1) and
`error` → `#FF8080` (8.41:1); the other four are already ≥7:1. Classic's
token-on-token failures are severe — Molten Amber on Red Oxide 1.13:1,
Radium Green on Liquid Coolant 1.01:1.

### §11.3 — Alternate Palettes

Five alternates, each anchored on two colors that never change, each verified
against its own canvas and surfaces. Full role tables and three-background
matrices live in the `steelbore-color-palette` skill's
`assets/steelbore.toml`; every token clears 4.5:1 on all three of its
backgrounds unless marked †.

| Palette | Slug | Canvas | Accent anchor | Note |
|---------|------|--------|---------------|------|
| Steelbore Blue | `steelbore-blue` | Orbit Navy `#0A1024` | Electric Blue `#0066FF` | Electric Blue is **†restricted** (3.91:1) — large text, icons, non-text UI only |
| Steelbore BlackPinkPanther | `steelbore-blackpinkpanther` | Core Black `#141418` | Plasma Magenta `#E445FF` | No restricted pairings |
| Steelbore MatrixGreen | `steelbore-matrixgreen` | Circuit Navy `#0C1A2B` | Solar Lime `#B6FF3B` | `surface-alt` (Ambient Black `#05070A`) is darker than the canvas — permitted |
| Steelbore NavyWhite | `steelbore-navywhite` | Pearl Silver `#E7E5E0` | Lunar Navy `#111827` (foreground) | **Light canvas**; high contrast *darkens*. Lighter source tints are non-text fills only |
| Tokyo Night | `tokyonight` | Night `#1A1B26` | Tokyo Blue `#7AA2F7` | Verbatim from the upstream editor theme; no restricted pairings. `surface` is the Storm background `#24283B`, `surface-alt` the Night `bg_dark` `#16161E` (darker than the canvas — permitted) |

#### §11.3.5 — Tokyo Night

Registered verbatim from [enkia/tokyo-night-vscode-theme](https://github.com/enkia/tokyo-night-vscode-theme).
It needed **no Spacecraft-derived substitutes** — every role token clears 4.5:1
on all three backgrounds — so it is a conforming alternate, not a §11.5 fidelity
palette: `foreground` `#C0CAF5` 10.59:1, `accent` `#7AA2F7` 6.79:1, `structure`
`#BB9AF7` 7.39:1, `success` `#9ECE6A` 9.35:1, `error` `#F7768E` 6.46:1,
`warning` `#E0AF68` 8.55:1, `focus` `#7DCFFF` 9.96:1 (vs canvas).

`tokyonight-high-contrast` lifts the two tokens below 7:1 on the canvas —
`accent` → `#97B6F9` (8.44:1) and `error` → `#F998AA` (8.22:1); the other six
carry over verbatim. The upstream comment tone `#565F89` (2.76:1) clears neither
the 4.5:1 text floor nor the 3:1 non-text floor and is **not bindable to a role
token**; boundaries are drawn in `structure` per §11.0.1.

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
| `steelbore-blackpinkpanther` | `blackpinkpanther-color-palette` |
| `steelbore-matrixgreen` | `matrixgreen-color-palette` |
| `steelbore-navywhite` | `navywhite-color-palette` |
| `tokyonight` | `tokyonight-color-palette` |
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
| Solarized Dark | `solarized-dark` | `base03` `#002B36` | `base0` 4.75:1 | 12 below 4.5:1; `structure`/`border` 2.97:1 and `error` 2.81:1 below 3:1 on `base02` |
| Solarized Light | `solarized-light` | `base3` `#FDF6E3` | `base00` **4.13:1 — under the AA floor** | `success` 2.97:1, `warning` 2.98:1, `focus` 2.93:1 below 3:1 — status cannot be signalled by color at all |

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
| **MUST register** | The six conforming palettes — `steelbore`, `steelbore-blue`, `steelbore-blackpinkpanther`, `steelbore-matrixgreen`, `steelbore-navywhite`, `tokyonight` — each with its `-high-contrast` sibling, plus `steelbore-mono`. **Thirteen themes** | All bind the same eleven role tokens, so a layer that reads `steelbore.toml` registers them in a loop, and a declaration can always be answered |
| **MAY register** | `steelbore-classic`, `steelbore-classic-high-contrast` | Classic keeps the legacy six-role contract (§11.2), defines no surface class, and carries an `info` token that is not one of §11.1's eleven roles — registrable only by an app that implements that contract too |
| **MUST NOT register** | A §11.5 fidelity palette, except as an explicitly user-selectable extra | §11.5 bars adoption; this section is not a route around it |

Three of the thirteen were already required (§11.4, §11.1.1), so this adds ten —
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

---

## §12 — Typography (FOSS-Licensed Fonts Only)

Acceptable font licenses: **OFL, Apache 2.0, Ubuntu Font License, CC0-1.0**

| Context        | Font              | License |
|----------------|-------------------|---------|
| Headings       | Share Tech Mono   | OFL     |
| Body / Code    | Inconsolata       | OFL     |
| Fallback       | monospace (system)| N/A     |

Never use proprietary fonts. When suggesting or using fonts in any Spacecraft Software artifact,
verify they are available on Google Fonts or another FOSS-licensed repository.

---

## §13 — UI/UX Design System

- **Every graphical application declares exactly one component system**, named in its
  `README.md` beside the §5.2 posture section, and themes it with the §11 palette.
  Which system is determined by the platform, not by preference:

  | Application class | Required component system |
  |-------------------|---------------------------|
  | **Flutter, web, mobile, and cross-platform GUI** | **Material Design** |
  | **GTK 4 desktop** | **GNOME HIG** via libadwaita → `spacecraft-gtk-guidelines` |
  | **Qt 6 desktop** | **KDE HIG** via Qt Quick Controls / Fusion → `spacecraft-qt-guidelines` |
  | **Custom-drawn or immediate-mode UI** | Material Design, unless a platform HIG is declared |

  **Rationale.** Material Design is a coherent, accessible system and remains the default
  wherever the platform does not supply one. A native desktop toolkit does supply one:
  GTK ships Adwaita and the GNOME HIG, Qt ships Fusion and the KDE HIG, and both are
  wired into the platform's window management, settings, and accessibility stack.
  Imposing Material on top of either produces an application that matches neither its
  own toolkit nor Material, and that fights the very platform integration §18 depends on.
  The mandate is therefore that a system is **declared and followed consistently** — not
  that one particular system is used everywhere.
- **§11 binding is unconditional.** Whichever system is declared, all palette references
  go through the named `steelbore` theme (§11.1). A component system chooses the widget
  vocabulary; it never supplies the colors.
- **WCAG 2.2 Level AA** contrast is the minimum for all color pairings.
  Any new color additions must be WCAG-verified before adoption, and the
  verification must state *which pairing* was measured (§11).
- **Accessibility** is governed by **§18**, which applies to CLI, TUI, and GUI
  alike. §13 is the graphical design system; §18 is the accessibility contract.
  Where the two overlap, §18 governs.

---

## §14 — Date, Time & Units

### §14.1 — Date & Time Format Rules

| Concern      | Rule                                                             | Example                      |
|--------------|------------------------------------------------------------------|------------------------------|
| Date format  | ISO 8601 only: `YYYY-MM-DD`                                      | `2026-03-08`                 |
| Time format  | 24-hour only: `HH:MM:SS` — AM/PM is **never** permitted          | `14:30:00`                   |
| Timestamp    | Combined ISO 8601 UTC: `YYYY-MM-DDTHH:MM:SSZ`                    | `2026-03-08T14:30:00Z`       |
| Timezone     | **UTC Z is the default and preferred primary** for general-purpose, cross-system, and machine-readable timestamps. A project whose core domain is inherently local-time-bound (e.g., solar/prayer-time calculations) may declare local time as its primary record instead — a documented exception, not a free choice. See §14.2 and §14.2.1 | `Z` not `+00:00`             |
| Duration     | ISO 8601 duration format only                                    | `PT1H30M` not "1h 30m"       |
| Units        | Metric (SI) primary; imperial in parentheses only if locale requires | `100 km (62 mi)`         |

Apply these conventions to all generated code, documentation, comments, and any
user-facing strings. Never output AM/PM time, non-ISO dates, or imperial-primary units.

### §14.2 — UTC Z Timezone Policy

**UTC Z is the default and preferred timezone for stored, transmitted, logged,
and committed timestamps across Spacecraft Software projects.** It is the
convention every project should reach for first — it keeps cross-project tooling,
sorting, and interchange simple and unambiguous. Under this default, the `Z`
suffix is required on primary timestamps, and local time expressed as a UTC
offset (e.g., `2026-05-24T13:34:55+03:00`) may optionally accompany a UTC Z value
as a secondary, human-convenience field — but UTC Z remains the authoritative
record.

This is a strong default, not a universal mandate forced onto every domain
regardless of fit — §14.2.1 documents the exception that lets a project whose
domain is genuinely local-time-bound use local time as its primary record instead.

**Rules for projects under the UTC Z default — apply unless a project has filed
the §14.2.1 exception:**

| Rule | Detail |
|------|--------|
| `Z` suffix required | Every **primary** stored/transmitted timestamp MUST end with `Z`. `2026-03-08T14:30:00Z` ✓. A companion local-time field with UTC offset is permitted alongside it. |
| No offset notation as replacement | Offset notation (`+03:00`, `-05:00`, etc.) is **forbidden as a replacement** for UTC Z. It is permitted only as an optional companion field alongside a `Z`-suffixed primary. |
| No bare local time in data | Local-time timestamps **without** timezone info are **forbidden** in files, databases, logs, API responses, and commits. |
| Log entries use UTC + `Z` | Every log line timestamp must be `YYYY-MM-DDTHH:MM:SS.sssZ` (millisecond precision encouraged). |
| Commit timestamps use UTC | `GIT_COMMITTER_DATE` and `GIT_AUTHOR_DATE` must be UTC when set programmatically. |
| File metadata written by Spacecraft Software tools | mtime/ctime written by Spacecraft Software tools must be UTC-sourced. |

### §14.2.1 — Domain Exception: Inherently Local-Time-Bound Projects

A project whose core domain is fundamentally defined by **local civil or solar
time** — not by a moment in absolute (UTC) time — may declare local time as the
**primary** representation for that domain's data. Examples: prayer-time
calculations (`Mawaqit`), sunrise/sunset tables, local event or business-hours
scheduling. For data like this, the meaningful value *is* "06:14 local, at this
place" — collapsing it to a UTC instant first and treating that as authoritative
would misrepresent what the data actually is.

**Conditions for the exception:**

1. **Document it.** The project's README or spec must state explicitly which
   data uses local time as primary, and the *domain* reason why — not developer
   or user convenience.
2. **Keep the default everywhere else.** General-purpose machinery within the
   same project — logs, commit timestamps, internal cross-system APIs,
   telemetry — still follows the §14.2 UTC Z default. The exception covers the
   domain data itself, not the whole project.
3. **Preserve UTC derivability.** Store or compute the IANA timezone (e.g.,
   `Africa/Cairo`) alongside the local value, so a UTC instant remains derivable
   for interchange, comparison, and storage portability.
4. **This is an exception, not an escape hatch.** "Local time is more
   convenient" or "our users are mostly in one timezone" do not qualify — the
   domain itself must be inherently local-time-bound.

### §14.3 — Local Time as Optional Companion

**For projects under the UTC Z default** (§14.2), local time expressed as a UTC
offset is permitted as an **optional companion** to the UTC Z primary value — in
human-facing display, in API responses (as an additional field, never replacing
the UTC Z field), and in stored records where timezone context aids human
readers. The UTC Z value is always present and always authoritative; the
local-time companion is supplemental only. (A project operating under the
§14.2.1 domain exception inverts these roles for its domain data — local time is
primary there, with UTC kept derivable rather than displayed as authoritative.)

- The `--absolute-time` flag (defined in `spacecraft-cli-standard` §3) disables
  relative-time rendering but always renders as UTC, not local time.
- If a future CLI wants to show local time in human mode, it MUST:
  1. Accept a `--tz <IANA-zone>` flag (e.g., `--tz Africa/Cairo`).
  2. Render local time only to stdout in human mode — never in `--json` output.
  3. Always include the UTC value alongside the local rendering.
  4. Never persist or transmit the local-time rendering.
- JSON/machine output (`--format json/jsonl/yaml/csv`) MUST always use UTC + `Z`.

### §14.4 — Duration Format

Durations follow ISO 8601 duration notation:

| Format   | Example   | Meaning             |
|----------|-----------|---------------------|
| `PTnHnMnS` | `PT1H30M` | 1 hour 30 minutes |
| `PnD`    | `P7D`     | 7 days              |
| `PnYnM`  | `P1Y6M`   | 1 year 6 months     |

Prose forms like "1h 30m", "90 minutes", "1.5 hours" are **forbidden** in
machine-readable output. They are acceptable in `--help` text only.

### §14.5 — Rust Implementation Guidance

When writing Rust code that handles time:

| Concern | Rule |
|---------|------|
| Crate choice | Use `jiff` (preferred) or `chrono` — never `time` 0.1.x |
| UTC type | `jiff::Timestamp` or `chrono::DateTime<chrono::Utc>` for all stored values |
| Local type | `chrono::Local` and `jiff::Zoned` (with non-UTC zone) are **forbidden** in serialized output |
| Serialization | Always serialize as `"2026-03-08T14:30:00Z"` (string, ISO 8601, `Z` suffix) |
| `serde` | Use `#[serde(with = "...")]` or a newtype that enforces UTC on deserialization |
| `SystemTime` | Acceptable for internal durations; convert to UTC ISO 8601 string before any output |
| No `NaiveDateTime` in output | `chrono::NaiveDateTime` has no timezone — forbidden in any serialized or logged value |

---

## §15 — Attribution, Maintainer & Contact

**Maintainer:** Mohamed Hammad
**Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** Copyright (C) 2026 Mohamed Hammad & Spacecraft Software | **License:** GPL-3.0-or-later
**Website:** [https://SpacecraftSoftware.org/](https://SpacecraftSoftware.org/)

### §15.1 — Project Pages

Each Spacecraft Software project has a dedicated subdomain following the pattern
`https://<ProjectName>.SpacecraftSoftware.org/`. Use the project-specific URL in all
project-level outputs; use `https://SpacecraftSoftware.org/` only for umbrella references.

| Project                    | URL                                              |
|----------------------------|--------------------------------------------------|
| Spacecraft Software (main) | https://SpacecraftSoftware.org/                  |
| The Steelbore Standard     | https://Standard.SpacecraftSoftware.org/         |
| Aetheric                   | https://Aetheric.SpacecraftSoftware.org/         |
| Gitway                     | https://Gitway.SpacecraftSoftware.org/           |
| Ferrocast                  | https://Ferrocast.SpacecraftSoftware.org/        |
| Caliper                    | https://Caliper.SpacecraftSoftware.org/          |
| Craton                     | https://Craton.SpacecraftSoftware.org/           |
| Ironway                    | https://Ironway.SpacecraftSoftware.org/          |
| Zamak                      | https://Zamak.SpacecraftSoftware.org/            |
| Bravais                    | https://Bravais.SpacecraftSoftware.org/          |
| Mawaqit                    | https://Mawaqit.SpacecraftSoftware.org/          |
| Flux                       | https://Flux.SpacecraftSoftware.org/             |
| Anvil                      | https://Anvil.SpacecraftSoftware.org/            |
| Construct                  | https://Construct.SpacecraftSoftware.org/        |
| Ferrite_OS                 | https://Ferrite.SpacecraftSoftware.org/          |
| Forge                      | https://Forge.SpacecraftSoftware.org/            |
| Ginx                       | https://Ginx.SpacecraftSoftware.org/             |
| Loran                      | https://Loran.SpacecraftSoftware.org/            |
| Pearlite                   | https://Pearlite.SpacecraftSoftware.org/         |
| MCP Servers                | https://MCP-Servers.SpacecraftSoftware.org/      |
| Lode                       | https://Lode.SpacecraftSoftware.org/             |
| Sonde                      | https://Sonde.SpacecraftSoftware.org/            |
| Vault                      | https://Vault.SpacecraftSoftware.org/            |
| Vacuum                     | https://Vacuum.SpacecraftSoftware.org/           |
| Docs                       | https://Docs.SpacecraftSoftware.org/             |
| Loran Pages                | https://Loran-Pages.SpacecraftSoftware.org/      |

When a new project is created, add its subdomain to this table immediately.

### §15.2 — Mandatory Attribution in Project Outputs

Every Spacecraft Software product **must** surface the following attribution in at least one
of: `--help` output, `--version` output, README, or About/Info screen.

**Required attribution block:**
```
Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
Copyright (C) 2026 Mohamed Hammad & Spacecraft Software  |  License: GPL-3.0-or-later
https://<ProjectName>.SpacecraftSoftware.org/
```
(The License line shows the project's own license — GPL-3.0-or-later or AGPL-3.0-or-later per §4.1.)

**Per-surface rules:**

| Surface           | Required content                                                        |
|-------------------|-------------------------------------------------------------------------|
| `--version`       | Maintainer name, project URL, copyright year                            |
| `--help`          | Project URL and maintainer name (at footer)                             |
| README            | "Maintainer" section: name, `Mohamed.Hammad@SpacecraftSoftware.org`, project URL |
| About / Info (GUI/TUI) | Maintainer name, project URL, copyright year                       |
| SPDX header       | REUSE two-tag header (§4.3): `SPDX-FileCopyrightText` + `SPDX-License-Identifier` (`GPL-3.0-or-later` or `AGPL-3.0-or-later`) |

**Specific rules:**
- The contact email is always `Mohamed.Hammad@SpacecraftSoftware.org` — never a personal
  domain, GitHub handle, or other address.
- The copyright year reflects the year of first release or current year, or a range
  (e.g., `2025-2026`) when a project spans multiple years.
- Link text for project pages must use the full URL as the display text or a clear
  label (e.g., `[Gitway](https://Gitway.SpacecraftSoftware.org/)`), never an opaque label.
- For CLI `--version` output in human mode, the footer line format is:
  ```
  Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
  https://<ProjectName>.SpacecraftSoftware.org/
  ```
- For CLI `--version` output in JSON/machine mode, include in `metadata`:
  ```json
  "maintainer": "Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>",
  "website": "https://<ProjectName>.SpacecraftSoftware.org/"
  ```
- **Email obfuscation in plain-text prose.** In plain-text prose contexts (README body,
  CONTRIBUTING.md, human-readable documentation) where the address is not a clickable
  link, `Mohamed.Hammad [at] SpacecraftSoftware.org` is permitted as a scraper-resistant
  form. `# Maintainer:` lines in PKGBUILDs and `SPDX-FileCopyrightText` headers **must**
  always use the full address — those formats are parsed by `makepkg`/`pkgcheck` and
  `reuse lint` respectively, and obfuscation breaks them.

### §15.3 — Third-Party Attribution

Spacecraft Software artifacts must give credit where credit is due. When a project
or skill **substantially builds on third-party work**, that credit appears
in a `CREDITS.md` at the artifact's root — `<project-root>/CREDITS.md` for
projects, `<skill-name>/CREDITS.md` for skills.

`CREDITS.md` is the inbound counterpart to §15.2's outbound attribution:
§15.2 tells consumers who maintains Spacecraft Software; §15.3 tells consumers whose
work Spacecraft Software stands on.

**Triggers** (any one obligates a `CREDITS.md`):

- Content adapted, derived, or copied verbatim from an external source
  under any license (permissive or copyleft).
- A library, framework, or specification whose ideas or implementation
  form a substantial conceptual basis for the artifact, beyond routine
  dependency use.
- Named prior art, research, or design work whose insights were borrowed.

**Not triggered by** (license metadata alone suffices):

- Routine package-manager dependencies whose `LICENSE` files are surfaced
  mechanically via Cargo, npm, pip, Nix, etc.
- Well-known standards and specifications (POSIX, RFC, ISO, GFM, ODF,
  OOXML) that the artifact conforms to but does not redistribute.
- Public-domain conventions and common idioms.

**Required content per credited work:**

| Field      | Required | Example                                          |
|------------|----------|--------------------------------------------------|
| Name       | Yes      | `Microsoft Pragmatic Rust Guidelines`            |
| Author(s)  | Yes      | `Microsoft Corporation`                          |
| License    | Yes      | `MIT License`                                    |
| Source URL | Yes      | `https://github.com/microsoft/rust-guidelines`   |
| Scope      | Yes      | One-line description of what was adapted/used    |

A skill MAY keep a deeper, scope-limited attribution file inside its
`references/` directory (typically `references/ATTRIBUTION.md`) when the
credit applies specifically to adapted reference content. The root
`CREDITS.md` remains canonical and should link down to any such deeper
file.

SPDX headers (§4) cover license compliance mechanically; `CREDITS.md` is
the human-readable narrative — who, what, and how the upstream work
shaped the Spacecraft Software artifact.

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

---

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

**Remediation for existing projects.** §18 applies to every project immediately on
adoption of v1.33, so projects predating it are non-compliant until retrofitted.
Until a project conforms it MUST carry a **dated remediation entry** in
`PROJECTS.md` recording its accessibility state and intended remediation. An absent
entry is itself a compliance failure — a project may be unfinished, but it may not
be silently unfinished. **Projects registered as games (§18.5) are excluded** —
they owe no remediation entry, because they owe no conformance.

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
- [ ] **§9** PFA: no tracking, minimal permissions, local storage default
- [ ] **§10** CUA + Vim-like key bindings planned/implemented; bindings user-remappable; assistive-technology modifier chords (NVDA/Orca/VoiceOver) not captured — N/A for projects registered as games (§18.5)
- [ ] **§11** A registered palette is used — Steelbore Modern by default, or exactly one declared alternate (§11.4), never a mix; that palette's canvas is used unaltered; surface tokens are fills only, never text (§11.0.1); token-on-token pairings outside the palette's verified matrix measured before use; new apps expose colors via a named `Steelbore` theme binding the §11.1 role tokens — no bare hex literals in UI logic — and ship the palette's `-high-contrast` sibling
- [ ] **§11.6** Theme resolution implemented in two stages — base palette (in-app selection, then `SPACECRAFT_THEME`, then the §11.6.4 system declaration, then the platform color scheme, then the project's §11.4 default), then variant overlay (a pinned variant, then `NO_COLOR` ⇒ `steelbore-mono`, then §18.1 accessible mode, then platform high contrast); the registered set covers §11.6.1's thirteen eleven-role themes; an unknown or unregistered slug falls through rather than failing; palette switches are atomic and whole-surface and carry the new canvas; resolved theme and deciding source reported under `--verbose`; no dependence on per-role environment variables — Steelbore OS additionally renders `/etc/steelbore/theme.toml`, exports `SPACECRAFT_THEME`, and keeps the platform color-scheme preference in agreement with the declared polarity (§11.6.5) — N/A for artifacts with no user-facing output
- [ ] **§12** FOSS-licensed fonts only (Share Tech Mono / Inconsolata)
- [ ] **§13** Exactly one component system declared in `README.md` and followed — Material Design for Flutter/web/mobile/cross-platform, GNOME HIG for GTK 4, KDE HIG for Qt 6; themed through the `steelbore` theme (§11.1); WCAG 2.2 AA verified, stating which pairing was measured
- [ ] **§14** ISO 8601 dates; 24h time; UTC Z is the default primary timestamp (companion local time with UTC offset permitted, never a replacement) — unless the project filed the §14.2.1 domain exception for inherently local-time-bound data; ISO 8601 durations; metric units
- [ ] **§15** Attribution present: maintainer name (`Mohamed Hammad`), contact (`Mohamed.Hammad@SpacecraftSoftware.org`), and project URL in `--version` / README / About
- [ ] **§15.3** Third-party work credited in `CREDITS.md` at project/skill root when triggers apply; deeper `references/ATTRIBUTION.md` present where reference content is adapted from external sources
- [ ] **§17** Development progress tracked and reported continuously as the §17.1 labelled-row block — one 20-cell bar per track, milestone rows then MVP then TODO/PLAN/PRD, only the rows that apply; every row set in `█`/`░` with tight brackets, columns aligned, no ASCII bars
- [ ] **§18** Accessible mode implemented and off by default; §18.1 toggle honored with correct precedence; status never color-only; no animation or decorative art in accessible mode; TUI ships a linear mode and a non-interactive CLI path; GUI publishes accessible names and roles (AccessKit for Rust); verified with a real screen reader; existing projects carry a dated remediation entry in `PROJECTS.md` until they conform — N/A for projects registered as games (§18.5), which are exempt in full
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
