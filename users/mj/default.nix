# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — User System Configuration
{ primaryUser, ... }:

let
  # Operator's standalone shell (Spacecraft-Software/Operator), installed
  # out-of-band by its own `cargo build` — not a Nix package, same posture as
  # the self-updating CLIs of constraint #4. If the binary is ever missing at
  # login, root (Brush) and the Nushell/Brush/Ion entries in /etc/shells
  # remain the recovery path.
  mjsh = "/home/${primaryUser}/.local/bin/mjsh";
in
{
  # Appended to hosts/common.nix's list (lists merge) — nushell, brush and ion stay.
  environment.shells = [ mjsh ];

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
      # (modules/desktops/mouse-workspace-nav.nix enables hardware.uinput, which
      # creates this group). `input` above covers only READING the real
      # devices; creating a virtual one needs this.
      "uinput"
    ];
    shell = mjsh;
  };
}
