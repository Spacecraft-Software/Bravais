# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — in-tree package index (elegance plan 3.2).
# Single callPackage surface for every vendored/first-party package; consumed
# by the modules AND exposed as the flake's `packages.x86_64-linux` output so
# each can be built/tested standalone via `nix build .#<name>`.
{ pkgs }:
{
  steelbore-audio-led = pkgs.callPackage ./steelbore-audio-led/package.nix { };
  claude-desktop = pkgs.callPackage ./claude-desktop/package.nix { };
  chrome-remote-desktop = pkgs.callPackage ./chrome-remote-desktop/package.nix { };
  ollama = pkgs.callPackage ./ollama/package.nix { };
  github-copilot-app = pkgs.callPackage ./github-copilot-app/package.nix { };
}
