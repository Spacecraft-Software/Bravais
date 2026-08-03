# grok-cli (grok)

**Replaces:** xAI web UI | **Language:** ⚠️ TypeScript/Bun | **Install:** via `spacecraft-missing-pkg` (npm package: `grok-cli` (Bun-published))

## Purpose
Open-source conversational AI agent for xAI's Grok models.

## Launch
```
grok                     # REPL
grok "<prompt>"          # one-shot
```

## Key flags
| Flag | Meaning |
|------|---------|
| `-m MODEL` | Model override |
| `-p` | Non-interactive |

## Examples
1. Chat: `grok`
2. One-shot: `grok -p "summarise this" < article.txt`

## Gotchas
- Needs Bun runtime (or Node with polyfills).
- Requires xAI API key.
