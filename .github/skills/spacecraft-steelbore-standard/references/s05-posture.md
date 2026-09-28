<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
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
| `SECURITY.md`     | Private reporting channel, acknowledgement target, supported versions, and coordinated-disclosure terms (§26.1) |
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

