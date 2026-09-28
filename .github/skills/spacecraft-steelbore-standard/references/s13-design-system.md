<!-- Part of spacecraft-steelbore-standard — see SKILL.md for the index -->
## §13 — UI/UX Design System

- **Every graphical application declares exactly one component system**, named in its
  `README.md` beside the §5.2 posture section, and themes it with the §11 palette.
  Which system is determined by the platform, not by preference:

  | Application class | Required component system |
  |-------------------|---------------------------|
  | **Flutter, web, mobile, and cross-platform GUI** | **Material Design** |
  | **GTK 4 desktop** | **GNOME HIG** via libadwaita → `spacecraft-gtk-guidelines` |
  | **Qt 6 desktop** | **KDE HIG** via Qt Quick Controls / Fusion → `spacecraft-qt-guidelines` |
  | **Custom-drawn or immediate-mode UI** | Material Design, unless a platform HIG is declared |

  **Rationale.** Material Design is a coherent, accessible system and remains the default
  wherever the platform does not supply one. A native desktop toolkit does supply one:
  GTK ships Adwaita and the GNOME HIG, Qt ships Fusion and the KDE HIG, and both are
  wired into the platform's window management, settings, and accessibility stack.
  Imposing Material on top of either produces an application that matches neither its
  own toolkit nor Material, and that fights the very platform integration §18 depends on.
  The mandate is therefore that a system is **declared and followed consistently** — not
  that one particular system is used everywhere.
- **§11 binding is unconditional.** Whichever system is declared, all palette references
  go through the named `steelbore` theme (§11.1). A component system chooses the widget
  vocabulary; it never supplies the colors.
- **WCAG 2.2 Level AA** contrast is the minimum for all color pairings.
  Any new color additions must be WCAG-verified before adoption, and the
  verification must state *which pairing* was measured (§11).
- **Accessibility** is governed by **§18**, which applies to CLI, TUI, and GUI
  alike. §13 is the graphical design system; §18 is the accessibility contract.
  Where the two overlap, §18 governs.

---

