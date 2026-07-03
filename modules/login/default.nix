# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — greetd + tuigreet Login Manager
{
  config,
  pkgs,
  steelborePalette,
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
  # stable/unstable split as xfce4-terminal (CLAUDE.md known constraint #5).
  xinitPkg = pkgs.xinit or pkgs.xorg.xinit;
  xauthPkg = pkgs.xauth or pkgs.xorg.xauth;
  xrdbPkg = pkgs.xrdb or pkgs.xorg.xrdb;
  xsetrootPkg = pkgs.xsetroot or pkgs.xorg.xsetroot;
  startxPath = "${xinitPkg}/bin:${xauthPkg}/bin:${xrdbPkg}/bin:${pkgs.util-linux}/bin";

  # Pre-create the per-PID xauth file so xauth doesn't print
  # "file ... does not exist" before startx generates it. bash's $$ is
  # preserved across exec, so the touched file matches startx's PID.
  start-plasma-x11 = pkgs.writeShellScriptBin "start-plasma-x11" ''
    export PATH="${startxPath}:$PATH"
    touch "$HOME/.serverauth.$$"
    exec ${xinitPkg}/bin/startx ${pkgs.kdePackages.plasma-workspace}/bin/startplasma-x11 "$@"
  '';

  # LeftWM session — split into two scripts to avoid shell-quoting hell.
  #
  # The OUTER script (`leftwm-xinitrc`) is what startx execs. It sets up
  # X-only env vars (GDK_BACKEND, fixed SSH_AUTH_SOCK) then exec's
  # `dbus-run-session` wrapping the INNER script.
  #
  # The INNER script (`leftwm-session-inner`) runs under a fresh dbus
  # session. It spawns the autostart services in the background and
  # execs leftwm.
  #
  # Why dbus-run-session: eww (GTK4) fails to initialize GTK without a
  # session bus; ~/.cache/eww/eww_*.log shows "Failed to initialize
  # GTK" otherwise. dbus-run-session also gives picom/dunst a bus for
  # proper shutdown.
  #
  # Why GDK_BACKEND=x11: forces eww/dunst onto X11 without probing
  # Wayland (we're under leftwm, X11-only).
  #
  # leftwm's own `themes/current/up` is left as an `exit 0` stub
  # (modules/desktops/leftwm.nix); session bring-up runs here, not
  # there.
  leftwm-session-inner = pkgs.writeShellScript "leftwm-session-inner" ''
    ${pkgs.picom}/bin/picom &
    ${pkgs.dunst}/bin/dunst &
    ${pkgs.eww}/bin/eww open bar &
    ${pkgs.numlockx}/bin/numlockx on &
    ${
      gitway.packages.${pkgs.stdenv.hostPlatform.system}.default
    }/bin/gitway-add "$HOME/.ssh/id_ed25519" &
    # After leftwm is up, force-apply the Steelbore theme and re-set the
    # root background. Both calls must happen AFTER leftwm starts:
    #
    # - leftwm 0.5.4 does not auto-load themes/current/theme.ron on
    #   session start; without LoadTheme the focused border falls back
    #   to leftwm's hardcoded red.
    # - leftwm clobbers the root window background on startup to its
    #   default grey (#333333); xsetroot must run AFTER leftwm or its
    #   color (voidNavy) gets overwritten and gaps between tiled
    #   windows show as grey instead.
    #
    # The one-second sleep gives leftwm's IPC socket and root grab
    # time to settle.
    (
      sleep 1
      ${pkgs.leftwm}/bin/leftwm-command "LoadTheme $HOME/.config/leftwm/themes/current/theme.ron"
      ${xsetrootPkg}/bin/xsetroot -solid '${steelborePalette.voidNavy}'
    ) &
    exec ${pkgs.leftwm}/bin/leftwm
  '';

  leftwm-xinitrc = pkgs.writeShellScript "leftwm-xinitrc" ''
    export GDK_BACKEND=x11
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gitway-agent.sock"
    # XDG_CURRENT_DESKTOP routes xdg-desktop-portal's per-DE config to
    # the GTK appearance backend (see xdg.portal.config.leftwm in
    # modules/theme/dark-mode.nix). Without it, the portal falls
    # through to `common`, which under multi-DE configPackages can
    # resolve appearance to a non-existent backend; libadwaita then
    # silently launches light.
    export XDG_CURRENT_DESKTOP=leftwm
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
        command = ''
          ${pkgs.tuigreet}/bin/tuigreet \
            --time \
            --time-format "%Y-%m-%d %H:%M:%S" \
            --remember \
            --remember-session \
            --asterisks \
            --greeting "STEELBORE :: BRAVAIS" \
            --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions:${config.services.displayManager.sessionData.desktops}/share/xsessions
        '';
        user = "greeter";
      };
    };
  };

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
