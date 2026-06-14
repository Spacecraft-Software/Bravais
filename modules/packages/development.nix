# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Development Tools and Languages
{ config, lib, pkgs, unstablePkgs, ... }:

{
  options.steelbore.packages.development = {
    enable = lib.mkEnableOption "Development tools and languages";
  };

  config = lib.mkIf config.steelbore.packages.development.enable {
    environment.systemPackages = (with pkgs; [
      # Git & Version Control (Rust preferred)
      git
      gitui                      # Rust — TUI for Git
      delta                      # Rust — Syntax-highlighting pager
      jujutsu                    # Rust — Git-compatible VCS (jj)
      gh                         # Go — GitHub CLI
      # github-desktop → Flatpak: io.github.shiftey.Desktop (already declared)

      # Forgejo (self-hosted Git)
      forgejo                    # Go — Git server
      forgejo-cli                # Rust — Forgejo CLI
      forgejo-runner             # Go — CI runner

      # C/C++ Toolchain
      gcc                        # C — GNU Compiler Collection

      # Rust Toolchain — managed via Home Manager (unstablePkgs): rustup +
      # cargo subcommands. rustup proxies rustc/cargo/rustfmt/clippy/rust-analyzer
      # as shim binaries, so those must not be declared separately in Nix.

      # Build & Task Tools (Rust preferred)
      just                       # Rust — Command runner
      sad                        # Rust — Batch search & replace
      pueue                      # Rust — Task management daemon
      tokei                      # Rust — Code statistics

      # Environment Management
      lorri                      # Rust — Nix env daemon
      dotter                     # Rust — Dotfile manager

      # Cloud CLIs
      google-cloud-sdk           # Python — Google Cloud SDK
      # azure-cli                  # Python — Azure CLI — massive dependency tree, slow to fetch from cache
      awscli                     # Python — AWS CLI

      # Languages
      guile                      # Scheme — GNU extension language
      jdk
      php
      python3                    # Python runtime
      python3Packages.pip        # Python package installer
      nodejs                     # JavaScript runtime (Node 24 LTS — provides node/npm/npx)

      # Nix Ecosystem
      nixfmt                     # Rust — Nix formatter
      cachix
      nix
      nix-prefetch-github        # Haskell — Prefetch GitHub sources for Nix
      # guix
      # emacsPackages.guix
    ]) ++ (with unstablePkgs; [
      uv                         # Rust — Python package + project manager
    ]);

    # Git configuration
    programs.git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
        core.editor = "${pkgs.msedit}/bin/edit";
        color.ui = true;
      };
    };
  };
}
