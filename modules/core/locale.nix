# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Locale Configuration
{ config, lib, pkgs, ... }:

{
  # Timezone (Asia/Bahrain for user preference)
  time.timeZone = "Asia/Bahrain";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Console/TTY keymap is set in the shared host config (see hosts/common.nix)

  # Input method — ibus-daemon runs idle. iBus is pulled in transitively by
  # GNOME, and `org.freedesktop.IBus.Panel.Wayland.Gtk3.desktop` autostarts
  # under Wayland sessions; without a daemon it surfaces an error popup
  # (notably under COSMIC). Empty engines list keeps the daemon idle on
  # US-only input but provides the dbus surface the panel autostart expects.
  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus.engines = [ ];
  };
}
