<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
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

