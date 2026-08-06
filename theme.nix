# SPDX-License-Identifier: GPL-3.0-or-later
# The active system theme. Change this one word and rebuild — every terminal,
# both bars, every WM, the TTY console and greetd follow, because no consumer
# names a color: they all read Standard §11.1 role tokens.
#
#   theme list          see every theme, with swatches
#   theme show <slug>   inspect one
#   theme set <slug>    rewrite this file
#   theme try <slug>    build a theme without touching this file
#   theme now <slug>    switch §11.6-aware apps with no rebuild
#
# This file is the BUILD-time selection. modules/theme/declaration.nix renders
# it into /etc/steelbore/theme.toml and exports SPACECRAFT_THEME, which is how a
# RUNNING application learns the active theme (Standard §11.6.4). Both come from
# the one word below, so they cannot drift; `theme now` writes the per-user
# override at $XDG_CONFIG_HOME/steelbore/theme.toml, which outranks it.
#
# Registered (from the `construct` input's steelbore.toml, Standard §11):
#   steelbore                    Modern — the Standard default
#   steelbore-classic            the legacy six-token palette (§11.2)
#   steelbore-blue               steelbore-blackpinkpanther
#   steelbore-matrixgreen        steelbore-navywhite (light canvas)
#   tokyonight
#   …plus a <slug>-high-contrast sibling of each (§11.1.1)
#
# Local themes live in ./themes/ — one file per theme, filename is the slug.
# A local theme may override a registered one of the same name.
{
  active = "steelbore";
}
