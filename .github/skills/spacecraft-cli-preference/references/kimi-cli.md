# kimi-cli (kimi)

**Replaces:** general-purpose coding assistants | **Language:** ⚠️ | **Install:** upstream

## Purpose
CLI for Moonshot AI. Long-context (≥200k token) specialisation — handy for large-codebase queries.

## Launch
```
kimi                     # REPL
kimi "<prompt>"          # one-shot
```

## Examples
1. Ingest a whole crate and ask a question: `cat src/**/*.rs | kimi "find every place we call .unwrap()"`
2. Summarise a long spec: `kimi -p "summarise key decisions" < design.md`

## Gotchas
- Requires Moonshot API credentials.
- Ingesting huge contexts can be slow/expensive — chunk when possible.
