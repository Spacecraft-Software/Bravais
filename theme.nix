# SPDX-License-Identifier: GPL-3.0-or-later
# The active system theme. Change this one word and rebuild — every terminal,
# both bars, every WM, the TTY console and greetd follow, because no consumer
# names a color: they all read Standard §11.1 role tokens.
#
#   theme list          see every theme, with swatches
#   theme show <slug>   inspect one
#   theme set <slug>    rewrite this file
#   theme try <slug>    build a theme without touching this file
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
