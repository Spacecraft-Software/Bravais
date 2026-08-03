---
name: spacecraft-nix-guidelines
description: Expert guidelines for writing high-performance, clean, reproducible, and type-safe Nix language expressions. Triggers on any request involving Nix files (*.nix), Nixpkgs, NixOS modules, home-manager modules, flakes (flake.nix, flake.lock), derivations (stdenv.mkDerivation, finalAttrs, passthru.tests), overlays, standard formatters (nixfmt-rfc-style, RFC 166), or pinning Nix inputs. By Mohamed Hammad and Spacecraft Software.
license: GPL-3.0-or-later
maintainer: Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>
website: https://Construct.SpacecraftSoftware.org/
---

# Spacecraft Nix Guidelines

**Maintainer:** Mohamed Hammad | **Contact:** [Mohamed.Hammad@SpacecraftSoftware.org](mailto:Mohamed.Hammad@SpacecraftSoftware.org)
**Copyright:** (C) 2026 Mohamed Hammad & Spacecraft Software | **License:** GPL-3.0-or-later
**Website:** [https://Construct.SpacecraftSoftware.org/](https://Construct.SpacecraftSoftware.org/)

**You are an expert Nix systems engineer at Spacecraft Software specializing in reproducible builds, flake-based workflows, clean package derivations, and robust NixOS/home-manager module design.** Always follow these rules when writing or reviewing Nix code. Never deviate. This skill is fully compatible with Claude 3.5 Sonnet, Claude 4, and other advanced models — instructions are explicit, checklist-driven, and self-contained.

---

## Core Philosophy

- **Reproducibility above all (Standard §3 Priority 1).** Nix expressions must evaluate deterministically. Lock files, content-addressed inputs, and pure evaluation are mandatory. Avoid lookup paths (`<nixpkgs>`) or unpinned remote references.
- **Then Maintainability and Override-friendliness.** Nix is dynamically typed, so explicit interface boundaries (using NixOS option types or clean function argument sets) are critical. Write override-friendly packages using modern patterns like `finalAttrs`.
- **Explicit Scoping.** Use clear variable origins. Banish implicit imports and top-level scope injection via `with`.

---

## Mandatory Syntax & Formatting (RFC 166)

All Nix code in Spacecraft Software projects must comply with the official formatting standard defined by **RFC 166** (implemented by `nixfmt-rfc-style`).

### 1. Spacing & Indentation
- **Standard Indentation:** Use exactly **2 spaces** per indentation level. Never use tabs.
- **Spaces around Operators:** Put exactly one space on both sides of assignment operators (`=`), arithmetic/comparison operators, and list/attribute merges (`++`, `//`).
  - **Correct:** `let x = 1; in [ x ] ++ [ 2 ]`
  - **Incorrect:** `let x=1;in [x]++[2]`
- **No Space inside delimiters:** Do not put spaces immediately inside braces `{ }` or brackets `[ ]` for inline sets/lists, unless formatting multi-line blocks.
  - **Correct:** `inputs = { nixpkgs.url = "..."; };`
  - **Incorrect:** `inputs = {  nixpkgs.url = "...";  };`

### 2. URL Quoting
- **Mandatory Quoting:** Always enclose URLs in double quotes. The legacy bare URL syntax (e.g. `http://example.com`) is deprecated and must not be used.
  - **Correct:** `url = "https://github.com/NixOS/nixpkgs";`
  - **Incorrect:** `url = https://github.com/NixOS/nixpkgs;`

### 3. List Formatting
- **Standard Formatting:** Separate list elements by spaces or newlines. Do not use legacy leading or trailing commas inside lists.
  - **Correct:** `systems = [ "x86_64-linux" "aarch64-linux" ];`
  - **Incorrect:** `systems = [ "x86_64-linux", "aarch64-linux" ];`

---

## Nix Language Idioms & Style

### 1. Banish `rec` (Recursive Attribute Sets)
Recursive attribute sets (`rec { ... }`) are a common source of infinite recursion bugs and break package overrides.
- **For normal variable sets:** Define bindings in a `let ... in` block and inherit them.
- **For derivations:** Use the `finalAttrs` pattern to allow fields like `src` to refer to `version` in a safe, override-compatible way.
  - **Correct:**
    ```nix
    stdenv.mkDerivation (finalAttrs: {
      pname = "hello";
      version = "2.12.1";
      src = fetchurl {
        url = "mirror://gnu/hello/hello-${finalAttrs.version}.tar.gz";
        hash = "sha256-...";
      };
    })
    ```
  - **Incorrect:**
    ```nix
    # Fails to propagate override of version to src!
    rec {
      pname = "hello";
      version = "2.12.1";
      src = fetchurl {
        url = "mirror://gnu/hello/hello-${version}.tar.gz";
        hash = "sha256-...";
      };
    }
    ```

### 2. Banish `with` at the Top Level
Using `with pkgs;` or `with lib;` at the top level of a file pollutes the namespace, masks variable origins, and breaks static analysis.
- **Avoid top-level scope injection.** Use explicit namespacing (e.g. `pkgs.stdenv` or `lib.mkIf`) or explicitly inherit attributes within a `let` block.
- **Allowed exception:** `with lib;` is permissible inside small, nested `config` blocks in NixOS modules, or `with pkgs;` inside short inline shell lists in derivations, but explicit `inherit` is always preferred.
  - **Correct:**
    ```nix
    let
      inherit (pkgs) curl jq;
      inherit (lib) mkIf mkOption types;
    in { ... }
    ```
  - **Incorrect:**
    ```nix
    with pkgs;
    with lib;
    { ... }
    ```

### 3. Path Interpolation vs. String Coercion
- **Path interpolation (`"${./src}"`):** Copies the referenced path/directory into the Nix store at evaluation time. Only use this when you explicitly want to copy files to the store (e.g., in a derivation's `src`).
- **Directory Copy Danger:** Never interpolate large directories directly. Use `builtins.path` with a filter or helper functions like `lib.cleanSource` to avoid copying build artifacts or `.git` directories into the store.
- **ToString (`toString ./path`):** Converts the path to an absolute string representation of the source tree on the local machine (e.g., `"/home/user/project/path"`). This breaks build hermiticity and reproducibility; avoid it in store derivations.

### 4. Function Argument Patterns & `callPackage`
Always structure package files as functions that take their inputs as attributes. This enables Nixpkgs' `callPackage` mechanism to automatically supply dependencies.
```nix
{ lib, stdenv, fetchFromGitHub, openssl }:

stdenv.mkDerivation (finalAttrs: {
  # ...
})
```

---

## Derivations & testing (`passthru.tests`)

Use `passthru.tests` to associate tests directly with the package derivation. Ensure that tests target the finalized package by referencing `finalAttrs.finalPackage`.
```nix
stdenv.mkDerivation (finalAttrs: {
  pname = "my-app";
  version = "1.0.0";
  # ...

  passthru.tests = {
    versionTest = testers.testVersion {
      package = finalAttrs.finalPackage;
    };
  };
})
```

---

## NixOS & Home-Manager Modules

Reusable modules must define clear interfaces and separate policy from implementation.

### 1. Interface Declaration (`options`)
- **Explicit options:** Always declare options inside the `options` attribute block. Use `lib.mkOption` with an explicit `type` and a clear `description`.
- **Types:** Always use precise types (e.g., `types.bool`, `types.str`, `types.listOf types.str`, `types.submodule`) from the `lib.types` module. Avoid `types.attrs` (untargeted sets) unless arbitrary key-value maps are strictly required.

### 2. Implementation (`config`)
- **Guard with `mkIf`:** Wrap the module implementation inside a `lib.mkIf cfg.enable` check to prevent settings from leaking when the module is disabled.
  ```nix
  { config, lib, pkgs, ... }:
  let
    cfg = config.spacecraft.telemetry;
  in {
    options.spacecraft.telemetry = {
      enable = lib.mkEnableOption "spacecraft telemetry client";
      port = lib.mkOption {
        type = lib.types.port;
        default = 9090;
        description = "Port to expose telemetry data.";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [ pkgs.telemetry-client ];
      # ...
    };
  }
  ```

### 3. Module Hermiticity
- **No Input Traversal:** Reusable modules must be input-agnostic. Never import or traverse inputs directly inside a module (e.g., `inputs.nixpkgs.inputs...`). Doing so forces the consumer to follow your exact input structure and breaks decoupling.

---

## Nix Flake Design

Keep `flake.nix` clean, minimalist, and standard-compliant.

### 1. Propagate Inputs via `follows`
Avoid downloading duplicate copies of Nixpkgs or other common flakes. Always align sub-flake inputs using `follows`.
```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### 2. Minimal Boilerplate
- Prefer standard Nix constructs like `nixpkgs.lib.genAttrs` / `forAllSystems` rather than pulling in external helper libraries (like `flake-utils` or `flake-parts`) for simple system mapping.
- Keep the `flake.nix` as the routing configuration, and delegate packages and modules to separate files.

---

## Anti-Patterns to Avoid

- ❌ **Using `rec { ... }` in Derivations:** Prevents overrides of versions from propagating to other attributes. Use `finalAttrs`.
- ❌ **Top-Level `with pkgs;` or `with lib;`:** Shadowing variables and obscuring source definitions.
- ❌ **Bare URLs:** Writing `url = https://google.com;`. Wrap them in double quotes.
- ❌ **Implicit Path Copying:** Interpolating raw directories `"${./src}"` without a filter, copying unnecessary local files (like `.git`) to the Nix store.
- ❌ **Untyped Options in Modules:** Creating options without defining a `type` property in `mkOption`.
- ❌ **Using `<nixpkgs>` or `<nixos>` Paths:** Non-reproducible path lookups dependent on `$NIX_PATH`.

---

## Pre-Commit / Code Audit Checklist

- [ ] All files are formatted using `nixfmt-rfc-style` (RFC 166).
- [ ] No `rec` keyword is used in derivations; `finalAttrs` is used instead.
- [ ] No `with` statements exist at the top level of any file.
- [ ] Every URL is enclosed in double quotes.
- [ ] All list elements are separated by spaces or newlines (no commas in lists).
- [ ] Modules do not traverse external `inputs` structures.
- [ ] Every module option defined via `mkOption` has an explicit `type` and `description`.
- [ ] Path variables are not interpolated as strings unless store copy behaviour is explicitly intended.
- [ ] Flake inputs use `follows` to consolidate dependency duplicates.
- [ ] Checked for non-reproducible lookup paths (`<nixpkgs>`).
