# SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Generated theme artifacts from the `theme` flake input (Spacecraft-Software/Theme).
#
# lib/palette.nix resolves the active slug to §11.1 ROLE TOKENS, and most of
# Bravais renders its own configs from those tokens — that path also serves a
# LOCAL theme in ./themes/, which no external repository can know about.
#
# The Theme repository renders the same palette family into formats Bravais
# does not render itself (a VS Code extension, Zed and Lapce themes, libadwaita
# GTK tokens, KDE colour schemes, the Starship preset, Nushell's colour config).
# This file maps the active slug to those files. Every attribute is a store
# path when the slug is a REGISTERED palette the Theme repository ships, and
# `null` for a local theme, so a consumer writes
#
#   if themeAssets.starship != null then <use the file> else <render from tokens>
#
# and a local theme keeps working. Nothing here carries a colour value: the
# Theme repository generated these files from the same steelbore.toml the
# `construct` input ships (§11.4), so the two inputs agree by construction —
# `nix flake update construct theme` moves them together.
#
# Only builtins are used — imported from flake.nix before nixpkgs' `lib` exists.
{
  themeRoot,
  slug,
  localThemes ? { },
}:

let
  root = toString themeRoot;
  isLocal = localThemes ? ${slug};

  # A per-slug file, or null when the slug is local or the file is absent
  # (an older Theme checkout that predates a palette, for instance).
  at =
    rel:
    let
      p = "${root}/${rel}";
    in
    if !isLocal && builtins.pathExists p then p else null;

  # A family-wide file that exists for every slug, active or not.
  shared =
    rel:
    let
      p = "${root}/${rel}";
    in
    if builtins.pathExists p then p else null;

  hasSuffix =
    suffix: s:
    let
      n = builtins.stringLength s;
      m = builtins.stringLength suffix;
    in
    n >= m && builtins.substring (n - m) m s == suffix;
  stripSuffix =
    suffix: s: builtins.substring 0 (builtins.stringLength s - builtins.stringLength suffix) s;

  # Display names come from the Theme repository's own registry, never from a
  # table kept here — a rename upstream must not need a Bravais edit.
  registryPath = shared "Steelbore/steelbore.json";
  registry = if registryPath == null then { } else builtins.fromJSON (builtins.readFile registryPath);
  nameOf = s: if registry ? themes && registry.themes ? ${s} then registry.themes.${s}.name else s;

  # Every KDE colour scheme the repository ships, so all of them can be
  # installed for System Settings while only the active one is selected.
  kdeDir = "${root}/Desktops/KDE_Plasma/themes";
  kdeFiles =
    if builtins.pathExists kdeDir then
      builtins.filter (hasSuffix ".colors") (builtins.attrNames (builtins.readDir kdeDir))
    else
      [ ];
  kdeSchemes = map (
    f:
    let
      s = stripSuffix ".colors" f;
    in
    {
      slug = s;
      name = nameOf s;
      path = "${kdeDir}/${f}";
    }
  ) kdeFiles;
in
{
  inherit slug root;

  # True when the active slug is a registered palette the Theme repository
  # renders. Local themes (./themes/<slug>.nix) are false and every per-slug
  # attribute below is null.
  registered = !isLocal && at "Shells/Starship/themes/${slug}.toml" != null;

  # The theme's display name ("Steelbore Blue High Contrast"), for consumers
  # that select by name rather than by file — VS Code's `workbench.colorTheme`,
  # KDE's `ColorScheme=` key.
  name = nameOf slug;

  # ── per-slug files (null for a local theme) ──────────────────────────────
  starship = at "Shells/Starship/themes/${slug}.toml";
  nushell = at "Shells/Nushell/themes/${slug}.nu";
  gtk4Css = at "Desktops/GNOME/themes/${slug}/gtk.css";
  gtk3Css = at "Desktops/XFCE/themes/${slug}/gtk.css";
  kde = at "Desktops/KDE_Plasma/themes/${slug}.colors";
  claudeCode = at "CLIs/Claude_Code/themes/${slug}/settings.json";

  # ── family-wide files (every theme, regardless of the active slug) ──────
  # Editors keep their own theme picker, so the whole family is installed and
  # the active slug only informs the default.
  zedFamily = shared "Editors/Zed/steelbore.json";
  lapceThemes = shared "Editors/Lapce/themes";
  vscodeExtension = shared "Editors/VSCode/spacecraft-software-theme";
  antigravityExtension = shared "Editors/Google_Antigravity/spacecraft-software-antigravity";
  inherit kdeSchemes;
}
