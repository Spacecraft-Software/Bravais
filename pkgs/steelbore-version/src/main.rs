// SPDX-License-Identifier: GPL-3.0-or-later
//
// steelbore-version — report the Steelbore OS version of the running system.
//
// Two names, one binary. As `steelbore-version` it follows the Spacecraft
// Software CLI Standard: envelope, `--json`/`--format`, `--fields`, `schema`,
// `describe`, canonical exit codes. As `nixos-version` (a symlink the package
// installs, replacing NixOS's own script) it keeps upstream's output contract
// byte for byte, so existing scripts keep working, while printing the Steelbore
// OS codename. src/compat.rs owns that second surface.
//
// Every value about the system comes from the version record (src/record.rs),
// written by modules/core/identity.nix; only the OS name and URL used in help
// text are compiled in (build.rs). So the binary is built once and reused
// across nixpkgs bumps.
//
// Standard §3.1: no `unwrap`/`expect` on a runtime path. A missing or bad
// record is a structured error with a hint, never a panic.

mod compat;
mod output;
mod record;

use std::ffi::OsString;
use std::fmt::Write as _;
use std::io::Write as _;
use std::path::Path;
use std::process::ExitCode;

use clap::error::ErrorKind;
use clap::{ArgGroup, Parser, Subcommand};
use serde_json::{json, Map, Value};

use output::{AppError, ColorWhen, Exit, Format, Out, MAINTAINER, WEBSITE};
use record::{LoadError, Record, DEFAULT_PATH, FIELDS, PATH_ENV, SCHEMA};

/// The name under which this binary answers with upstream's contract.
const COMPAT_NAME: &str = "nixos-version";

const ABOUT: &str = concat!(
    "Report the ",
    env!("STEELBORE_OS_NAME"),
    " version of the running system."
);

#[derive(Parser, Debug)]
#[command(
    name = "steelbore-version",
    version,
    // §15.2: --version carries the maintainer and the project URL. clap's
    // bare `version` prints name and number only, so the attribution goes in
    // long_version, which both -V and --version render.
    long_version = concat!(
        env!("CARGO_PKG_VERSION"), "\n",
        "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>\n",
        "Copyright (C) 2026 Mohamed Hammad & Spacecraft Software  |  License: GPL-3.0-or-later\n",
        env!("STEELBORE_OS_URL")
    ),
    about = ABOUT,
    after_help = concat!(
        "EXAMPLES:\n",
        "  steelbore-version                    26.05.20261007.2efa67f (Altair)\n",
        "  steelbore-version --pretty           ", env!("STEELBORE_OS_NAME"), " Bravais 26.05 (Altair)\n",
        "  steelbore-version --revision         The nixpkgs commit (alias: --hash)\n",
        "  steelbore-version --json             Every field, in the standard envelope\n",
        "  steelbore-version --fields release,codename --json\n",
        "  nixos-version --json                 Upstream NixOS's format, Steelbore codename\n",
        "\n",
        "The version record is read from ", "/run/current-system/sw/share/steelbore/version.json", "\n",
        "(override with STEELBORE_VERSION_FILE). Invoked as nixos-version, this binary\n",
        "reproduces NixOS's nixos-version output.\n",
        "\n",
        "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>\n",
        env!("STEELBORE_OS_URL")
    )
)]
#[command(group(
    ArgGroup::new("select")
        .args(["revision", "configuration_revision", "codename", "pretty"])
        .conflicts_with("fields")
))]
#[expect(
    clippy::struct_excessive_bools,
    reason = "this IS the flag surface; the selectors are one exclusive group and the rest are independent switches"
)]
struct Cli {
    #[command(subcommand)]
    command: Option<Cmd>,

    /// Print the nixpkgs commit the system was built from
    #[arg(long, visible_alias = "hash")]
    revision: bool,

    /// Print system.configurationRevision
    #[arg(long)]
    configuration_revision: bool,

    /// Print the Steelbore OS release codename
    #[arg(long)]
    codename: bool,

    /// Print the full name, as os-release `PRETTY_NAME`
    #[arg(long)]
    pretty: bool,

    /// Emit machine-readable JSON (alias for --format json)
    #[arg(long, global = true)]
    json: bool,

    /// Output format
    #[arg(long, global = true, value_enum)]
    format: Option<Format>,

    /// Restrict output to these record fields (comma-separated)
    #[arg(long, global = true, value_delimiter = ',', value_name = "FIELD,...")]
    fields: Vec<String>,

    /// Colour policy
    #[arg(long, global = true, value_enum, default_value = "auto")]
    color: ColorWhen,

    /// Disable colour (equivalent to --color never)
    #[arg(long, global = true)]
    no_color: bool,

    /// Accepted for the Standard's global flag set; this tool narrates nothing
    #[arg(long, short, global = true, conflicts_with = "quiet")]
    verbose: bool,

    /// Accepted for the Standard's global flag set; errors are still printed
    #[arg(long, short, global = true)]
    quiet: bool,
}

#[derive(Subcommand, Debug)]
enum Cmd {
    /// Emit the JSON Schema of the output, the exit codes and the record
    Schema,
    /// Emit a manifest of the command surface
    Describe,
}

fn main() -> ExitCode {
    let invocation: Vec<OsString> = std::env::args_os().collect();
    let prog = invocation.first().map_or_else(
        || "steelbore-version".to_owned(),
        |a| a.to_string_lossy().into_owned(),
    );
    if Path::new(&prog).file_name().and_then(|n| n.to_str()) == Some(COMPAT_NAME) {
        return ExitCode::from(run_compat(&prog, invocation.get(1)));
    }
    ExitCode::from(run_steelbore(&invocation))
}

/// The `nixos-version` surface: upstream's contract, written as-is.
fn run_compat(prog: &str, first: Option<&OsString>) -> u8 {
    let first = first.map(|a| a.to_string_lossy());
    let reply = compat::respond(prog, first.as_deref(), || record::load(&record::path()));
    let _ = std::io::stdout().lock().write_all(reply.stdout.as_bytes());
    let _ = std::io::stderr().lock().write_all(reply.stderr.as_bytes());
    reply.status
}

/// The `steelbore-version` surface.
fn run_steelbore(invocation: &[OsString]) -> u8 {
    let command = command_line(invocation);
    let cli = match Cli::try_parse_from(invocation) {
        Ok(cli) => cli,
        Err(e) => return usage_error(&e, invocation, &command),
    };
    let format = if cli.json {
        Some(Format::Json)
    } else {
        cli.format
    };
    let color = if cli.no_color {
        ColorWhen::Never
    } else {
        cli.color
    };
    let out = Out::resolve(format, color);
    match dispatch(&cli, out, &command) {
        Ok(()) => 0,
        Err(err) => out.fail(&err, &command),
    }
}

/// clap's own errors. Help and version are successes printed as clap renders
/// them; a real usage error becomes a structured error (exit 2), as JSON when
/// the caller asked for or implies machine output.
fn usage_error(e: &clap::Error, invocation: &[OsString], command: &str) -> u8 {
    if matches!(e.kind(), ErrorKind::DisplayHelp | ErrorKind::DisplayVersion) {
        let _ = e.print();
        return 0;
    }
    let out = Out::resolve(explicit_format(invocation), ColorWhen::Auto);
    let message = e.to_string();
    let first_line = message.lines().next().unwrap_or("invalid arguments");
    let err = AppError::new(
        "usage",
        Exit::Usage,
        first_line.trim_start_matches("error: ").to_owned(),
    )
    .with_hint("steelbore-version --help");
    out.fail(&err, command)
}

fn dispatch(cli: &Cli, out: Out, command: &str) -> Result<(), AppError> {
    match cli.command {
        Some(Cmd::Schema) => emit_document(out, command, &schema()),
        Some(Cmd::Describe) => emit_document(out, command, &describe()),
        None => report(cli, out, command),
    }
}

/// `schema` and `describe` are JSON documents in either mode: enveloped for
/// machines, pretty-printed for people.
fn emit_document(out: Out, command: &str, doc: &Value) -> Result<(), AppError> {
    let human = serde_json::to_string_pretty(doc)
        .map(|s| s + "\n")
        .map_err(|e| {
            AppError::new(
                "serialize",
                Exit::Failure,
                format!("cannot serialize output: {e}"),
            )
        })?;
    out.emit(command, doc, &human)
}

/// The default command: load the record, then print all of it, one selected
/// value, or the `--fields` subset.
fn report(cli: &Cli, out: Out, command: &str) -> Result<(), AppError> {
    let record = record::load(&record::path()).map_err(|e| load_error(&e))?;

    let selected: Option<(&str, String)> = if cli.revision {
        let rev = record.known_nixpkgs_revision().ok_or_else(|| {
            AppError::new(
                "revision_unknown",
                Exit::NotFound,
                "the nixpkgs commit hash is unknown",
            )
            .with_hint("steelbore-version --json")
        })?;
        Some(("nixpkgs_revision", rev.to_owned()))
    } else if cli.configuration_revision {
        let rev = record.configuration_revision.clone().ok_or_else(|| {
            AppError::new(
                "configuration_revision_unknown",
                Exit::NotFound,
                "the configuration revision is unknown: system.configurationRevision is not set",
            )
            .with_hint("steelbore-version --json")
        })?;
        Some(("configuration_revision", rev))
    } else if cli.codename {
        Some(("codename", record.codename.clone()))
    } else if cli.pretty {
        Some(("pretty_name", record.pretty_name.clone()))
    } else {
        None
    };

    if let Some((key, value)) = selected {
        let mut data = Map::new();
        data.insert(key.to_owned(), Value::String(value.clone()));
        return out.emit(command, &data, &format!("{value}\n"));
    }

    if cli.fields.is_empty() {
        return out.emit(command, &record, &format!("{}\n", record.version_line()));
    }

    let (data, human) = select_fields(&record, &cli.fields)?;
    out.emit(command, &data, &human)
}

/// Build the `--fields` subset: the JSON object, and `field: value` lines in
/// the order asked for (POSIX-parseable with `cut -d: -f2-`).
fn select_fields(
    record: &Record,
    fields: &[String],
) -> Result<(Map<String, Value>, String), AppError> {
    if let Some(bad) = fields.iter().find(|f| !FIELDS.contains(&f.as_str())) {
        return Err(AppError::new(
            "unknown_field",
            Exit::Usage,
            format!("unknown field `{bad}`; fields are: {}", FIELDS.join(", ")),
        )
        .with_hint("steelbore-version schema"));
    }
    let full = serde_json::to_value(record).map_err(|e| {
        AppError::new(
            "serialize",
            Exit::Failure,
            format!("cannot serialize record: {e}"),
        )
    })?;
    let mut data = Map::new();
    let mut human = String::new();
    for field in fields {
        let value = full.get(field.as_str()).cloned().unwrap_or(Value::Null);
        let shown = match &value {
            Value::String(s) => s.clone(),
            Value::Null => "unknown".to_owned(),
            other => other.to_string(),
        };
        // Writing to a String cannot fail.
        let _ = writeln!(human, "{field}: {shown}");
        data.insert(field.clone(), value);
    }
    Ok((data, human))
}

/// Map a record failure to a structured error. The hint is a command to run
/// as-is; the why goes in the message.
fn load_error(e: &LoadError) -> AppError {
    match e {
        LoadError::Missing(_) => AppError::new(
            "no_record",
            Exit::NotFound,
            format!("{e}; a Steelbore OS rebuild installs it (or set {PATH_ENV} to read another)"),
        )
        .with_hint("preflight"),
        LoadError::Unreadable(..) => {
            AppError::new("record_unreadable", Exit::Failure, e.to_string())
        }
        LoadError::Invalid(..) => AppError::new(
            "record_invalid",
            Exit::Failure,
            format!("{e}; a rebuild rewrites the record"),
        )
        .with_hint("preflight"),
        LoadError::Schema(..) => AppError::new(
            "record_schema",
            Exit::Failure,
            format!("{e}; rebuild so the binary and the record come from one system"),
        )
        .with_hint("preflight"),
    }
}

/// The format the caller asked for on the command line, read without clap
/// (which has just rejected these arguments), so a usage error honours an
/// explicit `--json` or `--format` ahead of the environment's default.
fn explicit_format(invocation: &[OsString]) -> Option<Format> {
    let args: Vec<String> = invocation
        .iter()
        .skip(1)
        .map(|a| a.to_string_lossy().into_owned())
        .collect();
    let mut found = None;
    for (i, arg) in args.iter().enumerate() {
        let value = match arg.as_str() {
            "--json" => Some("json"),
            "--format" => args.get(i + 1).map(String::as_str),
            other => other.strip_prefix("--format="),
        };
        match value {
            Some("json") => found = Some(Format::Json),
            Some("human") => found = Some(Format::Human),
            _ => {}
        }
    }
    found
}

/// `steelbore-version` plus its arguments, for `metadata.command` and errors.
fn command_line(invocation: &[OsString]) -> String {
    std::iter::once("steelbore-version".to_owned())
        .chain(
            invocation
                .iter()
                .skip(1)
                .map(|a| a.to_string_lossy().into_owned()),
        )
        .collect::<Vec<_>>()
        .join(" ")
}

/// The canonical exit codes, as `schema` and `describe` publish them.
fn exit_codes() -> Value {
    json!({
        "0": "success",
        "1": "failure: the version record is unreadable, malformed, or of another schema",
        "2": "usage error: bad arguments or an unknown --fields name",
        "3": "not found: no version record, or the requested revision is unknown",
    })
}

/// JSON Schema (Draft 2020-12) of the `steelbore-version --json` output, plus
/// the exit codes and the record contract as `x-` extensions.
fn schema() -> Value {
    let mut properties = Map::new();
    for field in FIELDS {
        let ty = match field {
            "schema" => json!({ "type": "integer", "const": SCHEMA }),
            "nixpkgs_revision" | "configuration_revision" => json!({ "type": ["string", "null"] }),
            _ => json!({ "type": "string" }),
        };
        properties.insert(field.to_owned(), ty);
    }
    json!({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "steelbore-version --json",
        "type": "object",
        "required": ["metadata", "data"],
        "properties": {
            "metadata": {
                "type": "object",
                "required": ["tool", "version", "command", "timestamp", "maintainer", "website"],
            },
            "data": {
                "description": "The whole record; with a selector or --fields, only the named keys",
                "type": "object",
                "properties": properties,
            },
        },
        "x-exit-codes": exit_codes(),
        "x-record": { "path": DEFAULT_PATH, "override_env": PATH_ENV, "schema": SCHEMA },
        "x-aliases": {
            COMPAT_NAME: "upstream NixOS nixos-version output: bare line, --hash/--revision, --configuration-revision, --json with camelCase keys; exit 1 on an unknown value",
        },
    })
}

/// Manifest of the command surface, for agents deciding how to call us.
fn describe() -> Value {
    json!({
        "name": "steelbore-version",
        "summary": ABOUT,
        "version": env!("CARGO_PKG_VERSION"),
        "commands": {
            "steelbore-version": {
                "description": "Print the version line, one selected value, or the whole record",
                "selectors (one at most)": {
                    "--revision": "nixpkgs commit (alias --hash)",
                    "--configuration-revision": "system.configurationRevision",
                    "--codename": "Steelbore OS release codename",
                    "--pretty": "full name, as os-release PRETTY_NAME",
                },
            },
            "schema": "JSON Schema of the output, exit codes and record contract",
            "describe": "this manifest",
        },
        "global_flags": ["--json", "--format", "--fields", "--color", "--no-color", "--verbose", "--quiet"],
        "fields": FIELDS,
        "aliases": {
            COMPAT_NAME: "same binary; upstream NixOS output contract with the Steelbore OS codename",
        },
        "record": { "path": DEFAULT_PATH, "override_env": PATH_ENV, "schema": SCHEMA },
        "exit_codes": exit_codes(),
        "maintainer": MAINTAINER,
        "website": WEBSITE,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::record::tests::sample;

    #[test]
    fn cli_definition_is_consistent() {
        use clap::CommandFactory as _;
        Cli::command().debug_assert();
    }

    #[test]
    fn selectors_are_mutually_exclusive_and_exclude_fields() {
        let _ = Cli::try_parse_from(["steelbore-version", "--hash", "--codename"])
            .expect_err("two selectors conflict");
        let _ = Cli::try_parse_from(["steelbore-version", "--pretty", "--fields", "name"])
            .expect_err("a selector conflicts with --fields");
        let _ = Cli::try_parse_from(["steelbore-version", "--fields", "name,release", "--json"])
            .expect("--fields with --json parses");
    }

    #[test]
    fn fields_keep_request_order_and_reject_unknown_names() {
        let fields = vec!["codename".to_owned(), "configuration_revision".to_owned()];
        let (data, human) = select_fields(&sample(), &fields).expect("known fields");
        assert_eq!(human, "codename: Altair\nconfiguration_revision: unknown\n");
        assert_eq!(data.get("configuration_revision"), Some(&Value::Null));

        let err = select_fields(&sample(), &["nope".to_owned()]).expect_err("unknown field");
        assert_eq!(err.exit_code, Exit::Usage.code());
    }

    #[test]
    fn explicit_format_wins_and_the_last_one_counts() {
        let args = |v: &[&str]| -> Vec<OsString> { v.iter().map(OsString::from).collect() };
        assert_eq!(
            explicit_format(&args(&["x", "--format", "human", "--bogus"])),
            Some(Format::Human)
        );
        assert_eq!(
            explicit_format(&args(&["x", "--format=json"])),
            Some(Format::Json)
        );
        assert_eq!(
            explicit_format(&args(&["x", "--json", "--format", "human"])),
            Some(Format::Human)
        );
        assert_eq!(explicit_format(&args(&["x", "--bogus"])), None);
    }

    #[test]
    fn schema_covers_every_field() {
        let doc = schema();
        let props = doc["properties"]["data"]["properties"]
            .as_object()
            .expect("data properties is an object");
        assert_eq!(props.len(), FIELDS.len());
    }
}

// Rust guideline compliant 2026-05-18
