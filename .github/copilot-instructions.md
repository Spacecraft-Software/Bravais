# Copilot Instructions — Bravais

Read `AGENTS.md` at the repository root first — it is the authority
(Standard §5.7). `CONSTRAINTS.md` holds the long form of each numbered
constraint, and `CONTRIBUTING.md` the PR and commit conventions. This
file adds only what is specific to GitHub Copilot.

## Skills

Copilot skills for this repository live in `.github/skills/`. They are a
**vendored mirror** of [Spacecraft-Software/Construct](https://github.com/Spacecraft-Software/Construct),
pinned to the `construct` rev in `flake.lock` — the same rev Home Manager
installs into `~/.agents/skills/`, so the cloud agent and the local agents read
byte-identical skills.

**Never hand-edit a file under `.github/skills/`.** It is generated output: the
next sync silently reverts it. Change the skill in Construct instead, then
re-vendor here.

```sh
nu pkgs/sync-skills.nu           # re-vendor from the rev pinned in flake.lock
nu pkgs/sync-skills.nu --check   # report drift only — this is what CI runs
```

The `Skills Drift` workflow fails the build when the vendored tree stops
matching the pinned rev, so a stale copy cannot land. The `SKILLS` list in
`pkgs/sync-skills.nu` is the authoritative set; it is not repeated here.
