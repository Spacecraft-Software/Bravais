# POSIX-Safe Shell Syntax

The portable subset that runs in `sh`, `dash`, `bash`, `zsh` (POSIX mode), `ksh`, and — with overlap — Ion. **Not** Nushell. Write this when you want the script to work anywhere `/bin/sh` exists.

Spec reference: POSIX.1-2017 Shell Command Language (<https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html>).

## Shebang

```sh
#!/bin/sh
set -eu
```

- `/bin/sh` is the POSIX shell (on Linux usually `dash`, on macOS usually `bash --posix`, on BSDs usually `ash` or similar).
- `set -e` exits on error; `set -u` errors on unset variables. Both are POSIX.
- `set -o pipefail` is **not POSIX** (ksh/bash extension); omit for strict portability or document the dependency.

## Variables

```sh
foo=bar                    # no spaces around =
export FOO=bar             # export to environment
readonly VERSION=1.0.0     # immutable
unset FOO
```

- **No spaces around `=`** — opposite of Ion and Nushell.
- Always quote expansions: `"$foo"` — unquoted `$foo` word-splits and globs.
- Use `${foo}` braces when gluing to adjacent text: `"${foo}bar"`.
- Parameter expansion POSIX subset: `${var:-default}`, `${var:=default}`, `${var:+alt}`, `${var:?error}`, `${var#prefix}`, `${var##prefix}`, `${var%suffix}`, `${var%%suffix}`. Case conversion (`^^`, `,,`) and pattern-replace (`//`, `/`) are **not** POSIX.

## Test and conditionals

```sh
if [ -f "$file" ]; then
    echo "exists"
elif [ -z "$s" ]; then
    echo "empty"
else
    echo "other"
fi
```

- Use `[ ]` (single bracket) or `test` — not `[[ ]]`.
- Always quote operands: `[ -z "$s" ]`, not `[ -z $s ]`.
- Logical combination: `[ -f a ] && [ -f b ]`, not `[ -f a -a -f b ]` (the `-a`/`-o` forms are deprecated).
- No `=~` regex operator — pipe to `grep -Eq` instead.
- Pattern matching via `case`:

```sh
case "$name" in
    *.rs)  echo "rust" ;;
    *.toml) echo "config" ;;
    *)     echo "other" ;;
esac
```

## Arithmetic

```sh
x=$(( a + b ))
i=0
while [ "$i" -lt 10 ]; do
    i=$(( i + 1 ))
    echo "$i"
done
```

- `$(( ... ))` is POSIX; `(( ... ))` as a standalone statement is Bash-only.
- Integer arithmetic only. For floats, use `awk` or `bc`.

## Loops

```sh
for f in *.rs; do
    echo "$f"
done

while read -r line; do
    printf '%s\n' "$line"
done < input.txt

until [ -f /tmp/ready ]; do
    sleep 1
done
```

- `for f in "$@"` iterates positional parameters.
- `read -r` prevents backslash interpretation — almost always what you want.
- **No `for ((i=0; i<10; i++))`** — Bash-only. Use `while` with a counter.

## Functions

```sh
greet() {
    printf 'hello %s\n' "$1"
}

greet "mohamed"
```

- No `function` keyword — `name() { ... }` only.
- No typed args. Access via `$1`, `$2`, …, `$#`, `$@`.
- No `local` keyword in strict POSIX (Bash/dash both support it as an extension; rely on it if your targets include dash, since dash does have `local`).
- `return N` sets exit status.

## Command substitution

```sh
branch=$(git rev-parse --abbrev-ref HEAD)
count=$(grep -c '^TODO' notes.txt)
```

- Use `$( ... )` — nestable, readable.
- Avoid backticks `` `cmd` ``: legal POSIX but awkward to nest and quote.

## Redirection and pipes

```sh
cmd > out.txt              # stdout
cmd 2> err.txt             # stderr
cmd > out.txt 2>&1         # both to same file (correct order — redirect stdout first)
cmd >> log.txt             # append
cmd < input.txt            # stdin
cmd1 | cmd2                # pipe
: > file.txt               # truncate
```

- `2>&1` must come **after** `> file` to merge streams into that file.
- `&>` is Bash, not POSIX.
- `<(...)` process substitution is Bash/zsh, not POSIX.

## Heredocs

```sh
cat <<EOF
hello $name
$(date)
EOF

cat <<'EOF'           # single-quoted EOF = no expansion
raw $text
EOF

cat <<-EOF            # leading-tab stripping (indented heredoc)
	still works
EOF
```

Heredocs are POSIX and portable — use them freely.

## Globbing

```sh
for f in *.rs; do …; done        # POSIX glob
for f in .*; do …; done          # includes . and ..; guard against it
```

- POSIX globs: `*`, `?`, `[abc]`, `[!abc]`.
- **No globstar** (`**`) in POSIX. If you need recursive traversal: `find . -name '*.rs'`.
- Brace expansion `{a,b,c}` and `{1..10}` is Bash, not POSIX. Use `seq 1 10` or enumerate.

## Error handling

```sh
set -eu

cleanup() {
    rm -f "$tmpfile"
}
trap cleanup EXIT

tmpfile=$(mktemp)
# ... work with $tmpfile ...
```

- `trap` with signal names (`EXIT`, `INT`, `TERM`, `HUP`) is POSIX.
- Command must return explicit exit code — `set -e` won't catch failures in tests, loops' conditions, or `\|\|` chains.
- Check `$?` explicitly when `set -e` is disabled or when you need the value.

## Signals and background jobs

```sh
long-task &
pid=$!
wait "$pid"
```

- `$!` is the PID of the most recent background job.
- `wait` blocks until the PID exits.
- `jobs`, `fg`, `bg` are POSIX but rarely used in scripts.

## What POSIX does NOT have

Flag these as non-portable and choose an explicit target:

- `[[ ]]` — Bash/ksh/zsh extension.
- `(( ))` as a statement — Bash/ksh extension.
- Arrays — Bash/ksh/zsh only.
- `function` keyword — Bash/ksh only.
- `<(...)`, `>(...)` process substitution — Bash/zsh.
- `<<<` here-string — Bash/zsh.
- `&>`, `|&` — Bash.
- `**` globstar — Bash with `shopt`.
- `{a,b}` and `{1..10}` brace expansion — Bash.
- `${var^^}`, `${var,,}`, `${var//a/b}` — Bash.
- `$RANDOM`, `$SECONDS`, `$LINENO`, `$BASH_SOURCE`, `$PIPESTATUS` — Bash.
- `local` — widely supported but not strictly POSIX (dash has it; true POSIX `sh` may not).
- `echo -e`, `echo -n` — not portable. Use `printf '%s\n' "$x"` instead.

## `echo` vs `printf`

```sh
# Don't:
echo -e "foo\tbar"        # -e is not POSIX; behavior varies
echo -n "no newline"      # -n is not POSIX

# Do:
printf '%s\t%s\n' foo bar
printf '%s' "no newline"
```

`printf` is POSIX and consistent. Reach for it whenever the output matters.

## Shellcheck

Run `shellcheck` over any POSIX script (`shellcheck -s sh script.sh`). It catches most bashisms automatically and is the fastest feedback loop for portability.

## Minimal portability checklist

Before marking a script as POSIX:

1. Shebang is `#!/bin/sh` (or `#!/usr/bin/env sh`).
2. No `[[`, `((`, `<(`, `&>`, `<<<`, or Bash-only parameter expansions.
3. No arrays.
4. No `function` keyword.
5. All expansions are quoted.
6. `shellcheck -s sh` passes.
7. Optionally test under `dash` — it catches bashisms that `bash` silently accepts.