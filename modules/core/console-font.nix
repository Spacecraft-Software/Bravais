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
#
# The same takeover has a second edge. When fbcon binds, udev starts
# `systemd-vconsole-setup.service` again, and this time its `setfont`
# succeeds: Terminus 24 lands on the greeter's VT a second or two after
# Gantry loaded its katakana copy of the console font, wiping the katakana
# and shrinking the grid from 240x67 to 160x45 under the running UI (seen
# 2026-10-25: Gantry's font load at 18:15:31, the re-run at 18:15:33). The
# service therefore skips itself while greetd is up; the VTs a user switches
# to still get the font from the getty hook above.
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

  # ExecCondition: exit 1 means "skip, not a failure". Runs at boot before
  # greetd exists (keymap applies, font fails harmlessly), and is skipped for
  # the takeover re-run and for `reload-systemd-vconsole-setup` on a switch.
  systemd.services.systemd-vconsole-setup.serviceConfig.ExecCondition = pkgs.writeShellScript "vconsole-not-under-greeter" ''
    state=$(${config.systemd.package}/bin/systemctl is-active greetd.service)
    [ "$state" != active ] && [ "$state" != activating ]
  '';
}
