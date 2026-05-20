# kilo

**Replaces:** agentic engineering platforms | **Language:** ⚠️ TypeScript | **Install:** upstream

## Purpose
Agentic engineering platform CLI. Orchestrates multi-step software tasks.

## Launch
```
kilo                     # start platform
kilo task "DESCRIPTION"  # submit a task
```

## Gotchas
- Project-specific configuration under `.kilo/` in the repo.
- Confirm model provider env vars are set before running (`OPENAI_API_KEY` / `ANTHROPIC_API_KEY`).
