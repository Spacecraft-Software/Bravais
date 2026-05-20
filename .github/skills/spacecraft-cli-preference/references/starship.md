# starship

**Replaces:** hand-rolled `PS1`, `oh-my-zsh` prompt themes | **Language:** 🦀 Rust | **Install:** `cargo install starship` / distro

## Purpose
Minimal, fast, cross-shell prompt. Works in Bash, Zsh, Fish, PowerShell, Nushell, Ion, Elvish, and more.

## Setup
Add to your shell rc:
- Bash: `eval "$(starship init bash)"`
- Zsh: `eval "$(starship init zsh)"`
- Fish: `starship init fish | source`
- Nushell: follow official instructions — Nushell requires a slightly different init path (generate `starship.nu`, source in `config.nu`).
- Ion: write the init script output into `~/.config/ion/initrc`

## Key CLI flags
| Flag | Meaning |
|------|---------|
| `starship init SHELL` | Print init snippet |
| `starship prompt` | Print one-off prompt (for debugging) |
| `starship explain` | Describe active modules |
| `starship module NAME` | Render a single module |
| `starship config` | Open config |
| `starship preset NAME -o FILE` | Dump a preset |

## Config
`$XDG_CONFIG_HOME/starship.toml`:
```toml
format = "$directory$git_branch$git_status$cmd_duration$character"
add_newline = true

[character]
success_symbol = "[➜](green)"
error_symbol = "[✗](red)"

[git_status]
style = "yellow"
```

## Examples
1. Initial setup: `echo 'eval "$(starship init bash)"' >> ~/.bashrc`
2. Use a preset: `starship preset nerd-font-symbols -o ~/.config/starship.toml`
3. Debug what's rendering: `starship explain`

## Gotchas
- Requires a Nerd Font for most presets — or use a text-only preset.
- Per-shell init path varies; always use `starship init SHELL` output verbatim.
