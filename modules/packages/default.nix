# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Package Modules Entry Point
{ config, lib, pkgs, ... }:

{
  imports = [
    ./browsers.nix
    ./terminals.nix
    ./editors.nix
    ./development.nix
    ./security.nix
    ./networking.nix
    ./multimedia.nix
    ./productivity.nix
    ./system.nix
    ./ai.nix
    ./flatpak.nix
    ./homebrew.nix
  ];
}
