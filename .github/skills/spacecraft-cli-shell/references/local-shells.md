# Local execution context — which shell actually runs this?

The per-shell references in this directory answer *how do I write X in shell
Y*. This file answers the question that comes first on a real machine:
**which shell is going to execute this, and can it?**

Three facts drive it:

1. The user's login shell and the agent's shell are usually **different**, and
   neither implies the other.
2. `/bin/sh` is often **not** a strict POSIX shell, so a local run proves far
   less about portability than it appears to.
3. A shell you can write for is not necessarily a shell that is **installed**.

Provisioning belongs to `spacecraft-missing-pkg`; tool choice belongs to
`spacecraft-cli-preference`. This file owns neither.

---

## 1. The probe

Run once per session, cache the result.

```sh
getent passwd "$(id -un)" | awk -F: '{print $NF}'   # the USER's login shell
ps -p "$$" -o comm=; echo "${BASH_VERSION:-}"       # the AGENT's own shell
readlink -f /bin/sh                                 # what `#!/bin/sh` really runs
for s in nu ion brush pwsh ash dash bash zsh; do
  command -v "$s" >/dev/null 2>&1 && echo "have $s" || echo "MISSING $s"
done
```

Nushell equivalent, when you're already inside Nu:

```nu
^getent passwd (^id -un) | split row ':' | last
^readlink -f /proc/(^ps -p $nu.pid -o ppid= | str trim)/exe
^readlink -f /bin/sh
[nu ion brush pwsh ash dash bash zsh] | where {|s| (which $s | is-not-empty) }
```

Two details that matter in the POSIX form:

- **`ps -p "$$" -o comm=`, not `echo "$0"`.** Inside a script `$0` holds the
  script's own path, so it identifies the file rather than the interpreter
  running it. `$0` is only informative for an interactive shell or `sh -c`.
- **The `|| echo MISSING` arm is load-bearing.** A bare `command -v "$s"` in
  the last loop iteration makes the whole snippet exit non-zero whenever that
  shell is absent — which will abort a `set -e` script for no reason.

### Reading the results

| Probe | What it tells you | What it does **not** tell you |
|---|---|---|
| `passwd` last field | The shell the user gets on login — the target for hand-offs | Anything about the agent's shell |
| `$0` / `$BASH_VERSION` | The shell executing the agent's commands right now | The user's preference |
| `readlink -f /bin/sh` | What a `#!/bin/sh` script actually runs here | Whether the script is portable elsewhere |
| `command -v <shell>` | Whether you can *run* something in that shell | Whether you can *write* for it — you always can |
| `$SHELL` | The harness's environment setting | The login shell; on many hosts these disagree |

`$SHELL` is the trap: it is an inherited environment variable, not a
measurement. Use the `passwd` lookup when you need the login shell.

---

## 2. Routing by executor

| Path | Target | Consequence |
|---|---|---|
| Agent runs it via its shell tool | that shell (measure it — Bash in this harness) | Write POSIX; Bash accepts all of it |
| User runs it (`!` prefix, or pasted into their terminal) | their login shell | POSIX may be *invalid* — Nushell and Ion are not POSIX shells |
| Written to a file | the shebang / extension | Independent of both of the above |

Worked examples, on a host whose login shell is Nushell and whose agent shell
is Bash:

```sh
# (a) Agent runs it — plain POSIX, no Nu accommodations, no `^`
fd -e rs | wc -l

# (b) Handed to the user — must parse in Nushell
#     `$(...)` is invalid there; `(...)` is the Nu form
! git switch (git branch --show-current)

# (c) Written to a file — the shebang decides, nothing else does
#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
```

### Where Bash and Nushell diverge in hand-offs

Most commands — `cmd --flag arg` — parse identically in both and need no
special handling. These are the ones that don't:

| Construct | Bash / POSIX | Nushell |
|---|---|---|
| inline env var | `TZ=UTC git log` | `^bash -c 'TZ=UTC git log'`, or `with-env { TZ: "UTC" } { git log }` |
| command substitution | `$(cmd)` | `(cmd)` |
| shadowed external | `zip -qr a.zip d/` | `^zip -qr a.zip d/` |
| `export` | `export FOO=bar` | `$env.FOO = "bar"` |
| `&&` chaining | `a && b` | works, but only when every token is valid Nu — otherwise `^bash -c 'a && b'` |

See [nushell.md](nushell.md) for the full rules on `^`, `with-env`, and
`$env`; [ion.md](ion.md) for the Ion equivalents.

**When the executing shell is unconfirmed,** stay in the common subset, or
give both forms explicitly. Guessing wrong produces a command that fails in a
way the user has to debug.

---

## 3. The `/bin/sh` trap

The single most misleading verification in shell work:

> The script ran fine locally, so it must be portable.

It isn't. `/bin/sh` is a symlink whose target varies by distribution — dash on
Debian/Ubuntu, busybox ash on Alpine, **bash on NixOS and many others**. When
it resolves to bash, every bashism this skill warns about is silently
accepted, and the run tells you nothing.

```sh
readlink -f /bin/sh
# .../bash-5.3p9/bin/bash   → a successful run proves NOTHING about POSIX
# /usr/bin/dash             → a successful run is meaningful evidence
```

### Verifying properly

Static analysis catches most of it, and a strict interpreter catches the rest.
Neither `shellcheck` nor `dash` is installed on many hosts, so run them
ephemerally rather than installing (see `spacecraft-missing-pkg`):

```sh
nix run nixpkgs#shellcheck -- -s sh script.sh    # flags bashisms statically
nix run nixpkgs#dash -- script.sh                # rejects what bash tolerates
guix shell shellcheck -- shellcheck -s sh script.sh
```

`shellcheck -s sh` is the fastest feedback loop and should be the default
gate for any script claiming POSIX compliance. Running under `dash` (or
busybox `sh`) is the stronger signal because it exercises the actual parser.

---

## 4. Interpreter availability

Writing for a shell and running in it are separate questions. Authoring a
`.ion` script on a host with no `ion` is perfectly valid; only the instruction
to **execute** it needs a gate.

| Shell | Commonly present? | If absent |
|---|---|---|
| `bash`, `sh` | Effectively always | — |
| `nu`, `ion`, `brush` | Only where deliberately installed | Provision via `spacecraft-missing-pkg`, or `nix run nixpkgs#nushell` |
| `pwsh` | Rare outside Windows and dev boxes | ditto |
| `dash`, `ash` | **Frequently absent**, despite being the POSIX reference | `nix run nixpkgs#dash` — worth it for verification |
| `zsh` | Common on macOS, patchy on Linux | ditto |

Check `command -v` from the Step 0 probe before suggesting a run.

---

## 5. Non-interactive gotchas

The agent's shell is non-interactive and has no TTY. The failures look like
syntax problems but aren't:

- **No rc files.** `.bashrc`, `.profile`, and `config.nu` are not sourced, so
  the user's aliases, functions, and `PATH` additions **do not exist** for the
  agent. A command that works when the user types it can fail for the agent
  purely because of this. Check it before rewriting the syntax.
- **No TTY.** `read`, password and confirmation prompts, pagers (`less`), job
  control, and full-screen programs hang or produce garbage. Pass
  non-interactive flags where they exist; hand off where they don't.
- **A different `PATH`.** Directories added by the login shell's config are
  missing. Absolute paths, or the probe in `spacecraft-missing-pkg`'s Step 0,
  resolve it.
- **No persistence between invocations.** Each command runs in a fresh
  process: `cd`, `export`, and any activated environment do not survive to the
  next call. Chain them in one invocation, or re-establish state each time.
