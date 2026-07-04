# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Google Chrome Remote Desktop (headless X11 host)
#
# CRD runs a headless *virtual* X server and execs the session file
# ~/.chrome-remote-desktop-session (provided for user `mj` in users/mj/home.nix,
# launching LeftWM — CRD needs X11, and Niri/GNOME here are Wayland). After a
# rebuild the host is authorized ONCE, manually, per Google account:
#   1. Sign into the Google account in Chrome/Chromium.
#   2. Open https://remotedesktop.google.com/headless → Begin → Authorize.
#   3. Run the shown command as this user:
#        start-host --code="4/..." \
#          --redirect-url="https://remotedesktop.google.com/_/oauthredirect" \
#          --name="$(hostname)"
#      (the --code is single-use, expires in minutes) and set a 6-digit PIN.
#   4. Connect from https://remotedesktop.google.com/access with the PIN.
# CRD connects outbound over HTTPS to Google's relays — no inbound firewall port.
{
  config,
  lib,
  pkgs,
  primaryUser,
  ...
}:

let
  cfg = config.steelbore.services.chromeRemoteDesktop;
  crd = (import ../../pkgs { inherit pkgs; }).chrome-remote-desktop;
  crdDir = "/opt/google/chrome-remote-desktop";
in
{
  options.steelbore.services.chromeRemoteDesktop = {
    enable = lib.mkEnableOption "Google Chrome Remote Desktop headless host (X11 virtual session)";
    user = lib.mkOption {
      type = lib.types.str;
      default = primaryUser;
      description = "User the CRD host runs as (added to the chrome-remote-desktop group).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ crd ]; # provides `start-host` for the one-time authorization

    users.groups.chrome-remote-desktop = { };
    users.users.${cfg.user}.extraGroups = [ "chrome-remote-desktop" ];

    # CRD authenticates the local user via its own PAM stack (pam_unix).
    security.pam.services.chrome-remote-desktop.text = ''
      auth      required  pam_unix.so
      account   required  pam_unix.so
      password  required  pam_unix.so
      session   required  pam_unix.so
    '';

    # System instance running as the user. Mirrors the .deb's
    # chrome-remote-desktop@.service template, but with a Nix-store ExecStart.
    # RestartForceExitStatus=41 matches CRD's "restart me" convention.
    systemd.services."chrome-remote-desktop@${cfg.user}" = {
      description = "Chrome Remote Desktop host for ${cfg.user}";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Environment = "XDG_SESSION_CLASS=user XDG_SESSION_TYPE=x11";
        PAMName = "chrome-remote-desktop";
        TTYPath = "/dev/chrome-remote-desktop";
        ExecStart = "${crd}${crdDir}/chrome-remote-desktop --start --new-session";
        ExecStop = "${crd}${crdDir}/chrome-remote-desktop --stop";
        StandardOutput = "journal";
        StandardError = "inherit";
        RestartForceExitStatus = "41";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
