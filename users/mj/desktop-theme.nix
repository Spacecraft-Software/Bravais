# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: GTK/Qt theming, cursor, dconf, MIME defaults, DE glue
# Split from home.nix in Phase D (elegance plan 3.1); zero behavior change.
{
  config,
  lib,
  pkgs,
  steelborePalette,
  ...
}:

let
  # ── §11.6.5: the platform preference must agree with the palette ──────────
  # Standard §11.6.5 requires an OS to keep the platform's color-scheme
  # preference in agreement with the declared palette's polarity. These keys
  # used to be hard-coded to dark, which was correct for every palette except
  # one: `steelbore-navywhite` is light-canvas (§11.3.4), and a NavyWhite
  # system telling toolkits `prefer-dark` is exactly the inconsistency that
  # clause forbids — third-party applications read only the platform
  # preference, so they would render dark chrome around a light interface.
  #
  # `org.gnome.desktop.interface.color-scheme` is the key that matters: both
  # xdg-desktop-portal-gnome and -gtk serve it as
  # org.freedesktop.appearance.color-scheme to libadwaita apps, which is how a
  # bare Niri/LeftWM session has an appearance preference at all (see
  # modules/theme/dark-mode.nix).
  isLight = steelborePalette.meta.polarity == "light";
  colorScheme = if isLight then "prefer-light" else "prefer-dark";
  gtkThemeName = if isLight then "adw-gtk3" else "adw-gtk3-dark";
  iconThemeName = if isLight then "Papirus-Light" else "Papirus-Dark";
  qtStyleName = if isLight then "adwaita" else "adwaita-dark";
in
{
  # The browser and image-viewer MIME bindings that used to live here moved to
  # ./default-apps.nix, where every handler role is decided in one place:
  #
  #   app set browser <slug>       app candidates browser
  #   app set imageViewer <slug>
  #
  # $BROWSER (shell.nix) reads the same registry entry, so the two can no
  # longer disagree. Handler choices are made in the repo-root
  # default-apps.nix; the MIME lists live in lib/default-apps.nix.

  xdg.configFile = {
    # COSMIC's cosmic-settings-daemon overwrites HM's gtk-4.0/gtk.css
    # with its own `cosmic/dark.css` symlink whenever the theme syncs.
    # On the next nixos-rebuild HM sees a foreign file at the path it
    # expects to own and refuses to activate ("would be clobbered").
    # `force = true` tells HM to overwrite unconditionally; cosmic
    # re-asserts its symlink moments later, producing at most a brief
    # theme flicker right after activation.
    "gtk-4.0/gtk.css".force = true;

    # Suppress gnome-keyring's SSH component so it doesn't override
    # SSH_AUTH_SOCK (which gitway-agent points at /run/user/$UID/gitway-agent.sock
    # via /etc/environment.d/10-gitway-agent.conf). PAM still launches
    # gnome-keyring-daemon for secrets/keyring; this file shadows the system
    # autostart and the daemon honors Hidden=true to skip its SSH agent.
    "autostart/gnome-keyring-ssh.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=SSH Key Agent
      Hidden=true
    '';

    # Suppress IBus autostarts that surface as Wayland-session popups.
    # i18n.inputMethod = ibus (modules/core/locale.nix) is required to
    # silence COSMIC's "no input method configured" notification — that
    # check keys off QT_IM_MODULE / GTK_IM_MODULE / XMODIFIERS, which the
    # option sets globally. The option also installs two autostart files
    # that misbehave under non-GNOME Wayland sessions:
    #   • Panel (Wayland Gtk3) — a tray widget we don't need
    #   • ibus-daemon          — under Niri, the daemon prints its long
    #                            "IBus should be called from the desktop
    #                            session in Wayland..." help text, which
    #                            dunst surfaces as a notification.
    # We shadow both with Hidden=true. ibus-daemon dbus-activates on
    # demand if any client really needs it.
    "autostart/org.freedesktop.IBus.Panel.Wayland.Gtk3.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=IBus Panel (Wayland)
      Hidden=true
    '';

    "autostart/ibus-daemon.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=IBus Daemon
      Hidden=true
    '';

    # COSMIC custom keybinds. cosmic-settings stores user-edited shortcuts
    # in this RON file at ~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom.
    # The COSMIC 1.0-alpha schema supports multiple bindings mapped to the
    # same action, so we ship pairs (Ctrl+Space + Super+Space → input-source
    # switch; Super+Return + Super+T → terminal) here. Note: home-manager
    # makes the file read-only, so future tweaks via the Settings UI silently
    # fail until the binding is also added/removed here.
    "cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom".text = ''
      {
          (
              modifiers: [
                  Ctrl,
              ],
              key: "space",
          ): System(InputSourceSwitch),
          (
              modifiers: [
                  Super,
              ],
              key: "space",
          ): System(InputSourceSwitch),
          (
              modifiers: [
                  Super,
              ],
          ): System(AppLibrary),
          (
              modifiers: [
                  Super,
              ],
              key: "d",
          ): System(Launcher),
          (
              modifiers: [
                  Super,
              ],
              key: "slash",
          ): Disable,
          (
              modifiers: [
                  Super,
              ],
              key: "Return",
          ): System(Terminal),
          (
              modifiers: [
                  Super,
              ],
              key: "t",
          ): System(Terminal),
      }
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # KWIN — Enable Krohnkite tiling script
    # ═══════════════════════════════════════════════════════════════════════════
    "kwinrc".text = ''
      [Plugins]
      krohnkiteEnabled=true
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # KWALLET — Pre-enable GPG backend
    # The wallet itself must be created manually via KWallet Manager:
    #   File → New Wallet → choose GPG encryption → select your GPG key.
    # ═══════════════════════════════════════════════════════════════════════════
    "kwalletrc".text = ''
      [Wallet]
      Default Wallet=kdewallet
      Enabled=true
      First Use=false

      [gpg]
      use=true
    '';
  };

  dconf.settings = {
    # ── Dark Mode (Niri + LeftWM appearance source) ─────────────────────────
    "org/gnome/desktop/interface" = {
      color-scheme = colorScheme;
      gtk-theme = gtkThemeName;
      icon-theme = iconThemeName;
      cursor-theme = "Bibata-Modern-Classic";
      cursor-size = 24;
      font-name = "Hack Nerd Font 11";
      document-font-name = "Hack Nerd Font 11";
      monospace-font-name = "JetBrainsMono Nerd Font 11";
    };
  };

  # ─── System-wide Dark Mode (Niri + LeftWM) ───────────────────────────────
  # Per-user side of modules/theme/dark-mode.nix. HM's gtk module writes
  # ~/.config/gtk-{3,4}.0/settings.ini with the theme names and
  # gtk-application-prefer-dark-theme=true; it also writes the matching
  # gsettings keys via dconf. The qt module exports QT_QPA_PLATFORMTHEME +
  # QT_STYLE_OVERRIDE through the systemd user env so Qt apps inherit
  # them at process start. Under GNOME/COSMIC/Plasma sessions these are
  # mostly inert — those DEs' own appearance daemons take precedence in
  # their own sessions; this layer "wins" only under Niri / LeftWM.
  gtk = {
    enable = true;
    theme = {
      name = gtkThemeName;
      package = pkgs.adw-gtk3;
    };
    # HM 25.11 deprecates the legacy gtk4.theme default at
    # home.stateVersion >= "26.05" (it becomes null and HM stops writing
    # gtk-theme-name into ~/.config/gtk-4.0/settings.ini). Bind it
    # explicitly to keep the legacy behavior across the upgrade and
    # silence the activation warning.
    gtk4.theme = {
      name = gtkThemeName;
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = iconThemeName;
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    font = {
      name = "Hack Nerd Font";
      size = 11;
    };
  };

  # Force HM to own ~/.gtkrc-2.0 (the gtk2 module writes it at this exact
  # key). DEs in the session blank/rewrite it out-of-band, so HM finds a
  # foreign file on the next switch and — with a stale .backup present —
  # aborts activation ("would be clobbered by backing up"). force overwrites
  # unconditionally with no backup attempt. Same fix as the VSCode flatpak
  # override above. Key must match gtk2's `configLocation` exactly. The gtk2
  # module sets force = false explicitly, so mkForce is needed to override it.
  home.file."${config.home.homeDirectory}/.gtkrc-2.0".force = lib.mkForce true;

  qt = {
    enable = true;
    # `adwaita` brings in adwaita-qt(6) + qadwaitadecorations. HM marks
    # `gnome` (qgnomeplatform) as deprecated in 25.11. `qtct` would need
    # a runtime GUI to configure — not declarative.
    platformTheme.name = "adwaita";
    # `style.name` selects the widget style explicitly rather than relying on
    # color-scheme inference, so it has to follow the palette's polarity too
    # (§11.6.5) — otherwise a light palette gets dark Qt chrome.
    style.name = qtStyleName;
  };

  # Single cursor across X11 + Wayland + GTK + .icons. Bibata ships
  # cursor files for all backends in one package, so enabling every
  # propagation path costs nothing.
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true; # writes ~/.config/gtk-{3,4}.0/settings.ini cursor keys
    x11.enable = true; # writes ~/.Xresources + Xcursor.theme / .size
    dotIcons.enable = true; # writes ~/.icons/default/index.theme (XDG)
  };
}
