# CREDITS

The `microsoft-rust-guidelines` skill is a Spacecraft Software adaptation of publicly released
work by Microsoft. This file records the upstream source it builds on, in
accordance with [The Steelbore Standard §15.3](../spacecraft-standard-constitution/SKILL.md).

## Microsoft Pragmatic Rust Guidelines

| Field      | Value                                          |
|------------|------------------------------------------------|
| Name       | Microsoft Pragmatic Rust Guidelines            |
| Author(s)  | Microsoft Corporation                          |
| License    | MIT License                                    |
| Source URL | https://github.com/microsoft/rust-guidelines   |
| Scope      | All twelve files under `references/` (`01_ai_guidelines.md` through `12_libraries_ux_guidelines.md`) are adapted from the upstream text. Section structure, naming, and most rule prose originate with Microsoft; the Spacecraft Software adaptation adds skill-loading triggers, the **Current compliance date** mechanism in `SKILL.md`, and integration with the wider Steelbore Standard. |

## License of the Spacecraft Software adaptation

This skill is **dual-licensed: `GPL-3.0-or-later OR MIT`** — see
[`LICENSE-GPL`](LICENSE-GPL) and [`LICENSE-MIT`](LICENSE-MIT). The recipient
may use the skill under **either** license, at their option.

- The **MIT arm** preserves the terms of the upstream Microsoft Pragmatic Rust
  Guidelines verbatim (Standard §4.2 — third-party-derived artifacts keep their
  upstream license; Microsoft's copyright + permission notice is retained in
  `LICENSE-MIT`). The entire `references/` tree is Microsoft's MIT text.
- The **GPL-3.0-or-later arm** brings the skill in line with the Standard's
  software-class default (Standard §4.1.1 — skills are software-class). MIT is
  one-way compatible with the GPL, so offering the adapted work under
  GPL-3.0-or-later is valid as long as the MIT notice above is preserved, which
  it is.

GPL is listed first as the preferred arm; MIT remains available so the skill is
never more restrictive than the work it derives from. (This replaces the earlier
"MIT only / single exception to §4" posture, which predated Standard v1.18's
§4.1.1/§4.2 artifact-class model.)

## Maintainer of the adaptation

Mohamed Hammad &lt;Mohamed.Hammad@SpacecraftSoftware.org&gt;
https://SpacecraftSoftware.org/
