# Full-disk encryption (LUKS) — analysis

The long form of PRD §16.8 and TODO `L-001`…`L-007`: what the reference machine
(`steelbore-thinkpad`) has on disk, whether LUKS fits the boot budget, the two
ways to convert, and what changes in the boot chain. Nothing here is
implemented yet. Read it before adding the LUKS option or touching the disk.

The disk layout was read from the running machine on 2026-10-21. The initrd
figures were measured again on 2026-11-17, after Fairing replaced Plymouth.

## 1. What is there now

| Partition | Size | Content |
|-----------|------|---------|
| nvme0n1p1 | 200M | ESP, vfat, `/boot` (196 MiB usable) |
| nvme0n1p2 | 16M | Microsoft reserved (Windows leftover) |
| nvme0n1p3 | 73M | NTFS basic data (Windows leftover) |
| nvme0n1p5 | 475.9G | **ext4, label `root`, mounted at `/`** (394G used, 89%) |
| nvme0n1p4 | 754M | Windows recovery (end of disk, leftover) |

- One ext4 filesystem holds everything: no LVM, no separate `/home` or `/nix`.
  `/home` is 155G of the 394G.
- Swap is zram only, so there is no swap partition to encrypt and no hibernation.
- Declared in `hosts/thinkpad/hardware.nix` (`fileSystems."/"` by UUID, ext4).
- Stage 1 is already the **systemd initrd**, which LUKS and TPM2 unlock both need.
- TPM 2.0 is present; Secure Boot is **off** (firmware in setup mode).
- p2 and p3 sit directly after the ESP and before p5, so deleting them would let
  the ESP grow from 196 MiB to about 289 MiB without touching root.

## 2. Does LUKS fit the boot budget? (measured)

Constraint #43 requires `3 × (kernel + initrd) ≤ ~190 MiB` so three generations
fit the ESP. Built from the flake with `extendModules` on 2026-11-17: kernel
7.3.4 (13.6 MiB), Fairing splash.

| Variant | initrd | 3 × (kernel + initrd) |
|---------|--------|-----------------------|
| Today (no LUKS) | 38.8 MiB | 157.4 MiB |
| LUKS, TPM2 stack kept (the default) | 39.1 MiB | 158.1 MiB |
| LUKS, `boot.initrd.systemd.tpm2.enable = false` | 36.1 MiB | 149.3 MiB |

LUKS itself costs about 0.2 MiB, because `systemd-cryptsetup` and libcryptsetup
are already in the systemd initrd. The TPM2 stack (tpm2-tss plus curl, krb5 and
friends) is about 2.9 MiB compressed.

Under Plymouth (measured 2026-10-21, kernel 7.2.11) the same three rows were
47.4, 47.6 and 44.8 MiB, close enough to the ~49 MiB ceiling that turning TPM2
off looked necessary. With Fairing about 10 MiB of headroom remains even with
LUKS and TPM2 kept, so the TPM2 stack can stay. Keeping it also means `L-007`
(TPM2 enrolment) needs no initrd change later.

Re-measure before switching the option on (`L-004`): the kernel and inputs
move every week.

## 3. The two ways to get there

### A. In-place conversion (keeps the install)

From a live USB, with root unmounted and the laptop on AC:

1. `e2fsck -f /dev/nvme0n1p5`
2. `resize2fs /dev/nvme0n1p5 <current size minus 64M>` (shrink so the LUKS2 header fits)
3. `cryptsetup reencrypt --encrypt --type luks2 --reduce-device-size 32M /dev/nvme0n1p5`
4. `cryptsetup open /dev/nvme0n1p5 cryptroot`, then `resize2fs /dev/mapper/cryptroot` (grow back)
5. Mount, switch the option on inside `nixos-enter`, `nixos-rebuild boot`

- LUKS2 reencryption keeps a resilience journal, so a power cut can be resumed,
  but a full backup is still mandatory. Expect tens of minutes for 476G of NVMe.
- The inner ext4 keeps its UUID; only the new LUKS UUID goes into the config.
- Leaves the 196 MiB ESP and the Windows leftovers as they are.

### B. Back up and reinstall with disko (recommended)

- Back up `/home` (155G) and any `/var/lib` state worth keeping. `/nix` comes
  back from the flake.
- Repartition with disko: a **1 GiB ESP**, then LUKS2 → ext4 (or btrfs) for the
  rest, and drop the three Windows leftovers. That retires constraints #42 and
  #43 instead of living at their edge, and leaves room for lanzaboote later.
- Same backup cost as A, since A also needs one. The extra work is the restore.

## 4. Boot chain impact

- **Older generations stop booting** the moment the disk is encrypted, because
  their config points at the plain partition. The live USB is the rescue path
  until a new generation is built.
- The order also bites the other way: if the LUKS config is switched on before
  the disk is converted, the default entry fails to boot. So the Nix change
  sits behind an option that defaults off and is switched on only on
  conversion day.
- **Fairing** (the current splash, `steelbore.boot.splash.provider = "fairing"`)
  answers the passphrase question in the splash through its agent
  (`steelbore.fairing.agent`, on). It types through a fixed US layout, and
  Bravais sets `console.keyMap = "us"`, so it is correct here. Fairing's own VM
  test (`packaging/nixos/tests/luks.nix` in the Fairing repo) covers the prompt.
- **Plymouth** (the fallback provider) asks natively in the systemd initrd;
  simpledrm without i915 is enough to show the prompt.
- **Shutdown ramfs.** `modules/theme/boot-splash.nix` sets
  `systemd.shutdownRamfs.enable = false` so the shutdown splash stays up until
  power-off (constraint #51). That is safe only on a plain ext4 root. With
  LUKS, systemd-shutdown must detach the dm-crypt device after root is
  unmounted, which needs the ramfs, so the LUKS option turns it back on. The
  cost, recorded in #51: the shutdown splash hands over to the text console for
  the last second or two.
- **Gantry / greetd** is unaffected: it starts after the root is unlocked.

## 5. TPM2

- With Secure Boot off, binding only to PCR 7 gives little protection, and
  binding to PCR 4 breaks on every kernel or initrd rebuild, which on NixOS is
  often.
- Recommendation: passphrase now. Add TPM2 later together with lanzaboote and
  Secure Boot: `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7` plus a
  `--recovery-key`, keeping the passphrase slot.
- If TPM-only unlock is ever used, the greeter password becomes the only gate,
  so autologin must stay off.

## 6. The Nix change (not written yet)

A new option, default off, `steelbore.boot.luks.enable` plus `device`:

```nix
boot.initrd.luks.devices.cryptroot = {
  device = "/dev/disk/by-uuid/<LUKS UUID>";
  allowDiscards = true;      # TRIM on NVMe
  bypassWorkqueues = true;   # lower latency on NVMe
};
fileSystems."/".device = "/dev/mapper/cryptroot";
# systemd-shutdown must detach the dm-crypt device (constraint #51).
systemd.shutdownRamfs.enable = true;
```

`boot-splash.nix` sets the ramfs with plain priority, so the LUKS module has to
win explicitly (`lib.mkForce`), or `boot-splash.nix` has to make its `false`
conditional on the option being off. The second is clearer.

With disko (path B) the device facts live in the disko layout instead, and
`hardware.nix` loses its `fileSystems` entries.
