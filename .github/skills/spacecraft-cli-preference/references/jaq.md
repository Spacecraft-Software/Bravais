# jaq

**Replaces:** `jq` | **Language:** 🦀 Rust | **Install:** via `spacecraft-missing-pkg` (upstream crate: `jaq`)

## Purpose
Faster, near drop-in `jq` clone. Compatible with most `jq` filters, written in safe Rust.

## Key flags
| Flag | Meaning |
|------|---------|
| `-r` / `--raw-output` | Strings without JSON quoting |
| `-R` / `--raw-input` | Input is raw strings, one per line |
| `-s` / `--slurp` | Read whole input as single array |
| `-c` / `--compact-output` | One JSON doc per line |
| `--tab` | Indent with tabs |
| `--indent N` | Indent with N spaces |
| `-e` / `--exit-status` | Exit non-zero on null/false |
| `--arg NAME VALUE` | Bind string variable |
| `--argjson NAME VALUE` | Bind JSON variable |

## Examples
1. Pretty-print: `curl -s api | jaq .`
2. Extract field: `jaq -r '.name' package.json`
3. Filter array: `jaq '.[] | select(.active)' users.json`
4. Group and count: `jaq 'group_by(.kind) | map({kind: .[0].kind, n: length})'`
5. Build object: `jaq -n --arg v 1.0 '{version: $v, generated: now}'`
6. Slurp one file: `jaq -s 'add' a.json`
   (`jaq -s … a.json b.json` slurps **per file** and runs the filter twice —
   see Gotchas.)

## Gotchas
**`jaq` is not a drop-in for `jq`, and `alias jq = jaq` will break scripts.**
Use **Pathfinder** (`https://Pathfinder.SpacecraftSoftware.org/`) when existing
jq scripts have to keep working; it translates the command line, supplies the
missing builtins, and reports what it cannot repair. Measured against jq 1.8.1:

- **No auto-vivification** — the one that actually bites. `jq` creates missing
  containers along an assignment path; `jaq` errors.
  `echo null | jaq '.a.b = 1'` → `cannot use null as iterable`, where `jq`
  gives `{"a":{"b":1}}`. Every "build the object as you go" idiom breaks,
  including `reduce … (null; .[$k] = …)`.
- **Several input files are not one stream.** `jq` concatenates them; `jaq`
  runs the whole filter once per file, so `jaq -s 'add' a.json b.json` prints
  two results rather than one. Affects `-s`, `input` and `inputs`.
- **Output-format flags are not last-wins.** `jq -c --tab` pretty-prints with
  tabs; `jaq -c --tab` is compact.
- **22 jq builtins are missing**, including `tostream`, `fromstream`, `IN`,
  `INDEX`, `JOIN`, `builtins`, `input_filename` and `$__loc__`.
- **9 jq flags are rejected** with `unknown flag`: `-a`, `--seq`, `--stream`,
  `--stream-errors`, `--jsonargs`, `--unbuffered`, `-b`, `--argfile`, and the
  attached `-Ldir` spelling.
- `"a" * 0` is `null` (jq: `""`); `1 / 0` is `Infinity`, which is invalid JSON
  on stdout (jq errors).
- Error messages differ from `jq`; adapt CI assertions accordingly. The exit
  **codes** do match jq in every case tested.

`jaq` has one flag `jq` lacks: **`-i`/`--in-place` rewrites the input file**.
Never pass an unrecognised flag through to it blindly.
