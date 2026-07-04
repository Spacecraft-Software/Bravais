# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Audio mute / mic-mute keyboard LED sync
#
# The ThinkPad mute (`platform::mute`) and mic-mute (`platform::micmute`) LEDs are
# wired by the kernel to the `audio-mute` / `audio-micmute` triggers, which follow
# the ALSA *hardware* mute control. PipeWire mutes the node in *software*, so the
# hardware mute never flips and the LEDs stay dark. The steelbore-audio-led daemon
# watches the default sink/source mute state and drives the LEDs directly.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  audioLed = (import ../../pkgs { inherit pkgs; }).steelbore-audio-led;
in
{
  options.steelbore.hardware.audioLed = {
    enable = lib.mkEnableOption "ThinkPad mute / mic-mute keyboard LED sync (PipeWire mute → sysfs LED)";
  };

  config = lib.mkIf config.steelbore.hardware.audioLed.enable {
    # The daemon reads mute state from the user's PipeWire session; without
    # PipeWire it starts, finds no server, and flaps under Restart=on-failure
    # (elegance plan 2.4).
    assertions = [
      {
        assertion = config.services.pipewire.enable;
        message = ''
          steelbore.hardware.audioLed requires services.pipewire.enable = true —
          the LED daemon watches the default sink/source mute via PipeWire.
        '';
      }
    ];

    environment.systemPackages = [ audioLed ];

    # Hand ownership of the two LEDs to the daemon by clearing their kernel
    # triggers — otherwise `snd_ctl_led` (follow-mute) could fight the daemon.
    # `trigger` is root-only (the brightnessctl udev rule in
    # modules/desktops/niri.nix only makes `brightness` group-writable), so it
    # must be set declaratively here.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::mute", ATTR{trigger}="none"
      ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", ATTR{trigger}="none"
    '';

    # Event-driven daemon, run in the user session (it needs the user's PipeWire).
    # It writes the LED `brightness` nodes as the `input`-group user (granted by
    # the brightnessctl udev rule). `Restart = on-failure` also covers audio-server
    # restarts: the daemon exits and is restarted, re-reading initial state.
    systemd.user.services.steelbore-audio-led = {
      description = "Steelbore audio mute / mic-mute keyboard LED sync";
      wantedBy = [ "default.target" ];
      after = [
        "pipewire.service"
        "wireplumber.service"
        "pipewire-pulse.service"
      ];
      wants = [
        "pipewire.service"
        "wireplumber.service"
        "pipewire-pulse.service"
      ];
      serviceConfig = {
        ExecStart = lib.getExe audioLed;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
