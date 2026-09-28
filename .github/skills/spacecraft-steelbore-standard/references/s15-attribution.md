<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
## §15 — Attribution, Maintainer & Contact

**Maintainer:** Mohamed Hammad
**Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** Copyright (C) 2026 Mohamed Hammad & Spacecraft Software | **License:** GPL-3.0-or-later
**Website:** [https://SpacecraftSoftware.org/](https://SpacecraftSoftware.org/)

### §15.1 — Project Pages

Each **published** Spacecraft Software project has a dedicated subdomain following the
pattern `https://<ProjectName>.SpacecraftSoftware.org/`. Use the project-specific URL in
all project-level outputs; use `https://SpacecraftSoftware.org/` only for umbrella references.

**Published** means the project has a repository under a namespace Spacecraft Software
controls (§6.4). The qualifier does real work: a working directory is not a project.
Vendored upstream forks carried under §4.2, scratch and experiment directories, symbolic
links into other trees, and reference copies all appear in `PROJECTS.md` — which tracks
what is *on disk* — and none is published by us or has anything to serve at a subdomain.

| Project                    | URL                                              |
|----------------------------|--------------------------------------------------|
| Spacecraft Software (main) | https://SpacecraftSoftware.org/                  |
| The Steelbore Standard     | https://Standard.SpacecraftSoftware.org/         |
| Aetheric                   | https://Aetheric.SpacecraftSoftware.org/         |
| Gitway                     | https://Gitway.SpacecraftSoftware.org/           |
| Ferrocast                  | https://Ferrocast.SpacecraftSoftware.org/        |
| Caliper                    | https://Caliper.SpacecraftSoftware.org/          |
| Craton                     | https://Craton.SpacecraftSoftware.org/           |
| Ironway                    | https://Ironway.SpacecraftSoftware.org/          |
| Zamak                      | https://Zamak.SpacecraftSoftware.org/            |
| Bravais                    | https://Bravais.SpacecraftSoftware.org/          |
| Mawaqit                    | https://Mawaqit.SpacecraftSoftware.org/          |
| Flux                       | https://Flux.SpacecraftSoftware.org/             |
| Anvil                      | https://Anvil.SpacecraftSoftware.org/            |
| Construct                  | https://Construct.SpacecraftSoftware.org/        |
| Ferrite_OS                 | https://Ferrite.SpacecraftSoftware.org/          |
| Forge                      | https://Forge.SpacecraftSoftware.org/            |
| Ginx                       | https://Ginx.SpacecraftSoftware.org/             |
| Loran                      | https://Loran.SpacecraftSoftware.org/            |
| Pearlite                   | https://Pearlite.SpacecraftSoftware.org/         |
| MCP Servers                | https://MCP-Servers.SpacecraftSoftware.org/      |
| Lode                       | https://Lode.SpacecraftSoftware.org/             |
| Sonde                      | https://Sonde.SpacecraftSoftware.org/            |
| Vault                      | https://Vault.SpacecraftSoftware.org/            |
| Vacuum                     | https://Vacuum.SpacecraftSoftware.org/           |
| Docs                       | https://Docs.SpacecraftSoftware.org/             |
| Loran Pages                | https://Loran-Pages.SpacecraftSoftware.org/      |
| Achernar                   | https://Achernar.SpacecraftSoftware.org/ |
| Adit                       | https://Adit.SpacecraftSoftware.org/ |
| Antigravity 2              | https://Antigravity2.SpacecraftSoftware.org/ |
| Babel                      | https://Babel.SpacecraftSoftware.org/ |
| Conduit                    | https://Conduit.SpacecraftSoftware.org/ |
| Majestic                   | https://Majestic-PRD.SpacecraftSoftware.org/ |
| Majestic (Fable/Rust Fable) | https://Majestic.SpacecraftSoftware.org/ |
| Majestic (Guile Fable)     | https://Majestic-Guile.SpacecraftSoftware.org/ |
| Majestic (Rust Kimi)       | https://Majestic-Rust-Kimi.SpacecraftSoftware.org/ |
| Majestic (Rust Opus)       | https://Majestic-Rust-Steel.SpacecraftSoftware.org/ |
| Majestic 4                 | https://Majestic4.SpacecraftSoftware.org/ |
| MajesticOS                 | https://MajesticOS.SpacecraftSoftware.org/ |
| Packages                   | https://Packages.SpacecraftSoftware.org/ |
| Projects                   | https://Projects.SpacecraftSoftware.org/ |
| Reel                       | https://Reel.SpacecraftSoftware.org/ |
| Specs                      | https://Specs.SpacecraftSoftware.org/ |
| Theme                      | https://Theme.SpacecraftSoftware.org/ |

When a new project is created, add its subdomain to this table immediately.

### §15.2 — Mandatory Attribution in Project Outputs

Every Spacecraft Software product **must** surface the following attribution in at least one
of: `--help` output, `--version` output, README, or About/Info screen.

**Required attribution block:**
```
Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
Copyright (C) 2026 Mohamed Hammad & Spacecraft Software  |  License: GPL-3.0-or-later
https://<ProjectName>.SpacecraftSoftware.org/
```
(The License line shows the project's own license — GPL-3.0-or-later or AGPL-3.0-or-later per §4.1.)

**Per-surface rules:**

| Surface           | Required content                                                        |
|-------------------|-------------------------------------------------------------------------|
| `--version`       | Maintainer name, project URL, copyright year                            |
| `--help`          | Project URL and maintainer name (at footer)                             |
| README            | "Maintainer" section: name, `Mohamed.Hammad@SpacecraftSoftware.org`, project URL |
| About / Info (GUI/TUI) | Maintainer name, project URL, copyright year                       |
| SPDX header       | REUSE two-tag header (§4.3): `SPDX-FileCopyrightText` + `SPDX-License-Identifier` (`GPL-3.0-or-later` or `AGPL-3.0-or-later`) |

**Specific rules:**
- The contact email is always `Mohamed.Hammad@SpacecraftSoftware.org` — never a personal
  domain, GitHub handle, or other address.
- The copyright year reflects the year of first release or current year, or a range
  (e.g., `2025-2026`) when a project spans multiple years.
- Link text for project pages must use the full URL as the display text or a clear
  label (e.g., `[Gitway](https://Gitway.SpacecraftSoftware.org/)`), never an opaque label.
- For CLI `--version` output in human mode, the footer line format is:
  ```
  Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
  https://<ProjectName>.SpacecraftSoftware.org/
  ```
- For CLI `--version` output in JSON/machine mode, include in `metadata`:
  ```json
  "maintainer": "Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>",
  "website": "https://<ProjectName>.SpacecraftSoftware.org/"
  ```
- **Email obfuscation in plain-text prose.** In plain-text prose contexts (README body,
  CONTRIBUTING.md, human-readable documentation) where the address is not a clickable
  link, `Mohamed.Hammad [at] SpacecraftSoftware.org` is permitted as a scraper-resistant
  form. `# Maintainer:` lines in PKGBUILDs and `SPDX-FileCopyrightText` headers **must**
  always use the full address — those formats are parsed by `makepkg`/`pkgcheck` and
  `reuse lint` respectively, and obfuscation breaks them.

### §15.3 — Third-Party Attribution

Spacecraft Software artifacts must give credit where credit is due. When a project
or skill **substantially builds on third-party work**, that credit appears
in a `CREDITS.md` at the artifact's root — `<project-root>/CREDITS.md` for
projects, `<skill-name>/CREDITS.md` for skills.

`CREDITS.md` is the inbound counterpart to §15.2's outbound attribution:
§15.2 tells consumers who maintains Spacecraft Software; §15.3 tells consumers whose
work Spacecraft Software stands on.

**Triggers** (any one obligates a `CREDITS.md`):

- Content adapted, derived, or copied verbatim from an external source
  under any license (permissive or copyleft).
- A library, framework, or specification whose ideas or implementation
  form a substantial conceptual basis for the artifact, beyond routine
  dependency use.
- Named prior art, research, or design work whose insights were borrowed.

**Not triggered by** (license metadata alone suffices):

- Routine package-manager dependencies whose `LICENSE` files are surfaced
  mechanically via Cargo, npm, pip, Nix, etc.
- Well-known standards and specifications (POSIX, RFC, ISO, GFM, ODF,
  OOXML) that the artifact conforms to but does not redistribute.
- Public-domain conventions and common idioms.

**Required content per credited work:**

| Field      | Required | Example                                          |
|------------|----------|--------------------------------------------------|
| Name       | Yes      | `Microsoft Pragmatic Rust Guidelines`            |
| Author(s)  | Yes      | `Microsoft Corporation`                          |
| License    | Yes      | `MIT License`                                    |
| Source URL | Yes      | `https://github.com/microsoft/rust-guidelines`   |
| Scope      | Yes      | One-line description of what was adapted/used    |

A skill MAY keep a deeper, scope-limited attribution file inside its
`references/` directory (typically `references/ATTRIBUTION.md`) when the
credit applies specifically to adapted reference content. The root
`CREDITS.md` remains canonical and should link down to any such deeper
file.

SPDX headers (§4) cover license compliance mechanically; `CREDITS.md` is
the human-readable narrative — who, what, and how the upstream work
shaped the Spacecraft Software artifact.

### §15.4 — Authoring Model Attribution

§15.2 records who maintains a Spacecraft Software artifact and §15.3 records whose
work it stands on. Neither records *what produced it*. When a language model drafts
a requirements document, an implementation plan, or a task list — or codes a project
outright — that fact stays legible for about as long as the session lasts. Which
model, at what reasoning effort, served by which provider, driven by which harness:
the answer lives in the maintainer's memory of the session and decays quickly.

This section obligates a record. §15.5 specifies its form — an append-only log,
`.agent-log.jsonl`, written by the harness.

**The record is local, and deliberately so.** §15.5 requires the log to be
git-ignored, so it never reaches a clone and makes no published claim about the
artifact. It serves the working copy that produced the work: what the maintainer can
ask, months later, about which model and configuration did what, how often tests
passed on the first attempt, and what the work cost. An artifact that must tell
*consumers* who stands behind it uses §15.2, which is unchanged.

Commit trailers do not serve this purpose. A `Co-Authored-By` line is unstructured,
is lost to squash-merges and to the history rewrites §6.3 permits, and names a
product without the reasoning effort, the inference provider, the harness, or any
measurement of the work. The §15.5 log is machine-readable and carries all of them.
The two are independent, both MAY be used, and §15.4 does not displace the trailer
convention.

**Triggers** (any one obligates a record):

- A Product Requirements Document (PRD).
- An implementation plan.
- A TODO or task list that drives implementation.
- A project whose initial implementation was substantially produced by a model.

**Not triggered by:**

- Chat answers, scratch output, and anything that is not committed.
- A model that only reviewed, critiqued, or reformatted an artifact it did not author.

**Provider and harness are independent, and both are recorded.** The **provider** is
the service that served the inference — `Anthropic`, `zAI`, `Ollama Cloud`,
`OpenRouter`, `OpenCode Zen`, or a local `Ollama`. The **harness** is the agent
client that drove it — `Claude Code`, `OpenCode`, `Codex`, `Orca`, `OpenClaude`,
`ZCode`, `Antigravity IDE`, `Antigravity CLI`. The same model reaches a repository
through many combinations of the two, and it is the combination, not the model alone,
that makes a result reproducible.

**Reasoning effort is recorded separately** in the `reasoning_effort` field, not
folded into the model identifier. Where a model exposes a thinking or effort setting,
the bare identifier is incomplete — the same weights at a different level produce
materially different work. Where a model exposes no such setting, the field is omitted.

**A record is not an authorship claim.** The copyright holder and maintainer remain
as §15.2 states, and the artifact's license is unchanged. §15.4 records a production
fact, not legal authorship: it MUST NOT appear in an `SPDX-FileCopyrightText` tag, in
a `# Maintainer:` line, or in `--version` output, and it never displaces the §15.2
attribution block.

### §15.5 — Agent Work Log (`.agent-log.jsonl`)

The record §15.4 obligates is an append-only JSON Lines log at the repository root,
named `.agent-log.jsonl`. One line is appended per completed task. The file is
created on first append; its absence is not an error, and a repository to which no
trigger has applied carries none.

**Append-only.** Each line is one complete JSON object, written once and never
rewritten, reordered, or deleted. The file is not a JSON array: there is no enclosing
bracket and no separating comma, so an append is a single write that cannot corrupt
what precedes it. A process that rewrites earlier lines has destroyed the only
property the format provides.

**Git-ignored, and excluded from agent context.** A `.gitignore` entry for
`.agent-log.jsonl` is REQUIRED. The log is working-copy state, not a published
artifact, and committing it makes every branch that runs an agent session conflict on
the same file. It SHOULD also be excluded from the file context agents are given
(`.cursorignore` and the equivalent for other harnesses): it grows without bound, and
an agent that reads its own log wastes context on data it cannot act upon.

This does not conflict with §5.7, which requires `AGENTS.md` and `CLAUDE.md` to be
tracked. Those are context files that carry project knowledge a fresh clone needs;
the log is a local measurement record that a fresh clone has no use for.

**The harness writes it, not the model.** Token counts are not observable by a model
during its own session, and a model instructed to report them will supply plausible
invented numbers. The log is therefore generated by the harness — a hook, wrapper, or
client feature with access to the real session record. **A field the harness cannot
determine is omitted, never estimated.** An absent field is a truthful statement that
the value is unknown; a guessed one silently corrupts every later query.

**Timestamps** are RFC 3339 UTC with a `Z` suffix, per §14.3, which already requires
UTC + `Z` for all `jsonl` machine output.

**Schema.** Unknown fields are permitted — a harness MAY record more than this table
names — but the required fields MUST be present on every line.

| Field                 | Type        | Required | Example                    |
|-----------------------|-------------|----------|----------------------------|
| `task_id`             | `string`    | Yes      | `"T-102"`                  |
| `timestamp`           | `string`    | Yes      | `"2026-09-14T20:25:00Z"`   |
| `model`               | `string`    | Yes      | `"claude-opus-5"`          |
| `provider`            | `string`    | Yes      | `"Anthropic"`              |
| `harness`             | `string`    | Yes      | `"Claude Code"`            |
| `files_touched`       | `string[]`  | Yes      | `["src/adapters/db.rs"]`   |
| `reasoning_effort`    | `string`    | No       | `"high"`                   |
| `subagent_role`       | `string`    | No       | `"implementer"`            |
| `test_pass_first_try` | `boolean`   | No       | `true`                     |
| `iterations`          | `integer`   | No       | `2`                        |
| `tokens_in`           | `integer`   | No       | `12450`                    |
| `tokens_out`          | `integer`   | No       | `890`                      |

`files_touched` holds repository-relative paths, so a log stays meaningful when the
working copy moves. A file edited outside the repository root is recorded by absolute
path instead: a relative path that escapes the root resolves nowhere once the working
copy has moved, which is the failure the relative form exists to avoid. `task_id` is
whatever identifier the surrounding process uses — an issue key, a plan milestone, or
the harness session id where nothing better exists.

**Example.** Two tasks, the second by a different model under a different harness:

```jsonl
{"task_id":"T-102","timestamp":"2026-09-14T20:25:00Z","model":"claude-opus-5","provider":"Anthropic","harness":"Claude Code","reasoning_effort":"high","subagent_role":"implementer","files_touched":["src/adapters/db.rs"],"test_pass_first_try":true,"tokens_in":12450,"tokens_out":890}
{"task_id":"T-103","timestamp":"2026-09-14T21:10:00Z","model":"o3-mini","provider":"OpenAI","harness":"Codex","subagent_role":"auditor","files_touched":["tests/db_test.rs"],"test_pass_first_try":false,"iterations":2,"tokens_in":18200,"tokens_out":1450}
```

**Reference implementation.** A Claude Code `SessionEnd` hook, treating one session
as one task. It reads the real transcript rather than asking the model anything, and
omits `model` if the transcript never names one:

```python
#!/usr/bin/env python3
"""SessionEnd hook: append one .agent-log.jsonl line per session."""
import datetime, json, os, sys

ev = json.load(sys.stdin)          # session_id, transcript_path, cwd
tin = tout = 0
model = None
files = set()

with open(ev["transcript_path"], encoding="utf-8") as fh:
    for line in fh:
        try:
            rec = json.loads(line)
        except ValueError:
            continue               # tolerate a torn final line
        msg = rec.get("message") or {}
        usage = msg.get("usage") or {}
        tin += usage.get("input_tokens", 0)
        tout += usage.get("output_tokens", 0)
        model = msg.get("model") or model
        for block in msg.get("content") or []:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                path = (block.get("input") or {}).get("file_path")
                if path:
                    rel = os.path.relpath(path, ev["cwd"])
                    # A file outside the repository has no meaningful
                    # relative path; record it absolute rather than as
                    # a ../../.. chain that resolves nowhere.
                    files.add(path if rel.startswith("..") else rel)

entry = {
    "task_id": os.environ.get("AGENT_TASK_ID", ev["session_id"]),
    "timestamp": datetime.datetime.now(datetime.timezone.utc)
                         .strftime("%Y-%m-%dT%H:%M:%SZ"),
    "model": model,
    "provider": "Anthropic",
    "harness": "Claude Code",
    "files_touched": sorted(files),
    "tokens_in": tin,
    "tokens_out": tout,
}

with open(os.path.join(ev["cwd"], ".agent-log.jsonl"), "a",
          encoding="utf-8") as fh:
    fh.write(json.dumps({k: v for k, v in entry.items()
                         if v is not None}) + "\n")
```

---

