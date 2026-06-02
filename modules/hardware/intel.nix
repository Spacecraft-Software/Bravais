# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Intel CPU Optimizations
{ config, lib, ... }:

let
  cfg = config.steelbore.hardware.intel;

  # ── CachyOS shared components (v1, v3, v4) ────────────────────────────────
  # Source: github.com/CachyOS/docker-makepkg (makepkg.conf per level)
  cachyosCommonCFlags =
    "-O3 -pipe -fno-plt -fexceptions "
    + "-Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security "
    + "-fstack-clash-protection -fcf-protection";

  cachyosLdFlags =
    "-Wl,-O1 -Wl,--sort-common -Wl,--as-needed "
    + "-Wl,-z,relro -Wl,-z,now -Wl,-z,pack-relative-relocs";

  # ── ALHP shared components (v2) ───────────────────────────────────────────
  # Source: github.com/an0nfunc/ALHP (flags.yaml)
  # ALHP is the authoritative v2 source; CachyOS skips v2 entirely.
  # ALHP trades security flags for -mpclmul and -falign-functions=32 (LTO).
  alhpLdFlags =
    "-Wl,-O1 -Wl,--sort-common -Wl,--as-needed "
    + "-Wl,-z,relro -Wl,-z,now";

  # ── Per-level flag sets ────────────────────────────────────────────────────
  flagsByLevel = {

    # v1 — CachyOS baseline (matches CachyOS x86-64 default repo / earlier table)
    v1 = {
      cFlags  = "-march=x86-64 -mtune=native ${cachyosCommonCFlags}";
      ldFlags = cachyosLdFlags;
      rust    = "-C target-cpu=x86-64 -C opt-level=3 -Clink-arg=-z -Clink-arg=pack-relative-relocs";
      goamd64 = "v1";
    };

    # v2 — ALHP-derived (SSE4.2 / POPCNT / CX16)
    v2 = {
      cFlags  = "-march=x86-64-v2 -mtune=native -O3 -mpclmul -falign-functions=32";
      ldFlags = alhpLdFlags;
      rust    = "-Copt-level=3 -Ctarget-cpu=x86-64-v2 -Clink-arg=-z -Clink-arg=pack-relative-relocs";
      goamd64 = "v2";
    };

    # v3 — CachyOS-derived (AVX2 / BMI1/2 / FMA / MOVBE)
    v3 = {
      cFlags  = "-march=x86-64-v3 -mtune=native -mpclmul ${cachyosCommonCFlags}";
      ldFlags = cachyosLdFlags;
      rust    = "-C target-cpu=x86-64-v3 -C opt-level=3 -Clink-arg=-z -Clink-arg=pack-relative-relocs";
      goamd64 = "v3";
    };

    # v4 — CachyOS-derived (AVX-512F/BW/CD/DQ/VL)
    v4 = {
      cFlags  = "-march=x86-64-v4 -mtune=native -mpclmul ${cachyosCommonCFlags}";
      ldFlags = cachyosLdFlags;
      rust    = "-C target-cpu=x86-64-v4 -C opt-level=3 -Clink-arg=-z -Clink-arg=pack-relative-relocs";
      goamd64 = "v4";
    };
  };

  flags = flagsByLevel.${cfg.marchLevel};

in
{
  options.steelbore.hardware.intel = {
    enable = lib.mkEnableOption "Intel CPU optimizations";

    marchLevel = lib.mkOption {
      type    = lib.types.enum [ "v1" "v2" "v3" "v4" ];
      default = "v4";
      description = ''
        x86-64 microarchitecture level used for all compiler flags.
        All levels use -mtune=native. RUSTFLAGS include -Clink-arg=pack-relative-relocs on all levels.
          v1 — baseline x86-64 (SSE2)         CachyOS baseline flags
          v2 — SSE4.2 / POPCNT / CX16         ALHP-derived flags
          v3 — AVX2 / BMI1/2 / FMA / MOVBE    CachyOS-derived flags  (CachyOS default)
          v4 — AVX-512F/BW/CD/DQ/VL           CachyOS-derived flags  (Bravais default)
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "kvm-intel" ];

    hardware.cpu.intel.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;

    environment.sessionVariables = {
      CFLAGS    = flags.cFlags;
      CXXFLAGS  = "${flags.cFlags} -Wp,-D_GLIBCXX_ASSERTIONS";
      LDFLAGS   = flags.ldFlags;
      RUSTFLAGS = flags.rust;
      GOAMD64   = flags.goamd64;
    };
  };
}
