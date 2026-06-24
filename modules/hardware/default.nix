# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Hardware Module Entry Point
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./bluetooth.nix
    ./fingerprint.nix
    ./intel.nix
  ];
}
