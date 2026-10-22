// SPDX-License-Identifier: GPL-3.0-or-later
//
// AppImages: which have updates, and applying them.
//
// AppImages live outside Nix entirely (Orca, Warp and WaveTerm sit in
// ~/Applications), so no flake update or vendored bump ever reaches them.
// BrowserOS is the exception: it is a pinned `appimageTools.wrapType2` in
// modules/packages/browsers.nix and moves with `--update-vendored`.
//
// The checking is delegated to Gear Lever (`it.mijorus.gearlever`, declared in
// modules/packages/flatpak.nix) rather than reimplemented here. It already
// reads an AppImage's embedded update information (`gh-releases-zsync|…`,
// `zsync|<url>`) AND the custom sources a user sets per app (GitHub, GitLab,
// Codeberg, Forgejo, a static URL), and since 4.6 its `--list-updates --json`
// is a versioned document meant for exactly this. Reimplementing zsync and
// six release APIs here would be a second copy of that logic to keep in step,
// for less coverage.
//
// Gear Lever only knows the AppImages it has integrated (its own folder,
// ~/AppImages by default). Anything else in the usual folders is reported as
// "outside Gear Lever" together with whether the file embeds update
// information, which this module reads straight from the ELF section table:
// an AppImage that embeds it would be updatable once integrated, while one
// without it can only update itself (or by hand).

// Rust guideline compliant 2026-05-18

use std::fs::File;
use std::io::Read;
use std::os::unix::fs::FileExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};
use std::time::{Duration, Instant};

use serde::Serialize;

/// Gear Lever's Flatpak application id.
pub const GEAR_LEVER: &str = "it.mijorus.gearlever";

/// Folders under `$HOME` scanned for AppImages Gear Lever does not manage.
/// `Applications` is where the self-updating ones were installed by hand;
/// `AppImages` is Gear Lever's own default folder.
pub const DIRS: &[&str] = &["Applications", "AppImages"];

/// The command that applies every pending update. `--yes` because preflight
/// gives it a null stdin: without it Gear Lever would ask, read EOF and loop.
/// A running app is skipped by Gear Lever itself (it needs `--force` to
/// replace one in use), which is the right default mid-session.
pub const UPDATE_ARGS: &[&str] = &["--update", "--all", "--yes"];

/// One AppImage with a newer version available, as Gear Lever reports it.
#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct Update {
    pub name: String,
    pub path: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current_version: Option<String>,
    /// The update source Gear Lever uses (`GithubUpdater`, …).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub manager: Option<String>,
    /// Whether the app is running now; Gear Lever skips those on update.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub running: Option<bool>,
}

/// An AppImage Gear Lever does not manage, so nothing checks it.
#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct Unmanaged {
    pub path: String,
    /// The embedded `.upd_info` string, if the file carries one.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub update_info: Option<String>,
}

/// What `preflight appimage status` and the run's check report.
#[derive(Debug, Default, Serialize)]
pub struct Report {
    /// How many AppImages Gear Lever manages.
    pub managed: usize,
    pub updates: Vec<Update>,
    pub unmanaged: Vec<Unmanaged>,
}

/// The command line that applies the updates, for hints and reports.
pub fn update_command() -> String {
    std::iter::once("flatpak run")
        .chain(std::iter::once(GEAR_LEVER))
        .chain(UPDATE_ARGS.iter().copied())
        .collect::<Vec<_>>()
        .join(" ")
}

/// Whether Gear Lever is installed (user or system installation).
pub fn gear_lever_installed() -> bool {
    let mut cmd = Command::new("flatpak");
    cmd.args(["info", GEAR_LEVER]).stdin(Stdio::null());
    output_within(cmd, CHECK_TIMEOUT).is_ok_and(|out| out.status.success())
}

/// `flatpak run it.mijorus.gearlever <args>`, with a null stdin so that no
/// question it asks can hang the run.
pub fn gear_lever(args: &[&str]) -> Command {
    let mut cmd = Command::new("flatpak");
    cmd.args(["run", GEAR_LEVER])
        .args(args)
        .stdin(Stdio::null());
    cmd
}

/// Ask Gear Lever what it manages and what has updates, then scan for the
/// AppImages it does not manage.
///
/// # Errors
///
/// A message naming what failed: Gear Lever could not be run, exited
/// non-zero (it does when it finds no internet connection), or printed
/// something that is not its JSON document (a release older than 4.6).
pub fn check() -> Result<Report, String> {
    let installed = run_json(&["--list-installed", "--json"])?;
    let managed = parse_paths(&installed, "installed")?;
    let updates = parse_updates(&run_json(&["--list-updates", "--json"])?)?;

    let home = std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_default();
    let known: Vec<PathBuf> = managed.iter().map(|p| canonical(Path::new(p))).collect();
    let unmanaged = DIRS
        .iter()
        .flat_map(|d| scan(&home.join(d)))
        .filter(|p| !known.contains(&canonical(p)))
        .map(|p| Unmanaged {
            update_info: update_info(&p),
            path: p.display().to_string(),
        })
        .collect();

    Ok(Report {
        managed: managed.len(),
        updates,
        unmanaged,
    })
}

fn canonical(p: &Path) -> PathBuf {
    std::fs::canonicalize(p).unwrap_or_else(|_| p.to_path_buf())
}

/// Run Gear Lever and return its stdout as a parsed JSON document.
fn run_json(args: &[&str]) -> Result<serde_json::Value, String> {
    let out = output_within(gear_lever(args), CHECK_TIMEOUT)
        .map_err(|e| format!("Gear Lever {}: {e}", args[0]))?;
    if !out.status.success() {
        // The last thing it said is the reason ("Internet connection not
        // available" goes to stderr under --json), whichever stream has it.
        let last = |b: &[u8]| {
            String::from_utf8_lossy(b)
                .lines()
                .rev()
                .map(str::trim)
                .find(|l| !l.is_empty())
                .map(ToOwned::to_owned)
        };
        let why = last(&out.stderr)
            .or_else(|| last(&out.stdout))
            .unwrap_or_else(|| "no output".to_owned());
        return Err(format!(
            "Gear Lever {} failed ({}): {why}",
            args[0], out.status
        ));
    }
    document(&String::from_utf8_lossy(&out.stdout)).ok_or_else(|| {
        format!(
            "Gear Lever {} printed no JSON document (needs Gear Lever 4.6 or later)",
            args[0]
        )
    })
}

/// How long one Gear Lever query may take before it is killed. Listing makes
/// one request per update source; a stalled one must not hold the rebuild
/// open, since the check runs before the Flatpak update starts.
pub const CHECK_TIMEOUT: Duration = Duration::from_mins(5);

/// [`Command::output`] with a time limit. The pipes are drained on their own
/// threads while the child is polled, so a large document cannot fill a pipe
/// and stall the child against a parent that is only waiting.
fn output_within(mut cmd: Command, limit: Duration) -> Result<Output, String> {
    let mut child = cmd
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("could not run: {e}"))?;
    let drain = |pipe: Option<Box<dyn Read + Send>>| {
        std::thread::spawn(move || {
            let mut buf = Vec::new();
            if let Some(mut p) = pipe {
                let _ = p.read_to_end(&mut buf);
            }
            buf
        })
    };
    let out = drain(
        child
            .stdout
            .take()
            .map(|p| Box::new(p) as Box<dyn Read + Send>),
    );
    let err = drain(
        child
            .stderr
            .take()
            .map(|p| Box::new(p) as Box<dyn Read + Send>),
    );
    let start = Instant::now();
    let status = loop {
        match child.try_wait() {
            Ok(Some(s)) => break s,
            Ok(None) if start.elapsed() >= limit => {
                let _ = child.kill();
                let _ = child.wait();
                return Err(format!("timed out after {} s; killed", limit.as_secs()));
            }
            Ok(None) => std::thread::sleep(crate::ai_tools::POLL),
            Err(e) => {
                let _ = child.kill();
                let _ = child.wait();
                return Err(format!("could not wait: {e}"));
            }
        }
    };
    Ok(Output {
        status,
        stdout: out.join().unwrap_or_default(),
        stderr: err.join().unwrap_or_default(),
    })
}

/// The JSON document in Gear Lever's stdout. It is one line, but a GTK or
/// Python warning can land on stdout before it, so take the last line that
/// parses as an object rather than the whole text.
fn document(stdout: &str) -> Option<serde_json::Value> {
    stdout
        .lines()
        .rev()
        .filter(|l| l.trim_start().starts_with('{'))
        .find_map(|l| serde_json::from_str::<serde_json::Value>(l).ok())
        .filter(serde_json::Value::is_object)
}

/// The schema this module was written against. A newer one may still parse;
/// an older one does not exist.
const SCHEMA: u64 = 1;

fn entries<'a>(
    doc: &'a serde_json::Value,
    key: &str,
) -> Result<&'a Vec<serde_json::Value>, String> {
    match doc
        .get("schema_version")
        .and_then(serde_json::Value::as_u64)
    {
        Some(v) if v >= SCHEMA => {}
        other => return Err(format!("unexpected Gear Lever schema_version {other:?}")),
    }
    doc.get(key)
        .and_then(serde_json::Value::as_array)
        .ok_or_else(|| format!("Gear Lever document has no `{key}` list"))
}

fn text(v: &serde_json::Value, key: &str) -> Option<String> {
    v.get(key)
        .and_then(serde_json::Value::as_str)
        .filter(|s| !s.is_empty())
        .map(ToOwned::to_owned)
}

/// The `path` of every entry under `key`.
fn parse_paths(doc: &serde_json::Value, key: &str) -> Result<Vec<String>, String> {
    Ok(entries(doc, key)?
        .iter()
        .filter_map(|e| text(e, "path"))
        .collect())
}

/// The entries of a `--list-updates --json` document.
fn parse_updates(doc: &serde_json::Value) -> Result<Vec<Update>, String> {
    Ok(entries(doc, "updates")?
        .iter()
        .filter_map(|e| {
            let path = text(e, "path")?;
            Some(Update {
                name: text(e, "name").unwrap_or_else(|| file_name(&path)),
                current_version: text(e, "current_version"),
                manager: text(e, "manager"),
                running: e.get("running").and_then(serde_json::Value::as_bool),
                path,
            })
        })
        .collect())
}

/// The last component of `path`, for display.
pub fn file_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .map_or_else(|| path.to_owned(), |n| n.to_string_lossy().into_owned())
}

/// Regular files in `dir` named `*.appimage`, any case. Not recursive: the
/// AppImage managers keep one flat folder, and Gear Lever's `.icons` is a
/// subfolder that must not be walked.
fn scan(dir: &Path) -> Vec<PathBuf> {
    let Ok(rd) = std::fs::read_dir(dir) else {
        return Vec::new();
    };
    let mut found: Vec<PathBuf> = rd
        .filter_map(Result::ok)
        .map(|e| e.path())
        .filter(|p| {
            p.extension()
                .is_some_and(|e| e.eq_ignore_ascii_case("appimage"))
                && p.is_file()
        })
        .collect();
    found.sort();
    found
}

/// The AppImage's embedded update information (the `.upd_info` ELF section,
/// AppImage specification "Update information"), or `None` if it has none or
/// the file is not a 64-bit little-endian ELF.
///
/// Read with positioned reads of the header and section table only: an
/// AppImage is often hundreds of MiB, and the section lives in the small
/// runtime at the front.
pub fn update_info(path: &Path) -> Option<String> {
    let f = File::open(path).ok()?;
    upd_info(&|offset, len| {
        let mut buf = vec![0; len];
        f.read_exact_at(&mut buf, offset).ok().map(|()| buf)
    })
}

/// Upper bounds that keep a corrupt or hostile header from asking for an
/// absurd allocation.
const MAX_SECTIONS: u64 = 4096;
const MAX_SECTION_BYTES: u64 = 64 * 1024;

fn upd_info(read: &dyn Fn(u64, usize) -> Option<Vec<u8>>) -> Option<String> {
    let eh = read(0, 64)?;
    // ELF magic, ELFCLASS64, ELFDATA2LSB.
    if eh.get(..4)? != b"\x7fELF" || *eh.get(4)? != 2 || *eh.get(5)? != 1 {
        return None;
    }
    let shoff = le_u64(&eh, 0x28)?;
    let shentsize = u64::from(le_u16(&eh, 0x3A)?);
    let shnum = u64::from(le_u16(&eh, 0x3C)?);
    let shstrndx = u64::from(le_u16(&eh, 0x3E)?);
    if shentsize != 64 || shnum == 0 || shnum > MAX_SECTIONS || shstrndx >= shnum {
        return None;
    }
    let table = read(shoff, usize::try_from(shentsize.checked_mul(shnum)?).ok()?)?;
    let section = |i: u64| -> Option<(u32, u64, u64)> {
        let at = usize::try_from(i.checked_mul(shentsize)?).ok()?;
        Some((
            le_u32(&table, at)?,
            le_u64(&table, at + 0x18)?,
            le_u64(&table, at + 0x20)?,
        ))
    };
    let bytes = |offset: u64, size: u64| -> Option<Vec<u8>> {
        if size > MAX_SECTION_BYTES {
            return None;
        }
        read(offset, usize::try_from(size).ok()?)
    };

    let (_, str_off, str_size) = section(shstrndx)?;
    let names = bytes(str_off, str_size)?;
    (0..shnum).find_map(|i| {
        let (name, off, size) = section(i)?;
        let name = names.get(usize::try_from(name).ok()?..)?;
        let end = name.iter().position(|&b| b == 0)?;
        if &name[..end] != b".upd_info" {
            return None;
        }
        let raw = bytes(off, size)?;
        let end = raw.iter().position(|&b| b == 0).unwrap_or(raw.len());
        let info = String::from_utf8_lossy(&raw[..end]).trim().to_owned();
        (!info.is_empty()).then_some(info)
    })
}

fn le_u16(b: &[u8], at: usize) -> Option<u16> {
    Some(u16::from_le_bytes(b.get(at..at + 2)?.try_into().ok()?))
}

fn le_u32(b: &[u8], at: usize) -> Option<u32> {
    Some(u32::from_le_bytes(b.get(at..at + 4)?.try_into().ok()?))
}

fn le_u64(b: &[u8], at: usize) -> Option<u64> {
    Some(u64::from_le_bytes(b.get(at..at + 8)?.try_into().ok()?))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A minimal ELF64 LE image: header, a `.shstrtab`, optionally an
    /// `.upd_info` holding `info`, and the section table at the end.
    fn elf(info: Option<&str>) -> Vec<u8> {
        let names = b"\0.shstrtab\0.upd_info\0".to_vec();
        let mut img = vec![0u8; 64];
        img[..4].copy_from_slice(b"\x7fELF");
        img[4] = 2;
        img[5] = 1;
        let names_off = img.len() as u64;
        img.extend_from_slice(&names);
        let info_off = img.len() as u64;
        let info_bytes: Vec<u8> = info.map_or_else(Vec::new, |s| {
            let mut v = s.as_bytes().to_vec();
            v.resize(v.len() + 16, 0); // padded, as appimagetool reserves space
            v
        });
        img.extend_from_slice(&info_bytes);
        let shoff = img.len() as u64;
        let mut sh = |name: u32, off: u64, size: u64| {
            let mut e = vec![0u8; 64];
            e[..4].copy_from_slice(&name.to_le_bytes());
            e[0x18..0x20].copy_from_slice(&off.to_le_bytes());
            e[0x20..0x28].copy_from_slice(&size.to_le_bytes());
            img.extend_from_slice(&e);
        };
        sh(0, 0, 0); // SHN_UNDEF
        sh(1, names_off, names.len() as u64);
        let mut n = 2u16;
        if info.is_some() {
            sh(11, info_off, info_bytes.len() as u64);
            n = 3;
        }
        img[0x28..0x30].copy_from_slice(&shoff.to_le_bytes());
        img[0x3A..0x3C].copy_from_slice(&64u16.to_le_bytes());
        img[0x3C..0x3E].copy_from_slice(&n.to_le_bytes());
        img[0x3E..0x40].copy_from_slice(&1u16.to_le_bytes());
        img
    }

    fn read_from(img: &[u8]) -> impl Fn(u64, usize) -> Option<Vec<u8>> + '_ {
        move |off, len| {
            let off = usize::try_from(off).ok()?;
            img.get(off..off.checked_add(len)?).map(<[u8]>::to_vec)
        }
    }

    #[test]
    fn reads_embedded_update_info() {
        let s = "gh-releases-zsync|neovim|neovim|latest|nvim-linux-x86_64.appimage.zsync";
        assert_eq!(upd_info(&read_from(&elf(Some(s)))).as_deref(), Some(s));
    }

    #[test]
    fn no_section_means_no_update_info() {
        assert_eq!(upd_info(&read_from(&elf(None))), None);
    }

    #[test]
    fn rejects_non_elf_and_truncated_input() {
        assert_eq!(upd_info(&read_from(b"#!/bin/sh\n")), None);
        let img = elf(Some("zsync|https://example.org/a.zsync"));
        assert_eq!(upd_info(&read_from(&img[..80])), None);
    }

    #[test]
    fn reads_update_info_from_a_file() {
        let dir = std::env::temp_dir().join(format!("preflight-appimage-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let f = dir.join("Tool.AppImage");
        std::fs::write(&f, elf(Some("zsync|https://example.org/t.zsync"))).unwrap();
        std::fs::write(dir.join("notes.txt"), b"").unwrap();
        std::fs::create_dir_all(dir.join(".icons")).unwrap();
        assert_eq!(scan(&dir), vec![f.clone()]);
        assert_eq!(
            update_info(&f).as_deref(),
            Some("zsync|https://example.org/t.zsync")
        );
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn parses_gear_lever_update_list() {
        let out = "Gtk-WARNING: whatever\n{\"schema_version\": 1, \"updates\": [{\"name\": \"Neovim\", \"path\": \"/home/mj/AppImages/nvim.appimage\", \"desktop_id\": \"x.desktop\", \"current_version\": \"0.11\", \"available_version\": null, \"download_size\": null, \"manager\": \"GithubUpdater\", \"embedded_source\": true, \"running\": false}]}\n";
        let doc = document(out).unwrap();
        let ups = parse_updates(&doc).unwrap();
        assert_eq!(
            ups,
            vec![Update {
                name: "Neovim".into(),
                path: "/home/mj/AppImages/nvim.appimage".into(),
                current_version: Some("0.11".into()),
                manager: Some("GithubUpdater".into()),
                running: Some(false),
            }]
        );
    }

    #[test]
    fn parses_gear_lever_installed_list() {
        let doc = document(
            "{\"schema_version\": 1, \"installed\": [{\"path\": \"/a\"}, {\"name\": \"no path\"}]}",
        )
        .unwrap();
        assert_eq!(
            parse_paths(&doc, "installed").unwrap(),
            vec!["/a".to_owned()]
        );
    }

    #[test]
    fn refuses_output_without_a_document() {
        assert!(document("No updates available\n").is_none());
        let doc = document("{\"updates\": []}").unwrap();
        assert!(
            parse_updates(&doc).is_err(),
            "a document without schema_version is not Gear Lever's"
        );
    }

    #[test]
    fn output_within_returns_output_and_kills_a_hung_child() {
        let mut ok = Command::new("sh");
        ok.args(["-c", "echo out; echo err >&2"]);
        let o = output_within(ok, Duration::from_secs(10)).unwrap();
        assert!(o.status.success());
        assert_eq!(
            (o.stdout.as_slice(), o.stderr.as_slice()),
            (&b"out\n"[..], &b"err\n"[..])
        );
        let mut hung = Command::new("sleep");
        hung.arg("30");
        let start = Instant::now();
        assert!(output_within(hung, Duration::from_millis(300)).is_err());
        assert!(start.elapsed() < Duration::from_secs(10));
    }

    #[test]
    fn the_update_command_never_prompts() {
        assert_eq!(
            update_command(),
            "flatpak run it.mijorus.gearlever --update --all --yes"
        );
    }
}
