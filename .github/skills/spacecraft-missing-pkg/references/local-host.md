# Running on the user's own machine

This skill executes on a real, long-lived host — the user's workstation, not a
disposable sandbox. Three consequences drive everything below: durable changes
outlive the session, the agent's shell is not the user's shell, and the agent's
shell has no TTY and no privileges.

---

## 1. Verify before you provision

`command -v <tool>` failing in the agent's shell does **not** prove the tool is
missing. Rule out each of these first.

### Shell-level definitions are invisible

Nushell `def`/`alias` and Bash functions/aliases never appear on `PATH`. A user
whose `config.nu` defines `def deploy [] { … }` has a working `deploy` that no
`command -v` will ever find.

### The agent's `PATH` is narrower than the user's

Directories commonly absent from a non-interactive, non-login shell:

```
~/.nix-profile/bin
/etc/profiles/per-user/$USER/bin
/run/current-system/sw/bin
~/.local/bin
~/.cargo/bin
/opt/homebrew/bin
/home/linuxbrew/.linuxbrew/bin
```

Probe them directly before concluding:

```sh
for d in "$HOME/.nix-profile/bin" "/etc/profiles/per-user/$USER/bin" \
         /run/current-system/sw/bin "$HOME/.local/bin" "$HOME/.cargo/bin" \
         /opt/homebrew/bin /home/linuxbrew/.linuxbrew/bin; do
  [ -x "$d/<tool>" ] && echo "found: $d/<tool>"
done
```

### A project env may already carry it

If the repo has `flake.nix`, `shell.nix`, or `.envrc`, the tool may exist
inside the activated environment and nowhere else:

```sh
nix develop -c command -v <tool>
nix-shell --run "command -v <tool>"
```

### A preferred alternative may be installed instead

`spacecraft-cli-preference` maps legacy tools to modern replacements — `rg` for
`grep`, `fd` for `find`, `bat` for `cat`, `jaq` for `jq`, `xh` for `curl`. The
mapped tool is frequently present when the one you reached for is not. Check
the mapping before provisioning anything.

### When still ambiguous, ask

Do not guess. In Claude Code the user can run a command in-session by prefixing
it with `!`, and its output lands in the conversation:

```
! which <tool>
! type <tool>
```

---

## 2. Non-interactive constraints and hand-off

The agent's shell has **no TTY and no privileges**. These hang or fail rather
than work:

| Blocker | Symptom | Fix |
|---|---|---|
| `sudo` | Waits forever on a password prompt | Hand off — never run it |
| `npx <pkg>` (uncached) | "Ok to proceed? (y)" prompt | `npx --yes <pkg>` |
| `flatpak install` | Confirmation prompt | `flatpak install --user -y …` |
| GPG / keychain / SSH passphrase | Silent hang | Hand off |
| Anything opening a pager | Blocks on `less` | `--no-pager`, or pipe to `cat` |
| Interactive TUI installers | Garbled output, hang | Hand off |

### Hand-off format

Give the user the exact command, say why you can't run it, and say what you
will do with the result:

> `snap` needs root and I can't run `sudo`. Run this and tell me what it says:
>
> ```
> ! sudo snap install --classic <pkg>
> ```
>
> Once it's in, I'll pick back up at the lint step.

Then stop. Do not attempt the privileged command, and do not sit on a hung
prompt waiting for it to resolve itself.

---

## 3. Shell syntax on this host

Standard §7 makes **Nushell, Ion, Brush, and Bash** all first-class. Consult
`spacecraft-cli-shell` before writing any shell command — it is the syntax
authority; this file only records what bites the provisioner.

- **Nushell:** external commands take a `^` prefix (`^rg`, `^nix`), and inline
  environment assignment (`VAR=x cmd`) is not valid syntax. Route anything
  needing POSIX semantics through `^bash -c '…'`.
- **Ion / PowerShell:** `&&` chaining, `$()` substitution, and `[ ]` tests
  differ. Prefer separate calls over chained one-liners.
- **Portability:** keep any snippet that ships in the repo (a `.envrc`, a
  Makefile recipe, a README example) in the POSIX sh subset — no `[[ ]]`,
  `(( ))`, `<(…)`, `${var^^}`, or Bash arrays.

Nu-native form of the Step 1 detection block:

```nu
let managers = [guix nix nix-shell npx uvx cargo brew flatpak snap]
let found = ($managers | where {|m| (which $m | is-not-empty) })
print $"Provisioners: ($found | str join ' ')"

let decl = ([nixos-rebuild home-manager darwin-rebuild guix direnv]
            | where {|m| (which $m | is-not-empty) })
print $"Declarative: ($decl | str join ' ')"
```

---

## 4. Ephemeral environments do not survive a tool call

Each Bash invocation is a separate process. A `guix shell` or `nix-shell`
environment exists only for the command that created it:

```sh
# WRONG — the second call is a new process; the tool is gone
nix-shell -p ripgrep
rg 'TODO' src/                 # command not found

# RIGHT — wrap each invocation
nix-shell -p ripgrep --run "rg 'TODO' src/"
nix run nixpkgs#ripgrep -- 'TODO' src/
```

If you find yourself writing the same wrapper three times, that is the signal
to propose a project env — see [project-env.md](project-env.md).

---

## 5. Download hygiene

Downloads land on the user's real disk.

- **Use the XDG cache, not `/tmp` blindly.** `/tmp` may be a tmpfs sized for
  small files, may be shared, and may be swept mid-session:

  ```sh
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/spacecraft-missing-pkg"
  mkdir -p "$cache"
  curl -fL -o "$cache/<tool>.AppImage" "<url>"
  ```

- **Verify what you fetched.** Prefer a release with a published checksum or
  signature and check it:

  ```sh
  curl -fLO "<url>.sha256"
  sha256sum -c "<tool>.AppImage.sha256"
  ```

- **Download only from upstream** — the project's own releases page, not a
  mirror or aggregator.
- **Report the path** so the user can keep or delete the file, and delete it
  yourself after a genuine one-off.

---

## 6. Offline and unreachable substituters

A local host may be offline, behind a proxy, or unable to reach a binary cache.
Symptoms: `unable to download`, `Could not resolve host`, a `nix-shell` that
stalls fetching from `cache.nixos.org`, `npx` failing to reach the registry.

**Report it — do not cascade.** Falling from Nix to Homebrew to Snap does not
help when the problem is the network: every tier needs it. Say what failed,
show the error, and ask whether the user wants to retry, configure a proxy, or
proceed without the tool.

A partial exception: if the package is already in the local Nix/Guix store, an
ephemeral run may still succeed offline. Worth one attempt before reporting.

---

## 7. Disclosure ledger

Any durable change gets reported in this shape — before it runs, as the
proposal, and again after the user approves and it completes:

| Field | Example |
|---|---|
| **What** | `cargo install hyperfine` |
| **Where** | `~/.cargo/bin/hyperfine` (~8 MB, compiled from source) |
| **Undo** | `cargo uninstall hyperfine` |
| **Drift** | Not tracked by the host's Home Manager config — `home.packages` is the tracked alternative |

If the change touches a file (a config edit, a `.envrc`, a `flake.nix`), name
the file and show the diff. If it is a repo change, note that it needs a commit
under that repo's rules.
