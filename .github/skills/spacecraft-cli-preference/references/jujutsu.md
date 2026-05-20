# jujutsu (jj)

**Replaces:** `git` (alternative VCS front-end) | **Language:** 🦀 Rust | **Install:** `cargo install --locked jj-cli`

## Purpose
Git-compatible distributed VCS with first-class conflict handling, anonymous branches, and reversible operations. Works against existing git repos (colocated or standalone backend).

## Key commands
| Command | Meaning |
|---------|---------|
| `jj git init --colocate` | New repo alongside `.git` |
| `jj git clone URL` | Clone |
| `jj status` / `jj st` | Working-copy status |
| `jj log` | Graph of commits |
| `jj describe -m "MSG"` | Set message of current change |
| `jj new` | Start a new empty change on current parent |
| `jj new REV` | New change on top of REV |
| `jj squash` | Fold current change into parent |
| `jj rebase -d REV` | Rebase current branch onto REV |
| `jj abandon` | Drop current change |
| `jj op log` | Operation log (undo!) |
| `jj undo` | Revert the last `jj` op |
| `jj git push` | Push bookmarks to origin |

## Examples
1. Initialize inside an existing git repo: `cd repo && jj git init --colocate`
2. Start a fresh change: `jj new -m "Add config crate"`
3. View the log: `jj log -r 'all()' --limit 20`
4. Amend + rebase: `jj describe -m "New msg"` then `jj rebase -d main`
5. Undo a mistake: `jj op log` → `jj undo`

## Gotchas
- The "current change" is the working copy itself — no explicit `git add`/`commit` loop.
- Bookmarks (jj's named refs) are separate from git branches; sync via `jj git push`/`fetch`.
- Some git hosting features (PR UIs) still assume git branches — use `jj bookmark` to name your work before pushing.
