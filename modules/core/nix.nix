# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Nix Settings
{
  pkgs,
  ...
}:

{
  # Enable flakes and nix-command
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Hardlink-deduplicate identical files in /nix/store. Costs a small
  # amount of CPU on every store add (and on the periodic optimise
  # service), saves disk on / which sits at 88 % full on this host.
  nix.settings.auto-optimise-store = true;

  # Silence the "Git tree '…' is dirty" warning that Nix prints on every
  # flake evaluation when this repo has uncommitted changes (the normal
  # state while iterating on the config before a rebuild).
  nix.settings.warn-dirty = false;

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Flake-only: the flake (nixos-26.05) is the single source of truth. `<nixpkgs>`
  # and the `nixpkgs` registry entry stay pinned to the flake's nixpkgs via
  # nixpkgs.flake.setNixPath / setFlakeRegistry (both default true on flake
  # systems), so `nix-shell -p` and `nix shell nixpkgs#…` track 26.05. This stops
  # `nix-channel` and retires the stale imperative nixos-25.11 channel, which was
  # independent of the flake and only ever fetched the wrong release.
  nix.channel.enable = false;

  # Allow unfree packages.
  nixpkgs.config.allowUnfree = true;

  # envfs — FUSE filesystem that provides /usr/bin/env so shebang scripts
  # (#!/usr/bin/env python3, etc.) work out of the box on NixOS.
  services.envfs.enable = true;

  # nix-ld — run unpatched dynamic binaries on NixOS by providing a
  # loader and common libraries that FHS binaries expect at build time.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    zlib
    openssl
    stdenv.cc.cc.lib
  ];

  # Overlays
  # The claude-code overlay was dropped — claude-code now comes from
  # nixpkgs-unstable via specialArgs (see flake.nix mkBravais and
  # modules/packages/ai.nix). Unstable already tracks recent npm
  # releases without our manual pin.
  nixpkgs.overlays = [
    (_final: prev: {
      # Disable failing tests for sequoia-wot
      sequoia-wot = prev.sequoia-wot.overrideAttrs (_old: {
        doCheck = false;
      });

      # 3-finger touchpad swipe switches workspaces under COSMIC.
      #
      # niri binds 3 fingers to workspace switching and 4 to the Overview;
      # cosmic-comp binds 4 to workspace switching and 3 to nothing at all:
      #
      #   activate_action = match gesture_state.fingers {
      #       3 => None, // TODO: 3 finger gestures
      #       4 => { ... NextWorkspace / PrevWorkspace ... }
      #
      # Unifying on 3 rather than 4 is the direction that loses nothing. Moving
      # niri to 4 would collide with its Overview gesture, and niri exposes no
      # finger-count config either (`gestures {}` has only dnd-edge-view-scroll,
      # dnd-edge-workspace-switch and hot-corners) — so that would ALSO be a
      # source patch, of a compositor whose 4-finger arm is already doing
      # something useful. cosmic-comp's 3-finger arm is a literal upstream TODO.
      #
      # This makes 3 share the 4 arm rather than replacing it, so 4 keeps
      # working on COSMIC and no muscle memory is invalidated. Nothing else in
      # cosmic-comp branches on finger count for an action (verified: the only
      # other sites are `event.fingers() >= 3`, which already admits 3-finger
      # gestures, and pass-throughs to the pointer), and `SwipeAction` has
      # exactly two variants, so there is no gesture for 3 fingers to steal.
      #
      # COST: this forces cosmic-comp to build from source, losing the binary
      # cache for a large Rust package. That is the whole price of the feature;
      # there is no configuration path to it.
      #
      # Two SINGLE-LINE substitutions, not one multi-line pattern: both target
      # lines are unique in the file (verified), and a multi-line --replace-fail
      # would depend on substituteInPlace's newline handling for no benefit.
      # Deleting the `3 => None` arm is safe because the match already ends in a
      # catch-all `_ => None`, so exhaustiveness holds either way; adding 3 to
      # the 4 arm is what actually gives it the action. The order matters — the
      # 3 arm must go first, or `3 | 4` would sit after a live `3 =>` arm and
      # never be reached.
      #
      # `--replace-fail` is deliberate: if upstream ever fills in the TODO, the
      # substitution stops matching and the build FAILS loudly instead of
      # silently reverting to 4-finger-only.
      cosmic-comp = prev.cosmic-comp.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/input/mod.rs \
            --replace-fail "3 => None, // TODO: 3 finger gestures" "" \
            --replace-fail "4 => {" "3 | 4 => {"
        '';
      });

      # Silence the "nixfmt-rfc-style is now the same as pkgs.nixfmt" alias
      # warning (nixpkgs 26.05, aliases.nix:1555). `nixfmt-rfc-style` is a
      # `lib.warnOnInstantiate` wrapper around `nixfmt`; any access prints
      # the warning. Bravais uses the canonical `nixfmt` attr everywhere
      # (flake.nix formatter/devShell + development.nix), but a flake input
      # (gitway, following nixpkgs-unstable) still references the old name.
      # This overlay replaces the warned alias with a direct pointer so the
      # warning never fires.
      nixfmt-rfc-style = prev.nixfmt;
    })
  ];
}
