# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — greetd + tuigreet Login Manager
{
  config,
  lib,
  pkgs,
  primaryUser,
  steelborePalette,
  steelboreIdentity,
  gitway,
  ...
}:

let
  # Wrap each shell-as-session in cage (single-app Wayland kiosk) plus rio
  # (the project's default terminal). Without this wrapper greetd execs the
  # bare shell binary in a no-TTY no-compositor context: brush blocks on
  # stdin, ion fails fast, nushell silently swallows its own startup error.
  # cage gives the missing compositor; rio gives the missing PTY; the shell
  # gets a real interactive terminal as it expects.
  mkShellSession =
    {
      name,
      sessionName,
      exec,
      comment,
    }:
    (pkgs.runCommand name
      {
        passthru.providedSessions = [ sessionName ];
      }
      ''
        mkdir -p $out/share/wayland-sessions
        cat > $out/share/wayland-sessions/${sessionName}.desktop <<EOF
        [Desktop Entry]
        Name=${name}
        Comment=${comment}
        Exec=${pkgs.cage}/bin/cage -- ${pkgs.rio}/bin/rio -e ${exec}
        Type=Application
        DesktopNames=${sessionName}
        EOF
      ''
    );

  # X11 session entry. Used for window managers that need Xorg started by the
  # session itself (greetd does not start Xorg). The Exec line should already
  # bring up an X server — typically via `startx <wm>` from xorg.xinit.
  mkXSession =
    {
      name,
      sessionName,
      exec,
      comment,
    }:
    (pkgs.runCommand "${name}-xsession"
      {
        passthru.providedSessions = [ sessionName ];
      }
      ''
        mkdir -p $out/share/xsessions
        cat > $out/share/xsessions/${sessionName}.desktop <<EOF
        [Desktop Entry]
        Name=${name}
        Comment=${comment}
        Exec=${exec}
        Type=XSession
        DesktopNames=${sessionName}
        EOF
      ''
    );

  ion-shell-session = mkShellSession {
    name = "Ion Shell";
    sessionName = "ion-shell";
    exec = "${pkgs.ion}/bin/ion";
    comment = "Drop to Ion shell";
  };

  nushell-session = mkShellSession {
    name = "Nushell";
    sessionName = "nushell";
    exec = "${pkgs.nushell}/bin/nu";
    comment = "Drop to Nushell";
  };

  brush-session = mkShellSession {
    name = "Brush Shell";
    sessionName = "brush";
    exec = "${pkgs.brush}/bin/brush";
    comment = "Drop to Brush shell";
  };

  # Operator's mjsh — the primary user's login shell, out-of-band at the
  # path users/mj/default.nix sets as `shell`, so it is read back from there
  # rather than restated. If the binary is missing, the Nushell/Brush/Ion
  # sessions remain.
  mjsh-session = mkShellSession {
    name = "mjsh";
    sessionName = "mjsh";
    exec = config.users.users.${primaryUser}.shell;
    comment = "Drop to mjsh (Operator)";
  };

  # Unified `start-<de>` launchers. Every desktop in Bravais exposes the same
  # naming pattern so users (and greetd's environment list) can launch any
  # session without remembering upstream session-binary names.
  #
  # `start-cosmic` is intentionally not defined here — `pkgs.cosmic-session`
  # already ships `bin/start-cosmic` (with login-shell env loading and
  # systemd-unit reset that we don't want to skip), and the cosmic NixOS
  # module pulls cosmic-session into systemPackages. Defining our own would
  # collide on /run/current-system/sw/bin/start-cosmic.
  mkStartWrapper =
    name: command:
    pkgs.writeShellScriptBin "start-${name}" ''
      exec ${command} "$@"
    '';

  start-gnome = mkStartWrapper "gnome" "${pkgs.gnome-session}/bin/gnome-session";
  start-plasma = mkStartWrapper "plasma" "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland";
  start-niri = mkStartWrapper "niri" "${pkgs.niri}/bin/niri-session";

  # X11 launchers need to bring up Xorg themselves — greetd does NOT start
  # an X server (unlike SDDM/GDM/LightDM). startx is a shell script that
  # internally invokes `xinit`, `xauth`, `xrdb`, and `mcookie` by bare name,
  # so they must be on PATH. greetd's session env doesn't include the xinit
  # bin/, hence the explicit prefix below.
  #
  # On unstable these are top-level (pkgs.xinit etc.) and the legacy
  # pkgs.xorg.* paths warn. On stable 25.11 only the xorg.* paths exist.
  # The `or`-fallback evaluates clean on both channels — same
  # stable/unstable split as xfce4-terminal (CONSTRAINTS.md #5).
  xinitPkg = pkgs.xinit or pkgs.xorg.xinit;
  xauthPkg = pkgs.xauth or pkgs.xorg.xauth;
  xrdbPkg = pkgs.xrdb or pkgs.xorg.xrdb;
  xsetrootPkg = pkgs.xsetroot or pkgs.xorg.xsetroot;
  startxPath = "${xinitPkg}/bin:${xauthPkg}/bin:${xrdbPkg}/bin:${pkgs.util-linux}/bin";

  # Pre-create the per-PID xauth file so xauth doesn't print
  # "file ... does not exist" before startx generates it. bash's $$ is
  # preserved across exec, so the touched file matches startx's PID.
  #
  # A lone Meta tap opening the launcher is a KWin modifier-only shortcut,
  # and kwin_x11 6.6 has no modifier-only support at all (libkwin-x11 carries
  # no ModifierOnlyShortcuts code; only kwin_wayland does), so on X11 the tap
  # did nothing. xcape restores it: a Super tap with no other key emits
  # Alt+F1, which Plasma binds to "Activate Application Launcher" alongside
  # Meta. Super held as a modifier is untouched. X11-only by construction —
  # it runs inside this X server's client and exits with it — so the Wayland
  # session, where KWin already handles the tap, never gets a second toggle.
  plasma-x11-client = pkgs.writeShellScript "plasma-x11-client" ''
    ${pkgs.xcape}/bin/xcape -e 'Super_L=Alt_L|F1;Super_R=Alt_L|F1'
    exec ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-x11 "$@"
  '';

  start-plasma-x11 = pkgs.writeShellScriptBin "start-plasma-x11" ''
    export PATH="${startxPath}:$PATH"
    touch "$HOME/.serverauth.$$"
    exec ${xinitPkg}/bin/startx ${plasma-x11-client} "$@"
  '';

  # LeftWM session — split into two scripts to avoid shell-quoting hell.
  #
  # The OUTER script (`leftwm-xinitrc`) is what startx execs. It sets up
  # X-only env vars (GDK_BACKEND, fixed SSH_AUTH_SOCK), joins the session
  # bus, and runs the INNER script.
  #
  # The INNER script (`leftwm-session-inner`) spawns the autostart services
  # in the background and execs leftwm.
  #
  # Which session bus: the systemd USER bus ($XDG_RUNTIME_DIR/bus), the one
  # every other session uses. eww (GTK) fails to initialise without a session
  # bus, but greetd does not export DBUS_SESSION_BUS_ADDRESS, so this script
  # sets it. It used to run `dbus-run-session` instead, and that PRIVATE bus
  # broke everything that talks to the Secret Service: the gnome-keyring that
  # pam_gnome_keyring unlocked at login lives on the user bus, so on the
  # private one `org.freedesktop.secrets` either did not exist or
  # D-Bus-activated a second, locked daemon. That is what made
  # steelbore-keyring-check report "no default collection" and gitway-add
  # (which reads its biometric-enrolled passphrase through oo7 on the session
  # bus) hang with no prompt. dbus-run-session stays only as the fallback for
  # a login with no user manager.
  #
  # Why GDK_BACKEND=x11: forces eww/dunst onto X11 without probing
  # Wayland (we're under leftwm, X11-only).
  #
  # leftwm's own `themes/current/up` handles picom, dunst, and eww
  # (modules/desktops/leftwm.nix); session bring-up here is minimal.
  leftwm-session-inner = pkgs.writeShellScript "leftwm-session-inner" ''
    ${pkgs.numlockx}/bin/numlockx on &
    ${
      gitway.packages.${pkgs.stdenv.hostPlatform.system}.default
    }/bin/gitway-add "$HOME/.ssh/id_ed25519" &
    # Polkit authentication agent. Niri spawns one via spawn-at-startup
    # (users/mj/niri.nix); LeftWM had NONE, so every polkit-mediated action
    # here failed with no dialog at all — including `fprintd-enroll`, which
    # needs net.reactivated.fprint.device.enroll, and udisks mounts and
    # Flatpak installs.
    #
    # Spawned here rather than from the theme's `up` script
    # (modules/desktops/leftwm.nix): `up` re-runs on EVERY LoadTheme, and this
    # very script issues one a second from now, so an agent placed there would
    # accumulate one process per theme load. polkit-gnome is GTK3, which is
    # correct for LeftWM's X11 session.
    ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 &
    # Diagnose the keyring before any browser can mint a fresh Safe Storage
    # key off a broken one. Read-only; exits non-zero and notifies on trouble.
    # The delay lets pam_gnome_keyring's daemon settle first.
    ( sleep 5 ; steelbore-keyring-check ) &
    # Idle lock + blank, and lock before suspend (CONSTRAINTS.md #45).
    # gtklock is Wayland-only (ext-session-lock), so X sessions lock with
    # i3lock. steelbore-x-idle (modules/desktops/shared.nix) arms the X
    # server's screensaver at 300 s and DPMS off at 360 s, or clears both
    # while Caffeine is on; xss-lock runs i3lock when the screensaver fires,
    # on `loginctl lock-session` (Ctrl+Alt+L) and before sleep. --nofork
    # with --transfer-sleep-lock: i3lock releases xss-lock's sleep delay
    # once the lock is up, so suspend never outruns the lock. Started here,
    # not in the theme's `up` script, for the polkit agent's reason above.
    # -e: an empty Enter is not a failed attempt (no fingerprint here; see
    # the i3lock entry in modules/hardware/fingerprint.nix).
    steelbore-x-idle
    ${pkgs.xss-lock}/bin/xss-lock --transfer-sleep-lock -- \
      ${pkgs.i3lock}/bin/i3lock --nofork --ignore-empty-password \
        --show-failed-attempts --color='${lib.removePrefix "#" steelborePalette.background}' &
    # After leftwm is up, force-apply the Steelbore theme and re-set the
    # root background. Both calls must happen AFTER leftwm starts:
    #
    # - leftwm 0.5.4 does not auto-load themes/current/theme.ron on
    #   session start; without LoadTheme the focused border falls back
    #   to leftwm's hardcoded red.
    # - leftwm clobbers the root window background on startup to its
    #   default grey (#333333); the wallpaper must be set AFTER leftwm or
    #   it gets overwritten and gaps between tiled windows show as grey.
    #
    # The wallpaper is the same loose file Niri shows (users/mj/niri.nix),
    # not Nix-managed; if it is ever missing, fall back to the solid
    # background-role fill, exactly as Niri does. --no-fehbg: nothing
    # reads ~/.fehbg, so don't write it.
    #
    # The one-second sleep gives leftwm's IPC socket and root grab
    # time to settle.
    (
      sleep 1
      ${pkgs.leftwm}/bin/leftwm-command "LoadTheme $HOME/.config/leftwm/themes/current/theme.ron"
      ${pkgs.feh}/bin/feh --no-fehbg --bg-fill "$HOME/Pictures/Wallpapers/Steelbore/ChatGPT_Image_2026-09-30_16-46-13.png" \
        || ${xsetrootPkg}/bin/xsetroot -solid '${steelborePalette.background}'
    ) &
    exec ${pkgs.leftwm}/bin/leftwm
  '';

  leftwm-xinitrc = pkgs.writeShellScript "leftwm-xinitrc" ''
    export GDK_BACKEND=x11
    # Chromium-family Flatpaks (Chrome, Brave, Opera) and Electron apps read
    # XDG_SESSION_TYPE to choose the ozone backend. Without this they probe
    # WAYLAND_DISPLAY and crash because there is no Wayland compositor under
    # LeftWM. ELECTRON_OZONE_PLATFORM_HINT covers Electron 28+.
    export XDG_SESSION_TYPE=x11
    export ELECTRON_OZONE_PLATFORM_HINT=x11
    # Silence AT-SPI D-Bus errors in X11-only sessions (no a11y bridge running).
    export NO_AT_BRIDGE=1
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gitway-agent.sock"
    # XDG_CURRENT_DESKTOP routes xdg-desktop-portal's per-DE config to
    # the GTK appearance backend (see xdg.portal.config.leftwm in
    # modules/theme/dark-mode.nix). Without it, the portal falls
    # through to `common`, which under multi-DE configPackages can
    # resolve appearance to a non-existent backend; libadwaita then
    # silently launches light.
    export XDG_CURRENT_DESKTOP=leftwm
    if [ -S "$XDG_RUNTIME_DIR/bus" ]; then
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
      # D-Bus-activated services (gcr-prompter for keyring unlocks, portals,
      # polkit dialogs) start from the user manager's environment, so they
      # need this session's display to draw on. Only display-scoped names
      # are imported, and they are withdrawn again when leftwm exits, so a
      # later Wayland session on the same user manager does not inherit a
      # dead DISPLAY.
      #
      # systemd only, never `dbus-update-activation-environment`: that also
      # writes the bus's own activation environment, which D-Bus offers no
      # way to unset, so a dead DISPLAY would outlive the session. With
      # dbus-broker (NixOS's bus) every activation goes through a systemd
      # unit, so the systemd environment is the one that counts.
      # Only names that are set: startx may leave XAUTHORITY unset.
      imported=""
      for v in DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE; do
        printenv "$v" >/dev/null && imported="$imported $v"
      done
      # shellcheck disable=SC2086
      ${pkgs.systemd}/bin/systemctl --user import-environment $imported
      ${leftwm-session-inner}
      status=$?
      # shellcheck disable=SC2086
      ${pkgs.systemd}/bin/systemctl --user unset-environment $imported
      exit "$status"
    fi
    exec ${pkgs.dbus}/bin/dbus-run-session -- ${leftwm-session-inner}
  '';

  start-leftwm = pkgs.writeShellScriptBin "start-leftwm" ''
    export PATH="${startxPath}:$PATH"
    touch "$HOME/.serverauth.$$"
    exec ${xinitPkg}/bin/startx ${leftwm-xinitrc} "$@"
  '';

  leftwm-xsession = mkXSession {
    name = "LeftWM";
    sessionName = "leftwm";
    exec = "${start-leftwm}/bin/start-leftwm";
    comment = "LeftWM tiling window manager (X11)";
  };

  plasma-x11-xsession = mkXSession {
    name = "Plasma X11";
    sessionName = "plasma-x11-startx";
    exec = "${start-plasma-x11}/bin/start-plasma-x11";
    comment = "KDE Plasma 6 (X11, started via startx)";
  };

  # Hide the upstream gnome-wayland.desktop alias — it's a duplicate of
  # gnome.desktop with only a different localized Name. Listed first in
  # sessionPackages so symlinkJoin's first-wins merge keeps our shadow.
  # GNOME X11 is not added back: gnome-session 49 ships no xsessions/
  # directory; reintroducing it would require pinning an older release
  # which is out of scope for Bravais.
  gnome-wayland-hidden =
    pkgs.runCommand "gnome-wayland-hidden"
      {
        passthru.providedSessions = [ "gnome-wayland" ];
      }
      ''
        mkdir -p $out/share/wayland-sessions
        cat > $out/share/wayland-sessions/gnome-wayland.desktop <<EOF
        [Desktop Entry]
        Type=Application
        Name=GNOME on Wayland (hidden)
        NoDisplay=true
        Hidden=true
        Exec=true
        EOF
      '';

  # Hide the upstream plasmax11.desktop — its Exec runs `startplasma-x11`
  # directly without bringing up Xorg, so under greetd it crashes with
  # "$DISPLAY is not set". Our plasma-x11-xsession (started via startx)
  # is the working entry. Same first-wins symlinkJoin trick as the GNOME
  # shadow above.
  plasmax11-hidden =
    pkgs.runCommand "plasmax11-hidden"
      {
        passthru.providedSessions = [ "plasmax11" ];
      }
      ''
        mkdir -p $out/share/xsessions
        cat > $out/share/xsessions/plasmax11.desktop <<EOF
        [Desktop Entry]
        Type=XSession
        Name=Plasma (X11) (hidden)
        NoDisplay=true
        Hidden=true
        Exec=true
        EOF
      '';
in
{
  # greetd display manager with tuigreet
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # tuigreet renders --time-format through chrono's strftime.
        #
        # The offset is DERIVED, not hardcoded: %:z renders the running
        # system's own UTC offset, so this line stays correct by itself if
        # time.timeZone (modules/core/locale.nix) ever changes, and across a
        # DST transition in any zone that has one. Asia/Bahrain has none — one
        # transition in its entire tzdata history, +04 -> +03 on 1972-06-01 —
        # so a literal "UTC+3" would have been stable too, but it would have
        # been a second place to remember when editing the timezone.
        #
        # The other two specifiers are the wrong shape: %Z renders a bare
        # "+03" and %z an unpunctuated "+0300". %:z is the only one that reads
        # as an offset, at the cost of "UTC+03:00" rather than "UTC+3".
        #
        # Labelling the offset is what makes the greeter's local time
        # unambiguous rather than merely local (Standard §14.3, which permits
        # local time as a human-facing companion).
        #
        # X sessions go to --xsessions, NOT --sessions: tuigreet stamps every
        # --sessions entry XDG_SESSION_TYPE=wayland, so Plasma X11 started
        # believing it was on Wayland — kded, plasmashell and kcminit each
        # logged "Failed to create wl_display", and Orca refused to start.
        # --xsessions makes it x11. --no-xsession-wrapper because every Exec
        # there already runs startx (start-leftwm, start-plasma-x11); the
        # default wrapper would start a second X server around it.
        #
        # The greeting is the identity banner (lib/identity.nix), never a
        # literal here; escapeShellArg single-quotes it so a future banner
        # with a quote, `$` or backslash cannot break the command line greetd
        # hands to its shell.
        command = ''
          ${pkgs.tuigreet}/bin/tuigreet \
            --time \
            --time-format "%Y-%m-%d %H:%M:%S UTC%:z" \
            --remember \
            --remember-session \
            --asterisks \
            --greeting ${lib.escapeShellArg steelboreIdentity.banner} \
            --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions \
            --xsessions ${config.services.displayManager.sessionData.desktops}/share/xsessions \
            --no-xsession-wrapper
        '';
        user = "greeter";
      };
    };
  };

  # Pin the default session. Required because we enable several desktops at
  # once and more than one upstream module now claims this option at the same
  # priority: plasma6.nix sets `mkDefault "plasma"` and niri.nix (added on
  # nixos-unstable) sets `mkDefault "niri"`, which collide with
  # "conflicting definition values" and fail evaluation. A plain definition
  # (priority 100) outranks both mkDefaults — no mkForce needed. Niri is the
  # primary session here. tuigreet itself reads `--sessions`, not this option,
  # and `--remember-session` still wins for the returning user; this only
  # settles the module-system conflict and the sessionNames assertion.
  services.displayManager.defaultSession = "niri";

  # Ensure session packages are registered.
  # GNOME sessions are registered automatically via services.desktopManager.gnome.enable.
  # LeftWM is registered via our own leftwm-xsession (NOT
  # services.xserver.windowManager.leftwm.enable — that path generates an
  # xsession whose Exec runs leftwm directly without an X server, which
  # crash-loops under greetd).
  services.displayManager.sessionPackages = [
    # Listed first so symlinkJoin's first-wins merge keeps our overrides
    # over the upstream packages' duplicates/broken entries.
    gnome-wayland-hidden
    plasmax11-hidden
  ]
  ++ (with pkgs; [
    niri
    cosmic-session
    ion-shell-session
    nushell-session
    brush-session
  ])
  ++ [
    mjsh-session
    leftwm-xsession
    plasma-x11-xsession
  ];

  # Available sessions for greetd environments
  # All desktops share a unified `start-<de>` naming scheme.
  environment.etc."greetd/environments".text = ''
    start-niri
    start-cosmic
    start-plasma
    start-plasma-x11
    start-gnome
    start-leftwm
    nu
    brush
    ion
    ${config.users.users.${primaryUser}.shell}
  '';

  environment.systemPackages =
    with pkgs;
    [
      tuigreet
    ]
    ++ [
      start-gnome
      start-plasma
      start-plasma-x11
      start-niri
      start-leftwm
    ];

  # PAM configuration for greetd
  security.pam.services.greetd.enableGnomeKeyring = true;
}
