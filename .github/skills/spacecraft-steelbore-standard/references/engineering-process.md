<!--
SPDX-License-Identifier: GPL-3.0-or-later
Copyright (C) 2026 Mohamed Hammad & Spacecraft Software
-->

# §19–§26 — Assurance, Requirements, V&V and Operations (full text)

Split out of `SKILL.md` for on-demand loading; this is the normative
§19–§26 text, unaltered. Load it when doing assurance, requirements,
verification, interface-control, baseline, or operations work — the skill
body carries the entry points and defers here for the detail.

---

## §19 — Assurance Categories, Tailoring & Conformance

§3 fixes the priority order for every artifact; it does not say how much
*evidence* a given artifact owes. A bootloader that leaves a machine unbootable
and a colour-palette skill that renders a swatch wrong were, until v2.00,
governed identically. Uniform obligation on unequal consequence produces one of
two failures: the small artifact carries ceremony it does not need, or the
critical one carries no more assurance than the small one. **This chapter grades
the obligation, and is what makes §20–§26 affordable.**

> **Provenance.** §19–§26 are informed by ISO/IEC/IEEE 29148:2018 (requirements
> engineering) and ECSS-E-ST-40C (ESA/ECSS space software engineering), credited
> per §15.3. No text from either is reproduced — the categories, thresholds,
> gate structure, and wording are Spacecraft Software's own. Where those sources
> assume a customer/supplier contract with a review board, this standard
> substitutes what a single maintainer can actually execute.

### §19.1 — The Four Assurance Categories

Category is assigned by **consequence of failure** — never by effort, line
count, or how interesting the project is.

| Category | Failure consequence and typical projects |
|----------|------------------------------------------|
| **A — Critical** | Failure destroys or corrupts data irrecoverably, prevents a machine from booting, or breaches a security or privacy boundary. Bootloaders, declarative system managers, credential stores, SSH and cryptographic transports, package installation paths. |
| **B — Significant** | Failure loses unsaved work, corrupts a user artifact recoverably, or silently produces a wrong answer the user relies on. Editors, package managers, conversion and tracing engines, and any tool whose output is consumed without inspection. |
| **C — Standard** | Failure is visible, contained, and recoverable by re-running the tool. Most CLIs, inspectors, and reporters. |
| **D — Incidental** | Failure has no consequence beyond the session. Skills, themes, documentation tooling, scratch utilities, and projects registered as games (§18.5). |

**Silent wrongness raises the category.** A tool whose wrong answer looks
exactly like a right answer is Category B at minimum, whatever its size — a
prayer-time calculator, a checksum reporter, a specification extractor. Nothing
downstream can detect the error.

**One category per project, raised per subsystem.** A project declares one
category. A subsystem MAY be raised above it — a Category C application shipping
a credential-handling module treats that module as Category A — and MUST NOT be
lowered below it. The raise is recorded with the declaration.

### §19.2 — Declaring and Changing a Category

| Rule | Detail |
|------|--------|
| Where declared | The `README.md` posture section (§5.2), `AGENTS.md` (§5.7), and `PROJECTS.md`. All three carry the same value; the registry is authoritative in a conflict |
| Declared before code | Declared at project creation, before G1 (§19.4). An undeclared project is treated as Category C for audit purposes, and the missing declaration is itself a finding |
| Raising is free | MAY be raised at any time by the maintainer, effective immediately |
| Lowering is gated | MAY be lowered only with a dated justification in the tailoring register (§19.5) naming what changed about the consequence of failure. Shipping pressure is not such a change |
| Scope changes force review | Adding a network listener, a credential path, a privileged operation, or a destructive default requires the category to be re-evaluated **in the same change** |

### §19.3 — What Each Category Owes

The chapters that follow are written once and applied by category. This table is
the index; each chapter restates its own row normatively.

| Obligation | A | B | C | D |
|------------|---|---|---|---|
| §20 Requirements specification | Texinfo SRS | Texinfo SRS | List in `AGENTS.md` | None |
| §21 Traceability matrix in CI | Required | Required | Recommended | None |
| §21 Verification evidence | Test + analysis + formal or exhaustive fuzzing | Test + analysis | Test | Smoke test |
| §22 Budgets & margins | Required | Required | Recommended | None |
| §23 Interface control document | Required | Required for public interfaces | Recommended | None |
| §24 Dependency qualification | Every direct dependency | Trust-path dependencies | Audit tooling only | Audit tooling only |
| §24 SBOM per release | Required | Required | Required | Recommended |
| §25 Baselines & anomalies | Full | Full | Release baseline only | None |
| §26 `SECURITY.md` & support window | Required | Required | Required | Required |

Every *Recommended* obligation that is **not** implemented is recorded in the
tailoring register (§19.5). *None* needs no record.

### §19.4 — The Three Gates

ECSS separates a project into staged reviews with defined entry evidence. That
structure is sound; the staffing behind it is not available here, so it is
compressed to three gates, each a **checklist a maintainer runs alone**, not a
meeting.

| Gate | Evidence required to pass |
|------|---------------------------|
| **G1 — Requirements** | The requirement set passes the §20.4 characteristics gate; every requirement carries an ID, a rationale, and a declared verification method (§21.1); the assurance category is declared (§19.2). **Exit:** the requirement set is baselined (§25.1) |
| **G2 — Design** | Architecture recorded; concurrency decisions and trade-offs documented (§3.2); resource budgets declared with initial margins (§22); interfaces identified and ICD drafted (§23); dependencies qualified (§24). **Exit:** the design and budget baseline |
| **G3 — Release** | Traceability matrix complete with no orphans (§21.3); budget margins measured and within threshold (§22.3); no open anomaly above the category's blocking severity (§25.2); release manifest assembled (§25.3); §16 checklist run. **Exit:** the release baseline and a signed tag (§6.3) |

Gates are **per release, not per project lifetime**: a project shipping
quarterly passes G1–G3 quarterly, and a change adding no requirements re-enters
at G2.

### §19.5 — Recorded Tailoring

§16 permits marking a check *N/A* in the moment of the audit, which leaves no
record and cannot be reviewed later. Tailoring is instead **written down once
and read every time**.

| Rule | Detail |
|------|--------|
| Where it lives | Category A and B ship `COMPLIANCE.md` at the repository root. Category C and D MAY instead carry the register as a "Compliance" section of `README.md` |
| What it records | One row per tailored clause: the clause, the status (`applied` / `tailored` / `not-applicable`), a one-line justification, and an ISO 8601 date (§14) |
| Silence means applied | A clause absent from the register is applied in full. The register never lists what is merely being followed |
| Not a waiver mechanism | Tailoring adjusts *how* a clause is satisfied, or records that its subject does not exist here. It **never** sets aside §3's priority order, §4 licensing, §6.3 signing, or §6.4 contribution targets |
| Reviewed at G3 | Every entry is re-read at the release gate. An entry whose justification has expired is removed and the clause applied |

### §19.6 — Claiming Conformance

A project claims conformance in `README.md`, in one line, naming the standard
version, the category, and whether the claim is full or tailored:

```
Conforms to The Steelbore Standard v2.02 — Category B, tailored
(§22, §23; see COMPLIANCE.md).
```

**Full conformance** means every applicable clause is applied and the register
is empty. **Tailored conformance** means the register is non-empty and current.
A claim naming an older standard version is honest and permitted; an absent
claim is not a conformance failure, but an inaccurate one is.

---

## §20 — Requirements Engineering

Code cannot be verified against an intention that was never written down. §17
assumes a PRD or plan exists and tracks progress against it, but the standard
never said what such a document contains, how a requirement is worded, or how
one is identified. Scaled by category (§19.3): a Category D skill owes nothing,
a Category A bootloader owes a specification.

### §20.1 — What Is Written, and Where

Two items, distinguished by whose question they answer. Keeping them apart is
what makes validation (§21.5) possible: needs are what the software is *for*,
requirements are what it *does*.

| Item | Content and location |
|------|----------------------|
| **Needs** | Why the software exists, who uses it, the operating environment, and the constraints the maintainer will not trade away. Written by the maintainer as user. **Two paragraphs is a legitimate length.** Lives in `doc/<project>.texi` under a `Needs` node, or `README.md` for Category C |
| **Requirements (SRS)** | What the software shall do, in individually verifiable statements, each traceable to a need. Written by the maintainer as implementer. Lives in `doc/<project>.texi` under a `Requirements` node |

Requirements are authored in **Texinfo (§8)**, not a parallel Markdown or office
file: they then build to `.info`, `.html`, and `.pdf` with the rest of the
manual, ship in the packages, and cannot drift from the documentation the user
reads. Category C MAY keep the list in `AGENTS.md` instead, where the agent
implementing against it will actually load it.

**Requirements are not the plan.** `TODO`, `PLAN`, and the §17 milestone rows
sequence the work; the requirement set states the obligation. A requirement is
not deleted because it slipped a milestone.

### §20.2 — Verbal Forms

Normative weight is carried by the verb, and one verb has exactly one meaning
throughout this standard, every project specification, and every requirement:

| Form | Meaning |
|------|---------|
| `shall` | A binding requirement. Verifiable, and its violation is a defect |
| `shall not` | A binding prohibition |
| `should` | A recommendation. Departure is permitted and is recorded in the tailoring register (§19.5) |
| `may` | Permission. Neither obligation nor recommendation |
| `will` | A statement of fact or intent about something outside the specification's control (the platform, the toolchain, a future release). **Never a requirement** |

**`must` is retired from normative text.** It reads as obligation but carries no
agreed weight, and this standard has used `must`, `MUST`, and `shall`
interchangeably. New and revised normative text uses the forms above; existing
occurrences migrate as their sections are next revised, and until then `must`
and `MUST` are read as `shall`. Capitalisation is not significant — `shall` and
`SHALL` are the same obligation.

### §20.3 — Identifiers and Attributes

**Identifier:** `<PREFIX>-<TYPE>-<NNN>`, where `<PREFIX>` is the project's short
code as registered in `PROJECTS.md`, `<TYPE>` is `NEED` or `SRS`, and `<NNN>` is
a zero-padded serial — `ZMK-SRS-014`.

Identifiers are **permanent and never reused.** A withdrawn requirement keeps
its identifier and is marked withdrawn; reissuing `ZMK-SRS-014` for a different
obligation silently invalidates every trace, commit message, and test that cited
it.

**Attributes.** A requirement missing any of these does not pass G1:

| Attribute | Content |
|-----------|---------|
| Rationale | Why this is required. One sentence. A requirement whose rationale cannot be written is a design decision in disguise, and belongs in the design record |
| Source | The need it satisfies, an upstream standard, a platform constraint, or a clause of this standard |
| Priority | `mandatory` / `expected` / `optional`. Drives what MVP means in §17 |
| Verification method | One of the four §21.1 methods, chosen **when the requirement is written** — not after the code exists and the cheapest evidence is obvious |
| Status | `draft` / `baselined` / `implemented` / `verified` / `withdrawn`. **The denominator of the §17 progress figures** |

### §20.4 — The Characteristics Gate

Run at G1, against each requirement and then against the set.

| Each requirement is | Meaning |
|---------------------|---------|
| **Necessary** | Removing it leaves a real gap. If nothing breaks when deleted, it documented an implementation choice |
| **Appropriate** | Pitched at this project's level — constrains what the software does, not how a function is written |
| **Unambiguous** | Admits one reading. If two readings survive, two people implement two things |
| **Complete** | Stands alone: no to-be-decided, no trailing `etc.`, no appeal to context living only in the maintainer's head |
| **Singular** | States one obligation. Two obligations joined by `and` are two requirements — separately met, separately failed |
| **Feasible** | Achievable within platform, toolchain, budgets (§22), and the maintainer's actual time |
| **Verifiable** | A declared method (§21.1) can produce a pass or a fail. If none can, it is unmeasurable prose |
| **Correct** | An accurate statement of the need it traces to |
| **Conforming** | Uses the §20.2 verbal forms and the §20.6 pattern |

| The set is | Meaning |
|------------|---------|
| **Complete** | Covers every stated need — including error, degraded, and shutdown behaviour, which is where hobby specifications habitually stop |
| **Consistent** | No requirement contradicts another, and one term means one thing throughout |
| **Feasible** | Satisfiable *together*, not merely one at a time — the §3 priority order is the tie-break |
| **Comprehensible** | Readable in order by someone who was not in the room: the maintainer in a year, and every coding agent that loads it |
| **Able to be validated** | Every need has at least one requirement tracing to it |

### §20.5 — Wording Rules

- **No unmeasurable adjectives** — `fast`, `robust`, `efficient`,
  `user-friendly`, `secure`, `modern`, `seamless`. Replace each with a figure
  and a method: not "startup shall be fast" but "cold start shall complete
  within 50 ms on the reference machine, measured per §22.4".
- **No open-ended clauses** — `etc.`, `and so on`, `as appropriate`,
  `including but not limited to`. Each hides an unbounded obligation nobody can
  verify.
- **No escape hatches** — `where possible`, `if practical`, `as far as
  reasonable`. Either the obligation binds (`shall`) or it is a recommendation
  (`should`).
- **No comparatives without a baseline** — `faster`, `smaller`, `better`
  require a named reference point and a measurement.
- **No implementation in a requirement** — name the observable behaviour, not
  the crate, data structure, or algorithm. Those belong to the design record and
  change without the obligation changing.
- **Active voice, named subject** — "The system shall reject", not "the input
  shall be rejected", which leaves nobody responsible.
- **Positive statement where possible** — a prohibition is verifiable only if
  the prohibited condition is observable.
- **No rationale inside the requirement** — the rationale is an attribute
  (§20.3). Prose reasoning inside a requirement sentence becomes accidentally
  binding.

### §20.6 — The House Sentence Pattern

One pattern, so requirements can be read and diffed quickly:

```
[<condition>,] the <subject> shall <action> <object> [<constraint>].
```

| Shape | Example |
|-------|---------|
| **Plain** | `The resolver shall report the resolved theme and the deciding source under --verbose.` |
| **Conditional** | `When NO_COLOR is set in the environment, the resolver shall select the steelbore-mono variant.` |
| **Constrained** | `The tracer shall convert a 4000 x 4000 pixel raster within 2 s on the reference machine.` |
| **Prohibition** | `The application shall not write to a path outside the directories named in §9.` |

---

## §21 — Verification, Validation & Traceability

§3.1 requires stability to be verified. That is one method of four, and says
nothing about what evidence is enough, or about the link between a requirement
and the test that discharges it. This chapter separates **verification** (was it
built right) from **validation** (was the right thing built), names the
admissible methods, and makes the requirement↔evidence link machine-checkable.

### §21.1 — The Four Admissible Methods

Every requirement declares exactly one primary method at G1 (§20.3). Naming the
method up front prevents the familiar retrofit in which whatever evidence
happened to be cheap is declared sufficient.

| Method | What it is, and when it is right |
|--------|----------------------------------|
| **Test** | Executing the software against defined inputs and comparing to expected results. The default for behavioural requirements |
| **Analysis** | Reasoning over the artifact rather than running it: static analysis, model checking, proof, worst-case bounds, exhaustive enumeration of a small state space. The right method for **concurrency invariants and resource bounds**, which tests sample but do not establish |
| **Inspection** | Direct examination for a property visible without execution: an SPDX header (§4.3), a compiler flag (§3.2.1), a file's line endings (§6.5), the presence of a required file |
| **Review of design** | Structured reading of the design against the requirement, for properties existing only at design level — privilege separation, failure containment, absence of a global lock on a hot path |

A requirement may cite a secondary method as supporting evidence. It may **not**
cite "manual check" as a method: manual checking is inspection, recorded as
such, with what was inspected and when.

### §21.2 — Evidence by Category

Coverage figures are a **floor for the paths that matter, not a target to farm**.
Percentages are line coverage of the crate's own code, excluding generated and
vendored sources.

| Category | Minimum evidence at G3 |
|----------|------------------------|
| **A — Critical** | Everything required of B, plus formal verification (Kani, Creusot, or SPARK for an Ada component) **or** exhaustive fuzzing of every parser and trust boundary; property-based tests over stated invariants; a documented worst-case bound for every unbounded loop and every allocation on a critical path; zero `unsafe` without a written safety argument at each site |
| **B — Significant** | Unit and integration tests with **≥ 80% line coverage**; fuzzing of every input parser; a mutation-testing run (`cargo-mutants`) whose surviving mutants are triaged and either killed or justified; every anomaly closed by a regression test (§25.2) |
| **C — Standard** | Unit tests over the public surface, integration coverage of the primary CLI paths, and a CI run that gates merge |
| **D — Incidental** | A smoke test proving the artifact loads, parses, or renders |

**Coverage is not evidence of verification.** It shows which lines ran, not which
requirements were discharged — the traceability matrix shows that. Mutation
score is the honest companion figure for A and B, since it measures whether the
tests would notice a defect at all.

### §21.3 — Traceability

Traceability shall be **bidirectional** and **mechanically generated**: forward
from each requirement to the design element, code, and evidence that discharges
it; backward from each test to the requirement it exists for. *A matrix
maintained by hand is a matrix that is accurate on the day it is written.*

**Markers.** Requirements are cited in source by identifier, in a form the
language's own tooling preserves:

```rust
/// Resolve the active theme from the §11.6 precedence chain.
///
/// Verifies: SBT-SRS-031, SBT-SRS-032
pub fn resolve_theme(env: &Env) -> Theme { /* ... */ }

#[test]
fn mono_variant_wins_when_no_color_set() {
    // Verifies: SBT-SRS-032
}
```

**Generation and gate.** A project script — Nushell is the house shell (§7) and
its structured output suits this directly — collects the markers, joins them
against the requirement set, and emits the matrix as a build artifact:

```nushell
# tools/trace.nu — emit the traceability matrix, fail on orphans
def main [] {
  let reqs = (open doc/requirements.toml | get requirement)
  let marks = (
    rg --json '(?:Verifies|Implements): ([A-Z]+-SRS-[0-9]+)' src tests
    | lines | each { |l| $l | from json } | where type == "match"
  )
  let covered = ($marks | get data.submatches.0.match.text | uniq)
  let orphan_reqs = ($reqs | where id not-in $covered | get id)
  let unknown_ids = ($covered | where $it not-in ($reqs | get id))

  if ($orphan_reqs | is-not-empty) or ($unknown_ids | is-not-empty) {
    print $"unverified: ($orphan_reqs)  unknown: ($unknown_ids)"
    exit 1
  }
}
```

| Rule | Detail |
|------|--------|
| Generated, never hand-maintained | Produced by tooling from the source and the requirement set, on every CI run |
| Orphans block release | A baselined requirement with no evidence marker, or a marker citing an identifier absent from the requirement set, **fails CI**. These are the two failure modes traceability exists to catch: work specified and never done, and evidence citing a requirement that was withdrawn or mistyped |
| Shipped as an artifact | The matrix accompanies the release (§25.3), so the verification state at that version is recoverable later without rebuilding |
| Feeds §17 | The verified fraction of the baselined requirement set is the denominator-backed figure behind the §17.1 progress bars |

### §21.4 — Independence Without a Second Engineer

Space software practice requires verification performed independently of the
people who wrote the code, in proportion to criticality. A single maintainer
cannot staff that, and pretending otherwise would make the clause decorative.
Independence is therefore obtained from a **different mechanism, not a different
person**, for Category A and B:

- **A different tool decides** — formal verification, a model checker, or a
  sanitizer run reaches its verdict without sharing the author's assumptions.
- **A different implementation decides** — differential testing against a
  reference implementation, an oracle, or the tool being replaced. Particularly
  available to Ironway, Caliper, and any rewrite, where the original *is* the
  oracle.
- **Generated inputs decide** — property-based tests and fuzzing explore the
  input space the author did not think of, which is the specific failure
  independent review is meant to catch.
- **A different reader decides** — a review pass by a coding agent that has not
  seen the implementation session, prompted from the requirement text alone, is
  a legitimate inspection, recorded with what was reviewed and when.

Mutation testing is the meta-check on all of the above: it measures whether the
verification would have noticed.

### §21.5 — Validation Against Needs

Verification asks whether the software meets its requirements. **Validation asks
whether the requirements were the right ones**, and is answered against the needs
(§20.1), by using the software as the user for whom it was written — which,
under §5.1, is usually the maintainer.

| Rule | Detail |
|------|--------|
| Against needs, not requirements | Each stated need is exercised end to end. A need with no requirement tracing to it is a §20.4 set-completeness failure found late |
| In the real environment | Performed at G3 against the release candidate on the target platform, **installed from the §5.5 packaging** — not from the development tree with the developer's configuration |
| Recorded | A short validation note in the release manifest (§25.3): what was exercised, on what, and what was found |
| Failure is a requirements defect | Software that passes verification and fails validation has **correct code and wrong requirements**. The fix begins in the requirement set, not the source |

---

## §22 — Resource Budgets & Margins

§3.2 requires benchmarking before and after optimization work. A before/after
delta detects a regression against the previous build; it cannot detect a build
that has been slowly getting worse for a year, and it never answers whether the
current figure is *acceptable*. A budget supplies the absolute line; a margin
says how much room is left before it is crossed.

### §22.1 — What Is Budgeted

At G2, a Category A or B project declares a ceiling for each applicable
resource. Category C should declare at least the first two.

| Resource | Definition |
|----------|------------|
| Binary size | Size of the stripped release artifact as shipped by §5.5 packaging |
| Cold-start latency | Time from process start to first useful output or interactive prompt, measured on a warm page cache |
| Peak resident memory | Maximum RSS over the declared reference workload |
| Throughput or frame time | The project's primary work rate: pixels, packets, frames, or requests per second |
| Startup allocations | Allocation count before first output, for Category A — an allocation on a path that must not fail *is* a failure mode |
| Hard platform limits | Where the target imposes one — a boot sector, a flash partition, a stack size — the limit is the ceiling and is **not negotiable**. Zamak is the standing example |

### §22.2 — Declaration and Re-Baselining

- Budgets are declared in the requirement set (§20.1) as ordinary requirements
  with figures, so they are verified and traced like any other.
- A budget is declared **before** the code that consumes it, at G2. *A ceiling
  set after measurement is a description, not a budget.*
- A ceiling MAY be re-baselined, with a dated entry recording the old ceiling,
  the new one, and what changed to justify it — a new feature, a platform
  change, a deliberate trade. **Re-baselining to accommodate an unexplained
  regression is prohibited: find the regression first.**
- Every budget names the reference machine and the reference workload (§22.4). A
  figure without both is not reproducible and cannot be compared across releases.

### §22.3 — Margin Thresholds

Margin is the headroom remaining: `(ceiling - measured) / ceiling`.

| Band | Consequence |
|------|-------------|
| **Green — above 25%** | Normal. Reported, no action |
| **Amber — 10% to 25%** | Recorded in the release manifest with a one-line note: the next feature will cross the ceiling, and that is now visible rather than discovered at the crossing |
| **Red — below 10%** | **Blocks the release gate for Category A and B.** Clear it by reducing consumption or re-baselining under §22.2 — never by suppressing the measurement |
| **Exceeded — negative** | A defect, filed as an anomaly (§25.2) at the severity the resource warrants. For a hard platform limit it is always S1 |

**Margins are reported, not just measured.** Where a project reports progress
under §17, the margin band accompanies it, so erosion is visible in the same
block as completion:

```
BUDGET: binary 3.4 MiB / 4.0 MiB (15% margin, amber)
```

### §22.4 — The Reference Machine and Workload

| Element | Requirement |
|---------|-------------|
| Reference machine | Named in the requirement set: CPU model, core count, memory, storage class, and OS. Where CI is the reference, the runner class is named and pinned |
| Reference workload | A fixed, committed input — a specific raster for Caliper, a specific save for Ironway, a specific configuration for Pearlite — versioned with the project so a figure from one release is comparable with the next |
| Automated | Measurement runs in CI on every release build. *A budget checked by hand is a budget checked once* |
| Tools | `criterion` for throughput, `hyperfine` for wall-clock start, `cargo bloat` and the stripped artifact size for binary budgets, `/usr/bin/time -v` or an in-process allocator hook for peak RSS |
| Noise discipline | Report the median and the spread, not a single run, and treat a change inside the spread as no change |

---

## §23 — Interface Control

Everything this standard said about compatibility before v2.00 was implicit:
§5.3 asks general-use projects for semantic versioning, and semantic versioning
is a promise about an interface nobody has written down. **An interface that was
never enumerated cannot be versioned, deprecated, or kept** — it is discovered by
the consumer at the moment it breaks.

### §23.1 — The Interface Inventory

Every project maintains an inventory of the interfaces it exposes. It is short
and it is exhaustive; an interface omitted from it is an interface that will be
broken by accident.

| Interface class | What is controlled |
|-----------------|--------------------|
| Library API | Public items of a crate or shared library: types, functions, traits, public fields, and the error types they return |
| Command-line surface | Subcommand and option names, argument order, exit codes, and the shape of `--json` / `--format` output |
| Machine-readable output | Any output another program parses. Carries a schema and a schema version, and the schema is committed |
| On-disk and configuration formats | Formats the project reads or writes, including `/etc/steelbore/theme.toml` (§11.6.4), state files, caches with a stable location, and save formats |
| Wire and IPC protocols | Sockets, pipes, message formats, and their framing |
| Environment variables | Names the project reads or sets — `SPACECRAFT_THEME`, `NO_COLOR`, `SPACECRAFT_A11Y`. *Reading a variable is a contract with whoever sets it* |
| Filesystem layout | Paths the project creates, requires, or documents, and the XDG bases it resolves them against (§9) |

### §23.2 — The Interface Control Document

Category A and B ship an ICD; Category C should. It lives as an
`@node Interfaces` chapter of `doc/<project>.texi` (§8) rather than a separate
file, so it builds and ships with the manual.

| The ICD records | Detail |
|-----------------|--------|
| Identity and version | Each interface has a name and its own version, which need not track the project version. An interface version changes only when the interface does |
| Contract | Names, types, ranges, units (§14 metric), encodings (§6.5 UTF-8), and required ordering |
| Error behaviour | What the interface does with invalid input, and what the consumer may rely on: exit codes, error types, partial-write guarantees |
| Stability class | `stable` / `unstable` / `internal`, documented at the point of use. **An interface with no declared class is stable by default** — the safe assumption for the consumer, the expensive one for the maintainer |
| Machine-readable schema | Where the interface is data — JSON output, TOML configuration, a wire message — a schema is committed alongside the prose and is what the tests validate against |
| Consumers | Known first-party consumers, so the blast radius of a change is visible before the change |

### §23.3 — Changing an Interface

| Rule | Detail |
|------|--------|
| Additive changes are minor | A new subcommand, a new optional field, a new variant behind an exhaustive-match guard |
| Breaking changes are major | Removing or renaming an element, tightening accepted input, **changing a default**, changing an exit code, or changing the meaning of an existing field. Changing a default is the one most often mistaken for a minor change |
| Deprecate before removing | A stable element is marked deprecated for **at least one minor release** before removal, warns once per invocation at run time, and names its replacement (§26.3) |
| Frozen at G3 | The ICD is baselined at the release gate (§25.1). An interface change after the freeze re-enters at G2 |
| Recorded in `CHANGELOG.md` | Every interface change appears under the version that made it, in the consumer's terms rather than the implementation's |

---

## §24 — Reuse & Third-Party Qualification

§4.2 and §4.3 settle the *legal* question about code this organization did not
write: preserve the notices, ship the licence, tag the file. They say nothing
about the *engineering* question — whether the dependency is fit to be trusted
with the stability, performance, and security priorities of §3. **A crate that
is perfectly licensed and unmaintained is compliant today and a Priority 1
defect next year.**

### §24.1 — The Qualification Record

Recorded in `DEPENDENCIES.md` at the repository root, or as a
`@node Dependencies` chapter of the manual. Category A records **every** direct
dependency; Category B records those in the **trust path** — anything parsing
untrusted input, handling credentials, touching the filesystem with privilege,
or on a critical path; Category C and D rely on the §24.2 tooling alone.

| Field | Content |
|-------|---------|
| Purpose | What it does for this project, in one line, and what would have to be written by hand without it |
| Provenance | Upstream repository, maintainer or organization, and the licence as recorded under §4.2 |
| Maintenance | Last release date, release cadence, open-issue posture, and whether the project is archived or has a stated successor |
| Security history | Past advisories (RUSTSEC or equivalent), and how upstream handled them |
| Unsafe posture | Volume and location of `unsafe` (`cargo geiger`), and whether the dependency's soundness is load-bearing for ours |
| Transitive weight | Count of transitive dependencies pulled in, and any duplicate versions introduced (`cargo tree --duplicates`) |
| Alternatives considered | What else was available, and why this one |
| Exit plan | What happens if it is abandoned: vendor it under §4.2, replace it, or absorb the functionality. **Written before adoption, when the answer is cheap** |

### §24.2 — Adopting a Dependency

| Rule | Detail |
|------|--------|
| Audit before adoption | `cargo audit` and `cargo deny` (licence, advisory, source, and duplicate policy) run **before** the dependency enters the lockfile, and in CI thereafter — extending §3.3 from a one-time check to a standing gate |
| Pinned and locked | The lockfile is committed and the toolchain pinned (`rust-toolchain.toml`, `flake.lock`) so a build is reproducible from the baseline (§25.1) |
| Vendoring is first-class | Where upstream is unmaintained or the patch is small, carrying it in-tree under §4.2 is **preferred** to depending on a repository nobody is watching — and to the §6.4 outbound submission that upstreaming would require |
| Unqualified software in Category A | Software that cannot be qualified — unavailable source, no licence, unauditable, unbuildable from source — **shall not** appear in a Category A path, and shall not enter a Category B path without a tailoring-register entry (§19.5) |
| Re-qualified at G3 | The record is re-read at each release gate. A dependency that has gone quiet since the last release is a finding, not a footnote |

### §24.3 — Software Bill of Materials

Every release of a Category A, B, or C project ships an SBOM.

- **Format:** CycloneDX or SPDX, generated by tooling (`cargo cyclonedx`,
  `cargo sbom`) — never assembled by hand.
- Generated from the **same locked inputs** as the release artifacts, in the same
  CI run, so the two cannot disagree.
- Shipped as a release asset with a SHA-256 checksum, listed in the release
  manifest (§25.3), and covered by §5.5 packaging where the format permits.
- An advisory published under §26.2 **cites the affected releases by SBOM**, so
  consumers can answer whether they are affected without reading a diff.

---

## §25 — Baselines, Anomalies & Release Acceptance

A release was previously defined in this standard by what *accompanies* it —
three package definitions (§5.5), signed commits (§6.3), a manual (§8). This
chapter defines what a release **is**: a frozen configuration, a known defect
state, and an assembled manifest a future maintainer can reconstruct.

### §25.1 — Baselines

A baseline is a named, frozen set of artifacts taken at a gate (§19.4). It is
what "the same build" means six months later.

| A baseline freezes | Detail |
|--------------------|--------|
| Source | The commit identifier, signed per §6.3 and tagged at the release baseline |
| Dependencies | The committed lockfile and the SBOM generated from it (§24.3) |
| Toolchain and environment | Toolchain pins (`rust-toolchain.toml`), the flake or channel revision (`flake.lock`), and the build flags applied and disabled per §3.2.1 |
| Requirements | The requirement set at its baselined status (§20.3), and the traceability matrix generated against it (§21.3) |
| Budgets | Declared ceilings and measured margins (§22) |
| Interfaces | The ICD and its committed schemas (§23.2) |

**Three baselines exist per release**, one per gate: requirements (G1), design
and budgets (G2), release (G3). Nothing is re-cut silently — changing a
baselined artifact means re-entering at that gate.

### §25.2 — Anomalies

An anomaly is any observed departure from a requirement, a budget, an interface
contract, or documented behaviour — **including one found by the maintainer
before anyone else sees it**. Anomalies are recorded in the project's issue
tracker under the authorized namespaces of §6.4, never in a private note.

| Severity | Definition and release consequence |
|----------|-----------------------------------|
| **S1 — Critical** | Data loss or corruption, a security or privacy breach, an unbootable or unusable system, or a wrong answer that cannot be detected downstream. **Blocks release in every category** |
| **S2 — Major** | A requirement is not met, an interface contract is violated, or a budget ceiling is exceeded, with a workaround available. Blocks release for A and B unless carried with a dated justification in the manifest |
| **S3 — Minor** | Incorrect behaviour with a straightforward workaround, or a cosmetic defect in a documented surface. Carried in known issues |
| **S4 — Cosmetic** | No functional effect. Carried indefinitely without ceremony |

| Rule | Detail |
|------|--------|
| Severity is assigned by consequence | Not by how hard the fix is, and not by how embarrassing the defect is |
| Closed by a regression test | An S1 or S2 is closed only when a test that **fails on the defective build and passes on the fix** is committed, citing the anomaly identifier. Closing by inspection permits the same defect to return unnoticed |
| Traced to a requirement | Where an anomaly reveals that no requirement covered the behaviour, the requirement set is amended (§20) — the anomaly found a specification gap, not only a bug |
| Known issues ship | Open S2–S4 anomalies are listed in the release manifest and release notes. *A defect the maintainer knows about and the user discovers is a trust failure, not a support event* |

### §25.3 — Release Acceptance and the Manifest

A release is accepted when the G3 evidence exists and the manifest is assembled.
The manifest is committed at the release tag and published with the release.

| Manifest section | Contents |
|------------------|----------|
| Identity | Project, version, ISO 8601 UTC release timestamp (§14), signed tag and commit (§6.3), and the assurance category (§19.2) |
| Artifacts | Every shipped file with its SHA-256, matching the checksums carried in the three package definitions (§5.5) |
| Provenance | The SBOM (§24.3), toolchain pins, and a reproducibility statement: how to rebuild, and whether the build is bit-reproducible |
| Verification summary | Requirements baselined, verified, and withdrawn; the traceability matrix (§21.3); coverage and, for A and B, mutation score |
| Validation note | What was exercised at G3, on what platform, and what was found (§21.5) |
| Budgets | Each ceiling, its measured value, and its margin band (§22.3) |
| Known issues | Open anomalies by severity, with identifiers (§25.2) |
| Conformance | The §19.6 claim and the tailoring register state at release |

**Installation is verified, not assumed.** Before the tag is pushed, the release
is installed from **each** of the three §5.5 package definitions into a clean
environment, run once, and uninstalled. *A package that builds is not a package
that installs.*

---

## §26 — Operations, Maintenance & Support

This standard governed software up to the moment it shipped and then stopped.
Every project it governs, however, has a life after the tag: vulnerabilities are
reported, interfaces are retired, and projects end. §5.1 is honest that the
posture is hobby pace with no service-level commitment — and that honesty is
precisely why the terms have to be written down, since a user cannot calibrate
against an unstated expectation.

### §26.1 — `SECURITY.md`

§3.3 requires security by design and §5.2 lists the files every project ships,
but no file told a finder how to report what they found. **Every project ships
`SECURITY.md` at its root, added to the §5.2 required set.**

| `SECURITY.md` states | Detail |
|----------------------|--------|
| Reporting channel | The private channel: the platform's private vulnerability reporting where available, otherwise `Mohamed.Hammad@SpacecraftSoftware.org` (§15), with a public key where one is offered. **Never a public issue tracker** |
| Acknowledgement target | An honest figure in days, consistent with hobby pace (§5.1). *A modest target that is met beats an ambitious one that is not* |
| Scope | Which projects and which versions are in scope, and what is out of scope |
| Supported versions | Which versions receive fixes (§26.4), so a reporter knows whether their version is covered before investing the effort |
| Coordinated disclosure | The embargo the maintainer will honour, and the point at which the finding is published regardless of fix status |
| Credit | Whether the reporter is credited, and where (§15.3) |

Security anomalies are **S1 by default** under §25.2; severity is lowered only
with a written argument.

### §26.2 — Advisories

- A fixed vulnerability is published as an advisory on the hosting platform and,
  for a published crate, to the ecosystem's advisory database.
- The advisory names affected versions, the fixed version, the impact, and the
  workaround — and **cites the SBOM (§24.3)** so consumers can determine exposure
  without reading the diff.
- The fix ships as a release under §25.3 like any other, with the anomaly closed
  by a regression test (§25.2).
- Where the vulnerability came from a dependency, the qualification record
  (§24.1) is updated with the incident and upstream's handling of it. *That
  record is what informs the next adoption decision.*

### §26.3 — Deprecation

§5.3 requires general-use projects to have a deprecation policy without saying
what one contains. **This is that policy**, and it applies to every project that
declares a stable interface (§23.2), general-use or not.

| Rule | Detail |
|------|--------|
| Announced in three places | `CHANGELOG.md`, the ICD entry's stability class, and a run-time warning at the point of use — once per invocation, on stderr, never suppressing the operation |
| Minimum notice period | One minor release for Category C and D; **two minor releases or six months, whichever is longer**, for A and B, whose consumers may be pinned |
| Replacement named | *A deprecation notice that does not say what to use instead is an abandonment notice* |
| Removal is major | Removal lands in a major version (§23.3) and is listed in the release notes under a breaking-changes heading |
| Security exception | A deprecation forced by a vulnerability may skip the notice period. The release notes state that it did, and why |

### §26.4 — Support Windows and End of Life

| Posture | Support commitment |
|---------|--------------------|
| Personal (§5.1 default) | Best effort on the latest release only. Stated plainly in `README.md`: no window, no backports, forking encouraged |
| General-use (§5.3) | The current major version receives security fixes for a stated window — **twelve months from the release of its successor** is the default — stated in both `README.md` and `SECURITY.md` |

**End of life is an event with a procedure**, not a repository that stops
receiving commits:

1. A **final release** is cut under §25.3, even if it contains no changes, so
   the last state is baselined and reproducible.
2. An **EOL notice** goes at the top of `README.md` with the ISO 8601 date
   (§14), the reason, the last supported version, and a successor or fork
   recommendation where one exists.
3. **`SECURITY.md` is updated** to state that no further fixes will be issued.
4. The **§5.5 packaging definitions and the manual stay** in the repository: a
   downstream packager rebuilding an archived release needs them more than a
   live project does.
5. **`PROJECTS.md` and the §15.1 subdomain table** are updated in the same
   change, and the repository is archived on the hosting platform.
6. Where the project held a reserved codename (§2.1), the registry entry records
   the retirement. **Codenames are not recycled.**
