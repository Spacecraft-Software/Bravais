# Snap (`snap install`) — last resort

Permanent, **system-wide** install. **Requires sudo.** Ubuntu-centric but
available on other distros via the `snapd` daemon. Last resort in the
priority chain: prefer any higher-ranked manager that has the package.

## Syntax

```bash
# Install (requires sudo)
sudo snap install <pkg>

# Some CLIs need classic confinement to access the host system
sudo snap install --classic <pkg>

# Run
snap run <pkg> [<args>]

# Or, if the snap auto-aliases its binary onto PATH:
<pkg> <args>
```

### Key notes

- **Sudo is mandatory for install.** If this skill is running without
  sudo, report the situation to the user rather than attempting the
  install or prompting.
- Many snaps are community-maintained with no upstream endorsement.
  Check upstream project docs before choosing Snap over another
  manager — e.g. `ripgrep` upstream explicitly discourages the snap.
- **Strict confinement** (default) isolates the snap from the host.
  **Classic confinement** (`--classic`) gives the snap full host access
  and is required for many developer CLIs.
- Snap binaries are often namespaced (`snap-pkg.binary`) but most
  publishers alias the plain name onto PATH.

## Examples

Generic patterns (verify any specific package on <https://snapcraft.io/>):

```bash
# Strict-confinement CLI
sudo snap install <pkg>
snap run <pkg> --version

# Classic-confinement CLI (e.g. editors, IDEs, compilers)
sudo snap install --classic <pkg>
<pkg> --version

# Installing a specific channel (e.g. edge, beta, candidate, stable)
sudo snap install <pkg> --channel=edge
```

## Extras

### Find and inspect without installing

```bash
snap find <term>
snap info <pkg>
```

Useful fields from `snap info`: `channels:`, `confinement:`, `publisher:`.

### List installed snaps

```bash
snap list
```

### Refresh (update) snaps

```bash
sudo snap refresh                 # all snaps
sudo snap refresh <pkg>           # one snap
sudo snap refresh <pkg> --channel=<channel>  # switch channels
```

### Revert to a previous revision

```bash
sudo snap revert <pkg>
```

## Lookup

- Online: <https://snapcraft.io/>
  - Direct page pattern: `https://snapcraft.io/<n>`
- CLI: `snap find <term>`
- See [lookup.md](lookup.md) for details.

## Cleanup

```bash
sudo snap remove <pkg>

# Also remove saved snapshots of the snap's data
sudo snap remove --purge <pkg>
```

Tell the user what was installed and how to remove it — Snap is a
permanent manager (tier 6, last-resort in the priority chain) and is
installed system-wide.
