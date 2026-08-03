# Cargo (`cargo install`) — Rust crates only (Band B, tier 4)

Permanent, user-local install to `~/.cargo/bin/`. No sudo required. **Only
applicable to Rust crates** — skip Cargo for any non-Rust tool, even if
`cargo` is installed.

> **Consent gate.** This is a durable change to the user's machine. Propose it
> — the command, the path it lands in (`~/.cargo/bin/<binary>`), the removal
> command (`cargo uninstall <crate>`), and the fact that it is untracked by any
> declarative config — then **wait for the go-ahead**. Do not install and
> report afterward.
>
> **Prefer the alternatives first:** an ephemeral `nix run nixpkgs#<pkg>` /
> `guix shell <pkg>` for a one-off ([nix.md](nix.md), [guix.md](guix.md)); a
> devShell if the repo needs it repeatedly ([project-env.md](project-env.md));
> a `home.packages` entry if the user wants it permanently
> ([declarative.md](declarative.md) — most Rust CLIs are already in nixpkgs and
> Guix, pre-built, so a declarative entry is faster than compiling here).
> Cargo is the answer only when the crate is packaged nowhere else.

## Syntax

```bash
# Install the crate (downloads, compiles, places binary in ~/.cargo/bin/)
cargo install <crate>

# Then run the binary
<binary> <args>

# If ~/.cargo/bin isn't on PATH yet:
"$HOME/.cargo/bin/<binary>" <args>
```

### Key notes

- `cargo install` **compiles from source** by default — first install can be
  slow. Use `cargo-binstall` (below) for pre-built binaries.
- The **binary name may differ** from the crate name. Examples:
  - `fd-find` crate → `fd` binary
  - `ripgrep` crate → `rg` binary
  - `exa` crate → `exa` binary
  Check the crate's README on <https://crates.io/> before assuming.
- `~/.cargo/bin` must be on `PATH`. On fresh systems:
  ```bash
  export PATH="$HOME/.cargo/bin:$PATH"
  ```

## Examples

```bash
# ripgrep (binary is `rg`)
cargo install ripgrep && rg 'TODO' src/

# hyperfine
cargo install hyperfine && hyperfine 'cmd_a' 'cmd_b'

# Nushell (binary is `nu`)
cargo install nu && nu -c 'ls | where size > 1kb'

# fd (crate is `fd-find`)
cargo install fd-find && fd -e rs

# bat
cargo install bat && bat README.md
```

## Extras

### Pre-built binaries with `cargo-binstall`

Much faster than compiling from source — downloads GitHub Release artifacts
when the upstream publishes them.

```bash
# Bootstrap cargo-binstall itself (one-time)
cargo install cargo-binstall

# Then use it in place of cargo install
cargo binstall <crate>
```

### Install from a Git source

Useful for unreleased crates or forks:

```bash
cargo install --git https://github.com/<owner>/<repo>
cargo install --git https://github.com/<owner>/<repo> --branch <branch>
cargo install --git https://github.com/<owner>/<repo> --rev <commit>
```

### Install a specific version

```bash
cargo install <crate> --version <semver>
```

### Install with specific features

```bash
cargo install <crate> --features "<feature-a>,<feature-b>"
cargo install <crate> --no-default-features
```

### Force reinstall / upgrade

```bash
cargo install <crate> --force
```

## Lookup

- Online: <https://crates.io/>
- CLI: `cargo search <n>`
- See [lookup.md](lookup.md) for details.

## Cleanup

```bash
cargo uninstall <crate>
```

Tell the user what was installed and how to remove it — Cargo is a permanent
manager (Band B in the priority chain).
