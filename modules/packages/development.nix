# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Development Tools and Languages
{ config, lib, pkgs, ... }:

{
  options.steelbore.packages.development = {
    enable = lib.mkEnableOption "Development tools and languages";
  };

  config = lib.mkIf config.steelbore.packages.development.enable {
    environment.systemPackages = with pkgs; [
      # Git & Version Control (Rust preferred)
      git
      gitui                      # Rust — TUI for Git
      delta                      # Rust — Syntax-highlighting pager
      jujutsu                    # Rust — Git-compatible VCS (jj)
      gh                         # Go — GitHub CLI
      github-desktop

      # Forgejo (self-hosted Git)
      forgejo                    # Go — Git server
      forgejo-cli                # Rust — Forgejo CLI
      forgejo-runner             # Go — CI runner

      # C/C++ Toolchain
      gcc                        # C — GNU Compiler Collection

      # Rust Toolchain
      # rustup is the toolchain manager; install it via:
      #   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
      # Then add components:
      #   rustup component add rustfmt clippy
      cargo
      cargo-update

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
      azure-cli                  # Python — Azure CLI
      awscli                     # Python — AWS CLI

      # Languages
      jdk
      php
      python3                    # Python runtime
      python3Packages.pip        # Python package installer
      nodejs                     # JavaScript runtime (Node 24 LTS — provides node/npm/npx)

      # Nix Ecosystem
      nixfmt                     # Rust — Nix formatter
      cachix
      nix
      guix
      emacsPackages.guix
    ];

    # nix-ld: dynamic linker shim for unpatched binaries (npm packages, Python
    # wheels with native extensions, VS Code server, pre-built toolchains, etc.)
    programs.nix-ld.enable = true;

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
