# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: KDE Plasma date/time, layout and Caffeine
# shortcuts, colour scheme and splash screen
{
  config,
  lib,
  pkgs,
  steelborePalette,
  themeAssets,
  ...
}:

let
  kwriteconfig = lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6";

  # The Plasma splash: the boot animation again, from the Plymouth theme's
  # own frames (pkgs/steelbore-ksplash), on the active palette's canvas.
  ksplash = (import ../../pkgs { inherit pkgs; }).steelbore-ksplash.override {
    inherit (steelborePalette) background;
  };

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

  # Every KDE colour scheme the Theme repository ships, installed under the
  # display name KDE looks schemes up by (`Steelbore Blue.colors`), so System
  # Settings › Colors lists the whole family. The active slug is written to
  # kdeglobals below; a local theme installs the family but selects nothing.
  schemeFiles = builtins.listToAttrs (
    map (sch: {
      name = "color-schemes/${sch.name}.colors";
      value.source = sch.path;
    }) themeAssets.kdeSchemes
  );

  # ═══════════════════════════════════════════════════════════════════════════
  # Caffeine: Meta+Shift+C, the same bind as Niri, LeftWM and COSMIC
  # ═══════════════════════════════════════════════════════════════════════════
  # Plasma has no shortcut for its battery applet's "Manually Block Sleep and
  # Screen Locking" toggle. The checkbox lives in the applet's own QML, and
  # neither PowerDevil nor the applet registers a global action for it. So
  # the bind runs steelbore-caffeine, which takes the same two inhibits
  # through a held kde-inhibit (modules/desktops/shared.nix). The applet's
  # popup then lists it among the applications blocking sleep; the checkbox
  # itself does not move.
  #
  # X-KDE-Shortcuts in a desktop file is how an application ships a default
  # global shortcut. kglobalacceld's detectAppsWithShortcuts() finds it, but
  # only through KApplicationTrader, i.e. among the applications/ entries, so
  # the file goes there and not under kglobalaccel/ (that directory is read
  # only for components kglobalshortcutsrc already names). NoDisplay keeps it
  # out of every menu without hiding it from that scan; NotShowIn=KDE would.
  # This is a DEFAULT, not a forced key, unlike the layout shortcut below: a
  # rebind in System Settings › Shortcuts sticks. Read at login.
  # Meta+Shift+C is unbound in stock Plasma.
  caffeineShortcut = ''
    [Desktop Entry]
    Type=Application
    Name=Toggle Caffeine (keep awake)
    Exec=steelbore-caffeine
    Icon=caffeine-cup-full
    NoDisplay=true
    X-KDE-Shortcuts=Meta+Shift+C
  '';

  # Terminal: Meta+Return, as Mod+Return under Niri, LeftWM and Margo. Shipped
  # the same way as Caffeine above, but also pinned in kglobalshortcutsrc
  # (plasmaSharedShortcuts below): Krohnkite claims Meta+Return for "Set
  # master", and once kglobalaccel has recorded this entry with no key, the
  # desktop-file default is never applied again. Plasma's own Konsole key,
  # Ctrl+Alt+T, is left as it is.
  terminalShortcut = ''
    [Desktop Entry]
    Type=Application
    Name=Open a Terminal (Alacritty)
    Exec=alacritty
    Icon=Alacritty
    NoDisplay=true
    X-KDE-Shortcuts=Meta+Return
  '';

  # Meta+N / Meta+Shift+N for desktops 1-9, as under Niri, LeftWM and Margo.
  # KWin ships keys for desktops 1-4 only (Meta+F1-F4 and Ctrl+F1-F4, kept
  # here); entries for desktops that do not exist are inert. A shifted digit
  # reaches kglobalaccel as its symbol, which is how System Settings records
  # it ("Meta+!"), so both spellings are listed; the symbols are the US
  # layout's.
  shiftedDigit = [
    "!"
    "@"
    "#"
    "$"
    "%"
    "^"
    "&"
    "*"
    "("
  ];
  desktopKeys = lib.concatMapStrings (
    n:
    let
      i = toString n;
      stock = lib.optionalString (n <= 4) "\\tMeta+F${i}\\tCtrl+F${i}";
      stockDefault = if n <= 4 then "Meta+F${i}\\tCtrl+F${i}" else "none";
      sym = builtins.elemAt shiftedDigit (n - 1);
    in
    ''
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group kwin --key "Switch to Desktop ${i}" \
        "$(printf '%b' 'Meta+${i}${stock},${stockDefault},Switch to Desktop ${i}')"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group kwin --key "Window to Desktop ${i}" \
        "$(printf '%b' 'Meta+${sym}\tMeta+Shift+${i},none,Window to Desktop ${i}')"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group plasmashell --key "activate task manager entry ${i}" \
        "none,Meta+${i},Activate Task Manager Entry ${i}"
    ''
  ) (lib.range 1 9);
in
{
  xdg.dataFile = schemeFiles // {
    "applications/steelbore-caffeine.desktop".text = caffeineShortcut;
    "applications/steelbore-terminal.desktop".text = terminalShortcut;
    "plasma/look-and-feel/${ksplash.packageId}".source =
      "${ksplash}/share/plasma/look-and-feel/${ksplash.packageId}";
  };

  # ═══════════════════════════════════════════════════════════════════════════
  # Splash screen — the boot animation (pkgs/steelbore-ksplash)
  # ═══════════════════════════════════════════════════════════════════════════
  # ksplashrc names a Look-and-Feel package by id; ours carries only the
  # splash, so choosing it here leaves the Global Theme alone. kwriteconfig6
  # rather than xdg.configFile because System Settings › Splash Screen
  # rewrites the file — same trade-off as the keys below: a choice made there
  # is reverted at the next rebuild. Read at the next Plasma login.
  home.activation.plasmaSplash = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/ksplashrc" \
      --group KSplash --key Engine KSplashQML
    $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/ksplashrc" \
      --group KSplash --key Theme "${ksplash.packageId}"
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # Active colour scheme — the §11.6.5 polarity/palette agreement for Plasma
  # ═══════════════════════════════════════════════════════════════════════════
  # kdeglobals is rewritten by Plasma itself, so it is edited with
  # kwriteconfig6 on activation rather than symlinked (same reasoning as the
  # clock keys below). Plasma applies a changed ColorScheme on the next login;
  # `plasma-apply-colorscheme` from a running session applies it live.
  home.activation.plasmaColorScheme = lib.mkIf (themeAssets.kde != null) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kdeglobals" \
        --group General --key ColorScheme "${themeAssets.name}"
    ''
  );

  # ═══════════════════════════════════════════════════════════════════════════
  # Keyboard layout switching: Ctrl+Space OR Meta+Space
  # ═══════════════════════════════════════════════════════════════════════════
  # The XKB "Switching to another layout" options CANNOT give two keys: each
  # grp:*_toggle option rewrites the same Space key, so ticking both Ctrl+Space
  # and Win+Space leaves only one in force. The layout switcher's own global
  # shortcut can, because kglobalaccel keeps a list of keys per action
  # (tab-separated in the active field). Ctrl+Space stays first, as set in
  # System Settings; Meta+Space is the alternate, matching Niri's Mod+Space.
  # Meta+Space is unbound in Plasma by default (KRunner is Alt+Space).
  #
  # kglobalshortcutsrc is rewritten by kglobalaccel, so this is kwriteconfig6
  # on one key, not an xdg.configFile — the same reasoning as the clock below,
  # with the same trade-off: a change made in System Settings is reverted at
  # the next rebuild. kglobalaccel reads the file at login, so the alternate
  # takes effect at the next Plasma login. Applies to Wayland and X11 alike.
  home.activation.plasmaLayoutShortcut = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
      --group "KDE Keyboard Layout Switcher" --key "Switch to Next Keyboard Layout" \
      "$(printf 'Ctrl+Space\tMeta+Space,Meta+Alt+K,Switch to Next Keyboard Layout')"
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # KRunner: Meta+D alongside its stock Alt+Space, Alt+F2 and Search keys
  # ═══════════════════════════════════════════════════════════════════════════
  # Matches Mod+D under Niri, COSMIC and GNOME (Super+D searches there).
  # Meta+D is KWin's default for "Peek at Desktop", and kglobalaccel gives a
  # key to only one action, so that action is left with no key. Both values are what System
  # Settings › Shortcuts writes for this choice, pinned the same way as the
  # layout shortcut above (with its trade-off). A [services] entry carries
  # only the active keys, tab-separated; a [kwin] entry is
  # "active,default,friendly name". Read at the next Plasma login.
  home.activation.plasmaKrunnerShortcut = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
      --group services --group org.kde.krunner.desktop --key _launch \
      "$(printf 'Alt+Space\tAlt+F2\tSearch\tMeta+D')"
    $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
      --group kwin --key "Show Desktop" "none,Meta+D,Peek at Desktop"
  '';

  # ═══════════════════════════════════════════════════════════════════════════
  # The keys every Bravais session shares (docs/keybindings.md)
  # ═══════════════════════════════════════════════════════════════════════════
  # Meta+Q close (Alt+F4 kept), Meta+F fullscreen, Meta+Shift+F maximize (Meta+PgUp kept), Meta+L lock (Meta+Shift+L
  # dropped), and Meta+N / Meta+Shift+N for desktops 1-9 in place of the task
  # manager entries (Meta+1-9 by default; those are left with no key).
  # Meta+Q is plasmashell's "Show Activity Switcher" by default, so that
  # action is left with no key (Meta+Tab still cycles activities).
  # Meta+Shift+D opens Kickoff beside Meta alone and Alt+F1, the app-menu
  # key in every session. Meta+F, Meta+Shift+D and Meta+Shift+N are unbound
  # in stock Plasma.
  # The Krohnkite tiling script (desktop-theme.nix) ships defaults on four of
  # the shared keys: Meta+Return (set master), Meta+D (fewer master windows),
  # Meta+F (toggle float) and Meta+L (focus right). Those four actions are
  # left with no key, so the shared key reaches the action above;
  # Krohnkite's other keys (Meta+H/J/K, Meta+Shift+H/J/K/L, Meta+I, ...) stay.
  # Meta+Shift+L (move right) was pinned to none while it was the lock key;
  # it is written back to Krohnkite's default here.
  # Its shortcuts live under [kwin], keyed by the script's action name.
  # Pinned like the keys above, with the same trade-off; read at the next
  # Plasma login. printf turns the \t separators into tabs.
  home.activation.plasmaSharedShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    ''
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group kwin --key "Window Close" "$(printf 'Meta+Q\tAlt+F4,Alt+F4,Close Window')"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group kwin --key "Window Fullscreen" "Meta+F,none,Make Window Fullscreen"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group kwin --key "Window Maximize" \
        "$(printf 'Meta+PgUp\tMeta+Shift+F,Meta+PgUp,Maximize Window')"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group plasmashell --key "manage activities" "none,Meta+Q,Show Activity Switcher"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group plasmashell --key "activate application launcher" \
        "$(printf 'Meta\tAlt+F1\tMeta+Shift+D,Meta\tAlt+F1,Activate Application Launcher')"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group ksmserver --key "Lock Session" \
        "$(printf 'Meta+L\tScreensaver,Meta+L\tScreensaver,Lock Session')"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group services --group steelbore-terminal.desktop --key _launch "Meta+Return"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group kwin --key KrohnkiteSetMaster "none,Meta+Return,Krohnkite: Set master"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group kwin --key KrohnkiteDecrease "none,Meta+D,Krohnkite: Decrease"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group kwin --key KrohnkiteToggleFloat "none,Meta+F,Krohnkite: Toggle Float"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group kwin --key KrohnkiteShiftRight "Meta+Shift+L,Meta+Shift+L,Krohnkite: Move Right"
      $DRY_RUN_CMD ${kwriteconfig} --file "${config.xdg.configHome}/kglobalshortcutsrc" \
        --group kwin --key KrohnkiteFocusRight "none,Meta+L,Krohnkite: Focus Right"
    ''
    + desktopKeys
  );

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

  # ═══════════════════════════════════════════════════════════════════════════
  # Pinned panel launchers — by app id, never by store path
  # ═══════════════════════════════════════════════════════════════════════════
  # The task manager sometimes saves a pin as the file it resolved, e.g.
  #   file:///nix/store/<hash>-system-path/share/applications/org.kde.dolphin.desktop
  # instead of applications:org.kde.dolphin.desktop. Every rebuild makes a new
  # system-path (and user-environment), and once GC takes the old one the pin
  # shows a blank-file icon and launches nothing. The same .desktop is reached
  # through /run/current-system/sw and /etc/profiles/per-user, both on
  # XDG_DATA_DIRS, so the app id is the stable spelling of the same launcher.
  #
  # Only the launchers= lines are touched, and only their store-path entries;
  # pins already written as applications: or preferred:// are left alone.
  # A sed on the file rather than kwriteconfig6: the key's group is a runtime
  # applet index, and a running plasmashell does not clobber an on-disk key
  # it has not dirtied (see the clock block above). It reads the change at
  # the next `systemctl --user restart plasma-plasmashell.service` or login.
  home.activation.plasmaLaunchers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rc="${config.xdg.configHome}/plasma-org.kde.plasma.desktop-appletsrc"
    if [ -f "$rc" ] && ${lib.getExe pkgs.gnugrep} -q '^launchers=.*file:///nix/store/' "$rc"; then
      $DRY_RUN_CMD ${lib.getExe pkgs.gnused} -E -i \
        '/^launchers=/ s#file:///nix/store/[0-9a-z]{32}-[^/,]+/share/applications/([^,/]+\.desktop)#applications:\1#g' \
        "$rc"
    fi
  '';
}
