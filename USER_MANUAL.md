# Bravais User Manual

**A Steelbore OS NixOS Distribution**
**Version:** 2.1 | **Date:** 2026-04-05

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Login and Session Selection](#2-login-and-session-selection)
3. [Desktop Environments](#3-desktop-environments)
   - [Niri (Wayland)](#31-niri-wayland)
   - [LeftWM (X11)](#32-leftwm-x11)
   - [COSMIC (Wayland)](#33-cosmic-wayland)
   - [GNOME (Wayland)](#34-gnome-wayland)
4. [Terminal Emulators](#4-terminal-emulators)
5. [Keyboard Layout](#5-keyboard-layout)
6. [Shell Configuration](#6-shell-configuration)
7. [System Administration](#7-system-administration)
8. [Steelbore Theme](#8-spacecraft-software-theme)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Getting Started

### 1.1 System Overview

Bravais is a NixOS-based operating system built on the Spacecraft Software Standard. It features:

- **Four desktop environments:** Niri, LeftWM, COSMIC, and GNOME
- **Unified theming:** All applications use the Steelbore color palette
- **Rust-first tooling:** Memory-safe alternatives wherever possible
- **Declarative configuration:** All settings managed through Nix

### 1.2 First Boot

After installation, you will be greeted by the tuigreet login screen:

```
STEELBORE :: BRAVAIS
2026-04-05 14:30:00

Username: _
```

Enter your username and password to log in.

---

## 2. Login and Session Selection

### 2.1 tuigreet Interface

The login manager displays:
- Current date and time (ISO 8601 format)
- Username prompt
- Password prompt (displayed as asterisks)
- Session selector

### 2.2 Selecting a Desktop Session

After entering your username, press **F2** or use the session selector to choose:

| Session       | Description                          |
|---------------|--------------------------------------|
| niri-session  | Niri scrolling tiling (Wayland)      |
| start-cosmic  | COSMIC desktop (Wayland)             |
| gnome-session | GNOME desktop (Wayland)              |
| leftwm        | LeftWM tiling WM (X11)               |

The session selector remembers your last choice.

---

## 3. Desktop Environments

### 3.1 Niri (Wayland)

Niri is a scrolling tiling Wayland compositor. Windows are arranged in columns that scroll horizontally.

#### 3.1.1 Core Concepts

- **Columns:** Windows are stacked vertically within columns
- **Scrolling:** Columns scroll left/right across the workspace
- **Workspaces:** Multiple virtual workspaces (1-9)

#### 3.1.2 Keybindings

**Legend:** `Mod` = Super/Windows key

##### Session Control

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Shift+E`   | Quit Niri (logout)        |

##### Application Launch

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Return`    | Open terminal (Alacritty) |
| `Mod+D`         | Open launcher (onagre)    |
| `Mod+Shift+D`   | Open launcher (anyrun)    |

##### Window Management

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Q`         | Close focused window      |
| `Mod+F`         | Maximize column           |
| `Mod+Shift+F`   | Fullscreen window         |

##### Focus Navigation (Vim-style)

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+H`         | Focus column left         |
| `Mod+L`         | Focus column right        |
| `Mod+K`         | Focus window up           |
| `Mod+J`         | Focus window down         |

##### Focus Navigation (Arrow keys)

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Left`      | Focus column left         |
| `Mod+Right`     | Focus column right        |
| `Mod+Up`        | Focus window up           |
| `Mod+Down`      | Focus window down         |

##### Move Windows (Vim-style)

| Keybinding        | Action                    |
|-------------------|---------------------------|
| `Mod+Shift+H`     | Move column left          |
| `Mod+Shift+L`     | Move column right         |
| `Mod+Shift+K`     | Move window up            |
| `Mod+Shift+J`     | Move window down          |

##### Move Windows (Arrow keys)

| Keybinding        | Action                    |
|-------------------|---------------------------|
| `Mod+Shift+Left`  | Move column left          |
| `Mod+Shift+Right` | Move column right         |
| `Mod+Shift+Up`    | Move window up            |
| `Mod+Shift+Down`  | Move window down          |

##### Workspaces

| Keybinding        | Action                    |
|-------------------|---------------------------|
| `Mod+1` to `Mod+9`| Focus workspace 1-9       |
| `Mod+Shift+1` to `Mod+Shift+9` | Move column to workspace 1-9 |
| `Mod+WheelUp`     | Focus workspace up        |
| `Mod+WheelDown`   | Focus workspace down      |

##### Resize

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Minus`     | Decrease column width 10% |
| `Mod+Equal`     | Increase column width 10% |

##### Screenshots

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Print`         | Screenshot entire screen  |
| `Mod+Print`     | Screenshot focused window |

#### 3.1.3 Status Bar (Ironbar)

The top bar displays:
- **Left:** Workspace indicators, focused window title
- **Center:** Clock (HH:MM:SS :: YYYY-MM-DD)
- **Right:** CPU %, RAM %, system tray

---

### 3.2 LeftWM (X11)

LeftWM is a tiling window manager for X11, written in Rust.

#### 3.2.1 Core Concepts

- **Tags:** LeftWM uses "tags" instead of workspaces (1-9)
- **Layouts:** Multiple layout algorithms available
- **Scratchpad:** Hidden terminal accessible via keybinding

#### 3.2.2 Keybindings

**Legend:** `Mod` = Super/Windows key

##### Session Control

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Shift+E`   | Logout                    |

##### Application Launch

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Return`    | Open terminal (Alacritty) |
| `Mod+D`         | Open launcher (rlaunch)   |
| `Mod+Shift+D`   | Open launcher (rofi)      |

##### Window Management

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Q`         | Close focused window      |
| `Mod+F`         | Toggle fullscreen         |
| `Mod+Shift+F`   | Toggle floating           |

##### Focus Navigation (Vim-style)

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+H`         | Focus window left         |
| `Mod+L`         | Focus window right        |
| `Mod+K`         | Focus window up           |
| `Mod+J`         | Focus window down         |

##### Focus Navigation (Arrow keys)

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Left`      | Focus window left         |
| `Mod+Right`     | Focus window right        |
| `Mod+Up`        | Focus window up           |
| `Mod+Down`      | Focus window down         |

##### Move Windows (Vim-style)

| Keybinding        | Action                    |
|-------------------|---------------------------|
| `Mod+Shift+H`     | Move window left          |
| `Mod+Shift+L`     | Move window right         |
| `Mod+Shift+K`     | Move window up            |
| `Mod+Shift+J`     | Move window down          |

##### Tags (Workspaces)

| Keybinding        | Action                    |
|-------------------|---------------------------|
| `Mod+1` to `Mod+9`| Go to tag 1-9             |
| `Mod+Shift+1` to `Mod+Shift+9` | Move window to tag 1-9 |

##### Layout Control

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Space`     | Next layout               |
| `Mod+Shift+Space` | Previous layout         |

##### Resize

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Minus`     | Decrease main width       |
| `Mod+Equal`     | Increase main width       |

##### Scratchpad

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Mod+Grave`     | Toggle scratchpad terminal|

#### 3.2.3 Layouts

LeftWM supports multiple layout algorithms:

| Layout              | Description                              |
|---------------------|------------------------------------------|
| MainAndVertStack    | Main window left, stack right            |
| MainAndHorizontalStack | Main window top, stack below          |
| MainAndDeck         | Main window left, deck (tabs) right      |
| GridHorizontal      | Grid layout                              |
| EvenHorizontal      | Equal horizontal split                   |
| EvenVertical        | Equal vertical split                     |
| Fibonacci           | Fibonacci spiral layout                  |
| Monocle             | Single window fullscreen                 |

Press `Mod+Space` to cycle through layouts.

#### 3.2.4 Status Bar (Polybar)

The top bar displays:
- **Left:** Tag indicators (workspaces)
- **Center:** Clock (HH:MM:SS :: YYYY-MM-DD)
- **Right:** CPU %, RAM %, network status

---

### 3.3 COSMIC (Wayland)

COSMIC is a full-featured desktop environment from System76.

#### 3.3.1 Key Features

- Native Wayland compositor
- Integrated settings application
- cosmic-panel for taskbar
- cosmic-launcher for application search
- cosmic-term terminal emulator

#### 3.3.2 Default Keybindings

COSMIC uses standard keybindings:

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Super`         | Open launcher             |
| `Super+T`       | Open terminal             |
| `Super+E`       | Open file manager         |
| `Alt+F4`        | Close window              |
| `Super+Arrow`   | Tile window               |

Configure keybindings in **Settings > Keyboard > Shortcuts**.

---

### 3.4 GNOME (Wayland)

GNOME is a full-featured desktop environment with extensive customization through extensions.

#### 3.4.1 Installed Extensions

- Caffeine (prevent sleep)
- Just Perfection (UI tweaks)
- Window Gestures
- Vim Alt-Tab
- Open-Bar
- Launcher

#### 3.4.2 Default Keybindings

| Keybinding      | Action                    |
|-----------------|---------------------------|
| `Super`         | Activities overview       |
| `Super+A`       | Show applications         |
| `Super+Arrow`   | Tile window               |
| `Alt+Tab`       | Switch windows            |
| `Alt+F2`        | Run command               |

Configure keybindings in **Settings > Keyboard > Keyboard Shortcuts**.

---

## 4. Terminal Emulators

### 4.1 Available Terminals

| Terminal   | Launch Command | Description                   |
|------------|----------------|-------------------------------|
| Alacritty  | `alacritty`    | Default, GPU-accelerated      |
| WezTerm    | `wezterm`      | Feature-rich, Lua config      |
| Rio        | `rio`          | Rust-based, native rendering  |
| Ghostty    | `ghostty`      | Zig-based, very fast          |
| COSMIC Term| `cosmic-term`  | COSMIC native terminal        |
| Ptyxis     | `ptyxis`       | GNOME VTE-based               |
| WaveTerm   | `waveterm`     | AI-native terminal            |
| Warp       | `warp-terminal`| AI-powered terminal           |

### 4.2 Recommended Usage

- **Daily use:** Alacritty or Ghostty (fastest)
- **Feature-rich:** WezTerm (tabs, splits, Lua scripting)
- **AI features:** WaveTerm or Warp
- **COSMIC integration:** cosmic-term
- **GNOME integration:** Ptyxis

All terminals are themed with the Steelbore color palette.

---

## 5. Keyboard Layout

### 5.1 Available Layouts

- **Primary:** US English (`us`)
- **Secondary:** Arabic (`ara`)

### 5.2 Switching Layouts

Press **Ctrl+Space** to toggle between US and Arabic layouts.

The current layout is indicated in the status bar.

---

## 6. Shell Configuration

### 6.1 Default Shell

The default shell is **Nushell** (`nu`), a modern shell written in Rust.

### 6.2 Built-in Aliases

| Alias            | Command                    | Description              |
|------------------|----------------------------|--------------------------|
| `ll`             | `ls -l`                    | Long listing             |
| `lla`            | `ls -la`                   | Long listing with hidden |
| `telemetry`      | `macchina`                 | System information       |
| `sensors`        | `watch -n 1 sensors`       | Hardware sensors         |
| `sys-logs`       | `journalctl -p 3 -xb`      | System error logs        |
| `network-diag`   | `gping google.com`         | Network diagnostics      |
| `top-processes`  | `bottom`                   | Process monitor          |
| `disk-telemetry` | `yazi`                     | File manager             |
| `edit`           | `hx`                       | Helix editor             |

### 6.3 Steelbore Identity

Run `steelbore` in the terminal to display the system identity banner:

```
============================================================
  STEELBORE :: Industrial Sci-Fi Desktop Environment
============================================================
  STATUS    :: ACTIVE
  LOAD      :: NOMINAL
  INTEGRITY :: VERIFIED
============================================================
```

### 6.4 Starship Prompt

The prompt displays:
- Current directory (blue)
- Git branch (cyan)
- Git status (red if dirty)
- Command duration (amber, if >2s)
- Success/error indicator (green/red)

---

## 7. System Administration

### 7.1 Rebuilding the System

After modifying configuration files in `/spacecraft-software/bravais/`:

```bash
# Navigate to configuration directory
cd /spacecraft-software/bravais

# Rebuild and switch
sudo nixos-rebuild switch --flake .#bravais
```

### 7.2 Common Operations

| Task                    | Command                                    |
|-------------------------|--------------------------------------------|
| Rebuild system          | `sudo nixos-rebuild switch --flake .#bravais` |
| Test build (no switch)  | `nixos-rebuild build --flake .#bravais`    |
| Dry-run build           | `nixos-rebuild dry-build --flake .#bravais`|
| Update flake inputs     | `nix flake update`                         |
| Garbage collection      | `sudo nix-collect-garbage -d`              |
| List generations        | `sudo nix-env --list-generations -p /nix/var/nix/profiles/system` |
| Rollback                | `sudo nixos-rebuild switch --rollback`     |

### 7.3 Configuration Locations

| Component        | Location                                    |
|------------------|---------------------------------------------|
| System config    | `/spacecraft-software/bravais/`                       |
| Host config      | `/spacecraft-software/bravais/hosts/bravais/`         |
| User config      | `/spacecraft-software/bravais/users/mj/home.nix`      |
| Hardware config  | `/spacecraft-software/bravais/hosts/bravais/hardware.nix` |

### 7.4 Android development

`adb` is installed system-wide. Plug a handset in, enable USB debugging on it,
and:

```nu
adb devices
```

No group membership and no re-login are needed — systemd handles device access
automatically on this release.

The **SDK** is not installed system-wide; it lives in a devShell, so each
project can pick its own platform and build-tools versions:

```nu
nix develop /spacecraft-software/bravais#android -c nu
```

That drops you into Nushell (not bash) with `ANDROID_HOME`, `ANDROID_SDK_ROOT`,
`JAVA_HOME`, `gradle` and the SDK's `platform-tools` / `cmdline-tools` on
`PATH`. Verify with:

```nu
$env.ANDROID_HOME
sdkmanager --list_installed
```

To change which SDK pieces you get — other platform levels, the NDK, the
emulator — edit `androidComposition` in `flake.nix`. Platform API levels 27-36
are available on this channel; 37 is not.

### 7.5 Fingerprint Enrollment

Enroll as **yourself**, not through `sudo` — `sudo fprintd-enroll` enrolls
*root's* finger, which is not what you want:

```bash
fprintd-enroll          # enroll a finger (needs a polkit agent — see below)
fprintd-list "$USER"    # what is enrolled
fprintd-verify          # test it
```

Enrollment needs a running polkit authentication agent, because
`net.reactivated.fprint.device.enroll` is `auth_self_keep`. Niri and LeftWM
both spawn one at session start; a bare TTY does not.

**Where the fingerprint is accepted:**

- `sudo` / `sudo -i`
- polkit dialogs (Flatpak installs, udisks mounts, fingerprint enrollment)
- screen unlock — gtklock, the COSMIC lock screen (`cosmic-greeter`), and swaylock / xlock / vlock if ever used
- `gitway-add`, once enrolled — see §7.7

**Where it is deliberately refused, and why.** Fingerprint *authenticates*; it
cannot *decrypt*. Your login keyring is encrypted with the password you type at
greetd, and `pam_fprintd` is `sufficient` at PAM order 11400 — ahead of
`pam_gnome_keyring` at 12200 — so a fingerprint login short-circuits `auth`
before the keyring module ever receives a password. The keyring would stay
locked, and Chromium-family browsers, finding no reachable Safe Storage key,
would mint a fresh one and drop every saved login. That is what logged Opera
out on 2026-07-21 and Chrome on 2026-07-25.

So fingerprint is refused for:

- **session entry** — `greetd`, TTY `login` (and `cosmic-greeter` *only* if it is ever made the display manager; today it is just the COSMIC lock screen, where fingerprint works)
- **anything needing the old password** — `passwd`, `chpasswd`. These re-key
  the login keyring, which is impossible without `PAM_OLDAUTHTOK`.
- **account/identity mutation** — `chsh`, `chfn`, `useradd`, `userdel`,
  `usermod`, `group*`
- **non-conversational contexts** — `su`, `runuser`, `systemd-run0`,
  `systemd-user`, `cups`

The authoritative list is `fprintAllow` / `fprintDeny` in
`modules/hardware/fingerprint.nix`. Verify what actually shipped with:

```bash
grep -l pam_fprintd /etc/pam.d/* | sort   # must equal fprintAllow
```

### 7.6 Keyring

The login keyring is unlocked automatically by the password you type at greetd.
Two helpers exist for when that goes wrong:

```bash
steelbore-keyring-check     # read-only diagnosis; safe any time
steelbore-keyring-unlock    # raise the unlock dialog (also Mod+Shift+U)
```

`steelbore-keyring-check` runs automatically ~5 s into every Niri and LeftWM
session and notifies via dunst. Its exit codes:

| Code | Meaning |
|------|---------|
| `0` | OK — `default` alias points at `login`, unlocked, no dangling items |
| `2` | The default collection is locked. Run `steelbore-keyring-unlock`. |
| `3` | The `default` alias is unset, or points somewhere other than `login` |
| `4` | Dangling items — lookups fail with "No such secret item at path" |

**Exit 3 is the dangerous one.** Chromium-family Safe Storage keys resolve
through the `default` alias, so if it points at the wrong collection your
browsers will store into a keyring that PAM does not manage. Repair it:

```bash
busctl --user call org.freedesktop.secrets /org/freedesktop/secrets \
  org.freedesktop.Secret.Service SetAlias so default \
  /org/freedesktop/secrets/collection/login
```

If a keyring file is ever unopenable, test candidate passwords **offline**
rather than against the daemon — a broken daemon and a wrong password look
identical through a prompt. gnome-keyring 50 derives its key with
`egg_symkey_generate_simple(AES128, SHA256, password, salt, iterations)`, then
AES-128-CBC, and validates with `MD5(plaintext[16:]) == plaintext[:16]`.

### 7.7 SSH key unlock by fingerprint (gitway)

`gitway` is built with its `biometric` feature. Enrolling stores the SSH key's
passphrase in the login keyring and lets fprintd gate its release, so
`gitway-add` stops prompting through ksshaskpass:

```bash
gitway biometric enroll ~/.ssh/id_ed25519
gitway biometric list      # expect count: 1
```

Two things to know:

- **Do not pass `--biometric` to `gitway-add`.** That flag means
  *enroll-then-load* and forces a passphrase prompt every time. After the
  one-time enroll above, plain `gitway-add` is already fingerprint-unlocked.
- This is **convenience, not a security boundary**. `gitway biometric status`
  reports `tier: advisory` — the passphrase is protected by your login keyring,
  not by the sensor, so anyone with an unlocked session bypasses the gate.

Enroll only *after* the login keyring is healthy (`steelbore-keyring-check`
returns 0), since enrollment writes into the default collection.

---

## 8. Steelbore Theme

### 8.1 Color Palette

| Color          | Hex       | Usage                        |
|----------------|-----------|------------------------------|
| Void Navy      | `#000027` | Background (mandatory)       |
| Molten Amber   | `#D98E32` | Primary text, active elements|
| Steel Blue     | `#4B7EB0` | Accents, borders, inactive   |
| Radium Green   | `#50FA7B` | Success, confirmations       |
| Red Oxide      | `#FF5C5C` | Errors, warnings             |
| Liquid Coolant | `#8BE9FD` | Info, links, highlights      |

### 8.2 Fonts

| Context        | Font              |
|----------------|-------------------|
| UI Headers     | Orbitron          |
| Code/Terminal  | JetBrains Mono    |
| Status/HUD     | Share Tech Mono   |

### 8.3 Environment Variables

The theme exports these variables for application use:

```bash
SPACECRAFT_BACKGROUND=#000027
SPACECRAFT_TEXT=#D98E32
SPACECRAFT_ACCENT=#4B7EB0
SPACECRAFT_SUCCESS=#50FA7B
SPACECRAFT_WARNING=#FF5C5C
SPACECRAFT_INFO=#8BE9FD
```

---

## 9. Troubleshooting

### 9.1 Display Issues

**Problem:** Screen is blank after login

**Solution:**
1. Press `Ctrl+Alt+F2` to switch to TTY2
2. Log in
3. Check logs: `journalctl -b -p err`
4. Try a different session (e.g., GNOME instead of Niri)

### 9.2 Audio Issues

**Problem:** No sound

**Solution:**
1. Check PipeWire status: `systemctl --user status pipewire`
2. Restart PipeWire: `systemctl --user restart pipewire`
3. Check volume: `wpctl get-volume @DEFAULT_AUDIO_SINK@`
4. Set volume: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 50%`

### 9.3 Network Issues

**Problem:** No network connection

**Solution:**
1. Check NetworkManager: `nmcli general status`
2. List connections: `nmcli connection show`
3. Connect to WiFi: `nmcli device wifi connect "SSID" password "PASSWORD"`

### 9.4 Build Failures

**Problem:** `nixos-rebuild` fails

**Solution:**
1. Check for syntax errors in Nix files
2. Run with `--show-trace` for detailed errors
3. Verify flake: `nix flake check`
4. Update flake lock: `nix flake update`

### 9.5 Session Won't Start

**Problem:** Selected session crashes immediately

**Solution:**
1. Check session logs: `journalctl --user -b`
2. Try starting manually from TTY:
   - Niri: `niri-session`
   - COSMIC: `start-cosmic`
   - GNOME: `dbus-run-session gnome-session`
   - LeftWM: `startx leftwm`

### 9.6 Fingerprint Not Working

**Problem:** Fingerprint authentication fails

**Solution:**
1. Re-enroll: `sudo fprintd-enroll`
2. Check device: `fprintd-list $USER`
3. Verify PAM configuration is enabled

---

## Quick Reference Card

### Niri Essentials

| Key           | Action              |
|---------------|---------------------|
| `Mod+Return`  | Terminal            |
| `Mod+D`       | Launcher            |
| `Mod+Q`       | Close window        |
| `Mod+H/J/K/L` | Navigate (vim)      |
| `Mod+1-9`     | Workspaces          |
| `Mod+Shift+E` | Logout              |

### LeftWM Essentials

| Key           | Action              |
|---------------|---------------------|
| `Mod+Return`  | Terminal            |
| `Mod+D`       | Launcher            |
| `Mod+Q`       | Close window        |
| `Mod+H/J/K/L` | Navigate (vim)      |
| `Mod+1-9`     | Tags                |
| `Mod+Space`   | Next layout         |
| `Mod+Shift+E` | Logout              |

### System

| Key           | Action              |
|---------------|---------------------|
| `Ctrl+Space`  | Switch keyboard     |
| `Print`       | Screenshot          |

---

*--- Forged in Spacecraft Software ---*
