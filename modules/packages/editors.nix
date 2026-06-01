# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Text Editors and IDEs
{ config, lib, pkgs, unstablePkgs, ... }:

{
  options.steelbore.packages.editors = {
    enable = lib.mkEnableOption "Text editors and IDEs";
  };

  config = lib.mkIf config.steelbore.packages.editors.enable {
    environment.systemPackages = (with pkgs; [
      # Linting
      markdownlint-cli2           # Markdown linter

      # TUI Editors (Rust preferred)
      helix                      # Rust — Modal editor
      amp                        # Rust — Vim-like
      msedit                     # Rust — MS-DOS style

      # TUI Editors (Standard)
      neovim
      vim
      mg                         # Micro Emacs
      zile                       # Lightweight Emacs clone
      zee                        # Rust — Minimal terminal editor
      mc                         # Midnight Commander

      # GUI Editors (Rust preferred)
      lapce                      # Rust — Lightning fast
      neovide                    # Rust — Neovim GUI
      cosmic-edit                # Rust — COSMIC editor

      # GUI Editors (Standard)
      emacs-pgtk
      gedit
    ]) ++ (with unstablePkgs; [
      # GUI Editors (Unstable — FHS variants)
      code-cursor-fhs            # Cursor AI editor
      kiro-fhs                   # Kiro editor
      vscode-fhs                 # VSCode
      zed-editor-fhs             # Zed editor
    ]);
  };
}
