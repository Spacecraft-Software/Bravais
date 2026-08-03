# Snap (`snap install`) — last resort, hand-off only (Band B, tier 8)

Permanent, **system-wide** install. **Requires root.** Ubuntu-centric but
available on other distros via the `snapd` daemon. Last resort in the
priority chain: prefer any higher-ranked manager that has the package.

> **The agent never runs this.** Snap installs need `sudo`, and the agent's
> shell has neither privileges nor a TTY to answer a password prompt — the
> command would simply hang. Snap is always a **hand-off**: give the user the
> exact command, say why you can't run it, and continue from what they report
> back. There is no declarative equivalent; on a Nix or Guix host, a
> `home.packages` entry ([declarative.md](declarative.md)) is almost always the
> better answer.

## Syntax — the commands you hand to the user

In Claude Code the user runs these in-session by prefixing `!`:

```
! sudo snap install <pkg>

! sudo snap install --classic <pkg>      # CLIs needing host access
```

Then they (or you, once installed) run it:

```bash
snap run <pkg> [<args>]

# Or, if the snap auto-aliases its binary onto PATH:
<pkg> <args>
```

Read-only `snap` subcommands (`snap find`, `snap info`, `snap list`) need no
root — the agent may run those directly to check availability and confinement
before proposing anything.

### Key notes

- **Root is mandatory for install, refresh, revert, and remove.** Every one of
  those is a hand-off. Never attempt them, never prompt for a password.
- Many snaps are community-maintained with no upstream endorsement.
  Check upstream project docs before choosing Snap over another
  manager — e.g. `ripgrep` upstream explicitly discourages the snap.
- **Strict confinement** (default) isolates the snap from the host.
  **Classic confinement** (`--classic`) gives the snap full host access
  and is required for many developer CLIs.
- Snap binaries are often namespaced (`snap-pkg.binary`) but most
  publishers alias the plain name onto PATH.

## Examples

Generic hand-off patterns (verify any specific package on
<https://snapcraft.io/> first — that check needs no root):

```
# Strict-confinement CLI
! sudo snap install <pkg>

# Classic-confinement CLI (e.g. editors, IDEs, compilers)
! sudo snap install --classic <pkg>

# A specific channel (edge, beta, candidate, stable)
! sudo snap install <pkg> --channel=edge
```

Once the user confirms the install landed, the agent can run it:

```bash
snap run <pkg> --version
```

## Extras

### Find and inspect without installing (no root — agent may run these)

```bash
snap find <term>
snap info <pkg>
```

Useful fields from `snap info`: `channels:`, `confinement:`, `publisher:`.

### List installed snaps

```bash
snap list
```

### Refresh (update) snaps — hand-off, needs root

```
! sudo snap refresh                 # all snaps
! sudo snap refresh <pkg>           # one snap
! sudo snap refresh <pkg> --channel=<channel>  # switch channels
```

### Revert to a previous revision — hand-off, needs root

```
! sudo snap revert <pkg>
```

## Lookup

- Online: <https://snapcraft.io/>
  - Direct page pattern: `https://snapcraft.io/<n>`
- CLI: `snap find <term>`
- See [lookup.md](lookup.md) for details.

## Cleanup — hand-off, needs root

```
! sudo snap remove <pkg>

# Also remove saved snapshots of the snap's data
! sudo snap remove --purge <pkg>
```

Give the user the removal command at the same time you propose the install —
Snap is permanent, system-wide, and the last-resort tier in the chain.
