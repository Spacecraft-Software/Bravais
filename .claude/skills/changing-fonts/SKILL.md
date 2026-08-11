---
name: changing-fonts
description: How to change the UI or terminal font in the Bravais NixOS config. Use when asked to change, swap, or verify a font family — covers finding the real fontconfig family name with fc-scan, the one-line terminal-font edit in lib/terminal-theme.nix, the non-generated spots that still need editing by hand (fonts.nix, eww/ironbar CSS, halloy/tiny, dconf keys, gtk.font, dunst), and the build-plus-fc-scan verification that a wrong family name would otherwise pass silently.
---


`fonts.nix` sets the fontconfig defaults. Since the Phase C terminal-theme
generator, **every terminal emulator config derives its font from
`theme.font` in `lib/terminal-theme.nix`** (foot, xterm, xfce, ghostty, warp,
konsole, wezterm, cosmic-term, waveterm, alacritty, rio — rio automatically
gets the `…Mono` variant, constraint #11). A terminal-font change is now a
ONE-LINE edit there. Family strings still appear by hand in the NON-generated
spots: `modules/theme/fonts.nix` (packages + fontconfig), the **eww** scss +
**ironbar** css (bar fonts), **halloy**/**tiny** configs, the **dconf**
`font-name`/`monospace-font-name` keys, `gtk.font`, Starship has none, and
`modules/desktops/shared.nix` (dunst) for the UI font (polybar was removed
in Phase E — eww is the bar on both WMs). Grep those when changing a family.

**Procedure (the way that actually works):**

1. **Get the exact family name — do not guess.** The fontconfig family is *not* the nixpkgs attr. Build the package and read it:
   ```sh
   p=$(nix build --no-link --print-out-paths nixpkgs#nerd-fonts.jetbrains-mono)
   fc-scan --format '%{family}\n' "$p" | tr ',' '\n' | sort -u | grep -i jetbrains
   # → "JetBrainsMono Nerd Font", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font Propo"
   ```
   Common gotcha: `nerd-fonts.jetbrains-mono` → family `JetBrainsMono Nerd Font` (no space), `nerd-fonts.hack` → `Hack Nerd Font`.

2. **Terminal font = one line.** Edit `theme.font` in `lib/terminal-theme.nix`
   — every generated terminal config (foot, xterm, xfce, ghostty, konsole,
   wezterm, waveterm, alacritty, rio, ptyxis palette consumers) follows
   automatically, and Rio keeps its `"${theme.font} Mono"` variant + the
   `Symbols Nerd Font Mono` extras by construction (constraint #11).
   Then stem-replace only the NON-generated spots (bars, IRC clients, dconf
   font-name keys, gtk font, dunst UI font):
   ```sh
   sd 'JetBrainsMono' 'NewFamily' users/mj/home.nix   # eww/ironbar/halloy/dconf hits only
   ```
   and edit the `nerd-fonts.*` attrs + `defaultFonts` in `fonts.nix` by hand.

3. **UI font** (`Hack Nerd Font`): edit `fonts.nix` defaults, the dconf
   `font-name`/`document-font-name` keys and `gtk.font` in `home.nix`, and the
   dunst (`modules/desktops/shared.nix`) font.

4. **Verify** before declaring done:
   ```sh
   git add -A
   nix build --no-link --print-out-paths '.#nixosConfigurations.bravais-thinkpad.config.system.build.toplevel'   # must evaluate+build
   nix-store -qR <result> | grep -i nerd-fonts                                                              # new fonts in, old fonts out
   ```
   The build does **not** catch a wrong family name (it's just a string) — only step 1's `fc-scan` does.

5. Update `PRD.md` §4.3 (Typography) and `TODO.md` `fonts.nix` checklist to the new families.

