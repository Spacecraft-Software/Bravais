# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Shells (bash, Nushell, Ion) + Starship + session vars
# Split from home.nix in Phase D (elegance plan 3.1); zero behavior change.
{
  lib,
  pkgs,
  steelborePalette,
  ...
}:

let
  # ── Shell-init single sources (CLAUDE.md "PATH in home.nix") ─────────────
  # Out-of-band tool dirs (self-updating CLIs installed outside Nix). Stated
  # ONCE here; rendered per shell below. APPENDED, never prepended, so Nix
  # store binaries always win. Adding a dir = one edit to this list.
  outOfBandDirs = [
    ".local/bin"
    ".cargo/bin"
    ".kimi-code/bin"
    ".npm-packages/bin"
    ".opencode/bin"
    ".kilo/bin"
    ".mimocode/bin"
    ".local/lib/qwen-code/bin"
  ];
  # POSIX-ish colon chain ($HOME/d1:$HOME/d2…) — bash and Ion share it.
  posixPathAppend = lib.concatMapStringsSep ":" (d: "$HOME/" + d) outOfBandDirs;
  # Nushell list form: $"($env.HOME)/d1" $"($env.HOME)/d2" …
  nuPathAppend = lib.concatMapStringsSep " " (d: "$\"($env.HOME)/" + d + "\"") outOfBandDirs;

  # gitway-agent socket override — same value in every shell; bash and Ion
  # share the POSIX $(id -u) spelling, Nushell uses its native (id -u).
  # WHY (stated once): PAM's pam_gnome_keyring pins SSH_AUTH_SOCK to
  # /run/user/$UID/keyring/ssh at session start; gitway-agent owns the real
  # socket (CLAUDE.md constraint #8), so every interactive shell re-points it.
  gitwaySockPosix = "/run/user/$(id -u)/gitway-agent.sock";
in
{
  # Session variables
  home.sessionVariables = {
    EDITOR = "${pkgs.msedit}/bin/edit";
    VISUAL = "${pkgs.msedit}/bin/edit";
    BROWSER = "flatpak run com.google.Chrome"; # default browser — see xdg.mimeApps below to change
    STEELBORE_THEME = "true";
    NIXPKGS_ALLOW_UNFREE = "1";
    # bitwarden-cli removed (Flatpak com.bitwarden.desktop used instead)
    # BITWARDENCLI_APPDATA_DIR = "${config.xdg.configHome}/bitwarden-cli";
  };

  programs = {
    # Bash/Brush — kept enabled because NixOS internals (PAM, userdel, etc.)
    # require it. The bashrcExtra below ONLY overrides SSH_AUTH_SOCK back to
    # gitway-agent's socket (PAM's pam_gnome_keyring otherwise pins it to
    # /run/user/$UID/keyring/ssh, which often points at a non-existent
    # socket). No SSH-key auto-load — that runs from each WM's session
    # spawn, see modules/desktops/{niri,leftwm}.nix.
    bash = {
      enable = true;
      bashrcExtra = ''
        export SSH_AUTH_SOCK="${gitwaySockPosix}"
        export PATH="$PATH:${posixPathAppend}"

        # Grok CLI tab-completion. grok is installed out-of-band in
        # ~/.local/bin (not via Nix), so it may be absent on a fresh build —
        # guard the eval so bash startup degrades gracefully when it's missing.
        command -v grok >/dev/null && eval "$(grok completions bash)"
      '';
    };

    # Starship prompt — Steelbore powerline (mirrors
    # /spacecraft-software/theme/Shells/Starship/starship.toml, kept inline so the
    # config doesn't depend on an out-of-flake path at eval time).

    # Starship prompt — Steelbore powerline (mirrors
    # /spacecraft-software/theme/Shells/Starship/starship.toml, kept inline so the
    # config doesn't depend on an out-of-flake path at eval time).
    starship = {
      enable = true;
      settings = {
        "$schema" = "https://starship.rs/config-schema.json";
        scan_timeout = 10000;

        format = "[](red)$os$username[](bg:peach fg:red)$directory[](bg:yellow fg:peach)$git_branch$git_status[](fg:yellow bg:green)$c$rust$golang$nodejs$bun$php$java$kotlin$haskell$python[](fg:green bg:sapphire)$conda[](fg:sapphire bg:lavender)$time[ ](fg:lavender)$cmd_duration$line_break$character";

        palette = "steelbore";

        os = {
          disabled = false;
          style = "bg:red fg:crust";
          symbols = {
            Windows = "";
            Ubuntu = "󰕈";
            SUSE = "";
            Raspbian = "󰐿";
            Mint = "󰣭";
            Macos = "󰀵";
            Manjaro = "";
            Linux = "󰌽";
            Gentoo = "󰣨";
            Fedora = "󰣛";
            Alpine = "";
            Amazon = "";
            Android = "";
            AOSC = "";
            Arch = "󰣇";
            Artix = "󰣇";
            CentOS = "";
            Debian = "󰣚";
            Redhat = "󱄛";
            RedHatEnterprise = "󱄛";
          };
        };

        username = {
          show_always = true;
          style_user = "bg:red fg:crust";
          style_root = "bg:red fg:crust";
          format = "[ $user]($style)";
        };

        directory = {
          style = "bg:peach fg:crust";
          format = "[ $path ]($style)";
          truncation_length = 3;
          truncation_symbol = "…/";

          substitutions = {
            Documents = "󰈙 ";
            Downloads = " ";
            Music = "󰝚 ";
            Pictures = " ";
            Developer = "󰲋 ";
          };
        };

        git_branch = {
          symbol = "";
          style = "bg:yellow";
          format = "[[ $symbol $branch ](fg:crust bg:yellow)]($style)";
        };

        git_status = {
          style = "bg:yellow";
          format = "[[($all_status$ahead_behind )](fg:crust bg:yellow)]($style)";
        };

        nodejs = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };

        bun = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };

        c = {
          symbol = " ";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };

        rust = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };

        golang = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };

        php = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };

        java = {
          symbol = " ";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };

        kotlin = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };

        haskell = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
        };

        python = {
          symbol = "";
          style = "bg:green";
          format = "[[ $symbol( $version)(\\(#$virtualenv\\)) ](fg:crust bg:green)]($style)";
        };

        docker_context = {
          symbol = "";
          style = "bg:sapphire";
          format = "[[ $symbol( $context) ](fg:crust bg:sapphire)]($style)";
        };

        conda = {
          symbol = "  ";
          style = "fg:crust bg:sapphire";
          format = "[$symbol$environment ]($style)";
          ignore_base = false;
        };

        time = {
          disabled = false;
          time_format = "%R";
          style = "bg:lavender";
          format = "[[  $time ](fg:crust bg:lavender)]($style)";
        };

        line_break.disabled = true;

        character = {
          disabled = false;
          success_symbol = "[❯](bold fg:green)";
          error_symbol = "[❯](bold fg:red)";
          vimcmd_symbol = "[❮](bold fg:green)";
          vimcmd_replace_one_symbol = "[❮](bold fg:lavender)";
          vimcmd_replace_symbol = "[❮](bold fg:lavender)";
          vimcmd_visual_symbol = "[❮](bold fg:yellow)";
        };

        cmd_duration = {
          show_milliseconds = true;
          format = " in $duration ";
          style = "bg:lavender";
          disabled = false;
          show_notifications = true;
          min_time_to_notify = 45000;
        };

        # Steelbore palette — Catppuccin role keys preserved so the
        # upstream powerline preset renders unchanged, but every hex
        # value resolves to a token from the Steelbore canonical palette.
        palettes.steelbore = {
          # Powerline section accents
          red = steelborePalette.redOxide; # red_oxide     — OS / username cap
          peach = steelborePalette.moltenAmber; # molten_amber  — directory block
          yellow = "#6272A4"; # slag_grey     — git block
          green = steelborePalette.radiumGreen; # radium_green  — language runtimes
          sapphire = steelborePalette.steelBlue; # steel_blue    — docker / conda
          lavender = steelborePalette.liquidCool; # liquid_cool   — time block

          # Dark canvas (foreground text on bright section blocks)
          crust = steelborePalette.voidNavy;
          mantle = steelborePalette.voidNavy;
          base = steelborePalette.voidNavy;

          # Secondary surfaces
          surface0 = "#050530";
          surface1 = "#050530";
          surface2 = "#050530";

          # Dim / muted scale
          overlay0 = "#6272A4";
          overlay1 = "#6272A4";
          overlay2 = "#6272A4";

          # Foreground text scale
          text = steelborePalette.moltenAmber;
          subtext0 = "#E6E6F0";
          subtext1 = "#E6E6F0";

          # Remaining catppuccin role keys mapped to nearest Steelbore semantic
          rosewater = steelborePalette.redOxide;
          flamingo = steelborePalette.redOxide;
          pink = steelborePalette.redOxide;
          mauve = steelborePalette.redOxide;
          maroon = steelborePalette.redOxide;
          teal = steelborePalette.liquidCool;
          sky = steelborePalette.liquidCool;
          blue = steelborePalette.steelBlue;
        };
      };
    };

    # Nushell configuration

    # Nushell configuration
    nushell = {
      enable = true;
      configFile.text = ''
        # Override SSH_AUTH_SOCK at every interactive shell start. PAM's
        # pam_gnome_keyring sets it to /run/user/$UID/keyring/ssh under
        # greetd, which (a) often points at a non-existent socket and
        # (b) shadows our gitway-agent socket. environment.sessionVariables
        # only takes effect for login shells; non-login shells (terminals
        # spawned inside a DE) inherit the PAM-set value.
        $env.SSH_AUTH_SOCK = $"/run/user/(id -u)/gitway-agent.sock"

        # Set SHELL to bash so tools that read $SHELL (e.g. Claude Code's Bash tool)
        # spawn a bash-compatible shell rather than Nushell.
        $env.SHELL = "${pkgs.bash}/bin/bash"

        # Override Nushell's default PROMPT_MULTILINE_INDICATOR (which ships
        # with ANSI color codes baked in). systemd's `import-environment`
        # refuses to inherit variables whose value contains control chars
        # and emits a warning when niri starts; a plain-ASCII value silences
        # it. The visible UX is identical except the indicator is uncolored.
        $env.PROMPT_MULTILINE_INDICATOR = "::: "

        # Steelbore palette — interpolated from the canonical lib/colors.nix
        # (Nushell needs literal strings inside color_config records; Nix
        # interpolation bakes them in at build time).
        let steelbore = {
          voidNavy:    "${steelborePalette.voidNavy}"
          moltenAmber: "${steelborePalette.moltenAmber}"
          steelBlue:   "${steelborePalette.steelBlue}"
          radiumGreen: "${steelborePalette.radiumGreen}"
          redOxide:    "${steelborePalette.redOxide}"
          liquidCool:  "${steelborePalette.liquidCool}"
        }

        $env.config = {
          show_banner: false,
          ls: { use_ls_colors: true, clickable_links: true },
          cursor_shape: { emacs: block, vi_insert: block, vi_normal: block },
          color_config: {
            separator:        $steelbore.steelBlue
            leading_trailing_space_bg: { attr: "n" }
            header:           { fg: $steelbore.moltenAmber attr: "b" }
            empty:            $steelbore.liquidCool
            bool:             {|v| if $v { $steelbore.radiumGreen } else { $steelbore.redOxide } }
            int:              $steelbore.moltenAmber
            filesize:         {|v| if $v == 0b { $steelbore.steelBlue } else if $v < 1mb { $steelbore.liquidCool } else { $steelbore.moltenAmber } }
            duration:         $steelbore.moltenAmber
            date:             {|v| (date now) - $v | if $in < 1hr { { fg: $steelbore.radiumGreen attr: "b" } } else if $in < 6hr { $steelbore.radiumGreen } else if $in < 1day { $steelbore.moltenAmber } else if $in < 3day { $steelbore.liquidCool } else if $in < 1wk { { fg: $steelbore.liquidCool attr: "b" } } else if $in < 6wk { $steelbore.steelBlue } else if $in < 52wk { { fg: $steelbore.steelBlue attr: "b" } } else { "dark_gray" } }
            range:            $steelbore.moltenAmber
            float:            $steelbore.moltenAmber
            string:           $steelbore.moltenAmber
            nothing:          $steelbore.liquidCool
            binary:           $steelbore.liquidCool
            cell-path:        $steelbore.steelBlue
            row_index:        { fg: $steelbore.steelBlue attr: "b" }
            record:           $steelbore.moltenAmber
            list:             $steelbore.moltenAmber
            block:            $steelbore.moltenAmber
            hints:            "dark_gray"
            search_result:    { fg: $steelbore.voidNavy bg: $steelbore.moltenAmber }

            shape_and:                { fg: $steelbore.radiumGreen attr: "b" }
            shape_binary:             { fg: $steelbore.liquidCool attr: "b" }
            shape_block:              { fg: $steelbore.liquidCool attr: "b" }
            shape_bool:               $steelbore.radiumGreen
            shape_closure:            { fg: $steelbore.radiumGreen attr: "b" }
            shape_custom:             $steelbore.radiumGreen
            shape_datetime:           { fg: $steelbore.liquidCool attr: "b" }
            shape_directory:          $steelbore.liquidCool
            shape_external:           $steelbore.moltenAmber
            shape_externalarg:        { fg: $steelbore.radiumGreen attr: "b" }
            shape_external_resolved:  { fg: $steelbore.liquidCool attr: "b" }
            shape_filepath:           $steelbore.steelBlue
            shape_flag:               { fg: $steelbore.steelBlue attr: "b" }
            shape_float:              { fg: $steelbore.moltenAmber attr: "b" }
            shape_garbage:            { fg: $steelbore.redOxide bg: $steelbore.voidNavy attr: "b" }
            shape_glob_interpolation: { fg: $steelbore.liquidCool attr: "b" }
            shape_globpattern:        { fg: $steelbore.liquidCool attr: "b" }
            shape_int:                { fg: $steelbore.moltenAmber attr: "b" }
            shape_internalcall:       { fg: $steelbore.moltenAmber attr: "b" }
            shape_keyword:            { fg: $steelbore.radiumGreen attr: "b" }
            shape_list:               { fg: $steelbore.liquidCool attr: "b" }
            shape_literal:            $steelbore.steelBlue
            shape_match_pattern:      $steelbore.radiumGreen
            shape_matching_brackets:  { attr: "u" }
            shape_nothing:            $steelbore.liquidCool
            shape_operator:           $steelbore.moltenAmber
            shape_or:                 { fg: $steelbore.radiumGreen attr: "b" }
            shape_pipe:               { fg: $steelbore.radiumGreen attr: "b" }
            shape_range:              { fg: $steelbore.moltenAmber attr: "b" }
            shape_record:             { fg: $steelbore.liquidCool attr: "b" }
            shape_redirection:        { fg: $steelbore.radiumGreen attr: "b" }
            shape_signature:          { fg: $steelbore.radiumGreen attr: "b" }
            shape_string:             $steelbore.steelBlue
            shape_string_interpolation: { fg: $steelbore.liquidCool attr: "b" }
            shape_table:              { fg: $steelbore.steelBlue attr: "b" }
            shape_variable:           $steelbore.steelBlue
            shape_vardecl:            $steelbore.steelBlue
            shape_raw_string:         $steelbore.steelBlue
            shape_garbage_unknown:    { fg: $steelbore.redOxide attr: "b" }
          }
        }

        # Steelbore Telemetry Aliases
        alias ll = ls -l
        alias lla = ls -la
        alias telemetry = macchina
        alias sensors = ^watch -n 1 sensors
        alias sys-logs = journalctl -p 3 -xb
        alias network-diag = gping google.com
        alias top-processes = bottom
        alias disk-telemetry = yazi
        alias edit = ${pkgs.msedit}/bin/edit

        # Project Steelbore Identity
        def steelbore [] {
          print "============================================================"
          print "  STEELBORE :: Industrial Sci-Fi Desktop Environment"
          print "============================================================"
          print "  STATUS    :: ACTIVE"
          print "  LOAD      :: NOMINAL"
          print "  INTEGRITY :: VERIFIED"
          print "============================================================"
        }


        # Update the Construct skill flake input — thin alias to the construct
        # CLI (`construct skill sync`, flake-update-only). Run rebuild afterwards
        # to apply. The binary is on PATH via home.packages.
        def skills-sync [topic?: string] {
          if $topic == "help" { ^construct skill sync --help; return }
          if $topic != null { print $"(ansi red)unknown argument '($topic)' — try: skills-sync help(ansi reset)"; return }
          ^construct skill sync
        }

        # Ship local Construct skill edits — commit (signed) + push, then sync.
        # Run from / pointed at the construct clone; rebuild afterwards to apply.
        def skills-ship [topic?: string] {
          if $topic == "help" { ^construct skill ship --help; return }
          if $topic != null { print $"(ansi red)unknown argument '($topic)' — try: skills-ship help(ansi reset)"; return }
          ^construct skill ship
        }

        # Full system rebuild for bravais-thinkpad: load the signing key, bump
        # the tracked flake inputs (construct == skills-sync; nixpkgs-unstable +
        # home-manager-unstable so unstablePkgs never lags stable — elegance
        # plan 5.2), free disk while keeping a week of rollback targets,
        # build + switch, then mirror the repo into /etc/nixos. A failed
        # switch aborts before the mirror.
        #   --dry        nixos-rebuild dry-build only; skips GC and the /etc mirror
        #   --no-update  skip `nix flake update`
        #   --no-gc      skip garbage collection + journal vacuum
        #   --trace      add --show-trace --verbose (to diagnose eval failures)
        def rebuild [topic?: string, --dry, --no-update, --no-gc, --trace] {
          if $topic == "help" { help rebuild; return }
          if $topic != null { print $"(ansi red)unknown argument '($topic)' — try: rebuild help(ansi reset)"; return }
          cd /spacecraft-software/bravais
          # Monthly vendored-binary reminder (elegance plan 5.1): claude-desktop,
          # chrome-remote-desktop, ollama, and BrowserOS pin upstream binaries
          # that `nix flake update` cannot bump.
          let stamp = ($nu.home-path | path join ".cache" "bravais-vendored-check")
          let stale = (not ($stamp | path exists)) or ((date now) - (ls $stamp | get 0.modified) > 30day)
          if $stale {
            print $"(ansi yellow)vendored binaries unchecked for 30+ days — run: nu pkgs/update-vendored.nu --check(ansi reset)"
            mkdir ($stamp | path dirname); touch $stamp
          }
          if not $no_update {
            gitway-add ~/.ssh/id_ed25519
            nix flake update antigravity-nix construct gitway nixpkgs-unstable home-manager-unstable
          }
          if (not $no_gc) and (not $dry) {
            try { sudo nix-collect-garbage --delete-older-than 7d }
            try { sudo journalctl --vacuum-time=7d }
          }
          print $"(ansi blue)── disk before ──(ansi reset)"; df -h /
          # --option warn-dirty false silences the "Git tree is dirty" warning on
          # the local flake eval (also set declaratively via nix.settings.warn-dirty;
          # this covers the rebuild run before that lands in /etc/nix/nix.conf).
          # nixos-rebuild-ng rejects nix's --no-warn-dirty passthrough, so use the
          # forwarded --option form it does accept.
          let extra = (["--option" "warn-dirty" "false"] | append (if $trace { ["--show-trace" "--verbose"] } else { [] }))
          if $dry {
            sudo nixos-rebuild dry-build --flake .#bravais-thinkpad ...$extra
          } else {
            sudo nixos-rebuild switch --flake .#bravais-thinkpad ...$extra
            # Lean true mirror: prune stale files, but skip VCS internals,
            # the build symlink, and agent-local context (.claude is gitignored).
            sudo rsync -av --delete --delete-excluded --exclude='.git/' --exclude='result' --exclude='.claude/' /spacecraft-software/bravais/ /etc/nixos/
            print $"(ansi green)── disk after ──(ansi reset)"; df -h /
          }
        }

        # User-local bins — appended so Nix store paths take precedence
        $env.PATH = ($env.PATH | append [${nuPathAppend}])
      '';
    };

    # Alacritty (Steelbore theme)
  };

  xdg.configFile = {
    # ═══════════════════════════════════════════════════════════════════════════
    # ZELLIJ — managed as a *writable* copy, NOT here.
    # zellij rewrites config.kdl at runtime, which fails against a read-only
    # Nix-store symlink ("Failed to write configuration file"). The config is
    # rendered to `zellijConfigFile` (let-block) and installed writable by
    # `home.activation.zellijConfig`. Do not re-add it to xdg.configFile.
    # ═══════════════════════════════════════════════════════════════════════════

    # ═══════════════════════════════════════════════════════════════════════════
    # ION — Shell init (Starship prompt)
    # ═══════════════════════════════════════════════════════════════════════════
    "ion/initrc".text = ''
      # Steelbore Ion Shell Init

      # Override SSH_AUTH_SOCK back to gitway-agent's socket. PAM's
      # pam_gnome_keyring otherwise sets it to /run/user/$UID/keyring/ssh.
      let SSH_AUTH_SOCK = "${gitwaySockPosix}"
      export SSH_AUTH_SOCK

      # User-local bins — appended so Nix store paths take precedence
      let PATH = "$PATH:${posixPathAppend}"
      export PATH

      # Starship prompt
      eval $(${pkgs.starship}/bin/starship init ion)

      # Aliases
      alias ll = ls -l
      alias lla = ls -la
      alias telemetry = macchina
      alias sensors = watch -n 1 sensors
      alias sys-logs = journalctl -p 3 -xb
      alias top-processes = bottom
      alias disk-telemetry = yazi
      alias edit = ${pkgs.msedit}/bin/edit
    '';
  };
}
