# claude-code (Claude Code)

**Replaces:** other AI coding agents | **Language:** ⚠️ TypeScript | **Install:** `npm install -g @anthropic-ai/claude-code` (Node.js 18+)

## Purpose
Anthropic's official command-line coding agent. Reads/edits/runs code in your terminal with MCP server integration. **Mohamed's primary agent; elevated role in the clean-room multi-agent pipeline.**

## Launch
```
claude                    # start interactive session in $PWD
claude "<prompt>"         # one-shot
claude -p "<prompt>"      # print-mode non-interactive
claude --resume           # resume previous session
claude --continue         # continue last session
```

## Key flags
| Flag | Meaning |
|------|---------|
| `-p` / `--print` | Non-interactive single turn |
| `--resume` | Pick a session from history |
| `--continue` | Continue most recent |
| `--model NAME` | Override model (e.g. `claude-opus-4-7`) |
| `--add-dir PATH` | Grant access to directory outside cwd |
| `--mcp-config FILE` | Load MCP servers from file |
| `--permission-mode MODE` | `default`, `acceptEdits`, `bypassPermissions`, `plan` |
| `--verbose` | Extra debug output |

## Slash commands (inside session)
| Command | Meaning |
|---------|---------|
| `/help` | List commands |
| `/clear` | Reset conversation |
| `/model` | Switch model |
| `/mcp` | Manage MCP servers |
| `/permissions` | Permission settings |
| `/cost` | Token usage |
| `/compact` | Compact transcript |
| `/exit` | Quit |

## Examples
1. Start in repo: `cd ~/code/ferrocast && claude`
2. One-shot code review: `claude -p "review the last commit and flag any unsafe blocks"`
3. Pipe into another tool: `claude -p "summarise this crate" < README.md`
4. With MCP config: `claude --mcp-config ~/.mcp.json`
5. Plan mode (no edits): `claude --permission-mode plan`

## Gotchas
- Needs Node.js 18+ and a `~/.claude.json` login.
- MCP servers in `.mcp.json` at repo root are auto-loaded (matches Mohamed's Antigravity MCP hub setup).
- When scripting, always use `-p` and inspect exit code; interactive mode doesn't play well in CI.
