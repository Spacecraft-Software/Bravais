# CREDITS

The `spacecraft-rust-guidelines` skill is original Spacecraft Software work (a
concurrency & performance doctrine for Rust). Its **idiom layer**
([`references/idioms.md`](references/idioms.md)) adapts third-party work, recorded here
in accordance with [The Steelbore Standard §15.3](../spacecraft-standard-constitution/SKILL.md).

## Apollo GraphQL — Rust Best Practices skill

| Field      | Value                                          |
|------------|------------------------------------------------|
| Name       | Apollo GraphQL *Rust Best Practices* skill (`rust-best-practices`) |
| Author(s)  | Apollo Graph, Inc.                             |
| License    | MIT License                                    |
| Source URL | https://github.com/apollographql/skills        |
| Scope      | Idiom/readability rules distilled into `references/idioms.md` — borrowing-vs-cloning, `Copy` sizing, idiomatic `Option`/`Result` flow, iterators-vs-`for`, clippy lint names + `expect`-over-`allow`, testing conventions (one assertion per test, `insta` snapshots), static-vs-dynamic dispatch, the type-state pattern, comments-vs-docs, import ordering, flamegraph profiling (adapted from Chapter 3), and smart pointers / thread-safety (adapted from Chapter 9). Apollo's error-handling chapter was **not** adapted (this skill's SKILL.md and `microsoft-rust-guidelines` cover those). |

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
