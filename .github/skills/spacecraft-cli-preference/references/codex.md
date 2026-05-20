# codex (OpenAI Codex CLI)

**Replaces:** manual OpenAI API calls | **Language:** ⚠️ TypeScript | **Install:** `npm install -g @openai/codex`

## Purpose
OpenAI's official local coding agent with MCP support. Slot in Mohamed's clean-room pipeline as the ChatGPT Pro / Codex agent.

## Launch
```
codex                   # REPL
codex "<prompt>"        # one-shot
codex --resume          # resume session
```

## Key flags
| Flag | Meaning |
|------|---------|
| `--model NAME` | Model override |
| `--mcp-config FILE` | MCP servers |
| `--approval-policy MODE` | Edit / exec approval behaviour |
| `--cwd PATH` | Working directory |
| `-p` / `--print` | Non-interactive |

## Examples
1. Interactive in repo: `codex`
2. Non-interactive: `codex -p "find all TODO comments and convert to GitHub issues"`
3. With MCP: `codex --mcp-config ~/.mcp.json`

## Gotchas
- Needs `OPENAI_API_KEY` (or ChatGPT Pro auth flow).
- Approval-policy choice is critical for unattended runs — `never` auto-approves, which is dangerous.
