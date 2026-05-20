# rage (age)

**Replaces:** `gpg` (simple symmetric/asymmetric encryption) | **Language:** 🦀 Rust | **Install:** `cargo install rage`

## Purpose
Rust implementation of the `age` encryption format. Simple, modern, small keys (X25519), no PGP web-of-trust complexity.

## Key commands
| Command | Meaning |
|---------|---------|
| `rage-keygen -o KEYFILE` | Generate key pair |
| `rage -e -r PUBKEY -o OUT FILE` | Encrypt for recipient |
| `rage -d -i KEYFILE -o OUT FILE.age` | Decrypt |
| `rage -p -o OUT FILE` | Passphrase-encrypt (symmetric) |
| `rage -R RECIPIENTS_FILE …` | Multiple recipients from file |
| `rage -i IDENTITY -d …` | Multiple identities |

## Examples
1. Generate key: `rage-keygen -o ~/.config/rage/key.txt`
2. Encrypt for a public key: `rage -r age1q… -o secret.txt.age secret.txt`
3. Decrypt: `rage -d -i ~/.config/rage/key.txt -o secret.txt secret.txt.age`
4. Passphrase-encrypt a tar on the fly: `tar c dir/ | rage -p -o dir.tar.age`

## Gotchas
- No signing — `age` is encryption-only. For signatures, use `sq` (Sequoia) or `sigstore`/`cosign`.
- Identity files are plaintext — protect with filesystem permissions or pair with `sops`/`rage-plugin-yubikey`.
