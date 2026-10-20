# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — OpenCode Go model registry (docs/ai-delegation.md).
#
# THE list of OpenCode Go models Claude Code delegates to, and what each one
# is for. users/mj/ai-delegation.nix renders one Claude Code subagent per entry
# (~/.claude/agents/oc-<slug>.md) whose description is `use`, so Claude picks
# the model by task; nothing else restates an id or a routing rule.
#
# `allowance` is the per-model monthly dollar allowance on the Go plan (the
# 5-hour window is 20% of it, the weekly one 50%). It is why the routing leans
# on the plentiful models for volume and keeps the $15 ones for the work where
# quality matters most. `contributor` models let Google or Meta train on the
# prompts: fine for public GPL code like this repo, never for private work, so
# their subagent descriptions say so. Source and as-of date:
# https://opencode.ai/v2/docs/console/go/ (2026-10-20); confirm on the machine
# with `opencode models opencode-go`.
{
  # Prefix every id carries; `opencode run -m` takes "<provider>/<model>".
  provider = "opencode-go";

  coders = [
    {
      slug = "deepseek-flash";
      id = "deepseek-v4.1-flash";
      name = "DeepSeek V4.1 Flash";
      allowance = 80;
      contributor = false;
      use = "Mechanical, high-volume edits: renames, boilerplate, SPDX headers, syncing PRD.md / TODO.md / CHANGELOG.md with a change. First choice when the task is well specified and the file list is known.";
    }
    {
      slug = "kimi";
      id = "kimi-k2.7-code";
      name = "Kimi K2.7 Code";
      allowance = 60;
      contributor = false;
      use = "Ordinary features and bug fixes confined to one module, package or crate. The default coder when no other row fits.";
    }
    {
      slug = "gemini";
      id = "gemini-4-argon-contributor";
      name = "Gemini 4 Argon Contributor";
      allowance = 60;
      contributor = true;
      use = "Whole-repo reads and long inputs: finding every place that does X, digesting long build logs or large diffs. Public repos only.";
    }
    {
      slug = "muse";
      id = "muse-spark-1.3-contributor";
      name = "Muse Spark 1.3 Contributor";
      allowance = 60;
      contributor = true;
      use = "Overflow for mechanical edits when DeepSeek V4.1 Flash is rate-limited. Public repos only.";
    }
    {
      slug = "deepseek-pro";
      id = "deepseek-v4-pro";
      name = "DeepSeek V4 Pro";
      allowance = 15;
      contributor = false;
      use = "Hard multi-file work: Rust crates such as pkgs/preflight, tricky Nix derivations, changes that must keep several files in step.";
    }
    {
      slug = "qwen";
      id = "qwen3.8-max";
      name = "Qwen3.8 Max";
      allowance = 15;
      contributor = false;
      use = "Fallback for hard multi-file work when DeepSeek V4 Pro is rate-limited, or a second independent attempt at it.";
    }
    {
      slug = "grok";
      id = "grok-4.7";
      name = "Grok 4.7";
      allowance = 15;
      contributor = false;
      use = "Stuck debugging: a fresh diagnosis when Claude or another delegate has not found the cause.";
    }
  ];

  # Read-only review of a finished change, before CodeRabbit.
  reviewer = {
    slug = "glm-review";
    id = "glm-5.3";
    name = "GLM-5.3";
    allowance = 15;
    contributor = false;
  };
}
