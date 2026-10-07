<!--
SPDX-FileCopyrightText: 2024 Apollo Graph, Inc.
SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
SPDX-License-Identifier: GPL-3.0-or-later
-->

# Steelbore Rust Idiom Layer

> **Provenance:** Distilled and adapted from Apollo GraphQL's *Rust Best Practices*
> skill (MIT, © 2024 Apollo Graph, Inc.); last re-synced against upstream on
> 2026-10-06. See [`../CREDITS.md`](../CREDITS.md) and
> [`ATTRIBUTION.md`](ATTRIBUTION.md). This is the **idiom/readability plane** — it sits
> *under* the concurrency/performance doctrine in `SKILL.md`, not against it. Error
> handling as a *design* concern is intentionally **not** covered here (the SKILL.md
> "Error Handling & Resilience" section and `microsoft-rust-guidelines` own that
> plane); only the **testing-side** error rules — exercising and asserting on the
> `Err` path — live here, in §5.

Load this when the question is about **how Rust reads** — borrowing, idiomatic
control flow, lint discipline, testing, dispatch choice, type-state, docs, import
ordering, smart pointers, and extracting functions. For *how fast it runs* and *how it
scales across cores*, stay in `SKILL.md`.

---

## 1. Borrowing & ownership

- Prefer `&T` over `.clone()`; pass `&str` not `String`, `&[T]` not `Vec<T>`/`&Vec<T>`.
- Make ownership transfer **explicit in the signature** — never `let x = arg.clone()`
  inside a function to fake ownership the caller should have handed you.
- **Clone deliberately**, only when: you need a mutated copy *and* the original
  (immutable snapshots), `Arc`/`Rc` sharing, the callee API demands owned data, or
  avoiding a disruptive refactor in non-hot code.
- Don't clone inside iterator closures (`.map(|x| x.clone())`); call `.cloned()` /
  `.copied()` at the end of the chain instead.

### Pass by value when `Copy` is cheap
- Derive `Copy` only when **all fields are `Copy`**, the type is "plain data" with no
  heap ownership, and it's small — **≤ 24 bytes / 2–3 machine words**.
- Good: `#[derive(Copy, Clone)] struct Point { x: f32, y: f32, z: f32 }`. Bad: any
  struct holding a `String`/`Vec`. Enum size is its **largest** variant.
- Arrays are stack-allocated and `Copy` if their element is — but large `[T; N]`
  copies invite stack overflow; see *Stack vs heap traps* below for how to
  heap-allocate them without a stack copy.

### Clone late, own deliberately
- **Never put `Copy` and `Iterator` on one type** — not even when every field is
  `Copy`. Copy an iterator, advance one copy, and the other stays put: silent wrong
  results, not a compile error. It is why `Range` is not `Copy`, and why the
  `core::range` types (Rust 1.96) implement `IntoIterator` rather than `Iterator` so
  they *can* be. A
  `Copy` type that needs iteration implements `IntoIterator` and hands back a separate
  iterator struct.
- **Ownership is a modelling tool.** Take a value by move when the move *says*
  something: `Validated::try_from(untrusted)` consuming the untrusted input makes "no
  going back" explicit even where a borrow would have compiled. Internal/private
  builders can use `fn x(&mut self, x: X) -> &mut Self`; public library builders follow
  M-INIT-BUILDER in `microsoft-rust-guidelines` (`references/12_libraries_ux_guidelines.md`:
  consuming `mut self -> Self`, setters named `x()`, final `build(self)`), and any
  type-state builder (§7, `bon`) must consume `self` because the state type changes.
- **If you must clone, clone at the last possible moment** — right where the owned
  value is handed off, never pre-emptively at the top of a function. Cloning is also the
  *right* call for handle-like types whose `Clone` shares a resource (a hyper legacy
  `Client` clone shares its connection pool; M-SERVICES-CLONE in
  `microsoft-rust-guidelines`, `references/12_libraries_ux_guidelines.md`, is the same
  idea).
- **`Cow<'_, str>` / `Cow<'_, [T]>` for maybe-owned parameters** when the API cannot
  say up front whether it needs ownership: the borrowed case stays allocation-free and
  the owned case is still accepted, without two signatures.
- **Stack vs heap traps.** `Box::new([0u8; 65536])` materialises the array on the
  stack *first* and then moves it to the heap — write `vec![0u8; N].into_boxed_slice()`
  (a `Box<[u8]>`) instead. Types above ~512 bytes travel by `&T`/`&mut T`, not by
  value; recursive data is boxed (`enum Octree<T> { Leaf(T), Children(Box<[Self; 8]>) }`);
  small `Copy` types are returned by value. `#[inline]` only when a benchmark proves
  it — rustc inlines well without hints; the exception is a small non-generic `pub fn`
  on a hot cross-crate path, which needs `#[inline]` (or LTO) to be inlined by callers.

## 2. Idiomatic `Option`/`Result` control flow

- `let Some(x) = expr else { return / continue / break };` when the missing case is
  **expected** and the divergent branch needs no info about the failure.
- `if let … else { … }` only when the else branch needs real computation.
- `match` when you pattern-match inner `T`/`E`, use guards, or reshape the type.
- Convert with `.ok()` / `.ok_or_else()`, not a hand-written `match`.
- Propagate with `?` when you don't inspect the `Err`; transform/log with
  `.inspect_err(…)` + `.map_err(…)`.
- **Prevent early allocation:** prefer the `_else` / `_default` family when the
  fallback allocates or computes — `ok_or_else`, `unwrap_or_else`, `unwrap_or_default`,
  `map_or_else` — over `ok_or`, `unwrap_or(Vec::new())`, `map_or(format!(…), …)`.

## 3. Iterators vs `for`

- Reach for **iterator chains** to transform collections / `Option` / `Result`,
  compose steps, `enumerate`, `windows`/`chunks`, or fuse multiple sources without
  intermediate allocations.
- Reach for a **`for` loop** for early exit (`break`/`continue`/`return`), side-effecting
  iteration (logging, I/O), or when it simply reads clearer.
- Iterators are **lazy** — nothing runs until a consumer (`.collect`, `.sum`,
  `.for_each`). Prefer `.iter()` over `.into_iter()` unless you need ownership (and for
  `Copy` element types). Prefer `.sum()` over `.fold()` for summation (the compiler
  specialises it). Don't `.collect()` just to throw the collection away.
- When a callee only *iterates*, hand it an `impl Iterator<Item = T>` (or
  `impl IntoIterator`) rather than collecting into an intermediate `Vec` it will walk
  once and drop: `process(items.iter().map(|x| x * 2))`, not
  `process(items.iter().map(|x| x * 2).collect::<Vec<_>>())`.

## 4. Clippy discipline (the surgical layer)

The **canonical CI command** is the one in `SKILL.md` ("Tooling & Quality Gates") —
run that, not a variant of it. This section is the per-lint detail under that command,
not a competing policy.

- `--all-features` in the canonical command enables every feature at once and cannot
  express mutually exclusive ones; such crates need a feature matrix as well.
- To see *only* the performance lints (e.g. while triaging a hot path), isolate the
  group: `cargo clippy -- -A clippy::all -W clippy::perf` — under the canonical command
  they already fail the build.
- Set lint levels in `Cargo.toml` `[lints.*]` (or `[workspace.lints.*]` plus
  `lints.workspace = true` in each member). Groups take a negative `priority` so
  individual lints (default 0) override them. `[lints.clippy]` itself is the base
  skill's table (M-STATIC-VERIFICATION in `microsoft-rust-guidelines`,
  `references/08_universal_guidelines.md`): groups at `priority = -1`, single lints
  above them, so per-lint opt-outs win. Give it a `[lints.rust]` companion:

  ```toml
  [lints.rust]
  future_incompatible = { level = "warn", priority = -1 }
  nonstandard_style = { level = "deny", priority = -1 }
  ```

  Setting a group's level overrides each member's default, so `"warn"` here demotes
  the group's deny-by-default members to warnings under plain `cargo build` (the
  canonical `-D warnings` makes them errors again).
- Named lints worth respecting: `redundant_clone`, `clone_on_copy`, `needless_borrow`,
  `needless_collect`, `large_enum_variant` (box the big variant), `unnecessary_wraps`,
  `map_unwrap_or`, `manual_ok_or`.
- **Fix, don't silence.** Never `#[allow(clippy::…)]`. Use
  `#[expect(clippy::…)]` **with a justifying comment** — `expect` re-warns once the lint
  no longer fires, so dead suppressions can't accumulate. Keep overrides local.

## 5. Testing

- **One behaviour per test**, ideally **one assertion**; a failing test should name
  exactly what broke.
- Name tests like sentences: `process_should_return_error_when_input_empty`, or group
  under `mod process { fn should_… }`. Organise with `#[cfg(test)] mod` submodules.
- For matrices of inputs use `rstest` cases with descriptive `#[case::…]` labels rather
  than many asserts in one `fn`. On `assert!`/`assert_eq!`, pass a formatted message
  showing actual vs expected; `Ok`-path tests should print the `Err` on failure.
  `assert_matches!(x, Pat)` for shape checks (see below); `#[should_panic]` only when
  panic is the contract.
- Three test planes: **unit** (same module, sees privates, edge cases), **integration**
  (`tests/`, public API only, split binaries into `main.rs` + `lib.rs`), **doc-tests**
  (`///` examples that run under `cargo test` — note: not under `cargo nextest`, use
  `cargo test --doc`). Doc-test attributes: `no_run`, `should_panic`, `compile_fail`.
- **Snapshot testing with `cargo insta`** when output is structural/visual (generated
  code, serialised data, rendered HTML, CLI output). Prefer YAML snapshots; name them;
  keep them **small and scoped** (`assert_yaml_snapshot!("app_config/http", cfg.http)`,
  not the whole object); **redact** unstable fields (timestamps, UUIDs); commit
  snapshots and review diffs. Don't snapshot primitives/flat structs — use `assert_eq!`.
- **`assert_matches!` / `debug_assert_matches!`** (`std`, stable since Rust 1.96) over
  `assert!(matches!(x, Pat), "…{x:?}")` — it prints the actual value on failure for
  free, so the hand-written message goes away. `pretty_assertions` swaps in
  `assert_eq!`/`assert_ne!` with coloured diffs for large values. Not in the prelude —
  `use std::assert_matches;` (or `std::assert_matches!(…)`); upstream's
  `std::assert_matches::assert_matches` module path predates stabilisation and no
  longer resolves: `use std::assert_matches; assert_matches!(err, MyError::BadInput(_));`.
- **Pool the setup, not the test body.** Fixtures, `rstest` cases and a `setup()` helper
  are fine; each test's action and assertion stay inline, repetition included. A test
  has no test of its own, so logic moved into a shared helper is unverified, and a
  failure must be readable from the test body alone (§11).
- **Exercise the error path.** Every fallible unit gets a test that reaches `Err`. When
  the error type is not `PartialEq`, assert on `err.to_string()` (or `format!("{err}")`)
  so the message itself is under test; where feasible derive `PartialEq` on error types
  so `assert_eq!(err, MyError::Xyz)` works directly.

## 6. Generics & dispatch — "static where you can, dynamic where you must"

- **Static dispatch** (`<T: Trait>` / `impl Trait`) is the default: monomorphised,
  inlined, zero runtime cost — best for hot loops and call sites you control.
- **Dynamic dispatch** (`Box<dyn Trait>`, `Arc<dyn Trait>`, `&dyn Trait`) only when you
  genuinely need runtime polymorphism: heterogeneous collections, plugin/hot-swap
  architectures, or hiding internals behind a stable interface.
- Ergonomics: `&dyn` when you don't need ownership; `Arc<dyn>` for cross-thread sharing;
  **box at the API boundary, not internally**; don't box prematurely inside structs.
  Trait objects must be **object-safe** (no generic methods, no `Self`-returning, no
  `Self: Sized`). If unsure, start generic and add `dyn` only when flexibility wins.

## 7. Type-state pattern

Encode states as **types**, not runtime flags — illegal operations become compile
errors, and `PhantomData<State>` is zero-cost (erased after compilation).

```rust
struct Disconnected;
struct Connected;

struct Client<State> {
    stream: Option<std::net::TcpStream>,
    _state: std::marker::PhantomData<State>,
}

impl Client<Disconnected> {
    fn connect(addr: &str) -> std::io::Result<Client<Connected>> {
        let stream = std::net::TcpStream::connect(addr)?;
        Ok(Client { stream: Some(stream), _state: std::marker::PhantomData })
    }
}

impl Client<Connected> {
    fn send(&mut self, msg: &[u8]) { /* only a Connected client can send */ }
}
```

**Use it** for compile-time state safety, builder "required fields before `.build()`",
and protocol state machines. **Avoid it** for trivial enum-like states, when it
explodes generic signatures, or when runtime flexibility is the point — "use it when it
saves bugs, not for cleverness."

For builders specifically, the [`bon`](https://docs.rs/bon) crate derives the type-state
plumbing (required-before-`build()`, no double-set) from an attribute, with no
hand-written `PhantomData` markers.

## 8. Comments vs documentation

- `//` explains **why** — safety invariants (`// SAFETY: …`), performance quirks
  (`// PERF: …`), platform workarounds, links to an ADR/design doc. Don't restate the
  *what* (`// increment i`), don't leave walls of text, don't trust stale comments —
  read them in context and fix or delete.
- `///` (item) and `//!` (module/crate) explain **what & how** for public APIs, with
  `# Examples`, `# Errors`, `# Panics`, `# Safety` sections where relevant. Examples
  double as doc-tests.
- Prefer **structure and naming over commentary**: split a function rather than
  narrate its steps. `TODO`s become tracked issues — `// TODO(#42): …`.
- For libraries, enforce coverage with `#![deny(missing_docs)]` and the rustdoc/clippy
  doc lints (`missing_docs`, `missing_errors_doc`, `missing_panics_doc`,
  `missing_safety_doc`, `broken_intra_doc_links`).
- **`#[non_exhaustive]`** on public enums and structs that downstream code may match
  on or construct, so adding a variant or field stays non-breaking. The SemVer rules
  themselves are the Cargo book's *SemVer Compatibility* chapter; in
  `microsoft-rust-guidelines`, M-FEATURES-ADDITIVE
  (`references/09_libraries_building_guidelines.md`) relies on the attribute: a feature
  may add variants only to a `#[non_exhaustive]` enum.
- **Doc-coverage checklist** (`cargo doc --open` to check): crate `//!` says what the
  crate does and what problem it solves, plus a crate-level `# Examples`; module `//!`
  states purpose, exports, and invariants; types — role, invariants, an example
  construction; functions — parameters, return value, `# Errors` / `# Panics`,
  `# Examples`; traits — purpose, when and why to implement each method, which defaults
  to override; public `const`s — what they configure and when to use them.

## 9. Import ordering

Group `use` declarations: `std`/`core`/`alloc` → external crates → workspace crates →
`super::`/`crate::`. In `rustfmt.toml`:

```toml
reorder_imports = true              # stable (and on by default)
imports_granularity = "Crate"       # nightly only
group_imports = "StdExternalCrate"  # nightly only
```

Only `reorder_imports` is stable. `imports_granularity` and `group_imports` are still
unstable as of rustfmt 1.9: stable `rustfmt` warns and ignores them, so a stable
`cargo fmt --check` neither fails nor enforces the grouping; only `cargo +nightly fmt`
applies it. Keep CI on stable `cargo fmt --check`, run the nightly formatter locally if you want the grouping applied, and enforce the
group order by review.

## 10. Smart pointers & thread safety

Rust tracks thread safety via compiler-enforced auto-traits:
- `Send` indicates that ownership of a type can be transferred across thread boundaries.
- `Sync` indicates that references to a type (`&T`) can be shared safely across threads.

### Smart Pointer Comparison

| Pointer Type | Description | Send / Sync | Use Case |
| :--- | :--- | :--- | :--- |
| `&T` | Shared reference | `Send + Sync` (if `T: Sync`) | Immutable shared access. |
| `&mut T` | Exclusive mutable reference | `Send + Sync` (if `T: Send + Sync`) | Exclusive temporary mutation. |
| `Box<T>` | Unique heap-allocated pointer | `Send + Sync` (if `T: Send + Sync`) | Owned indirection / recursive types. |
| `Rc<T>` | Non-atomic reference-counted | **Neither** `Send` nor `Sync` | Shared ownership within a single thread. |
| `Arc<T>` | Atomic reference-counted | `Send + Sync` (if `T: Send + Sync`) | Shared ownership across multiple threads. |
| `Cell<T>` | Interior mutability for `Copy` types | `Send` (if `T: Send`), **not** `Sync` | Zero-overhead single-thread mutability. |
| `RefCell<T>` | Interior mutability (dynamic borrow) | `Send` (if `T: Send`), **not** `Sync` | Single-thread runtime-checked mutation; a conflicting borrow **panics**. |
| `Mutex<T>` | Thread-safe mutual exclusion lock | `Send + Sync` (if `T: Send`) | Shared mutable access across threads. |
| `RwLock<T>` | Thread-safe readers-writer lock | `Send + Sync` (if `T: Send + Sync`) | Read-heavy shared mutable thread access. |

**`RefCell` enforces the borrow rules at runtime, and it panics.** Holding a `borrow()`
guard while taking `borrow_mut()` — or two `borrow_mut()`s — is not a compile error; it
is a panic at the second call. Keep guards short-lived, never hold one across a call
that may re-enter the same cell, prefer `Cell<T>` for `Copy` payloads (no guard, no
panic), and use `try_borrow`/`try_borrow_mut` where a conflict is a legitimate runtime
outcome rather than a bug.

### Lazy Initialization & One-Time Cells

Avoid complex custom setups with `Option` or unsafe blocks for lazy values. Use standard library cells:

- **Single-Threaded (`std::cell`):**
  - `OnceCell<T>`: Write-once container for single-threaded deferred initialization.
  - `LazyCell<T>` (stabilized in Rust 1.80): Lazy value initialized via a closure on first deref.
- **Thread-Safe / Shared (`std::sync`):**
  - `OnceLock<T>` (stabilized in Rust 1.70): Thread-safe `OnceCell` for global/shared resources.
  - `LazyLock<T>` (stabilized in Rust 1.80): Thread-safe `LazyCell` for lazy thread-safe globals.

## 11. Extracting functions

§8 asks for named helpers so a function reads without narration. That is a readability
rule, not a deduplication mandate: each extraction costs an indirection, and a helper
that turned out wrong is harder to delete than the lines it replaced.

- **Rule of Three** (Fowler/Roberts): refactor on the third occurrence, not the
  second — by then the abstraction's shape is known rather than guessed.
- **DRY is about knowledge, not text.** Merge two blocks only when they encode the
  *same decision*. Look-alike blocks that encode different decisions are coincidental
  duplication; merging them chains together code that needs to change independently.
- **The flag-parameter smell.** A `bool`/mode argument needed to unify two helpers
  means two decisions were merged; each later variant adds a branch.

  ```rust
  // ✅ Two formats, two lines — they will change for different reasons.
  writeln!(env_out, "{key}={value}")?;
  writeln!(toml_out, "{key} = \"{value}\"")?;

  // ❌ One helper, a bool to choose; the call site says nothing.
  fn write_pair(out: &mut impl Write, k: &str, v: &str, quoted: bool) -> io::Result<()>
  ```
- **Unwinding a wrong abstraction:** inline the body into each caller, drop the flag
  and the dead branches, let the copies diverge, then see what (if anything) is still
  shared.
- **Extract when:** the name says more than the code (`is_retryable`), the same
  knowledge is used in ≥ 3 places, or the unit needs testing in isolation.
- **Don't extract when:** it needs a flag/mode parameter, the only motive is line
  count, or it hides one decision behind an extra hop.
