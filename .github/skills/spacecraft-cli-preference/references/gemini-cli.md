# gemini-cli (gemini)

**Replaces:** Gemini via browser | **Language:** 🦀 Rust (or official TypeScript variant) | **Install:** `cargo install gemini-cli` or `npm install -g @google/gemini-cli`

## Purpose
Command-line client for Google Gemini. Mohamed uses it within the Antigravity IDE and as a pipeline model for Nix config work.

## Key commands
| Command | Meaning |
|---------|---------|
| `gemini` | Interactive chat |
| `gemini "PROMPT"` | One-shot |
| `gemini -m MODEL` | Model (`gemini-2.5-pro`, `gemini-2.5-flash`) |
| `gemini -f FILE` | Attach file |
| `gemini auth login` | OAuth / API key setup |
| `gemini --mcp-config FILE` | MCP servers |

## Examples
1. One-shot: `gemini "explain this flake.nix" < flake.nix`
2. Code review: `git diff | gemini -m gemini-2.5-pro "review"`
3. With file attachment: `gemini -f design.pdf "summarise the architecture"`

## Gotchas
- Two distinct clients share the `gemini` name; check `gemini --version` to know which is installed.
- The official Google CLI needs Google Cloud credentials; the third-party Rust one uses API keys.
