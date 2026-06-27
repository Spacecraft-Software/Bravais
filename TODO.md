# Bravais Implementation TODO

This document tracks the implementation status of the Bravais NixOS distribution based on the [Product Requirements Document (PRD.md)](./PRD.md) v3.0.

---

## Phase 1: Foundation & Structure

- [✓] Establish git repository structure
- [✓] Create `flake.nix` entry point with all inputs
- [✓] Configure stable nixpkgs (`nixos-26.05`)
- [✓] Configure unstable nixpkgs channel (`nixos-unstable`)
- [✓] Configure home-manager input (stable `release-26.05`, follows nixpkgs)
- [✓] Configure home-manager-unstable input (follows nixpkgs-unstable)
- [✓] Configure nix-flatpak input
- [✓] Configure gitway input (`github:Spacecraft-Software/Gitway`, tracks `main`; threaded via `specialArgs` / `extraSpecialArgs`)
- [✓] Define `mkBravais` function with `host` and `channel` parameters (march pinned per-machine)
- [✓] Generate per-machine `nixosConfigurations` (`bravais-thinkpad`, `bravais-thinkpad-unstable`, `bravais` alias)
- [✓] Factor shared host config into `hosts/common.nix`; one `hosts/<machine>/` dir per machine
- [✓] Set up `spacecraftPalette` in specialArgs
- [✓] ~~Pass `stablePkgs` to modules via specialArgs~~ (removed — claude-code now uses channel-appropriate `pkgs`)
- [✓] Build folder hierarchy (`hosts/`, `modules/`, `lib/`, `users/`, `overlays/`)

---

## Phase 2: Core Modules (`modules/core/`)

- [✓] **`default.nix`**: Core module entry point with imports
- [✓] **`boot.nix`**: systemd-boot configuration, EFI variables writable
- [✓] **`boot.nix`**: XanMod kernel (`linuxPackages_xanmod_latest`)
- [✓] **`boot.nix`**: initrd modules (`xhci_pci`, `nvme`, `usb_storage`, `sd_mod`, `rtsx_pci_sdmmc`)
- [✓] **`boot.nix`**: Kernel modules (`kvm-intel`)
- [✓] **`nix.nix`**: Enable flakes and nix-command
- [✓] **`nix.nix`**: Configure garbage collection (weekly, 30d retention)
- [✓] **`nix.nix`**: Allow unfree packages
- [✓] **`nix.nix`**: Define overlays inline (sequoia-wot fix, claude-code pin to latest npm release)
- [✓] **`locale.nix`**: Set timezone to `Asia/Bahrain`
- [✓] **`locale.nix`**: Configure `en_US.UTF-8` locale (all `LC_*` variables)
- [✓] **`locale.nix`**: Console keymap (`us`)
- [✓] **`audio.nix`**: Disable PulseAudio
- [✓] **`audio.nix`**: Enable PipeWire with ALSA/Pulse compatibility
- [✓] **`audio.nix`**: Enable rtkit for realtime audio
- [✓] **`security.nix`**: Disable standard sudo
- [✓] **`security.nix`**: Enable sudo-rs (Rust), `execWheelOnly = true`
- [✓] **`security.nix`**: Enable polkit
- [✓] **`security.nix`**: Enable SSH agent, disable GNOME keyring SSH agent
- [✓] **`security.nix`**: Configure tmpfiles rules (`/tmp`, `/var/tmp`)
- [✓] **`dns.nix`**: Enable `systemd-resolved` with DNS-over-TLS and DNSSEC enforced
- [✓] **`dns.nix`**: Cloudflare malware-block primary (`1.1.1.2` / `1.0.0.2` + v6, SNI `security.cloudflare-dns.com`)
- [✓] **`dns.nix`**: Plain Cloudflare fallback (`1.1.1.1` / `1.0.0.1` + v6, SNI `cloudflare-dns.com`)
- [✓] **`dns.nix`**: Global `~.` Domains entry to override DHCP-pushed link DNS
- [✓] **`dns.nix`**: Route NetworkManager DNS through `systemd-resolved`
- [✓] **`dns.nix`**: Stable/unstable schema portability via `options.services.resolved ? settings` check (silences four rename warnings × five unstable variants)

---

## Phase 3: Theme Engine (`modules/theme/`)

- [✓] **`default.nix`**: Define `SPACECRAFT_*` environment variables (6 colors)
- [✓] **`default.nix`**: Configure TTY console colors (16-color palette)
- [✓] **`fonts.nix`**: Install Hack Nerd Font (main / UI font — sans + serif)
- [✓] **`fonts.nix`**: Install JetBrains Mono Nerd Font (terminal / code font — monospace)
- [✓] **`fonts.nix`**: Install CaskaydiaMono Nerd Font (icon fallback) + Symbols-only Nerd Font (Rio glyph fallback)
- [✓] **`fonts.nix`**: Configure fontconfig defaults (monospace → JetBrainsMono, sans-serif/serif → Hack)
- Note: to change fonts later, follow the "Changing fonts" runbook in `CLAUDE.md`

---

## Phase 4: Login Management (`modules/login/`)

- [✓] **`default.nix`**: greetd + tuigreet with Steelbore branding
- [✓] **`default.nix`**: Session memory and ISO 8601 time display
- [✓] **`default.nix`**: Shell sessions (Ion, Nushell, Brush) via `mkShellSession`
- [✓] **`default.nix`**: Register session packages (niri, cosmic, ion, nushell, brush)
- [✓] **`default.nix`**: PAM gnome-keyring integration

---

## Phase 5: Desktop Environments (`modules/desktops/`)

### GNOME (`gnome.nix`)

- [✓] Define `spacecraft.desktops.gnome` option
- [✓] Enable GNOME on Wayland, disable GDM (use greetd)
- [✓] Install GNOME Tweaks, dconf-editor
- [✓] Install extension manager and browser connector
- [✓] Install curated extensions (14: Caffeine, Just Perfection, Forge, etc.)
- [✓] Configure XDG portals (gnome, gtk)
- [✓] Exclude bloatware (Tour, Music, Epiphany, Geary, Totem)

### COSMIC (`cosmic.nix`)

- [✓] Define `spacecraft.desktops.cosmic` option
- [✓] Enable COSMIC DE, disable cosmic-greeter (use greetd)

### KDE Plasma 6 (`plasma.nix`)

- [✓] Define `spacecraft.desktops.plasma` option
- [✓] Enable Plasma 6 on Wayland, disable SDDM (use greetd)
- [✓] Enable X server for XWayland support
- [✓] Configure SSH askpass override (`ksshaskpass`)
- [✓] Install KDE packages (8: browser-integration, kdeconnect, systemmonitor, etc.)
- [✓] Enable KWallet and Krohnkite tiling
- [✓] Enable GPG agent with pinentry-qt
- [✓] Exclude bloatware (oxygen, elisa, khelpcenter)

### Niri (`niri.nix`) -- The Spacecraft Software Standard

- [✓] Define `spacecraft.desktops.niri` option
- [✓] Enable Niri compositor
- [✓] Install companion packages (14: swaybg, xwayland-satellite, ironbar, waybar, etc.)
- [✓] Write Niri config with Steelbore palette (single source: `~/.config/niri/config.kdl` via `users/mj/home.nix`; niri prefers the user config over `/etc/niri`)
- [✓] Write `/etc/ironbar/config.yaml` and `/etc/ironbar/style.css`
- [✓] Configure keybindings (Vim-style + CUA arrows); `Mod+Return` → alacritty (default terminal)
- [✓] Configure workspaces 1-5
- [✓] Configure startup applications (swaybg, ironbar, wired)
- [✓] Idle management: swayidle (auto gtklock + screen-off via `niri msg action power-off-monitors`, lock before-sleep) + Caffeine toggle `Mod+Shift+C` (`steelbore-caffeine` SIGSTOP/SIGCONTs swayidle)
- [✓] Configure input (keyboard `us,ar` with `grp:ctrl_space_toggle`, touchpad)
- [✓] Map dedicated/multimedia keys (XF86): display + keyboard brightness, volume/mute/mic-mute, media (playerctl), Bluetooth + airplane-mode (rfkill wrappers w/ dunst feedback)
- [✓] swayosd OSD bars for brightness/volume (swayosd-server startup; Steelbore-themed `~/.config/swayosd/style.css`); brightnessctl udev rules for rootless backlight

### LeftWM (`leftwm.nix`)

- [✓] Define `spacecraft.desktops.leftwm` option
- [✓] Enable X11 and LeftWM, configure XKB layout (`us,ar`)
- [✓] Install companion packages (15: rlaunch, rofi, dmenu, polybar, picom, etc.)
- [✓] Write `/etc/leftwm/config.ron` with keybindings; `Mod+Return` → alacritty (default terminal)
- [✓] Write theme files (`theme.ron`, `up`, `down`, `polybar.ini`, `template.liquid`, `picom.conf`)
- [✓] Write `/etc/dunst/dunstrc` with Steelbore theme

---

## Phase 6: Package Modules (`modules/packages/`)

### Infrastructure

- [✓] **`default.nix`**: Package module entry with imports (all 12 submodules)

### browsers.nix

- [✓] Define `spacecraft.packages.browsers` option
- [✓] Enable Firefox via `programs.firefox`
- [✓] Install browsers (Chrome, Brave, Edge, Librewolf)
- [✓] Package BrowserOS AppImage as Nix derivation (`appimageTools.wrapType2`, pinned fetchurl)

### terminals.nix

- [✓] Define `spacecraft.packages.terminals` option
- [✓] Install Rust terminals (Alacritty, WezTerm, Rio, Warp)
- [✓] Install Ghostty (Zig)
- [✓] Install GTK/VTE terminals (Ptyxis, GNOME Console)
- [✓] Install AI-native terminals (WaveTerm)
- [✓] Install KDE terminals (Konsole, Yakuake)
- [✓] Install other terminals (Foot, XTerm, XFCE4 Terminal, Termius, COSMIC Term)
- [✓] Write system-level configs for all 15 terminals with Steelbore theme

### editors.nix

- [✓] Define `spacecraft.packages.editors` option
- [✓] Install linting (markdownlint-cli2)
- [✓] Install Rust TUI editors (Helix, Amp, msedit)
- [✓] Install standard TUI editors (Neovim, Vim, mg, mc)
- [✓] Install Rust GUI editors (zed-editor-fhs, Lapce, Neovide, cosmic-edit)
- [✓] Install standard GUI editors (Emacs-pgtk, VSCode-FHS, gedit)

### development.nix

- [✓] Define `spacecraft.packages.development` option
- [✓] Install Git and Rust VCS tools (gitui, delta, jujutsu)
- [✓] Install gh and github-desktop
- [✓] Install Forgejo stack (forgejo, forgejo-cli, forgejo-runner)
- [✓] Install Rust toolchain (rustup, cargo, cargo-update)
- [✓] Install build tools (just, sad, pueue, tokei)
- [✓] Install environment tools (lorri, dotter)
- [✓] Install Cloud CLIs (google-cloud-sdk, azure-cli, awscli)
- [✓] Install languages (JDK, PHP, Guile + guile-json)
- [✓] Install Ada toolchain (gnat16 — GNAT/GCC 16 Ada compiler)
- [✓] Install Nix ecosystem (nixfmt, cachix, nix, guix)
- [✓] Configure system Git defaults (`init.defaultBranch`, `core.editor`)

### security.nix

- [✓] Define `spacecraft.packages.security` option
- [✓] Install Rust encryption (age, rage)
- [✓] Install sops for secrets
- [✓] Install Sequoia PGP stack (sq, chameleon, wot, sqv, sqop)
- [✓] Install password managers (rbw, bitwarden-cli/desktop, authenticator)
- [✓] Install SSH tools (openssh_hpn — general-purpose fallback)
  - [✓] Add gitway as primary git-SSH stack (flake input — `gitway-agent` owns `$SSH_AUTH_SOCK`, `gitway-keygen` signs commits, `gitway-add` in shell init)
- [✓] Install pika-backup (Rust, Borg frontend)
- [✓] Install sydbox (process sandboxing)
- [✓] Install sbctl (Secure Boot)

### networking.nix

- [✓] Define `spacecraft.packages.networking` option
- [✓] Install network management (impala, iwd)
- [✓] Install HTTP clients (xh, monolith, curlFull, wget2)
- [✓] Install Rust diagnostics (gping, trippy, lychee, rustscan, sniffglue, bandwhich)
- [✓] Install GUI tools (sniffnet, mullvad-vpn, rqbit)
- [✓] Install download managers (aria2, uget)
- [✓] Install clipboard tools (wl-clipboard, wl-clipboard-rs)
- [✓] Install DNS & services (dnsmasq, atftp, adguardhome)

### multimedia.nix

- [✓] Define `spacecraft.packages.multimedia` option
- [✓] Install video players (mpv, vlc, cosmic-player)
- [✓] Install Rust audio (amberol, termusic, ncspot, psst, shortwave)
- [✓] Install Rust image viewers (loupe, viu, emulsion)
- [✓] Install mousai (audio recognition)
- [✓] Install audio mixers / output switchers (wiremix TUI, pavucontrol GUI) — PipeWire sink/stream routing for Niri
- [✓] Install processing tools (rav1e, gifski, oxipng, video-trimmer, ffmpeg)
- [✓] Install yt-dlp

### productivity.nix

- [✓] Define `spacecraft.packages.productivity` option
- [✓] Install Rust knowledge tools (AppFlowy, Affine)
- [✓] Install CLI note-taking (nb)
- [✓] Install office suites (LibreOffice, OnlyOffice)
- [✓] Install utilities (qalculate-gtk)
- [✓] Install communication (Fractal, NewsFlash, Tutanota, Onedriver)

### system.nix

- [✓] Define `spacecraft.packages.system` option
- [✓] Install modern Unix (fd, ripgrep, bat, eza, sd, zoxide, procs, dust, dua)
- [✓] Install uutils (coreutils, diffutils, findutils)
- [✓] Install file managers (yazi, broot, superfile, spacedrive, fclones, kondo, pipe-rename, ouch)
- [✓] Install disk tools (gptman, parted, tparted, gparted)
- [✓] Install monitoring (bottom, kmon, macchina, bandwhich, mission-center, htop, btop, gotop, fastfetch, i7z, hw-probe)
- [✓] Install text processing (jaq, teip, htmlq, skim, tealdeer, mdcat, difftastic, texinfo, pandoc, reuse, hunspell)
- [✓] Install Rust shells (nushell, brush, ion, starship, atuin, pipr, moor, powershell)
- [✓] Install multiplexers (zellij, screen)
- [✓] Install t-rec (terminal recorder)
- [✓] Install containers (steam-run, distrobox, boxbuddy, host-spawn, podman, runc, youki, oxker, qemu, flatpak, bubblewrap)
- [✓] Install system management (topgrade, paru, doas, os-prober, kbd, numlockx, xremap, input-leap)
- [✓] Install archiving (p7zip, zip, unzip)
- [✓] Install ZFS tools and antigravity-fhs
- [✓] Install benchmarking (phoronix-test-suite, perf)
- [✓] Enable Flatpak and AppImage (binfmt) services
- [✓] Enable Podman with `dockerCompat`, runc + youki runtimes

### ai.nix

- [✓] Define `spacecraft.packages.ai` option
- [✓] Install Rust AI tools (aichat, gemini-cli)
- [✓] Install opencode (Go)
- [✓] Install AI tools (codex, copilot-cli, gpt-cli, mcp-nixos)
- [✓] Install task-master (npx wrapper; nixpkgs `task-master-ai` unfixable — see CLAUDE.md note 3)
- [✓] Install claude-code from channel-appropriate `pkgs` (stable on stable, unstable on unstable)

### flatpak.nix

- [✓] Define `spacecraft.packages.flatpak` option
- [✓] Configure Flathub remote
- [✓] Declare Flatpak packages (44+ apps across browsers, communication, networking, security, development, gaming, retro, productivity, terminals, incl. de.haeckerfelix.Fragments torrent client and org.gnome.baobab disk usage analyzer)
- [✓] Add app.devsuite.Ptyxis flatpak (alongside nixpkgs host install; both themed via shared host dconf `org/gnome/Ptyxis/Profiles/steelbore` — flatpak app id differs but GSettings schema is org.gnome.Ptyxis)
- [✓] Fix VSCode flatpak launch — declarative user override (`xdg.dataFile`) prepends `/app/bin:/usr/bin` to PATH so the `code` entrypoint resolves (was `bwrap: execvp code: No such file or directory`)

### homebrew.nix

- [✓] Define `steelbore.packages.homebrew` option
- [✓] Run Homebrew inside a `brew` distrobox container (ubuntu-toolbox image) — full FHS, no sandbox sharp edges
- [✓] `brew-box-init` command: create container, apt-install brew Linux deps, run Homebrew installer (one-time)
- [✓] `brew` command: proxy `brew <args>` into the box, auto-source `brew shellenv`
- [✓] `brew-box` command: interactive shell inside the container
- [✓] Depends on rootless podman from the `system` bundle (documented in module + PRD §11.11)

---

## Phase 7: Hardware Modules (`modules/hardware/`)

- [✓] **`default.nix`**: Hardware module entry point (imports bluetooth, fingerprint, intel)
- [✓] **`bluetooth.nix`**: Define option, enable BlueZ (`hardware.bluetooth`, powerOnBoot, Experimental), install bluetui + overskride
- [✓] **`fingerprint.nix`**: Define option, enable fprintd
- [✓] **`intel.nix`**: Define option with `marchLevel` suboption (enum: v1/v2/v3/v4, default: v4)
- [✓] **`intel.nix`**: Enable `kvm-intel` module, Intel microcode updates
- [✓] **`intel.nix`**: Set per-level optimization flags (CFLAGS, CXXFLAGS, RUSTFLAGS, GOAMD64, LDFLAGS, LTOFLAGS)
- [✓] **`intel.nix`**: v1/v3/v4 CachyOS-sourced flags, v2 ALHP-sourced flags
- [✓] **Tier 2 (S8) split**: `marchLevel` + all compiler/linker flags moved to
  `modules/platform/x86-64.nix` under `steelbore.platform.x86_64`; `intel.nix` is now
  vendor-only (`kvm-intel`, microcode). New sibling modules `modules/services/` (podman,
  S13) and `modules/compat/` (appimage, S13); palette single-sourced in `lib/colors.nix`
  (S9); desktop guard assertions in `modules/desktops/assertions.nix` (S11).

---

## Phase 8: Host & User Configuration

### Host (`hosts/common.nix` + `hosts/thinkpad/`)

- [✓] **`thinkpad/default.nix`**: Set hostname to `bravais-thinkpad`; pin `steelbore.platform.x86_64.marchLevel = "v3"`; enable `hardware.bluetooth`
- [✓] **`default.nix`**: Enable NetworkManager
- [✓] **`default.nix`**: Configure X11 keyboard layout (`us,ara`, `grp:ctrl_space_toggle`)
- [✓] **`default.nix`**: Console keymap `us`
- [✓] **`default.nix`**: Enable printing
- [✓] **`default.nix`**: Create user `mj` with groups (networkmanager, wheel, input, video, audio)
- [✓] **`default.nix`**: Set user shell to Nushell (Rust), root shell to Brush (Rust)
- [✓] **`default.nix`**: Register Nushell, Brush, Ion as valid login shells; bash excluded from `environment.shells` (`programs.bash.enable` kept — NixOS PAM/activation scripts require it; overlay replacement impossible due to nixpkgs bootstrapping cycle)
- [✓] **`default.nix`**: Enable all spacecraft desktop modules (gnome, cosmic, plasma, niri, leftwm)
- [✓] **`default.nix`**: Enable all spacecraft hardware modules (bluetooth, fingerprint, intel)
- [✓] **`default.nix`**: Enable all spacecraft package modules (13 modules including flatpak, homebrew)
- [✓] **`default.nix`**: Set `stateVersion = "26.05"`
- [✓] **`hardware.nix`**: Import from `modulesPath`, configure root (ext4) and boot (vfat) filesystems

### User (`users/mj/`)

- [✓] **`default.nix`**: Define user account
- [✓] **`home.nix`**: Set username, home directory, stateVersion 26.05
- [✓] **`home.nix`**: Create `~/steelbore` symlink to `/spacecraft-software`
- [✓] **`home.nix`**: Configure keyboard layout (`us,ara`, `grp:ctrl_space_toggle`)
- [✓] **`home.nix`**: Set session variables (`EDITOR`, `VISUAL` to msedit, `SPACECRAFT_THEME`)
- [✓] **`home.nix`**: Configure Git with SSH signing (Sequoia), LFS enabled
- [✓] **`home.nix`**: Configure Starship prompt (Tokyo Night preset)
- [✓] **`home.nix`**: Configure Nushell with aliases (telemetry, steelbore banner)
- [✓] **`home.nix`**: Configure Ion shell init (`~/.config/ion/initrc`) with aliases
- [✓] **`home.nix`**: Configure Alacritty with Steelbore colors (via `programs.alacritty`)
- [✓] **`home.nix`**: Write user-level XDG configs (niri, ironbar, wezterm, rio, ghostty, foot, xfce4-terminal, konsole, yakuake, xresources)
- [✓] **`home.nix`**: Configure dconf settings (Ptyxis profile, GNOME Console)
- [✓] **`home.nix`**: Configure containers (`~/.config/containers/containers.conf`, runc default)

---

## Phase 9: Overlays (`overlays/default.nix`)

- [✓] **sequoia-wot**: Disable failing tests (`doCheck = false`)
- [✓] **claude-code**: Pinned to 2.1.113 via `overrideAttrs` overlay; `src` built with `runCommand` to bake `overlays/claude-code-package-lock.json` into the source tree; `npmDeps` explicitly overridden (workaround for `overrideAttrs` not propagating into internal `fetchNpmDeps`); `postInstall` copies native binary from `@anthropic-ai/claude-code-linux-x64` over the placeholder `bin/claude.exe`; `autoPatchelfHook` + `autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ]` for ELF patching on NixOS
- [✓] **overlay location**: Defined inline in `modules/core/nix.nix`; reference copy in `overlays/default.nix`
- [✓] **bash→brush overlay**: Investigated and found infeasible — nixpkgs bootstrapping cycle prevents overriding `pkgs.bash` via any overlay

---

## Phase 10: Testing & Verification

- [✓] Run `nix flake check` without errors
- [✓] Run `nix flake show` and verify per-machine configurations listed (`bravais-thinkpad`, `-unstable`, `bravais` alias)
- [✓] Run `nixos-rebuild dry-build --flake .#bravais-thinkpad` successfully
- [✓] Run `nixos-rebuild build --flake .#bravais-thinkpad` successfully
- [✓] Run `nixos-rebuild switch --flake .#bravais-thinkpad` successfully
- [✓] Verify unstable channel build (`nixos-rebuild build --flake .#bravais-thinkpad-unstable`)
- [~] Verify Niri session boots with Ironbar
- [✓] Verify COSMIC session boots with panel
- [✓] Verify GNOME session boots on Wayland
- [✓] Verify KDE Plasma 6 session boots on Wayland
- [ ] Verify LeftWM session boots with Polybar
- [✓] Verify greetd/tuigreet login with session selection
- [✓] Verify Steelbore palette on TTY
- [~] Verify Steelbore palette on all themed terminals (15)
- [ ] Verify Steelbore palette on Ironbar and Polybar
- [ ] Verify sudo-rs works for privilege escalation
- [✓] Verify fingerprint authentication (fprintd)
- [ ] Verify Podman with `docker` compat alias
- [✓] Verify Flatpak apps install from Flathub
- [ ] Verify AppImage binfmt execution

---

## Phase 11: Documentation

- [✓] **README.md**: Project overview and quick start
- [✓] **ARCHITECTURE.md**: System diagrams and data flow
- [✓] **TODO.md**: Implementation checklist (this file)
- [✓] **PRD.md**: Product requirements (v3.0)

---

## Known Issues & Notes

1. **COSMIC packages**: Uses native nixpkgs module (no third-party flake). `useFetchCargoVendor` deprecation warnings come from upstream nixpkgs packages — harmless.

2. **claude-code**: Pinned to 2.1.113 via `overrideAttrs` overlay in `modules/core/nix.nix`. Lock file stored at `overlays/claude-code-package-lock.json`. Native-binary architecture (since ~2.1.113) requires explicit `npmDeps` override, `postInstall` copy from `@anthropic-ai/claude-code-linux-x64`, and `autoPatchelfHook`. See `CLAUDE.md` constraint #4 for full gotchas and update procedure.

3. **XanMod kernel**: Sourced from unstable channel for latest version.

4. **sequoia-wot**: Tests disabled via overlay due to build failures.

5. **Console keymap**: Set to `us` only -- ckbcomp can't resolve multi-layout XKB configs (`us,ara`).

6. **Bash cannot be replaced via nixpkgs overlay**: Every nixpkgs derivation uses `final.bash` as its build shell via stdenv. Overriding `pkgs.bash` in an overlay creates an unavoidable bootstrapping cycle (`final.bash → prev.bash.stdenv.shell = "${final.bash}/bin/bash" → final.bash`). Bash is excluded from login shells but `programs.bash.enable` must remain `true` for NixOS PAM and activation script generation. Users get Nushell; root gets Brush.

7. **Overlays** are defined inline in `modules/core/nix.nix`. `overlays/default.nix` exists as a reference copy.

8. **task-master-ai**: nixpkgs build is unfixable via overlay — upstream's `package-lock.json` omits the platform-specific optionalDependencies of `@biomejs/biome` and `esbuild`, and `npm ci`'s lockfile validation runs before any `--omit=optional` or fetcher-v2 logic. `modules/packages/ai.nix` ships a `task-master` shell wrapper that runs `npx -y --package=task-master-ai task-master "$@"` against `pkgs.nodejs` instead. See `CLAUDE.md` constraint #3.

9. **xdg-desktop-portal routing under multi-DE**: With GNOME, COSMIC, Plasma all enabled, each DE's NixOS module registers its own portal backends via `xdg.portal.extraPortals` and `configPackages`. The active backend is selected per-session via `XDG_CURRENT_DESKTOP`. Bravais adds explicit `xdg.portal.config.<de>.default` routing in `modules/desktops/cosmic.nix` and `modules/desktops/gnome.nix` so Screenshot/ScreenCast/FileChooser interfaces resolve deterministically per session — without it, dbus startup popups and PrtSc "server crash" can occur in COSMIC.

10. **Unified `start-<de>` commands**: All desktops expose a `start-<de>` launcher (`start-cosmic`, `start-gnome`, `start-plasma`, `start-plasma-x11`, `start-niri`, `start-leftwm`). `start-cosmic` comes from upstream `pkgs.cosmic-session`; the rest are `writeShellScriptBin` wrappers in `modules/login/default.nix`. `start-leftwm` invokes `startx leftwm` for X11 from a TTY.

---

## Summary

| Phase | Status | Progress |
|-------|--------|----------|
| 1. Foundation | Complete | 12/12 |
| 2. Core Modules | Complete | 20/20 |
| 3. Theme Engine | Complete | 7/7 |
| 4. Login Management | Complete | 5/5 |
| 5. Desktop Environments | Complete | 33/33 |
| 6. Package Modules | Complete | 73/73 |
| 7. Hardware Modules | Complete | 7/7 |
| 8. Host & User Config | Complete | 26/26 |
| 9. Overlays | Complete | 2/2 |
| 10. Testing | In Progress | 2/21 |
| 11. Documentation | Complete | 4/4 |
| **Total** | **91%** | **189/208** |

---

*Last updated: 2026-04-20*
