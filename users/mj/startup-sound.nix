# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — startup sound (assets/boot/startup-sound.mp3)
#
# Plays once per boot, at the first graphical login: Plymouth has no audio
# path and PipeWire is a per-user service, so nothing can play earlier without
# a system-wide audio stack. The marker lives in /tmp, which is on the tmpfs
# root (constraint #28) and so resets on every boot but survives a logout.
#
# Wanted by graphical-session.target: Niri, GNOME, COSMIC and Plasma reach it;
# LeftWM (startx) does not, so it stays silent there. Volume follows the
# default sink. Stop it early with `systemctl --user stop steelbore-startup-sound`.
{
  pkgs,
  ...
}:

let
  marker = "/tmp/steelbore-startup-sound-%U";
in
{
  systemd.user.services.steelbore-startup-sound = {
    Unit = {
      Description = "Steelbore startup sound (once per boot)";
      After = [
        "graphical-session.target"
        "pipewire.service"
        "wireplumber.service"
      ];
      PartOf = [ "graphical-session.target" ];
      ConditionPathExists = "!${marker}";
    };
    Service = {
      Type = "exec";
      # Marked before playing: a failed or interrupted playback must not
      # retry on the next login of the same boot.
      ExecStartPre = "${pkgs.coreutils}/bin/touch ${marker}";
      ExecStart = "${pkgs.pipewire}/bin/pw-play ${../../assets/boot/startup-sound.mp3}";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
