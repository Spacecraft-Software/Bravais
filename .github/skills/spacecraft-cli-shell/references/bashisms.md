# Bashisms → POSIX / Ion / Nushell

Reference when converting an existing Bash snippet or catching a Bash-only construct before it lands in a non-Bash target. Each entry shows the Bash original and the idiomatic replacement for each target.

## Tests and conditionals

| Bash | POSIX | Ion | Nushell |
|------|-------|-----|---------|
| `[[ -f foo ]]` | `[ -f foo ]` or `test -f foo` | `exists -f foo` | `"foo" \| path exists` |
| `[[ -z $s ]]` | `[ -z "$s" ]` | `test -z $s` or `not exists -s s` | `$s \| is-empty` |
| `[[ $a == *.rs ]]` | `case "$a" in *.rs) … ;; esac` | `if echo $a \| grep -q '\.rs$'` | `$a \| str ends-with ".rs"` |
| `[[ $a =~ ^[0-9]+$ ]]` | `echo "$a" \| grep -Eq '^[0-9]+$'` | `if echo $a \| grep -Eq '^[0-9]+$'` | `$a =~ '^[0-9]+$'` |
| `[[ $a && $b ]]` | `[ -n "$a" ] && [ -n "$b" ]` | `and exists -s a exists -s b` | `($a \| is-not-empty) and ($b \| is-not-empty)` |

`[[ ]]` is **always** a bashism. The POSIX `[ ]` does slightly less (no `=~`, no pattern matching on the right side of `==`, no `&&`/`\|\|` inside) but works everywhere.

## Arithmetic

| Bash | POSIX | Ion | Nushell |
|------|-------|-----|---------|
| `(( x = a + b ))` | `x=$(( a + b ))` | `let x = a + b` (via `let` arithmetic) | `let x = $a + $b` |
| `(( x++ ))` | `x=$(( x + 1 ))` | `let x += 1` | `$x = $x + 1` (needs `mut x`) |
| `(( a > b ))` | `[ "$a" -gt "$b" ]` | `test $a -gt $b` | `$a > $b` |

## String manipulation

| Bash | POSIX | Ion | Nushell |
|------|-------|-----|---------|
| `${var^^}` (upper) | `echo "$var" \| tr '[:lower:]' '[:upper:]'` | `$upper(var)` | `$var \| str upcase` |
| `${var,,}` (lower) | `echo "$var" \| tr '[:upper:]' '[:lower:]'` | `$lower(var)` | `$var \| str downcase` |
| `${var//a/b}` (replace-all) | `echo "$var" \| sed 's/a/b/g'` | `$replace(var "a" "b")` | `$var \| str replace --all "a" "b"` |
| `${var/a/b}` (replace-first) | `echo "$var" \| sed 's/a/b/'` | `$replacen(var "a" "b" 1)` | `$var \| str replace "a" "b"` |
| `${#var}` (length) | `printf %s "$var" \| wc -c` | `$len(var)` | `$var \| str length` |
| `${var:2:5}` (substring) | `echo "$var" \| cut -c3-7` | `$var[2..7]` | `$var \| str substring 2..7` |
| `${var#prefix}` | `echo "$var" \| sed 's/^prefix//'` | no direct; use `$replace` | `$var \| str replace -r '^prefix' ''` |

## Arrays

| Bash | POSIX | Ion | Nushell |
|------|-------|-----|---------|
| `arr=(a b c)` | (no arrays; use positional `$@` or newline-delim strings) | `let arr = [a b c]` | `let arr = [a b c]` |
| `"${arr[@]}"` | N/A | `@arr` | `$arr` |
| `"${arr[0]}"` | N/A | `$arr[0]` | `$arr.0` |
| `"${#arr[@]}"` | N/A | `$len(@arr)` | `$arr \| length` |
| `arr+=(x)` | N/A | `let arr ++= [x]` | `$arr \| append x` (rebind with `mut`) |
| `for x in "${arr[@]}"; do …; done` | loop over `$@` or parse a string | `for x in @arr; …; end` | `for x in $arr { … }` |

POSIX has **no array type**. Workarounds: positional params (`set -- a b c` then `$@`), or newline-separated strings processed with `while read`.

## Functions

| Bash | POSIX | Ion | Nushell |
|------|-------|-----|---------|
| `function foo { … }` | `foo() { … }` | `fn foo; …; end` | `def foo [] { … }` |
| `function foo { local x=1; }` | `foo() { x=1; }` (no locals) | `fn foo; let x = 1; end` | `def foo [] { let x = 1 }` |
| `return 1` | `return 1` | `return 1` | `error make { msg: "…" }` or just use the return value |

## Redirection

| Bash | POSIX | Ion | Nushell |
|------|-------|-----|---------|
| `cmd &> file` | `cmd > file 2>&1` | `cmd &> file` | `cmd out+err> file` |
| `cmd 2>&1 \| other` | `cmd 2>&1 \| other` | `cmd &\| other` | `cmd e>\| other` (stderr only) or combine first |
| `cmd < <(other)` (process sub) | pipe or tempfile | pipe or tempfile | pipe |
| `cmd <<< "string"` | `echo "string" \| cmd` | `cmd <<< "string"` (supported) | `"string" \| cmd` |
| `exec 3< file` (custom fd) | same | not supported | not supported |

**Process substitution `<(…)` and `>(…)` are Bash/zsh only.** The usual fix is a pipeline or a tempfile.

## Control flow and error handling

| Bash | POSIX | Ion | Nushell |
|------|-------|-----|---------|
| `set -e` | `set -e` | (none; check exit codes explicitly) | (pipelines fail on error by default) |
| `set -u` | `set -u` | (none) | (undefined variables are errors) |
| `set -o pipefail` | `set -o pipefail` (bash/ksh; **not POSIX**) | (none) | (pipeline failures propagate) |
| `trap handler EXIT` | same (POSIX) | (limited signal support) | `def --env cleanup [] { … }` manually |

`set -o pipefail` is itself not strictly POSIX — `dash` lacks it. For pure POSIX, check each stage explicitly or accept that only the last command's exit status matters.

## Special variables

| Bash | POSIX | Ion | Nushell |
|------|-------|-----|---------|
| `$RANDOM` | `shuf -i 0-32767 -n 1` or `od -An -N2 -i /dev/urandom` | `$(shuf -i 0-32767 -n 1)` | `random int 0..32767` |
| `$SECONDS` | track manually with `date +%s` | same | `date now` deltas |
| `$LINENO` | Bash-specific debugging aid; no portable equivalent | same | same |
| `$BASH_SOURCE` | `$0` (approximate) | `$0` | `$nu.current-file` |
| `$PIPESTATUS` | Bash extension; no POSIX form | check each stage | inspect pipeline result |

## Globbing and brace expansion

| Bash | POSIX | Ion | Nushell |
|------|-------|-----|---------|
| `*.rs` | `*.rs` (POSIX glob) | `*.rs` | `*.rs` or `glob *.rs` |
| `**/*.rs` (globstar) | requires `shopt -s globstar`; **not POSIX** | `**/*.rs` | `**/*.rs` |
| `{1..10}` | bash-only; use `seq 1 10` | `{1..10}` supported | `1..10` range |
| `{a,b,c}.txt` | bash-only; enumerate | `{a,b,c}.txt` supported | list literal `[a.txt b.txt c.txt]` |

## Sourcing

| Bash | POSIX | Ion | Nushell |
|------|-------|-----|---------|
| `source file` | `. file` | `source file` | `source file.nu` |
| `. file` | `. file` | `source file` | `source file.nu` |

`source` as a keyword is a bashism; POSIX uses `.`. Ion and Nushell both accept `source`.

## Heredocs

```bash
cat <<EOF          # bash / POSIX — same
hello $name
EOF

cat <<'EOF'        # no interpolation
raw $text
EOF
```

POSIX and Bash share heredoc syntax. **Ion supports heredoc-string `<<<` but not the multi-line `<<EOF`**. **Nushell has no heredoc** — use multi-line strings (`"..."` spanning lines) or `$""` interpolation.

## Quick sanity rules

1. If you see `[[`, `((`, `<(`, `${...^^}`, `${...//}`, `${arr[@]}`, `function name`, `&>`, `<<<`, or `$RANDOM` — it's Bash. Check the target.
2. If the target isn't Bash, translate to the column above.
3. If the translation loses fidelity (e.g., no arrays in POSIX), flag it for the user rather than silently downgrading.