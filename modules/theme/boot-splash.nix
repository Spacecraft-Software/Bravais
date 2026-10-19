# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Plymouth boot splash (pkgs/steelbore-plymouth)
#
# Plays the boot animation from early initrd until greetd starts (greetd is
# ordered after plymouth-quit-wait.service upstream), and plays the shutdown
# animation at poweroff and reboot — the same theme, branching on the mode.
# The firmware and systemd-boot stages before the kernel cannot show it. It renders on simpledrm (built into the
# XanMod kernel, up from the first kernel second); i915 loads in stage 2 and
# takes the display over, which may show as a brief flicker. Do NOT add i915
# to the initrd for "early KMS": it drags in ~6 MiB of already-compressed
# firmware for every Intel GPU generation and breaks the ESP budget (#43).
{
  config,
  lib,
  pkgs,
  steelborePalette,
  ...
}:

let
  theme = (import ../../pkgs { inherit pkgs; }).steelbore-plymouth.override {
    background = steelborePalette.convert.srgbaChannels steelborePalette.background;
  };
in
{
  options.steelbore.boot.splash = {
    enable = lib.mkEnableOption "the Steelbore Plymouth boot splash";
  };

  config = lib.mkIf config.steelbore.boot.splash.enable {
    boot.plymouth = {
      enable = true;
      theme = theme.themeName;
      themePackages = [ theme ];
    };

    # Keep kernel and udev chatter off the splash; errors still reach the
    # journal. `quiet` also silences the initrd's own stage messages.
    boot.consoleLogLevel = 3;
    boot.initrd.verbose = false;
    boot.kernelParams = [
      "quiet"
      "splash"
      "udev.log_level=3"
      "systemd.show_status=auto"
    ];

    # Keep the shutdown animation's last frame on screen until the power goes
    # (constraint #48). On SIGTERM, plymouthd hands its display to
    # plymouthd-fd-escrow, which survives systemd-shutdown and holds the
    # frame; pivoting into the shutdown ramfs resets /dev/console to text
    # mode, which hands the screen back to the kernel console. The root is
    # plain ext4 with no LUKS, LVM or MD to detach, so systemd-shutdown's
    # remount read-only plus sync is all the ramfs added here.
    systemd.shutdownRamfs.enable = false;
  };
}
