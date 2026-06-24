# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Fingerprint Reader Support
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.steelbore.hardware.fingerprint = {
    enable = lib.mkEnableOption "Fingerprint reader support";
  };

  config = lib.mkIf config.steelbore.hardware.fingerprint.enable {
    services.fprintd.enable = true;

    environment.systemPackages = [ pkgs.fprintd ];
  };
}
