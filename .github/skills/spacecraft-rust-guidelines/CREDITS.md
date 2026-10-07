# CREDITS

The `spacecraft-rust-guidelines` skill is original Spacecraft Software work (a
concurrency & performance doctrine for Rust). Its **idiom layer**
([`references/idioms.md`](references/idioms.md)) and the two error-handling bullets in
`SKILL.md` ("Error Handling & Resilience") adapt third-party work, recorded here
in accordance with [The Steelbore Standard §15.3](../spacecraft-steelbore-standard/SKILL.md).

## Apollo GraphQL — Rust Best Practices skill

| Field      | Value                                          |
|------------|------------------------------------------------|
| Name       | Apollo GraphQL *Rust Best Practices* skill (`rust-best-practices`) |
| Author(s)  | Apollo Graph, Inc.                             |
| License    | MIT License                                    |
| Source URL | https://github.com/apollographql/skills        |
| Scope      | Idiom/readability rules distilled into `references/idioms.md` — borrowing-vs-cloning, `Copy` sizing, idiomatic `Option`/`Result` flow, iterators-vs-`for`, clippy lint names + `expect`-over-`allow`, testing conventions (one assertion per test, `insta` snapshots), static-vs-dynamic dispatch, the type-state pattern, comments-vs-docs, import ordering, flamegraph profiling (adapted from Chapter 3), and smart pointers / thread-safety (adapted from Chapter 9). |

**2026-10-06 re-sync** additionally adapted: Ch. 1 §1.5 (never `Copy` + `Iterator` on one type) and §1.8 (when to extract a function); Ch. 2 (`[lints.rust]` beside `[lints.clippy]`, `--all-features` caveat); Ch. 3 (ownership as modelling, clone-late, `Cow`, stack-vs-heap traps, `clippy::perf` pass, `impl Iterator` to callees); Ch. 4 §4.4 (`anyhow` for binaries and test helpers only), §4.6 (tests exercise errors) and §4.7 (async error bounds) — §4.4 and §4.7 sit in `SKILL.md`'s "Error Handling & Resilience" section, not `idioms.md`; Ch. 5 (`assert_matches!`, `pretty_assertions`, shared setup with inline action/assertion); Ch. 7 (`bon`); Ch. 8 (`#[non_exhaustive]`, doc-coverage checklist); Ch. 9 (`RefCell` conflicting-borrow panic). Apollo's error-*design* guidance (Ch. 4 §4.1–§4.3, §4.5) remains **not** adapted — SKILL.md points to `microsoft-rust-guidelines` for it.

Last synced against upstream: 2026-10-06 (apollographql/skills commit of 2026-09-28).

The verbatim upstream MIT notice is preserved in
[`references/ATTRIBUTION.md`](references/ATTRIBUTION.md) (Standard §4.2).

## License of this skill

This skill is released under **GPL-3.0-or-later** (skills are software-class per
Standard §4.1.1). MIT is GPL-3.0-compatible, so the adapted idiom material is carried
under the GPL overlay while the upstream MIT copyright/permission notice is preserved
per §4.2.

## Maintainer

Mohamed Hammad &lt;Mohamed.Hammad@SpacecraftSoftware.org&gt;
https://SpacecraftSoftware.org/
