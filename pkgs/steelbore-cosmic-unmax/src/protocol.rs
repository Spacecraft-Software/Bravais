// SPDX-License-Identifier: GPL-3.0-or-later
//
// Generated client bindings for the three COSMIC protocols this daemon needs.
//
// The XML is VENDORED under protocols/ rather than taken from the
// `cosmic-protocols` git repository, which is how cosmic-comp itself consumes
// it. That is deliberate: a git dependency would force a
// `cargoLock.outputHashes` entry in package.nix and pin a rev that has to be
// bumped by hand, whereas vendored XML plus `wayland-scanner` keeps the whole
// crate resolvable from crates.io alone. The files came from
// pop-os/cosmic-protocols rev 160b086 — the exact rev cosmic-comp 1.0.13 pins.
//
// `cosmic-workspace-unstable-v1` is here only because the toplevel protocols
// reference `zcosmic_workspace_handle_v1` in event signatures. Nothing in this
// daemon uses workspaces; wayland-scanner simply cannot generate the toplevel
// bindings without every cross-referenced interface in scope.
// The glob imports below are load-bearing, not laziness: wayland-scanner's
// generated code refers to sibling interfaces by bare name, so every
// cross-referenced protocol has to be in scope wholesale. That trips
// clippy::wildcard_imports 15 times, and it is the ONLY lint this file trips —
// established by starting from a broad suppression and letting
// `unfulfilled_lint_expectations` prune it down.
//
// `allow`, not `expect`, and deliberately so. M-LINT-OVERRIDE-EXPECT prefers
// `expect` precisely because it goes stale loudly — but it also carves out
// generated code, which this is. Empirically `expect` does not work here:
// `pedantic` is enabled at `warn` from Cargo.toml's `[lints.clippy]`, and a
// module-scope `expect` against a manifest-enabled group reports itself
// unfulfilled while still suppressing nothing useful. Naming the one lint
// keeps the suppression narrow: anything else the generated code starts
// tripping still surfaces as a warning.
#![allow(
    clippy::wildcard_imports,
    reason = "wayland-scanner requires cross-referenced interfaces in scope by bare name"
)]

pub mod workspace {
    use wayland_client;
    use wayland_client::protocol::*;

    pub mod __interfaces {
        use wayland_client::protocol::__interfaces::*;
        wayland_scanner::generate_interfaces!("protocols/cosmic-workspace-unstable-v1.xml");
    }
    use self::__interfaces::*;

    wayland_scanner::generate_client_code!("protocols/cosmic-workspace-unstable-v1.xml");
}

pub mod info {
    use wayland_client;
    use wayland_client::protocol::*;
    use wayland_protocols::ext::foreign_toplevel_list::v1::client::ext_foreign_toplevel_handle_v1;
    use wayland_protocols::ext::workspace::v1::client::ext_workspace_handle_v1;

    use super::workspace::zcosmic_workspace_handle_v1;

    pub mod __interfaces {
        use wayland_client::protocol::__interfaces::*;
        use wayland_protocols::ext::foreign_toplevel_list::v1::client::__interfaces::*;
        use wayland_protocols::ext::workspace::v1::client::__interfaces::*;

        use super::super::workspace::__interfaces::*;
        wayland_scanner::generate_interfaces!("protocols/cosmic-toplevel-info-unstable-v1.xml");
    }
    use self::__interfaces::*;

    wayland_scanner::generate_client_code!("protocols/cosmic-toplevel-info-unstable-v1.xml");
}

pub mod management {
    use wayland_client;
    use wayland_client::protocol::*;
    use wayland_protocols::ext::workspace::v1::client::ext_workspace_handle_v1;

    use super::info::zcosmic_toplevel_handle_v1;
    use super::workspace::zcosmic_workspace_handle_v1;

    pub mod __interfaces {
        use wayland_client::protocol::__interfaces::*;
        use wayland_protocols::ext::workspace::v1::client::__interfaces::*;

        use super::super::info::__interfaces::*;
        use super::super::workspace::__interfaces::*;
        wayland_scanner::generate_interfaces!(
            "protocols/cosmic-toplevel-management-unstable-v1.xml"
        );
    }
    use self::__interfaces::*;

    wayland_scanner::generate_client_code!("protocols/cosmic-toplevel-management-unstable-v1.xml");
}
