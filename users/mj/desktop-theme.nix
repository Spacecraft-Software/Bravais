# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: GTK/Qt theming, cursor, dconf, MIME defaults, DE glue
# Split from home.nix in Phase D (elegance plan 3.1); zero behavior change.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Default web browser.
  #
  # To change the default browser, edit BOTH of the following to point at the
  # new app's `.desktop` id (find it under any of these dirs:
  #   ~/.local/share/applications, /run/current-system/sw/share/applications,
  #   ~/.local/share/flatpak/exports/share/applications — Flatpak ids look like
  #   `com.google.Chrome.desktop`, `org.mozilla.firefox.desktop`):
  #
  #   1. `xdg.mimeApps.defaultApplications` below — writes ~/.config/mimeapps.list,
  #      the declarative source of truth consulted by xdg-open, Niri, and the
  #      desktop portals. HM owns this file (conflicts backed up to
  #      mimeapps.list.backup), so do NOT hand-edit it — change it here.
  #   2. `BROWSER` in `home.sessionVariables` (shell.nix) — for CLI tools
  #      that open URLs via $BROWSER. Verified to reach all four shells
  #      (Nushell, Ion, Brush, Bash): the greetd session sources
  #      hm-session-vars.sh at login, and every WM-spawned shell inherits it.
  #
  # After editing, `nixos-rebuild switch` makes both live. To set them
  # immediately in an already-running session without a rebuild (optional —
  # the rebuild re-asserts the same values, so this only avoids a relogin):
  #   xdg-settings set default-web-browser com.google.Chrome.desktop
  #   xdg-mime default com.google.Chrome.desktop x-scheme-handler/http
  #   xdg-mime default com.google.Chrome.desktop x-scheme-handler/https
  #   xdg-mime default com.google.Chrome.desktop text/html
  # Verify with: xdg-settings get default-web-browser

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "com.google.Chrome.desktop";
      "x-scheme-handler/http" = "com.google.Chrome.desktop";
      "x-scheme-handler/https" = "com.google.Chrome.desktop";
      "x-scheme-handler/about" = "com.google.Chrome.desktop";
      "x-scheme-handler/unknown" = "com.google.Chrome.desktop";
    }
    # Default image viewer — oculante (Rust, GPU-accelerated, editing +
    # RAW/PSD/EXR). All types below are declared in oculante.desktop's
    # MimeType. genAttrs maps each → the same handler.
    // (lib.genAttrs [
      "image/png"
      "image/jpeg"
      "image/gif"
      "image/webp"
      "image/bmp"
      "image/tiff"
      "image/svg+xml"
      "image/avif"
      "image/heic"
      "image/jxl"
      "image/jp2"
      "image/vnd.microsoft.icon"
      "image/x-tga"
      "image/x-exr"
      "application/vnd.adobe.photoshop" # PSD
      "image/x-adobe-dng" # RAW
      "image/x-canon-cr2"
      "image/x-nikon-nef"
      "image/x-sony-arw"
      "image/x-fuji-raf"
    ] (_: "oculante.desktop"));
  };

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
      color-scheme = "prefer-dark";
      gtk-theme = "adw-gtk3-dark";
      icon-theme = "Papirus-Dark";
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
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    # HM 25.11 deprecates the legacy gtk4.theme default at
    # home.stateVersion >= "26.05" (it becomes null and HM stops writing
    # gtk-theme-name into ~/.config/gtk-4.0/settings.ini). Bind it
    # explicitly to keep the legacy behavior across the upgrade and
    # silence the activation warning.
    gtk4.theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
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
    # `style.name` selects the widget style; -dark gives dark chrome
    # immediately rather than relying on color-scheme inference.
    style.name = "adwaita-dark";
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
