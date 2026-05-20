# sequoia-chameleon-gnupg

**Replaces:** `gpg` (drop-in) | **Language:** 🦀 Rust | **Install:** `cargo install sequoia-chameleon-gnupg`

## Purpose
GnuPG-compatible CLI built on Sequoia. Drop-in `gpg` replacement for git signing, package signing, any workflow that shells out to `gpg`. Mohamed's preferred signing stack across Git CLI, gh CLI, GitHub Desktop, VSCode, Antigravity IDE.

## Install as `gpg`
Symlink or alias:
```
ln -s "$(which sqv-gpg)" ~/.local/bin/gpg
# or
alias gpg=sqv-gpg
```
Then `~/.gitconfig`:
```ini
[gpg]
    program = sqv-gpg
[commit]
    gpgsign = true
```

## Key commands (GnuPG-compatible)
| Command | Meaning |
|---------|---------|
| `gpg --list-keys` | List public keys |
| `gpg --list-secret-keys` | Private keys |
| `gpg --gen-key` | Generate |
| `gpg --export -a FPR` | Export armored |
| `gpg --import KEY.asc` | Import |
| `gpg -s -u FPR FILE` | Sign |
| `gpg --verify FILE.sig` | Verify |
| `gpg -e -r USER FILE` | Encrypt |
| `gpg -d FILE.gpg` | Decrypt |

## Examples
1. Sign a commit: `git commit -S -m "msg"` (with gpg.program configured)
2. Export your public key: `gpg --export -a "$FPR" > pub.asc`
3. Verify a release signature: `gpg --verify release.tar.gz.sig release.tar.gz`

## Gotchas
- Imports GnuPG keyrings automatically on first use — back them up first.
- Some exotic `gpg` flags aren't implemented; unsupported operations fall back to GnuPG if present.
