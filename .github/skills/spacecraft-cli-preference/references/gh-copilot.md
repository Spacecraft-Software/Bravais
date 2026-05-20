# gh-copilot (GitHub Copilot CLI)

**Replaces:** — (official GitHub AI assistant) | **Language:** ⚠️ TypeScript | **Install:** `gh extension install github/gh-copilot`

## Purpose
GitHub's official AI terminal assistant. Provides `gh copilot suggest` and `gh copilot explain`.

## Key commands
| Command | Meaning |
|---------|---------|
| `gh copilot suggest "QUERY"` | Suggest a command |
| `gh copilot explain "CMD"` | Explain a command |
| `gh copilot --help` | Help |

## Suggest target types
- `-t shell` — shell command (default)
- `-t gh` — gh CLI command
- `-t git` — git command

## Examples
1. Suggest a shell command: `gh copilot suggest "compress all .log files older than 7 days"`
2. Explain a command: `gh copilot explain "find . -name '*.rs' -newer file.txt"`
3. gh-specific: `gh copilot suggest -t gh "list my open PRs"`

## Gotchas
- Requires active GitHub Copilot subscription and `gh auth login`.
- Suggestions are not executed automatically — review first.
