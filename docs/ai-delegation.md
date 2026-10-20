# Delegating code to OpenCode Go

Claude Code plans, splits work into bounded tasks and decides what lands.
OpenCode Go models write the code. GLM-5.3 and then CodeRabbit review it
before and after the PR opens.

```
Claude plans ──> oc-<model> codes ──> oc-glm-review ──> coderabbit review ──> PR ──> @coderabbitai review
     ^                                     │                    │
     └──────── findings: Claude fixes or re-delegates ──────────┘
```

## What Bravais installs

| Piece | File | Notes |
| --- | --- | --- |
| Model registry | `lib/opencode-go.nix` | The only place a model id or routing rule is written |
| Delegate subagents | `users/mj/ai-delegation.nix` → `~/.claude/agents/oc-<slug>.md` | One per registry entry; Haiku forwarders around `opencode run -m opencode-go/<id> --agent build` |
| Reviewer subagent | same file → `~/.claude/agents/oc-glm-review.md` | GLM-5.3, OpenCode's read-only `plan` agent, diff against `origin/main` attached |
| CodeRabbit CLI | `pkgs/coderabbit-cli/` | `coderabbit` and `cr`; bumped by `nu pkgs/update-vendored.nu coderabbit-cli` |
| GitHub review rules | `.coderabbit.yaml` | AGENTS.md's rules, shortened, as path instructions |

Routing is the `use` line of each registry entry; it becomes the subagent's
description, which is what Claude reads when choosing. Edit the registry and
rebuild; never edit a rendered `oc-*.md`, the next activation replaces it.

Each model has its own monthly allowance on the Go plan (5-hour window 20% of
it, weekly 50%), so the plentiful models ($60–$80: DeepSeek V4.1 Flash, Kimi
K2.7 Code, Gemini 4 Argon, Muse Spark 1.3) take the volume and the $15 ones
(DeepSeek V4 Pro, Qwen3.8 Max, Grok 4.7, GLM-5.3) the harder work and the
review. The **Contributor** models (Gemini 4 Argon, Muse Spark) let Google and
Meta train on the prompts: public repos only. Source:
<https://opencode.ai/v2/docs/console/go/>.

## Left out of Nix on purpose

- **Sign-ins.** Keys never go in the store. Once per machine, interactively:
  `opencode auth login` (choose OpenCode Go, paste the console key) and
  `coderabbit auth login`.
- **`~/.config/opencode/opencode.json`.** OpenCode writes it; a managed copy
  would clash on every activation (CONSTRAINTS.md #30).
- **The `opencode` CLI.** Out-of-band in `~/.opencode/bin`, updated by
  `preflight --update-ai-tools`.
- **Claude Code plugins.** `claude plugin install coderabbit` adds
  `/coderabbit:coderabbit-review`; the OpenCode plugin adds `/opencode:rescue`
  and `/opencode:review`, which take `--model opencode-go/<id>` and suit long
  background runs better than the `oc-*` subagents.
- **The CodeRabbit GitHub app** on the repository. Bravais is public, so the
  open-source plan applies; under 10 stars every PR review must be asked for
  with an `@coderabbitai review` comment.

## Checking it works

```
opencode models opencode-go
coderabbit --version
```

Both in one line (Nushell): `opencode models opencode-go ; coderabbit --version`

Then ask Claude Code to use one subagent by name, for example "use oc-deepseek-flash
to add the SPDX header to every file under scripts/ that lacks one", and
`oc-glm-review` on the result.

## Limits

- The forwarders make one `opencode run` call with a 10-minute ceiling. Longer
  jobs belong in `/opencode:rescue --background --model …`.
- `opencode run` is non-interactive: if a run stops on a permission prompt,
  the agent's permissions in OpenCode need loosening, not the forwarder.
- CodeRabbit's CLI allowance on the free and open-source plans is 3 reviews an
  hour; run it at the end of a change, not after every edit.
- The CodeRabbit CLI is closed source; no memory-safe tool does the same job.
