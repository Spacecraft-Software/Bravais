# minimax-cli (minimax)

**Replaces:** vendor-specific coding agents | **Language:** 🦀 Rust | **Install:** upstream

## Purpose
Terminal-native AI coding assistant powered by MiniMax models.

## Launch
```
minimax                  # REPL
minimax "<prompt>"       # one-shot
```

## Key flags
| Flag | Meaning |
|------|---------|
| `-m MODEL` | Model override |
| `-p` | Non-interactive |
| `--config FILE` | Config |

## Examples
1. Interactive: `minimax`
2. One-shot review: `minimax -p "review for unsafe blocks" < src/lib.rs`

## Gotchas
- Requires MiniMax API credentials.
- Less mature than Claude Code / Codex — treat as secondary agent in pipelines.
