# Flatpak (Flathub) — mostly GUI apps (Band B, tier 6)

Permanent, user-local install (no sudo with `--user`). Flathub is the
default remote. **Strongly biased toward GUI applications** — most
CLI tools are not on Flathub. Only use Flatpak when a confirmed app-id
exists for the tool you need.

> **Consent gate.** This is a durable change to the user's machine — an app
> plus, often, a multi-hundred-megabyte runtime. Propose it: the command, the
> install path (`~/.local/share/flatpak/`), the download size if you know it,
> the removal command (`flatpak uninstall --user <app-id>`), and any needed
> sandbox override. Then **wait for the go-ahead**.
>
> **Always pass `-y`.** The agent's shell has no TTY, so an unattended
> `flatpak install` hangs on its confirmation prompt.
>
> **Declarative equivalent:** `services.flatpak` / the Home Manager Flatpak
> module can declare the app-id in the host config. See
> [declarative.md](declarative.md).

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
permanent manager (Band B in the priority chain; AppImage and Snap rank
below it).
