# Execution context — whose machine is this?

`spacecraft-cli-shell`, `spacecraft-cli-preference`, and `spacecraft-missing-pkg`
are written for **the user's own machine**. Agents also run in throwaway VMs,
in hosted containers, and with no shell at all. This file classifies the
context once, before any other probe, and says what changes per mode. It is
shared: identical copies ship in all three skills.

Three facts drive it:

1. A probe measures **the machine it runs on** — which may not be the user's.
2. Mutation rules exist to protect **durable** state; a VM discarded after the
   session has none worth protecting.
3. The user's login shell is only measurable **on the user's host**.

---

## 1. Step −1 — Classify the execution context

| Mode | What it is | Evidence |
|---|---|---|
| **local-host** | The user's own long-lived machine, **including a container that persists on it** — distrobox, toolbox, a local devcontainer. **Default.** | Nix or Guix present; a personal login shell (`nu`, `ion`, `zsh`, `fish`, …); a home under `/home/<user>` for a **personal** account (not a generic cloud account such as `user`, `ubuntu`, `runner`), or bind-mounted from the host — **even with a container signal** |
| **disposable-sandbox** | A VM or container discarded after the session — Claude Code on the web, hosted chat/agent sandboxes | **All** of: a **positive hosted marker** — `CLAUDE_CODE_REMOTE=true`, or the harness's own instructions or the user stating the session runs in a hosted sandbox; no Nix/Guix; no local-container marker; no personal login shell (`nu`, `ion`, `zsh`, `fish`, …). A container signal **never qualifies on its own** |
| **no-execution** | No shell or code tool exists | The tool list itself — nothing can be probed |

Probe, when a shell exists (POSIX sh, `sh -eu`-safe — every test has an
`||` arm):

```sh
echo "remote=${CLAUDE_CODE_REMOTE:-unset} HOME=${HOME:-unset}"
for t in nix guix; do command -v "$t" >/dev/null 2>&1 && echo "have $t" || echo "no $t"; done
u=$(id -un 2>/dev/null) || u=
{ getent passwd "$u" 2>/dev/null || awk -F: -v u="$u" '$1 == u' /etc/passwd 2>/dev/null || true; } \
  | awk -F: '{print "home=" $6, "login=" $NF} END {if (!NR) print "no passwd entry"}'
command -v systemd-detect-virt >/dev/null 2>&1 \
  && echo "virt=$(systemd-detect-virt --container 2>/dev/null || true)" || true
grep -Eq 'docker|kubepods|containerd|lxc' /proc/1/cgroup 2>/dev/null && echo "signal cgroup" || true
for f in /.dockerenv /run/.containerenv; do [ -e "$f" ] && echo "signal $f" || true; done
for v in REMOTE_CONTAINERS DEVCONTAINER CODESPACES TOOLBOX_PATH CONTAINER_ID; do
  eval "[ -n \"\${$v:-}\" ]" && echo "local-container $v" || true
done
[ -e /run/.toolboxenv ] && echo "local-container /run/.toolboxenv" || true
echo "pid1=$(cat /proc/1/comm 2>/dev/null || echo unknown)"
```

A **container signal** is any one of: `virt=` other than `none`; a `signal`
line; PID 1 that is not an init system (`systemd`, `init`, `shepherd`,
`runit`, `s6-svscan`, `openrc-init`, `dinit`, `launchd`). A container signal
says *containerised*, not *disposable*: a devcontainer running as root on the
user's laptop looks exactly like a hosted one, and no probe can tell them
apart. That is why **disposable-sandbox** needs a positive hosted marker. A
`local-container` line (devcontainer, Codespaces, toolbox, distrobox) is
local-host evidence outright — those environments persist.

Rules:

- **Classify by evidence, never by one path.** Hosted sandboxes are
  undocumented; their mounts, homes, and env vars change without notice, so
  this file hard-codes none of them. `CLAUDE_CODE_REMOTE=true` is the one
  documented marker, and even it counts only alongside the rest of the row —
  no Nix/Guix, no local-container marker, no personal login shell. A generic
  cloud account (`user`, `ubuntu`, `runner`) under `/home/` is not personal.
  Without any positive marker (a claude.ai chat container, say), the session
  is local-host: safe, at the cost of a consent prompt.
- **Unreachable host → no hand-off of probes or privilege.** When the user
  cannot reach the agent's machine — a hosted chat UI, no `!`, a VM on
  someone else's hardware — never ask them to run `which`, `sudo`, or a
  probe: their terminal is a different machine and its answer describes the
  wrong host. Treat the agent's own probe as the answer; for an install, ask
  consent and then run it yourself, or report the gap.
- **Tie-break → local-host.** Partial or conflicting evidence resolves to
  **local-host**, the mode with the strictest mutation and consent rules:
  a container signal with no hosted marker (a local devcontainer, even as
  root); any `local-container` line; `CLAUDE_CODE_REMOTE=true` but Nix/Guix
  present, or a personal login shell (`nu`, `ion`, …). Guessing "sandbox" wrongly mutates a real machine;
  guessing "local" wrongly only costs a consent prompt.
- **Once per session, cached.** Run it with the Step 0 probes of the other
  skills and reuse the answer. Re-classify only if the environment visibly
  changes.
- **Measurement is evidence** — commit silently. In **no-execution**, state the
  assumption in one line instead.

---

## 2. Per-mode behaviour

| Concern | **local-host** (unchanged) | **disposable-sandbox** | **no-execution** |
|---|---|---|---|
| **Host probes** (cli-shell Step 0, missing-pkg Step 0–1) | Run once, cache, report as the user's environment | Run once, cache — they describe **the sandbox, never the user**. Do not report the sandbox's login shell, `PATH`, or tools as the user's | Skip every probe |
| **User's login shell** | Measured from `passwd`; announced, not silent, when it reads `/bin/sh` or `/bin/bash` with no Nix/Guix (cli-shell Step 0 safety net) | **Not measurable** — infer per cli-shell Step 1 signal 4 (Nushell in Spacecraft context) and announce it | Same inference, announced |
| **Tool substitution** (cli-preference §1.1–§1.2) | Substitute only when installed; legacy fallback with `# preferred:` note; no TUI in the agent's shell; consent before mutating | Same gates, measured against the sandbox. Preferred tool absent, legacy present → use the legacy tool; no `# preferred:` note for agent-only output. Both absent → the preferred tool **may** be installed (Band B row below) | Emit the preferred form, always with a one-line legacy fallback note |
| **Shell targeting** (cli-shell Step 0.5) | Agent-run → agent's shell; user-run → login shell; file → shebang | Agent-run → the sandbox's shell (measure it); user-run → the **user's** login shell (inferred, Nushell default); file → shebang | No agent-run path. User-run → login shell (inferred, Nushell default); file → shebang |
| **Provisioning — ephemeral** (Band A) | `guix shell` / `nix run` / `nix-shell` / `npx` / `uvx`, no consent | Nix/Guix routes **skipped** (absent). `npx` / `uvx` / `pipx run` still preferred for one-shots | Hand the user a Band A command for their host |
| **Provisioning — project env** | Proposed repo change; the repo's own rules | **Unchanged** — a repo change, proposed as one | Unchanged — proposed as text |
| **Provisioning — declarative** (Band C) | Propose the config edit; the user rebuilds; never run it | **Skipped for the sandbox** — nothing outlives the session. If the user wants the tool permanently **on their own machine**, propose the Band C edit as text, as in no-execution | Propose the edit as text |
| **Provisioning — imperative** (Band B) | Consent-gated last resort, with removal command | The sandbox's own managers (`apt`, `pip`, `npm`, `cargo`, `gem`, `go`) may be used **without consent** — nothing outlives the session. No removal command needed | Propose as text, with removal command |
| **`sudo` / distro managers** | Never run; hand off | The ban protects the user's durable host; it does not attach to a throwaway VM. Use what the sandbox permits; do not assume root | Never emit as something to run on the user's host |
| **Consent** | Required for anything durable, mutating, or deleting | Not required for **package and tool installs** or scratch state outside the working tree. **Still required** for anything that leaves the sandbox — pushes, PRs, publishing, network writes, commits — and for deleting, overwriting, or reverting repo files beyond the requested change or rewriting git history (`rm -rf`, `git reset --hard`, `git clean -fdx`, `kondo`, `fclones remove`): the session's uncommitted work is the user's | Every command is the user's to run — the hand-off itself is the consent point |
| **Command hand-off** | `!`-prefixed in the Claude Code CLI; fenced block elsewhere | **Fenced code block** for the user's login shell — `!` does not exist here | `!`-prefixed in the Claude Code CLI (Bash tool denied); fenced block elsewhere |

**The `!` prefix exists only in the Claude Code CLI.** Claude Code on the web,
hosted chat, and every other harness get a fenced block the user copies into
their own terminal.

---

## 3. What the mode does not change

- **Commands written into a repo** — scripts, CI jobs, `Justfile` recipes,
  docs — are governed by **the repo's own environment** in every mode: its
  devShell, documented prerequisites, CI image, and the file's shebang. A tool
  installed in a sandbox is not a guarantee the repo can rely on.
- **Syntax priority** (POSIX first, shell-native where it diverges, Bash last)
  is independent of mode.
- **Repo and publication rules** — branch + PR, signed commits, Standard §6.4
  contribution targets — apply unchanged. A disposable machine does not make
  its outbound effects disposable.
