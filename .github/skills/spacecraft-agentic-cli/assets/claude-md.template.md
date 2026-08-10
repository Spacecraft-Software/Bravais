# CLAUDE.md — <PROJECT_NAME>

<!--
  Spacecraft Software CLAUDE.md template, version 2.0.0.
  License: GPL-3.0-or-later

  Standard §5.7 governs this file. AGENTS.md is the authority: it holds
  every project fact — build commands, invariants, layout, forbidden
  patterns. This file imports it and adds ONLY what a non-Claude harness
  cannot act on.

  Do NOT copy, symlink, summarize, or mirror AGENTS.md here. If you find
  yourself writing "keep these two files in sync," the split is wrong.

  Do NOT duplicate the CLI Standard here either — those rules live in the
  spacecraft-cli-standard and spacecraft-agentic-cli skills.

  CLAUDE.md is REQUIRED even when it holds nothing else. Claude Code reads
  CLAUDE.md, not AGENTS.md — a project with only an AGENTS.md gives a
  Claude session no project context at all. With nothing Claude-only to
  say, the heading + @AGENTS.md + the blockquote is the whole file.

  Both AGENTS.md and CLAUDE.md are tracked. Neither may be gitignored, and
  neither carries credentials, private hostnames, or personal filesystem
  paths.
-->

@AGENTS.md

> Record project knowledge in `AGENTS.md`, not here. This file holds only
> Claude-Code-only context (skills, `.claude/`, slash commands, MCP client).

<!-- ===== Claude-only content below this line ===== -->

## Skills to load

The following Spacecraft Software skills apply to this project. Consult them
via the Skill tool when their triggers match:

- `spacecraft-standard-constitution` — master Steelbore Standard
- `spacecraft-cli-standard` — structural CLI Standard rules
- `spacecraft-agentic-cli` — agent-facing UX for the CLI
- `spacecraft-brand-guidelines` — brand look-and-feel
- `steelbore-color-palette` — canonical palette values (§11)
- `microsoft-rust-guidelines` — Microsoft Pragmatic Rust Guidelines
- `spacecraft-cli-preference` — preferred external CLI tools (rg, fd, bat)
- `spacecraft-cli-shell` — shell syntax for generated commands
- <ADD-PROJECT-SPECIFIC-SKILLS>

## MCP servers expected

- `<TOOL_NAME> mcp` — this project's own MCP surface (when implemented)
- <ADD-PROJECT-SPECIFIC-MCP-SERVERS>

## Claude Code specifics

- <Slash commands this repo installs, `.claude/` layout, plan-mode notes,
  subagent conventions, TaskMaster wiring — anything meaningless to Codex,
  Cursor, or Goose.>
- <ADD-PROJECT-SPECIFIC-CLAUDE-NOTES>

<!--
  Tool preferences, commit-message format, and TODO conventions are NOT
  Claude-only — they belong in AGENTS.md. Likewise CLAUDECODE=1 detection:
  a CLI that checks it alongside CURSOR_AGENT and GEMINI_CLI is documenting
  its own behavior, which every harness needs to know.
-->
