# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Boot Configuration
{
  pkgs,
  ...
}:

{
  # Bootloader: systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel: XanMod Latest (performance-optimized)
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

  # No kernel-module lists here — one owner per fact: machine-scan facts
  # (initrd modules) live in the generated hosts/<machine>/hardware.nix;
  # vendor modules (kvm-intel) live in modules/hardware/intel.nix.
}
