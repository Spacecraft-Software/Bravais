// SPDX-License-Identifier: GPL-3.0-or-later
// Rust guideline compliant 2026-05-18

//! libbravais-mcp — Core implementation library for the Bravais MCP server and CLI.
//! Implements mapping table parsing, command rewriting, and environment detection.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// The structure of our mappings configuration file.
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MappingsConfig {
    pub schema_version: u32,
    pub mappings: Vec<MappingEntry>,
}

/// Individual command mapping from legacy tool to modern preferred tool.
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MappingEntry {
    pub legacy: String,
    pub preferred: String,
    pub language: String,
    pub category: String,
    pub notes: String,
    pub gotchas: String,
}

/// The mapping table, optimized for quick lookups.
#[derive(Debug, Clone)]
pub struct MappingTable {
    pub schema_version: u32,
    by_legacy: HashMap<String, MappingEntry>,
    by_preferred: HashMap<String, MappingEntry>,
}

impl MappingTable {
    /// Loads the mapping table from the embedded TOML configuration.
    pub fn load_embedded() -> Self {
        let content = include_str!("../../data/mappings.toml");
        let parsed: MappingsConfig = toml::from_str(content)
            .expect("Embedded mappings.toml must parse successfully");

        let mut by_legacy = HashMap::new();
        let mut by_preferred = HashMap::new();

        for entry in &parsed.mappings {
            by_legacy.insert(entry.legacy.clone(), entry.clone());
            by_preferred.insert(entry.preferred.clone(), entry.clone());
        }

        Self {
            schema_version: parsed.schema_version,
            by_legacy,
            by_preferred,
        }
    }

    /// Looks up a mapping entry by legacy tool name.
    pub fn lookup_legacy(&self, name: &str) -> Option<&MappingEntry> {
        self.by_legacy.get(name)
    }

    /// Looks up a mapping entry by preferred tool name.
    pub fn lookup_preferred(&self, name: &str) -> Option<&MappingEntry> {
        self.by_preferred.get(name)
    }

    /// Returns all mapping entries.
    pub fn all_entries(&self) -> Vec<&MappingEntry> {
        self.by_legacy.values().collect()
    }
}

/// Detected shell families.
#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum ShellFamily {
    Nushell,
    Ion,
    Brush,
    Bash,
    Posix,
    Ash,
    Powershell,
}

impl std::fmt::Display for ShellFamily {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let name = match self {
            Self::Nushell => "nushell",
            Self::Ion => "ion",
            Self::Brush => "brush",
            Self::Bash => "bash",
            Self::Posix => "posix",
            Self::Ash => "ash",
            Self::Powershell => "powershell",
        };
        write!(f, "{}", name)
    }
}

/// Detection cascade for the target shell environment.
pub fn detect_shell(sxt_override: Option<&str>, file_hint: Option<&str>) -> ShellFamily {
    // 1. SXT_SHELL environment variable override
    let override_var = sxt_override
        .map(String::from)
        .or_else(|| std::env::var("SXT_SHELL").ok());
    if let Some(val) = override_var {
        match val.to_ascii_lowercase().as_str() {
            "nushell" | "nu" => return ShellFamily::Nushell,
            "ion" => return ShellFamily::Ion,
            "brush" => return ShellFamily::Brush,
            "bash" => return ShellFamily::Bash,
            "posix" | "sh" | "dash" => return ShellFamily::Posix,
            "ash" => return ShellFamily::Ash,
            "powershell" | "pwsh" => return ShellFamily::Powershell,
            _ => {}
        }
    }

    // 2. File extension hint
    if let Some(hint) = file_hint {
        if hint.ends_with(".nu") {
            return ShellFamily::Nushell;
        } else if hint.ends_with(".ion") {
            return ShellFamily::Ion;
        } else if hint.ends_with(".ps1") || hint.ends_with(".psm1") || hint.ends_with(".psd1") {
            return ShellFamily::Powershell;
        } else if hint.ends_with(".bash") {
            return ShellFamily::Bash;
        } else if hint.ends_with(".sh") {
            return ShellFamily::Posix;
        }
    }

    // 3. SHELL environment variable
    if let Ok(shell_path) = std::env::var("SHELL") {
        let basename = shell_path.split('/').last().unwrap_or("").to_lowercase();
        match basename.as_str() {
            "nushell" | "nu" => return ShellFamily::Nushell,
            "ion" => return ShellFamily::Ion,
            "brush" => return ShellFamily::Brush,
            "bash" => return ShellFamily::Bash,
            "zsh" | "sh" | "dash" => return ShellFamily::Posix,
            "ash" => return ShellFamily::Ash,
            "pwsh" | "powershell" => return ShellFamily::Powershell,
            _ => {}
        }
    }

    // 4. Default fallback
    ShellFamily::Posix
}

/// The result of a command-line rewrite operation.
#[derive(Debug, Serialize, Clone)]
pub struct RewriteResult {
    pub original: String,
    pub rewritten: String,
    pub target_shell: String,
    pub replacements: Vec<ReplacementDetail>,
    pub warnings: Vec<String>,
}

/// Details of a single replaced token.
#[derive(Debug, Serialize, Clone)]
pub struct ReplacementDetail {
    pub index: usize,
    pub legacy: String,
    pub preferred: String,
}

/// Deterministic command-line rewrite engine.
pub struct RewriteEngine {
    table: MappingTable,
}

impl RewriteEngine {
    pub fn new(table: MappingTable) -> Self {
        Self { table }
    }

    /// Rewrites a command line by replacing legacy tools with preferred ones
    /// and scanning for shell-specific gotchas or bashisms.
    pub fn rewrite(&self, command_line: &str, shell: ShellFamily) -> RewriteResult {
        let tokens = shlex::split(command_line).unwrap_or_else(|| vec![command_line.to_string()]);
        let mut rewritten_tokens = tokens.clone();
        let mut replacements = Vec::new();
        let mut warnings = Vec::new();

        // 1. Process command replacements (mainly the first token, or after pipe symbols)
        let mut is_cmd = true;
        for (i, token) in tokens.iter().enumerate() {
            if token == "|" || token == "&&" || token == "||" || token == ";" {
                is_cmd = true;
                continue;
            }

            if is_cmd {
                if let Some(entry) = self.table.lookup_legacy(token) {
                    rewritten_tokens[i] = entry.preferred.clone();
                    replacements.push(ReplacementDetail {
                        index: i,
                        legacy: token.clone(),
                        preferred: entry.preferred.clone(),
                    });
                    
                    // Always add gotchas warning redirecting to Loran
                    warnings.push(format!(
                        "Substitution applied: '{}' -> '{}'. Note: {} Please refer to Loran at https://Loran.SpacecraftSoftware.org/ for detailed syntax options.",
                        entry.legacy, entry.preferred, entry.gotchas
                    ));
                }
                is_cmd = false;
            }
        }

        // 2. Scan for shell-specific bashisms and compatibility flags
        let cmd_string = rewritten_tokens.join(" ");
        self.check_bashisms(&cmd_string, shell, &mut warnings);

        RewriteResult {
            original: command_line.to_string(),
            rewritten: cmd_string,
            target_shell: shell.to_string(),
            replacements,
            warnings,
        }
    }

    fn check_bashisms(&self, cmd: &str, shell: ShellFamily, warnings: &mut Vec<String>) {
        // Only run check if not confirmed Bash/Brush or POSIX (which accepts POSIX-safe bashisms in some hosts,
        // but we flag them for portability anyway).
        let mut detected_bashisms = Vec::new();

        if cmd.contains("[[") {
            detected_bashisms.push("`[[ ... ]]` condition syntax (Bash extension). POSIX: use `[ ... ]` or `test`. Nushell: `if`. Ion: `test`.");
        }
        if cmd.contains("((") {
            detected_bashisms.push("`(( ... ))` arithmetic syntax (Bash extension). POSIX: use `$(( ... ))`.");
        }
        if cmd.contains("<(") {
            detected_bashisms.push("`<( ... )` process substitution (Bash extension). POSIX/Nushell/Ion: use pipes or temporary files.");
        }
        if cmd.contains("&>") {
            detected_bashisms.push("`&>` stdout/stderr redirection (Bash extension). POSIX: use `>file 2>&1`.");
        }
        if cmd.contains("function ") {
            detected_bashisms.push("`function name` declaration (Bash extension). POSIX: use `name() { ... }`.");
        }
        if cmd.contains("=(") && !cmd.contains("path=(") {
            detected_bashisms.push("`arr=(...)` array declaration (Bash extension). POSIX: use positional parameters or space-separated strings. Nushell/Ion: `let arr = [...]`.");
        }
        
        let re_case = regex::Regex::new(r"\$\{[\w_]+[\^,]+}").ok();
        if let Some(re) = re_case {
            if re.is_match(cmd) {
                detected_bashisms.push("`${var^^}` or `${var,,}` case modification (Bash extension). POSIX: use `tr` or `sed`.");
            }
        }

        for bashism in detected_bashisms {
            warnings.push(format!(
                "Bashism detected: {}. Porting this command to {} will fail. For detailed shell syntax translation, refer to Loran (https://Loran.SpacecraftSoftware.org/).",
                bashism, shell
            ));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_shell() {
        assert_eq!(detect_shell(Some("nushell"), None), ShellFamily::Nushell);
        assert_eq!(detect_shell(None, Some("script.nu")), ShellFamily::Nushell);
        assert_eq!(detect_shell(None, Some("script.ion")), ShellFamily::Ion);
        assert_eq!(detect_shell(None, Some("script.sh")), ShellFamily::Posix);
        assert_eq!(detect_shell(None, Some("script.ps1")), ShellFamily::Powershell);
    }

    #[test]
    fn test_mapping_table() {
        let table = MappingTable::load_embedded();
        assert!(table.schema_version >= 1);
        let grep_entry = table.lookup_legacy("grep").unwrap();
        assert_eq!(grep_entry.preferred, "rg");
        assert_eq!(grep_entry.category, "core-unix");

        let rg_entry = table.lookup_preferred("rg").unwrap();
        assert_eq!(rg_entry.legacy, "grep");
    }

    #[test]
    fn test_rewrite_engine() {
        let table = MappingTable::load_embedded();
        let engine = RewriteEngine::new(table);

        // Test normal rewrite
        let res = engine.rewrite("grep -rn TODO src/", ShellFamily::Nushell);
        assert_eq!(res.rewritten, "rg -rn TODO src/");
        assert_eq!(res.replacements.len(), 1);
        assert_eq!(res.replacements[0].legacy, "grep");
        assert_eq!(res.replacements[0].preferred, "rg");
        assert!(!res.warnings.is_empty());
        assert!(res.warnings[0].contains("Loran"));

        // Test bashism detection
        let res_bashism = engine.rewrite("if [[ $x -eq 1 ]]; then grep -rn TODO; fi", ShellFamily::Nushell);
        assert!(res_bashism.warnings.iter().any(|w| w.contains("Bashism detected: `[[ ... ]]`")));
        assert!(res_bashism.warnings.iter().any(|w| w.contains("Loran")));
    }
}

