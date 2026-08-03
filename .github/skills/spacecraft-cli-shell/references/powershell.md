# PowerShell Syntax Reference

PowerShell is **object-oriented**, not text-oriented: pipelines pass .NET
objects, not lines of text. It is not POSIX and does not accept Bash syntax.
Target it for `.ps1` / `.psm1` / `.psd1` files, Windows-first tooling, and
cross-platform automation where `pwsh` (PowerShell 7+) is the runtime. Prefer
`pwsh` (cross-platform, MIT-licensed) over Windows PowerShell 5.1 for anything
new.

Docs: <https://learn.microsoft.com/powershell/scripting/>

## Variables

```powershell
$name = "mohamed"               # spaces around = are fine and conventional
[int]$n = 42                    # typed
[string[]]$files = 'a.rs','b.rs'
$env:PATH = "$env:PATH:/extra"  # environment variables live under $env:
Remove-Variable name            # unset
```

- Sigil `$` is part of the name (`$name`), not just expansion — assignment uses
  it too: `$x = 1`, never `x=1`.
- **No word-splitting.** `$files` stays one array; `"$name"` stays one string.
  This is the biggest mental shift from POSIX — you almost never need defensive
  quoting against splitting.
- Environment variables are a drive: `$env:HOME`, `$env:USERPROFILE`.
- `$null`, `$true`, `$false` are the literals.

## Everything is an object

```powershell
Get-ChildItem *.rs | Where-Object Length -gt 1kb | Sort-Object Name
Get-Process | Select-Object Name, Id | Format-Table
```

- Cmdlets are `Verb-Noun` (`Get-ChildItem`, `Set-Content`, `Where-Object`).
- The pipeline carries objects; `$_` (or `$PSItem`) is the current object inside
  `ForEach-Object` / `Where-Object`.
- Reach for cmdlets over external binaries when a native one exists — you keep
  the objects instead of re-parsing text.

## Comparison operators (NOT `[[ ]]` / `-eq` is a word)

```powershell
if ($n -eq 5)        { }    # equal
if ($n -ne 5)        { }    # not equal
if ($n -lt 5)        { }    # less than  (-le -gt -ge similarly)
if ($s -like '*.rs') { }    # wildcard match
if ($s -match '\.rs$'){ }   # regex match, sets $matches
if ($arr -contains 1){ }    # membership
```

- **No `<`, `>`, `==` for comparison** — those are redirection/assignment-ish.
  Use the dashed word operators.
- Case-insensitive by default; prefix `c` for case-sensitive (`-ceq`, `-cmatch`)
  or `i` to force insensitive (`-ieq`).
- Against an array, comparison operators **filter**: `1,2,3 -gt 1` returns
  `2,3`, not a boolean. Wrap in `@(...)`/check `.Count` when you mean a test.

## Conditionals

```powershell
if ($x -gt 10) {
    "big"
} elseif ($x -eq 10) {
    "ten"
} else {
    "small"
}

switch ($name) {
    'a.rs'   { 'rust' }
    { $_ -like '*.toml' } { 'config' }
    default  { 'other' }
}
```

## Loops

```powershell
foreach ($f in $files)      { $f }
for ($i = 0; $i -lt 10; $i++) { $i }
while ($x -lt 100)          { $x++ }
do { $x++ } while ($x -lt 100)

Get-ChildItem *.rs | ForEach-Object { $_.Name }   # pipeline form
1..10 | ForEach-Object { $_ }                      # range operator
```

- `1..10` is an inclusive range.
- `foreach` (statement) and `ForEach-Object` (pipeline cmdlet) are different —
  the statement is faster for in-memory collections; the cmdlet streams.

## Functions

```powershell
function Get-Greeting {
    param(
        [Parameter(Mandatory)][string]$Name,
        [int]$Times = 1
    )
    1..$Times | ForEach-Object { "hello $Name" }
}

Get-Greeting -Name mohamed -Times 2
```

- Name functions `Verb-Noun` with an approved verb (`Get`, `Set`, `New`,
  `Remove`, …; see `Get-Verb`).
- Parameters go in a `param( )` block, typed and attributed. Add
  `[CmdletBinding()]` above `param` for an advanced function (gets `-Verbose`,
  `-ErrorAction`, etc. for free).
- Output is whatever expression values fall out — no `return` needed (and
  `return $x` just emits `$x` then exits).

## Arrays, hashtables, splatting

```powershell
$arr = 1, 2, 3                 # or @(1,2,3)
$arr += 4                      # arrays are immutable; this rebuilds
$arr.Count
$map = @{ name = 'mj'; n = 42 }
$map['name']; $map.name

$params = @{ Path = 'x.txt'; Encoding = 'utf8' }
Set-Content @params            # splatting: @params, not $params
```

## Strings

```powershell
"interpolated $name and $($n + 1)"   # double quotes expand; $() for expressions
'literal $name'                       # single quotes do NOT expand
@"
multi-line $name
"@                                    # expanding here-string
@'
multi-line literal $name
'@                                    # literal here-string
```

- Sub-expression `$( … )` is required to interpolate anything beyond a bare
  variable (property access, arithmetic, method calls).

## Command substitution / external commands

```powershell
$branch = (git rev-parse --abbrev-ref HEAD)   # capture stdout as string(s)
$count  = (Get-Content notes.txt | Measure-Object -Line).Lines
& $exe --flag                                  # call operator for a path/var
git status; $LASTEXITCODE                       # exit code of last native exe
$?                                              # success of last operation (bool)
```

- `$(...)` is a sub-expression; `( )` captures pipeline output. Native command
  stdout comes back as an array of strings (split on newlines).
- Use `&` (call operator) to run a command whose name is in a variable or has a
  space in its path.
- Native-exe success is `$LASTEXITCODE`; cmdlet success is `$?`. They are not
  the same thing.

## Redirection

```powershell
cmd > out.txt          # success stream (1) to file
cmd >> out.txt         # append
cmd 2> err.txt         # error stream
cmd *> all.txt         # all streams
cmd 2>&1               # merge error into success
cmd | Out-File -Encoding utf8 out.txt
$null = cmd            # discard output (faster than | Out-Null)
```

PowerShell has numbered streams beyond 1/2: `3` warning, `4` verbose, `5` debug,
`6` information. `*>` captures them all.

## Error handling

```powershell
$ErrorActionPreference = 'Stop'        # make errors terminating (script-wide)

try {
    Get-Content missing.txt -ErrorAction Stop
} catch {
    Write-Error "failed: $($_.Exception.Message)"
} finally {
    # cleanup
}

throw "fatal"
```

- Many cmdlet errors are **non-terminating** by default and won't trigger
  `catch` unless you set `-ErrorAction Stop` (or `$ErrorActionPreference`).
- The current error in `catch` is `$_`; the error collection is `$Error`.

## Gotchas

- **Not Bash.** `[[ ]]`, `$(( ))`, `${var^^}`, `for ((;;))`, `arr=(...)`, `&&`
  in older Windows PowerShell — none are PowerShell. (`&&`/`||` *do* work in
  pwsh 7+ as pipeline-chain operators, but not in 5.1.)
- **Output is objects.** Piping to a text tool (`findstr`, `grep`) forces a
  string conversion and loses structure — prefer `Where-Object`/`Select-Object`.
- **Execution policy** (Windows): scripts may be blocked. `pwsh -File x.ps1` or
  `Set-ExecutionPolicy -Scope Process RemoteSigned` for a one-off.
- **Paths:** use `/` for cross-platform; `\` is Windows-only and is also the
  escape-ish char in some contexts. Prefer `Join-Path`.
- **Case-insensitive** by default for comparisons, variable names, and cmdlet
  names — do not rely on case to disambiguate.
- Pin the runtime: target `pwsh` 7+ for cross-platform scripts; note when a
  script requires Windows PowerShell 5.1 (e.g. uses a Windows-only module).

## Quick translation targets

| Bash / POSIX | PowerShell |
|--------------|------------|
| `foo=bar` | `$foo = 'bar'` |
| `export FOO=bar` | `$env:FOO = 'bar'` |
| `$(cmd)` | `(cmd)` or `$(cmd)` |
| `if [ "$a" = "$b" ]` | `if ($a -eq $b)` |
| `if [ -f x ]` | `if (Test-Path x)` |
| `for f in *.rs; do …; done` | `foreach ($f in Get-ChildItem *.rs) { … }` |
| `cmd > out 2>&1` | `cmd *> out` |
| `grep pat file` | `Select-String pat file` |
| `cat file` | `Get-Content file` |
| `arr=(a b c); "${arr[0]}"` | `$arr = 'a','b','c'; $arr[0]` |
| `${#arr[@]}` | `$arr.Count` |
| `function foo { … }` | `function Foo { … }` |
| `set -e` | `$ErrorActionPreference = 'Stop'` |
