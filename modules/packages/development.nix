# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Development Tools and Languages
{
  config,
  lib,
  pkgs,
  unstablePkgs,
  nil,
  steelboreApps,
  ...
}:

{
  options.steelbore.packages.development = {
    enable = lib.mkEnableOption "Development tools and languages";
  };

  config = lib.mkIf config.steelbore.packages.development.enable {
    environment.systemPackages =
      (with pkgs; [
        # Git & Version Control (Rust preferred)
        git
        gitui # Rust — TUI for Git
        delta # Rust — Syntax-highlighting pager
        jujutsu # Rust — Git-compatible VCS (jj)
        gh # Go — GitHub CLI
        # github-desktop → Flatpak: io.github.shiftey.Desktop (already declared)

        # Forgejo (self-hosted Git)
        forgejo # Go — Git server
        forgejo-cli # Rust — Forgejo CLI
        forgejo-runner # Go — CI runner

        # C/C++ Toolchain
        gcc # C — GNU Compiler Collection
        # WebKitGTK, both ABIs in parallel. Every library, SONAME and typelib is
        # version-suffixed (libwebkit2gtk-4.1.so.0 / WebKit2-4.1.typelib vs
        # libwebkitgtk-6.0.so.4 / WebKit-6.0.typelib), so the two do not conflict —
        # only the unversioned `bin/WebKitWebDriver` is shared. lowPrio settles that
        # one file on 4.1 (the ABI github-copilot-app's Tauri runtime links against).
        # Without it the winner is decided by list order, and a strict buildEnv —
        # e.g. home.packages, which unlike environment.systemPackages does not set
        # ignoreCollisions — fails outright. Same reason as the gnat lowPrio above.
        webkitgtk_4_1 # C/C++ — WebKitGTK for GTK3 (libwebkit2gtk-4.1)
        (lib.lowPrio webkitgtk_6_0) # C/C++ — WebKitGTK for GTK4 (libwebkitgtk-6.0)

        # Ada Toolchain — lowPrio so GNAT's bundled gcc/cpp/cc/g++ yield to the
        # primary `gcc` above on buildEnv collision; gnat/gnatmake/etc. still link.
        # gnat16-or-gnat fallback (CLAUDE.md constraint #5): the pinned unstable
        # channel tops out at gnat15, so a bare gnat16 broke the
        # bravais-thinkpad-unstable eval; `gnat` is the channel's default GNAT.
        (lib.lowPrio (pkgs.gnat16 or pkgs.gnat)) # Ada — GNAT (GCC Ada) compiler

        # Rust Toolchain — managed via Home Manager (unstablePkgs): rustup +
        # cargo subcommands. rustup proxies rustc/cargo/rustfmt/clippy/rust-analyzer
        # as shim binaries, so those must not be declared separately in Nix.

        # Build & Task Tools (Rust preferred)
        just # Rust — Command runner
        sad # Rust — Batch search & replace
        pueue # Rust — Task management daemon
        tokei # Rust — Code statistics

        # Environment Management
        lorri # Rust — Nix env daemon
        dotter # Rust — Dotfile manager

        # Cloud CLIs
        google-cloud-sdk # Python — Google Cloud SDK
        # azure-cli                  # Python — Azure CLI — massive dependency tree, slow to fetch from cache
        awscli # Python — AWS CLI

        # Languages
        guile # Scheme — GNU extension language
        guile-json # Scheme — JSON reader/writer library for Guile
        jdk
        php
        python3 # Python runtime
        python3Packages.pip # Python package installer
        nodejs # JavaScript runtime (Node 24 LTS — provides node/npm/npx)

        # Nix Ecosystem
        nil.packages.${pkgs.stdenv.hostPlatform.system}.default # Rust — Nix LSP (from flake input)
        nixfmt # Rust — Nix formatter
        cachix
        nix
        nix-prefetch-github # Haskell — Prefetch GitHub sources for Nix
        # guix
        # emacsPackages.guix
      ])
      ++ (with unstablePkgs; [
        uv # Rust — Python package + project manager
      ]);

    # Git configuration
    programs.git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
        # Same registry entry as $EDITOR (users/mj/shell.nix), so `git commit`
        # and the shell agree. Change: app set termEditor <slug>
        core.editor = steelboreApps.roles.termEditor.exec pkgs;
        color.ui = true;
      };
    };
  };
}
