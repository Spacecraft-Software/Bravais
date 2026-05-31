# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Typography Configuration
{ config, lib, pkgs, ... }:

{
  fonts.packages = with pkgs; [
    # UI / General
    noto-fonts

    # Code / Terminal
    inconsolata

    # Nerd Fonts (icons)
    nerd-fonts.caskaydia-mono
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [ "Inconsolata" "CaskaydiaMono Nerd Font" ];
    sansSerif = [ "Noto Sans" ];
    serif = [ "Noto Sans" ];
  };
}
