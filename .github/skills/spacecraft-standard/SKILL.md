---
name: spacecraft-standard
description: >
  The authoritative compliance reference for ALL work on Spacecraft Software-umbrella projects and
  subprojects (Zamak, Bravais, Ferrocast, Craton, Ironway, Caliper, Mawaqit, and any future
  projects). ALWAYS load this skill before writing code, documentation, specifications,
  architecture decisions, UI designs, naming choices, or any other artifact for a
  Spacecraft Software-umbrella project — even if the user doesn't explicitly mention the Standard.
  If the user mentions "Spacecraft Software", a Spacecraft Software subproject name, or asks you to work on
  anything in the Spacecraft Software ecosystem, consult this skill immediately. It encodes
  The Steelbore Standard v1.9 so you never need to ask for it or have it attached to a
  prompt again.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# The Steelbore Standard — Compliance Reference

**Version:** 1.9 | **Date:** 2026-05-18 | **Author:** Mohamed Hammad
**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

This skill encodes The Steelbore Standard in full. Apply every applicable section
to any artifact you produce under the standard. The 13-point compliance checklist
in §14 is your audit gate — run through it mentally before finalising any output.

**Changelog:**

- **v1.9 (2026-05-18):** Clarified organizational model in §1: "Steelbore" now specifically refers to Steelbore OS and OS-specific artifacts (configurations, themes, tooling); "Spacecraft Software" is the broader umbrella. Independent projects (Zamak, Ironway, Ferrocast, Caliper, etc.) are peer citizens of the umbrella — designed to work with Steelbore OS but OS-agnostic and usable on any compliant platform. Both categories governed by this standard in full.
- **v1.8 (2026-05-18):** Standard name reinstated as "The Steelbore Standard". Primary mandate reaffirmed as the Steelbore OS line; scope explicitly extended by default to all Spacecraft Software projects (unless a project's own spec explicitly carves out an exception). Subtitle updated to reflect dual scope. Source file renamed `The_Spacecraft_Software_Standard.md` → `The_Steelbore_Standard.md`. §13.1: added Standard subdomain entry (`Standard.SpacecraftSoftware.org`). Umbrella org name and domain (Spacecraft Software / SpacecraftSoftware.org) unchanged.
- **v1.7 (2026-05-15):** Umbrella renamed from `Steelbore` to `Spacecraft Software` per the brand consolidation. Standard's name updated to "The Spacecraft Software Standard"; domain to `SpacecraftSoftware.org`; contact email to `Mohamed.Hammad@SpacecraftSoftware.org`; §13.1 subdomain pattern to `<ProjectName>.SpacecraftSoftware.org`. Skill ID prefix renamed (`steelbore-*` → `spacecraft-*`). Subproject codenames unchanged. The OS line (`Steelbore OS`, `Steelbore OS Bravais`, `Steelbore OS Lattice`) retains the Steelbore name and is unaffected by this rename.
- **v1.6 (2026-05-13):** Synced §2.1 development statuses with PROJECTS.md — `Bravais` and `Anvil` and `Flux` promoted to Completed; `Ferrocast` corrected to Planning; `Mawaqit` updated to Planning (Pending rename).
- **v1.5 (2026-05-13):** Corrected `Craton` status in §2.1 from `Active` to `Reserved` — codename is registered but no development has started yet.
- **v1.4 (2026-05-13):** Synced §2.1 Legacy Metallurgical Registry with PROJECTS.md — added five previously unregistered pre-v1.2 codenames: `Anvil`, `Flux`, `Pearlite`, `Ferrite_OS`, and `Forge`. Expanded §13.1 subdomain table to include all first-party projects with GitHub repositories that were missing: Anvil, Construct, Ferrite_OS, Forge, Ginx, Loran, Pearlite.
- **v1.3 (2026-05-12):** Added §6.3 (Signed & Verified Commits — mandatory Ed25519 SSH commit signing with hosting-platform "Verified" status; the rule extends to programmatic, CI, and assistant-driven commits and requires rewrites to preserve signatures). Added §13.3 (Third-Party Attribution — `CREDITS.md` at project/skill root when external work is substantially built upon, distinct from mechanical SPDX license metadata). Two new compliance-checklist bullets cover both additions.
- **v1.2 (2026-05-11):** Replaced §2 metallurgical naming convention with Aerospace, Sci-Fi & AI naming (aerospace/astronomy terminology + franchise references from *2001: A Space Odyssey*, *The Matrix*, *Terminator*). Preserved pre-v1.2 metallurgical-era names under §2's Legacy Registry. Added explicit statement that the standard's name was decoupled from project naming and would survive any project or umbrella rename (subsequently revisited in v1.7's umbrella rename). Renamed `Lattice` to `Bravais` (collision with Lattice OS) in registry and §13.1 subdomain table. Flagged `Mawaqit` as pending rename under the v1.2 convention.
- **v1.1 (2026-05-06):** Added §5 Project Posture (personal-hobby default, general-use carve-out, required posture files). Renumbered prior §5–§13 to §6–§14. Added posture bullet to compliance checklist.
- **v1.0 (2026-03-08):** Initial release.

---

## §1 — Preamble

The Steelbore Standard defines the engineering principles, compliance requirements, and design conventions that govern all software produced under Spacecraft Software. The umbrella encompasses two categories of work: **Steelbore OS** — the operating system and all OS-specific artifacts (configurations, themes, OS tooling) — and **independent Spacecraft Software projects** such as Zamak, Ironway, Ferrocast, and Caliper, which are designed to work with Steelbore OS but are not OS-specific and may run on any compliant platform. Both categories are full citizens of Spacecraft Software and subject to this standard in full. Where a project-specific specification conflicts with this standard, the stricter of the two requirements shall prevail.

**Standard name vs. project naming.** "The Steelbore Standard" is the canonical, stable name of *this standard*. It is independent of the projects it governs and of the umbrella organization name — the standard retains this name regardless of any future renames. The v1.7 umbrella rename (Steelbore → Spacecraft Software) and the v1.8 reinstatement of this standard's name are recorded in the changelog. Versioning of project codenames (see §2) and versioning of the standard are separate concerns.

---

## §2 — Aerospace, Sci-Fi & AI Naming Convention

All **new** project codenames, module identifiers, and public-facing component names
**must** draw from one of the following domains:

- **Real aerospace and astronomy** — orbital mechanics terms, propulsion concepts,
  named missions/programs, stellar objects and phenomena, observatories.
- **Science-fiction franchises with space / AI / cybernetic themes** —
  *2001: A Space Odyssey*, *The Matrix*, and *Terminator* are the explicitly
  endorsed canonical sources. Other franchises (e.g., *Alien*, *Blade Runner*,
  *Ex Machina*) are acceptable if they fit the space-machine-AI register.
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
| `Zamak`     | Active                | Rust bootloader (Limine rewrite)                               |
| `Bravais`   | Completed (renamed)   | NixOS flake configuration. Renamed from `Lattice` due to collision with Lattice OS. `Bravais` is still a metallurgical-era name (Bravais lattice) and predates the v1.2 convention. |
| `Ferrocast` | Planning              | Rust PowerShell rewrite (16-crate workspace)                   |
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
this table and §13.1's subdomain table in the same commit.

### §2.2 — Skill IDs are functional, not codenamed

Skill directory names and SKILL.md `name` fields are **functional identifiers**
(e.g., `spacecraft-standard`, `spacecraft-document-format`) and are not subject to
the §2 codename convention. §2 reserves codenames for projects/modules/utilities/releases,
not for skill identifiers.

---

## §3 — Priority Hierarchy (Non-Negotiable Order)

A higher-numbered priority **may never compromise** a lower-numbered one.

### §3.1 — Priority 1: Memory Safety
- **Preferred language: Rust** — governed by the Spacecraft Software Rust Guidelines.
  → Always load the `rust-guidelines` skill before writing any Rust code.
- When Rust is not viable (Flutter/Dart, Zig, etc.), **mandatory mitigations**:
  - **ASLR** (Address Space Layout Randomization) on all compiled binaries
  - **CFI** (Control-Flow Integrity) wherever the toolchain supports it
- Memory-Safe Languages (MSLs) are always preferred. If an MSL alternative exists,
  it must be chosen unless a documented technical exemption is filed.

### §3.2 — Priority 2: Performance
- Concurrency must be **designed-in from the start**, never bolted on retroactively.
- Release builds must use CPU-optimized flags: `-march=native`, LTO, PGO where applicable.
- Benchmarking is **mandatory** before and after any optimization work; regressions must
  be documented and justified.

### §3.3 — Priority 3: Hardened Security
- Kernel hardening (XanMod, grsecurity profiles) where applicable.
- Sandboxing and privilege separation for all network-facing components.
- **Post-Quantum Cryptography (PQC) readiness**: all crypto subsystems must support
  PQC migration paths. Use hybrid schemes (classical + PQC candidate) where library
  support exists. Adopt NIST-finalized PQC standards within one major release cycle.
  - Current targets: ML-KEM-768, ML-DSA-65 (as used in Ferrocast)
- Dependency auditing: `cargo-audit` or equivalent before any third-party crate inclusion.

**Cardinal Rule:** Any optimization that weakens memory safety or security hardening
**must be rejected**, no exceptions.

---

## §4 — Licensing & Compliance

- **License:** GNU General Public License, version 3 or later (`GPL-3.0-or-later`)
- No proprietary, closed-source, or permissive-only exceptions for core project code.

### SPDX Headers (mandatory on software source code files only)
```
<!-- REUSE-IgnoreStart -->
// SPDX-License-Identifier: GPL-3.0-or-later
<!-- REUSE-IgnoreEnd -->
```
**Software source code files** (`.rs`, `.ts`, `.js`, `.py`, `.sh`, `.ps1`, `.go`, etc.)
and project manifests (`Cargo.toml`, `package.json`, `flake.nix`, etc.) must include
the SPDX header/expression.

**Document files** (`.odt`, `.ods`, `.odp`, `.docx`, `.xlsx`, `.pptx`, `.pdf`, etc.) are **exempt** from
SPDX header requirements; the license is stated in the project root.

**When writing or reviewing any software source file**, check that the SPDX header is present.
When generating new source files, always include it.

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
| License        | GPL-3.0-or-later (formal terms govern in any conflict)         |

### §5.2 — Required Posture Files (per project)

Every Spacecraft Software project repository **must** ship the following files at its
root, derived from the canonical Spacecraft Software templates:

| File              | Purpose                                                     |
|-------------------|-------------------------------------------------------------|
| `README.md`       | Includes a "Project Posture" section linking to the two below |
| `NOTICE.md`       | Full no-warranty / no-liability statement; defers to GPL-3.0-or-later for binding terms |
| `CONTRIBUTING.md` | Contribution scope, PR-acceptance discretion, sign-off, security reporting, license-of-contributions |
| `LICENSE`         | Verbatim GPL-3.0-or-later text (existing §4 rule)           |

Customize only the project name, scope, and any project-specific carve-outs.

### §5.3 — General-Use Carve-Out

A project may declare itself **intended for general use**. When it does:

- The declaration MUST appear in that project's `README.md` posture section.
- The no-warranty / no-liability stance from §5.1 still applies in full —
  general-use status changes audience and intent, **not** legal terms.
- General-use projects must hold a higher release-quality bar:
  semantic versioning, maintained `CHANGELOG.md`, deprecation policy, and a
  documented support window for the current major version.

**General-use registry** (keep in sync with §13.1 subdomain table):

| Project      | Posture       |
|--------------|---------------|
| Anvil-SSH    | General-use   |
| (all others) | Personal      |

### §5.4 — Maintainer Discretion

PR acceptance, feature scope, naming, architecture, and roadmap are at the
maintainer's sole discretion. This is stated openly so contributors can
calibrate effort accordingly. Rejection reflects fit, not quality.

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
| Hosting-platform "Verified" required | Every commit on a Spacecraft Software remote must show "Verified" on the platform's commit/PR view. Unsigned or "Unverified" commits MUST be remediated (re-signed via rebase or amend by the original author) before merge to a default branch. |
| Programmatic commits signed too | Bots, CI pipelines, scripted commits, and assistant-driven commits inherit the same rule — no `--no-gpg-sign`, no signing-disabled subshells. The signing pipeline runs unattended. |
| Rewrites preserve signatures | Rebase, amend, cherry-pick, and squash MUST re-sign each resulting commit. Don't push history that lost signatures through rewriting. |
| Local verification is best-effort | `git log --show-signature` may report "No signature" on a given host when `~/.ssh/allowed_signers` is not populated — this is a local-verifier gap, not a signing failure. The hosting platform's "Verified" badge is authoritative. |

**Algorithm note:** Ed25519 SSH signing is the current default. §6.2 calls
for PQC readiness across the cryptographic surface; commit-signing
algorithm migration is gated on hosting-platform support for post-quantum
key formats. When GitHub (or Spacecraft Software's own Gitway) accepts PQC signing
keys, Spacecraft Software commits migrate accordingly.

---

## §7 — Privacy-Friendly Application (PFA) Policy

Every Spacecraft Software application must satisfy **all three** PFA requirements:

| Requirement        | Rule                                                                     |
|--------------------|--------------------------------------------------------------------------|
| No Tracking/No Ads | Zero advertising, tracking, analytics SDKs, or telemetry beacons        |
| Minimal Permissions| Only essential permissions; requested lazily at point of use, never eagerly |
| Local Storage      | User data stored locally by default; sync is strictly opt-in, E2E encrypted |

When reviewing or designing any feature that touches data handling, permissions,
or networking, verify all three PFA requirements are met.

---

## §8 — Key Bindings

All interactive applications must support **both**:

| Scheme    | Requirement                                                              |
|-----------|--------------------------------------------------------------------------|
| **CUA**   | Standard bindings (Ctrl+C/X/V/Z/S) must work in all text input contexts  |
| **Vim**   | Modal editing layer (Normal / Insert / Visual mode) as opt-in feature. Minimum: hjkl navigation where full Vim layer is impractical |

---

## §9 — Spacecraft Software Color Palette (WCAG-Compliant)

The **only** permitted colors for Spacecraft Software interfaces and documents:

| Token          | Hex       | RGB              | Role                        |
|----------------|-----------|------------------|-----------------------------|
| Void Navy      | `#000027` | RGB(0, 0, 39)    | **Background / Canvas**     |
| Molten Amber   | `#D98E32` | RGB(217, 142, 50)| Primary Text / Active Readout |
| Steel Blue     | `#4B7EB0` | RGB(75, 126, 176)| Primary Accent / Structural |
| Radium Green   | `#50FA7B` | RGB(80, 250, 123)| Success / Safe Status       |
| Red Oxide      | `#FF5C5C` | RGB(255, 92, 92) | Warning / Error Status      |
| Liquid Coolant | `#8BE9FD` | RGB(139, 233, 253)| Info / Links               |

**`#000027` (Void Navy) is the mandatory background for ALL Spacecraft Software surfaces.**
No alternative background is permitted. This is non-negotiable.

For document/file generation → load the `spacecraft-document-format` skill.
For IDE/terminal themes → load the `spacecraft-theme-factory` skill.

---

## §10 — Typography (FOSS-Licensed Fonts Only)

Acceptable font licenses: **OFL, Apache 2.0, Ubuntu Font License, CC0-1.0**

| Context        | Font              | License |
|----------------|-------------------|---------|
| Headings       | Share Tech Mono   | OFL     |
| Body / Code    | Inconsolata       | OFL     |
| Fallback       | monospace (system)| N/A     |

Never use proprietary fonts. When suggesting or using fonts in any Spacecraft Software artifact,
verify they are available on Google Fonts or another FOSS-licensed repository.

---

## §11 — UI/UX Design System

- **Material Design** is the required component system for all graphical applications.
  Theme Material components with the §9 color palette.
- **WCAG 2.1 Level AA** contrast is the minimum for all color pairings.
  Any new color additions must be WCAG-verified before adoption.
- **Accessibility:** screen readers, keyboard-only navigation, and system accessibility
  preferences (reduced motion, high contrast) must all be respected.

---

## §12 — Date, Time & Units

### §12.1 — Date & Time Format Rules

| Concern      | Rule                                                             | Example                      |
|--------------|------------------------------------------------------------------|------------------------------|
| Date format  | ISO 8601 only: `YYYY-MM-DD`                                      | `2026-03-08`                 |
| Time format  | 24-hour only: `HH:MM:SS` — AM/PM is **never** permitted          | `14:30:00`                   |
| Timestamp    | Combined ISO 8601 UTC: `YYYY-MM-DDTHH:MM:SSZ`                    | `2026-03-08T14:30:00Z`       |
| Timezone     | **UTC always.** The `Z` suffix is mandatory — see §12.2          | `Z` not `+00:00`             |
| Duration     | ISO 8601 duration format only                                    | `PT1H30M` not "1h 30m"       |
| Units        | Metric (SI) primary; imperial in parentheses only if locale requires | `100 km (62 mi)`         |

Apply these conventions to all generated code, documentation, comments, and any
user-facing strings. Never output AM/PM time, non-ISO dates, or imperial-primary units.

### §12.2 — UTC-Only Timezone Policy (Non-Negotiable)

**UTC is the one and only timezone for all stored, transmitted, logged, and
committed timestamps across every Spacecraft Software project.** This is a non-negotiable
rule with no exceptions for core data paths.

**Mandatory rules — violation blocks shipping:**

| Rule | Detail |
|------|--------|
| `Z` suffix required | Every stored/transmitted timestamp MUST end with `Z`. `2026-03-08T14:30:00Z` ✓ |
| No offset notation in data | `+03:00`, `-05:00`, `+00:00` etc. are **forbidden** in stored or API timestamps. `Z` is the only permitted UTC marker. |
| No local time in data | Local-time timestamps (without timezone info, or with a local offset) are **forbidden** in files, databases, logs, API responses, and commits. |
| Log entries use UTC + `Z` | Every log line timestamp must be `YYYY-MM-DDTHH:MM:SS.sssZ` (millisecond precision encouraged). |
| Commit timestamps use UTC | `GIT_COMMITTER_DATE` and `GIT_AUTHOR_DATE` must be UTC when set programmatically. |
| File metadata written by Spacecraft Software tools | mtime/ctime written by Spacecraft Software tools must be UTC-sourced. |

### §12.3 — Display-Only Local Time (Render Layer Only)

Local time is permitted **only** as an ephemeral render layer in human-facing
terminal output. It is **never** stored, serialized, transmitted, or logged.

- The `--absolute-time` flag (defined in `spacecraft-cli-standard` §3) disables
  relative-time rendering but always renders as UTC, not local time.
- If a future CLI wants to show local time in human mode, it MUST:
  1. Accept a `--tz <IANA-zone>` flag (e.g., `--tz Africa/Cairo`).
  2. Render local time only to stdout in human mode — never in `--json` output.
  3. Always include the UTC value alongside the local rendering.
  4. Never persist or transmit the local-time rendering.
- JSON/machine output (`--format json/jsonl/yaml/csv`) MUST always use UTC + `Z`.

### §12.4 — Duration Format

Durations follow ISO 8601 duration notation:

| Format   | Example   | Meaning             |
|----------|-----------|---------------------|
| `PTnHnMnS` | `PT1H30M` | 1 hour 30 minutes |
| `PnD`    | `P7D`     | 7 days              |
| `PnYnM`  | `P1Y6M`   | 1 year 6 months     |

Prose forms like "1h 30m", "90 minutes", "1.5 hours" are **forbidden** in
machine-readable output. They are acceptable in `--help` text only.

### §12.5 — Rust Implementation Guidance

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

## §13 — Attribution, Maintainer & Contact

**Maintainer:** Mohamed Hammad
**Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad | **License:** GPL-3.0-or-later
**Website:** [https://SpacecraftSoftware.org/](https://SpacecraftSoftware.org/)

### §13.1 — Project Pages

Each Spacecraft Software project has a dedicated subdomain following the pattern
`https://<ProjectName>.SpacecraftSoftware.org/`. Use the project-specific URL in all
project-level outputs; use `https://SpacecraftSoftware.org/` only for umbrella references.

| Project                    | URL                                              |
|----------------------------|--------------------------------------------------|
| Spacecraft Software (main) | https://SpacecraftSoftware.org/                  |
| The Steelbore Standard     | https://Standard.SpacecraftSoftware.org/         |
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

When a new project is created, add its subdomain to this table immediately.

### §13.2 — Mandatory Attribution in Project Outputs

Every Spacecraft Software product **must** surface the following attribution in at least one
of: `--help` output, `--version` output, README, or About/Info screen.

**Required attribution block:**
```
Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
Copyright (C) 2026 Mohamed Hammad  |  License: GPL-3.0-or-later
https://<ProjectName>.SpacecraftSoftware.org/
```

**Per-surface rules:**

| Surface           | Required content                                                        |
|-------------------|-------------------------------------------------------------------------|
| `--version`       | Maintainer name, project URL, copyright year                            |
| `--help`          | Project URL and maintainer name (at footer)                             |
| README            | "Maintainer" section: name, `Mohamed.Hammad@SpacecraftSoftware.org`, project URL |
| About / Info (GUI/TUI) | Maintainer name, project URL, copyright year                       |
<!-- REUSE-IgnoreStart -->
| SPDX header       | `// SPDX-License-Identifier: GPL-3.0-or-later` (existing §4 rule)      |
<!-- REUSE-IgnoreEnd -->

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

### §13.3 — Third-Party Attribution

Spacecraft Software artifacts must give credit where credit is due. When a project
or skill **substantially builds on third-party work**, that credit appears
in a `CREDITS.md` at the artifact's root — `<project-root>/CREDITS.md` for
projects, `<skill-name>/CREDITS.md` for skills.

`CREDITS.md` is the inbound counterpart to §13.2's outbound attribution:
§13.2 tells consumers who maintains Spacecraft Software; §13.3 tells consumers whose
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

## §14 — Compliance Checklist (Audit Gate)

Before finalising **any** Spacecraft Software artifact, mentally verify:

- [ ] **§2** Aerospace/Sci-Fi/AI naming convention applied to all **new** identifiers; legacy (pre-v1.2) names preserved unless explicitly renamed
- [ ] **§3.1** Memory safety: Rust used, or ASLR+CFI mitigations documented
- [ ] **§3.2** Concurrency designed-in; benchmarking planned/documented
- [ ] **§3.3** Hardened security; PQC readiness addressed
- [ ] **§4** `GPL-3.0-or-later` license; SPDX headers on software source code files (excluding documents)
- [ ] **§5** Project Posture: README/NOTICE/CONTRIBUTING present; default personal-hobby stance applied; general-use carve-outs declared in project README
- [ ] **§6.1** POSIX-compliant CLI/system tools
- [ ] **§7** PFA: no tracking, minimal permissions, local storage default
- [ ] **§8** CUA + Vim-like key bindings planned/implemented
- [ ] **§9** Spacecraft Software color palette used; Void Navy background mandatory
- [ ] **§10** FOSS-licensed fonts only (Share Tech Mono / Inconsolata)
- [ ] **§11** Material Design UI/UX; WCAG 2.1 AA verified
- [ ] **§12** ISO 8601 dates; 24h time; UTC-only timestamps with mandatory `Z` suffix; no local-time in stored/transmitted data; ISO 8601 durations; metric units
- [ ] **§13** Attribution present: maintainer name (`Mohamed Hammad`), contact (`Mohamed.Hammad@SpacecraftSoftware.org`), and project URL in `--version` / README / About
- [ ] **§13.3** Third-party work credited in `CREDITS.md` at project/skill root when triggers apply; deeper `references/ATTRIBUTION.md` present where reference content is adapted from external sources
- [ ] **§6.3** All commits to Spacecraft Software Git remotes cryptographically signed and showing "Verified" on the hosting platform; rewrites preserve signatures; programmatic and assistant-driven commits signed too

If any item is not applicable to the current artifact type (e.g., color palette
for a pure Rust library), note it as N/A rather than silently skipping it.

---

## Skill Cross-References

| Task                                  | Load this skill              |
|---------------------------------------|------------------------------|
| Writing any Rust code                 | `rust-guidelines`            |
| Generating DOCX / ODT / PDF documents | `spacecraft-document-format` |
| Creating IDE / terminal themes        | `spacecraft-theme-factory`   |
| All other Spacecraft Software work    | `spacecraft-standard`        |

---

*— Built by Spacecraft Software —*
