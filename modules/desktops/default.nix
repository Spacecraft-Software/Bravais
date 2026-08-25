# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Desktop Environments Module Entry Point
{
  imports = [
    ./gnome.nix
    ./cosmic.nix
    ./plasma.nix
    ./shared.nix
    ./niri.nix
    ./niri-unmax.nix
    ./gnome-mouse-nav.nix
    ./leftwm.nix
    ./assertions.nix
  ];
}
