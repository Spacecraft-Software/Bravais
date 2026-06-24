# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Intel CPU vendor support (KVM, microcode)
#
# Vendor-only. The x86-64 ISA level and the compiler/linker flag policy derived
# from it live in modules/platform/x86-64.nix (steelbore.platform.x86_64) —
# an x86-64-vN level is not Intel-specific.
{
  config,
  lib,
  ...
}:

{
  options.steelbore.hardware.intel = {
    enable = lib.mkEnableOption "Intel CPU vendor support (KVM, microcode)";
  };

  config = lib.mkIf config.steelbore.hardware.intel.enable {
    boot.kernelModules = [ "kvm-intel" ];

    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
