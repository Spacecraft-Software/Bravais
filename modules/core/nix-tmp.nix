# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Loop-mounted /mnt/nix-tmp for Nix builder TMPDIR
#
# Move Nix's working set off the system disk and onto a 40 GiB ext4
# loop image on the user's Expansion external drive. udisks2 mounts
# the drive at /run/media/mj/Expansion after login (no UUID-based
# fileSystems entry available — the drive is removable). A systemd
# path unit watches that directory; when it appears, a oneshot
# service creates the .img if missing, mkfs.ext4's it, mounts it
# loop-back at /mnt/nix-tmp, and chmods 1777.
#
# nix-daemon's TMPDIR is set to /mnt/nix-tmp unconditionally. With
# the drive unplugged, /mnt/nix-tmp is the empty local tmpfiles dir
# and builds fall back to the system disk transparently. With the
# drive plugged in, the same path resolves to the loop ext4.
#
# The path unit triggers on a DIRECTORY existing, which does not imply
# anything is mounted there — so the service verifies the mount itself
# before creating an 80 GiB image. See the guard in ExecStart: without
# it, a stale udisks mountpoint puts the whole build scratch in RAM.
#
# Mode is 0755 root:root (NOT 1777). Nix 2.31+ refuses a world-writable
# `build-dir` for security; only nix-daemon (root) needs to write here,
# and it creates per-build subdirs as the nixbld* sandbox users itself.
# This dir is *not* a user-level TMPDIR.
{
  primaryUser,
  pkgs,
  ...
}:

let
  imgPath = "/run/media/${primaryUser}/Expansion/nix-tmp.img";
  mountAt = "/mnt/nix-tmp";
  # 80 GiB chosen because 40 GiB couldn't fit deno-2.7.13 + LTO +
  # codegen-units=1 + parallel cargo for sibling crates
  # (deno_core/deno_runtime/test_server/dcore) — peak ~50–55 GiB.
  # Sparse, so the .img only consumes what builds actually write.
  # Note: this only governs *fresh* image creation by the oneshot
  # service below; an already-existing .img must be grown imperatively
  # via truncate + e2fsck + resize2fs (see CLAUDE.md / Round 11 plan).
  imgSize = "80G";
in
{
  # The age field is load-bearing, not cosmetic. `-` (never clean) let the
  # fallback path leak without bound: with the Expansion drive unplugged,
  # ${mountAt} is a plain directory on the system disk and nix-daemon builds
  # there "transparently" — but a build killed part-way leaves its scratch tree
  # behind, and nothing removes it. `nix-collect-garbage` does not touch the
  # builder TMPDIR, so the rebuild's own GC step reports success while the disk
  # keeps filling. Observed 2026-08-19: 13 orphaned trees dating back to
  # 2026-06-01 held ~146 GiB, leaving 759 MiB free on a 203 GiB partition, and
  # the next build failed with "No space left on device" during installPhase.
  #
  # 10d is chosen for headroom, not for reclaim speed: systemd-tmpfiles ages
  # each file individually, an active build touches its files continuously, and
  # nothing here builds for even one day — so this cannot race a live build. It
  # bounds the leak at ten days' worth instead of unbounded. Applies equally
  # when the loop image IS mounted, where the same orphans accumulate on the
  # external drive.
  systemd.tmpfiles.rules = [ "d ${mountAt} 0755 root root 10d" ];

  systemd.paths.nix-tmp-loop = {
    description = "Watch for Expansion drive auto-mount, then bring up nix-tmp loop";
    pathConfig = {
      PathExists = "/run/media/${primaryUser}/Expansion";
      Unit = "nix-tmp-loop.service";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.nix-tmp-loop = {
    description = "Create and mount Nix builder loop image at ${mountAt}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "nix-tmp-loop-up" ''
        set -eu
        drive="/run/media/${primaryUser}/Expansion"

        # ── Guard: the drive must actually be MOUNTED ────────────────────
        # PathExists is satisfied by a leftover empty DIRECTORY just as
        # readily as by a real mount. udisks2 leaves the mountpoint behind
        # after an unclean removal, and on the next plug-in it finds that
        # name taken and mounts the drive at "Expansion1" instead — so the
        # decoy can outlive the drive indefinitely.
        #
        # Unguarded, the image below is then created on whatever backs that
        # path, which is /run: a tmpfs, i.e. RAM. That is not hypothetical —
        # it filled /run to 100%, drove the machine into OOM, and left the
        # loop ext4 with an aborted journal remounted read-only, which fails
        # every subsequent build with "Read-only file system".
        #
        # udisks creates the directory a moment before it mounts, so wait
        # briefly rather than racing it.
        for _ in $(${pkgs.coreutils}/bin/seq 1 20); do
          ${pkgs.util-linux}/bin/mountpoint -q "$drive" && break
          ${pkgs.coreutils}/bin/sleep 0.5
        done

        if ! ${pkgs.util-linux}/bin/mountpoint -q "$drive"; then
          echo "nix-tmp: $drive exists but nothing is mounted there." >&2
          echo "nix-tmp: refusing to create the build image — it would land on" >&2
          echo "nix-tmp: the tmpfs backing /run (RAM). Builds fall back to /." >&2
          echo "nix-tmp: check for a stale mountpoint (the drive may be at" >&2
          echo "nix-tmp: ''${drive}1); remove the empty decoy dir and replug." >&2
          exit 1
        fi

        # Belt and braces: a real mount must still not be memory-backed.
        fstype="$(${pkgs.util-linux}/bin/findmnt -no FSTYPE "$drive")"
        case "$fstype" in
          tmpfs | ramfs | devtmpfs)
            echo "nix-tmp: $drive is $fstype (memory-backed) — refusing." >&2
            exit 1
            ;;
        esac

        # ── Image ────────────────────────────────────────────────────────
        # Only ever creates ${imgPath}. Nothing else on the drive is read,
        # moved or removed.
        if [ ! -f "${imgPath}" ]; then
          ${pkgs.coreutils}/bin/truncate -s ${imgSize} "${imgPath}"
          ${pkgs.e2fsprogs}/bin/mkfs.ext4 -F "${imgPath}"
        fi

        if ! ${pkgs.util-linux}/bin/mountpoint -q "${mountAt}"; then
          # Preen the scratch image before mounting. An aborted journal
          # (what a full backing store leaves behind) otherwise remounts
          # read-only on first write and every build fails until it is
          # repaired by hand. Scoped to our own image file; exit codes 1/2
          # mean "fixed", so only a genuine failure is worth reporting.
          ${pkgs.e2fsprogs}/bin/e2fsck -p "${imgPath}" || \
            echo "nix-tmp: e2fsck returned $? for ${imgPath}; mounting anyway" >&2
          ${pkgs.util-linux}/bin/mount -o loop "${imgPath}" "${mountAt}"
        fi
        ${pkgs.coreutils}/bin/chmod 0755 "${mountAt}"
      '';
      ExecStop = pkgs.writeShellScript "nix-tmp-loop-down" ''
        ${pkgs.util-linux}/bin/mountpoint -q "${mountAt}" && \
          ${pkgs.util-linux}/bin/umount "${mountAt}" || true
      '';
    };
  };

  systemd.services.nix-daemon.environment.TMPDIR = mountAt;

  # nix.conf-level build-dir. Forces every nix client to use the loop
  # for build scratch — root callers (sudo nixos-rebuild) build
  # in-process and bypass the daemon's TMPDIR drop-in above, falling
  # back to /tmp on / and disk-out'ing on big builds (deno+LTO etc).
  # Falls back transparently to the empty tmpfiles dir on / when the
  # loop isn't mounted — same semantics as TMPDIR. Requires the dir
  # to be 0755 (not 1777) per nix 2.31+ security check.
  nix.settings.build-dir = mountAt;
}
