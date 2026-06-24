# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Memory headroom & OOM resilience
#
# Why: the machine has 31 GB RAM and *zero* swap, and systemd-oomd — though active —
# monitored no cgroups, so it never acted. A heavy `cargo`/`rustc`/`mold` build could
# spike memory past RAM with no cushion and no working guard, and the kernel's hard kill
# took the zellij server (and its panes, including the Claude Code session) down with it.
# This module gives the system memory headroom plus a name-aware OOM guard that kills the
# *build* instead of the multiplexer.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # zram — ~16 GB of compressed, RAM-backed swap (zstd). Absorbs transient build spikes;
  # far faster than disk swap, no SSD wear. Highest priority so it fills before any future
  # disk swap. (A previous zram was added imperatively and lost on reboot — this persists it.)
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  # earlyoom — the PRIMARY guard. It triggers on a free-memory threshold (faster than oomd's
  # sustained-pressure window) and SIGTERMs, then SIGKILLs, the *preferred* process: it kills
  # the build (rustc/cargo/mold/…) by name and avoids the multiplexer and the session.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 8; # SIGTERM the preferred memory hog below 8% free RAM
    freeMemKillThreshold = 4; # escalate to SIGKILL below 4%
    freeSwapThreshold = 10;
    enableNotifications = true; # desktop notification names the killed process
    extraArgs = [
      "--prefer"
      "(^|/)(cargo|rustc|cc1|cc1plus|lld|ld|mold|rust-analyzer|clippy-driver|cargo-clippy)$"
      "--avoid"
      "(^|/)(zellij|claude|node|nu|bash|sshd|systemd|niri|Xwayland)$"
    ];
  };

  # systemd-oomd — pressure-based BACKSTOP. It was monitoring zero cgroups; enable it on the
  # root and all user slices so sustained memory-pressure stalls are caught after earlyoom.
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableUserSlices = true;
  };

  # Diagnostics — so a recurrence is *capturable* (the last one left no proof: no persistent
  # evidence of what was killed). Both are NixOS defaults, affirmed here so they can't
  # silently regress.
  services.journald.storage = "persistent";
  systemd.coredump.enable = true;
}
