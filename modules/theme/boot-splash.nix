# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — boot splash: Fairing (default) or Plymouth
#
# `steelbore.boot.splash.provider` picks one of two splashes; both cannot run,
# because Fairing's module refuses Plymouth (FRN-SRS-091).
#
# fairing — Spacecraft Software's Rust splash (the `fairing` flake input,
#   `steelbore.fairing`). Draws from the systemd initrd, through switch-root,
#   until greetd starts; asks for disk passphrases in the splash; Escape shows
#   the journal; a shutdown splash at poweroff and reboot. It needs the systemd
#   initrd, which this module turns on. Nothing requires its units, so a splash
#   that fails never stops a boot.
#
# plymouth — the Steelbore Plymouth theme (pkgs/steelbore-plymouth), kept as
#   the fallback: one word here brings it back.
#
# Either renders on simpledrm (built into the XanMod kernel, up from the first
# kernel second); i915 loads in stage 2 and takes the display over, which may
# show as a brief flicker. Do NOT add i915 to the initrd for "early KMS"
# (Fairing's `kmsModules`): it drags in ~6 MiB of already-compressed firmware
# for every Intel GPU generation and breaks the ESP budget (#43).
{
  config,
  lib,
  pkgs,
  steelborePalette,
  ...
}:

let
  cfg = config.steelbore.boot.splash;

  theme = (import ../../pkgs { inherit pkgs; }).steelbore-plymouth.override {
    background = steelborePalette.convert.srgbaChannels steelborePalette.background;
  };
in
{
  options.steelbore.boot.splash = {
    enable = lib.mkEnableOption "the Steelbore boot splash";

    provider = lib.mkOption {
      type = lib.types.enum [
        "fairing"
        "plymouth"
      ];
      default = "fairing";
      description = ''
        Which splash draws the boot. `fairing` is Spacecraft Software's Rust
        splash (`steelbore.fairing`, from the `fairing` flake input);
        `plymouth` is the Steelbore Plymouth theme.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # Keep kernel and udev chatter off the splash; errors still reach the
        # journal. `quiet` also silences the initrd's own stage messages.
        boot.consoleLogLevel = 3;
        boot.initrd.verbose = false;
        boot.kernelParams = [
          "udev.log_level=3"
          # `auto` flips to "yes" on a slow job, which is exactly the
          # "Stopping ..." / "A stop job is running" text that covered the
          # shutdown splash. The journal keeps every status line.
          "systemd.show_status=false"
          "rd.systemd.show_status=false"
        ];

        # Keep the shutdown splash on screen until the power goes (constraint
        # #51), whichever splash draws it. Pivoting into the shutdown ramfs
        # resets /dev/console to text mode, which hands the screen back to the
        # kernel console and its "Failed to unmount /run/shutdown/mounts/..."
        # lines. Plymouth's plymouthd-fd-escrow holds the last frame through
        # systemd-shutdown; Fairing draws until systemd-shutdown's final kill.
        # The root is plain ext4 with no LUKS, LVM or MD to detach, so
        # systemd-shutdown's remount read-only plus sync is all the ramfs
        # added here. Turn it back on for a LUKS, LVM, MD or ZFS root.
        systemd.shutdownRamfs.enable = false;
      }

      (lib.mkIf (cfg.provider == "fairing") {
        # The module adds `quiet splash`, simpledrm and evdev to the initrd,
        # and installs `fairing` for `fairing preview` and `theme check`. Its
        # handoff paints greetd's VT (services.greetd.settings.terminal.vt,
        # set by Gantry's module) with the theme canvas before letting go.
        steelbore.fairing.enable = true;
        boot.initrd.systemd.enable = true;
      })

      (lib.mkIf (cfg.provider == "plymouth") {
        boot.plymouth = {
          enable = true;
          theme = theme.themeName;
          themePackages = [ theme ];
        };

        boot.kernelParams = [
          "quiet"
          "splash"
        ];
      })
    ]
  );
}
