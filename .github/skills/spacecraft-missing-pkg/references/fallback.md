# Cleanup & Fallback Guidance

## Cleanup summary

Band A leaves nothing to clean up — the Guix/Nix stores are garbage-collected
on the user's own schedule, and the one-shot runners (`npx`/`uvx`) only
populate a throwaway cache. Band C (declarative) needs no separate uninstall
either: removing the line and rebuilding removes the tool. The Band B
(imperative) managers are the ones that leave something behind:

| Manager  | Remove a package | Scope |
|----------|------------------|-------|
| Cargo    | `cargo uninstall <crate>` | User-local (`~/.cargo/bin/`) |
| Homebrew | `brew uninstall <formula>` | User-local (brew prefix) |
| Flatpak  | `flatpak uninstall --user <app-id>` | User-local (`~/.local/share/flatpak/`) |
| AppImage | `rm <cache>/<tool>.AppImage` (and `rm -rf <cache>/squashfs-root` if extracted) | The file you downloaded |
| Snap     | `! sudo snap remove <pkg>` (or `--purge` to wipe data) — hand-off | System-wide |

**Give the removal command up front, as part of the proposal — not afterward.**
On the user's own machine, "here's what I already installed" is too late; the
consent gate is what makes the change reversible in practice.

---

## When the package isn't in any manager in the chain

If lookups across Guix, Nix, the one-shot runners, Cargo, Homebrew, Flatpak,
AppImage, and Snap all come up empty:

1. **Re-check the ephemeral tiers first.** `npx`/`uvx` are Band A tier 3, not a
   fallback — a tool published to npm or PyPI should have been provisioned
   there, bootstrapping the runtime via `guix shell node -- npx --yes <pkg>` if
   needed. Revisit [oneshot.md](oneshot.md) before concluding it is
   unavailable. Likewise re-check the nixpkgs attribute path: dotted paths
   (`nodePackages.<x>`, `python3Packages.<x>`) miss a naive top-level search.
2. **Rule out a network problem** (below) before concluding the package does
   not exist — an unreachable substituter looks exactly like a missing package
   if you only read the exit code.
3. **If it's a Rust crate not yet on crates.io**, a Git source is an option —
   consent-gated like any other durable install:
   ```bash
   cargo install --git https://github.com/<owner>/<repo>
   ```
4. **If upstream ships a release binary or `*.AppImage`** but it's in no
   manager, that download is the remaining option — see
   [appimage.md](appimage.md). Verify the checksum; download into the XDG
   cache.
5. **Consider packaging it declaratively.** On a Nix host, a small derivation
   (`pkgs.stdenv.mkDerivation`, `buildGoModule`, `rustPlatform.buildRustPackage`,
   `appimageTools.wrapType2`) in the user's own config is often cleaner than an
   imperative install, and it is tracked. Propose it; see
   [declarative.md](declarative.md) and the `spacecraft-nix-guidelines` skill.
6. **Report the gap** with the searches you ran and the URLs you consulted, so
   the user can double-check or report the missing package upstream.

---

## When the network is the problem

A local host may be offline, behind a proxy, or unable to reach a binary cache.
Symptoms: `unable to download`, `Could not resolve host`, a `nix-shell` that
stalls fetching from `cache.nixos.org`, `npx` failing to reach the registry.

**Report it — do not cascade down the chain.** Dropping from Nix to Homebrew to
Snap does not help when every tier needs the same network. Say what failed,
show the error, and ask whether the user wants to retry, configure a proxy, or
proceed without the tool.

One exception worth a single attempt: if the package is already in the local
Nix/Guix store, an ephemeral run may still succeed offline.

---

## Hard prohibitions

Do **not** fall back to:

- **System-distro managers:** `apt`, `dnf`, `yum`, `pacman`, `zypper`,
  `emerge`, `xbps`. They require root, write to `/usr`, and leave durable,
  hard-to-reverse changes.
- **Imperative installs on a declaratively managed host:** `nix-env -i`,
  `nix profile install`, `guix install`. They shadow the host's config and
  survive rebuilds as drift. Band C exists so this is never necessary — see
  [declarative.md](declarative.md).
- **Global language package installs:** `pip install` outside a venv,
  `npm install -g`, `gem install` without a user prefix.
- **Vendor install scripts piped into a shell:** `curl … | sh`. Unreviewable,
  unpinned, and typically writes to several places at once.
- **`sudo`, in any form.** Hand privileged commands to the user.
- **Editing shell rc files** (`.bashrc`, `.profile`, `config.nu`) to add a
  `PATH` entry or alias.

If a user explicitly requests one of the above anyway, explain the skill's
policy, document the exact command they would need to run, and let them make
the call — it is their machine.
