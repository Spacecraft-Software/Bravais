# Nushell Modules and Overlays Reference

This document outlines the standard architecture for writing modules, importing commands, and utilizing overlays in Nushell.

---

## 1. Writing Reusable Modules

A module in Nushell is a collection of commands, aliases, and environment variables defined in a `.nu` file. Only definitions prefixed with `export` are accessible outside the module.

### Module Structure
```nu
# modules/network.nu

# Internal helper (not exported, private to the module)
def build-headers [token: string] {
    { Authorization: $"Bearer ($token)" }
}

# Public command (exported)
export def get-telemetry [
    url: string
    --token: string
] {
    let headers = (build-headers $token)
    http get --headers $headers $url
}

# Public environment block
export-env {
    $env.NET_MODULE_LOADED = "true"
}
```

---

## 2. Importing Modules

Use the `use` command to bring exported definitions into scope.

### Standard Import
Loads all exported definitions, accessible via `<module-name> <command>`:
```nu
use modules/network.nu

network get-telemetry "https://api.spacecraft.org" --token "secret"
```

### Import Selected Definitions
Imports specific commands directly into the current namespace:
```nu
use modules/network.nu get-telemetry

get-telemetry "https://api.spacecraft.org" --token "secret"
```

---

## 3. Managing Environment Layers with Overlays

Overlays allow you to load modules as activation layers. Any environment variables, aliases, or commands defined inside the module are active as long as the overlay is in use.

### Activating an Overlay
Use `overlay use` to activate a module layer.

```nu
# Load environment configurations and commands
overlay use modules/network.nu

# Check that exported environment variables are present
print $env.NET_MODULE_LOADED  # "true"
```

### Discarding an Overlay
Remove the overlay and clean up all environment overrides.

```nu
overlay hide network
```

---

## 4. Script Execution Entry Points (`main`)

For standalone Nushell scripts (`.nu` files) intended to be executed directly, define a command named `main`. When the script is run, Nushell maps command line parameters directly to the `main` signature.

### Example Script: `deploy.nu`
```nu
#!/usr/bin/env nu

# Deploys a spacecraft package to the selected target
def main [
    target: string             # Target node (e.g., core, payload)
    --version: string = "1.0"  # Target version
    --verbose                  # Log detailed output
] {
    if $verbose {
        print $"Starting deployment of version ($version) to ($target)..."
    }
    # deployment pipeline
}
```
Run this script via:
```sh
nu deploy.nu payload --version 2.1 --verbose
```
