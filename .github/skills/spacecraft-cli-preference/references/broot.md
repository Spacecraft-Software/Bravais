# broot (br)

**Replaces:** `tree`, `ranger` | **Language:** 🦀 Rust | **Install:** `cargo install broot`

## Purpose
Tree-oriented file navigator with incremental filter-as-you-type and shell integration that updates your parent shell's `cwd`.

## Setup
```
broot --install     # sets up `br` shell function for cd-on-exit
```

## Key flags
| Flag | Meaning |
|------|---------|
| `-h` | Show hidden |
| `-i` | Show gitignored |
| `-s` / `--sizes` | Show sizes |
| `-d` / `--dates` | Show mtimes |
| `-w` / `--whale-spotting` | Size-sorted descent (big-file hunt) |
| `-p` / `--permissions` | Show perms |
| `-g` / `--show-git-info` | Git statuses |
| `-c CMD` | Execute CMD on startup |

## Key bindings (in-app)
| Key | Action |
|-----|--------|
| Type | Filter |
| `↑`/`↓` | Navigate |
| `Enter` | Open / cd |
| `Alt+Enter` | cd + quit (via `br`) |
| `:` | Command input |
| `?` | Help |
| `Esc` | Clear |

## Examples
1. Navigate + cd: `br`
2. Hunt for big files: `br -w`
3. Filter Rust files by typing `/\.rs$`.

## Gotchas
- `br` (the shell wrapper) is what you should invoke — `broot` alone can't cd the parent shell.
- Config: `$XDG_CONFIG_HOME/broot/conf.hjson`.
