# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Nix Settings
{
  config,
  lib,
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

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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
    (final: prev: {
      # Disable failing tests for sequoia-wot
      sequoia-wot = prev.sequoia-wot.overrideAttrs (old: {
        doCheck = false;
      });
    })
  ];
}
