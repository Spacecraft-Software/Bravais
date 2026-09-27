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
  # The ESP is 196 MiB and each XanMod kernel+initrd pair is ~54 MiB, so it
  # holds three and no more; the installer prunes entries beyond the limit
  # BEFORE copying the new kernel (constraint #42).
  boot.loader.systemd-boot.configurationLimit = 3;

  # Kernel: XanMod Latest (performance-optimized)
  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;

  # No kernel-module lists here — one owner per fact: machine-scan facts
  # (initrd modules) live in the generated hosts/<machine>/hardware.nix;
  # vendor modules (kvm-intel) live in modules/hardware/intel.nix.
}
