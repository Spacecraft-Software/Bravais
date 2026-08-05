# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore default-application registry — the single canonical source for
# "which program handles what".
#
# The problem this exists to solve: an application's own `.desktop` entry is
# not a reliable statement of what it can open. `com.system76.CosmicEdit.desktop`
# declares `MimeType=text/plain;` and nothing else, while gedit declares
# `text/plain;application/x-zerosize;`. A zero-byte file — exactly what a file
# manager's "New file" creates — is `application/x-zerosize`, which is NOT a
# subclass of `text/plain`, so a `text/plain` default does not cascade to it.
# The type falls through to desktop-entry cache ordering and an arbitrary
# editor wins.
#
# So here the ROLE owns the MIME list, not the application. Whichever editor
# is selected inherits the complete set, even when its own `.desktop`
# under-declares. Selecting a different one is one word in ./default-apps.nix.
#
# Only builtins are used — no `pkgs`, no nixpkgs `lib`. That keeps the
# `app-registry` flake output cheap to evaluate (it never touches a system
# config), the same way lib/palette.nix stays builtins-only.
#
# Usage:  import ./lib/default-apps.nix {
#           selection = import ./default-apps.nix;
#           localApps = { majestic = import ./apps/majestic.nix; };
#         }
{
  selection,
  localApps ? { },
}:

let
  # ---------------------------------------------------------------------
  # Roles — the handler slots, and the MIME types each one owns.
  # ---------------------------------------------------------------------
  # A role's `mimeTypes` is bound wholesale to whatever app fills it. An
  # entry may narrow the list (see `mimeTypes` on a catalog entry) when it
  # genuinely cannot open everything, but it must never be left to the
  # app's own MimeType= line: that is the bug described at the top.
  roleDefs = {
    editor = {
      description = "GUI text editor — what double-clicking a text file opens";
      mimeTypes = [
        "text/plain"
        # The reason this file exists. An empty file is x-zerosize, and it
        # is not a subclass of text/plain, so it needs its own binding.
        "application/x-zerosize"
        "text/markdown"
        "text/x-markdown"
        "text/x-nix"
        "text/x-shellscript"
        "application/x-shellscript"
        "text/x-python"
        "application/json"
        "application/xml"
        "text/xml"
        "text/csv"
        "text/x-log"
        "text/x-c"
        "text/x-c++src"
        "text/x-chdr"
        "text/x-rust"
        "text/x-toml"
        "application/toml"
        "text/x-yaml"
        "application/x-yaml"
        "text/x-makefile"
        "text/x-tex"
        "text/x-sql"
        "text/x-lua"
        "text/x-go"
        "text/x-java"
        "text/javascript"
        "text/css"
        "text/x-diff"
        "text/x-patch"
        "text/x-scheme"
        "text/x-ruby"
        "text/x-perl"
      ];
    };

    browser = {
      description = "Web browser — HTML documents and http(s) links";
      mimeTypes = [
        "text/html"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
        "x-scheme-handler/about"
        "x-scheme-handler/unknown"
      ];
    };

    fileManager = {
      # `inode/directory` alone is not enough: Chromium's "Show in folder"
      # and the portal's OpenURI.OpenDirectory resolve by D-Bus activation
      # of org.freedesktop.FileManager1. The entry's `dbusExec` covers that
      # half; users/mj/default-apps.nix writes the service file.
      description = "GUI file manager — directories, and the FileManager1 bus name";
      mimeTypes = [ "inode/directory" ];
    };

    imageViewer = {
      description = "Image viewer";
      mimeTypes = [
        "image/png"
        "image/jpeg"
        "image/gif"
        "image/webp"
        "image/bmp"
        "image/tiff"
        "image/svg+xml"
        "image/avif"
        "image/heic"
        "image/jxl"
        "image/jp2"
        "image/vnd.microsoft.icon"
        "image/x-tga"
        "image/x-exr"
        "application/vnd.adobe.photoshop" # PSD
        "image/x-adobe-dng" # RAW
        "image/x-canon-cr2"
        "image/x-nikon-nef"
        "image/x-sony-arw"
        "image/x-fuji-raf"
      ];
    };

    termEditor = {
      # No MIME types by design: this role drives $EDITOR / $VISUAL, the
      # `edit` alias in Nushell and Ion, and git's core.editor. It is
      # deliberately separate from `editor` — what $EDITOR runs and what a
      # double-click opens are different questions.
      description = "Terminal editor — \$EDITOR / \$VISUAL / git core.editor";
      mimeTypes = [ ];
    };
  };

  # ---------------------------------------------------------------------
  # Catalog — the built-in entries, keyed by slug.
  # ---------------------------------------------------------------------
  # Required: name, role, desktopId (use "" for a role with no MIME types).
  # Optional:
  #   package   pkgs -> drv   installed by users/mj/default-apps.nix when this
  #                           entry is active. `null` means "already carried by
  #                           a modules/packages bundle" — the common case, and
  #                           why most built-ins leave it null.
  #   exec      pkgs -> str   shell command for env vars ($EDITOR, $BROWSER).
  #                           A function, so the registry JSON never evaluates
  #                           it and stays pkgs-free.
  #   dbusExec  pkgs -> str   Exec= line for org.freedesktop.FileManager1.
  #   mimeTypes [ str ]       narrows the role's list for an app that cannot
  #                           open all of it.
  catalog = {
    # ── editor ──────────────────────────────────────────────────────────
    cosmic-edit = {
      name = "COSMIC Text Editor";
      role = "editor";
      desktopId = "com.system76.CosmicEdit.desktop";
      exec = pkgs: "${pkgs.cosmic-edit}/bin/cosmic-edit";
    };
    gnome-text-editor = {
      name = "GNOME Text Editor";
      role = "editor";
      # Arrives with services.desktopManager.gnome, not a bundle.
      desktopId = "org.gnome.TextEditor.desktop";
      exec = pkgs: "${pkgs.gnome-text-editor}/bin/gnome-text-editor";
    };
    gedit = {
      name = "gedit";
      role = "editor";
      desktopId = "org.gnome.gedit.desktop";
      exec = pkgs: "${pkgs.gedit}/bin/gedit";
    };
    zed = {
      name = "Zed";
      role = "editor";
      desktopId = "dev.zed.Zed.desktop";
      exec = pkgs: "${pkgs.zed-editor}/bin/zeditor";
    };
    lapce = {
      name = "Lapce";
      role = "editor";
      desktopId = "lapce.desktop";
      exec = pkgs: "${pkgs.lapce}/bin/lapce";
    };
    vscode = {
      name = "Visual Studio Code";
      role = "editor";
      # Flatpak (modules/packages/flatpak.nix), not a Nix package here.
      desktopId = "com.visualstudio.code.desktop";
      exec = _: "flatpak run com.visualstudio.code";
    };
    kate = {
      name = "Kate";
      role = "editor";
      desktopId = "org.kde.kate.desktop";
      exec = pkgs: "${pkgs.kdePackages.kate}/bin/kate";
    };
    kwrite = {
      name = "KWrite";
      role = "editor";
      desktopId = "org.kde.kwrite.desktop";
      exec = pkgs: "${pkgs.kdePackages.kate}/bin/kwrite";
    };

    # ── browser ─────────────────────────────────────────────────────────
    chrome = {
      name = "Google Chrome";
      role = "browser";
      desktopId = "com.google.Chrome.desktop";
      # Flatpak — matches the $BROWSER value this replaced.
      exec = _: "flatpak run com.google.Chrome";
    };
    brave = {
      name = "Brave";
      role = "browser";
      desktopId = "com.brave.Browser.desktop";
      exec = _: "flatpak run com.brave.Browser";
    };
    opera = {
      name = "Opera";
      role = "browser";
      desktopId = "com.opera.Opera.desktop";
      exec = _: "flatpak run com.opera.Opera";
    };
    browseros = {
      name = "BrowserOS";
      role = "browser";
      # Vendored AppImage wrapper, inline in modules/packages/browsers.nix.
      desktopId = "browseros.desktop";
      exec = _: "browseros";
    };

    # ── fileManager ─────────────────────────────────────────────────────
    cosmic-files = {
      name = "COSMIC Files";
      role = "fileManager";
      desktopId = "com.system76.CosmicFiles.desktop";
      exec = pkgs: "${pkgs.cosmic-files}/bin/cosmic-files";
      # The applet, not the main binary: it is what claims the bus name and
      # spawns `cosmic-files <uri>` on ShowItems / ShowFolders.
      dbusExec = pkgs: "${pkgs.cosmic-files}/bin/cosmic-files-applet";
    };
    nautilus = {
      name = "Files (Nautilus)";
      role = "fileManager";
      desktopId = "org.gnome.Nautilus.desktop";
      exec = pkgs: "${pkgs.nautilus}/bin/nautilus";
      dbusExec = pkgs: "${pkgs.nautilus}/bin/nautilus --gapplication-service";
    };

    # ── imageViewer ─────────────────────────────────────────────────────
    oculante = {
      name = "Oculante";
      role = "imageViewer";
      desktopId = "oculante.desktop";
      exec = pkgs: "${pkgs.oculante}/bin/oculante";
    };
    loupe = {
      name = "Loupe";
      role = "imageViewer";
      desktopId = "org.gnome.Loupe.desktop";
      exec = pkgs: "${pkgs.loupe}/bin/loupe";
      # No PSD, no camera RAW.
      mimeTypes = [
        "image/png"
        "image/jpeg"
        "image/gif"
        "image/webp"
        "image/bmp"
        "image/tiff"
        "image/svg+xml"
        "image/avif"
        "image/heic"
        "image/jxl"
        "image/vnd.microsoft.icon"
      ];
    };
    gwenview = {
      name = "Gwenview";
      role = "imageViewer";
      desktopId = "org.kde.gwenview.desktop";
      exec = pkgs: "${pkgs.kdePackages.gwenview}/bin/gwenview";
    };
    feh = {
      name = "feh";
      role = "imageViewer";
      desktopId = "feh.desktop";
      exec = pkgs: "${pkgs.feh}/bin/feh";
      mimeTypes = [
        "image/png"
        "image/jpeg"
        "image/gif"
        "image/webp"
        "image/bmp"
        "image/tiff"
      ];
    };

    # ── termEditor ──────────────────────────────────────────────────────
    msedit = {
      name = "Microsoft Edit";
      role = "termEditor";
      desktopId = "";
      exec = pkgs: "${pkgs.msedit}/bin/edit";
    };
    helix = {
      name = "Helix";
      role = "termEditor";
      desktopId = "";
      exec = pkgs: "${pkgs.helix}/bin/hx";
    };
    nvim = {
      name = "Neovim";
      role = "termEditor";
      desktopId = "";
      exec = pkgs: "${pkgs.neovim}/bin/nvim";
    };
    vim = {
      name = "Vim";
      role = "termEditor";
      desktopId = "";
      exec = pkgs: "${pkgs.vim}/bin/vim";
    };
  };

  # ---------------------------------------------------------------------
  # Merge in ./apps/<slug>.nix — a drop-in shadows a built-in of the same
  # name, mirroring how ./themes/<slug>.nix shadows a registered palette.
  # ---------------------------------------------------------------------
  merged = catalog // localApps;

  sourceOf = slug: if localApps ? ${slug} then "local" else "builtin";

  roleNames = builtins.attrNames roleDefs;
  slugs = builtins.attrNames merged;

  commaList = xs: builtins.concatStringsSep ", " (builtins.sort builtins.lessThan xs);

  # ---------------------------------------------------------------------
  # Validation — fail at eval time with a message that names the fix.
  # ---------------------------------------------------------------------
  checkEntry =
    slug:
    let
      e = merged.${slug};
      need =
        field:
        if e ? ${field} then
          true
        else
          throw "default-apps: '${slug}' is missing the required field '${field}' (needed: name, role, desktopId)";
    in
    if !(need "name" && need "role" && need "desktopId") then
      throw "unreachable"
    else if !(builtins.elem e.role roleNames) then
      throw "default-apps: '${slug}' declares the unknown role '${e.role}' — known roles: ${commaList roleNames}"
    else
      slug;

  checkedSlugs = map checkEntry slugs;

  candidatesFor = role: builtins.filter (s: merged.${s}.role == role) checkedSlugs;

  resolveRole =
    role:
    let
      slug =
        if selection ? ${role} then
          selection.${role}
        else
          throw "default-apps: ./default-apps.nix does not name an app for the role '${role}' — add `${role} = \"<slug>\";`";
      cand = candidatesFor role;
      # Routed through checkEntry so a malformed entry fails here, not later
      # and only if something happens to force the catalog.
      e = merged.${checkEntry slug};
    in
    if !(merged ? ${slug}) then
      throw "default-apps: unknown app '${slug}' for role '${role}' — registered: ${commaList cand} (or drop a definition in ./apps/${slug}.nix)"
    else if e.role != role then
      throw "default-apps: '${slug}' fills the role '${e.role}', not '${role}' — for '${role}' choose one of: ${commaList cand}"
    else
      {
        inherit slug role;
        inherit (e) name desktopId;
        source = sourceOf slug;
        package = e.package or null;
        exec = e.exec or null;
        dbusExec = e.dbusExec or null;
        mimeTypes = e.mimeTypes or roleDefs.${role}.mimeTypes;
        inherit (roleDefs.${role}) description;
      };

  # Every role named in ./default-apps.nix must be a real role.
  unknownSelected = builtins.filter (r: !(builtins.elem r roleNames)) (builtins.attrNames selection);

  roles =
    if unknownSelected != [ ] then
      throw "default-apps: ./default-apps.nix names the unknown role(s) ${commaList unknownSelected} — known roles: ${commaList roleNames}"
    else
      builtins.listToAttrs (
        map (r: {
          name = r;
          value = resolveRole r;
        }) roleNames
      );

  # ---------------------------------------------------------------------
  # Flatten every role's bindings into one mime -> desktopId map.
  # ---------------------------------------------------------------------
  # Two roles claiming the same type would silently let one win, so that is
  # an eval error rather than a coin flip.
  pairs = builtins.concatLists (
    map (
      r:
      map (m: {
        mime = m;
        role = r;
        id = roles.${r}.desktopId;
      }) roles.${r}.mimeTypes
    ) roleNames
  );

  mimeDefaults =
    let
      dup =
        (builtins.foldl'
          (
            acc: p:
            if acc.seen ? ${p.mime} && acc.seen.${p.mime} != p.role then
              acc
              // {
                dup = acc.dup ++ [ "${p.mime} (${acc.seen.${p.mime}} and ${p.role})" ];
              }
            else
              acc
              // {
                seen = acc.seen // {
                  ${p.mime} = p.role;
                };
              }
          )
          {
            seen = { };
            dup = [ ];
          }
          pairs
        ).dup;
    in
    if dup != [ ] then
      throw "default-apps: MIME type(s) claimed by more than one role: ${builtins.concatStringsSep ", " dup} — a type belongs to exactly one role in lib/default-apps.nix"
    else
      builtins.listToAttrs (
        map (p: {
          name = p.mime;
          value = p.id;
        }) pairs
      );
in
{
  inherit roles mimeDefaults;

  # Every registered app, pkgs-free — this is what the `app-registry` flake
  # output serialises and the `app` command reads.
  registry = {
    roles = builtins.listToAttrs (
      map (r: {
        name = r;
        value = {
          inherit (roles.${r})
            slug
            name
            desktopId
            source
            mimeTypes
            description
            ;
          candidates = builtins.sort builtins.lessThan (candidatesFor r);
        };
      }) roleNames
    );
    catalog = builtins.listToAttrs (
      map (s: {
        name = s;
        value = {
          slug = s;
          inherit (merged.${s}) name role desktopId;
          source = sourceOf s;
          active = roles.${merged.${s}.role}.slug == s;
        };
      }) checkedSlugs
    );
  };

  meta = {
    inherit roleNames selection;
  };
}
