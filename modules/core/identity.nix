# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — the operating system names itself Steelbore OS
#
# Always on, no enable option: the OS identity is not a feature to toggle.
# Every value comes from lib/identity.nix via `steelboreIdentity`
# (specialArgs) — nothing here retypes a name, URL or codename (PLAN.md M1,
# P-005..P-007).
#
# What these options reach, beyond /etc/os-release and /etc/lsb-release:
#   - `distroName` titles the systemd-boot entries (the builder substitutes
#     it) and the getty greeting line ("<<< Welcome to Steelbore OS … >>>").
#   - `distroId` is passed to switch-to-configuration as DISTRO_ID and names
#     DEFAULT_HOSTNAME. The first switch away from ID=nixos is checked
#     against the OLD /etc/os-release, which still says `nixos`; it passes
#     only because /etc/NIXOS exists (setup-etc.pl recreates the marker on
#     every activation while system.etc.overlay stays off). See PLAN.md P-004.
#   - boot.initrd.osRelease is generated from the same merged contents
#     (extraOSReleaseArgs included), so the initrd's os-release carries the
#     same NAME/URLs/codename with " (Initrd)" appended to PRETTY_NAME.
{
  config,
  lib,
  steelboreIdentity,
  steelborePalette,
  ...
}:

let
  id = steelboreIdentity;
  inherit (config.system.nixos) release;

  # D3: Steelbore OS's own star-name codename for this NixOS release. A
  # release missing from lib/identity.nix fails evaluation here on purpose.
  codename = id.codenameFor release;
  versionString = "${release} (${codename})";
  prettyName = "${id.fullName} ${versionString}";

  # os-release ANSI_COLOR wants "0;38;2;R;G;B". The palette already decodes
  # hex to decimal channels (`convert.rgbTriple` → "R,G,B", the Konsole
  # form); only the separator differs, so reuse it rather than re-decode.
  # `accent` is a role token — never a brand colour name (§11.4).
  accentSgr = "0;38;2;" + lib.replaceStrings [ "," ] [ ";" ] (
    steelborePalette.convert.rgbTriple steelborePalette.accent
  );
in
{
  system.nixos = {
    # distroName, distroId, vendorName and vendorId are `internal = true`
    # upstream (nixos/modules/misc/version.nix): settable but undocumented,
    # so a nixpkgs bump could rename or drop them without a release note.
    # The regression check is evaluating BOTH channels' os-release
    # (bravais-thinkpad and bravais-thinkpad-unstable) after every bump.
    distroName = id.name;
    distroId = id.id; # ≠ "nixos", so upstream emits ID_LIKE=nixos (D1)
    vendorName = id.vendor;
    vendorId = id.vendorId; # → CPE_NAME=cpe:/o:spacecraft-software:steelbore:<rel> (D2)
    variantName = id.variant;
    variant_id = id.variantId;

    # No `system.nixos.tags` (P-011): tags lengthen every boot-menu label and
    # nixos-version string; the variant already names the edition.

    # Upstream blanks the five URLs and ANSI_COLOR once ID ≠ nixos, and
    # hardcodes LOGO = nix-snowflake, so all of them are supplied here.
    extraOSReleaseArgs = {
      HOME_URL = id.urls.home;
      VENDOR_URL = id.urls.vendor;
      DOCUMENTATION_URL = id.urls.documentation;
      SUPPORT_URL = id.urls.support;
      BUG_REPORT_URL = id.urls.bugReport;
      ANSI_COLOR = accentSgr;
      # Emblem icon name installed by pkgs/steelbore-branding (D4).
      LOGO = id.logo;

      # D3: replace NixOS's codename in every user-facing os-release field.
      # `system.nixos.codeName` itself is readOnly upstream, so
      # `nixos-version` and the bootspec label keep NixOS's name — accepted.
      VERSION = versionString;
      VERSION_CODENAME = lib.toLower codename;
      PRETTY_NAME = prettyName;
    };

    # Same D3 override in lsb-release, kept consistent with os-release.
    extraLSBReleaseArgs = {
      LSB_VERSION = versionString;
      DISTRIB_CODENAME = lib.toLower codename;
      DISTRIB_DESCRIPTION = prettyName;
    };
  };
}
