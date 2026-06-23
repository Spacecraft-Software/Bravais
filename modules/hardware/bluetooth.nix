# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Bluetooth Support
#
# Enables the BlueZ stack (bluetoothd) and ships two memory-safe (Rust),
# GPL-3.0 BlueZ clients per the Rust-first convention:
#   • bluetui    — keyboard-driven TUI (scan → pair → connect), the default
#                  manager for the Niri/TUI workflow.
#   • overskride — GTK GUI client (DE/WM-agnostic) with OBEX file transfer.
# Both are plain D-Bus clients of the same bluetoothd, so they coexist with
# no package collision or runtime conflict. The Niri keybinds that launch
# them, and the existing XF86Bluetooth rfkill radio toggle, live in
# users/mj/home.nix + modules/desktops/niri.nix.
{ config, lib, pkgs, ... }:

{
  options.steelbore.hardware.bluetooth = {
    enable = lib.mkEnableOption "Bluetooth (BlueZ) support with bluetui + overskride managers";
  };

  config = lib.mkIf config.steelbore.hardware.bluetooth.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
        # Battery-level reporting for headsets/controllers that support it.
        Experimental = true;
      };
    };

    environment.systemPackages = [
      pkgs.bluetui     # Rust -- TUI BlueZ client (default manager)
      pkgs.overskride  # Rust -- GTK GUI BlueZ/OBEX client
    ];
  };
}
