# Homebrew (`brew install`)

Permanent install to a user-owned prefix (`/opt/homebrew` on macOS,
`/home/linuxbrew/.linuxbrew` on Linux). No sudo required after initial
Homebrew bootstrap. Large formula index (~7,000 CLI formulae plus macOS
casks).

## Syntax

```bash
# Install
brew install <formula>

# Then run the binary
<binary> <args>
```

### Key notes

- No ephemeral-run equivalent. Every `brew install` persists until
  explicitly uninstalled.
- Binary name usually matches the formula name.
- On macOS, `brew` is the dominant non-Apple package manager; on Linux
  it works but is a lower-priority choice than Guix/Nix.
- Casks (`brew install --cask <cask>`) are macOS-only GUI apps and
  should generally be avoided by this skill — prefer CLI formulae.

## Examples

```bash
# Search a codebase with ripgrep
brew install ripgrep && rg 'TODO' src/

# Benchmark two commands
brew install hyperfine && hyperfine 'cmd_a' 'cmd_b'

# Static analysis of a shell script
brew install shellcheck && shellcheck script.sh

# Quick QEMU VM
brew install qemu && qemu-system-x86_64 -nographic -m 512 disk.img

# Specific Python version
brew install python@3.12 && python3.12 script.py
```

## Extras

### Search

```bash
brew search <regex>
brew info <formula>
```

### Pin a formula against upgrades

```bash
brew pin <formula>
brew unpin <formula>
```

### Third-party taps

```bash
brew tap <owner>/<n>
brew install <owner>/<n>/<formula>
```

### Upgrade an installed formula

```bash
brew upgrade <formula>
brew upgrade          # upgrade everything
```

### Cleanup downloaded artifacts (keep formulae installed)

```bash
brew cleanup
```

## Lookup

- Online: <https://formulae.brew.sh/>
  - Casks (macOS GUI, usually skip): <https://formulae.brew.sh/cask/>
- CLI: `brew search <regex>`
- See [lookup.md](lookup.md) for details.

## Cleanup

```bash
brew uninstall <formula>
```

Tell the user what was installed and how to remove it — Homebrew is a
permanent manager (tier 4 in the priority chain).
