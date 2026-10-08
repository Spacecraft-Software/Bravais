// SPDX-License-Identifier: GPL-3.0-or-later
//! `steelbore-quantize` — palette-quantize one PNG with the Rust `imagequant`
//! crate, the engine inside pngquant 3, with no C on the path: `png` decodes
//! and encodes, `imagequant` builds the palette and dithers.
//!
//! It exists for build-time asset budgets (the Plymouth splash lives in every
//! initrd; constraint #43), so it is deliberately one verb with no sub-command
//! tree. Output is written to a sibling temporary file and renamed into place,
//! so INPUT and OUTPUT may be the same path.

use std::fs::{self, File};
use std::io::{self, BufReader, BufWriter, IsTerminal as _, Write as _};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use anyhow::{Context as _, Result};
use imagequant::RGBA;

const TOOL: &str = "steelbore-quantize";
const VERSION: &str = env!("CARGO_PKG_VERSION");
const MAINTAINER: &str = "Maintained by Mohamed Hammad <Mohamed.Hammad@SpacecraftSoftware.org>";
const WEBSITE: &str = "https://Bravais.SpacecraftSoftware.org/";

/// Default `--quality` floor and target, pngquant's 0-100 scale. The floor is
/// a hard stop: below it nothing is written and the exit code is
/// [`EXIT_QUALITY_TOO_LOW`]. 70-90 is what the splash budget was tuned with.
const DEFAULT_QUALITY: (u8, u8) = (70, 90);

/// imagequant speed 1 (slowest, best) to 10. 4 is pngquant's own default and
/// the value the crate documents as the best size/quality balance; this tool
/// runs once per build, so speed buys nothing worth losing quality for.
const SPEED: i32 = 4;

/// Floyd-Steinberg dithering strength, 0.0-1.0. 1.0 matches pngquant's
/// default; lower values band smooth gradients (the splash is mostly glow).
const DITHERING: f32 = 1.0;

/// zlib compression level for the output; see `encode` for the measurement.
const DEFLATE_LEVEL: u8 = 9;

/// Canonical exit codes (CLI Standard section 4); 6 is this tool's own.
const EXIT_FAILURE: u8 = 1;
const EXIT_USAGE: u8 = 2;
const EXIT_NOT_FOUND: u8 = 3;
/// The palette cannot reach the `--quality` floor. Same meaning as
/// pngquant's 99, renumbered into the Standard's tool-specific range.
const EXIT_QUALITY_TOO_LOW: u8 = 6;

#[derive(Debug)]
struct Args {
    input: PathBuf,
    output: PathBuf,
    quality: (u8, u8),
}

#[derive(Debug)]
enum Command {
    Run(Args),
    Help,
    Version,
}

/// A failure carrying its exit code, error code and fix hint.
#[derive(Debug)]
struct Failure {
    exit: u8,
    code: &'static str,
    message: String,
    hint: Option<String>,
}

impl Failure {
    fn new(exit: u8, code: &'static str, message: impl Into<String>, hint: Option<&str>) -> Self {
        Self {
            exit,
            code,
            message: message.into(),
            hint: hint.map(str::to_owned),
        }
    }

    fn usage(message: impl Into<String>) -> Self {
        Self::new(
            EXIT_USAGE,
            "usage",
            message,
            Some("steelbore-quantize --help"),
        )
    }
}

#[derive(Debug)]
struct Summary {
    width: u32,
    height: u32,
    colors: usize,
    quality: Option<u8>,
    bytes: u64,
}

fn main() -> ExitCode {
    let invocation: Vec<String> = std::env::args().skip(1).collect();
    let machine = machine_mode(&invocation);
    match parse(&invocation) {
        Ok(Command::Help) => {
            print!("{}", help());
            ExitCode::SUCCESS
        }
        Ok(Command::Version) => {
            println!("{TOOL} {VERSION}\n{MAINTAINER}\n{WEBSITE}");
            ExitCode::SUCCESS
        }
        Ok(Command::Run(args)) => match run(&args) {
            Ok(summary) => {
                if machine {
                    println!("{}", success_json(&invocation, &args, &summary));
                }
                ExitCode::SUCCESS
            }
            Err(failure) => report(&invocation, &failure, machine),
        },
        Err(failure) => report(&invocation, &failure, machine),
    }
}

/// Machine mode, for the result on stdout and diagnostics on stderr alike
/// (CLI Standard section 5): `--json`, an agent harness (`AI_AGENT` / `AGENT`
/// set to anything non-empty — presence, not `== "1"`), truthy `CI`, or stdout
/// not being a terminal (piped, or a Nix build log).
fn machine_mode(invocation: &[String]) -> bool {
    let present = |name: &str| std::env::var_os(name).is_some_and(|v| !v.is_empty());
    let ci = std::env::var("CI").is_ok_and(|v| !v.is_empty() && v != "0" && v != "false");
    invocation.iter().any(|a| a == "--json")
        || present("AI_AGENT")
        || present("AGENT")
        || ci
        || !io::stdout().is_terminal()
}

fn parse(invocation: &[String]) -> Result<Command, Failure> {
    let mut quality = DEFAULT_QUALITY;
    let mut paths = Vec::new();
    let mut iter = invocation.iter();
    while let Some(arg) = iter.next() {
        match arg.as_str() {
            "-h" | "--help" => return Ok(Command::Help),
            "--version" => return Ok(Command::Version),
            // Accepted here, resolved by `machine_mode` with the other signals.
            "--json" => {}
            "--quality" => {
                let value = iter
                    .next()
                    .ok_or_else(|| Failure::usage("--quality needs a value such as 70-90"))?;
                quality = parse_quality(value)?;
            }
            flag if flag.starts_with("--quality=") => {
                quality = parse_quality(&flag["--quality=".len()..])?;
            }
            flag if flag.starts_with('-') && flag != "-" => {
                return Err(Failure::usage(format!("unknown option {flag}")));
            }
            path => paths.push(PathBuf::from(path)),
        }
    }
    match <[PathBuf; 2]>::try_from(paths) {
        Ok([input, output]) => Ok(Command::Run(Args {
            input,
            output,
            quality,
        })),
        Err(_) => Err(Failure::usage("expected exactly two paths: INPUT OUTPUT")),
    }
}

/// Parses pngquant's `MIN-MAX` form; a bare `N` means `0-N`, as in pngquant.
fn parse_quality(value: &str) -> Result<(u8, u8), Failure> {
    let bad = |why: &dyn std::fmt::Display| {
        Failure::usage(format!(
            "--quality {value}: {why}; expected MIN-MAX, each 0-100"
        ))
    };
    let number = |n: &str| n.parse::<u8>().map_err(|e| bad(&e));
    let (min, max) = match value.split_once('-') {
        Some((min, max)) => (number(min)?, number(max)?),
        None => (0, number(value)?),
    };
    if min > max || max > 100 {
        return Err(bad(&"out of range"));
    }
    Ok((min, max))
}

fn run(args: &Args) -> Result<Summary, Failure> {
    if !args.input.is_file() {
        return Err(Failure::new(
            EXIT_NOT_FOUND,
            "not_found",
            format!(
                "input {} does not exist or is not a file",
                args.input.display()
            ),
            Some("check the INPUT path"),
        ));
    }
    let (pixels, width, height) = decode(&args.input).map_err(general)?;

    let mut attr = imagequant::new();
    attr.set_quality(args.quality.0, args.quality.1)
        .map_err(general_liq)?;
    attr.set_speed(SPEED).map_err(general_liq)?;
    let mut image = attr
        .new_image(pixels, to_usize(width), to_usize(height), 0.0)
        .map_err(general_liq)?;
    let mut result = attr.quantize(&mut image).map_err(|e| match e {
        imagequant::Error::QualityTooLow => Failure::new(
            EXIT_QUALITY_TOO_LOW,
            "quality_too_low",
            format!(
                "no palette reaches the --quality floor of {} for {}",
                args.quality.0,
                args.input.display()
            ),
            Some("lower the floor, e.g. --quality 50-90"),
        ),
        other => general_liq(other),
    })?;
    result.set_dithering_level(DITHERING).map_err(general_liq)?;
    let quality = result.quantization_quality();
    let (palette, indices) = result.remapped(&mut image).map_err(general_liq)?;

    let bytes = encode(&args.output, width, height, &palette, &indices).map_err(general)?;
    Ok(Summary {
        width,
        height,
        colors: palette.len(),
        quality,
        bytes,
    })
}

/// Decodes any PNG to 8-bit RGBA. `normalize_to_color8` expands palettes,
/// tRNS and sub-byte gray and strips 16-bit samples, which leaves exactly the
/// four color types matched below.
fn decode(path: &Path) -> Result<(Vec<RGBA>, u32, u32)> {
    let file = File::open(path).with_context(|| format!("opening {}", path.display()))?;
    let mut decoder = png::Decoder::new(BufReader::new(file));
    decoder.set_transformations(png::Transformations::normalize_to_color8());
    let mut reader = decoder
        .read_info()
        .with_context(|| format!("reading PNG header of {}", path.display()))?;
    let size = reader
        .output_buffer_size()
        .context("image dimensions exceed the decoder's limits")?;
    let mut buf = vec![0; size];
    let info = reader
        .next_frame(&mut buf)
        .with_context(|| format!("decoding {}", path.display()))?;
    let buf = &buf[..info.buffer_size()];

    let pixels = match info.color_type {
        png::ColorType::Rgba => buf
            .chunks_exact(4)
            .map(|p| RGBA::new(p[0], p[1], p[2], p[3]))
            .collect(),
        png::ColorType::Rgb => buf
            .chunks_exact(3)
            .map(|p| RGBA::new(p[0], p[1], p[2], u8::MAX))
            .collect(),
        png::ColorType::GrayscaleAlpha => buf
            .chunks_exact(2)
            .map(|p| RGBA::new(p[0], p[0], p[0], p[1]))
            .collect(),
        png::ColorType::Grayscale => buf.iter().map(|&g| RGBA::new(g, g, g, u8::MAX)).collect(),
        png::ColorType::Indexed => {
            unreachable!("normalize_to_color8 expands indexed images before they reach here")
        }
    };
    Ok((pixels, info.width, info.height))
}

/// Writes an 8-bit indexed PNG through a temporary sibling, then renames it
/// over `path`, so a failure never leaves a truncated OUTPUT and INPUT may be
/// OUTPUT. Returns the written size in bytes.
fn encode(path: &Path, width: u32, height: u32, palette: &[RGBA], indices: &[u8]) -> Result<u64> {
    let plte: Vec<u8> = palette.iter().flat_map(|c| [c.r, c.g, c.b]).collect();
    // tRNS may stop at the last translucent entry; omit it when all are opaque.
    let opaque_tail = palette.iter().rev().take_while(|c| c.a == u8::MAX).count();
    let trns: Vec<u8> = palette[..palette.len() - opaque_tail]
        .iter()
        .map(|c| c.a)
        .collect();

    let (tmp, file) = create_temp(path)?;
    let written = (|| -> Result<()> {
        let mut out = BufWriter::new(file);
        let mut encoder = png::Encoder::new(&mut out, width, height);
        encoder.set_color(png::ColorType::Indexed);
        encoder.set_depth(png::BitDepth::Eight);
        // No row filter: palette indices are not numeric samples, so the
        // prediction filters only add noise to the deflate stream (libpng
        // skips them for indexed images too). Measured on the splash:
        // Adaptive 716 KB, MinEntropy 645 KB, none 555 KB, pngquant 589 KB.
        encoder.set_filter(png::Filter::NoFilter);
        // zlib level 9: this runs once per build on one image, so the slowest
        // standard level is free and the bytes land in every initrd. Level 10
        // saved under 0.1% more.
        encoder.set_deflate_compression(png::DeflateCompression::Level(DEFLATE_LEVEL));
        encoder.set_palette(plte);
        if !trns.is_empty() {
            encoder.set_trns(trns);
        }
        let mut writer = encoder.write_header().context("writing PNG header")?;
        writer
            .write_image_data(indices)
            .context("writing PNG data")?;
        writer.finish().context("finishing PNG stream")?;
        out.flush().context("flushing output")?;
        Ok(())
    })();
    if let Err(e) = written {
        let _ = fs::remove_file(&tmp);
        return Err(e);
    }
    if let Err(e) = fs::rename(&tmp, path) {
        let _ = fs::remove_file(&tmp);
        return Err(e).with_context(|| format!("moving output into {}", path.display()));
    }
    Ok(fs::metadata(path)?.len())
}

/// Attempts at a free temporary name before giving up; a collision needs a
/// leftover from a crashed run with the same PID, so a handful is plenty.
const TEMP_ATTEMPTS: u32 = 16;

/// Creates a new sibling of `path` to write into. `create_new` refuses an
/// existing file instead of truncating it, and the name carries the PID, so
/// neither a concurrent run nor an unrelated file of that name is clobbered.
fn create_temp(path: &Path) -> Result<(PathBuf, File)> {
    let pid = std::process::id();
    for attempt in 0..TEMP_ATTEMPTS {
        let mut name = path.as_os_str().to_owned();
        name.push(format!(".steelbore-quantize.{pid}.{attempt}.tmp"));
        let tmp = PathBuf::from(name);
        match File::options().write(true).create_new(true).open(&tmp) {
            Ok(file) => return Ok((tmp, file)),
            Err(e) if e.kind() == io::ErrorKind::AlreadyExists => {}
            Err(e) => return Err(e).with_context(|| format!("creating {}", tmp.display())),
        }
    }
    anyhow::bail!(
        "no free temporary name beside {} after {TEMP_ATTEMPTS} attempts",
        path.display()
    )
}

/// `u32` image dimensions always fit `usize` on the 32/64-bit targets this
/// builds for; anything else is a platform this tool never runs on.
fn to_usize(n: u32) -> usize {
    usize::try_from(n).expect("u32 fits in usize on every supported target")
}

#[expect(
    clippy::needless_pass_by_value,
    reason = "passed to map_err as a fn item, which hands over ownership"
)]
fn general(e: anyhow::Error) -> Failure {
    Failure::new(EXIT_FAILURE, "failure", format!("{e:#}"), None)
}

fn general_liq(e: imagequant::Error) -> Failure {
    Failure::new(EXIT_FAILURE, "quantizer", format!("imagequant: {e}"), None)
}

fn now_utc() -> String {
    jiff::Timestamp::now()
        .strftime("%Y-%m-%dT%H:%M:%SZ")
        .to_string()
}

fn command_line(invocation: &[String]) -> String {
    std::iter::once(TOOL)
        .chain(invocation.iter().map(String::as_str))
        .collect::<Vec<_>>()
        .join(" ")
}

fn report(invocation: &[String], failure: &Failure, machine: bool) -> ExitCode {
    let mut stderr = io::stderr().lock();
    let _ = if machine {
        let error = serde_json::json!({
            "error": {
                "code": failure.code,
                "exit_code": failure.exit,
                "message": failure.message,
                "hint": failure.hint,
                "timestamp": now_utc(),
                "command": command_line(invocation),
                "docs_url": WEBSITE,
            }
        });
        writeln!(stderr, "{error}")
    } else {
        match &failure.hint {
            Some(hint) => writeln!(stderr, "[ERROR] {}\n  hint: {hint}", failure.message),
            None => writeln!(stderr, "[ERROR] {}", failure.message),
        }
    };
    ExitCode::from(failure.exit)
}

fn success_json(invocation: &[String], args: &Args, summary: &Summary) -> serde_json::Value {
    serde_json::json!({
        "metadata": {
            "tool": TOOL,
            "version": VERSION,
            "command": command_line(invocation),
            "timestamp": now_utc(),
            "maintainer": MAINTAINER,
            "website": WEBSITE,
        },
        "data": {
            "input": args.input.display().to_string(),
            "output": args.output.display().to_string(),
            "width": summary.width,
            "height": summary.height,
            "colors": summary.colors,
            "quality": summary.quality,
            "bytes": summary.bytes,
        }
    })
}

fn help() -> String {
    format!(
        "\
{TOOL} {VERSION} — palette-quantize a PNG (pure Rust: imagequant + png)

Usage: {TOOL} [--quality MIN-MAX] [--json] INPUT OUTPUT

Options:
  --quality MIN-MAX  0-100; below MIN nothing is written (default {min}-{max})
  --json             print a result object on stdout (also automatic when
                     stdout is not a terminal or AI_AGENT/AGENT/CI is set)
  -h, --help         this help
  --version          version and maintainer

INPUT and OUTPUT may be the same path; OUTPUT is replaced atomically.

Exit codes: 0 ok, 1 failure, 2 usage, 3 INPUT not found,
            6 palette cannot reach the --quality floor

Examples:
  {TOOL} --quality 70-90 splash.png splash.png
  {TOOL} --json in.png out.png

{WEBSITE}
{MAINTAINER}
",
        min = DEFAULT_QUALITY.0,
        max = DEFAULT_QUALITY.1,
    )
}

// Rust guideline compliant 2026-05-18
