# Nushell Syntax Reference

Nushell is **not** POSIX-compatible. Don't try to port Bash — rewrite it. Structured data (tables, records, lists) flows between commands instead of bytestreams.

Docs: <https://www.nushell.sh/book/>

## Variables

```nu
let x = 42                 # immutable binding
mut y = 10                 # mutable binding (required for reassignment)
$y = $y + 1                # mutation

const PATH_SEP = "/"       # parse-time constant
```

- Spaces around `=` are **mandatory**.
- Sigil is always `$var`. No `${var}` form.
- Shadowing is allowed; retyping is allowed across shadows.

## Environment variables

```nu
$env.FOO = "bar"                                    # set
$env.PATH = ($env.PATH | prepend "~/.cargo/bin")    # extend PATH
print $env.HOME                                     # read
hide-env FOO                                        # unset
```

**`let-env` was removed in Nushell 0.92.** Use `$env.NAME = ...`.

To scope an env var to a single external command: `with-env { FOO: "bar" } { cmd }`.

## String interpolation

```nu
let name = "mohamed"
print $"hello ($name)"                 # double-quoted interpolation
print $'literal $no_interp ($name)'    # single-quoted interpolation (expressions only)
```

Parentheses — **not** `${...}` — delimit expressions inside interpolated strings.

## Pipelines and command substitution

Pipes pass **structured data**, not bytes. External commands emit strings; convert with `from json` / `from csv` / etc.

```nu
ls | where size > 1mb | sort-by modified -r | first 5
http get https://api.github.com/repos/UnbreakableMJ/Understand-Anything | get stargazers_count
cargo metadata --format-version=1 | from json | get packages | select name version
```

Command substitution = parentheses:

```nu
let branch = (git rev-parse --abbrev-ref HEAD | str trim)
```

`$(...)` is **not** Nushell syntax (it's POSIX). Use bare `(...)`.

## Conditionals

```nu
if $x > 0 { "positive" } else if $x == 0 { "zero" } else { "negative" }
```

- `if` is an **expression** — it returns a value.
- No `test` or `[ ]`; use native comparison operators.
- `and` / `or` / `not` for logic (also `&&` / `||` / `!` work).

## Pattern matching

```nu
match $foo {
    { name: "bar", count: $n } if $n < 5 => ($n + 3)
    { name: _, count: $n }               => ($n + 7)
    _                                    => 1
}
```

## Loops

```nu
for f in (ls | get name) { print $f }

mut i = 0
while $i < 10 { $i = $i + 1; print $i }

[1 2 3] | each { |x| $x * 2 }           # map
[1 2 3] | reduce --fold 0 { |it, acc| $acc + $it }    # fold
```

`for` uses a block and can mutate outer `mut` vars. `each` uses a closure and cannot.

## Functions (custom commands)

```nu
def greet [name: string, --loud] {
    if $loud { print $"HELLO ($name | str upcase)" } else { print $"hello ($name)" }
}

greet mohamed
greet mohamed --loud
```

Env-mutating functions need `def --env`:

```nu
def --env cd-up [] { cd .. }
```

## Redirection

```nu
cmd | save out.txt                  # stdout to file (overwrite)
cmd | save --append log.txt         # append
cmd out> out.txt                    # same, operator form
cmd err> err.txt                    # stderr to file
cmd out+err> combined.txt           # both streams
cmd e>| other-cmd                   # pipe stderr into next command
```

Numeric fd redirection (`2>&1`, `>&3`) does not exist. Use stream operators.

## Arrays, records, tables

```nu
let xs = [1 2 3]                            # list, no commas
let row = { name: "mo", role: "lead" }      # record
let tbl = [[a b]; [1 2] [3 4]]              # table literal

$xs.0              # index
$row.name          # field access
$tbl | get a       # column
```

## External commands

External commands always return text (bytestream). To parse:

```nu
curl -s https://api.github.com/users/UnbreakableMJ | from json | get public_repos
```

To force a command to be treated as external even if a built-in shadows it, prefix `^`:

```nu
^ls          # real /bin/ls, not Nushell's ls
```

## Gotchas

- No `&&` short-circuiting with external commands the way Bash does — Nushell short-circuits on pipeline exit status differently. Use `if` blocks for explicit control flow.
- Nushell scripts need `nu` installed — for cross-platform CI scripts, keep POSIX `.sh` for entrypoints and call `nu` explicitly for the Nushell-heavy bits.
- Config lives at `$nu.config-path` (typically `~/.config/nushell/config.nu`) and `$nu.env-path`.
- Glob patterns are first-class values; pass a bare `*.rs` where a glob is expected. To force string-not-glob, quote it.
- Comments use `#`, not `//`.

## Quick translation targets

| Bash | Nushell |
|------|---------|
| `foo=bar` | `let foo = "bar"` |
| `export FOO=bar` | `$env.FOO = "bar"` |
| `$(cmd)` | `(cmd)` |
| `cmd1 && cmd2` | `cmd1; cmd2` (or explicit `if`) |
| `cmd > out 2>&1` | `cmd out+err> out` |
| `for f in *.rs; do …; done` | `ls *.rs \| each { \|f\| … }` |
| `if [ -f x ]; then …; fi` | `if ("x" \| path exists) { … }` |
| `function foo { … }` | `def foo [] { … }` |
| `arr=(a b c); echo "${arr[0]}"` | `let arr = [a b c]; print $arr.0` |