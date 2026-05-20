# Flatpak (Flathub) — mostly GUI apps

Permanent, user-local install (no sudo with `--user`). Flathub is the
default remote. **Strongly biased toward GUI applications** — most
CLI tools are not on Flathub. Only use Flatpak when a confirmed app-id
exists for the tool you need.

## Syntax

```bash
# Install from Flathub (user-local)
flatpak install --user -y flathub <app-id>

# Run
flatpak run <app-id> [<args>]
```

### Key notes

- **App-ids are reverse-DNS**: `org.inkscape.Inkscape`, `org.gimp.GIMP`,
  `com.github.tchx84.Flatseal`.
- The `--user` flag installs into `~/.local/share/flatpak/` — no sudo.
  Without `--user`, Flatpak defaults to a system-wide install that does
  need root.
- Flatpak apps run sandboxed. They may not see files outside their
  declared filesystem permissions unless overridden.
- For CLI-first tasks, Guix/Nix/Cargo/Homebrew will almost always be a
  better fit. Reach for Flatpak only when the tool is specifically a
  desktop GUI app.

## Examples

Most useful Flatpak entries are GUI apps. Example invocations:

```bash
# Image editor
flatpak install --user -y flathub org.gimp.GIMP
flatpak run org.gimp.GIMP

# Vector graphics
flatpak install --user -y flathub org.inkscape.Inkscape
flatpak run org.inkscape.Inkscape

# Browser
flatpak install --user -y flathub org.mozilla.firefox
flatpak run org.mozilla.firefox

# Generic pattern for any app
flatpak install --user -y flathub <app-id>
flatpak run <app-id>
```

## Extras

### Ensure Flathub remote is configured

```bash
flatpak remote-add --if-not-exists --user flathub \
  https://flathub.org/repo/flathub.flatpakrepo
```

### Override sandboxing (e.g. grant home-directory access)

```bash
flatpak override --user --filesystem=home <app-id>

# Revoke the override
flatpak override --user --reset <app-id>
```

### List installed flatpaks and their permissions

```bash
flatpak list --user
flatpak info <app-id>
```

### Update installed flatpaks

```bash
flatpak update --user
```

## Lookup

- Online: <https://flathub.org/>
- CLI: `flatpak search <term>`
- See [lookup.md](lookup.md) for details.

## Cleanup

```bash
flatpak uninstall --user <app-id>

# Remove unused runtimes too
flatpak uninstall --user --unused
```

Tell the user what was installed and how to remove it — Flatpak is a
permanent manager (tier 5 in the priority chain).
