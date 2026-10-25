# Keybindings — one scheme across every session

The long form of PRD §9's keybinding notes. Bravais keeps one set of keys
across GNOME, Plasma, Niri, LeftWM and Margo, the way Garuda keeps its
i3/Sway/Hyprland keys in its DE editions: each window manager's keys are added
to GNOME and Plasma **next to** their stock keys, and the WMs change only where
they disagreed with each other. "Super", "Meta" and "Mod" are the same key.

**Change one session, change all five.** Where a key lives:

| Session | File | How it is written |
|---|---|---|
| GNOME 50 | `users/mj/gnome.nix` | `dconf.settings`, plus an activation step that appends to the two lists GNOME shares with Settings (`enabled-extensions`, `custom-keybindings`) |
| Plasma 6 | `users/mj/plasma.nix` | `kwriteconfig6` into `kglobalshortcutsrc` on activation (pinned: a System Settings change is reverted at the next rebuild); app keys as `X-KDE-Shortcuts` defaults (a rebind sticks) |
| Niri | `users/mj/niri.nix` | `binds { }`; `Mod+Shift+/` shows them |
| LeftWM | `modules/desktops/leftwm.nix` | `keybind: [ ]`, and the `keybinds.txt` that `Mod+Shift+/` shows — keep the two in step |
| Margo | `users/mj/margo.nix` | `bind =` lines; `Super+Shift+/` lists them |

COSMIC is installed too but keeps its own defaults, which already share most of
these keys; `users/mj/desktop-theme.nix` adds the few it lacks (Super+D,
Super+Space, Super+Shift+C, Super+Shift+D, F9, and Super+Return for
Alacritty).

## The shared keys

| Action | Key | Notes |
|---|---|---|
| Launcher / search | Super+D | GNOME: overview search. Plasma: KRunner. WMs: anyrun / rlaunch (LeftWM Mod+Shift+D: rofi) |
| App grid / menu | Super alone · Super+Shift+D | GNOME (app grid), Plasma (Kickoff) and COSMIC (App Library) take both; the WMs have Super+Shift+D only (rofi drun) |
| Terminal | Super+Return | Alacritty everywhere, COSMIC included. Plasma's Ctrl+Alt+T still opens Konsole; COSMIC's Super+T still opens COSMIC Terminal |
| Close window | Super+Q | Alt+F4 still works in GNOME and Plasma |
| Fullscreen | Super+F | |
| Maximize | Super+Shift+F (Niri: column) · Super+Up (GNOME) · Meta+PgUp (Plasma) | LeftWM and Margo have none |
| Toggle floating | Super+V | Niri, LeftWM, Margo. GNOME and Plasma do not tile; there Super+V is notifications / clipboard |
| Focus | Super+arrows, Super+Alt+H/J/K/L | WMs. LeftWM has up/down only (lefthk limit). Plain Super+H/J/K/L no longer focus: Super+L locks |
| Move / swap window | Super+Shift+arrows, Super+Shift+H/J/K/L | WMs. LeftWM has up/down only |
| Workspace 1–9 | Super+1…9 | GNOME and Plasma give up "open the Nth dock / task-bar app" for this |
| Send window to 1–9 | Super+Shift+1…9 | |
| Previous / next workspace | Super+Ctrl+←/→ | Niri's workspaces are vertical: Mod+PgUp/PgDn there |
| Mouse thumb buttons | workspace ←/→ | Niri: column ←/→. Niri and Margo bind them natively, so apps lose back/forward there |
| Keyboard layout (us/ara) | Super+Space | Ctrl+Space too in Plasma, LeftWM and Margo |
| Next tiling layout | Super+Ctrl+Space | LeftWM (Super+Ctrl+Shift+Space: previous), Margo |
| Lock | Super+L | LeftWM keeps Ctrl+Alt+L too |
| Exit session | Super+Shift+E | WMs. GNOME and Plasma: Ctrl+Alt+Del |
| Caffeine | Super+Shift+C | |
| Keyring unlock (rescue) | Super+Shift+U | WMs |
| Cheat-sheet | Super+Shift+/ | WMs |
| Screenshot | Print = region or the screenshot UI · Super+Print = focused window · Shift+Print = whole screen | Margo has no window capture yet (no `mscreenshot` in the package) |

Hardware keys (volume, mute, mic mute, brightness, media, keyboard backlight,
Bluetooth, airplane) work in all five: `swayosd` under Niri and Margo,
`steelbore-osd` under LeftWM, the desktops' own OSDs in GNOME and Plasma.
The F9 gear key (`XF86Tools`) opens the desktop's settings app: GNOME and
Plasma bind it by default, and COSMIC gets it from the custom-shortcut RON in
`users/mj/desktop-theme.nix`. The WMs leave it unbound.

## Per-session extras

These are kept as they are; they do not collide with the shared keys.

- **GNOME:** Super+A app grid, Super+S quick settings, Super+V / Super+M
  notifications, Super+N focus notification, Super+H minimize,
  Super+Left/Right half-tile, Super+Shift+arrows to another monitor,
  Super+PgUp/PgDn and Super+Alt+←/→ (and Ctrl+Alt+←/→) workspaces,
  Super+Home / Super+End first / last workspace, Super+Ctrl+1…9 new window of
  the Nth dock app, Alt+Tab / Super+Tab app switcher, Alt+F2 run.
  The Forge tiling extension keeps its own keys (Super+H/J/K focus,
  Super+Ctrl+H/J/K/L swap, Super+W, …) except the five it shipped on shared
  keys: *swap with last active* (Super+Return), *split vertical* (Super+V),
  *always float* (Super+Shift+C), *move right* (Super+Shift+L) and *focus
  right* (Super+L, the lock key) have no key.
  The same goes for O-tiling (installed by hand): *enter tiling mode*
  (Super+Return, Super+KP_Enter) and *toggle floating* (Super+F) have no key.
- **Plasma:** Meta+W overview, Meta+G desktop grid, Meta+PgDown minimize,
  Meta+arrows quick tile, Meta+Alt+arrows focus, Meta+Ctrl+Shift+←/→ window to
  desktop, Meta+F1–F4 and Ctrl+F1–F4 desktops 1–4, Meta+V clipboard,
  Meta+Shift+S region capture, Alt+Space / Alt+F2 KRunner. *Peek at Desktop*
  gave Meta+D to KRunner and the *Activity Switcher* gave Meta+Q to Close
  Window; both have no key now (Meta+Tab still cycles activities). The
  Krohnkite tiling script keeps its own keys (Meta+H/J/K focus,
  Meta+Shift+H/J/K/L move, Meta+T / Meta+M layouts, …) except the four it
  shipped on shared keys: *Set master* (Meta+Return), *Decrease* (Meta+D),
  *Toggle Float* (Meta+F) and *Focus Right* (Meta+L, the lock key) have no
  key.
- **Niri:** Mod+O overview, Mod+R / Mod+Minus / Mod+Equal column widths,
  Mod+[ / Mod+] consume / expel, Mod+Tab previous workspace, Mod+wheel
  workspaces, Mod+B / Mod+Shift+B Bluetooth, Mod+A / Mod+Shift+A audio,
  Mod+Shift+Minus / Equal output scale.
- **LeftWM:** Mod+` scratchpad terminal, Mod+Minus / Mod+Equal main width.
- **Margo:** Super+Ctrl+Return scratchpad, Super+T / S / M / Ctrl+G layouts,
  Super+R proportion presets, Super+W / E / Ctrl+E groups, Super+Ctrl+H/J/K/L
  move, Super+Ctrl+Shift+H/J/K/L resize, Super+Ctrl+R reload, Super+F10
  monitors off, Super+B / Super+Shift+B Bluetooth, Super+Shift+A audio,
  Super+wheel tags.

## Known gaps

- **Forge does not load on GNOME 50** (the nixpkgs build declares GNOME 45–49),
  so GNOME has no tiling keys.
- GNOME workspaces are dynamic: Super+5 does nothing until a fifth workspace
  exists.
- Plasma registers keys for desktops that exist; keys for desktops 5–9 are
  inert until those desktops are created. A shifted digit is recorded both as
  its symbol (`Meta+!`, as System Settings writes it) and as `Meta+Shift+1`.
