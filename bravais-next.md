<!--
SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
SPDX-License-Identifier: CC-BY-SA-4.0
-->
<!-- GFM Document
     title:      Bravais Next — Flake Evolution Roadmap
     author:     Mohamed Hammad & Spacecraft Software
     date:       2026-06-24
     version:    r1
     license:    CC-BY-SA-4.0
     project:    Bravais
     website:    https://Bravais.SpacecraftSoftware.org/
-->
<!-- GFM companion to the canonical source bravais-next.texi.
     The .texi is authoritative; this .md is kept content-identical. -->

# Bravais Next — Flake Evolution Roadmap

**Author:** Mohamed Hammad & Spacecraft Software \
**Maintainer:** Mohamed Hammad — <Mohamed.Hammad@SpacecraftSoftware.org> \
**Date:** 2026-06-24 (revision r1) \
**License:** CC-BY-SA-4.0 \
**Website:** <https://Bravais.SpacecraftSoftware.org/>

This document evaluates the external *Bravais Nix Flake Structure Improvement Plan* (an HTML
report dated 2026-06-17) against the **actual** state of the Bravais flake, and distils the
result into a prioritised, go-forward roadmap. The canonical source is `bravais-next.texi`;
this Markdown file is its GFM companion.

## Table of Contents

- [Introduction](#introduction)
- [Method](#method)
- [Repository State](#repository-state)
- [Corrections](#corrections)
- [Evaluation](#evaluation)
- [Roadmap](#roadmap)
- [Quick Wins](#quick-wins)


## Introduction

The proposal makes sixteen structural recommendations (a thin `flake.nix`, a generated CPU/channel
matrix, exported modules, a profiles layer, a package catalogue, and more). Several are sound.
Others are built on a **stale or speculative snapshot** of the repository and do not match what is
on disk today.

The cardinal finding: *the source proposal must not be relayed uncritically.* This document
classifies every suggestion as **adopt**, **adopt with modification**, **defer**, or **reject**,
with the reasoning grounded in concrete file references, and then orders the survivors by value
and risk.


## Method

Each suggestion was checked by reading the live tree — `flake.nix`, `modules/`, `hosts/`,
`users/`, `overlays/`, and `README.md` — rather than trusting the proposal's description of it.

The weighting follows The Steelbore Standard priority hierarchy (§3): **stability and correctness
rank first**. A change that removes a latent bug, a drift trap, or an ambiguity outranks a change
whose only payoff is speculative reuse by a hypothetical future distribution. A single-machine
personal configuration does not pay the carrying cost of abstractions that only amortise across
many machines or many consumers.

Verdicts use four levels:

- **Adopt** — valid and worth doing; low risk.
- **Adopt (modified)** — the underlying problem is real, but the fix is lighter or differently
  shaped than the proposal's.
- **Defer** — sound in principle, but the trigger condition (a second machine, real external reuse,
  painful drift) has not arrived.
- **Reject** — contradicts a deliberate design decision, or rests on a factual error.


## Repository State

The following facts were confirmed by direct reading and anchor every verdict in
[Evaluation](#evaluation).

- `flake.nix` is 182 lines and already lean; `mkBravais` is a 57-line inline function (it does
  *not* need extracting into `lib/`).
- The configuration outputs are `bravais-thinkpad`, `bravais-thinkpad-unstable`, and the `bravais`
  alias. There is **no** `bravais-v1`…`v4` matrix; the x86-64 march level is **pinned per host**
  (the ThinkPad's i7-8665U is `v3`).
- The stable channel is `nixos-26.05`; `kimi-cli` is commented out, not an active input.
- `users.users.mj` is **duplicated**: the active definition is in `hosts/common.nix` (and includes
  the `seat` group), while `users/mj/default.nix` holds a dead, unimported copy that has drifted
  (it is missing `seat`).
- `modules/packages/system.nix` mixes pure packages with services and compatibility layers —
  `virtualisation.podman`, `programs.appimage`, and `services.flatpak.enable`. The Flatpak service
  is **double-declared**: `modules/packages/flatpak.nix` already owns it, properly gated behind its
  own toggle.
- The flake exposes only `nixosConfigurations`. There are no `formatter`, `devShells`, `checks`,
  `nixosModules`, or `overlays` outputs.
- The Steelbore palette is duplicated: an inline `steelborePalette` in `flake.nix` and an unused
  copy in `lib/default.nix`, with a naming drift (`liquidCool` in the repo versus `liquidCoolant`
  in the proposal).
- `README.md` carries a hand-maintained package table (185 packages, 57.8% Rust-first) that will
  drift as the inventory changes.


## Corrections

Three of the proposal's load-bearing premises are simply out of date. They are recorded here so the
report is not mistaken for an endorsement of them.

1. **Channel.** The proposal's example `flake.nix` pins `nixos-25.11` and lists `kimi-cli` as an
   input. The repository tracks `nixos-26.05`, and `kimi-cli` is commented out.
2. **CPU matrix.** The proposal's flagship recommendation generates `bravais-v1`…`v4` per channel
   from a matrix function. No such outputs exist; march is pinned per host by deliberate design.
3. **Thin flake.** The proposal argues for shrinking `flake.nix` by moving `mkBravais` into `lib/`.
   The flake is already small and auditable; the move would add indirection without removing weight.


## Evaluation

The verdicts, keyed to the section numbers in the source proposal:

| Pr. | Suggestion                                          | Verdict                    | Why                                                                                  |
|-----|-----------------------------------------------------|----------------------------|--------------------------------------------------------------------------------------|
| §6  | Generate a CPU v1–v4 / channel matrix               | **Reject**                 | Contradicts a deliberate design — no v1–v4 outputs; march pinned per host.           |
| §5  | Make `flake.nix` thin (move `mkBravais` to `lib/`)  | **Reject**                 | Already lean (182 lines); example uses the stale 25.11 + `kimi-cli`.                 |
| §15 | Formatter / dev shell / checks                      | **Adopt now**              | Absent, cheap, high value; fix bogus `v1`/`v4` check refs.                           |
| §12 | Centralise user + Home Manager                      | **Adopt now**              | Real duplication and drift trap.                                                     |
| §13 | Split packages / services / compat                  | **Adopt**                  | Real mixing; the Flatpak double-declare is a latent decoupling bug.                  |
| §9  | Centralise the palette                              | **Adopt (modified)**       | Real duplication + naming drift; single-source it, drop the module-option weight.    |
| §8  | Split hardware (vendor) from platform (ISA flags)   | **Adopt (modified)**       | `intel.nix` genuinely mixes microcode with march/`RUSTFLAGS`; keep march pinned.     |
| §11 | Desktop primary/extras + assertions                 | **Adopt (assertions only)**| Kitchen-sink is intentional; add guard assertions, do not force exclusivity.         |
| §10 | Profiles layer                                      | **Defer**                  | Host is already lean; `common.nix` already serves as the profile.                    |
| §7  | Export modules / overlays                           | **Defer**                  | Only worth it for real external reuse; modules are tightly coupled.                  |
| §14 | Package catalogue + generated docs                  | **Defer**                  | Stats will drift, but a full catalogue for 185 packages is heavy; a script is lighter.|
| §4  | Full directory reorganisation                       | **Defer (partial)**        | Heavy for a single-machine personal config; adopt sub-parts individually.            |

The proposal's strengths are real and worth affirming: it correctly identifies the
hardware/platform conflation, the kitchen-sink desktop model, the package/service mixing, and the
hand-maintained statistics as genuine issues. The disagreement is about which fixes are
proportionate to a personal, single-machine distribution — and about the factual premises in
[Corrections](#corrections).


## Roadmap

The survivors, ordered by value and risk.

### Tier 1 — Adopt now

Low-risk, high-value changes applied in the same pass as this document (see
[Quick Wins](#quick-wins) for the mechanics):

- Add `formatter`, `devShells`, and `checks` flake outputs, with the checks referencing the *real*
  `bravais-thinkpad` and `bravais-thinkpad-unstable` configurations.
- De-duplicate the `mj` user account into a single owning module.
- Remove the redundant Flatpak service declaration so Flatpak has one owner.

### Tier 2 — Adopt soon

Sound improvements of moderate effort, queued behind Tier 1:

- **Single-source the palette.** Make `flake.nix` import one canonical colour definition and delete
  the unused, drifted copy in `lib/default.nix`. This is the *lightweight* form of proposal §9 — a
  data file, not a module option read through `config`.
- **Split hardware from platform (§8).** Separate CPU-vendor settings (`kvm-intel`, microcode) from
  x86-64 ISA / compiler-flag policy (`marchLevel`, `RUSTFLAGS`, LTO) so an AMD machine would not
  require rewriting the whole module. The march level stays **pinned per host**.
- **Desktop guard assertions (§11).** Keep all desktops enableable, but add assertions and
  documentation around the X11/Wayland interplay (LeftWM unconditionally enables X11 today, with no
  guard).
- **Relocate services/compat out of `system.nix` (§13).** Move `virtualisation.podman` and
  `programs.appimage` into dedicated service/compat modules so a `packages` module installs packages
  only.

### Tier 3 — Defer

Each of these is reasonable *once a trigger arrives*:

- **Profiles layer (§10)** — trigger: a second machine, or a meaningfully different system
  personality.
- **Export modules and overlays (§7)** — trigger: a real external consumer of the Bravais modules.
- **Generated package report (§14)** — trigger: the hand-maintained statistics become painful to
  keep accurate; a small count script is the cheaper first step before a full catalogue.
- **Broad directory reorganisation (§4)** — trigger: Tier 2 and the deferred items converge on it;
  otherwise the churn is not justified.

### Rejected

- **CPU v1–v4 matrix (§6)** — contradicts the per-host march pin, a documented and deliberate
  decision.
- **Thin-flake extraction (§5)** — the flake is already lean; the premise rests on the stale
  snapshot.


## Quick Wins

The three Tier 1 changes, as applied.

### Flake quality outputs

Added to the output set of `flake.nix`, reusing the existing `system` binding and `self`. The
formatter is `nixfmt` (now the canonical RFC-style formatter attribute on 26.05); the checks point
at the real configurations, not the proposal's non-existent `bravais-v1`/`v4`:

```nix
formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;

devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
  packages = with nixpkgs.legacyPackages.${system}; [ nil nixfmt statix deadnix ];
};

checks.${system} = {
  bravais-thinkpad          = self.nixosConfigurations.bravais-thinkpad.config.system.build.toplevel;
  bravais-thinkpad-unstable = self.nixosConfigurations.bravais-thinkpad-unstable.config.system.build.toplevel;
};
```

This makes `nix fmt`, `nix flake check`, and `nix develop` work out of the box.

### User-account de-duplication

The `mj` account now has a single owner. `users/mj/default.nix` (documented as the system user
definition) gains the `seat` group it was missing, is wired into the `mkBravais` module list, and
the duplicate block is removed from `hosts/common.nix` (its `root` shell and `environment.shells`
lines stay). The dead, drifted copy is no longer a trap.

### Flatpak single owner

The redundant `services.flatpak.enable = true` is removed from `modules/packages/system.nix`.
`modules/packages/flatpak.nix` already enables the service, its remotes, and its package list behind
`steelbore.packages.flatpak.enable`. With both toggles on (the default), behaviour is unchanged;
with the Flatpak toggle off, Flatpak now actually turns off. The `podman` and `appimage` blocks are
left in place — their relocation is Tier 2 work, not a quick win.

---

*— Built by [Spacecraft Software](https://SpacecraftSoftware.org/) — companion to `bravais-next.texi` —*
