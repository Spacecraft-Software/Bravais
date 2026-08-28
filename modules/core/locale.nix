# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Locale Configuration
{
  ...
}:

{
  # Timezone (Asia/Bahrain for user preference)
  time.timeZone = "Asia/Bahrain";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # NOTE: there is deliberately no `i18n.supportedLocales` here. On 26.05 that
  # option is hidden and derived — it aggregates defaultLocale plus every
  # locale named in extraLocaleSettings below — so setting LC_TIME to en_DK
  # already gets en_DK.UTF-8 generated. Writing the list by hand would be
  # redundant today and a trap tomorrow: the next LC_* added below would need
  # mirroring here or the locale silently would not be built. Confirm with
  #   nix eval .#nixosConfigurations.bravais-thinkpad.config.i18n.supportedLocales
  # (A locale wanted WITHOUT a matching LC_* goes in `i18n.extraLocales`.)
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    # ISO 8601 dates and 24h time everywhere, per AGENTS.md ("All date/time
    # displays use %Y-%m-%d %H:%M:%S 24h format") and Standard §14.1, which
    # states AM/PM is never permitted. Deliberately system-wide rather than
    # Plasma-only: this host runs five desktops, and scoping the fix to one of
    # them would leave GNOME, COSMIC, Niri and LeftWM on 12h M/D/Y. Every other
    # LC_* stays en_US, so only date/time formatting moves — `date`, `ls -l`
    # and log viewers change with it, which is the intent.
    LC_TIME = "en_DK.UTF-8";
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
