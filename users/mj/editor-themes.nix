# SPDX-FileCopyrightText: 2026 Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Steelbore Bravais — Home Manager: editor themes from the Theme repository.
#
# The `theme` flake input (Spacecraft-Software/Theme) renders the whole §11
# palette family into editor formats Bravais does not generate itself. Editors
# keep their own theme pickers, so the WHOLE family is installed — every
# palette, its high-contrast sibling, Classic and the Solarized fidelity pair —
# and `theme set <slug>` + rebuild only changes which one the rest of the
# desktop wears. Each editor's own settings file stays user-owned: nothing here
# rewrites a settings.json, so an in-editor choice survives a rebuild.
#
# Everything is a symlink into the store; there is nothing to copy or update
# by hand, and `nix flake update theme` moves all of it.
{
  lib,
  themeAssets,
  ...
}:

let
  # VS Code and its forks discover an extension from a directory named
  # `<publisher>.<name>-<version>` under their extensions root. The Theme
  # repository ships the unpacked extension; linking it is the same thing the
  # marketplace install would produce, minus the marketplace.
  extensionDirName = "spacecraft-software.spacecraft-software-2.0.0";

  # Every VS Code-family extensions root this user runs. The Flatpak VS Code
  # (com.visualstudio.code, modules/packages/flatpak.nix) keeps its extensions
  # in its own sandboxed data directory; Cursor and Antigravity IDE in theirs.
  # VSCodium ships twice (modules/packages/editors.nix): nixpkgs reads
  # ~/.vscode-oss, and the Flatpak's wrapper passes
  # `--extensions-dir $XDG_DATA_HOME/codium/extensions`.
  vscodeRoots = [
    ".vscode/extensions"
    ".var/app/com.visualstudio.code/data/vscode/extensions"
    ".vscode-oss/extensions"
    ".var/app/com.vscodium.codium/data/codium/extensions"
    ".cursor/extensions"
  ];

  linkExtension = source: root: {
    name = "${root}/${extensionDirName}";
    value.source = source;
  };
in
{
  home.file =
    lib.optionalAttrs (themeAssets.vscodeExtension != null) (
      builtins.listToAttrs (map (linkExtension themeAssets.vscodeExtension) vscodeRoots)
    )
    // lib.optionalAttrs (themeAssets.antigravityExtension != null) {
      # Antigravity IDE is a VS Code fork with its own extensions root and its
      # own build of the extension (same themes, different package id).
      ".antigravity/extensions/spacecraft-software.spacecraft-software-antigravity-2.0.0".source =
        themeAssets.antigravityExtension;
    };

  xdg.configFile =
    lib.optionalAttrs (themeAssets.zedFamily != null) {
      # One Zed theme-family file carrying every theme; Zed lists each entry
      # under Settings › Theme.
      "zed/themes/steelbore.json".source = themeAssets.zedFamily;
    }
    // lib.optionalAttrs (themeAssets.lapceThemes != null) {
      # Lapce reads one TOML per theme from its themes directory. Linked file
      # by file (`recursive`) so a hand-dropped theme beside them survives.
      "lapce-stable/themes" = {
        source = themeAssets.lapceThemes;
        recursive = true;
      };
    };
}
