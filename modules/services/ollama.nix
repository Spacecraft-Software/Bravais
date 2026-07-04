# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Ollama local LLM server (official prebuilt, CPU-only)
#
# nixpkgs' ollama is far behind upstream (stable 0.24.0), and current models
# 412-reject it. Run the official prebuilt (pkgs/ollama/, pinned 0.31.1) via the
# stock services.ollama module. CPU-only — the prebuilt's CUDA/Vulkan runners are
# stripped in the package, so no `acceleration` setting is needed.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.steelbore.services.ollama;
  ollama = (import ../../pkgs { inherit pkgs; }).ollama;
in
{
  options.steelbore.services.ollama = {
    enable = lib.mkEnableOption "Ollama local LLM server (official prebuilt 0.31.1, CPU-only)";
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = ollama;
    };
    # Ensure the `ollama` client is on PATH (idempotent with the service module).
    environment.systemPackages = [ ollama ];
  };
}
