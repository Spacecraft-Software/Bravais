<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
## §6 — Platform & Systems Requirements

### §6.1 — POSIX Compliance
All CLI tools, daemons, and system utilities must be **POSIX-compliant**.
Platform-specific extensions go behind feature flags and must not be required
for core functionality.

### §6.2 — Post-Quantum Cryptography
Crypto subsystems must have migration paths to post-quantum algorithms.
Current implementations should use hybrid schemes where library support exists.

### §6.3 — Signed & Verified Commits (Non-Negotiable)

Every commit pushed to a Spacecraft Software-controlled Git remote **must** be
cryptographically signed and show "Verified" on the hosting platform's
commit/PR view (GitHub today; Gitway or any future Spacecraft Software host inherits
the same rule).

**Mandatory rules — violation blocks shipping:**

| Rule | Detail |
|------|--------|
| All commits signed | `commit.gpgsign=true` configured globally. SSH signing (`gpg.format=ssh`) is the current default; GPG is acceptable. The signing key MUST be registered as a **Signing** key on the hosting platform — Authentication-only keys do not validate signatures. |
| Authorized signing identity | All commits from v1.12 onwards must be signed with the `Mohamed.Hammad@SpacecraftSoftware.org` key. The committer email and the signing key identity must both resolve to `Mohamed.Hammad@SpacecraftSoftware.org`. Commits predating v1.12 are exempt from this requirement. |
| Hosting-platform "Verified" required | Every commit on a Spacecraft Software remote must show "Verified" on the platform's commit/PR view. Unsigned or "Unverified" commits MUST be remediated (re-signed via rebase or amend by the original author) before merge to a default branch. |
| Programmatic commits signed too | Bots, CI pipelines, scripted commits, and assistant-driven commits inherit the same rule — no `--no-gpg-sign`, no signing-disabled subshells. The signing pipeline runs unattended, through the signing setup already present where the commit is made (next row). |
| Agents never handle key material | An agent — an AI assistant, a bot, a script, or a CI job — signs only through the signing setup already configured where it runs: git with an SSH agent or a hardware key on a maintainer's host, or the CI system's own secret store. It never creates, reads, copies, exports, or asks for a private key, passphrase, password, or access token, and never writes one into a log, a chat, a commit, or a file. When signing is not configured or fails, the agent stops and reports the failure to the maintainer; it does not request a key, switch to another identity, or disable signing to get past it. |
| Rewrites preserve signatures | Rebase, amend, cherry-pick, and squash MUST re-sign each resulting commit. Don't push history that lost signatures through rewriting. |
| Local verification is best-effort | `git log --show-signature` may report "No signature" on a given host when `~/.ssh/allowed_signers` is not populated — this is a local-verifier gap, not a signing failure. The hosting platform's "Verified" badge is authoritative. |

**Algorithm note:** Ed25519 SSH signing is the current default. §6.2 calls
for PQC readiness across the cryptographic surface; commit-signing
algorithm migration is gated on hosting-platform support for post-quantum
key formats. When GitHub (or Spacecraft Software's own Gitway) accepts PQC signing
keys, Spacecraft Software commits migrate accordingly.

### §6.4 — Authorized Contribution Targets (Non-Negotiable)

Spacecraft Software work is published only to namespaces Spacecraft Software
controls. Two are authorized today:
[github.com/Spacecraft-Software](https://github.com/Spacecraft-Software) (the
umbrella organization) and
[github.com/UnbreakableMJ](https://github.com/UnbreakableMJ) (the maintainer's
personal namespace). A future Spacecraft Software-controlled host — Gitway, or
any successor — inherits the same standing. Every other destination is
**outbound** and gated.

§6.3 says how a commit must be signed on a Spacecraft Software remote; this
section says which remotes those are, and what it takes to send anything
anywhere else.

**Mandatory rules — violation blocks shipping:**

| Rule | Detail |
|------|--------|
| Default-deny outbound | No `git push`, pull or merge request, patch series, or mailing-list submission to any Git remote outside the authorized namespaces. Silence is a denial, not permission. |
| Automation never initiates | Bots, CI pipelines, scripted workflows, and assistant-driven sessions MUST NEVER open an outbound contribution. Authorization for one contribution does not carry to the next task, session, or repository. |
| Maintainer-only exception | Only Mohamed Hammad, acting explicitly and per contribution, may authorize an outbound submission (§5.4 maintainer discretion). The authorization names the destination and the change; it does not generalize. |
| Registries and trackers included | Publishing to a package registry under a namespace Spacecraft Software does not control (`crates.io`, npm, PyPI, AUR, Nixpkgs, Guix, Flathub, and the like), and filing issues, bug reports, or patches on an external tracker or mailing list, are outbound contributions under this same rule. |
| Forks are inbound-only | A fork under an authorized namespace may be created and pushed to freely — that is our namespace. Turning a fork branch into an upstream pull request is the gated act, not the fork itself. |
| Prefer carrying the patch | When an upstream change is needed, carry the patch in-tree (§4.2 preserves upstream copyright, license texts, and notices) rather than upstreaming it, unless the maintainer authorizes upstreaming. |
| GNU posture does not exempt | An artifact under the free-software/GNU posture (§1) still requires explicit maintainer authorization before anything is sent to GNU, the FSF, or Savannah. That posture yields this standard's identity clauses (§2, §11–§12, §15); it does not yield this one. |
| Withdraw mistakes promptly | An outbound submission made without authorization MUST be closed or withdrawn as soon as it is discovered, and the incident recorded. |

### §6.5 — Text File Format (LF, UTF-8, final newline)

Every text file in a Spacecraft Software source tree is a **POSIX text file**:
UTF-8 encoded, LF-terminated, and ending with a newline. §6.1 requires POSIX
compliance of the tools; this section requires it of the files those tools are
written in.

**Mandatory rules — violation blocks shipping:**

| Rule | Detail |
|------|--------|
| LF line endings | Lines terminate with **LF** (U+000A). CRLF and a lone CR are prohibited — in source, configuration, scripts, documentation, and CI definitions alike. |
| Final newline | Every text file ends with a newline. A file whose last line is unterminated is not a POSIX text file, and it makes every diff that touches the last line carry a spurious `\ No newline at end of file`. |
| UTF-8, no BOM | Text files are encoded UTF-8. A byte-order mark is prohibited: it breaks shebang lines, `#`-comment parsing, and every config reader that expects the first byte of the file to be content. |
| `.gitattributes` required | Every repository MUST ship `.gitattributes` at its root containing `* text=auto eol=lf`. This is the only mechanism that holds regardless of a contributor's `core.autocrlf` setting — which defaults to `true` on Windows and rewrites the working tree on checkout. Relying on per-clone Git configuration is not compliance. |
| `.editorconfig` required | Every repository MUST ship `.editorconfig` at its root with `root = true` and, under `[*]`, at minimum `charset = utf-8`, `end_of_line = lf`, and `insert_final_newline = true`. It carries the rule to editors that never consult Git. |
| CI gate | CI MUST fail when a tracked text file is **stored** with CRLF. Both config files are advisory to the tools that read them; the gate is what makes the rule binding. The gate reads the index, not the working tree — `git ls-files --eol` reports the stored line ending as `i/lf`, `i/crlf` or `i/mixed`, and any `i/crlf` or `i/mixed` is a violation. A path pinned `-text` is declared binary and is not a text file at all, so it is skipped and its blob keeps whatever bytes it has. Grepping the working tree for a CR byte is **not** a correct implementation: a file pinned `eol=crlf` is stored LF and checked out CRLF by design, so a working-tree grep fails the very exception this section grants. |
| Exceptions | Vendored upstream files keep their upstream line endings (§4.2 — preserve what you build on). Windows-native scripts invoked by `cmd.exe` (`.bat`, `.cmd`) MAY use CRLF where the interpreter requires it. A format whose specification mandates CRLF keeps it. Every such exception is pinned explicitly in `.gitattributes` (`*.bat text eol=crlf`) rather than left to chance. Binary files are unaffected — `text=auto` never touches them. |

**Scope note.** This section governs *files on disk*, not *bytes on a socket*.
The CRLF that HTTP, SMTP, and the other line-oriented wire protocols require in
their framing is unaffected — a protocol implementation emits what its
specification demands.

This is codification of existing practice rather than a new constraint: `anvil`
and `bravais` already carry `* text=auto eol=lf`, and `loran` and `caliper`
already carry the three `.editorconfig` keys. What §6.5 adds is that the
convention is now uniform and enforced rather than rediscovered one repository
at a time.

---

