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

  networking.hostName = "steelbore-thinkpad";

  steelbore.hardware = {
    android.enable = true;
    audioLed.enable = true;
    bluetooth.enable = true;
    fingerprint.enable = true;
    intel.enable = true;
  };

  # Per-machine because the names are (`xremap --device-details` to confirm
  # after a hardware change); see the option's own description for why a grab
  # silently breaks each one.
  #   "Elan TrackPoint" (i2c Elan, event11) — a grab loses libinput's
  #     pointing-stick default of middle-button scrolling.
  #   "AT Translated Set 2 keyboard" (the built-in keyboard) — a grab leaves the
  #     Caps Lock / Num Lock LEDs dark, in the session and on every TTY.
  steelbore.desktops.mouseWorkspaceNav.ignoredDevices = [
    "Elan TrackPoint"
    "AT Translated Set 2 keyboard"
  ];

  # Remote access into this machine (headless X11 virtual session via LeftWM).
  # One-time Google authorization is manual — see modules/services/chrome-remote-desktop.nix.
  # Waydroid is Wayland-only: it works under Niri, GNOME, COSMIC and Plasma's
  # Wayland session, and NOT under LeftWM (startx/X11, no X11 backend exists).
  steelbore.services.waydroid.enable = true;

  # Disabled 2026-10-02; flip back to re-enable (the host registration in
  # ~/.config/chrome-remote-desktop is left in place).
  steelbore.services.chromeRemoteDesktop = {
    enable = false;
    user = primaryUser;
  };

  # i7-8665U is x86-64-v3 (AVX2/BMI2/FMA) but has NO AVX-512, so v4 would
  # emit illegal instructions on this CPU. Pin to v3.
  steelbore.platform.x86_64 = {
    enable = true;
    marchLevel = "v3";
  };
}
