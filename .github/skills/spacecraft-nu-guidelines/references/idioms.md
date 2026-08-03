# Nushell Idiomatic Patterns & Translation Reference

This document provides quick reference tables and side-by-side examples to translate common Bash patterns into idiomatic Nushell code.

---

## 1. Quick Translation Targets

| Bash Pattern | Nushell Equivalent | Notes |
| :--- | :--- | :--- |
| `val="hello"` | `let val = "hello"` | Variables are immutable by default. |
| `val="new"` (reassign) | `mut val = "init"; $val = "new"` | Reassignment requires the `mut` keyword. |
| `export VAR="value"` | `$env.VAR = "value"` | Env variables are stored in the `$env` record. |
| `$(command)` | `(command)` | Standard parentheses denote command substitution. |
| `cmd1 && cmd2` | `cmd1; if ($env.LAST_EXIT_CODE == 0) { cmd2 }` | Nushell has no `&&` short-circuiting for external commands. |
| `cmd > out.txt 2>&1` | `cmd out+err> out.txt` | Stream redirection operator. |
| `if [ -f path ]; then ...` | `if ("path" \| path exists) { ... }` | Use path inspection pipelines. |
| `for f in *.rs; do ...` | `ls *.rs \| each { \|f\| ... }` | Prefer pipelines with closures over loops. |
| `function name { ... }` | `def name [] { ... }` | Custom command definition. |

---

## 2. Common Scripting Scenarios

### Checking File Existence and Attributes
In Bash, you use various `-f`, `-d`, `-e` flags with the `test` command. In Nushell, use the `path` family of commands.

#### Bash:
```bash
if [ -f "telemetry.log" ]; then
    echo "Found file"
fi
```

#### Nushell:
```nu
if ("telemetry.log" | path exists) and ("telemetry.log" | path type) == "file" {
    print "Found file"
}
```

---

### Executing Loops and Pipeline Maps
Nushell processes lists and tables using pipelines. Avoid standard `for` loops in favor of `each` and `filter` closures.

#### Bash:
```bash
for file in *.json; do
    if grep -q "active" "$file"; then
        echo "Active: $file"
    fi
done
```

#### Nushell:
```nu
ls *.json
| filter { |file| (open $file.name | get status?) == "active" }
| each { |file| print $"Active: ($file.name)" }
```

---

### Temporary Environment Scopes
Run a command with temporary environment variables.

#### Bash:
```bash
PORT=9000 DEBUG=true node server.js
```

#### Nushell:
```nu
with-env { PORT: 9000 DEBUG: "true" } {
    ^node server.js
}
```

---

### Finding and Invoking Actions Recursively
Nushell's globbing is built into `ls` and `glob`.

#### Bash:
```bash
find . -name "*.log" -exec rm {} \;
```

#### Nushell:
```nu
ls **/*.log | each { |file| rm $file.name }
```

---

## 3. Working with Nushell Tables

Nushell commands return structured tables. Here are the most common operations for table manipulation:

### Filtering Columns (`select` & `reject`)
- Use `select` to keep specific columns.
- Use `reject` to discard specific columns.

```nu
# Keep only name and size
ls | select name size

# Discard the type column
ls | reject type
```

### Filtering Rows (`where`)
- Use boolean conditions to filter records.

```nu
# Find large files modified recently
ls | where size > 10mb and modified > ((date now) - 1hr)
```

### Accessing Inner Values (`get`)
- Extract a column as a list, or query a nested record path.

```nu
# Get names as a list of strings
let names = (ls | get name)

# Nested record extraction
let port = ({ server: { config: { port: 8080 } } } | get server.config.port)
```
