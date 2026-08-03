<!--
SPDX-FileCopyrightText: 2024 Apollo Graph, Inc.
SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
SPDX-License-Identifier: GPL-3.0-or-later
-->

# Steelbore Rust Idiom Layer

> **Provenance:** Distilled and adapted from Apollo GraphQL's *Rust Best Practices*
> skill (MIT, © 2024 Apollo Graph, Inc.). See [`../CREDITS.md`](../CREDITS.md) and
> [`ATTRIBUTION.md`](ATTRIBUTION.md). This is the **idiom/readability plane** — it sits
> *under* the concurrency/performance doctrine in `SKILL.md`, not against it. Error
> handling is intentionally **not** covered here (the SKILL.md "Error Handling &
> Resilience" section and `microsoft-rust-guidelines` own that plane).

Load this when the question is about **how Rust reads** — borrowing, idiomatic
control flow, lint discipline, testing, dispatch choice, type-state, and docs.
For *how fast it runs* and *how it scales across cores*, stay in `SKILL.md`.

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
  copies invite stack overflow; box or slice them.

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

## 4. Clippy discipline (the surgical layer)

The **canonical CI policy** is set in `SKILL.md` ("Tooling & Quality Gates":
`clippy` warnings-as-errors). This section is the per-lint detail under that policy —
not a competing policy.

- Daily / CI invocation:
  `cargo clippy --all-targets --all-features --locked -- -D warnings`
  (add `-W clippy::pedantic` where you can stand the false-positive rate).
- Encode levels in `Cargo.toml` `[lints.clippy]` / `[workspace.lints.clippy]` with
  explicit `priority` so conflicting lints resolve deterministically.
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
  `assert!(matches!(x, Pat))` for shape checks; `#[should_panic]` only when panic is
  the contract.
- Three test planes: **unit** (same module, sees privates, edge cases), **integration**
  (`tests/`, public API only, split binaries into `main.rs` + `lib.rs`), **doc-tests**
  (`///` examples that run under `cargo test` — note: not under `cargo nextest`, use
  `cargo test --doc`). Doc-test attributes: `no_run`, `should_panic`, `compile_fail`.
- **Snapshot testing with `cargo insta`** when output is structural/visual (generated
  code, serialised data, rendered HTML, CLI output). Prefer YAML snapshots; name them;
  keep them **small and scoped** (`assert_yaml_snapshot!("app_config/http", cfg.http)`,
  not the whole object); **redact** unstable fields (timestamps, UUIDs); commit
  snapshots and review diffs. Don't snapshot primitives/flat structs — use `assert_eq!`.

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

## 9. Import ordering

Group `use` declarations: `std`/`core`/`alloc` → external crates → workspace crates →
`super::`/`crate::`. Automate it in `rustfmt.toml`:

```toml
reorder_imports = true
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
```

(`group_imports` currently needs `cargo +nightly fmt`.)

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
| `RefCell<T>` | Interior mutability (dynamic borrow) | `Send` (if `T: Send`), **not** `Sync` | Single-thread runtime-checked mutation. |
| `Mutex<T>` | Thread-safe mutual exclusion lock | `Send + Sync` (if `T: Send`) | Shared mutable access across threads. |
| `RwLock<T>` | Thread-safe readers-writer lock | `Send + Sync` (if `T: Send + Sync`) | Read-heavy shared mutable thread access. |

### Lazy Initialization & One-Time Cells

Avoid complex custom setups with `Option` or unsafe blocks for lazy values. Use standard library cells:

- **Single-Threaded (`std::cell`):**
  - `OnceCell<T>`: Write-once container for single-threaded deferred initialization.
  - `LazyCell<T>` (stabilized in Rust 1.80): Lazy value initialized via a closure on first deref.
- **Thread-Safe / Shared (`std::sync`):**
  - `OnceLock<T>` (stabilized in Rust 1.70): Thread-safe `OnceCell` for global/shared resources.
  - `LazyLock<T>` (stabilized in Rust 1.80): Thread-safe `LazyCell` for lazy thread-safe globals.
