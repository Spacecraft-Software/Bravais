# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Bash → Brush wrapper (all users, including root)
#
# Installs a high-priority `bash` shim into the system PATH so that any
# invocation of `bash` (interactive or scripted) is transparently redirected
# to Brush — the Rust, Bash-compatible shell.
#
# NixOS activation scripts and PAM tooling that reference bash via its full
# Nix store path (e.g. /nix/store/...-bash-.../bin/bash) are unaffected and
# continue to use the real bash.  Only PATH-based lookups hit this wrapper.
{ pkgs, lib, ... }:

let
  # Wrapper: a minimal shell script that exec-replaces itself with brush,
  # forwarding all arguments unchanged.  The shebang uses the Nix store path
  # for brush so the script is fully self-contained and path-independent.
  bashWrapper = pkgs.writeShellScriptBin "bash" ''
    exec ${pkgs.brush}/bin/brush "$@"
  '';
in
{
  # lib.hiPrio raises the package priority so NixOS's merge logic resolves the
  # `bash` name collision in favour of this wrapper rather than raising an
  # error or silently preferring the real bash.
  environment.systemPackages = [ (lib.hiPrio bashWrapper) ];
}
