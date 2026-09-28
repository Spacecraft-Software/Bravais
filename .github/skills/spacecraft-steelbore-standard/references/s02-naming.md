<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
## §2 — Aerospace, Sci-Fi & AI Naming Convention

All **new** project codenames, module identifiers, and public-facing component names
**must** draw from one of the following domains:

- **Real aerospace and astronomy** — orbital mechanics terms, propulsion concepts,
  named missions/programs, stellar objects and phenomena, observatories.
- **Science-fiction franchises with space / AI / cybernetic themes** — naming is
  meant to be enjoyable as well as fitting. The following are explicitly endorsed
  canonical sources:
  - *2001: A Space Odyssey*, *The Matrix*, *Terminator* — the original canonical trio
  - *The Hitchhiker's Guide to the Galaxy* — also a rich vein for in-jokes (Vogon,
    Marvin, 42, Babel fish, Heart of Gold)
  - *Hackers* (1995)
  - Spielberg films (*Close Encounters of the Third Kind*, *E.T. the Extra-Terrestrial*,
    *A.I. Artificial Intelligence*, *Minority Report*, *Ready Player One*, etc.)
  - *Ghost in the Shell*
  - *Equilibrium*
  - *Dune*
  - *Æon Flux*
  - *Super 8*
  - *LOST* (TV series)
  - *Cloverfield* films
  - Robot / android names from any sci-fi film or franchise (e.g., HAL, Data, Bishop,
    T-800, GERTY, TARS, Marvin)

  Other franchises (e.g., *Alien*, *Blade Runner*, *Ex Machina*) remain acceptable
  if they fit the space-machine-AI register.
- **Generic sci-fi / AI vocabulary** — hyperspace, neural, cybernetic, synthetic,
  sentinel, oracle, daemon, vector, lattice (the lowercase common noun), etc.

| Category  | Examples                            | Domain                          |
|-----------|-------------------------------------|---------------------------------|
| Projects  | Apollo, Discovery, Skynet, Trinity  | Missions / Ships / AI Machines  |
| Modules   | Apogee, HAL, Cortex, Sentinel       | Subsystems / AI Cores           |
| Utilities | Boost, Throttle, Trace, Telemetry   | Operational Verbs / Telemetry   |
| Releases  | Vega, Pulsar, Quasar, Nebula        | Stellar Phenomena               |

Names must be **fitting for space-related and futuristic AI machines** — the
test is whether the name would feel at home on the hull of a spacecraft or in
the boot banner of an AI machine. Reject proposed names that don't pass this test.

### §2.1 — Legacy Metallurgical Registry (pre-v1.2)

Projects named before the v1.2 convention drew from metallurgy, materials science,
and industrial forging. These names are **preserved as-is** unless explicitly
renamed by the maintainer. The v1.2 convention applies prospectively — no forced
back-rename.

| Codename    | Status                | Description                                                    |
|-------------|-----------------------|----------------------------------------------------------------|
| `Steelbore` | Renamed to Spacecraft Software (umbrella, v1.7) | Former umbrella organization name. Renamed 2026-05-15 under the v1.7 brand consolidation. The OS line (`Steelbore OS`, `Steelbore OS Bravais`, `Steelbore OS Lattice`) retains the Steelbore name. |
| `Aetheric`  | Deprecated            | Next-generation extensible text editor (Pulsar + Quasar + Nebula IPC). Superseded by another project. |
| `Zamak`     | Active                | Rust bootloader (Limine rewrite)                               |
| `Bravais`   | Completed (renamed)   | NixOS flake configuration. Renamed from `Lattice` due to collision with Lattice OS. `Bravais` is still a metallurgical-era name (Bravais lattice) and predates the v1.2 convention. |
| `Ferrocast` | Deprecated            | Rust PowerShell rewrite (16-crate workspace). Superseded by another project.                   |
| `Craton`    | Reserved              | Rust universal package manager — codename registered; no work started yet. |
| `Ironway`   | Active                | Rust OpenTTD rewrite                                           |
| `Caliper`   | Active                | Rust raster-to-vector tracing engine (CLI+TUI)                 |
| `Mawaqit`   | Planning (**Pending rename**) | Islamic prayer times app (Flutter + Rust CLI + libmawaqit). To be renamed under the v1.2 aerospace/sci-fi/AI convention. |
| `Anvil`     | Completed             | Rust workspace; benches and CHANGELOG; legacy forging-tool name.                |
| `Flux`      | Completed             | Rust workspace; CHANGELOG and deny.toml; legacy metallurgical-flux name.        |
| `Pearlite`  | Active                | Rust workspace; audit.toml, clippy.toml, CHANGELOG; steel microstructure name.  |
| `Ferrite_OS`| Active                | Custom OS / DOS-emulation experiments; ferrite (iron-based material) name.      |
| `Forge`     | Active                | Production flavor tooling (forge-cli, forge-build, forge-activate); forging-tool name. |

Existing legacy-named projects MAY be renamed under the v1.2 convention at the
maintainer's discretion — renames are optional. When a rename happens, update
this table and §15.1's subdomain table in the same commit.

### §2.2 — Skill IDs are functional, not codenamed

Skill directory names and SKILL.md `name` fields are **functional identifiers**
(e.g., `spacecraft-steelbore-standard`, `spacecraft-document-format`) and are not subject to
the §2 codename convention. §2 reserves codenames for projects/modules/utilities/releases,
not for skill identifiers.

---

