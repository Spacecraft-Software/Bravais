# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — ThinkPad (Intel i7-8665U, Whiskey Lake)
#
# Per-machine config. Shared host settings live in ../common.nix; only the
# machine-specific bits are set here.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ../common.nix
    ./hardware.nix
  ];

  networking.hostName = "bravais-thinkpad";

  steelbore.hardware = {
    bluetooth.enable = true;
    fingerprint.enable = true;
    intel.enable = true;
  };

  # i7-8665U is x86-64-v3 (AVX2/BMI2/FMA) but has NO AVX-512, so v4 would
  # emit illegal instructions on this CPU. Pin to v3.
  steelbore.platform.x86_64 = {
    enable = true;
    marchLevel = "v3";
  };
}
