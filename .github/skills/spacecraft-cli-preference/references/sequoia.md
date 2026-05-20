# sequoia (sq)

**Replaces:** `gpg` (native, non-drop-in) | **Language:** 🦀 Rust | **Install:** `cargo install sequoia-sq`

## Purpose
Modern OpenPGP implementation. For interoperable signing/encryption/verification where you control the toolchain. Use `sequoia-chameleon` if you need drop-in `gpg` compatibility.

## Key commands
| Command | Meaning |
|---------|---------|
| `sq key generate --userid "Name <mail>"` | New key |
| `sq encrypt --recipient-cert FILE -o OUT FILE` | Encrypt |
| `sq decrypt --recipient-key KEY FILE.pgp` | Decrypt |
| `sq sign --signer-key KEY FILE` | Sign |
| `sq verify --signer-cert CERT FILE.pgp` | Verify |
| `sq inspect FILE` | Describe contents |
| `sq cert export --cert FPR` | Export public cert |
| `sq wkd publish` | Web Key Directory |

## Examples
1. Generate: `sq key generate --userid 'Mohamed <mohamed@example.com>' --output key.pgp`
2. Export cert: `sq cert export --cert "$FPR" --output cert.pgp`
3. Sign a release tarball: `sq sign --signer-key key.pgp release.tar.gz`
4. Verify: `sq verify --signer-cert cert.pgp release.tar.gz.sig`

## Gotchas
- Keys + certs are separate files; keep private keys offline where possible.
- Not automatically compatible with GnuPG keyrings — for that workflow use `sequoia-chameleon`.
