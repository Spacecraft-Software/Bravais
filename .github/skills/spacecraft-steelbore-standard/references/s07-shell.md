<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
## §7 — Shell Environment

Spacecraft Software tooling, documentation, and CI pipelines target **four first-class shell environments**: **Nushell**, **Ion**, **Brush**, and **Bash**. All four are equally supported; none is deprecated or downgraded.

### §7.1 — Script Portability Policy

| Rule | Detail |
|------|--------|
| Default: POSIX-compatible | Shell scripts in source trees, CI pipelines, `Makefile` targets, and documentation examples **must** be written to the POSIX sh subset unless a shell-native feature is required. POSIX scripts run correctly in Bash and Brush without modification. |
| Nushell / Ion native variants when needed | When a task cannot be expressed cleanly in POSIX sh (structured data pipelines, typed parameters, Nushell modules), provide a Nushell (`.nu`) and/or Ion-native variant alongside the POSIX version. Do not force POSIX-only idioms that degrade the Nushell or Ion experience. |
| No Bashisms in shared scripts | Bash-only extensions (`[[ ]]`, `(( ))`, process substitution `<(...)`, `${var^^}`, indexed arrays) are prohibited in files intended for all four shells. Bash-specific scripts are permitted only when explicitly scoped (e.g., `#!/usr/bin/env bash` shebang, clearly labeled). |
| Graceful shell detection | Tools that need runtime shell detection must inform the user or degrade gracefully rather than silently failing in non-Bash environments. |

### §7.2 — Commands Handed to a User

When an agent, a document, or a tool's output gives a person **two or more commands to run in sequence**, it ends the list with **one line that runs them all**, so the whole sequence is one copy and one paste. The separate commands stay above it; the combined line is the convenience, not a replacement.

The line must **stop at the first command that fails**: each step depends on the one before it, and a line that carries on past a failure runs the later steps against a state that does not exist. A plain `;` gives that guarantee in some shells and not in others, so the joiner is chosen for the shell that will run the line.

| Rule | Detail |
|------|--------|
| When it applies | Two or more commands the reader is meant to run together, one after the other, in one shell. A single command needs no combined line. Commands meant for different hosts, different shells, or different points in a procedure ("run this, then check the output before going on") are separate hand-offs and are not combined. |
| Placement and content | The combined line comes last, in its own code block. It carries exactly the commands listed above it, in the same order, with nothing added, dropped, or rewritten except what joining them requires. Comments are left out of it. |
| Joiner per shell | Join with the shell's fail-fast operator, not a plain separator. POSIX sh, Bash, Brush, dash, ash, and zsh use `&&`. Ion, fish 3 or later, and PowerShell 7 or later also use `&&`. **Nushell uses `;`**, because a failed command — an external command exiting non-zero included — raises an error that ends the line, and Nushell does not accept `&&` between commands. Windows PowerShell 5.1, which has no `&&`, uses `cmd1; if ($?) { cmd2 }`. A shell not named here uses its own fail-fast operator; when that is not known, the plain separator is used and the hand-off says, in one line, that it does not stop on failure. |
| Which shell | The combined line is written for the same shell as the commands above it — the login shell of the person who will run it, not the shell the project's scripts target. A POSIX line handed to a Nushell user is wrong even when each command is in the common subset, because the joiner differs. |
| Commands with their own operators | In a POSIX shell, a listed command that itself contains `\|\|`, `;`, or `&` is wrapped in a brace group, `{ cmd \|\| alt; }`, before it is joined, so the operators bind as the separate command did. A pipeline needs no wrapping; its status is its last command's. |
| What never goes in | A command that opens an interactive session, runs in the foreground until stopped (a server, a watcher, an editor), or is destructive and meant to be run only after reading the output of the steps before it. A long-running command may end the line if the steps before it only prepare for it; otherwise the line stops short of it and the hand-off says so. |

Three commands for a Bash user end with the first line below; the same three for a Nushell user end with the second:

```sh
git fetch origin main && git switch -c fix-typo origin/main && make md
```

```nu
git fetch origin main ; git switch -c fix-typo origin/main ; make md
```

---
