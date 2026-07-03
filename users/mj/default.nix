# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — User System Configuration
{ pkgs, ... }:

{
  users.users.mj = {
    isNormalUser = true;
    description = "Mohamed Hammad";
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "video"
      "audio"
      "seat" # Access to /run/seatd.sock (cage/Wayland kiosk)
    ];
    shell = pkgs.nushell;
  };
}
