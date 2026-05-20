# gitway

**Replaces:** `ssh` (for Git transport to GitHub/GHE) | **Language:** 🦀 Rust | **Install:** Spacecraft Software default; `cargo install --path gitway-cli` from `github.com/Spacecraft-Software/Gitway`

## Purpose
Purpose-built SSH transport client for Git operations against GitHub and GitHub
Enterprise Server. Unlike general-purpose `ssh`, Gitway pins GitHub's host-key
fingerprints (no TOFU), searches for keys in a predictable order, and behaves
identically on Linux, macOS, and Windows. Drop-in for `GIT_SSH_COMMAND` and
`core.sshCommand`. Does **not** replace `ssh` for general SSH use (shells,
tunneling, forwarding) — only for Git's SSH transport.

## Key flags
| Flag | Meaning |
|------|---------|
| `-i, --identity <FILE>` | Path to SSH private key |
| `--cert <FILE>` | OpenSSH certificate alongside the key |
| `-p, --port <PORT>` | SSH port (default: 22) |
| `-v, --verbose` | Debug logging to stderr |
| `--test` | Verify connectivity; print GitHub banner |
| `--install` | Register as `core.sshCommand` in global Git config |
| `--insecure-skip-host-check` | Danger: skip host-key verification |

## Examples
1. Register Gitway as the global Git SSH command
   `gitway --install`
2. Verify connectivity to GitHub
   `gitway --test`
3. Use a specific key
   `gitway --identity ~/.ssh/id_ed25519_github github.com git-upload-pack 'org/repo.git'`
4. Per-operation override (POSIX/Bash)
   `GIT_SSH_COMMAND=gitway git clone git@github.com:org/repo.git`
5. Per-operation override (Nushell)
   `$env.GIT_SSH_COMMAND = "gitway"; git clone git@github.com:org/repo.git`
6. Target a GHE instance
   `gitway --port 22 ghe.corp.example.com git-upload-pack 'org/repo.git'`

## Gotchas
- **GitHub/GHE only.** Not a general `ssh` replacement — will not connect to
  arbitrary hosts. Keep `ssh` for shell sessions, port-forwarding, tunnels.
- **GHE requires `~/.config/gitway/known_hosts`** populated with SHA-256
  fingerprints in OpenSSH `known_hosts` format. Retrieve via
  `ssh-keyscan -t ed25519 <host> | ssh-keygen -lf -`.
- **Key discovery order is fixed:** `--identity` → `~/.ssh/id_ed25519` →
  `~/.ssh/id_ecdsa` → `~/.ssh/id_rsa` → `SSH_AUTH_SOCK` agent.
- **Host-key pinning aborts on mismatch.** If GitHub rotates keys, update Gitway
  rather than bypassing with `--insecure-skip-host-check`.
- **Library crate available:** `gitway-lib` for embedding programmatic Git
  transport in Rust projects.
- **Repo:** `github.com/Spacecraft-Software/Gitway` — check there for current fingerprints
  and MSRV.
