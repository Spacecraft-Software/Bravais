# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: KDE Plasma date/time formatting
{
  config,
  lib,
  pkgs,
  ...
}:

let
  kwriteconfig = lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6";

  # The panel clock's own keys, from plasma-workspace v6.6.5
  # `applets/digital-clock/main.xml`, group [Appearance]:
  #
  #   use24hFormat  UInt    0 = 12-Hour, 1 = follow region, 2 = 24-Hour
  #   dateFormat    string  longDate | shortDate | isoDate | custom
  #
  # The 0/1/2 mapping is NOT in main.xml — it is the ComboBox `model` index
  # order in configAppearance.qml, so read that file rather than assuming a
  # boolean if these ever need changing. `isoDate` renders %Y-%m-%d and needs
  # no companion customDateFormat.
  use24hFormat = "2";
  dateFormat = "isoDate";
in
{
  # ═══════════════════════════════════════════════════════════════════════════
  # 24-hour time and ISO 8601 dates in Plasma
  # ═══════════════════════════════════════════════════════════════════════════
  #
  # The applet's own keys are the ONLY thing that sets this, deliberately.
  # Locale is not used and must not be reintroduced -- see modules/core/locale.nix.
  #
  #   use24hFormat = 2  -> 24-hour
  #   dateFormat = isoDate -> Qt.formatDate(d, Qt.ISODate), i.e. %Y-%m-%d,
  #                           and genuinely locale-independent
  #
  # WHAT IS NOT CONTROLLABLE HERE: the time SEPARATOR. DigitalClock.qml's
  # timeFormatCorrection() takes its delimiter from
  # Qt.locale().timeFormat(Locale.ShortFormat) and there is no config key for
  # it, so the separator is whatever Qt's CLDR says for the session locale.
  # en_US gives ":". en_DK gives "." and produced a 23.15 clock -- which is why
  # LC_TIME is NOT written here any more and why locale.nix stays on en_US.
  # A future locale change must keep a colon separator or this breaks again.
  #
  # WHY kwriteconfig6 AND NOT xdg.configFile: plasmashell rewrites appletsrc
  # constantly (every panel move, widget add, popup resize). An xdg.configFile
  # entry would symlink it read-only into the store and break Plasma outright —
  # the same hazard already noted for kwinrc in ./desktop-theme.nix. Writing
  # only the two keys leaves the rest of the file to Plasma.
  #
  # TRADE-OFF, stated so it does not read as a bug: this runs on EVERY
  # activation and re-forces both keys, so a change made afterwards in Plasma's
  # own "Configure Digital Clock" dialog is reverted at the next rebuild. The
  # flake is the source of truth; to change the format, change it here.
  #
  # APPLYING IT. A running plasmashell does NOT clobber these writes:
  # KConfigIniBackend::writeConfig re-parses the file on disk on every sync and
  # only overwrites keys it has marked dirty, and plasmashell never dirties a
  # key the user did not change through the applet's own dialog. What it does
  # not do is pick them up live — Plasmoid.configuration has no KConfigWatcher.
  # There is no plasmashell "reconfigure" D-Bus method (unlike KWin's), so:
  #   - the clock flips on `systemctl --user restart plasma-plasmashell.service`
  #     (or at the next login), and nothing here needs a full re-login any more
  #     now that no locale is involved.
  home.activation.plasmaDateTime = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rc="${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc"

    # The applet index is runtime-generated — it is [Containments][2][Applets][21]
    # today and will not stay that across a panel edit or a fresh install — so
    # every digitalclock group is discovered rather than hardcoded. awk emits
    # one line per clock, already converted from the "[A][B][C]" header form
    # into the repeated --group flags kwriteconfig6 wants for nesting.
    #
    # Guarded with `if` rather than an early `exit`: this is one step in a
    # larger activation script, and exiting would skip everything after it.
    if [ -f "$rc" ]; then
      ${pkgs.gawk}/bin/awk '
        /^\[/ {
          group = ""
          n = split($0, parts, /\]\[/)
          for (i = 1; i <= n; i++) {
            p = parts[i]
            gsub(/^\[|\]$/, "", p)
            group = group " --group " p
          }
          next
        }
        /^plugin=org\.kde\.plasma\.digitalclock$/ { print group }
      ' "$rc" | while IFS= read -r groupArgs; do
        # Word splitting is intentional: group names are Containments/Applets
        # and digits, never anything needing quoting.
        # shellcheck disable=SC2086
        $DRY_RUN_CMD ${kwriteconfig} --file "$rc" $groupArgs \
          --group Configuration --group Appearance \
          --key use24hFormat ${use24hFormat}
        # shellcheck disable=SC2086
        $DRY_RUN_CMD ${kwriteconfig} --file "$rc" $groupArgs \
          --group Configuration --group Appearance \
          --key dateFormat ${dateFormat}
        # Default-true, so currently on by implication rather than by
        # declaration. Stated explicitly so the date survives a stray toggle.
        # shellcheck disable=SC2086
        $DRY_RUN_CMD ${kwriteconfig} --file "$rc" $groupArgs \
          --group Configuration --group Appearance \
          --key showDate true
      done
    fi
  '';
}
