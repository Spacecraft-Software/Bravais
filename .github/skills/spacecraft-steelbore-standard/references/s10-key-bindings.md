<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
## §10 — Key Bindings

All interactive applications must support **both**:

**Scope.** This chapter does **not** apply to projects registered as **games**
under §18.5 — games are exempt from §10 in full, including the CUA and Vim rows
below. Modal editing and text-editor chords are a poor fit for real-time play; a
game's control scheme is entirely at the maintainer's discretion. §18.5 restates
the useful parts as recommendations a game may decline.

| Scheme    | Requirement                                                              |
|-----------|--------------------------------------------------------------------------|
| **CUA**   | Standard bindings (Ctrl+C/X/V/Z/S) must work in all text input contexts  |
| **Vim**   | Modal editing layer (Normal / Insert / Visual mode) as opt-in feature. Minimum: hjkl navigation where full Vim layer is impractical |

**Remappability (mandatory).** Every binding must be user-remappable through the
project's configuration layer — a fixed, non-configurable keymap is non-compliant.

**Reserved assistive-technology chords.** These are claimed by screen readers and
**must not** be captured by a Spacecraft Software application:

| Chord | Claimed by |
|-------|------------|
| `Insert` / `CapsLock` | NVDA (Windows) — the NVDA modifier key |
| `Insert` / `KP_Insert` | Orca (GNOME/Linux) — the screen reader's own modifier |
| `Ctrl`+`Option` | VoiceOver (macOS) — the "VO" modifier |

Every action reachable by pointer must also be reachable by keyboard; focus order
must be linear and the focused element visibly indicated. See §18.

---

