# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager Configuration
{
  config,
  pkgs,
  construct,
  mcp-servers,
  vacuum,
  engram,
  unstablePkgs,
  primaryUser,
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
    ./eww.nix
    ./niri.nix
    ./desktop-theme.nix
    ./apps.nix
    # Which program handles what — the sole xdg.mimeApps block. Selection is
    # one word per role in the repo-root default-apps.nix.
    ./default-apps.nix
  ];

  # Construct skill hub — installs all cross-platform skills from
  # github:Spacecraft-Software/Construct into ~/.agents/skills/ (Nix store)
  # and symlinks each agent harness to it. Run `skills-sync` then rebuild
  # to pull the latest skill set.
  # Gemini CLI reads ~/.agents/ directly, so ".gemini/skills" stays omitted.
  # Antigravity does NOT — it scans ~/.gemini/config/skills (reached via the
  # ~/.gemini/antigravity/skills symlink), so that path must be managed here
  # or it silently keeps whatever was hand-copied into it.
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
      ".gemini/config/skills"
      ".opencode/skills"
      ".openclaude/skills"
    ];
  };

  home.username = primaryUser;
  home.homeDirectory = "/home/${primaryUser}";
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

      # `mcpctl` — generates each MCP host's config from mcp-servers/mcp.toml
      # and deploys it. User-scoped rather than system-wide because it writes
      # into $HOME (~/.claude.json and friends), not /etc.
      #
      # It was previously installed imperatively (`nix profile install`), which
      # a fresh machine would not reproduce. That copy must be removed:
      #   nix profile remove mcpctl
      # — because ~/.nix-profile/bin precedes /etc/profiles/per-user/mj/bin on
      # PATH, so the stale imperative build shadows this one until it is gone.
      # (`rebuild`'s drift probe is unaffected: it calls mcpctl by store path.)
      mcp-servers.packages.${pkgs.stdenv.hostPlatform.system}.mcpctl

      # `vacuum` — disk-space recovery CLI + TUI from the Vacuum flake input
      # (constraint #7: flake-input package consumed by attr-path, threaded via
      # extraSpecialArgs). User-scoped rather than system-wide because its
      # config is HM-managed at ~/.config/vacuum/config.toml (apps.nix) and the
      # roots that bound its deletions are $HOME-relative — binary and root-list
      # stay in one module. Vacuum's nixosModules.default is deliberately unused;
      # see the input comment in flake.nix.
      #
      # It was previously `cargo install`ed from the working tree, which a fresh
      # machine would not reproduce. Remove that copy:
      #   cargo uninstall vacuum-cli
      # (crate `vacuum-cli`, binary `vacuum`.) Unlike the mcpctl note above this
      # is hygiene, not a shadowing fix: the out-of-band dirs including
      # ~/.cargo/bin are APPENDED to PATH (outOfBandDirs in shell.nix), so this
      # store copy already wins. `vacuum --version` reporting 0.1.0-git — the
      # marker the flake sets — is how you confirm which one ran.
      vacuum.packages.${pkgs.stdenv.hostPlatform.system}.default

      # `engram` — shared verbatim chat memory, AND the `engram` MCP server.
      # This entry is what every MCP host actually spawns: mcp-servers/mcp.toml
      # resolves `command = "engram"` by BARE NAME on PATH, then runs
      # `engram --db <path> mcp` (--db is a GLOBAL flag, hence before the
      # subcommand). Until this landed that resolved to a `cargo install` build
      # of an uncommitted working tree.
      #
      # User-scoped for the same reason as mcpctl: every byte of engram's state
      # lives in $HOME — the SQLite store (see ENGRAM_DB in shell.nix) and the
      # slash-command files under ~/.claude/commands/. The upstream flake ships
      # no nixosModule, deliberately.
      #
      # Remove the imperative copy:  cargo uninstall engram
      engram.packages.${pkgs.stdenv.hostPlatform.system}.default

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
