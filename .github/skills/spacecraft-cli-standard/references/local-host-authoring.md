# Authoring a CLI on the user's machine

Building, testing, and scaffolding a Spacecraft Software CLI happen on the
user's real workstation, not a disposable sandbox. This file is the detail
behind the local-host rules in SKILL.md. It owns none of provisioning, shell
syntax, or tool choice — those belong to the retargeted siblings and are
cross-referenced at the end.

The one flagship point: **agent detection is presence-based, and this skill's
prose must never drift back to `AI_AGENT == "1"`.** The reference
implementation is already correct; the risk is a spec reader re-deriving the
value-matching bug from prose that says `=1`.

---

## 1. Presence vs value detection

The agent-presence variables are set by the harness to **whatever it likes** —
not to `1`. Measured in a live Claude Code session on this class of host:

```sh
env | grep -iE 'AI_AGENT|^AGENT=|^CI=|CLAUDE|CURSOR|GEMINI|TERM'
```

```
AI_AGENT=claude-code_2-1-218_agent
CLAUDECODE=1
TERM=alacritty
```

`AI_AGENT` is a descriptive string; `CLAUDECODE` being `1` is incidental; `CI`
is unset. Two classes:

| Class | Variables | Predicate |
|---|---|---|
| **Presence** | `AI_AGENT`, `AGENT`, `CLAUDECODE`, `CURSOR_AGENT`, `GEMINI_CLI` | set **and non-empty**, any value (`!v.is_empty() && v != "0" && v != "false"`) |
| **Value** | `CI` | truthy = set and not `""` / `0` / `false` |

The canonical Rust — `is_agent_env` in
[rust-implementation.md](rust-implementation.md) — already implements this
correctly. It is presence-based on purpose; do not "simplify" it to a value
comparison, and keep §5, `output-modes.md`, and the compliance tests aligned to
it. A `== "1"` check misses `AI_AGENT=claude-code_2-1-218_agent` entirely — the
agent driving the tool goes unrecognised, and the CLI silently skips its agent
profile. (See `spacecraft-agentic-cli`'s §7, where this same bug lived in code.)

---

## 2. Verify detection by running, with a string value

Reading `is_agent_env` tells you what the code intends; running the binary
under the host's real environment tells you what a *fresh implementation*
actually does — and only the second catches a value-matching regression.

```sh
# Use the real value the host exports, not a guessed "1"
AI_AGENT="$AI_AGENT" mytool trace list --format json \
  | jq -e '.metadata.tool_agent == "claude-code"'
```

| Method | Catches an `AI_AGENT == "1"` implementation? |
|---|---|
| Read the detection source | No — it reads as intentional |
| Run under a descriptive `AI_AGENT` string and inspect the mode | **Yes** — human mode / missing agent profile is observable |

A compliance fixture of `AI_AGENT=1` gives false confidence: it passes a broken
value-matching build. Test with the descriptive string, and include `1` only
for extra coverage. See [testing-compliance.md](testing-compliance.md).

---

## 3. No-clobber scaffolding

Writing `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, or `CONTRIBUTING.md` (§8 step 9)
is the one durable change the authoring flow makes to the user's disk. A real
repo often already has one carrying project context.

1. **Read first** — check whether the file exists and read it.
2. **Merge, don't replace** — fold the template into the existing content;
   preserve the project's own invariants and commands.
3. **Propose the diff** — a scaffold is a proposal, not a force-write.
4. **Never `git add -A`** a scaffolded tree.

This is `spacecraft-missing-pkg`'s consent-before-durable rule applied to file
creation.

---

## 4. Testing destructive commands

The CLI you build has a strong consent model already — non-TTY destructive ops
without `--yes` / `--force` must exit `MISSING_ARGUMENT` and default to "no"
([validation-safety.md](validation-safety.md) §6). That is unchanged.

The local-host angle is for **you, testing it on the user's real machine**: use
the CLI's own `--dry-run` to exercise write/delete paths rather than executing
them. `--dry-run` emits the action plan as JSON with no side effects — exactly
the safe way to verify a destructive command against real state. Reserve actual
execution for throwaway fixtures you created.

---

## 5. Where the siblings take over

All four are now local-host aware — route to them, don't restate their rules.

| Concern while building the CLI | Owner |
|---|---|
| A needed toolchain / linter / interpreter isn't installed | `spacecraft-missing-pkg` — ephemeral-first (`nix run nixpkgs#…`), consent before durable |
| Syntax of a command you scaffold, test, or document | `spacecraft-cli-shell` — routes by who executes it (agent vs user vs file) |
| Which external tool the CLI (or you) should invoke | `spacecraft-cli-preference` — substitutes only when present |
| Agent-facing UX depth (hints, MCP lazy-load, token economy) | `spacecraft-agentic-cli` — the paired UX layer atop this Standard |
