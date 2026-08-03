# Project environments — when a repo needs the tool repeatedly

**Rule: a tool needed more than once for a given repo belongs in a committed
project environment.** Re-typing `nix run nixpkgs#…` on every call is a smell —
it re-resolves the package each time, drifts between invocations, and leaves
nothing for the next contributor (or the next session) to reuse.

A project env is a **repo change**: it is committed, reviewed, and follows that
repo's own commit rules. Propose it rather than writing it silently.

Pick the form that matches the repo and the host:

| Form | Use when | Activate with |
|---|---|---|
| `flake.nix` devShell | The repo already uses flakes, or the host has flakes enabled | `nix develop` |
| `shell.nix` | Non-flake Nix, or maximum compatibility | `nix-shell` |
| `guix.scm` / `manifest.scm` | Guix host, or a Guix-first project | `guix shell -m manifest.scm` |
| `.envrc` + direnv | Any of the above, plus automatic activation on `cd` | `direnv allow` (one-time) |

For idiomatic Nix authoring — formatting, `let` bindings, overlays, flake
structure — defer to the `spacecraft-nix-guidelines` skill. This file covers
only the provisioning role.

---

## `flake.nix` devShell (preferred where flakes are enabled)

Add a `devShells.default` to the repo's existing flake, or create one:

```nix
{
  description = "<project> development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
        (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            shellcheck
            hyperfine
            ripgrep
          ];
        };
      });
    };
}
```

```sh
nix develop                       # interactive shell with the tools on PATH
nix develop -c shellcheck script.sh   # run one command inside it
```

Notes:

- `nix develop -c <cmd>` is the non-interactive form — use it from the agent,
  since each tool call is a fresh process and an interactive shell would not
  survive it.
- **`flake.lock` is generated and must be committed.** It is what makes the
  environment reproducible; an uncommitted lock defeats the purpose.
- If the repo already has a flake, *add* the `devShells` output — do not
  replace the existing structure.

## `shell.nix` (non-flake)

```nix
{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = with pkgs; [
    shellcheck
    hyperfine
  ];
}
```

```sh
nix-shell                              # interactive
nix-shell --run "shellcheck script.sh" # one command
```

Pin `nixpkgs` for reproducibility when the repo cares:

```nix
{ pkgs ? import (fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/<commit>.tar.gz") { } }:
```

## `guix.scm` / `manifest.scm`

```scheme
;; manifest.scm
(specifications->manifest
  '("shellcheck"
    "hyperfine"
    "ripgrep"))
```

```sh
guix shell -m manifest.scm -- shellcheck script.sh
```

For exact reproducibility, pin the Guix commit alongside it:

```sh
guix time-machine --commit=<git-commit> -- shell -m manifest.scm -- <cmd>
```

## `.envrc` + direnv (automatic activation)

direnv activates the environment on `cd` into the repo, so contributors and
agents get the tools without remembering a wrapper command.

```sh
# .envrc
use flake          # for flake.nix
# use nix          # for shell.nix
# eval "$(guix shell -m manifest.scm --search-paths)"   # for Guix
```

Two caveats, both consent-gated:

- **direnv itself may be missing** — installing it is a durable change to the
  host. Propose it through Band C (`home.packages = [ pkgs.direnv ];`), not an
  imperative install.
- **`direnv allow` is a per-user trust decision.** It lets the repo execute
  code on `cd`. The user runs it, not the agent:

  ```
  ! direnv allow
  ```

Add the cache directory to `.gitignore`:

```gitignore
.direnv/
```

---

## What to commit

| File | Commit? |
|---|---|
| `flake.nix`, `flake.lock` | Yes — the lock is the reproducibility guarantee |
| `shell.nix` | Yes |
| `guix.scm` / `manifest.scm` | Yes |
| `.envrc` | Yes |
| `.direnv/` | No — `.gitignore` it |
| `result` / `result-*` symlinks | No — `.gitignore` them |

---

## Interaction with the other bands

- **Band A is still correct for a genuinely one-off command** — don't write a
  devShell to run a linter once.
- **Band C (declarative) is for machine-wide tools**, not repo tools. A
  formatter used by one project belongs in that project's devShell; a shell the
  user lives in belongs in `home.packages`. See [declarative.md](declarative.md).
- Package names are the same ones the ephemeral managers use — verify them via
  [lookup.md](lookup.md) before writing them into the file.
