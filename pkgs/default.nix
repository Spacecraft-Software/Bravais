# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — in-tree package index (elegance plan 3.2).
# Single callPackage surface for every vendored/first-party package; consumed
# by the modules AND exposed as the flake's `packages.x86_64-linux` output so
# each can be built/tested standalone via `nix build .#<name>`.
{ pkgs }:
{
  steelbore-audio-led = pkgs.callPackage ./steelbore-audio-led/package.nix { };
  steelbore-beacon = pkgs.callPackage ./steelbore-beacon/package.nix { };
  steelbore-niri-unmax = pkgs.callPackage ./steelbore-niri-unmax/package.nix { };
  claude-desktop = pkgs.callPackage ./claude-desktop/package.nix { };
  chrome-remote-desktop = pkgs.callPackage ./chrome-remote-desktop/package.nix { };
  ollama = pkgs.callPackage ./ollama/package.nix { };
  github-copilot-app = pkgs.callPackage ./github-copilot-app/package.nix { };
  bravais-mcp = pkgs.callPackage ./bravais-mcp/package.nix { };
  opencode-desktop = pkgs.callPackage ./opencode-desktop/package.nix { };
  goose-desktop = pkgs.callPackage ./goose-desktop/package.nix { };
  codex-desktop = pkgs.callPackage ./codex-desktop/package.nix { };
  adguardvpn-cli = pkgs.callPackage ./adguardvpn-cli/package.nix { };
  crates-mcp = pkgs.callPackage ./crates-mcp/package.nix { };
  obscura = pkgs.callPackage ./obscura/package.nix { };
}

