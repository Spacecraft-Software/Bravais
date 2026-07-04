# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager Configuration
{
  config,
  pkgs,
  construct,
  unstablePkgs,
  ...
}:

{
  imports = [
    construct.homeManagerModules.default
    # Phase D split (elegance plan 3.1) — one concern per file; zero
    # behavior change (verified via unchanged toplevel store path).
    ./git.nix
    ./shell.nix
    ./terminals.nix
    ./niri.nix
    ./desktop-theme.nix
    ./apps.nix
  ];

  # Construct skill hub — installs all cross-platform skills from
  # github:Spacecraft-Software/Construct into ~/.agents/skills/ (Nix store)
  # and symlinks each agent harness to it. Run `skills-sync` then rebuild
  # to pull the latest skill set.
  # .gemini intentionally omitted — Gemini reads ~/.agents/ directly.
  spacecraft.construct = {
    enable = true;
    enableGrok = true;
    agentPaths = [
      ".agent/skills"
      ".ai/skills"
      ".aichat/skills"
      ".claude/skills"
      ".codex/skills"
      ".copilot/skills"
      ".opencode/skills"
    ];
  };

  home.username = "mj";
  home.homeDirectory = "/home/mj";
  home.stateVersion = "26.05";

  # Rust toolchain — rustup manages rustc/cargo/rustfmt/clippy itself.
  # Installing standalone cargo/rustc alongside rustup causes a buildEnv
  # conflict (both ship _cargo zsh completions). After rebuild run:
  #   rustup install stable && rustup default stable

  # Rust toolchain — rustup manages rustc/cargo/rustfmt/clippy itself.
  # Installing standalone cargo/rustc alongside rustup causes a buildEnv
  # conflict (both ship _cargo zsh completions). After rebuild run:
  #   rustup install stable && rustup default stable
  home.packages =
    (with unstablePkgs; [
      rustup # manages rustc/cargo/rustfmt/clippy/rust-analyzer as components
      cargo-update # cargo install-update subcommand
      cargo-watch
      cargo-nextest
      cargo-audit
      sccache
      cargo-expand
    ])
    ++ [
      # `construct` skills CLI from the Construct flake input (constraint #7:
      # flake-input package consumed by attr-path, threaded via extraSpecialArgs).
      construct.packages.${pkgs.stdenv.hostPlatform.system}.construct

      # Run a heavy build inside a memory-capped, killable systemd scope so a runaway
      # cargo/rustc is contained (and OOM-killed within its own cgroup) instead of
      # competing with — and taking down — the editor/multiplexer session.
      # Usage: cargo-capped test -p <crate>
      (pkgs.writeShellScriptBin "cargo-capped" ''
        exec systemd-run --user --scope --quiet \
          -p MemoryMax=24G -p MemorySwapMax=8G -- cargo "$@"
      '')
    ];

  home.file = {
    # Steelbore project symlink
    "steelbore".source = config.lib.file.mkOutOfStoreSymlink "/spacecraft-software";

  };

  # Keyboard layout
  home.keyboard = {
    layout = "us,ara";
    options = [ "grp:ctrl_space_toggle" ];
  };
}
