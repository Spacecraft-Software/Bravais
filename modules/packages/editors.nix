# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Text Editors and IDEs
{
  config,
  lib,
  pkgs,
  unstablePkgs,
  antigravity-nix,
  ...
}:

{
  options.steelbore.packages.editors = {
    enable = lib.mkEnableOption "Text editors and IDEs";
  };

  config = lib.mkIf config.steelbore.packages.editors.enable {
    environment.systemPackages =
      (with pkgs; [
        # Linting
        markdownlint-cli2 # Markdown linter

        # TUI Editors (Rust preferred)
        helix # Rust — Modal editor
        amp # Rust — Vim-like
        msedit # Rust — MS-DOS style

        # TUI Editors (Standard)
        neovim
        vim
        mg # Micro Emacs
        zile # Lightweight Emacs clone
        zee # Rust — Minimal terminal editor
        mc # Midnight Commander

        # GUI Editors (Rust preferred)
        zed-editor # Rust — GPU-accelerated editor
        lapce # Rust — Lightning fast
        neovide # Rust — Neovim GUI
        cosmic-edit # Rust — COSMIC editor
        cosmic-files # Rust — COSMIC file manager

        # GUI Editors (Standard)
        emacs-pgtk # Emacs with pure GTK backend (Wayland-native)
        gedit
      ])
      ++ (with unstablePkgs; [
        # GUI Editors (Unstable — FHS variants)
        code-cursor-fhs # Cursor AI editor
        kiro-fhs # Kiro editor
        # vscode-fhs → Flatpak: com.visualstudio.code
      ])
      ++ [
        # Antigravity 2.0 Desktop app — the standalone, agent-orchestration
        # app (antigravity-hub), distinct from the IDE below. No IDE required.
        antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-desktop

        # Antigravity IDE only — the `agy` CLI is installed out-of-band via the
        # upstream install script and must NOT come from Nix. Use the IDE-only
        # package (not -with-cli) so the two stay separate.
        antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide
      ];
  };
}
