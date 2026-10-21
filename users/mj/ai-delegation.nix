# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Claude Code delegates to OpenCode Go (docs/ai-delegation.md)
#
# Claude Code plans and reviews; OpenCode Go models write the code. This file
# renders one Claude Code subagent per model in lib/opencode-go.nix into
# ~/.claude/agents/oc-<slug>.md. Each subagent is a thin forwarder: one
# `opencode run -m opencode-go/<id>` call, output returned verbatim. Its
# description carries the registry's `use` line, which is what Claude reads
# when it decides which subagent gets a task, so the routing table lives in
# the registry and nowhere else.
#
# The forwarders run on Haiku: they only quote the task into one command, so a
# larger model would cost Claude Code usage for no gain.
#
# Left unmanaged on purpose:
#   - ~/.config/opencode/opencode.json and the Go key (`opencode auth login`):
#     OpenCode writes both itself, and a managed copy would clash on every
#     activation (constraint #30). Keys never go in the store.
#   - the `opencode` CLI, which stays out-of-band in ~/.opencode/bin and is
#     updated by `preflight --update-ai-tools`.
{ lib, ... }:

let
  go = import ../../lib/opencode-go.nix;
  model = m: "${go.provider}/${m.id}";

  contributorNote =
    m:
    lib.optionalString m.contributor " Its provider trains on the prompts, so never send it private code, secrets or anything outside a public repo.";

  # Descriptions are emitted as JSON strings, which YAML reads as quoted
  # scalars: the registry's `use` lines contain ": ", which would end a plain
  # YAML scalar and break the frontmatter.
  coder = m: ''
    ---
    name: oc-${m.slug}
    description: ${builtins.toJSON "Hand one bounded coding task to ${m.name} through OpenCode Go (writes files). Use for: ${m.use}${contributorNote m} Give it the goal, the files to touch and how to check the result; review its diff before relying on it."}
    tools: Bash
    model: haiku
    ---
    You forward exactly one coding task to OpenCode, running ${m.name}. You do
    no other work: do not read files, plan, fix, review or summarise.

    Make exactly one Bash call, with a 600000 ms timeout, putting the task text
    you were given between the TASK lines unchanged:

    ```sh
    opencode run -m ${model m} --agent build "$(cat <<'TASK'
    <the task, verbatim>
    TASK
    )"
    ```

    Return OpenCode's output exactly as printed. If the command fails (rate
    limit, sign-in, unknown model), return the error text and say it came from
    ${model m}, so the caller can pick another model.
  '';

  reviewer = r: ''
    ---
    name: oc-${r.slug}
    description: ${builtins.toJSON "Read-only review of a finished change by ${r.name} through OpenCode Go. ${r.use} Use after the work is done and before the CodeRabbit review and the PR. Pass a base ref if it is not origin/main. It changes no files."}
    tools: Bash
    model: haiku
    ---
    You forward one review to OpenCode, running ${r.name} read-only. You do no
    other work: do not read files, judge findings or fix anything.

    Make exactly one Bash call, with a 600000 ms timeout. Use the base ref you
    were given, or origin/main when none was named:

    ```sh
    base=origin/main
    diff_file=$(mktemp --suffix=.diff)
    git diff "$(git merge-base "$base" HEAD)" >"$diff_file"
    opencode run -m ${model r} --agent plan -f "$diff_file" "$(cat <<'REVIEW'
    ${lib.trim r.brief}
    REVIEW
    )"
    status=$?
    rm -f "$diff_file"
    [ "$status" -eq 0 ] || echo "opencode exited with status $status"
    ```

    Return OpenCode's output exactly as printed. If the command fails, return
    the error text and say it came from ${model r}.
  '';
in
{
  home.file = lib.listToAttrs (
    map (m: lib.nameValuePair ".claude/agents/oc-${m.slug}.md" { text = coder m; }) go.coders
    ++ map (r: lib.nameValuePair ".claude/agents/oc-${r.slug}.md" { text = reviewer r; }) go.reviewers
  );
}
