# CLAUDE.md — <PROJECT_NAME>

<!--
  Spacecraft Software CLAUDE.md template, version 1.0.0.
  License: GPL-3.0-or-later

  CLAUDE.md is a strict superset of AGENTS.md. Start by mirroring the
  AGENTS.md content (either symlink or copy), then add the
  Claude-specific sections at the bottom.

  Do NOT duplicate the CLI Standard here — those rules live in the
  spacecraft-cli-standard and spacecraft-agentic-cli skills.
-->

<!-- ===== AGENTS.md content (mirror or symlink) ===== -->

## Project identity

<COPY-FROM-AGENTS.MD>

## Build, test, lint

<COPY-FROM-AGENTS.MD>

## Architectural invariants

<COPY-FROM-AGENTS.MD>

## Forbidden patterns

<COPY-FROM-AGENTS.MD>

## Environment expectations

<COPY-FROM-AGENTS.MD>

## Where to look for ___

<COPY-FROM-AGENTS.MD>

<!-- ===== Claude-specific additions ===== -->

## Skills referenced

The following Spacecraft Software skills apply to this project. Claude should
consult them when their triggers match:

- `spacecraft-standard` — master Project Spacecraft Software Standard
- `spacecraft-cli-standard` — structural CLI Standard rules
- `spacecraft-agentic-cli` — agent-facing UX for the CLI
- `spacecraft-brand-guidelines` — six-token color palette
- `rust-guidelines` — Microsoft Pragmatic Rust Guidelines
- `spacecraft-cli-preference` — preferred external CLI tools (rg, fd, bat)
- `spacecraft-cli-shell` — shell syntax for generated commands
- <ADD-PROJECT-SPECIFIC-SKILLS>

## MCP servers expected

This project may coexist with the following MCP servers in agent
sessions:

- `<TOOL_NAME> mcp` — this project's own MCP surface (when implemented)
- <ADD-PROJECT-SPECIFIC-MCP-SERVERS>

## Tool preferences

- Use `rg` over `grep`, `fd` over `find`, `bat` over `cat` (per
  spacecraft-cli-preference).
- Use `cargo nextest` over `cargo test` if available; fall back if not.
- Use `jaq` over `jq` for JSON filtering.
- <ADD-PROJECT-SPECIFIC-TOOL-PREFERENCES>

## Notes for Claude specifically

- Inline TODOs use `// TODO(claude):` to distinguish from human TODOs.
- Commit messages use the format `<type>(<scope>): <subject>` with
  conventional-commits types.
- <ADD-PROJECT-SPECIFIC-CLAUDE-NOTES>

## Standards compliance

This project follows the CLI Standard v1.0.0. The CLI Standard skills
are authoritative on structural and agentic conventions. This file
documents project-specific deviations and supplements only.
