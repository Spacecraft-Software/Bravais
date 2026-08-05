# SPDX-License-Identifier: GPL-3.0-or-later
# The active default application for each handler role. Change one word and
# rebuild — every MIME binding, the D-Bus FileManager1 name, $BROWSER, $EDITOR
# and the `edit` alias follow, because no consumer names an application.
#
#   app list                 every role and its active app
#   app show [role]          the resolved entry, with the MIME types it binds
#   app candidates <role>    every app that can fill a role
#   app set <role> <slug>    rewrite this file
#
# Registered slugs (see lib/default-apps.nix for the catalog):
#   editor        cosmic-edit  gnome-text-editor  gedit  zed  lapce  vscode
#                 kate  kwrite
#   browser       chrome  brave  opera  browseros
#   fileManager   cosmic-files  nautilus
#   imageViewer   oculante  loupe  gwenview  feh
#   termEditor    msedit  helix  nvim  vim
#
# Drop-ins live in ./apps/ — one file per app, filename is the slug. A drop-in
# may shadow a built-in entry of the same name, and is how an application that
# is not yet in nixpkgs (Majestic) joins the registry.
#
# `app set` rewrites this file with `sd`, anchored on `<role> = "<current>"`.
# Do NOT align the `=` signs — the anchor must match the text exactly.
{
  editor = "cosmic-edit";
  browser = "chrome";
  fileManager = "cosmic-files";
  imageViewer = "oculante";
  termEditor = "msedit";
}
