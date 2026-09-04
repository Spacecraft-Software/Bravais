# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — ThinkPad (Intel i7-8665U, Whiskey Lake)
#
# Per-machine config. Shared host settings live in ../common.nix; only the
# machine-specific bits are set here.
{
  primaryUser,
  ...
}:

{
  imports = [
    ../common.nix
    ./hardware.nix
  ];

  networking.hostName = "bravais-thinkpad";

  steelbore.hardware = {
    audioLed.enable = true;
    bluetooth.enable = true;
    fingerprint.enable = true;
    intel.enable = true;
  };

  # Per-machine because the name is: this T490s reports its pointing stick as
  # "Elan TrackPoint" (i2c Elan, event11 — `xremap --device-details` to confirm
  # after a hardware change). Keeping xremap off it is what preserves libinput's
  # pointing-stick default of middle-button scrolling; see the option's own
  # description for why a grab silently destroys it.
  steelbore.desktops.mouseWorkspaceNav.ignoredDevices = [ "Elan TrackPoint" ];

  # Remote access into this machine (headless X11 virtual session via LeftWM).
  # One-time Google authorization is manual — see modules/services/chrome-remote-desktop.nix.
  steelbore.services.chromeRemoteDesktop = {
    enable = true;
    user = primaryUser;
  };

  # i7-8665U is x86-64-v3 (AVX2/BMI2/FMA) but has NO AVX-512, so v4 would
  # emit illegal instructions on this CPU. Pin to v3.
  steelbore.platform.x86_64 = {
    enable = true;
    marchLevel = "v3";
  };
}
