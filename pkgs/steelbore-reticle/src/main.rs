// SPDX-License-Identifier: GPL-3.0-or-later
//
// steelbore-reticle — mouse selection, paste and mouse reporting on the Linux
// virtual consoles. A Rust replacement for gpm's console role.
//
// `steelbore-reticle run` is the system service. On whichever VT is in the
// foreground and in text mode it:
//   - draws the pointer (the kernel inverts the cell under it);
//   - selects by character on a left drag, by word on a double click and by
//     line on a triple click; a right click (or right drag) extends the
//     selection from where it started; a middle click pastes into the VT;
//   - hands the clicks to a program that asked for xterm mouse reporting
//     (htop, mc, vim with `mouse=a`, …) instead of selecting.
//
// The kernel does all of the console work. Everything above is one `ioctl`:
// TIOCLINUX with TIOCL_SETSEL (pointer, selection, mouse report),
// TIOCL_PASTESEL, and TIOCL_GETMOUSEREPORTING. This tool only turns pointer
// motion into a cell and decides which call to make, so the console itself is
// never replaced: tuigreet, getty, the palette in `console.colors` and the
// keymap all stay as they are.
//
// Input comes from every pointing device through evdev, never grabbed, so a
// compositor on another VT sees every event as before. Devices are found at
// start-up and through inotify on /dev/input, which also picks up xremap's
// virtual device: xremap grabs a mouse and re-emits it, and reading the
// re-emitted device is how a grabbed mouse keeps working here.
//
// What it deliberately does not do, compared with gpm:
//   - no /dev/gpmctl client protocol; programs fall back to the kernel's
//     xterm-style reporting, which this tool drives;
//   - no wheel: the kernel console has had no scrollback since Linux 5.9, and
//     its mouse report has no wheel buttons;
//   - a small touchpad model: one-finger motion, tap to click (one finger
//     left, two right, three middle) and clickfinger buttons. Palm rejection
//     and tap-and-drag are libinput's job and are not reimplemented.
// Absolute pointers with a left button (a tablet in mouse mode, the USB
// tablet a virtual machine's display attaches) map straight onto the grid.
//
// Standard §3.1: no `unwrap`/`expect` on a fallible runtime path; every
// `unsafe` block is one of the three ioctl wrappers in console.rs.
// Standard §3.2: single-threaded by design. Every source is a file descriptor,
// so one poll(2) waits on all of them; there is no shared state to lock and
// no workload a second thread could speed up.
//
// `mimalloc` (M-MIMALLOC-APPS) is intentionally omitted: the daemon idles in
// poll(2) and allocates a few small vectors per pointer event.
//
// Rust guideline compliant 2026-10-19

mod console;
mod daemon;
mod input;
mod output;

use std::fs::File;
use std::path::Path;

use clap::{Parser, Subcommand};
use serde_json::{json, Value};

use output::{AppError, ColorWhen, Exit, Format, Level, Out};

const ABOUT: &str = "Mouse selection, paste and mouse reporting on the Linux virtual consoles (a Rust gpm replacement).";

/// The fields of a `device list` record, in output order.
const DEVICE_FIELDS: [&str; 3] = ["path", "kind", "name"];
/// The fields of a `console get` record, in output order.
const CONSOLE_FIELDS: [&str; 5] = ["vt", "mode", "columns", "rows", "mouse_reporting"];

#[derive(Parser, Debug)]
#[command(
    name = "steelbore-reticle",
    version,
    // §15.2: --version carries the maintainer and the project URL.
    long_version = concat!(
        env!("CARGO_PKG_VERSION"), "\n",
        "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>\n",
        "Copyright (C) 2026 Mohamed Hammad & Spacecraft Software  |  License: GPL-3.0-or-later\n",
        env!("STEELBORE_OS_URL")
    ),
    about = ABOUT,
    after_help = concat!(
        "EXAMPLES:\n",
        "  steelbore-reticle run                       The service (needs CAP_SYS_ADMIN)\n",
        "  steelbore-reticle run --speed 1.5           The same, pointer 50 % faster\n",
        "  steelbore-reticle device list               Pointing devices it would use\n",
        "  steelbore-reticle device list --json --fields path,kind\n",
        "  steelbore-reticle console get --json        Foreground VT, text or graphics, size\n",
        "  steelbore-reticle schema                    JSON Schema of this command surface\n",
        "\n",
        "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>\n",
        env!("STEELBORE_OS_URL")
    )
)]
#[expect(
    clippy::struct_excessive_bools,
    reason = "this IS the global flag surface the CLI Standard fixes; enums would only rename the same switches"
)]
struct Cli {
    #[command(subcommand)]
    command: Cmd,

    /// Emit machine-readable JSON (alias for --format json)
    #[arg(long, global = true)]
    json: bool,

    /// Output format
    #[arg(long, global = true, value_enum)]
    format: Option<Format>,

    /// Restrict each record to these fields (comma-separated)
    #[arg(long, global = true, value_delimiter = ',')]
    fields: Vec<String>,

    /// Colour policy
    #[arg(long, global = true, value_enum, default_value = "auto")]
    color: ColorWhen,

    /// Disable colour (equivalent to --color never)
    #[arg(long, global = true)]
    no_color: bool,

    /// Lower the severity floor to info
    #[arg(long, short, global = true, conflicts_with = "quiet")]
    verbose: bool,

    /// Raise the severity floor to errors only
    #[arg(long, short, global = true)]
    quiet: bool,
}

#[derive(Subcommand, Debug)]
enum Cmd {
    /// Run the console mouse (the system service)
    Run {
        /// Pointer speed multiplier, 0.1 to 10
        #[arg(long, default_value_t = 1.0, value_parser = parse_speed)]
        speed: f64,
    },
    /// Pointing devices
    Device {
        #[command(subcommand)]
        action: DeviceCmd,
    },
    /// The foreground virtual console
    Console {
        #[command(subcommand)]
        action: ConsoleCmd,
    },
    /// Emit the JSON Schema of the command surface
    Schema,
    /// Emit a compact capability manifest
    Describe,
}

#[derive(Subcommand, Debug)]
enum DeviceCmd {
    /// List the pointing devices `run` would read
    List,
}

#[derive(Subcommand, Debug)]
enum ConsoleCmd {
    /// Show the foreground VT: number, text or graphics, size, mouse reporting
    Get,
}

/// Bounds-checked here so a hallucinated `--speed 1e9` fails at parse time
/// (exit 2) rather than flinging the pointer into a corner.
fn parse_speed(s: &str) -> Result<f64, String> {
    let v: f64 = s.parse().map_err(|_| format!("{s:?} is not a number"))?;
    if (0.1..=10.0).contains(&v) {
        Ok(v)
    } else {
        Err(format!("{v} is outside 0.1 to 10"))
    }
}

fn main() -> std::process::ExitCode {
    let cli = match Cli::try_parse() {
        Ok(cli) => cli,
        Err(e) => return usage_error(&e),
    };

    let color = if cli.no_color {
        ColorWhen::Never
    } else {
        cli.color
    };
    let format = if cli.json {
        Some(Format::Json)
    } else {
        cli.format
    };
    let out = Out::resolve(format, color, cli.verbose, cli.quiet);

    let code = match &cli.command {
        Cmd::Run { speed } => daemon::run(out, *speed),
        Cmd::Device {
            action: DeviceCmd::List,
        } => cmd_device_list(out, &cli.fields),
        Cmd::Console {
            action: ConsoleCmd::Get,
        } => cmd_console_get(out, &cli.fields),
        Cmd::Schema => cmd_schema(out),
        Cmd::Describe => cmd_describe(out),
    };

    #[expect(
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        reason = "exit codes are 0..=4 by construction; the enum has no other values"
    )]
    std::process::ExitCode::from(code as u8)
}

/// A parse failure. `--help` and `--version` print as clap renders them;
/// every real usage error becomes the structured error object in machine
/// mode, so an agent gets `hint` and exit 2 rather than prose.
fn usage_error(e: &clap::Error) -> std::process::ExitCode {
    use clap::error::ErrorKind;
    if matches!(
        e.kind(),
        ErrorKind::DisplayHelp
            | ErrorKind::DisplayVersion
            | ErrorKind::DisplayHelpOnMissingArgumentOrSubcommand
    ) {
        let _ = e.print();
        return std::process::ExitCode::from(if e.use_stderr() { 2 } else { 0 });
    }
    // The flags were not parsed, so read the format request off argv.
    let args: Vec<String> = std::env::args().collect();
    let asked = |f: &str| {
        args.iter().any(|a| a == &format!("--format={f}"))
            || args.windows(2).any(|w| w[0] == "--format" && w[1] == f)
    };
    let format = if args.iter().any(|a| a == "--json") || asked("json") {
        Some(Format::Json)
    } else if asked("jsonl") {
        Some(Format::Jsonl)
    } else if asked("human") {
        Some(Format::Human)
    } else {
        None
    };
    let out = Out::resolve(format, ColorWhen::Auto, false, false);
    if out.format == Format::Human {
        let _ = e.print();
        return std::process::ExitCode::from(2);
    }
    let detail = e.to_string();
    let first = detail.lines().next().unwrap_or("invalid arguments");
    out.fail(&AppError::new(
        "USAGE",
        Exit::Usage,
        first.trim_start_matches("error: "),
        "steelbore-reticle schema --json   # lists every command, flag and bound",
        &args.join(" "),
    ));
    std::process::ExitCode::from(2)
}

fn unknown_field(out: Out, field: &str, known: &[&str], command: &str) -> i32 {
    out.fail(&AppError::new(
        "USAGE",
        Exit::Usage,
        format!("unknown field {field:?}; valid fields: {}", known.join(",")),
        format!("{command} --json --fields {}", known.join(",")),
        command,
    ))
}

fn cmd_device_list(out: Out, fields: &[String]) -> i32 {
    const CMD: &str = "steelbore-reticle device list";
    let inputs = input::scan(Path::new(daemon::INPUT_DIR));
    if inputs.is_empty() {
        out.say(
            Level::Warn,
            "no readable pointing device; reading /dev/input needs the input group or root",
        );
    }
    let records: Vec<Value> = inputs
        .iter()
        .map(|i| {
            json!({
                "path": i.path.display().to_string(),
                "kind": i.kind.as_str(),
                "name": input::name_of(i),
            })
        })
        .collect();
    let records = match output::select_fields(records, fields, &DEVICE_FIELDS) {
        Ok(r) => r,
        Err(bad) => return unknown_field(out, &bad, &DEVICE_FIELDS, CMD),
    };
    out.emit_list(CMD, &records, &render(&records, &DEVICE_FIELDS));
    Exit::Success as i32
}

fn cmd_console_get(out: Out, fields: &[String]) -> i32 {
    const CMD: &str = "steelbore-reticle console get";
    let number = match File::open(daemon::ACTIVE_VT).and_then(|mut f| daemon::read_active(&mut f)) {
        Ok(n) => n,
        Err(e) => {
            return out.fail(&AppError::new(
                "NOT_FOUND",
                Exit::NotFound,
                format!("cannot read {}: {e}", daemon::ACTIVE_VT),
                "ls /sys/class/tty/tty0   # a kernel without virtual consoles has no VT",
                CMD,
            ))
        }
    };
    let vt = match console::Vt::open(number) {
        Ok(vt) => vt,
        Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => {
            return out.fail(&AppError::new(
                "PERMISSION_DENIED",
                Exit::Permission,
                format!("opening /dev/tty{number} needs root or the tty group"),
                "steelbore-reticle device list --json   # works unprivileged; console get needs the user to run it as root",
                CMD,
            ))
        }
        Err(e) => {
            return out.fail(&AppError::new(
                "FAILURE",
                Exit::Failure,
                format!("opening /dev/tty{number}: {e}"),
                "steelbore-reticle console get --verbose",
                CMD,
            ))
        }
    };
    let probe = (|| -> std::io::Result<Value> {
        let (columns, rows) = vt.size()?;
        let reporting = match vt.mouse_reporting()? {
            0 => "off",
            1 => "x10",
            _ => "x11",
        };
        Ok(json!({
            "vt": number,
            "mode": if vt.is_text()? { "text" } else { "graphics" },
            "columns": columns,
            "rows": rows,
            "mouse_reporting": reporting,
        }))
    })();
    let record = match probe {
        Ok(r) => r,
        Err(e) => {
            return out.fail(&AppError::new(
                "FAILURE",
                Exit::Failure,
                format!("querying /dev/tty{number}: {e}"),
                "steelbore-reticle console get --verbose",
                CMD,
            ))
        }
    };
    let record = match output::select_fields(vec![record], fields, &CONSOLE_FIELDS) {
        Ok(mut r) => r.pop().unwrap_or(Value::Null),
        Err(bad) => return unknown_field(out, &bad, &CONSOLE_FIELDS, CMD),
    };
    let human = render(std::slice::from_ref(&record), &CONSOLE_FIELDS);
    out.emit(CMD, &record, &human);
    Exit::Success as i32
}

/// Human rendering: one record per line, the values tab-separated in `order`
/// (only the fields present). Parses with `cut -f` in POSIX sh.
fn render(records: &[Value], order: &[&str]) -> String {
    let mut s = String::new();
    for r in records {
        let cells: Vec<String> = order
            .iter()
            .filter_map(|k| r.get(*k))
            .map(|v| match v {
                Value::String(t) => t.clone(),
                other => other.to_string(),
            })
            .collect();
        s.push_str(&cells.join("\t"));
        s.push('\n');
    }
    s
}

fn cmd_schema(out: Out) -> i32 {
    // Hand-written, as preflight's is: the surface is small, and the exit-code
    // table has no derive source.
    let schema = json!({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "steelbore-reticle",
        "description": ABOUT,
        "commands": {
            "steelbore-reticle run": {
                "description": "Run the console mouse; the system service. Needs CAP_SYS_ADMIN.",
                "flags": {
                    "--speed": { "type": "number", "minimum": 0.1, "maximum": 10, "default": 1.0 }
                }
            },
            "steelbore-reticle device list": {
                "description": "Pointing devices run would read",
                "record": {
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" },
                        "kind": { "enum": ["pointer", "touchpad", "tablet"] },
                        "name": { "type": "string" }
                    }
                }
            },
            "steelbore-reticle console get": {
                "description": "The foreground VT. Needs root or the tty group.",
                "record": {
                    "type": "object",
                    "properties": {
                        "vt": { "type": "integer", "minimum": 1 },
                        "mode": { "enum": ["text", "graphics"] },
                        "columns": { "type": "integer" },
                        "rows": { "type": "integer" },
                        "mouse_reporting": { "enum": ["off", "x10", "x11"] }
                    }
                }
            },
            "steelbore-reticle schema": { "description": "This document" },
            "steelbore-reticle describe": { "description": "Capability manifest" }
        },
        "global_flags": ["--json", "--format human|json|jsonl", "--fields", "--color", "--no-color", "--verbose", "--quiet"],
        "exit_codes": {
            "0": "success",
            "1": "general failure",
            "2": "usage error",
            "3": "not found (no virtual console)",
            "4": "permission denied (CAP_SYS_ADMIN, root or the tty group)"
        }
    });
    out.emit(
        "steelbore-reticle schema",
        &schema,
        &format!("{schema:#}\n"),
    );
    Exit::Success as i32
}

fn cmd_describe(out: Out) -> i32 {
    let manifest = json!({
        "tool": env!("CARGO_PKG_NAME"),
        "version": env!("CARGO_PKG_VERSION"),
        "summary": ABOUT,
        "maintainer": output::MAINTAINER,
        "website": output::WEBSITE,
        "capabilities": ["console-pointer", "console-selection", "console-paste", "mouse-reporting", "device-list", "console-get"],
        "reads": [daemon::INPUT_DIR, daemon::ACTIVE_VT, "/dev/ttyN"],
        "privileges": "run: CAP_SYS_ADMIN; console get: root or the tty group; device list: the input group",
    });
    out.emit(
        "steelbore-reticle describe",
        &manifest,
        &format!("{manifest:#}\n"),
    );
    Exit::Success as i32
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::CommandFactory;

    #[test]
    fn the_flag_surface_is_well_formed() {
        Cli::command().debug_assert();
    }

    #[test]
    fn an_unknown_subcommand_is_a_usage_error() {
        assert!(Cli::try_parse_from(["steelbore-reticle", "frobnicate"]).is_err());
    }

    #[test]
    fn speed_is_bounds_checked() {
        assert!(Cli::try_parse_from(["steelbore-reticle", "run", "--speed", "1e9"]).is_err());
        assert!(Cli::try_parse_from(["steelbore-reticle", "run", "--speed", "1.5"]).is_ok());
    }

    #[test]
    fn human_rendering_is_tab_separated_in_field_order() {
        let r = json!({"name": "TrackPoint", "path": "/dev/input/event11", "kind": "pointer"});
        assert_eq!(
            render(&[r], &DEVICE_FIELDS),
            "/dev/input/event11\tpointer\tTrackPoint\n"
        );
    }
}
