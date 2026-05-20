# zoxide (z)

**Replaces:** `cd` + shell history navigation | **Language:** 🦀 Rust | **Install:** `cargo install zoxide` + shell init

## Purpose
Smart directory jumper. Ranks visited directories by frequency+recency ("frecency"). Bound to `z` (or any alias you pick).

## Shell init (required)
Add one of these to your rc:
- Bash: `eval "$(zoxide init bash)"`
- Zsh: `eval "$(zoxide init zsh)"`
- Fish: `zoxide init fish | source`
- **Nushell**: add `zoxide init nushell | save -f ~/.zoxide.nu` then `source ~/.zoxide.nu`
- **Ion**: `zoxide init ion` output into your `~/.config/ion/initrc`

## Key commands
| Command | Meaning |
|---------|---------|
| `z PATTERN` | Jump to best match |
| `z foo bar` | Jump to best dir matching both |
| `zi PATTERN` | Interactive selection (requires `fzf`) |
| `z -` | Previous directory (like `cd -`) |
| `zoxide add PATH` | Manually add |
| `zoxide remove PATH` | Remove from DB |
| `zoxide query PATTERN` | Print match without cd'ing |
| `zoxide edit` | Edit DB in `$EDITOR` |

## Examples
1. Jump to the last-used project directory matching `spacecraft-software`: `z spacecraft-software`
2. Match on two tokens: `z bravais src`
3. Pick interactively: `zi`
4. Preview match without jumping: `zoxide query -l bravais`

## Gotchas
- You must `cd` into directories first for zoxide to learn them.
- Conflicts with bash's builtin `z`/aliases — check `type z`.
- DB lives at `$_ZO_DATA_DIR` (defaults under `$XDG_DATA_HOME`).
