# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Typography Configuration
{ config, lib, pkgs, ... }:

{
  fonts.packages = with pkgs; [
    # UI / General — CommitMono (Nerd Font patched)
    nerd-fonts.commit-mono

    # Code / Terminal — Inconsolata (Nerd Font patched)
    nerd-fonts.inconsolata

    # Nerd Fonts (icons fallback)
    nerd-fonts.caskaydia-mono

    # Symbol-only Nerd Font — required by Rio for icon glyph fallback
    nerd-fonts.symbols-only
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [ "Inconsolata Nerd Font" "CaskaydiaMono Nerd Font" ];
    sansSerif = [ "CommitMono Nerd Font" ];
    serif = [ "CommitMono Nerd Font" ];
  };
}
