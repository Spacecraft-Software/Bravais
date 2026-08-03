<!--
SPDX-License-Identifier: GPL-3.0-or-later
Copyright (C) 2026 Mohamed Hammad & Spacecraft Software
-->

# Brush — Bash-Compatible Rust Shell

**Brush** (Bourne RUsty SHell) is a POSIX- and Bash-compatible shell written in
Rust. The Steelbore Standard §7 lists it as one of the four first-class shell
environments (Nushell, Ion, Brush, Bash). Unlike Nushell and Ion — which reject
Bash syntax outright — Brush is built to *accept* the Bourne/Bash family, so the
mental model is simple:

> **For syntax purposes, treat Brush as Bash.** Write POSIX first (it runs
> unchanged); reach for a Bash extension only when POSIX cannot express the
> operation. The POSIX-first / avoid-bashisms discipline from `posix-safe.md`
> applies directly.

This file records only what is *different* from "just write Bash."

## What carries over unchanged

- **All POSIX sh constructs** — `[ ]` / `test`, `name() { … }`, `$(( … ))`,
  `. file`, parameter expansion (`${var:-default}`, `${var#pat}`, `${var%pat}`),
  `case`/`esac`, command substitution `$( )`. These are the rank-1 default and
  the safest target in Brush.
- **Common Bash extensions** Brush implements — `[[ … ]]`, `(( … ))`, arrays
  (`arr=(a b c)`, `${arr[@]}`), `${var^^}`/`${var,,}`, brace expansion,
  `local`, here-strings. When the target is genuinely Brush (not portable sh),
  these generally parse the same as in Bash.

## Where Brush differs from Bash — verify, don't assume

Brush is an actively maturing reimplementation. It targets Bash compatibility but
does not yet cover 100% of Bash's surface. Treat the following as "confirm before
relying on it," especially in scripts meant to run unattended:

- **Newer / exotic Bash builtins and options.** Less-common `shopt` toggles
  (`globstar`, `extglob`, `nocaseglob`), namerefs (`declare -n`), associative
  arrays (`declare -A`), `coproc`, and `mapfile`/`readarray` may be partially
  implemented or absent in a given Brush release. If a script needs one, test it
  against the installed Brush version or fall back to a POSIX formulation.
- **Bash-specific special variables.** `$PIPESTATUS`, `$BASH_SOURCE`,
  `$FUNCNAME`, `$EPOCHSECONDS`, `$RANDOM` — presence tracks Brush's compatibility
  matrix, not a guarantee. Prefer portable equivalents (`date +%s`, `shuf -i`)
  unless Brush support is confirmed.
- **`$BASH_VERSION` is unset.** Scripts that gate behavior on `$BASH_VERSION`
  will take their non-Bash branch under Brush. Detect by capability, not by
  identity string.

## Bottom line for this skill

- **Portable / shared scripts** → write POSIX (`posix-safe.md`). Runs identically
  in Brush, Bash, dash, ash. This is the default and needs no Brush-specific care.
- **Confirmed-Brush target, POSIX insufficient** → a Bash extension is acceptable,
  but announce it (per SKILL.md Step 2) *and* prefer the widely-implemented subset
  (`[[ ]]`, indexed arrays, `local`) over the exotic tail above.
- **Converting an existing Bash script to run under Brush** → it usually "just
  works"; the residual risk is the exotic-feature tail, not everyday syntax. See
  `bashisms.md` for the constructs that are Bash-only against the *non*-Bash
  shells — those are a non-issue for Brush itself, but matter if the same script
  must also run in Nushell or Ion.
