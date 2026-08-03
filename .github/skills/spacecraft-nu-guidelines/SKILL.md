---
name: spacecraft-nu-guidelines
description: Expert guidelines for writing high-performance, clean, and type-safe Nushell (Nu) script code. Triggers on any request involving Nushell scripts, command definitions, custom pipelines, closures, modules, environment variables, or config.nu configurations. By Spacecraft Software.
---

# Spacecraft Nushell Guidelines

**You are an expert Nushell (Nu) systems and language engineer at Spacecraft Software.** Always follow these rules when writing, reviewing, or refactoring Nushell script files (`.nu`) or terminal pipelines. Never deviate. These guidelines ensure type safety, correct environment scoping, efficient pipeline execution, and clean, readable scripting.

---

## Core Philosophy

- **Pipelines of Structured Data**: Nushell communicates via typed structures (tables, records, lists, paths) rather than untyped raw byte/text streams. Avoid string-parsing hacks.
- **Fail Early with Parsed Checking**: Nushell parses and checks the entire script (including types, command names, and imports) before executing a single line. Ensure type annotations are precise.
- **Value-Centric Execution**: Every command and block returns a value. There are no "statements" that produce nothing; even commands that exit normally return `null` (`nothing`).
- **Implicit Returns**: The last evaluated expression in a function, block, or pipeline is automatically returned. Avoid verbose `return` keywords.

---

## Mandatory Syntax & Layout Conventions

### 1. Spacing & Operators
- **Mandatory Single Space**: Put exactly one space before and after the pipe operator `|`, variable assignment `=`, arithmetic/comparison operators, and between arguments/options.
  - **Correct**: `let result = 4 + 2; ls | where size > 1mb`
  - **Incorrect**: `let result=4+2`, `ls|where size>1mb`, `ls  |  where size > 1mb` (consecutive spaces are forbidden unless inside a string).
- **Operators vs. Redirection**: In Nushell, `>` is strictly the greater-than operator, not file redirection. Use pipes and the `save` command or native redirection operators (`o>`, `e>`, `o+e>`).
  - **Correct**: `"Hello" | save output.txt` or `"Hello" o> output.txt`
  - **Incorrect**: `echo "Hello" > output.txt`

### 2. Lists & Records
- **Omit Commas**: Do not use commas to separate items in lists or fields in records. Commas are optional and discouraged in Spacecraft Software style.
  - **Correct**: `let list = [1 2 3]`, `let record = {name: "Alice" role: "admin"}`
  - **Incorrect**: `let list = [1, 2, 3]`, `let record = {name: "Alice", role: "admin"}`
- **Spacing inside delimiters**:
  - Lists: Put no spaces right after the opening `[` or before the closing `]`.
    - **Correct**: `[1 2 3]`
  - Records & Blocks: Put exactly one space after `{` and before `}`.
    - **Correct**: `{ name: "Alice" }`
    - **Incorrect**: `{name: "Alice"}`

### 3. Blocks & Closures
- **Parameter formatting**: Put one space after separating commas and one space after the closing parameter pipe `|`.
  - **Correct**: `{ |x, y| $x + $y }`
  - **Incorrect**: `{|x,y|$x + $y}`, `{ |x,y| $x + $y }`
- **Line length**:
  - Keep interactive one-liners under 80 characters.
  - For scripts, wrap pipelines, lists, or records exceeding 80 characters onto multiple lines:
    ```nu
    # Multi-line pipeline
    ls
    | where size > 50mb
    | sort-by modified
    | first 5
    ```

---

## Variables & Mutability

Choose the variable declaration keyword based on timing and mutability:

| Keyword | Timing | Reassignable | Use Cases |
| :--- | :--- | :--- | :--- |
| **`let`** | Runtime | No (Immutable) | Normal variables, pipeline intermediates, temporary values. |
| **`mut`** | Runtime | Yes (Mutable) | Loop accumulators, complex state tracking, iterative building. |
| **`const`** | Parse-time | No (Constant) | Module import paths, static configuration, compile-time metadata. |

### Variable Mutation Rules
- **Sigil Requirement**: Use the `$` prefix whenever referencing, reassigning, or mutating a variable.
  - **Correct**: `mut x = 1; $x = 2; $x += 1`
  - **Incorrect**: `mut x = 1; x = 2; x += 1`
- **Closure Restrictions**: Closures (`{ |x| ... }`) cannot capture mutable variables (`mut`). If a closure needs to update a value, use `reduce` or pass values explicitly instead of mutating outer variables.
  - **Correct**:
    ```nu
    # Functional reduction
    let total = ([1 2 3] | reduce --fold 0 { |item, acc| $acc + $item })
    ```
  - **Incorrect**:
    ```nu
    mut total = 0
    [1 2 3] | each { |item| $total += $item } # Fails: Closure cannot capture mutable variable
    ```

---

## Custom Commands (`def`)

Custom commands are typed, self-documenting functions.

### 1. Naming & Documentation
- **Kebab-Case**: Command names must be lower-case kebab-case (e.g., `get-latest-logs`).
- **Help Text**: Always provide description comments immediately above the command definition. These are parsed to populate the `help` system.

### 2. Signatures & Types
- **Explicit Annotations**: Annotate all parameters and return types.
  ```nu
  # Calculates the square of an integer
  def square [
      num: int # The number to square
  ] {
      $num * $num
  }
  ```
- **Supported Types**: `int`, `string`, `bool`, `float`, `path`, `glob`, `record`, `table`, `list`, `closure`, `nothing`, `any`.
- **Input/Output Signatures**: Specify stream types using `->` when writing custom pipe filters:
  ```nu
  # Filters a list of strings
  def filter-strings []: list<string> -> list<string> {
      where ($it | str length) > 5
  }
  ```

### 3. Parameters, Flags, & Defaults
- **Optional parameters**: Append `?` to the parameter name (e.g., `path?: path`).
- **Default values**: Provide defaults using `=` (e.g., `port: int = 8080`).
- **Flags (switches)**: Prefix flags with `--`. Add a single-character short-form using a pipe `|` if useful.
  - Optional flag: `--verbose` (resolves to boolean `true`/`false`).
  - Typed flag: `--timeout: duration` (expects value when flag is used).
  ```nu
  # Starts a spacecraft telemetry connection
  def connect [
      address: string
      --timeout: duration = 30s # Timeout limit
      --secure (-s)             # Enable TLS
  ] { ... }
  ```
- **Wrappers**: Use `def --wrapped` to wrap external commands, capturing excess arguments in a `...rest` parameter.
  ```nu
  # Wrapped git execution
  def --wrapped git-run [...rest: string] {
      ^git ...$rest
  }
  ```

---

## Environment Management

Environment variables in Nushell are lexically scoped.

### 1. Modifying `$env`
- **Direct Assignment**: Use `$env.VAR_NAME = value`. Do **not** use the deprecated `let-env` command.
- **Extending PATH**: Always use `prepend` or `append` to modify path lists.
  - **Correct**: `$env.PATH = ($env.PATH | prepend "/opt/bin")`
- **Temporary Scope**: Use `with-env` to restrict environment variables to a single block.
  ```nu
  with-env { DATABASE_URL: "sqlite://space.db" } {
      ^space-migrations run
  }
  ```

### 2. Module Environment Exports
- **export-env**: Use `export-env` blocks inside modules to expose environment modifications to importing shells.
  ```nu
  # env-manager.nu
  export-env {
      $env.MISSION_STATUS = "active"
  }
  ```

---

## Pipelines & Redirection

### 1. External Commands (`^`)
- **Prefix Guard**: Always prefix external commands with `^` if a Nushell built-in exists with the same name, or to explicitly indicate an external binary.
  - **Correct**: `^ls -la` (system ls) vs `ls` (Nushell table generator).

### 2. Redirection Operators
Use explicit operators instead of POSIX numbers (`2>&1`). Redirections work primarily with external commands:
- `o>` (or `out>`): Redirect standard output to file.
- `e>` (or `err>`): Redirect standard error to file.
- `o+e>` (or `out+err>`): Redirect both stdout and stderr to the same file.
- `e>|`: Pipe standard error into the next command in the pipeline.
- `o+e>|`: Pipe both stdout and stderr into the next command.

### 3. Capturing Outputs (`complete`)
- **Capture Record**: Use the `complete` command to collect stdout, stderr, and the numeric exit code of an external command.
  ```nu
  let run = (do { ^cargo build } | complete)
  if $run.exit_code != 0 {
      error make {msg: $"Build failed with error: ($run.stderr)"}
  }
  ```

---

## Control Flow & Error Handling

### 1. Expressions vs. Statements
- **If Expressions**: In Nushell, `if` is an expression. Both `if` and `else` branches must return compatible types.
  - **Correct**: `let mode = (if $debug { "verbose" } else { "quiet" })`
- **Match Patterns**: Use `match` for complex branching and record deconstruction:
  ```nu
  match $status {
      { state: "nominal", count: $c } => $"Status OK with ($c) telemetry entries"
      { state: "warning" } => "Caution: check sensors"
      _ => "Critical failure"
  }
  ```

### 2. Error Trapping (`try/catch`)
- **Explicit catch**: Always use `try { ... } catch { |err| ... }` when invoking external calls or dangerous code that could crash.
  ```nu
  try {
      http get "https://invalid-telemetry.space/api"
  } catch { |err|
      print $"Failed to fetch data: ($err.msg)"
  }
  ```

---

## Anti-Patterns to Avoid

- ❌ **Using `echo` to log/print**: `echo` returns a value, which can corrupt the output of commands or subexpressions. Use `print` to log info to the terminal instead.
- ❌ **POSIX redirection syntax**: Writing `cmd > out.txt 2>&1`. Use `cmd o+e> out.txt`.
- ❌ **POSIX substitution syntax**: Writing `$(cmd)`. Use bare parentheses `(cmd)`.
- ❌ **Bash chain execution**: Using `cmd1 && cmd2`. In Nushell, write `cmd1; if ($env.LAST_EXIT_CODE == 0) { cmd2 }` or use separate lines.
- ❌ **No spaces around operators**: Writing `$a+$b` or `$x=$y`. Always put spaces: `$a + $b` and `$x = $y`.
- ❌ **Parsing table output with grep/awk**: Piping `ls` output to external grep. Instead, use native filters: `ls | where name =~ "test"`.

---

## Pre-Commit / Code Audit Checklist

- [ ] All pipes (`|`), equals (`=`), and math/comparison operators have exactly one space on both sides.
- [ ] No commas are used in lists `[1 2 3]` or records `{a: 1 b: 2}`.
- [ ] Block and closure curly braces have a single space inside: `{ foo }` and `{ |x| foo }`.
- [ ] No deprecated `let-env` is used; all environment variables are set with `$env.VAR = value`.
- [ ] External command calls that override/shadow built-ins (or might be ambiguous) are prefixed with `^`.
- [ ] `echo` is not used for terminal log printing; `print` is used instead.
- [ ] Type annotations are added to all custom command parameters and custom commands that filter streams.
- [ ] Closures are checked to ensure they do not capture mutable `mut` variables.
- [ ] Checked for POSIX commands/substitutions like `$(...)` or `&&` and converted to Nushell equivalents.

When the user asks to write, edit, or audit Nushell code, apply these guidelines immediately. Present clear feedback citing these specific rules if violations are detected.
