# Authoring an agentic CLI on the user's machine

Scaffolding, auditing, and testing a Spacecraft Software CLI happen on a real
workstation, not a disposable sandbox. That changes four things: agent
detection must match what harnesses actually export, the audit can *observe*
instead of *infer*, scaffolding writes durable files, and error hints must be
runnable by the agent that reads them.

This file is the detail behind SKILL.md §12. Provisioning is
`spacecraft-missing-pkg`'s job; shell syntax is `spacecraft-cli-shell`'s; tool
choice is `spacecraft-cli-preference`'s. This file owns none of those — it
cross-references them.

---

## 1. Probe the real agent environment

Never assume the agent-presence variables equal `1`. Read what the host
actually exports and use those concrete values as your test fixtures:

```sh
env | grep -iE 'AI_AGENT|^AGENT=|^CI=|CLAUDE|CURSOR|GEMINI|TRAE|TERM|NO_COLOR|FORCE_COLOR' | sort
```

A live Claude Code session on this class of host returns something like:

```
AI_AGENT=claude-code_2-1-218_agent
CLAUDECODE=1
CLAUDE_CODE_ENTRYPOINT=cli
TERM=alacritty
```

Note what this shows: `AI_AGENT` is a **descriptive string**, not `1`;
`CLAUDECODE` happens to be `1` but that is incidental; `CI` is unset; `TERM` is
a real terminal, not `dumb`. A CLI whose detector hard-codes `== "1"` classifies
this session as *not an agent*.

---

## 2. Presence vars vs value vars

Two classes, and conflating them is the bug this whole file exists to prevent.

| Class | Variables | Predicate |
|---|---|---|
| **Presence** — set to whatever the harness likes | `AI_AGENT`, `AGENT`, `CLAUDECODE`, `CURSOR_AGENT`, `GEMINI_CLI`, `TRAE_AI_SHELL_ID` | set **and non-empty**, any value |
| **Value** — carries real semantics | `CI`, `NO_COLOR`, `FORCE_COLOR`, `CLICOLOR`, `TERM` | value-specific (see below) |

Presence predicate:

```rust
fn is_present(var: &str) -> bool {
    matches!(std::env::var(var), Ok(v) if !v.is_empty())
}
```

Value predicates:

- `CI` — truthy = set and not `""`, `0`, or `false` (GitHub sets `CI=true`,
  others set `CI=1`).
- `NO_COLOR` / `FORCE_COLOR` — active when set to any non-empty value
  (no-color.org convention).
- `CLICOLOR` — off when exactly `0`.
- `TERM` — capability signal; `dumb` suppresses color and TUI.

Worked case, this session's `AI_AGENT=claude-code_2-1-218_agent`:
`is_present("AI_AGENT")` is `true` (non-empty) → agent profile. A
`== "1"` / `matches!(…, Ok("1") | Ok("true"))` check is `false` → the profile
is silently skipped. Full cascade and Rust in
[agent-env-detection.md](agent-env-detection.md).

---

## 3. Audit by running, not by reading

The agentic audit (SKILL.md §9) is **behavioral**. Source inspection tells you
what the code *intends*; running the CLI under the host's real environment
tells you what it *does* — and only the second catches a presence-vs-value
detection bug.

Drive the CLI with the actual value the host exports, then assert on the
envelope:

```sh
# Use the real value, not a guessed "1"
AI_AGENT="$AI_AGENT" mytool describe --format json \
  | jq -e '.metadata.invoking_agent == "claude-code" and .metadata.profile == "agent"'
```

Nushell (route through the shell that will run it — see
`spacecraft-cli-shell`):

```nu
with-env { AI_AGENT: $env.AI_AGENT } { ^mytool describe } | from json | get metadata.profile
```

If `describe` reports `profile: none` while `AI_AGENT` is set to a real string,
the detector is value-matching — fix it per §2. A source read would have shown
`is_truthy("AI_AGENT")` and looked fine.

Contrast the two failure signals:

| Method | Catches the `== "1"` bug? |
|---|---|
| Read the detection source | No — `matches!(…, Ok("1"))` reads as intentional |
| Run under the real `AI_AGENT` string and inspect the envelope | **Yes** — `profile: none` is observable |

---

## 4. No-clobber scaffolding

Writing `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, or `CONTRIBUTING.md` is the one
durable change this skill triggers on the user's disk. A real repo often
already has one, carrying project context you must not destroy.

1. **Read first.** Check whether the target file exists and read it.
2. **Merge, don't replace.** Fold the template's structure into the existing
   content; preserve the project's own invariants, commands, and prose.
3. **Propose the diff.** Show what changes and let the user confirm — a
   scaffold is a proposal, not a force-write.
4. **Never overwrite wholesale**, and never `git add -A` a scaffolded tree.

This is the consent-before-durable rule from `spacecraft-missing-pkg`, applied
to file creation.

---

## 5. Agent-runnable hints

Tips-thinking (SKILL.md §3, [tips-thinking.md](tips-thinking.md)) says a good
hint is a command the agent can run directly. On a real host that rules out two
whole categories:

- **Anything needing root.** `sudo …` stalls — the agent has no TTY to answer
  the password prompt. Point at a non-privileged path instead
  (`$XDG_CONFIG_HOME`, `--config <path>`, a project-local file). If root is
  truly unavoidable, surface it as an explicit human-escalation step
  (`requires_human: true`), never inside `hint`.
- **Anything needing a TTY.** Interactive prompts, pagers, and full-screen
  flows can't run in the agent's shell. Prefer the non-interactive form.

For a `MISSING_DEPENDENCY` hint, emit the ephemeral run
`spacecraft-missing-pkg` prefers — `nix run nixpkgs#<pkg> -- <args>` — not a
durable `cargo install` and never a system-package-manager command.

---

## 6. Where the other skills take over

| Concern while building the CLI | Owner |
|---|---|
| A needed toolchain / linter / interpreter isn't installed | `spacecraft-missing-pkg` — ephemeral-first, consent before durable |
| Syntax of a command you scaffold, test, or document | `spacecraft-cli-shell` — routes by who executes it |
| Which external tool the CLI (or you) should invoke | `spacecraft-cli-preference` — substitutes only when present |
| Structural CLI rules (envelope, exit codes, schema) | `spacecraft-cli-standard` — authoritative on structure |

All three of the first three are now local-host aware. Route to them; don't
restate their rules here.
