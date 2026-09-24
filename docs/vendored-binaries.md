# Vendored upstream binaries — the exceptions

The long form of the **Vendored upstream binaries** section in `AGENTS.md`:
why `codex-desktop` breaks differently from every other pinned package, and
why `grok-bot` and `skyroads` are deliberately kept out of
`pkgs/update-vendored.nu`. Read it before bumping or re-wiring any of the
three. The updater's own mechanics are in the `vendored-binaries` skill
(`.claude/skills/vendored-binaries/`).

`codex-desktop` is the odd one out: OpenAI publishes **no versioned URL**, only `…/deb/latest/`. The pin therefore breaks whenever they ship a build, and the pinned artifact cannot be refetched once replaced — unlike every other entry, whose exact version stays fetchable. Its updater keys off the blob **ETag** from a HEAD request rather than a release API, so `--check` stays free instead of downloading 378 MB, and reads the version out of the `.deb` control file only once something has actually changed.

`grok-bot` (`pkgs/grok-bot/`) is the other deliberate exclusion, for a different reason: its download URL embeds an opaque **build hash** (`.../grokbot/stable/<40 hex>/linux/x64/grok-bot_<version>_amd64.deb`) that is not derivable from the version, and upstream publishes no release feed to discover it from — `cursor.com/api/download` ignores a `product=`/`app=grokbot` parameter and answers for the Cursor editor instead, and the download page renders its link client-side. So a bump is two edits from a URL copied by hand: take a fresh link from https://www.cursor.com/grokbot/download, **strip the `?_gl=...` analytics parameter** (a Google Analytics linker token, not part of the address — leaving it in makes the fetch unreproducible), then `nix-prefetch-url` it and update `version` + `hash` together. Wire it into the updater the moment a feed appears; until then an entry there could only ever report "unknown".

`skyroads` (`pkgs/skyroads/`) also pins a `version` + `hash` but is deliberately **outside** this set and outside `update-vendored.nu`: the artifact has been frozen since the 1990s and Bluemoon publishes no release feed, so there is nothing for a bumper to poll. Do not "fix" the omission by adding it.
