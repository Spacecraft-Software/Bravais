# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Multimedia Players and Processing Tools
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.steelbore.packages.multimedia = {
    enable = lib.mkEnableOption "Multimedia players and processing tools";
  };

  config = lib.mkIf config.steelbore.packages.multimedia.enable {
    environment.systemPackages = with pkgs; [
      # Video Players
      mpv
      # vlc → Flatpak: org.videolan.VLC (large source build on march configs)
      cosmic-player # Rust — COSMIC player

      # Audio Players (Rust preferred)
      amberol # Rust — Local music
      termusic # Rust — TUI music
      ncspot # Rust — Spotify TUI
      psst # Rust — Spotify GUI
      shortwave # Rust — Internet radio

      # Image Viewers (Rust preferred)
      loupe # Rust — Image viewer
      viu # Rust — CLI image viewer
      emulsion # Rust — Image viewer
      oculante # Rust — Image viewer with editing tools

      # Audio Recognition
      mousai # Rust — Song identification

      # Audio Mixers / Output Switchers (PipeWire; Niri has no audio applet)
      wiremix # Rust — TUI PipeWire mixer (switch sinks, move streams)
      pavucontrol # GTK — GUI volume / output-device control

      # Processing (Rust preferred)
      rav1e # Rust — AV1 encoder
      gifski # Rust — GIF encoder
      oxipng # Rust — PNG optimizer
      video-trimmer # Rust — Video trimmer
      ffmpeg

      # Downloaders
      yt-dlp
    ];
  };
}
