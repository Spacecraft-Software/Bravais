# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — AI Coding Assistants and Tools
{
  config,
  lib,
  pkgs,
  unstablePkgs,
  ...
}:

{
  options.steelbore.packages.ai = {
    enable = lib.mkEnableOption "AI coding assistants and tools";
  };

  config = lib.mkIf config.steelbore.packages.ai.enable {
    environment.systemPackages =
      (with pkgs; [
        # AI Coding Assistants (Rust preferred)
        aichat # Rust — Universal chat REPL
        # gemini-cli                 # DISABLED — re-enable by uncommenting
        # opencode                   # DISABLED — re-enable by uncommenting (Go coding agent)
        # kilocode-cli              # Coding agent (Kilo Code) — not in nixpkgs
        # codex                     # DISABLED — re-enable by uncommenting (OpenAI Codex CLI)
        # github-copilot-cli           # DISABLED — re-enable by uncommenting
        gpt-cli
        gorilla-cli # Python — LLMs for your CLI (Gorilla LLM)
        # llm                      # Python — Simon Willison's universal LLM CLI
        # task-master wrapper DISABLED — re-enable by uncommenting the
        # writeShellApplication block below. Rationale (preserved):
        # task-master-ai npm build is broken in nixpkgs (lockfile omits
        # @biomejs/biome and esbuild platform-specific optionalDependencies,
        # which `npm ci` refuses to ignore even with --omit=optional or
        # fetcher v2). Workaround: ship a `task-master` wrapper that runs
        # the package via npx. First invocation populates ~/.npm/_npx;
        # subsequent ones are near-instant.
        # (writeShellApplication {
        #   name = "task-master";
        #   runtimeInputs = [ nodejs ];
        #   text = ''exec npx -y --package=task-master-ai task-master "$@"'';
        # })
        # claude-code is currently installed out-of-band via the official
        # installer; the unstablePkgs entry below is commented out. See the
        # block under `with unstablePkgs;` for re-enabling.

        # Local LLM runtime
        # ollama-cpu               # DISABLED — re-enable by uncommenting (Go, CPU-only Ollama local LLM server)
      ])
      # mcp-nixos: always from nixpkgs-unstable via specialArgs threading.
      ++ (with unstablePkgs; [
        # claude-code intentionally disabled — installed out-of-band via the
        # official installer (npm `@anthropic-ai/claude-code` or the curl
        # one-shot) to get same-day upstream releases. Re-enable by
        # uncommenting and rebuilding; see CLAUDE.md constraint #4 for the
        # original rationale.
        # claude-code
        # mcp-nixos DISABLED — pulls fastmcp whose tests hang in Nix sandbox
      ]);
  };
}
