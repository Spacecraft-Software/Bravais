# gws-cli (gws)

**Replaces:** `gcloud`-based Google Workspace scripts | **Language:** 🦀 Rust | **Install:** `cargo install gws-cli`

## Purpose
Unified Google Workspace CLI built to be equally usable by humans and AI agents. Drive, Docs, Sheets, Calendar, Gmail in one tool.

## Key commands
| Command | Meaning |
|---------|---------|
| `gws auth login` | OAuth authentication |
| `gws drive list` | List Drive files |
| `gws drive upload FILE` / `download ID` | Up/download |
| `gws docs read ID` / `append ID TEXT` | Docs manipulation |
| `gws sheets read ID RANGE` / `write ID RANGE VAL` | Sheets |
| `gws calendar list` / `create` | Calendar events |
| `gws mail send --to … --subject …` | Send email |
| `gws config` | View/set config |

## Examples
1. List Drive: `gws drive list --query "name contains 'Spacecraft Software'"`
2. Append to a Doc: `gws docs append DOC_ID "Session notes: …"`
3. Script-friendly output: `gws drive list -o json | jaq '.[] | .name'`

## Gotchas
- OAuth stores tokens under `$XDG_CONFIG_HOME/gws/` — treat as credentials.
- Designed for agent use — pairs well with `claude-code` MCP integration.
