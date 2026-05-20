# rustup

**Replaces:** manual Rust toolchain management | **Language:** 🦀 Rust | **Install:** https://rustup.rs

## Purpose
Official Rust toolchain multiplexer. Manages stable/beta/nightly channels, targets, components (rustfmt, clippy, rust-analyzer).

## Key commands
| Command | Meaning |
|---------|---------|
| `rustup update` | Update all installed toolchains |
| `rustup default CHANNEL` | Set default (`stable`, `beta`, `nightly`, `1.78.0`) |
| `rustup toolchain install CHANNEL` | Install a toolchain |
| `rustup target add TARGET` | Add compilation target (e.g. `wasm32-unknown-unknown`) |
| `rustup component add NAME` | Add component (`clippy`, `rustfmt`, `rust-src`, `rust-analyzer`) |
| `rustup show` | Show active toolchain |
| `rustup override set NIGHTLY` | Pin toolchain for current directory |
| `rustup run CHANNEL CMD` | Run CMD with a specific toolchain |
| `rustup self update` | Update rustup itself |

## Examples
1. Fresh bootstrap: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
2. Add WASM target: `rustup target add wasm32-unknown-unknown`
3. Use nightly in this directory only: `rustup override set nightly`
4. Add clippy + rust-analyzer: `rustup component add clippy rust-analyzer`
5. Run a one-off nightly build: `rustup run nightly cargo build`

## Gotchas
- `rust-toolchain.toml` in a repo will override CLI defaults automatically — preferred for per-project pinning.
- `rustup self update` is disabled on package-manager installations (apt, brew, nix) — use the package manager.
