---
name: default-apps
description: How to change which program handles a file type or role in the Bravais NixOS config. Use when asked to change the default editor, browser, file manager, image viewer, or terminal editor, or to add an app that is not in nixpkgs yet. Covers the app list/show/candidates/set commands, the role-to-MIME registry in lib/default-apps.nix, drop-ins at apps/<slug>.nix, and the app-registry JSON output.
---

Which program handles what is a registry, shaped exactly like the theme system.
The active choice is **one word per role** in **`default-apps.nix`** at the repo
root; the role→MIME lists and the app catalog live in `lib/default-apps.nix`;
`users/mj/default-apps.nix` is the only consumer.

```sh
app list                  # every role and its active app
app show editor           # the resolved entry + every MIME type it binds
app candidates editor     # every app that can fill the role
app set editor zed        # rewrite default-apps.nix, then `rebuild`
```

Roles: `editor` (GUI — what double-clicking a text file opens), `browser`,
`fileManager`, `imageViewer`, `termEditor` (`$EDITOR`/`$VISUAL`/`git core.editor`
— binds no MIME types). `editor` and `termEditor` are deliberately separate.

**The ROLE owns the MIME list, never the application.** An app's own `MimeType=`
line is not a reliable statement of what it can open (see constraint #22), so
whichever app fills a role inherits the role's complete set. A catalog entry may
set `mimeTypes` to *narrow* the list when it genuinely cannot open everything
(`loupe`, `feh`), but never to widen it — add the type to the role instead.

An app that isn't in nixpkgs yet joins via a **drop-in**: `apps/<slug>.nix`,
filename = slug, merged over the built-in catalog and free to shadow it — the
same semantics as `themes/<slug>.nix`. `apps/README.md` documents every field.
A drop-in that sets `package` installs itself when active, so `app set` is the
only edit needed.

Never hardcode a `.desktop` id, a browser command, or an editor path in a
consumer — thread `steelboreApps` from `specialArgs`/`extraSpecialArgs` and read
`steelboreApps.roles.<role>`. Same rule as §11.4 for palette values. Adding a
second `xdg.mimeApps` block anywhere is the specific mistake this replaced: two
blocks merge silently until the day both name the same type, which is an
eval-time conflict.

The `app-registry` flake output (JSON) is what the `app` command reads; it stays
pkgs-free (the `package`/`exec`/`dbusExec` fields are functions of `pkgs` and
never reach it), so `app list` costs one builtins-only evaluation rather than a
system config.

