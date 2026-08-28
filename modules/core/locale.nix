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

  # LC_TIME stays en_US here, and that is a CORRECTION, not an oversight.
  #
  # en_DK.UTF-8 was used briefly to get ISO 8601 dates and 24h time
  # system-wide. It failed on both fronts and was reverted:
  #
  #   1. Qt does NOT read glibc locales — it carries its own CLDR data, and
  #      CLDR's en_DK is Danish-conventioned, whose short time format is
  #      "HH.mm". Plasma's digital clock lifts its separator straight out of
  #      Qt.locale().timeFormat(ShortFormat) in timeFormatCorrection(), with no
  #      config key to override it, so the panel clock rendered 23.15 with a
  #      DOT. See users/mj/plasma.nix, which is where the clock is actually
  #      pinned to 24h + ISO in a locale-independent way.
  #   2. glibc never generated it anyway. Despite i18n.supportedLocales
  #      evaluating to include en_DK.UTF-8/UTF-8, the built glibc-locales
  #      contained only en_US, so `LC_ALL=en_DK.UTF-8 date +%x` fell back to C
  #      and printed 08/28/26. Verify any locale added here actually exists
  #      before trusting it:  LC_ALL=<locale> date '+%x %X'
  #
  # So: ISO 8601 in the Plasma clock comes from the applet keys, not from here.
  # Making `date` in a terminal print ISO is a SEPARATE, still-open problem —
  # it needs (2) solved first, and whatever locale is chosen must keep a colon
  # time separator under Qt/CLDR or it will re-break the clock.
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
