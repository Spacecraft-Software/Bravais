# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Modern with a warmer accent — an example of a LOCAL theme.
#
# Two shapes are accepted here, both resolved by lib/palette.nix through the
# same path as a registered palette (so a local theme gets the same role
# completion, hue-derived ANSI map and xterm-256 handling for free):
#
#   { base = "steelbore"; accent = "#FF8A3D"; }   override tokens of a registered palette
#   { background = "…"; foreground = "…"; … }     fully custom (needs the five
#                                                 required roles: background,
#                                                 foreground, accent, success, error)
#
# Naming a file after a registered slug (themes/steelbore.nix) shadows it —
# the way to tweak Modern everywhere without forking the upstream TOML.
#
# §11.4: a fully custom palette is outside the Standard's registered family and
# carries no verified contrast matrix. Deriving from a `base` keeps the rest of
# a compliant palette — and its measured ratios — intact.
{
  base = "steelbore";

  # Modern's own high-contrast accent lift (§11.1.1), 8.70:1 on Void Navy
  # against Plasma Orange's 6.66:1. A verified value, not an invented one.
  accent = "#FF8A3D";
}
