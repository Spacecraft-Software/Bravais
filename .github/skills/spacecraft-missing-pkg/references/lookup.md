# Package Name Lookup

Package names differ between every manager in the chain, and frequently
differ from the CLI binary name. Never guess — always verify against the
authoritative sources below.

If a lookup returns nothing, the package is not available via that manager.
Do not fabricate a name. Move down the priority chain.

**Prefer a live query over a web page.** On the user's own machine the managers
are right there, and a local query is faster, offline-capable, and exactly
matches the channel/commit the host will actually resolve against:

```sh
nix search nixpkgs <term>              # authoritative for this host's nixpkgs
nix eval --raw nixpkgs#<pkg>.name      # confirm an attribute path resolves
guix search <regex>                    # authoritative for this host's Guix
brew search <regex>
flatpak search <term>
snap find <term>                       # read-only, no root needed
```

If the harness exposes a package-search tool or MCP server for the manager (a
NixOS-aware search server, for example), prefer it over scraping the web UI —
it is current, structured, and cheaper than fetching HTML.

Fall back to the web pages below when no local manager is installed or the
host is offline from the registry but you still need the canonical name.

---

## Lookup sources

### Guix

- **Online:** <https://packages.guix.gnu.org/>
  - Direct page pattern: `https://packages.guix.gnu.org/packages/<n>/`
  - *"Couldn't find any package named …"* means the package is not packaged.
- **CLI:** `guix search <regex>` or `guix package -s <regex>`

### Nix

- **Online:** <https://search.nixos.org/packages>
- **CLI:** `nix search nixpkgs <tool-name>`
  - Extract the attribute name after `legacyPackages.x86_64-linux.`
  - Confirm it resolves: `nix eval --raw nixpkgs#<pkg>.name`
- **NixOS / Home Manager options** (needed when proposing a Band C edit):
  <https://search.nixos.org/options>, <https://home-manager-options.extranix.com/>
- The same attribute names are what go into `environment.systemPackages` /
  `home.packages` — see [declarative.md](declarative.md).

### One-shot runners (`npx` / `uvx`)

- **npm (npx):** <https://www.npmjs.com/>
  - Direct page pattern: `https://www.npmjs.com/package/<n>`
- **PyPI (uvx / pipx run):** <https://pypi.org/>
  - Direct page pattern: `https://pypi.org/project/<n>/`
- Confirm the package exposes a CLI / console-script before running. For
  Python, when the command name differs from the distribution use
  `uvx --from <pkg> <command>`.

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

### AppImage

- **Authoritative:** the upstream project's own releases (GitHub Releases or the
  project download page) — that is where the correct `*.AppImage` asset URL
  lives.
- **Catalogue:** <https://appimage.github.io/> (AppImageHub) — searchable index
  of apps that ship an AppImage.
- Prefer an asset with a published checksum/signature and verify it when offered.

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
