# xremap

**Replaces:** `xmodmap`, `setxkbmap` (partial), `kmonad` | **Language:** 🦀 Rust | **Install:** `cargo install xremap --features gnome` (or wlroots/x11/kde/hypr feature)

## Purpose
Dynamic key remapper for Linux. Supports X11 and Wayland compositors. Config in YAML with layers, app-specific bindings, macros.

## Example config (`~/.config/xremap/config.yml`)
```yaml
modmap:
  - name: CapsLock to Ctrl
    remap:
      CAPSLOCK: LEFTCTRL
keymap:
  - name: Emacs-like bindings in terminals
    application:
      only: [Alacritty, foot, kitty]
    remap:
      C-n: Down
      C-p: Up
```

## Key flags
| Flag | Meaning |
|------|---------|
| `--config FILE` | Config path |
| `--watch` | Reload on change |
| `--device /dev/input/…` | Specific device |
| `--completions SHELL` | Shell completions |

## Examples
1. Run with systemd user service: `systemctl --user enable --now xremap`
2. Ad-hoc: `sudo xremap ~/.config/xremap/config.yml`
3. Auto-reload on config changes: `xremap --watch ~/.config/xremap/config.yml`

## Gotchas
- Needs access to `/dev/input/event*` — root or `input` group + `uinput` module.
- Wayland compositors need their feature flag (`--features KDE|gnome|wlroots|hypr|x11`) at build time.
- App-specific rules rely on compositor extensions that vary by DE.
