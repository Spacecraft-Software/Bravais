# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — AI Coding Assistants and Tools
{ config, lib, pkgs, unstablePkgs, ... }:

{
  options.steelbore.packages.ai = {
    enable = lib.mkEnableOption "AI coding assistants and tools";
  };

  config = lib.mkIf config.steelbore.packages.ai.enable {
    environment.systemPackages = (with pkgs; [
      # AI Coding Assistants (Rust preferred)
      aichat                     # Rust — Universal chat REPL
      gemini-cli                 # Rust — Gemini CLI

      # AI Coding Assistants (Other)
      opencode                   # Go — Coding agent
      # kilocode-cli              # Coding agent (Kilo Code) — not in nixpkgs
      codex
      github-copilot-cli
      gpt-cli
      gorilla-cli                # Python — LLMs for your CLI (Gorilla LLM)
      llm                        # Python — Simon Willison's universal LLM CLI
      mcp-nixos
      # task-master-ai is disabled — its npm build is broken in nixpkgs (lockfile
      # omits @biomejs/biome and esbuild platform-specific optionalDependencies,
      # which `npm ci` refuses to ignore even with --omit=optional or fetcher v2).
      # Workaround: ship a `task-master` wrapper that runs the package via npx.
      # First invocation populates ~/.npm/_npx; subsequent ones are near-instant.
      (writeShellApplication {
        name = "task-master";
        runtimeInputs = [ nodejs ];
        text = ''exec npx -y --package=task-master-ai task-master "$@"'';
      })
      # claude-code intentionally not in this `with pkgs` block — it's
      # imported from unstablePkgs below so every Bravais variant gets the
      # latest npm-tracking nixpkgs build, not the channel-stable one.

      # Local LLM runtime
      ollama-cpu                 # Go — CPU-only Ollama (local LLM server)
    ])
    # claude-code: always from nixpkgs-unstable via specialArgs threading.
    ++ [ unstablePkgs.claude-code ];
  };
}
# grok-cli moved to users/mj/home.nix (unstable channel via HM) — it's
# unstable-only at the moment (added to nixpkgs after 25.11 branched),
# so HM-via-unstable is the right home rather than a stable-system
# conditional include.
