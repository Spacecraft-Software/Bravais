# opencode

**Replaces:** closed-source AI coding agents | **Language:** 🐹 Go | **Install:** upstream installer

## Purpose
Open-source AI coding assistant. Bring-your-own-model (OpenAI, Anthropic, local). Configurable agent loop.

## Launch
```
opencode                 # TUI
opencode "<prompt>"      # one-shot
```

## Key flags
| Flag | Meaning |
|------|---------|
| `-m MODEL` / `--model` | Model override |
| `--provider NAME` | Provider override |
| `--config FILE` | Config |
| `-p` / `--print` | Non-interactive |
| `--mcp-config FILE` | MCP servers |

## Examples
1. Launch TUI: `opencode`
2. Non-interactive with Anthropic: `opencode -m claude-opus-4-7 "add logging to this module"`
3. Local model via Ollama: `opencode --provider ollama -m llama3.1 "…"`

## Gotchas
- Config lives in `~/.opencode/` — API keys stored here, treat like `~/.ssh/`.
- Mohamed's fork is `UnbreakableMJ/opencode` — check for pipeline-specific tweaks.
