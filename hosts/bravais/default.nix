# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Host Configuration
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware.nix
  ];

  # Hostname
  networking.hostName = "bravais";
  networking.networkmanager.enable = true;

  # X11 (for LeftWM)
  services.xserver.enable = true;
  # Touchpad — natural (reverse) scrolling on X11 sessions (LeftWM, Plasma X11).
  # Niri sets its own equivalent in its config.kdl.
  services.libinput.touchpad.naturalScrolling = true;
  services.xserver.xkb = {
    layout = "us,ara";
    options = "grp:ctrl_space_toggle";
  };

  # ckbcomp can't resolve multi-layout XKB configs; keep console on US
  console.keyMap = "us";

  # Printing
  services.printing.enable = true;

  # User account
  users.users.mj = {
    isNormalUser = true;
    description = "Mohamed Hammad";
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "video"
      "audio"
      "seat"      # Access to /run/seatd.sock (cage/Wayland kiosk)
    ];
    shell = pkgs.nushell;
  };

  # Root shell — Brush (Rust, Bash-compatible)
  users.users.root.shell = pkgs.brush;

  # Register shells as valid login shells
  # Ion kept as available; bash is present in NixOS internals but not a user shell
  environment.shells = [ pkgs.nushell pkgs.brush pkgs.ion ];
  # Note: programs.bash.enable is intentionally left at its default (true) because
  # NixOS activation scripts and PAM tooling (userdel, useradd, etc.) depend on the
  # bash module being active. Bash is excluded from user shells via shell= and
  # environment.shells — no user or root has bash as their login shell.

  # Steelbore module toggles
  steelbore = {
    # Desktop environments
    desktops.gnome.enable = true;
    desktops.cosmic.enable = true;   # stable pkgs (nixos-26.05)
    desktops.plasma.enable = true;
    desktops.niri.enable = true;
    desktops.leftwm.enable = true;

    # Hardware
    hardware.fingerprint.enable = true;
    hardware.intel.enable = true;

    # Package bundles
    packages.browsers.enable = true;
    packages.terminals.enable = true;
    packages.editors.enable = true;
    packages.development.enable = true;
    packages.security.enable = true;
    packages.networking.enable = true;
    packages.multimedia.enable = true;
    packages.productivity.enable = true;
    packages.system.enable = true;
    packages.ai.enable = true;
    packages.flatpak.enable = true;
  };

  system.stateVersion = "25.11";
}
