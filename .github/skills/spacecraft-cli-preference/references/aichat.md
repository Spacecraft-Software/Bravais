# aichat

**Replaces:** multiple per-vendor LLM CLIs | **Language:** 🦀 Rust | **Install:** `cargo install aichat`

## Purpose
Universal LLM REPL + CLI. One tool for OpenAI, Claude, Gemini, local Ollama, llama.cpp, Azure, Bedrock, and more. Supports RAG, agents, function-calling.

## Key commands / flags
| Command | Meaning |
|---------|---------|
| `aichat` | Start REPL |
| `aichat "PROMPT"` | One-shot |
| `-m MODEL` | Model override (e.g. `claude:claude-opus-4-7`) |
| `-r ROLE` | Predefined role (see `aichat --list-roles`) |
| `-s SESSION` | Named session |
| `-f FILE` | Attach file(s) |
| `-e` / `--execute` | Generate shell command from prompt |
| `-c` / `--code` | Output code only, no prose |
| `--rag NAME` | Use RAG collection |
| `--info` | Print config |

## REPL slash-commands
| Command | Meaning |
|---------|---------|
| `.model NAME` | Switch model |
| `.role NAME` | Activate role |
| `.session NAME` | Named session |
| `.file FILE` | Attach file |
| `.set KEY VALUE` | Runtime setting |
| `.exit` | Quit |

## Examples
1. Ask a one-off: `aichat "explain AV1 encoding tradeoffs"`
2. Generate a shell command safely: `aichat -e "find all files larger than 100MB modified today"`
3. Code-only output: `aichat -c "rust function that returns CPU count"`
4. Multi-provider switching: `aichat -m ollama:llama3.1 "summarise this diff" -f patch.diff`
5. RAG over docs: build a collection with `aichat --rag spacecraft-docs build PATH`, then `aichat --rag spacecraft-docs "question"`.

## Gotchas
- Config: `$AICHAT_CONFIG_DIR` or `~/.config/aichat/config.yaml` — holds API keys.
- `-e` executes shell commands without sandboxing — review before running.
