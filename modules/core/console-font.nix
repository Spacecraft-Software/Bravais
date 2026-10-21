# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — the text consoles' font (tty2…tty6, constraint #52)
#
# NixOS 26.05 sets no console font (`console.font = null`), so the TTYs ran on
# the kernel's built-in 8x16 VGA font, small on the ThinkPad's 14" 1080p
# panel. This sets Terminus 24 (12x24, PSF) for every virtual console.
#
# Setting it is not enough. `systemd-vconsole-setup` runs once, early in
# stage 2, and under a quiet boot with a splash the kernel has not yet handed
# the VT to the framebuffer console (fbcon's deferred takeover waits for the
# first thing printed), so the console is still the dummy driver and
# `setfont` fails with ENOSYS ("Function not implemented"). Nothing reports
# it; the font just never applies. Gantry hit the same wall and retries after
# its first frame (Gantry PR #3).
#
# The fix re-applies the font to each VT as its getty starts: logind spawns
# `autovt@ttyN` only when you switch to a VT, by which point the greeter has
# been drawing and fbcon has taken over. `systemd-vconsole-setup /dev/ttyN`
# loads /etc/vconsole.conf's font and keymap onto that one tty; it is the
# very program the boot-time unit runs, so the setting stays single-sourced.
# The leading `-` keeps a failure from ever stopping a login prompt.
{ config, pkgs, ... }:

{
  console = {
    packages = [ pkgs.terminus_font ]; # PSF fonts (ter-v*), the kbd package has none this size
    font = "ter-v24n"; # Terminus 24, regular weight
  };

  # getty@ is also what logind starts as autovt@ttyN (an alias NixOS declares).
  systemd.services."getty@".serviceConfig.ExecStartPre = [
    "-${config.systemd.package}/lib/systemd/systemd-vconsole-setup /dev/%I"
  ];
}
