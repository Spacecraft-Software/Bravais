# AppImage — download-and-run application bundle

Band B, tier 7 — **after Flatpak, before Snap.** An AppImage is a single
self-contained executable that carries the app and its dependencies. There is
**no manager to install and nothing to detect with `command -v`**: you reach for
AppImage when upstream publishes an `*.AppImage` release asset, the host can run
it, and no higher-ranked manager (Guix → … → Flatpak) has the tool.

Mostly a GUI / portable-app format, like Flatpak and Snap. A single AppImage
*can* be used disposably (download, run, delete), but it ranks in Band B
because it is a packaged-application download reached only when the ephemeral
and earlier permanent managers come up empty.

> **Consent gate.** A download is a durable change to the user's disk. Propose
> it: the URL you will fetch, the path it lands in, the size, whether a
> checksum is published, and the removal command. Then **wait for the
> go-ahead**. Delete the file after a genuine one-off run and say so.
>
> **Declarative equivalent:** nixpkgs' `appimageTools.wrapType2` can wrap an
> AppImage into a tracked package for `home.packages`. See
> [declarative.md](declarative.md).

## Syntax

Download into the XDG cache, not blindly into `/tmp` — `/tmp` may be a
small tmpfs, may be shared, and may be swept mid-session.

```bash
# 0. Pick a cache directory under the user's home
cache="${XDG_CACHE_HOME:-$HOME/.cache}/spacecraft-missing-pkg"
mkdir -p "$cache"

# 1. Download the upstream release asset
curl -fL -o "$cache/<tool>.AppImage" <release-asset-url>

# 2. Make it executable
chmod +x "$cache/<tool>.AppImage"

# 3. Run it
"$cache/<tool>.AppImage" [<args>]
```

### No-FUSE fallback (extract instead of mount)

AppImages mount themselves through **FUSE** at runtime. On hosts without FUSE
(many containers, some minimal systems) the direct run fails with a
`dlopen(): error loading libfuse.so.2` / `fuse: failed to … /dev/fuse` message.
Extract and run the payload directly instead:

```bash
cd "$cache" && ./<tool>.AppImage --appimage-extract   # unpacks ./squashfs-root/
"$cache/squashfs-root/AppRun" [<args>]
```

Extract inside the cache directory, not the user's repo — `squashfs-root/` is
a few hundred files and will show up in `git status` if you unpack it in a
working tree.

(Or run the upstream binary found under `squashfs-root/usr/bin/`.) The
`--appimage-extract` route needs no FUSE and no root.

### Key notes

- **No sudo, no system files.** Everything lives in the file you downloaded (and
  `./squashfs-root/` if you extracted). Nothing touches `/usr`.
- **Verify the source.** Download only from the project's official releases
  (GitHub Releases, the project site). Prefer an asset with a published checksum
  or signature and verify it when one is offered:

  ```bash
  curl -fLO "<release-asset-url>.sha256"
  sha256sum -c "<tool>.AppImage.sha256"
  ```
- **Integration is optional.** Tools like `appimaged` / AppImageLauncher can
  register an AppImage with the desktop, but that creates durable state — skip it
  for a one-off run.

## Lookup

- Upstream project releases (GitHub Releases / the project's download page) are
  the authoritative source for the correct `*.AppImage` asset URL.
- Catalogue: <https://appimage.github.io/> (AppImageHub) — searchable index of
  apps that ship an AppImage.

Confirm an `*.AppImage` asset actually exists for the tool before choosing this
tier; if none does, fall through to Snap. See [lookup.md](lookup.md).

## Cleanup

```bash
rm -f  "$cache/<tool>.AppImage"     # the bundle itself
rm -rf "$cache/squashfs-root"       # only if you used --appimage-extract
```

Because the whole app is one file, removing it removes the install completely —
no leftover system state. Tell the user where the file landed so they can delete
it (or keep it) at will.
