# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager Configuration
{
  config,
  lib,
  pkgs,
  construct,
  constructSkills,
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
    ./editor-themes.nix
    # Plasma's clock keys + plasma-localerc formats (24h, ISO 8601). Separate
    # from desktop-theme.nix because it writes through kwriteconfig6 rather
    # than xdg.configFile — see the header comment there for why.
    ./plasma.nix
    ./apps.nix
    # Which program handles what — the sole xdg.mimeApps block. Selection is
    # one word per role in the repo-root default-apps.nix.
    ./default-apps.nix
  ];

  # Construct skill hub — installs all cross-platform skills from
  # github:Spacecraft-Software/Construct and wires each agent harness to that
  # hub per `agentPaths` below: one link per skill, or nothing at all.
  #
  # Under mutablePointer every per-skill link there resolves through
  # ~/.local/state/construct/current rather than straight into the store, so
  # `skills-sync` applies a new skill set in seconds with no rebuild and no
  # sudo. A rebuild still resets the pointer to whatever flake.lock pins;
  # `skills-status` (`construct skill status`) reports when it has moved ahead.
  #
  # Gemini CLI reads ~/.agents/ directly, so ".gemini/skills" stays omitted.
  # Antigravity does NOT — it scans ~/.gemini/config/skills (reached via the
  # ~/.gemini/antigravity/skills symlink), so that path must be managed here
  # or it silently keeps whatever was hand-copied into it.
  spacecraft.construct = {
    enable = true;
    enableGrok = true;
    mutablePointer.enable = true;

    # ~/.agents/skills is a real directory of per-skill symlinks, not one
    # directory symlink into the pointer. Same content either way; the
    # difference is that names this module does not carry stay free, which is
    # what lets Orca own its own three skills here.
    #
    # enableOrca is off (the module default, stated for the record): Orca's
    # updater throws `skill-package-link` on any file with nlink != 1, which
    # every Nix-store file becomes once store optimisation hardlinks it, and
    # then reports the skill as `Unrecognized`. Vendored copies that were
    # byte-identical to Orca's own manifest were flagged just the same, so the
    # copies live where Orca can write them: `orca skills install`.
    perSkillLinks.enable = true;
    enableOrca = false;
    # The SAME derivation flake.nix exposes as `packages.skills`. Not a
    # convenience: it is what makes "pinned vs live" an exact comparison
    # instead of a permanently-drifted one. See `constructSkills` in flake.nix.
    package = constructSkills;
    # One entry per harness, with the mode its reader needs (CONSTRAINTS.md
    # #41). `per-skill`: a REAL directory holding one link per Construct
    # skill, for the four readers that see only their own directory — which
    # is also what keeps Claude Code's claude.ai `synced/` inside
    # ~/.claude/skills. `none`: nothing, for readers of ~/.agents/skills
    # itself (the cross-vendor hub) and for paths no installed agent reads;
    # it also lets Codex keep `.system/` in its own directory.
    # Never `dir-symlink`: it exposed those private trees to every agent.
    # `.gemini/skills` stays omitted; Gemini CLI reads ~/.agents/ directly.
    agentPaths = [
      # readers of their own directory only
      {
        path = ".claude/skills";
        mode = "per-skill";
      }
      {
        path = ".kiro/skills";
        mode = "per-skill";
      }
      {
        path = ".qwen/skills";
        mode = "per-skill";
      }
      {
        path = ".gemini/config/skills";
        mode = "per-skill";
      } # Antigravity IDE + CLI
      # readers of ~/.agents/skills; `none` only removes the old symlink
      {
        path = ".codex/skills";
        mode = "none";
      }
      {
        path = ".opencode/skills";
        mode = "none";
      }
      {
        path = ".copilot/skills";
        mode = "none";
      }
      {
        path = ".aichat/skills";
        mode = "none";
      } # aichat loads no skills at all
      {
        path = ".agent/skills";
        mode = "none";
      } # no installed reader
      {
        path = ".ai/skills";
        mode = "none";
      } # no installed reader
      {
        path = ".openclaude/skills";
        mode = "none";
      } # no installed reader
    ];
  };

  # One-time move of the two agent-private trees that landed in the hub
  # through the old directory symlinks (CONSTRAINTS.md #41): claude.ai's
  # `synced/` belongs to Claude Code, Codex's `.system/` to Codex. Runs after
  # Construct has replaced the symlinks. Each tree moves when its owner's
  # real directory exists and does not hold one yet; if the owner already
  # re-created its own (claude.ai re-syncs every ten minutes, Codex rebuilds
  # `.system/` at start), the hub copy is only the leak and is removed. A
  # no-op forever after. Not previewable with a dry run: the guards read
  # real state, and under DRY_RUN the old symlink is still in place.
  home.activation.steelboreSkillDirMigration =
    lib.hm.dag.entryAfter [ "spacecraft-construct-agent-symlinks" ]
      ''
        hub="$HOME/.agents/skills"
        claude="$HOME/.claude/skills"
        if [ -d "$hub/synced" ] && [ -d "$claude" ] && [ ! -L "$claude" ]; then
          if [ ! -e "$claude/synced" ]; then
            $DRY_RUN_CMD mv "$hub/synced" "$claude/synced"
          else
            echo "steelbore: ~/.claude/skills/synced already exists — removing the hub copy" >&2
            $DRY_RUN_CMD rm -rf "$hub/synced"
          fi
        fi
        codex="$HOME/.codex/skills"
        if [ -d "$hub/.system" ] && [ ! -L "$codex" ]; then
          if [ ! -e "$codex/.system" ]; then
            $DRY_RUN_CMD mkdir -p "$codex"
            $DRY_RUN_CMD mv "$hub/.system" "$codex/.system"
          else
            echo "steelbore: ~/.codex/skills/.system already exists — removing the hub copy" >&2
            $DRY_RUN_CMD rm -rf "$hub/.system"
          fi
        fi
      '';

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

      # `crates-mcp` — the `crates` MCP server (crates.io / docs.rs lookups),
      # from the in-tree pkgs/ index. Third-party, so it is packaged here rather
      # than consumed as a flake input, and pinned by version + hash rather than
      # by rev. mcp.toml names it by bare name on PATH, same as engram.
      #
      # Remove the imperative copy:  cargo uninstall crates-mcp
      (pkgs.callPackage ../../pkgs/crates-mcp/package.nix { })

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
