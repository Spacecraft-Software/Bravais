<!--
SPDX-FileCopyrightText: 2024 Apollo Graph, Inc.
SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
SPDX-License-Identifier: GPL-3.0-or-later
-->

# Attribution — Steelbore Rust Idiom Layer

[`idioms.md`](idioms.md) — together with the `anyhow` and async-error-bound bullets in
[`../SKILL.md`](../SKILL.md) "Error Handling & Resilience" — is a Steelbore-authored
distillation (GPL-3.0-or-later) of rules adapted from the **Apollo GraphQL Rust
Best Practices skill**. Per the Steelbore Standard §4.2 (upstream license compliance)
and §15.3 (third-party attribution), the upstream MIT notice is preserved verbatim below.

- **Adapted work:** Apollo GraphQL — *Rust Best Practices* skill (`rust-best-practices`)
- **Source:** <https://github.com/apollographql/skills>
- **Upstream license:** MIT
- **What was adapted:** the idiom/readability rules — borrowing-vs-cloning, `Copy`
  sizing, idiomatic `Option`/`Result` flow, iterators-vs-`for`, clippy lint names and
  `expect`-over-`allow` discipline, testing conventions (one assertion per test,
  descriptive names, `insta` snapshots), static-vs-dynamic dispatch, the type-state
  pattern, comments-vs-docs, import ordering, flamegraph profiling details (adapted
  from Chapter 3), and smart pointers / thread-safety guidelines (adapted from Chapter 9).
  The 2026-10-06 re-sync additionally adapted: Ch. 1 §1.5 (never `Copy` + `Iterator` on
  one type) and §1.8 (when to extract a function); Ch. 2 (`[lints.rust]` beside
  `[lints.clippy]`, `--all-features` caveat); Ch. 3 (ownership as modelling, clone-late,
  `Cow`, stack-vs-heap traps, `clippy::perf` pass, `impl Iterator` to callees); Ch. 4
  §4.4 (`anyhow` for binaries and test helpers only), §4.6 (tests exercise errors) and
  §4.7 (async error bounds) — both §4.4 and §4.7 placed in `SKILL.md`, not `idioms.md`;
  Ch. 5 (`assert_matches!`, `pretty_assertions`, shared setup with inline
  action/assertion); Ch. 7 (`bon`); Ch. 8 (`#[non_exhaustive]`, doc-coverage checklist);
  Ch. 9 (`RefCell` conflicting-borrow panic). Apollo's error-*design* guidance (Ch. 4
  §4.1–§4.3, §4.5) remains **not** adapted — SKILL.md points to
  `microsoft-rust-guidelines` for it.
- **Last synced against upstream:** 2026-10-06 (apollographql/skills commit of
  2026-09-28)

> Note: the *skill* we adapted from (the `apollographql/skills` repository) is MIT. A
> separate upstream repository — the standalone *Rust Best Practices* handbook/book —
> is Apache-2.0; we did not copy that book's text, only adapted the MIT skill, so the
> applicable notice is the MIT one below.

---

## Upstream MIT License (verbatim)

```
MIT License

Copyright (c) 2024 Apollo Graph, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
