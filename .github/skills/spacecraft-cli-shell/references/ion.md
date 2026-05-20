# Ion Shell Syntax Reference

Ion is POSIX-*inspired* but not POSIX-compatible. Most pipes, redirects, and external commands work like sh, but variable binding, arrays, functions, and control flow all diverge. Default shell of Redox OS.

Docs: <https://doc.redox-os.org/ion-manual/>

## Variables

```ion
let name = "mohamed"                       # string
let n:int = 42                             # typed
let flag:bool = true
let xs:[str] = [ "a.rs" "b.rs" "c.rs" ]    # typed array
let m:hmap[str] = hmap[str]::new()         # typed hashmap
```

- **Spaces around `=` are mandatory.** `let a=1` fails.
- `let` is always required — no bare `a = 1`.
- Arrays use `[ ... ]` with whitespace-separated items (no commas).
- String sigil is `$name`; array sigil is `@name`. Mixing them is a top error source.
- Braced form `${name}` works when you need to glue a variable to adjacent text: `echo ${a}s`.

`drop VAR` removes a variable (pass the bare name, not `$VAR`).

## Environment variables

```ion
export FOO = "bar"              # create/assign env var
export PATH = "$PATH:/extra"    # extend (string concat via interpolation)
echo $FOO
```

`export` mirrors `let` but sets a global env var visible to child processes. Arithmetic compound-assign (`+=`, `-=`, `*=`, `/=`) works on both `let` and `export`.

## String interpolation and methods

```ion
let a = one
let b = two
echo $a:$b                      # direct
echo ${a}s and ${b}s            # braced, for gluing
echo $join(xs ", ")             # method call on variable `xs`
echo $upper(name)
echo $replace(name "o" "0")
echo $len(name)
```

String methods are invoked as `$method(var arg1 arg2)` — **parentheses, no dollar on inner args**. Array methods use `@method(...)`.

## Command substitution

```ion
let branch = $(git rev-parse --abbrev-ref HEAD)        # captures as single string
let files = [ @(find . -name '*.rs') ]                 # captures as whitespace-split array
```

- `$(...)` → single string.
- `@(...)` → whitespace-split array.

Same syntax as POSIX for `$(...)` — one of the rare direct overlaps.

## Conditionals

```ion
if test $a -lt 5
    echo "a < 5"
else if test $a -eq 5
    echo "a == 5"
else
    echo "a > 5"
end
```

- Use `test` or the `exists` builtin — **not** `[[ ]]`.
- `[ ... ]` (single bracket) also works as an alias for `test`.
- Block terminator is `end`, not `fi`.

`exists` is Ion-specific and more ergonomic than `test`:

```ion
exists -f Cargo.toml && echo "rust project"
exists -b ripgrep    && echo "rg installed"
exists -s NAME       && echo "NAME is set and non-empty"
```

## Loops

```ion
# Exclusive range
for i in 1..10
    echo $i
end

# Inclusive range
for i in 1...10
    echo $i
end

# Iterate array
for f in @files
    echo $f
end

# Brace expansion
for a in {1..10}
    echo $a
end

# Ignore loop variable
for _ in 1..5
    echo tick
end

while test $a -lt 100
    echo $a
    let a += 1
end
```

**Quoting rule is reversed inside `for`**: unquoted values are literal; quote to enable expansion.

## Functions

```ion
fn greet name:str
    echo "hello $name"
end

fn fib n:int
    if test $n -le 1
        echo $n
    else
        let output = 1
        let previous = 1
        for _ in 2..$n
            let temp = $output
            let output += $previous
            let previous = $temp
        end
        echo $output
    end
end

greet mohamed
fib 10
```

- `fn NAME args; body; end` — no parentheses around args.
- Args can be typed: `name:str`, `n:int`, `xs:[str]`.
- Ion checks argument count at call time.

## Redirection

POSIX-like with extensions:

```ion
cmd > out.txt          # stdout to file
cmd 2> err.txt         # stderr to file
cmd &> both.txt        # stdout and stderr to file (like Bash)
cmd ^> /dev/null       # error-only redirect shorthand
cmd1 | cmd2            # pipe stdout
cmd1 ^| cmd2           # pipe stderr
cmd1 &| cmd2           # pipe both
cmd <<< "heredoc-string"
```

`^>` and `^|` (stderr-only variants) are Ion extensions. `&>` and `&|` (both-streams) are also supported.

## String slicing

Strings slice like arrays using grapheme indices:

```ion
let s = "one two three"
echo $s[0]       # o
echo $s[..3]     # one
echo $s[4..7]    # two
echo $s[8..]     # three
```

`++=` concatenates in place:

```ion
let s = world
let s ++= !
echo $s          # world!
```

## Aliases

```ion
alias ll = 'eza -la'
alias ..  = 'cd ..'
```

## Gotchas

- **Ion is not Bash.** Don't drop `.sh` files into Ion expecting them to run.
- **`@` vs `$`** — arrays expand with `@name`, strings with `$name`. Using `$arr` coerces to a single string (space-joined); that's occasionally useful but usually a bug.
- `source FILE` works (same as POSIX `.`).
- Config: `~/.config/ion/initrc`.
- No `set -e`, `set -u`, `set -o pipefail` equivalents. Check exit statuses explicitly with `&&`/`||` or `if`.
- Community is smaller than Nushell's; feature stabilisation is ongoing — pin versions in CI.
- Shebang: `#!/usr/bin/env ion` for scripts.

## Quick translation targets

| Bash | Ion |
|------|-----|
| `foo=bar` | `let foo = bar` (spaces around `=`) |
| `export FOO=bar` | `export FOO = bar` |
| `$(cmd)` | `$(cmd)` (same) |
| `cmd1 && cmd2` | `cmd1 && cmd2` (same) |
| `cmd > out 2>&1` | `cmd &> out` |
| `for f in *.rs; do …; done` | `for f in *.rs; …; end` |
| `if [ -f x ]; then …; fi` | `if exists -f x; …; end` |
| `function foo { … }` | `fn foo; …; end` |
| `arr=(a b c); echo "${arr[0]}"` | `let arr = [a b c]; echo $arr[0]` |
| `${arr[@]}` | `@arr` |
| `${#arr[@]}` | `$len(@arr)` |