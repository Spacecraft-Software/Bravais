---
name: rust-guidelines
description: 
  ALWAYS invoke this skill BEFORE writing or modifying ANY Rust code (.rs files),
  even for simple Hello World programs. Enforces Microsoft Pragmatic Rust Guidelines,
  requires consulting the appropriate guideline files before any coding activity.
  This skill is MANDATORY for all Rust development.
user-invocable: false
license: MIT
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

**Current compliance date: 2026-05-18**

# Rust-Guidelines Skill

**Maintainer (Spacecraft Software adaptation):** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)
*(Base guidelines: Microsoft Pragmatic Rust Guidelines — MIT License)*

This skill enforces structured, guideline-driven Rust development. It ensures all
Rust code strictly follows the Microsoft Pragmatic Rust Guidelines for style,
documentation, safety, performance, and API design.

## Mandatory Workflow

**This skill MUST be invoked for ANY Rust action**, including:

- Creating new `.rs` files (even minimal examples like Hello World)
- Modifying existing `.rs` files (any change, no matter how small)
- Reviewing, refactoring, or rewriting Rust code

## Which Guideline to Read and When

Before writing or modifying Rust code, **load ONLY the guideline files that apply
to the requested task**, using segmented reading (`offset` and `limit`) when needed.

> When in doubt about which guidelines apply, load all candidates —
> loading an extra file is cheaper than missing a relevant rule.

### Guidelines and When They Apply

#### 1. `references/01_ai_guidelines.md`

Use when the Rust code involves:

- AI agents and LLM-driven code generation
- Making APIs easier for AI systems to use
- Comprehensive documentation and detailed examples
- Strong type systems that help AI avoid mistakes

#### 2. `references/02_application_guidelines.md`

Use when working on:

- Application-level error handling with `anyhow` or `eyre`
- CLI tools and desktop applications
- Performance optimization using `mimalloc` allocator
- User-facing features and initialization logic

#### 3. `references/03_documentation.md`

Use when:

- Writing public API documentation and doc comments
- Creating canonical documentation sections (Examples, Errors, Panics, Safety)
- Structuring module-level documentation comprehensively
- Re-exporting items and using `#[doc(inline)]` annotations

#### 4. `references/04_ffi_guidelines.md`

Use when:

- Loading multiple Rust-based dynamic libraries (DLLs)
- Creating FFI boundaries and interoperability layers
- Sharing data between different Rust compilation artifacts
- Dealing with portable vs non-portable data types across DLL boundaries

#### 5. `references/05_library_guidelines.md`

Use when creating or modifying **Rust libraries**, including:

- Structuring a crate
- Designing public APIs
- Dependency decisions

#### 6. `references/06_performance_guidelines.md`

Use when:

- Identifying and profiling hot paths in your code
- Optimizing for throughput and CPU cycle efficiency
- Managing allocation patterns and memory usage
- Implementing yield points in long-running async tasks

#### 7. `references/07_safety_guidelines.md`

Use when:

- Writing `unsafe` code for novel abstractions, performance, or FFI
- Ensuring code soundness and preventing undefined behavior
- Documenting safety requirements and invariants
- Reviewing `unsafe` blocks for correctness with Miri

#### 8. `references/08_universal_guidelines.md`

Use in **ALL Rust tasks**. This file defines:

- General Rust best practices applicable to all code
- Style, naming, and organizational conventions
- Cross-cutting concerns that apply everywhere
- Foundational principles for any Rust project

#### 9. `references/09_libraries_building_guidelines.md`

Use when:

- Creating reusable library crates
- Managing Cargo features and their additivity
- Building native `-sys` crates for C interoperability
- Ensuring libraries work out-of-the-box on all platforms

#### 10. `references/10_libraries_interoperability_guidelines.md`

Use when:

- Exposing public APIs and managing external dependencies
- Designing types for `Send`/`Sync` compatibility
- Avoiding leaking third-party types from public APIs
- Creating escape hatches for native handle interop

#### 11. `references/11_libraries_resilience_guidelines.md`

Use when:

- Avoiding statics and thread-local state in libraries
- Making I/O and system calls mockable for testing
- Preventing glob re-exports and accidental leaks
- Feature-gating test utilities and mocking functionality

#### 12. `references/12_libraries_ux_guidelines.md`

Use when:

- Designing user-friendly library APIs
- Managing error types and error handling patterns
- Creating runtime abstractions and trait-based designs
- Structuring crate organization and public interfaces

## Coding Rules

1. **Load `references/08_universal_guidelines.md` FIRST, for every Rust task without exception.**
2. Then load any additional guideline files relevant to the task (see above).
3. Apply the required rules from the relevant guidelines.
4. Load `references/03_documentation.md` when you need to write documentation.
5. Comments MUST ALWAYS be written in American English, unless the user explicitly
   requests another language (e.g., "write comments in Japanese").
6. If the file is fully compliant, add a comment:
   `// Rust guideline compliant <DATE>` where `<DATE>` is the **Current compliance
   date** shown at the top of this document, formatted as ISO 8601 (`YYYY-MM-DD`).

---

## Spacecraft Software Standard Requirements (Rust)

When writing Rust code for any Spacecraft Software project, these additional rules
from [The Steelbore Standard](../spacecraft-standard/SKILL.md) apply on top of the
Microsoft Pragmatic Rust Guidelines above.

### §4 — SPDX License Header (mandatory)

Every `.rs` source file and Rust manifest (`Cargo.toml`, `build.rs`) must include:

```
// SPDX-License-Identifier: GPL-3.0-or-later
```

Place it as the first non-blank line. Document files (`.md`, `.toml` configs that
are not manifests) are exempt; software source files are not.

### §3.2 — Performance

- Concurrency must be **designed-in from the start**, never bolted on retroactively.
- Release profiles must use `-C target-cpu=native` (or `RUSTFLAGS=-C target-cpu=native`),
  LTO (`lto = true`), and PGO where the toolchain supports it.
- Benchmarking is **mandatory** before and after any optimization work; regressions
  must be documented and justified.

### §3.3 — Security & Dependency Auditing

- Run `cargo audit` before adding any new third-party crate.
- **Post-Quantum Cryptography (PQC) readiness:** crypto subsystems must support
  migration to PQC algorithms. Use hybrid schemes (classical + PQC candidate) where
  library support exists. Current targets: **ML-KEM-768, ML-DSA-65**.

### §12.5 — Time Handling

| Concern | Rule |
|---------|------|
| Crate choice | Use `jiff` (preferred) or `chrono` — never `time` 0.1.x |
| UTC type | `jiff::Timestamp` or `chrono::DateTime<chrono::Utc>` for all stored values |
| Local type | `chrono::Local` and `jiff::Zoned` (with non-UTC zone) are **forbidden** in serialized output |
| Serialization | Always serialize as `"2026-03-08T14:30:00Z"` (ISO 8601, `Z` suffix) |
| `serde` | Use `#[serde(with = "...")]` or a newtype that enforces UTC on deserialization |
| `SystemTime` | Acceptable for internal durations; convert to UTC ISO 8601 string before any output |
| No `NaiveDateTime` | `chrono::NaiveDateTime` has no timezone — forbidden in any serialized or logged value |

---

## Directory Structure
```
rust-guidelines/
├── SKILL.md
└── references/
    ├── 01_ai_guidelines.md
    ├── 02_application_guidelines.md
    ├── 03_documentation.md
    ├── 04_ffi_guidelines.md
    ├── 05_library_guidelines.md
    ├── 06_performance_guidelines.md
    ├── 07_safety_guidelines.md
    ├── 08_universal_guidelines.md
    ├── 09_libraries_building_guidelines.md
    ├── 10_libraries_interoperability_guidelines.md
    ├── 11_libraries_resilience_guidelines.md
    └── 12_libraries_ux_guidelines.md
```
