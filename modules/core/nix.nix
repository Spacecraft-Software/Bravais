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

  # Allow unfree packages
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
    })
  ];
}
