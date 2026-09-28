<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
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

