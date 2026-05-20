# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Bash → Brush wrapper (system-wide, all users, including root)
#
# Three-part strategy:
#
#   1. PATH wrapper  — a high-priority `bash` shim in the system PATH so that
#      any PATH-based invocation of `bash` dispatches to Brush.
#
#   2. /bin/bash override — an activation script that re-links /bin/bash to
#      Brush after NixOS sets up the standard symlink, making `#!/bin/bash`
#      shebangs and any caller that hardcodes /bin/bash use Brush as well.
#
#   3. bash-real shim — a `bash-real` command in the system PATH that always
#      invokes the genuine GNU Bash, giving a safe escape hatch when real Bash
#      behaviour is required.
{ pkgs, lib, ... }:

let
  # 1. PATH wrapper: exec-replaces itself with Brush, forwarding all args.
  #    The shebang references the real bash store path so the wrapper itself
  #    is not subject to its own redirect.
  bashWrapper = pkgs.writeScriptBin "bash" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.brush}/bin/brush "$@"
  '';

  # 3. bash-real shim: always invokes the real GNU Bash.
  bashReal = pkgs.writeScriptBin "bash-real" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.bash}/bin/bash "$@"
  '';
in
{
  environment.systemPackages = [
    # lib.hiPrio ensures the `bash` collision resolves to our wrapper.
    (lib.hiPrio bashWrapper)
    bashReal
  ];

  # 2. Override /bin/bash after NixOS's own `binsh` activation script runs so
  #    that scripts using the #!/bin/bash shebang also land on Brush.
  #    NixOS activation scripts that reference bash by its full Nix store path
  #    (e.g. /nix/store/...-bash-x.y/bin/bash) are unaffected.
  system.activationScripts.brushBashOverride = {
    deps = [ "binsh" ];
    text = ''
      ln -sf ${pkgs.brush}/bin/brush /bin/bash
    '';
  };
}
