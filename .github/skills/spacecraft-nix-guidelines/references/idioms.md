# Nix Idioms & Translation Reference

This document provides quick reference tables and side-by-side examples to translate legacy or non-reproducible Nix patterns into modern, idiomatic, and override-friendly Nix code.

---

## 1. Quick Translation Targets

| Anti-Pattern | Modern Idiom | Notes |
| :--- | :--- | :--- |
| `rec { version = "1.0"; ... }` | `stdenv.mkDerivation (finalAttrs: { ... })` | Use `finalAttrs` to reference self safely in derivations. |
| `with pkgs; [ curl jq ]` | `let inherit (pkgs) curl jq; in [ curl jq ]` | Explicit `inherit` prevents scoping ambiguity. |
| `url = http://example.com;` | `url = "https://example.com";` | Bare URLs are deprecated; always quote them. |
| `src = ./. ;` | `src = lib.cleanSource ./. ;` | Filters out `.git` and build artifacts from the store. |
| `"${./my-file}"` | `builtins.path { path = ./my-file; }` | Provides precise control over store copies. |
| `import <nixpkgs> {}` | `inputs.nixpkgs` (in flakes) | Eliminate non-reproducible channel lookups. |
| `inputs.hm.inputs.nixpkgs...` | `follows = "nixpkgs"` in inputs | Prevents duplicate instantiations of the same flake. |
| `options.myOption = mkOption { ... }` | Include `type` and `description` | Ensure options are fully typed and self-documenting. |

---

## 2. Common Scenarios & Side-by-Side Mappings

### Self-Reference in Derivations
When a derivation's attributes need to reference each other (e.g. `src` using `version`), the legacy pattern used `rec`. The modern pattern uses a functional argument representing the final attributes (`finalAttrs`).

#### Anti-Pattern (using `rec`):
```nix
# If version is overridden, src STILL downloads version 1.0.0!
rec {
  pname = "cool-app";
  version = "1.0.0";
  src = fetchFromGitHub {
    owner = "spacecraft";
    repo = "cool-app";
    rev = "v${version}";
    hash = "sha256-...";
  };
}
```

#### Modern Idiom (using `finalAttrs`):
```nix
stdenv.mkDerivation (finalAttrs: {
  pname = "cool-app";
  version = "1.0.0";
  src = fetchFromGitHub {
    owner = "spacecraft";
    repo = "cool-app";
    rev = "v${finalAttrs.version}";
    hash = "sha256-...";
  };
})
```

---

### Namespace Scoping
The `with` keyword places all attributes of a set into the current namespace. While convenient for short lists, it hides the origins of variables and conflicts with local variables.

#### Anti-Pattern (using top-level `with`):
```nix
with pkgs;
with lib;
stdenv.mkDerivation {
  pname = "my-tool";
  buildInputs = [ curl jq git ];
}
```

#### Modern Idiom (explicit namespace and `inherit`):
```nix
{ lib, stdenv, curl, jq, git }:

stdenv.mkDerivation {
  pname = "my-tool";
  buildInputs = [ curl jq git ];
}
```
*Note: The package should be called via `pkgs.callPackage ./my-tool.nix {}`.*

---

### Preventing Build Pollution in Source Paths
By default, referencing a local path like `src = ./.` copies the entire directory—including large `.git` folders, build caches, and temporary files—into the Nix store, triggering unnecessary rebuilds.

#### Anti-Pattern:
```nix
stdenv.mkDerivation {
  pname = "my-project";
  version = "0.1.0";
  src = ./.; # Copies EVERYTHING (build artifacts, .git)
}
```

#### Modern Idiom:
```nix
{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "my-project";
  version = "0.1.0";
  src = lib.cleanSource ./.; # Filters out common VCS and build junk
}
```

---

### Formatting Lists and Sets (RFC 166)
Nix formatting has standardized on RFC 166. Legacy code often features commas in lists, or inconsistent vertical spacing.

#### Anti-Pattern (legacy style):
```nix
{
  buildInputs = [
    curl,
    jq,
    git
  ];
}
```

#### Modern Idiom (RFC 166 style):
```nix
{
  buildInputs = [
    curl
    jq
    git
  ];
}
```

---

## 3. NixOS / Home-Manager Options Mappings

When defining NixOS or Home-Manager modules, configure options with strong type guarantees.

#### Anti-Pattern (Weakly-typed or Untyped):
```nix
options.services.app = {
  enable = mkOption {
    default = false;
  };
  extraConfig = mkOption {
    default = {};
  };
};
```

#### Modern Idiom (Strongly-typed and Documented):
```nix
options.services.app = {
  enable = mkOption {
    type = types.bool;
    default = false;
    description = "Whether to enable the app service.";
  };
  extraConfig = mkOption {
    type = types.attrsOf types.str;
    default = {};
    description = "Extra configuration attributes (key-value strings).";
  };
};
```
