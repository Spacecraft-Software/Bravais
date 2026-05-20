# ion

**Replaces:** `bash` (system shell) | **Language:** 🦀 Rust | **Install:** `cargo install ion-shell` (or Redox repos)

## Purpose
Default shell of Redox OS. Faster than Bash, simpler than Nushell, with typed variables and first-class arrays/maps. **One of Mohamed's primary shells.**

## Syntax highlights
```ion
# Strings, arrays, maps
let name = "mohamed"
let files:[str] = [ "a.rs" "b.rs" "c.rs" ]
let config:hmap[str] = hmap[str]::new()

# For loop with array
for f in @files
    echo $f
end

# Conditionals
if test -f Cargo.toml
    cargo build
else
    echo "not a rust project"
end

# Functions
fn greet name:str
    echo "hello $name"
end
greet mohamed
```

## Key commands
| Command | Meaning |
|---------|---------|
| `let VAR = VALUE` | Assign |
| `export VAR = VALUE` | Export to env |
| `fn NAME ARGS; …; end` | Define function |
| `read VAR` | Read from stdin |
| `source FILE` | Source script |
| `alias NAME = CMD` | Alias |

## Examples
1. One-liner: `ion -c "let xs = [1 2 3]; for x in @xs; echo $x; end"`
2. Run a script: `ion ./build.ion`
3. Config: `~/.config/ion/initrc`

## Gotchas
- Syntax is NOT Bash-compatible — rewrite scripts, don't drop Bash ones into Ion directly.
- Arrays expand with `@name`, strings with `$name` — mixing them is a common error.
- Community is smaller than Nushell's; stabilisation work is ongoing.
