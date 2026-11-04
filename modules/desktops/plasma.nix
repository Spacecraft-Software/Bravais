# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — KDE Plasma 6 Desktop Environment (Wayland and X11)
{
  config,
  lib,
  pkgs,
  escapepod,
  ...
}:
let
  escapePodPackage = escapepod.packages.${pkgs.stdenv.hostPlatform.system}.default;
  superTapConfig = (pkgs.formats.toml { }).generate "escapepod-plasma-super-tap.toml" {
    tap_timeout_ms = 500;
    # F13 is XF86Tools in the default XKB map (the ThinkPad's settings key).
    # F19 remains F19 and is reserved as the launcher trigger in plasma.nix.
    dual_role =
      map
        (key: {
          inherit key;
          tap = "KEY_F19";
        })
        [
          "KEY_LEFTMETA"
          "KEY_RIGHTMETA"
        ];
  };
in
{
  options.steelbore.desktops.plasma = {
    enable = lib.mkEnableOption "KDE Plasma 6 Desktop Environment (Wayland)";
  };

  config = lib.mkIf config.steelbore.desktops.plasma.enable {
    # Enable Plasma 6
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm.enable = lib.mkDefault false; # Use greetd instead
    services.displayManager.sddm.wayland.enable = lib.mkDefault false;

    # X server required for XWayland support
    services.xserver.enable = true;

    # KWin X11 lacks Wayland's modifier-only shortcut handling. Observe X11
    # events without grabbing keyboards; the mouse daemon keeps its evdev job.
    # Plasma imports XDG_SESSION_TYPE and DISPLAY into its user manager before
    # starting plasma-core.target. Never run this in the Wayland session.
    environment.etc."escapepod/plasma-super-tap.toml".source = superTapConfig;
    systemd.user.services.escapepod-plasma-super-tap = {
      description = "Escape Pod lone Super key for the Plasma X11 application menu";
      wantedBy = [ "plasma-core.target" ];
      partOf = [ "plasma-core.target" ];
      after = [ "graphical-session-pre.target" ];
      unitConfig.ConditionEnvironment = "XDG_SESSION_TYPE=x11";
      serviceConfig = {
        ExecStartPre = "${lib.getExe escapePodPackage} config check --config ${superTapConfig} --json";
        ExecStart = lib.escapeShellArgs [
          (lib.getExe escapePodPackage)
          "daemon"
          "run"
          "--backend"
          "x11"
          "--config"
          (toString superTapConfig)
          "--yes"
          "--json"
        ];
        Restart = "on-failure";
        RestartSec = 2;
        RestartPreventExitStatus = "6";
        TimeoutStopSec = 5;
      };
    };

    # Portal routing — services.desktopManager.plasma6 already registers
    # xdg-desktop-portal-kde (+ -gtk). Add the explicit per-DE config so
    # multi-DE installs route interfaces deterministically when Plasma is
    # the active session, mirroring gnome.nix and cosmic.nix (plan 2.4).
    xdg.portal.config.kde = {
      default = [
        "kde"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
    };

    # Avoid askpass conflicts when multiple desktop modules are enabled.
    programs.ssh.askPassword = lib.mkForce "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

    environment.systemPackages = with pkgs; [
      # kdePackages.plasma-browser-integration — already installed by the Plasma 6
      # module; per-browser hosts live in users/mj/browser-integration.nix
      kdePackages.kdeconnect-kde
      kdePackages.plasma-systemmonitor
      kdePackages.filelight
      kdePackages.kcalc
      kdePackages.ark
      kdePackages.kate
      # kdePackages.xdg-desktop-portal-kde

      # Wallet
      kdePackages.kwalletmanager # Wallet management GUI
      kdePackages.kwallet # KWallet daemon
      pinentry-qt # GPG pinentry for KDE dialogs

      # Tiling
      kdePackages.krohnkite # KWin tiling script
    ];

    # Exclude KDE bloat
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      oxygen
      elisa
      khelpcenter
    ];
  };
}
