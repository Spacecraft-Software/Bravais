# Cleanup & Fallback Guidance

## Cleanup summary

Ephemeral managers (Guix, Nix) need no cleanup — the store is
garbage-collected later by `guix gc` / `nix-collect-garbage`. The permanent
managers do:

| Manager  | Remove a package                                   | Scope           |
|----------|----------------------------------------------------|-----------------|
| Cargo    | `cargo uninstall <crate>`                          | User-local      |
| Homebrew | `brew uninstall <formula>`                         | User-local      |
| Flatpak  | `flatpak uninstall --user <app-id>`                | User-local      |
| Snap     | `sudo snap remove <pkg>` (or `--purge` to wipe data) | System-wide     |

**Whenever a permanent manager (tier 3 or later) was used, tell the user
what was installed and how to remove it.**

---

## When the package isn't in any of the six managers

If lookups across Guix, Nix, Cargo, Homebrew, Flatpak, and Snap all come up
empty:

1. **If it's a Rust crate not yet on crates.io**, try a Git source:
   ```bash
   cargo install --git https://github.com/<owner>/<repo>
   ```
2. **If it's a Node / Python / other-ecosystem package**, propose a
   temporary language-native ad-hoc environment rather than installing
   permanently:
   ```bash
   # Node (one-shot via npx)
   guix shell node -- npx <pkg>
   nix-shell -p nodejs --run "npx <pkg>"

   # Python (one-shot via uv)
   uvx <pkg>                        # if uv is installed
   guix shell uv -- uvx <pkg>       # otherwise
   ```
3. **Report the gap to the user** with the searches you performed and the
   URLs you consulted — makes it easy to double-check or report the
   missing package upstream.

## Hard prohibitions

Do **not** fall back to:

- **System-distro managers:** `apt`, `dnf`, `yum`, `pacman`, `zypper`,
  `emerge`, `xbps`, etc. These require root, touch `/usr`, and leave
  durable, hard-to-reverse changes.
- **Global language package installs:** `pip install` outside a venv,
  `npm install -g`, `gem install` without a user prefix.

If a user explicitly requests one of the above anyway, explain the
skill's policy, document the command they would need to run, and let
them make the call.
