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

  # Kernel modules
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.kernelModules = [ "kvm-intel" ];
}
