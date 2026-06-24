# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Typography Configuration
{
  config,
  lib,
  pkgs,
  ...
}:

{
  fonts.packages = with pkgs; [
    # UI / General — Hack (Nerd Font patched)
    nerd-fonts.hack

    # Code / Terminal — JetBrains Mono (Nerd Font patched)
    nerd-fonts.jetbrains-mono

    # Nerd Fonts (icons fallback)
    nerd-fonts.caskaydia-mono

    # Symbol-only Nerd Font — required by Rio for icon glyph fallback
    nerd-fonts.symbols-only
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [
      "JetBrainsMono Nerd Font"
      "CaskaydiaMono Nerd Font"
    ];
    sansSerif = [ "Hack Nerd Font" ];
    serif = [ "Hack Nerd Font" ];
  };
}
