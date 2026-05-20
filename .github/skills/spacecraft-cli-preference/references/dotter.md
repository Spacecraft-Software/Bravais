# dotter

**Replaces:** `stow`, `chezmoi`, `yadm` | **Language:** 🦀 Rust | **Install:** `cargo install dotter`

## Purpose
Dotfile manager with templating (Handlebars), per-package toggling, and symlink/copy deployment.

## Project layout
```
dotfiles/
├── .dotter/
│   ├── global.toml
│   └── local.toml
├── nushell/
│   └── config.nu
└── starship/
    └── starship.toml
```

## Key commands
| Command | Meaning |
|---------|---------|
| `dotter deploy` | Apply configs |
| `dotter undeploy` | Remove deployed files |
| `dotter init` | Initialise `.dotter/` |
| `dotter -p` / `--patch` | Generate diffs instead of applying |
| `dotter -d` / `--dry-run` | Dry run |
| `-c FILE` / `--config FILE` | Alt config file |
| `-f` / `--force` | Overwrite existing |

## Examples
1. Deploy current host's configs: `dotter deploy`
2. Preview: `dotter -d deploy`
3. Templated config with variables: define in `.dotter/local.toml`, use `{{ .variable }}` in source files

## Gotchas
- Lives well with git — commit `.dotter/global.toml` but keep `local.toml` per-host.
- First deploy aborts if target exists; use `-f` only after reviewing.
