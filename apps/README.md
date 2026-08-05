# Application drop-ins

One file per application, filename **is** the slug — the same convention as
`themes/<slug>.nix`. Everything here is merged over the built-in catalog in
`lib/default-apps.nix`, so a drop-in may also **shadow** a built-in entry of the
same name (to correct a desktop ID, narrow the MIME list, or point at a
different package).

This is how an application that is not in nixpkgs joins the registry, without
touching the resolver.

```nix
# apps/majestic.nix
{
  name = "Majestic";
  role = "editor";                    # editor | browser | fileManager | imageViewer | termEditor
  desktopId = "org.spacecraftsoftware.Majestic.desktop";

  # Optional. `pkgs -> drv`. Installed by users/mj/default-apps.nix while this
  # entry is active, so `app set editor majestic` is the only edit needed.
  # Leave it out when a modules/packages bundle already carries the package.
  package = pkgs: pkgs.majestic;

  # Optional. `pkgs -> string`. Shell command for the env vars a role feeds
  # ($EDITOR for termEditor, $BROWSER for browser). A function, so the
  # `app-registry` flake output never has to evaluate it.
  exec = pkgs: "${pkgs.majestic}/bin/majestic";

  # Optional, fileManager only. Exec= line for the org.freedesktop.FileManager1
  # D-Bus name, which "Show in folder" resolves instead of inode/directory.
  # dbusExec = pkgs: "${pkgs.majestic}/bin/majestic --gapplication-service";

  # Optional. Narrows the role's MIME list for an app that genuinely cannot
  # open all of it. Omit it and the app inherits the role's full set — which is
  # the point: the role owns the list, not the app's own MimeType= line.
  # mimeTypes = [ "text/plain" "application/x-zerosize" ];
}
```

Then:

```sh
app set editor majestic   # rewrites ../default-apps.nix
rebuild
```

Required fields are `name`, `role`, and `desktopId` (use `""` for `termEditor`,
which binds no MIME types). Anything missing, or a role that does not exist,
fails at evaluation with a message naming the fix.
