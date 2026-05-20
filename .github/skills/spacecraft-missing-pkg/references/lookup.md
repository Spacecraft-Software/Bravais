# Package Name Lookup

Package names differ between every manager in the chain, and frequently
differ from the CLI binary name. Never guess — always verify against the
authoritative sources below.

If a lookup returns nothing, the package is not available via that manager.
Do not fabricate a name. Move down the priority chain.

---

## Lookup sources

### Guix

- **Online:** <https://packages.guix.gnu.org/>
  - Direct page pattern: `https://packages.guix.gnu.org/packages/<n>/`
  - *"Couldn't find any package named …"* means the package is not packaged.
- **CLI:** `guix search <regex>` or `guix package -s <regex>`

### Nix

- **Online:** <https://search.nixos.org/packages>
- **CLI:** `nix search nixpkgs#<tool-name>`
  - Extract the attribute name after `legacyPackages.x86_64-linux.`

### Cargo

- **Online:** <https://crates.io/>
  - Direct page pattern: `https://crates.io/crates/<n>`
- **CLI:** `cargo search <n>`
- **Important:** the crate name and the installed binary name often
  differ (e.g. the `fd-find` crate installs a binary named `fd`). Check
  the crate's README before assuming.

### Homebrew

- **Online:** <https://formulae.brew.sh/>
  - Direct page pattern: `https://formulae.brew.sh/formula/<n>`
- **CLI:** `brew search <regex>`
- Casks (macOS GUI apps) are separate: <https://formulae.brew.sh/cask/>

### Flatpak / Flathub

- **Online:** <https://flathub.org/>
- **CLI:** `flatpak search <term>`
- App-ids are reverse-DNS (e.g. `org.inkscape.Inkscape`,
  `com.github.tchx84.Flatseal`).
- Flathub is strongly biased toward GUI apps. Most CLI tools are not on
  Flathub — only use Flatpak when a confirmed app-id exists.

### Snap

- **Online:** <https://snapcraft.io/>
  - Direct page pattern: `https://snapcraft.io/<n>`
- **CLI:** `snap find <term>`
- Many snaps are community-maintained with no upstream endorsement — prefer
  a higher-ranked manager whenever one has the package.

---

## Cross-manager naming conventions

Rough rules only. Always verify the exact name via the lookup sources above.

| Aspect             | Guix                 | nixpkgs                | Cargo              | Homebrew            |
|--------------------|----------------------|------------------------|--------------------|---------------------|
| Python interpreter | `python`             | `python3`              | —                  | `python@3.12`       |
| Python lib X       | `python-X`           | `python3Packages.X`    | —                  | `python-X` (rare)   |
| Node runtime       | `node`               | `nodejs`               | —                  | `node`              |
| Typical attr style | flat name            | dotted path (`a.b.c`)  | flat crate name    | flat formula name   |
| Binary vs package  | usually matches      | usually matches        | **often differs**  | usually matches     |

When names diverge (especially for language ecosystem wrappers, legacy
aliases, and Rust crates whose binary differs from the crate name), look
each one up individually.

---

## Verification policy

- Guix names used in this skill's examples have been confirmed against
  <https://packages.guix.gnu.org/>.
- Cargo crates have been confirmed against <https://crates.io/>.
- Homebrew formulae have been confirmed against <https://formulae.brew.sh/>.
- Flatpak and Snap examples use placeholder `<app-id>` / `<pkg>` because
  Flathub is dominated by GUI apps and Snap CLI packages are often
  upstream-disowned (e.g. upstream `ripgrep` explicitly discourages the
  snap).
