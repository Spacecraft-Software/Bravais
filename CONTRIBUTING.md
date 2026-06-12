# Contributing to Steelbore OS Bravais

Thank you for your interest. Please read this document before opening an issue or pull
request — it sets honest expectations for both sides so no one's time is wasted.

## Project Stance

Steelbore OS Bravais is a **personal hobby project**. It is shaped around the
maintainer's own NixOS configuration and developed at hobby pace. This is **not** a
community-driven project, but external input is welcome and appreciated within the
bounds set out below.

## What Is Welcome

- **Bug reports** — clear, reproducible, with environment details (NixOS version,
  channel, flake target, CPU march level, hardware).
- **Suggestions** — module improvements, package additions, naming proposals (must
  follow the [Steelbore Standard §2](https://Standard.SpacecraftSoftware.org/) —
  aerospace/sci-fi/AI convention for new identifiers).
- **Pull requests** — small, focused, and aligned with the Steelbore Standard.
- **Documentation fixes** — typos, inaccuracies, broken links, clarifications.

## What Is Not Guaranteed

- **PR acceptance.** Direction, scope, and quality bar are set by the maintainer alone.
  A submitted contribution is not a guaranteed merge, even if it is correct and
  well-written. If a PR is not accepted, that is a judgment of fit, not of the work.
- **Response time.** Hobby project — expect responses on the order of days to weeks.
- **Roadmap influence.** Suggestions may inform direction but do not override the
  maintainer's plans.

## Before Opening a PR

1. **Open an issue first** for non-trivial changes. Discuss the design before writing
   code.
2. **Read the Steelbore Standard.** Memory safety → performance → hardened security,
   in that order. Rust-first. GPL-3.0-or-later with SPDX headers on source files.
3. **Test locally.** Validate with `nix flake check` and a dry-run rebuild:
   ```sh
   nix flake check
   nixos-rebuild dry-build --flake .#bravais-unstable-v3 --show-trace
   ```
4. **Follow existing conventions.** Module namespace is `steelbore.*`. Add packages to
   the appropriate `modules/packages/*.nix` file. Prefer Rust packages.
5. **Sign your commits with SSH** (Standard §6.3 — mandatory). Configure
   `commit.gpgsign=true` and `gpg.format=ssh`, and register your Ed25519 SSH
   key as a **Signing** key on GitHub (auth-only keys won't validate).
   Commits must show **Verified** on GitHub. `git commit -s` (DCO sign-off)
   is a different mechanism and does not satisfy this requirement.

## Commit Style

- Conventional Commits prefix (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).
- Subject ≤ 72 characters, imperative mood ("add" not "added").
- Body wrapped at 72 columns; explain *why*, not just *what*.
- Reference issues by number (`Closes #42`).

## Forking

If your needs diverge, **fork it**. That is exactly what GPL-3.0-or-later is for.
Preserve copyright notices and pass the same freedoms downstream.

## Reporting Security Issues

For security-sensitive bugs, do **not** open a public issue. Email
&lt;Mohamed.Hammad@SpacecraftSoftware.org&gt; with details. A coordinated-disclosure window
of 90 days from acknowledgment is the default.

## License of Contributions

By submitting a contribution, you agree that it will be licensed under
**GPL-3.0-or-later**, the same terms as the project. No CLA is required.
You retain copyright in your contributions.

---

**Maintainer:** Mohamed Hammad &lt;Mohamed.Hammad@SpacecraftSoftware.org&gt;
**License:** GPL-3.0-or-later
**Website:** <https://Bravais.SpacecraftSoftware.org/>

*--- Forged in Spacecraft Software ---*
