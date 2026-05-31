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
    nerd-fonts.jetbrains-mono
    nerd-fonts.caskaydia-mono

    # HUD / Data Display
    (stdenv.mkDerivation {
      pname = "share-tech-mono";
      version = "1.0";
      src = fetchurl {
        url = "https://github.com/google/fonts/raw/main/ofl/sharetechmono/ShareTechMono-Regular.ttf";
        hash = "sha256-nOqx+HQUgpryWcD1N1c64D733TFHwLJ6NqGgvrZzJnc=";
      };
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/share/fonts/truetype
        cp $src $out/share/fonts/truetype/ShareTechMono-Regular.ttf
      '';
    })
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [ "Inconsolata" "CaskaydiaMono Nerd Font" "Share Tech Mono" ];
    sansSerif = [ "Noto Sans" ];
    serif = [ "Noto Sans" ];
  };
}
