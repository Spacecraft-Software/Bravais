# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Desktop Environments Module Entry Point
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./gnome.nix
    ./cosmic.nix
    ./plasma.nix
    ./niri.nix
    ./leftwm.nix
  ];
}
