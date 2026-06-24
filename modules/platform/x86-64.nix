# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — x86-64 platform policy (ISA level + compiler/linker flags)
#
# Vendor-neutral. Owns the x86-64-vN microarchitecture level and the
# compiler/linker flag policy derived from it. CPU-vendor settings (Intel
# microcode, kvm-intel) live in modules/hardware/. Set the level per machine
# via steelbore.platform.x86_64.marchLevel.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.steelbore.platform.x86_64;

  # gcc-unwrapped exposes gcc-ar / gcc-nm / gcc-ranlib (LTO-plugin-aware
  # wrappers around binutils ar/nm/ranlib). The wrapped pkgs.gcc does not
  # ship them, and on NixOS there is no /usr/lib/bfd-plugins for plain
  # `ar` to autoload liblto_plugin.so, so static-lib LTO breaks without
  # these. See AGENTS.md §8.11.
  gccUnwrapped = pkgs.gcc.cc;

  # ── Common CFLAGS ─────────────────────────────────────────────────────────
  # Removed vs original:
  #   -Werror=format-security   (breaks legit user builds; keep diag flags)
  #   duplicated hardening      (already in nixpkgs stdenv hardeningEnable)
  # Kept: optimization, LTO, format diagnostics (warning-only),
  #       stack-clash, CET — these are useful in user-driven builds too.
  commonCFlags =
    "-O3 -pipe -fno-plt -fexceptions -flto=auto "
    + "-Wp,-D_FORTIFY_SOURCE=3 -Wformat -Wformat-security "
    + "-fstack-clash-protection -fcf-protection";

  # ── Linker flags ──────────────────────────────────────────────────────────
  # Switched gold → mold:
  #   • gold is deprecated upstream (binutils 2.44, 2025).
  #   • gold does NOT support -z pack-relative-relocs (silent or fatal).
  #   • mold >=1.4 supports it.
  #   • mold has correct GCC LTO plugin handling via --plugin.
  #   • 5–10× faster wall-clock link time vs bfd/gold.
  commonLdFlags =
    "-fuse-ld=mold -Wl,-O1 -Wl,--sort-common -Wl,--as-needed "
    + "-Wl,-z,relro -Wl,-z,now -Wl,-z,pack-relative-relocs";

  # ALHP variant — same linker change rationale.
  alhpLdFlags =
    "-fuse-ld=mold -Wl,-O1 -Wl,--sort-common -Wl,--as-needed " + "-Wl,-z,relro -Wl,-z,now";

  # ── Per-level flag sets ────────────────────────────────────────────────────
  flagsByLevel = {

    # v1 — baseline x86-64 (SSE2). -mtune=generic to preserve portability
    # of the v1 profile (was -mtune=native, which defeats the point).
    v1 = {
      cFlags = "-march=x86-64 -mtune=generic ${commonCFlags}";
      ldFlags = commonLdFlags;
      rust = "-C target-cpu=x86-64 -C opt-level=3 -Clink-arg=-fuse-ld=mold -Clink-arg=-Wl,-z,pack-relative-relocs";
      goamd64 = "v1";
    };

    # v2 — ALHP-derived (SSE4.2 / POPCNT / CX16). -mtune=generic for portability.
    v2 = {
      cFlags = "-march=x86-64-v2 -mtune=generic -O3 -mpclmul -falign-functions=32 -flto=auto";
      ldFlags = alhpLdFlags;
      rust = "-Copt-level=3 -Ctarget-cpu=x86-64-v2 -Clink-arg=-fuse-ld=mold";
      goamd64 = "v2";
    };

    # v3 — CachyOS-derived (AVX2 / BMI1/2 / FMA / MOVBE).
    v3 = {
      cFlags = "-march=x86-64-v3 -mtune=native -mpclmul ${commonCFlags}";
      ldFlags = commonLdFlags;
      rust = "-C target-cpu=x86-64-v3 -C opt-level=3 -Clink-arg=-fuse-ld=mold -Clink-arg=-Wl,-z,pack-relative-relocs";
      goamd64 = "v3";
    };

    # v4 — CachyOS-derived (AVX-512F/BW/CD/DQ/VL).
    v4 = {
      cFlags = "-march=x86-64-v4 -mtune=native -mpclmul ${commonCFlags}";
      ldFlags = commonLdFlags;
      rust = "-C target-cpu=x86-64-v4 -C opt-level=3 -Clink-arg=-fuse-ld=mold -Clink-arg=-Wl,-z,pack-relative-relocs";
      goamd64 = "v4";
    };
  };

  flags = flagsByLevel.${cfg.marchLevel};

in
{
  options.steelbore.platform.x86_64 = {
    enable = lib.mkEnableOption "x86-64 platform optimizations (ISA level + build flags)";

    marchLevel = lib.mkOption {
      type = lib.types.enum [
        "v1"
        "v2"
        "v3"
        "v4"
      ];
      default = "v4";
      description = ''
        x86-64 microarchitecture level used for all compiler flags.
        v1/v2 use -mtune=generic (portable); v3/v4 use -mtune=native.
        RUSTFLAGS include -Clink-arg=-fuse-ld=mold on all levels;
        -Wl,-z,pack-relative-relocs on v1/v3/v4 (omitted on v2 per ALHP).
          v1 — baseline x86-64 (SSE2)         CachyOS baseline flags
          v2 — SSE4.2 / POPCNT / CX16         ALHP-derived flags
          v3 — AVX2 / BMI1/2 / FMA / MOVBE    CachyOS-derived flags  (CachyOS default)
          v4 — AVX-512F/BW/CD/DQ/VL           CachyOS-derived flags  (Bravais default)
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # mold must be available system-wide so -fuse-ld=mold can resolve it
    # in user-driven builds. (nixos-rebuild itself sandboxes its env, so
    # this only affects the interactive shell.)
    environment.systemPackages = [ pkgs.mold ];

    environment.sessionVariables = {
      CFLAGS = flags.cFlags;
      CXXFLAGS = "${flags.cFlags} -Wp,-D_GLIBCXX_ASSERTIONS";
      LDFLAGS = flags.ldFlags;
      LTOFLAGS = "-flto=auto";
      RUSTFLAGS = flags.rust;
      GOAMD64 = flags.goamd64;

      # LTO-aware archive tools — required on NixOS because the wrapped
      # `gcc` package does not put gcc-ar/gcc-nm/gcc-ranlib on PATH and
      # plain binutils `ar`/`nm`/`ranlib` cannot autoload liblto_plugin.so
      # (there is no /usr/lib/bfd-plugins on NixOS).
      AR = "${gccUnwrapped}/bin/gcc-ar";
      NM = "${gccUnwrapped}/bin/gcc-nm";
      RANLIB = "${gccUnwrapped}/bin/gcc-ranlib";
    };
  };
}
