# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — User System Configuration
{ pkgs, primaryUser, ... }:

{
  users.users.${primaryUser} = {
    isNormalUser = true;
    description = "Mohamed Hammad";
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "video"
      "audio"
      "seat" # Access to /run/seatd.sock (cage/Wayland kiosk)
      # /dev/uinput, for xremap's virtual output device under GNOME
      # (modules/desktops/gnome-mouse-nav.nix enables hardware.uinput, which
      # creates this group). `input` above covers only READING the real
      # devices; creating a virtual one needs this.
      "uinput"
    ];
    shell = pkgs.nushell;
  };
}
