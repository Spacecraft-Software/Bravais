# Cargo (`cargo install`) — Rust crates only

Permanent, user-local install to `~/.cargo/bin/`. No sudo required. **Only
applicable to Rust crates** — skip Cargo for any non-Rust tool, even if
`cargo` is installed.

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
manager (tier 3 in the priority chain).
