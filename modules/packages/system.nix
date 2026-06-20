# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — System Utilities and Modern Unix Tools
{ config, lib, pkgs, unstablePkgs, ... }:

{
  options.steelbore.packages.system = {
    enable = lib.mkEnableOption "System utilities and modern Unix tools";
  };

  config = lib.mkIf config.steelbore.packages.system.enable {
    environment.systemPackages = (with pkgs; [
      # Modern Unix (Rust preferred)
      fd                         # Rust — find replacement
      ripgrep                    # Rust — grep replacement
      bat                        # Rust — cat replacement
      eza                        # Rust — ls replacement
      sd                         # Rust — sed replacement
      zoxide                     # Rust — cd replacement
      procs                      # Rust — ps replacement
      dust                       # Rust — du replacement
      dua                        # Rust — Interactive du

      # Coreutils reimplementation (Rust)
      uutils-coreutils
      uutils-diffutils
      uutils-findutils

      # File Management (Rust preferred)
      yazi                       # Rust — TUI file manager
      broot                      # Rust — Tree navigator
      superfile                  # Go — TUI file manager
      spacedrive                 # Rust — Cross-platform explorer
      fclones                    # Rust — Duplicate finder
      kondo                      # Rust — Project cleaner
      pipe-rename                # Rust — Interactive rename
      ouch                       # Rust — Archive tool

      # Disk Management (Rust preferred)
      gptman                     # Rust — GPT manager
      parted                     # C — Partition manipulation
      tparted                    # C — TUI for parted
      gparted                    # C — GUI partition editor

      # System Monitoring (Rust preferred)
      bottom                     # Rust — htop replacement
      kmon                       # Rust — Kernel manager
      macchina                   # Rust — System fetch
      bandwhich                  # Rust — Bandwidth monitor
      mission-center             # Rust — Task manager
      htop
      btop
      gotop
      fastfetch
      i7z
      hw-probe

      # Text Processing (Rust preferred)
      jaq                        # Rust — jq replacement
      teip                       # Rust — Masking tool
      htmlq                      # Rust — HTML selector
      skim                       # Rust — Fuzzy finder
      tealdeer                   # Rust — tldr client
      mdcat                      # Rust — Markdown renderer
      difftastic                 # Rust — Structural diff
      texinfo                    # C — GNU Info documentation reader
      reuse                      # Python — REUSE compliance checker (SPDX)
      hunspell                   # C — Spell checker
      hunspellDicts.en_US        # English (US) dictionary

      # Shells (Rust preferred)
      nushell                    # Rust — Modern shell
      brush                      # Rust — Bash compatible
      ion                        # Rust — Shell
      starship                   # Rust — Prompt
      atuin                      # Rust — Shell history
      pipr                       # Rust — Pipeline builder
      moor                       # Rust — Shell
      powershell

      # Multiplexers
      zellij                     # Rust — Terminal multiplexer
      screen

      # Recording
      t-rec                      # Rust — Terminal recorder

      # Containers & Virtualization
      distrobox
      host-spawn
      podman
      runc
      youki                      # Rust — OCI container runtime
      oxker                      # Rust — Docker/Podman TUI
      qemu
      flatpak
      bubblewrap

      # System Management
      topgrade                   # Rust — Universal updater
      paru                       # Rust — AUR helper
      doas
      os-prober
      kbd
      numlockx
      xremap                     # Rust — Key remapper
      input-leap

      # Archiving
      p7zip
      zip
      unzip

      # ZFS
      zfs

      # Benchmarking
      phoronix-test-suite
      perf
    ]) ++ (with unstablePkgs; [
      steam-run                  # FHS environment for running Linux binaries
    ]);

    # Podman runtimes
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;       # docker → podman drop-in alias
      extraPackages = [ pkgs.youki pkgs.runc ];
    };

    # Flatpak service
    services.flatpak.enable = true;

    # AppImage support (auto-run via binfmt)
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
