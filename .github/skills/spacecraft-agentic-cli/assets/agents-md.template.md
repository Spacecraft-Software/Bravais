# AGENTS.md — <PROJECT_NAME>

<!--
  Spacecraft Software AGENTS.md template, version 2.0.0.
  License: GPL-3.0-or-later

  THIS FILE IS THE AUTHORITY (Standard §5.7). Every agent reads it —
  Codex CLI, Cursor, Aider, OpenCode, Goose, and Claude Code (which
  imports it from CLAUDE.md via `@AGENTS.md`). New project knowledge
  goes HERE, not into a harness-specific file. CLAUDE.md holds only
  what is meaningless to a non-Claude harness.

  This file is tracked, never gitignored, and never carries credentials,
  private hostnames, or personal filesystem paths.

  Replace every <PLACEHOLDER> below with project-specific content.
  Delete instruction comments before committing.

  Do NOT dump the CLI Standard or general Spacecraft Software conventions here — those
  live in the spacecraft-cli-standard and spacecraft-agentic-cli skills.
  This file is for PROJECT-SPECIFIC invariants only.
-->

## Project identity

<PROJECT_NAME> is <ONE-SENTENCE-WHAT-IT-IS>, organized as a
<WORKSPACE-SHAPE> targeting <PRIMARY-USE-CASE>. Part of Project
Spacecraft Software.

## Build, test, lint

- Build: `<EXACT-BUILD-COMMAND>`
- Test: `<EXACT-TEST-COMMAND>`
- Lint: `<EXACT-LINT-COMMAND>`
- Format check: `<EXACT-FORMAT-CHECK-COMMAND>`
- CLI Standard audit: `<EXACT-AUDIT-COMMAND>` <!-- e.g., cargo run -p <name>-audit -- check . -->

## Architectural invariants

<!--
  Document things that the code's structure ASSUMES that aren't visible
  in any single file. The agent will violate these without prompting if
  not warned.
-->

- Every sub-command returns `Result<Response<T>, AppError>`; never bare
  `T` and never raw error types to stdout.
- All timestamps use `<CHOSEN-TIME-CRATE>`; alternatives are forbidden.
- The `OutputMode` is computed once at main entry and threaded through
  every sub-command — never recompute mid-command.
- <ADD-PROJECT-SPECIFIC-INVARIANTS>

## Forbidden patterns

<!--
  Things that LOOK reasonable but break THIS codebase. Be specific.
-->

- `println!` / `eprintln!` direct calls. Use the OutputMode-aware emit
  helpers exclusively.
- Local-time formatting anywhere. UTC only.
- `unwrap()` / `expect()` outside `#[cfg(test)]`. Use `?` with proper
  AppError conversion.
- <ADD-PROJECT-SPECIFIC-FORBIDDEN-PATTERNS>

## Environment expectations

- Rust toolchain: stable, MSRV <VERSION>.
- `cargo`, `rustc`, `clippy`, `rustfmt` installed via rustup.
- Do NOT assume nightly features.
- Do NOT install crates outside the workspace lockfile.
- <ADD-PROJECT-SPECIFIC-ENV>

## Where to look for ___

- Error types: `<PATH-TO-ERROR-MODULE>`
- Schema sub-command: `<PATH-TO-SCHEMA-CMD>`
- JSON envelope: `<PATH-TO-ENVELOPE>`
- Output mode detection: `<PATH-TO-OUTPUT-MODE>`
- Integration tests: `<PATH-TO-INTEGRATION-TESTS>`

## Standards compliance

This project follows the Spacecraft Software Dual-Mode Self-Documenting CLI Standard (v1.0.0). The
`spacecraft-cli-standard` and `spacecraft-agentic-cli` skills are
authoritative on structural and agentic conventions. This file
documents project-specific deviations and supplements only.
