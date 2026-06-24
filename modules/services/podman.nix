# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Podman Container Runtime
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.steelbore.services.podman = {
    enable = lib.mkEnableOption "Podman container runtime (Docker-compatible)";
  };

  config = lib.mkIf config.steelbore.services.podman.enable {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true; # docker → podman drop-in alias
      extraPackages = [
        pkgs.youki
        pkgs.runc
      ];
    };
  };
}
