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

  # Only the mouse interfaces: the USB receiver also exposes keyboards with
  # the same vendor/product pair. Confirm names with `escapepod device list`.
  steelbore.desktops.mouseWorkspaceNav.deviceNames = [
    "UGREEN Receiver  Mouse"
    "UGREEN BLE Mouse"
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
