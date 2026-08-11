---
name: vendored-binaries
description: How to bump the nine version+hash-pinned upstream packages in the Bravais NixOS config that nix flake update cannot touch (claude-desktop, chrome-remote-desktop, ollama, goose-desktop, opencode-desktop, github-copilot-app, adguardvpn-cli, obscura, browseros). Use when asked to update or check a vendored binary, or when a vendored package fails to build. Covers pkgs/update-vendored.nu, per-package failure isolation, and why obscura needs its own bumper with two hashes.
---

Nine packages pin an upstream `version` + `hash` that `nix flake update` cannot
touch: `claude-desktop`, `chrome-remote-desktop`, `ollama`, `goose-desktop`,
`opencode-desktop`, `github-copilot-app`, `adguardvpn-cli`, `obscura` (all in
`pkgs/`), and `browseros` (inline in `modules/packages/browsers.nix`). They are
**declarative, not self-updating** -- never bump one by hand.

```sh
nu pkgs/update-vendored.nu              # bump all 9 + nix build each
nu pkgs/update-vendored.nu --check      # report only, change nothing
nu pkgs/update-vendored.nu ollama       # single package
```

- **Failures are isolated per package** (fixed 2026-08-04). A build failure yields
  `action: "build failed"`; any other error yields `action: "error: …"`; both are
  re-listed in a summary block after the table. Before that fix, `nix build`
  raising propagated out of the `each` in `main`, so the first broken package
  silently skipped every package after it -- the run merely *looked* finished.
- **A failed build leaves the version/hash rewrite in place on purpose.** The bump
  is nearly always correct and the *packaging* is what needs fixing, so the
  modified file is the starting point. Check `git diff`.
- The script exits **zero** even on failure, because `rebuild`'s monthly `--check`
  nag depends on it. Change that only if it is ever wired into CI.
- `up-github` takes optional `tag_pattern` / `strip_suffix` params for repos whose
  tags carry decoration the version string does not (AdGuardVPNCLI tags
  `v1.7.12-release` for version `1.7.12`).
- **`obscura` is the only member built from SOURCE**, so `up-github` cannot bump it
  and `up-obscura` exists instead. It pins *two* hashes, neither a release asset:
  the `fetchFromGitHub` **unpacked-tree** hash (`prefetch-github-tree`, since
  `nix store prefetch-file` hashes the tarball and has no `--unpack`), and
  `cargoHash`, which no URL yields -- the vendored tree does not exist until cargo
  resolves the lock, so it is discovered by poisoning the hash, building, and
  parsing the `got:` line back out. `pkgs/obscura/librusty_v8.nix` is deliberately
  **not** bumped by the script: that pin tracks Obscura's `deno_core` dependency,
  not its release cadence.
- **Never restate a pinned version in prose.** The ollama 0.31.1 -> 0.32.5 bump
  orphaned five hardcoded copies across modules and docs; they now point at
  `pkgs/ollama/package.nix` as the single source of truth. Same rule as §11.4 for
  palette values.
- `adguardvpn-cli` is the odd one out: upstream ships a **fully static** ELF, so it
  needs no `autoPatchelfHook` and no `buildInputs` -- unlike every other entry,
  which is a `.deb` needing the Electron/Chromium library chase. Its
  `installCheckPhase` runs `--version` under a scratch `HOME` (first run creates a
  data dir) to prove the static claim at build time.

