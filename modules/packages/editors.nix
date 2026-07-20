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

let
  agyPkgs = antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system};

  # Chromium picks its credential backend from XDG_CURRENT_DESKTOP. Under Niri
  # and LeftWM that reads "niri"/"leftwm", which Chromium maps to DE_OTHER — so
  # it skips the Secret Service and falls back to plaintext storage, surfacing
  # as "An OS keyring couldn't be identified…" in Cursor and friends. The
  # keyring daemon itself is fine (see modules/core/keyring.nix); only the
  # auto-detection fails, so name the backend explicitly.
  #
  # Wrapping keeps each package's own .desktop file working: their Exec lines
  # are bare command names (`Exec=cursor %F`), resolved through PATH, so the
  # wrapper in $out/bin shadows the original.
  withKeyring =
    bins: pkg:
    pkgs.symlinkJoin {
      name = "${lib.getName pkg}-keyring";
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = lib.concatMapStringsSep "\n" (bin: ''
        wrapProgram $out/bin/${bin} \
          --add-flags "${config.steelbore.keyring.chromiumFlag}"
      '') bins;
    };
in
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
      ++ [
        # GUI Editors (Unstable — FHS variants). Electron apps: keyring-wrapped.
        (withKeyring [ "cursor" ] unstablePkgs.code-cursor-fhs) # Cursor AI editor
        (withKeyring [ "kiro" ] unstablePkgs.kiro-fhs) # Kiro editor
        # vscode-fhs → Flatpak: com.visualstudio.code

        # Antigravity 2.0 Desktop app — the standalone, agent-orchestration
        # app (antigravity-hub), distinct from the IDE below. No IDE required.
        (withKeyring [ "antigravity" ] agyPkgs.google-antigravity-desktop)

        # Antigravity IDE only — the `agy` CLI is installed out-of-band via the
        # upstream install script and must NOT come from Nix. Use the IDE-only
        # package (not -with-cli) so the two stay separate.
        (withKeyring [ "antigravity-ide" ] agyPkgs.google-antigravity-ide)
      ];
  };
}
