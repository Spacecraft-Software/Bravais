# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager Configuration
{
  config,
  pkgs,
  lib,
  steelborePalette,
  gitway,
  construct,
  unstablePkgs,
  ...
}:

let
  # Foot requires hex colors without the '#' prefix
  h = c: builtins.substring 1 (builtins.stringLength c - 1) c;

  # Wallpaper daemon: upstream renamed swww → awww. On unstable both
  # exist (swww is a deprecation alias that warns); on stable 25.11
  # only swww. The `or`-fallback picks the right package per channel;
  # binary names follow the package name (awww/awww-daemon vs
  # swww/swww-daemon), so wallpaperBin tracks. Mirrors the system-wide
  # logic in modules/desktops/niri.nix.
  wallpaperPkg = pkgs.awww or pkgs.swww;
  wallpaperBin = if pkgs ? awww then "awww" else "swww";

  # ZELLIJ — Full Steelbore config, rendered to a store file so it can be
  # installed as a *writable* copy (see home.activation.zellijConfig below).
  # Zellij persists config.kdl at runtime (e.g. its in-app Configuration
  # screen), so a read-only Nix-store symlink yields
  # "Failed to write configuration file". Nix stays source of truth: the
  # writable copy is refreshed on every activation.
  zellijConfigFile = pkgs.writeText "zellij-config.kdl" ''
    theme "steelbore"
    default_shell "${pkgs.nushell}/bin/nu"
    simplified_ui false
    pane_frames true
    mouse_mode true
    copy_on_select true
    // Bound per-pane scrollback so a flood of build output can't balloon the server's
    // memory (defense in depth alongside zram + earlyoom). Lower to 5000 if pressure persists.
    scroll_buffer_size 10000

    themes {
        steelbore {
            text_unselected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            text_selected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            ribbon_selected {
                base "${steelborePalette.voidNavy}"
                background "${steelborePalette.moltenAmber}"
                emphasis_0 "${steelborePalette.redOxide}"
                emphasis_1 "${steelborePalette.moltenAmber}"
                emphasis_2 "${steelborePalette.steelBlue}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            ribbon_unselected {
                base "${steelborePalette.voidNavy}"
                background "${steelborePalette.steelBlue}"
                emphasis_0 "${steelborePalette.redOxide}"
                emphasis_1 "${steelborePalette.moltenAmber}"
                emphasis_2 "${steelborePalette.steelBlue}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            table_title {
                base "${steelborePalette.radiumGreen}"
                background 0
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            table_cell_selected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            table_cell_unselected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            list_selected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            list_unselected {
                base "${steelborePalette.moltenAmber}"
                background "${steelborePalette.voidNavy}"
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.radiumGreen}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            frame_selected {
                base "${steelborePalette.moltenAmber}"
                background 0
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 "${steelborePalette.liquidCool}"
                emphasis_2 "${steelborePalette.steelBlue}"
                emphasis_3 0
            }
            frame_highlight {
                base "${steelborePalette.moltenAmber}"
                background 0
                emphasis_0 "${steelborePalette.steelBlue}"
                emphasis_1 0
                emphasis_2 "${steelborePalette.moltenAmber}"
                emphasis_3 "${steelborePalette.moltenAmber}"
            }
            exit_code_success {
                base "${steelborePalette.radiumGreen}"
                background 0
                emphasis_0 "${steelborePalette.liquidCool}"
                emphasis_1 "${steelborePalette.voidNavy}"
                emphasis_2 "${steelborePalette.steelBlue}"
                emphasis_3 "${steelborePalette.steelBlue}"
            }
            exit_code_error {
                base "${steelborePalette.redOxide}"
                background 0
                emphasis_0 "${steelborePalette.moltenAmber}"
                emphasis_1 0
                emphasis_2 0
                emphasis_3 0
            }
            multiplayer_user_colors {
                player_1 "${steelborePalette.steelBlue}"
                player_2 "${steelborePalette.steelBlue}"
                player_3 0
                player_4 "${steelborePalette.moltenAmber}"
                player_5 "${steelborePalette.liquidCool}"
                player_6 0
                player_7 "${steelborePalette.redOxide}"
                player_8 0
                player_9 0
                player_10 0
            }
        }
    }
  '';
in

{
  imports = [ construct.homeManagerModules.default ];

  # Construct skill hub — installs all cross-platform skills from
  # github:Spacecraft-Software/Construct into ~/.agents/skills/ (Nix store)
  # and symlinks each agent harness to it. Run `skills-sync` then rebuild
  # to pull the latest skill set.
  # .gemini intentionally omitted — Gemini reads ~/.agents/ directly.
  spacecraft.construct = {
    enable = true;
    enableGrok = true;
    agentPaths = [
      ".agent/skills"
      ".ai/skills"
      ".aichat/skills"
      ".claude/skills"
      ".codex/skills"
      ".copilot/skills"
      ".opencode/skills"
    ];
  };

  home.username = "mj";
  home.homeDirectory = "/home/mj";
  home.stateVersion = "26.05";

  # Rust toolchain — rustup manages rustc/cargo/rustfmt/clippy itself.
  # Installing standalone cargo/rustc alongside rustup causes a buildEnv
  # conflict (both ship _cargo zsh completions). After rebuild run:
  #   rustup install stable && rustup default stable
  home.packages = (with unstablePkgs; [
    rustup          # manages rustc/cargo/rustfmt/clippy/rust-analyzer as components
    cargo-update    # cargo install-update subcommand
    cargo-watch
    cargo-nextest
    cargo-audit
    sccache
    cargo-expand
  ]) ++ [
    # `construct` skills CLI from the Construct flake input (constraint #7:
    # flake-input package consumed by attr-path, threaded via extraSpecialArgs).
    construct.packages.${pkgs.stdenv.hostPlatform.system}.construct

    # Run a heavy build inside a memory-capped, killable systemd scope so a runaway
    # cargo/rustc is contained (and OOM-killed within its own cgroup) instead of
    # competing with — and taking down — the editor/multiplexer session.
    # Usage: cargo-capped test -p <crate>
    (pkgs.writeShellScriptBin "cargo-capped" ''
      exec systemd-run --user --scope --quiet \
        -p MemoryMax=24G -p MemorySwapMax=8G -- cargo "$@"
    '')
  ];

  home.file = {
    # Steelbore project symlink
    "steelbore".source = config.lib.file.mkOutOfStoreSymlink "/spacecraft-software";


  };

  # Keyboard layout
  home.keyboard = {
    layout = "us,ara";
    options = [ "grp:ctrl_space_toggle" ];
  };

  # Session variables
  home.sessionVariables = {
    EDITOR  = "${pkgs.msedit}/bin/edit";
    VISUAL  = "${pkgs.msedit}/bin/edit";
    BROWSER = "flatpak run com.google.Chrome";  # default browser — see xdg.mimeApps below to change
    STEELBORE_THEME = "true";
    NIXPKGS_ALLOW_UNFREE = "1";
    # bitwarden-cli removed (Flatpak com.bitwarden.desktop used instead)
    # BITWARDENCLI_APPDATA_DIR = "${config.xdg.configHome}/bitwarden-cli";
  };


  # Refresh the tealdeer (tldr) cache on every home-manager activation.
  # `tldr --update` pulls the latest pages bundle. Failure is non-fatal so
  # an offline rebuild still succeeds.
  home.activation.tldrUpdate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.tealdeer}/bin/tldr --update >/dev/null 2>&1 || true
  '';

  # Install zellij's config.kdl as a writable file (see zellijConfigFile in the
  # let-block). Must be writable so zellij can persist runtime config changes
  # without erroring; refreshed each activation so Nix remains source of truth.
  home.activation.zellijConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -Dm644 ${zellijConfigFile} "$HOME/.config/zellij/config.kdl"
  '';

  # Programs
  programs = {
    # Git-LFS
    git.lfs.enable = true;

    # Git configuration
    git = {
      enable = true;
      settings = {
        user.name = "UnbreakableMJ";
        user.email = "Mohamed.Hammad@SpacecraftSoftware.org";
        user.signingkey = "~/.ssh/id_ed25519.pub";
        gpg.program = "${pkgs.sequoia-chameleon-gnupg}/bin/gpg-sq";
        gpg.format = "ssh";
        gpg.ssh.program = "${gitway.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/gitway-keygen";
        commit.gpgsign = true;
        init.defaultBranch = "main";
        "credential.https://github.com".helper = ["" "!${pkgs.gh}/bin/gh auth git-credential"];
        "credential.https://gist.github.com".helper = ["" "!${pkgs.gh}/bin/gh auth git-credential"];
      };
    };

    # Bash/Brush — kept enabled because NixOS internals (PAM, userdel, etc.)
    # require it. The bashrcExtra below ONLY overrides SSH_AUTH_SOCK back to
    # gitway-agent's socket (PAM's pam_gnome_keyring otherwise pins it to
    # /run/user/$UID/keyring/ssh, which often points at a non-existent
    # socket). No SSH-key auto-load — that runs from each WM's session
    # spawn, see modules/desktops/{niri,leftwm}.nix.
    bash = {
      enable = true;
      bashrcExtra = ''
        export SSH_AUTH_SOCK="/run/user/$(id -u)/gitway-agent.sock"
        export PATH="$PATH:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.kimi-code/bin:$HOME/.npm-packages/bin:$HOME/.opencode/bin:$HOME/.kilo/bin:$HOME/.mimocode/bin:$HOME/.local/lib/qwen-code/bin"

        # Grok CLI tab-completion. grok is installed out-of-band in
        # ~/.local/bin (not via Nix), so it may be absent on a fresh build —
        # guard the eval so bash startup degrades gracefully when it's missing.
        command -v grok >/dev/null && eval "$(grok completions bash)"
      '';
    };

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
          red      = "#FF5C5C";  # red_oxide     — OS / username cap
          peach    = "#D98E32";  # molten_amber  — directory block
          yellow   = "#6272A4";  # slag_grey     — git block
          green    = "#50FA7B";  # radium_green  — language runtimes
          sapphire = "#4B7EB0";  # steel_blue    — docker / conda
          lavender = "#8BE9FD";  # liquid_cool   — time block

          # Dark canvas (foreground text on bright section blocks)
          crust  = "#000027";
          mantle = "#000027";
          base   = "#000027";

          # Secondary surfaces
          surface0 = "#050530";
          surface1 = "#050530";
          surface2 = "#050530";

          # Dim / muted scale
          overlay0 = "#6272A4";
          overlay1 = "#6272A4";
          overlay2 = "#6272A4";

          # Foreground text scale
          text     = "#D98E32";
          subtext0 = "#E6E6F0";
          subtext1 = "#E6E6F0";

          # Remaining catppuccin role keys mapped to nearest Steelbore semantic
          rosewater = "#FF5C5C";
          flamingo  = "#FF5C5C";
          pink      = "#FF5C5C";
          mauve     = "#FF5C5C";
          maroon    = "#FF5C5C";
          teal      = "#8BE9FD";
          sky       = "#8BE9FD";
          blue      = "#4B7EB0";
        };
      };
    };

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

        # Steelbore palette — kept in sync with flake.nix steelborePalette.
        # Nushell needs literals; env-var interpolation isn't available inside
        # color_config records.
        let steelbore = {
          voidNavy:    "#000027"
          moltenAmber: "#D98E32"
          steelBlue:   "#4B7EB0"
          radiumGreen: "#50FA7B"
          redOxide:    "#FF5C5C"
          liquidCool:  "#8BE9FD"
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
        def skills-sync [] { ^construct skill sync }

        # Ship local Construct skill edits — commit (signed) + push, then sync.
        # Run from / pointed at the construct clone; rebuild afterwards to apply.
        def skills-ship [] { ^construct skill ship }

        # Full system rebuild for bravais-thinkpad: load the signing key, bump
        # the three tracked flake inputs (construct == skills-sync), free disk
        # while keeping a week of rollback targets, build + switch, then mirror
        # the repo into /etc/nixos. A failed switch aborts before the mirror.
        #   --dry        nixos-rebuild dry-build only; skips GC and the /etc mirror
        #   --no-update  skip `nix flake update`
        #   --no-gc      skip garbage collection + journal vacuum
        #   --trace      add --show-trace --verbose (to diagnose eval failures)
        def rebuild [--dry, --no-update, --no-gc, --trace] {
          cd /spacecraft-software/bravais
          if not $no_update {
            gitway-add ~/.ssh/id_ed25519
            nix flake update antigravity-nix construct gitway
          }
          if (not $no_gc) and (not $dry) {
            try { sudo nix-collect-garbage --delete-older-than 7d }
            try { sudo journalctl --vacuum-time=7d }
          }
          print $"(ansi blue)── disk before ──(ansi reset)"; df -h /
          let extra = (if $trace { ["--show-trace" "--verbose"] } else { [] })
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
        $env.PATH = ($env.PATH | append [$"($env.HOME)/.local/bin" $"($env.HOME)/.cargo/bin" $"($env.HOME)/.kimi-code/bin" $"($env.HOME)/.npm-packages/bin" $"($env.HOME)/.opencode/bin" $"($env.HOME)/.kilo/bin" $"($env.HOME)/.mimocode/bin" $"($env.HOME)/.local/lib/qwen-code/bin"])
      '';
    };

    # Alacritty (Steelbore theme)
    alacritty = {
      enable = true;
      settings = {
        terminal.shell = {
          program = "${pkgs.nushell}/bin/nu";
        };
        window = {
          padding = {
            x = 10;
            y = 10;
          };
          dynamic_title = true;
          opacity = 0.95;
        };
        font = {
          normal = {
            family = "JetBrainsMono Nerd Font";
            style = "Regular";
          };
          size = 10.0;
        };
        colors = {
          primary = {
            background = steelborePalette.voidNavy;
            foreground = steelborePalette.moltenAmber;
          };
          cursor = {
            text = steelborePalette.voidNavy;
            cursor = steelborePalette.moltenAmber;
          };
          selection = {
            text = steelborePalette.voidNavy;
            background = steelborePalette.steelBlue;
          };
          normal = {
            black = steelborePalette.voidNavy;
            red = steelborePalette.redOxide;
            green = steelborePalette.radiumGreen;
            yellow = steelborePalette.moltenAmber;
            blue = steelborePalette.steelBlue;
            magenta = steelborePalette.steelBlue;
            cyan = steelborePalette.liquidCool;
            white = steelborePalette.moltenAmber;
          };
          bright = {
            black = steelborePalette.steelBlue;
            red = steelborePalette.redOxide;
            green = steelborePalette.radiumGreen;
            yellow = steelborePalette.moltenAmber;
            blue = steelborePalette.liquidCool;
            magenta = steelborePalette.liquidCool;
            cyan = steelborePalette.liquidCool;
            white = steelborePalette.moltenAmber;
          };
        };
      };
    };
  };

  # GPG agent — uses pinentry-qt for KDE wallet and commit signing prompts
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
  };

  # gitway-agent itself is enabled system-wide via services.gitway-agent.enable
  # in modules/core/security.nix (NixOS module from the gitway flake). That
  # module also writes /etc/environment.d/10-gitway-agent.conf and registers
  # the hardened systemd.user.services.gitway-agent unit, so neither needs to
  # be duplicated here.

  # SSH key loading happens lazily via the bash/brush rc snippet above on the
  # first interactive shell. A boot-time systemd user unit was tried but
  # failed silently against passphrase-protected keys without a TTY/SSH_ASKPASS.

  # Default web browser.
  #
  # To change the default browser, edit BOTH of the following to point at the
  # new app's `.desktop` id (find it under any of these dirs:
  #   ~/.local/share/applications, /run/current-system/sw/share/applications,
  #   ~/.local/share/flatpak/exports/share/applications — Flatpak ids look like
  #   `com.google.Chrome.desktop`, `org.mozilla.firefox.desktop`):
  #
  #   1. `xdg.mimeApps.defaultApplications` below — writes ~/.config/mimeapps.list,
  #      the declarative source of truth consulted by xdg-open, Niri, and the
  #      desktop portals. HM owns this file (conflicts backed up to
  #      mimeapps.list.backup), so do NOT hand-edit it — change it here.
  #   2. `BROWSER` in `home.sessionVariables` (top of this file) — for CLI tools
  #      that open URLs via $BROWSER. Verified to reach all four shells
  #      (Nushell, Ion, Brush, Bash): the greetd session sources
  #      hm-session-vars.sh at login, and every WM-spawned shell inherits it.
  #
  # After editing, `nixos-rebuild switch` makes both live. To set them
  # immediately in an already-running session without a rebuild (optional —
  # the rebuild re-asserts the same values, so this only avoids a relogin):
  #   xdg-settings set default-web-browser com.google.Chrome.desktop
  #   xdg-mime default com.google.Chrome.desktop x-scheme-handler/http
  #   xdg-mime default com.google.Chrome.desktop x-scheme-handler/https
  #   xdg-mime default com.google.Chrome.desktop text/html
  # Verify with: xdg-settings get default-web-browser
  #              xdg-mime query default x-scheme-handler/https
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html"                = "com.google.Chrome.desktop";
      "x-scheme-handler/http"   = "com.google.Chrome.desktop";
      "x-scheme-handler/https"  = "com.google.Chrome.desktop";
      "x-scheme-handler/about"  = "com.google.Chrome.desktop";
      "x-scheme-handler/unknown" = "com.google.Chrome.desktop";
    }
    # Default image viewer — oculante (Rust, GPU-accelerated, editing +
    # RAW/PSD/EXR). All types below are declared in oculante.desktop's
    # MimeType. genAttrs maps each → the same handler.
    // (lib.genAttrs [
      "image/png"
      "image/jpeg"
      "image/gif"
      "image/webp"
      "image/bmp"
      "image/tiff"
      "image/svg+xml"
      "image/avif"
      "image/heic"
      "image/jxl"
      "image/jp2"
      "image/vnd.microsoft.icon"
      "image/x-tga"
      "image/x-exr"
      "application/vnd.adobe.photoshop"  # PSD
      "image/x-adobe-dng"                # RAW
      "image/x-canon-cr2"
      "image/x-nikon-nef"
      "image/x-sony-arw"
      "image/x-fuji-raf"
    ] (_: "oculante.desktop"));
  };

  # XDG config files
  xdg.configFile = {
    # COSMIC's cosmic-settings-daemon overwrites HM's gtk-4.0/gtk.css
    # with its own `cosmic/dark.css` symlink whenever the theme syncs.
    # On the next nixos-rebuild HM sees a foreign file at the path it
    # expects to own and refuses to activate ("would be clobbered").
    # `force = true` tells HM to overwrite unconditionally; cosmic
    # re-asserts its symlink moments later, producing at most a brief
    # theme flicker right after activation.
    "gtk-4.0/gtk.css".force = true;

    # Suppress gnome-keyring's SSH component so it doesn't override
    # SSH_AUTH_SOCK (which gitway-agent points at /run/user/$UID/gitway-agent.sock
    # via /etc/environment.d/10-gitway-agent.conf). PAM still launches
    # gnome-keyring-daemon for secrets/keyring; this file shadows the system
    # autostart and the daemon honors Hidden=true to skip its SSH agent.
    "autostart/gnome-keyring-ssh.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=SSH Key Agent
      Hidden=true
    '';

    "containers/containers.conf".text = ''
      [engine]
      runtime = "runc"
    '';

    # SwayOSD — on-screen-display bars for the dedicated brightness/volume
    # keys under Niri (binds + swayosd-server startup live in
    # modules/desktops/niri.nix). swayosd-server auto-reads both files from
    # this directory. Themed with the Steelbore palette.
    # cosmic-term shell + profile. cosmic-config layers per-key with the USER
    # file winning over /etc/cosmic, and cosmic-term writes a real `profiles`
    # file here (profile 0, empty command → $SHELL) that shadows the system
    # default in modules/packages/terminals.nix. Own it at the user level so
    # cosmic-term deterministically launches Nushell on the Steelbore scheme.
    # force = true overwrites the app-written file without a backup deadlock
    # (same treatment as the VSCode flatpak override and .gtkrc-2.0).
    "cosmic/com.system76.CosmicTerm/v1/profiles" = {
      force = true;
      text = ''
        {
            0: (
                name: "Steelbore",
                command: "${pkgs.nushell}/bin/nu",
                syntax_theme_dark: "Steelbore",
                syntax_theme_light: "Steelbore",
                tab_title: "",
                working_directory: "",
                drain_on_exit: false,
            ),
        }
      '';
    };
    "cosmic/com.system76.CosmicTerm/v1/default_profile" = {
      force = true;
      text = "Some(0)\n";
    };

    "swayosd/config.toml".text = ''
      [server]
      max_volume = 100
      style = "/home/mj/.config/swayosd/style.css"
    '';

    # swayidle — idle management under Niri (spawned via the Niri config's
    # spawn-at-startup "swayidle" "-w"). Auto-locks then blanks on idle, and
    # locks before suspend. The Caffeine toggle (Mod+Shift+C → steelbore-
    # caffeine, defined in modules/desktops/niri.nix) SIGSTOPs swayidle to
    # keep the machine awake on demand. niri restores monitors on input, but
    # the explicit resume power-on is a harmless safety net.
    "swayidle/config".text = ''
      timeout 300 'gtklock -d'
      timeout 360 'niri msg action power-off-monitors' resume 'niri msg action power-on-monitors'
      before-sleep 'gtklock -d'
    '';
    "swayosd/style.css".text = ''
      /* Steelbore SwayOSD theme — Void Navy / Molten Amber */
      window#osd {
        padding: 12px 18px;
        border-radius: 12px;
        border: 1px solid ${steelborePalette.steelBlue};
        background-color: ${steelborePalette.voidNavy};
      }

      window#osd #container {
        margin: 14px;
      }

      window#osd image,
      window#osd label {
        color: ${steelborePalette.moltenAmber};
      }

      window#osd progressbar {
        min-height: 6px;
        border-radius: 999px;
        background: transparent;
      }

      window#osd trough {
        min-height: 6px;
        border-radius: 999px;
        background-color: ${steelborePalette.steelBlue};
      }

      window#osd progress {
        min-height: 6px;
        border-radius: 999px;
        background-color: ${steelborePalette.moltenAmber};
      }

      /* Muted state — desaturate the bar to the warning color. */
      window#osd progressbar:disabled progress {
        background-color: ${steelborePalette.redOxide};
      }
    '';

    # tealdeer (tldr) — auto-update once a week on first invocation.
    # The home-manager activation script also forces a refresh on every
    # nixos-rebuild (see home.activation.tldrUpdate).
    "tealdeer/config.toml".text = ''
      [updates]
      auto_update = true
      auto_update_interval_hours = 168

      [display]
      use_pager = false
      compact = false
    '';

    # Suppress IBus autostarts that surface as Wayland-session popups.
    # i18n.inputMethod = ibus (modules/core/locale.nix) is required to
    # silence COSMIC's "no input method configured" notification — that
    # check keys off QT_IM_MODULE / GTK_IM_MODULE / XMODIFIERS, which the
    # option sets globally. The option also installs two autostart files
    # that misbehave under non-GNOME Wayland sessions:
    #   • Panel (Wayland Gtk3) — a tray widget we don't need
    #   • ibus-daemon          — under Niri, the daemon prints its long
    #                            "IBus should be called from the desktop
    #                            session in Wayland..." help text, which
    #                            dunst surfaces as a notification.
    # We shadow both with Hidden=true. ibus-daemon dbus-activates on
    # demand if any client really needs it.
    "autostart/org.freedesktop.IBus.Panel.Wayland.Gtk3.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=IBus Panel (Wayland)
      Hidden=true
    '';

    "autostart/ibus-daemon.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=IBus Daemon
      Hidden=true
    '';

    # COSMIC custom keybinds. cosmic-settings stores user-edited shortcuts
    # in this RON file at ~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom.
    # The COSMIC 1.0-alpha schema supports multiple bindings mapped to the
    # same action, so we ship pairs (Ctrl+Space + Super+Space → input-source
    # switch; Super+Return + Super+T → terminal) here. Note: home-manager
    # makes the file read-only, so future tweaks via the Settings UI silently
    # fail until the binding is also added/removed here.
    "cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom".text = ''
      {
          (
              modifiers: [
                  Ctrl,
              ],
              key: "space",
          ): System(InputSourceSwitch),
          (
              modifiers: [
                  Super,
              ],
              key: "space",
          ): System(InputSourceSwitch),
          (
              modifiers: [
                  Super,
              ],
          ): System(AppLibrary),
          (
              modifiers: [
                  Super,
              ],
              key: "d",
          ): System(Launcher),
          (
              modifiers: [
                  Super,
              ],
              key: "slash",
          ): Disable,
          (
              modifiers: [
                  Super,
              ],
              key: "Return",
          ): System(Terminal),
          (
              modifiers: [
                  Super,
              ],
              key: "t",
          ): System(Terminal),
      }
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # EWW — Shared status bar for LeftWM (X11) and Niri (Wayland).
    # Eww auto-detects X11 vs Wayland; one config drives both. WMs spawn it
    # via `eww open bar` from their startup scripts.
    # ═══════════════════════════════════════════════════════════════════════════
    "eww/eww.yuck".text = ''
      ;; Steelbore Eww — shared bar widget

      (defpoll time    :interval "1s"  "date '+%Y-%m-%d %H:%M:%S'")
      (defpoll cpu     :interval "3s"  "top -bn1 -d 0.1 | awk '/^%Cpu/ {printf \"%d\", $2 + $4}'")
      (defpoll memory  :interval "5s"  "free | awk '/^Mem/ {printf \"%d\", $3 / $2 * 100}'")
      (defpoll battery :interval "30s" "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo --")

      (defwidget bar []
        (centerbox :orientation "h"
          (label :class "title" :text "STEELBORE :: BRAVAIS")
          (label :class "clock" :text time)
          (box :orientation "h" :spacing 16 :halign "end" :class "metrics"
            (label :class "metric" :text "CPU ''${cpu}%")
            (label :class "metric" :text "RAM ''${memory}%")
            (label :class "metric" :text "BAT ''${battery}%"))))

      (defwindow bar
        :monitor 0
        :geometry (geometry :x      "0"
                            :y      "0"
                            :width  "100%"
                            :height "32px"
                            :anchor "top center")
        :stacking  "fg"
        :exclusive true
        (bar))
    '';

    "eww/eww.scss".text = ''
      $voidNavy:    ${steelborePalette.voidNavy};
      $moltenAmber: ${steelborePalette.moltenAmber};
      $steelBlue:   ${steelborePalette.steelBlue};
      $radiumGreen: ${steelborePalette.radiumGreen};
      $liquidCool:  ${steelborePalette.liquidCool};
      $redOxide:    ${steelborePalette.redOxide};

      * {
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 13px;
          font-weight: bold;
      }

      window {
          background-color: $voidNavy;
          color: $moltenAmber;
          border-bottom: 2px solid $steelBlue;
          padding: 0 12px;
      }

      .title  { color: $moltenAmber; }
      .clock  { color: $liquidCool; }
      .metrics { padding-right: 12px; }
      .metric { color: $radiumGreen; }
    '';

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
      let SSH_AUTH_SOCK = "/run/user/$(id -u)/gitway-agent.sock"
      export SSH_AUTH_SOCK

      # User-local bins — appended so Nix store paths take precedence
      let PATH = "$PATH:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.kimi-code/bin:$HOME/.npm-packages/bin:$HOME/.opencode/bin:$HOME/.kilo/bin:$HOME/.mimocode/bin:$HOME/.local/lib/qwen-code/bin"
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

    # ═══════════════════════════════════════════════════════════════════════════
    # NIRI — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "niri/config.kdl".text = ''
      // Steelbore Niri User Configuration

      // XDG_CURRENT_DESKTOP routes xdg-desktop-portal lookups (see
      // xdg.portal.config.niri in modules/theme/dark-mode.nix). Niri
      // imports these into the systemd user env at session start.
      environment {
          XDG_CURRENT_DESKTOP "niri"
      }

      layout {
          gaps 8
          focus-ring {
              // off  — uncomment to disable; presence of the block enables it
              width 2
              active-color "${steelborePalette.moltenAmber}"
              inactive-color "${steelborePalette.steelBlue}"
          }
          border { off; }
          // Default column width
          default-column-width { proportion 0.5; }
          // Center focused column when it changes
          center-focused-column "on-overflow"
      }

      // Startup. The wallpaper daemon needs to bind its IPC socket before
      // any client command; the inline sleep gives it a moment before the
      // `clear` call sets the solid Void Navy wallpaper.
      spawn-at-startup "${wallpaperPkg}/bin/${wallpaperBin}-daemon"
      spawn-at-startup "sh" "-c" "sleep 1 && ${wallpaperPkg}/bin/${wallpaperBin} clear ${lib.removePrefix "#" steelborePalette.voidNavy}"
      spawn-at-startup "eww" "open" "bar"
      spawn-at-startup "dunst"
      // OSD daemon for the dedicated brightness/volume keys (binds below).
      // Auto-reads ~/.config/swayosd/{config.toml,style.css}.
      spawn-at-startup "swayosd-server"
      // Idle daemon — auto lock + screen-off (config: ~/.config/swayidle/config).
      // Toggle off on demand with Mod+Shift+C (Caffeine).
      spawn-at-startup "swayidle" "-w"
      // Load SSH key into gitway-agent once per session. With no TTY but
      // DISPLAY/WAYLAND_DISPLAY set, gitway-add uses $SSH_ASKPASS
      // (ksshaskpass) automatically. Cached for 24 h per the agent TTL.
      spawn-at-startup "gitway-add" "/home/mj/.ssh/id_ed25519"

      input {
          keyboard {
              xkb {
                  layout "us,ar"
                  options "grp:ctrl_space_toggle"
              }
          }
          touchpad {
              tap
              accel-speed 0.3
              natural-scroll
          }
      }

      // Key bindings.
      //
      // `hotkey-overlay-title="..."` populates Niri's show-hotkey-overlay
      // cheatsheet. Binds WITHOUT a title are still active but hidden
      // from the overlay — used here for secondary aliases (vim-style
      // movement that mirrors arrow-key binds, mouse-wheel workspace
      // nav, individual workspace 2-9 numbers that share the title of
      // the Mod+1 anchor entry).
      binds {
          // Session
          Mod+Shift+E hotkey-overlay-title="Exit niri" { quit; }
          Mod+Shift+L hotkey-overlay-title="Lock the Screen: gtklock" { spawn "gtklock"; }
          Mod+Shift+C hotkey-overlay-title="Toggle Caffeine (keep awake)" { spawn "steelbore-caffeine"; }
          // `Slash` is Niri's KDL name for the `/` key (US layout produces
          // `?` when shifted) — consistent with our use of symbolic names
          // (Minus, Equal, Return) elsewhere in the bind table.
          Mod+Shift+Slash hotkey-overlay-title="Show Important Hotkeys" { show-hotkey-overlay; }

          // Applications
          Mod+Return hotkey-overlay-title="Open a Terminal: alacritty" { spawn "alacritty"; }
          Mod+D hotkey-overlay-title="Run an Application: anyrun" { spawn "anyrun"; }

          // Window management
          Mod+Q hotkey-overlay-title="Close Focused Window" { close-window; }
          Mod+F hotkey-overlay-title="Maximize Column" { maximize-column; }
          Mod+Shift+F hotkey-overlay-title="Fullscreen Window" { fullscreen-window; }

          // Floating
          Mod+V hotkey-overlay-title="Toggle Window Floating" { toggle-window-floating; }
          Mod+Shift+V hotkey-overlay-title="Switch Focus Floating/Tiling" { switch-focus-between-floating-and-tiling; }

          // Overview
          Mod+O hotkey-overlay-title="Open the Overview" { toggle-overview; }

          // Focus — arrow-key primaries appear in the overlay; vim
          // duplicates are silent secondary aliases.
          Mod+Left  hotkey-overlay-title="Focus Column to the Left"  { focus-column-left; }
          Mod+Right hotkey-overlay-title="Focus Column to the Right" { focus-column-right; }
          Mod+Up    hotkey-overlay-title="Focus Window Up"           { focus-window-up; }
          Mod+Down  hotkey-overlay-title="Focus Window Down"         { focus-window-down; }
          Mod+H { focus-column-left; }
          Mod+L { focus-column-right; }
          Mod+K { focus-window-up; }
          Mod+J { focus-window-down; }

          // Move windows — Mod+Ctrl+arrows primaries (matches Niri's
          // default-config idioms); Mod+Shift+arrows and vim variants
          // are silent secondary aliases for muscle memory.
          Mod+Ctrl+Left  hotkey-overlay-title="Move Column Left"   { move-column-left; }
          Mod+Ctrl+Right hotkey-overlay-title="Move Column Right"  { move-column-right; }
          Mod+Ctrl+Up    hotkey-overlay-title="Move Window Up"     { move-window-up; }
          Mod+Ctrl+Down  hotkey-overlay-title="Move Window Down"   { move-window-down; }
          Mod+Shift+Left  { move-column-left; }
          Mod+Shift+Right { move-column-right; }
          Mod+Shift+Up    { move-window-up; }
          Mod+Shift+Down  { move-window-down; }
          // Mod+Shift+L is reserved for gtklock; vim moves use H/K/J only.
          Mod+Shift+H { move-column-left; }
          Mod+Shift+K { move-window-up; }
          Mod+Shift+J { move-window-down; }

          // Consume / Expel (column-folding) — square brackets per the
          // Niri default-config idiom. `BracketLeft`/`BracketRight` are
          // Niri's KDL names for `[`/`]`.
          Mod+BracketLeft  hotkey-overlay-title="Consume Window into Column" { consume-or-expel-window-left; }
          Mod+BracketRight hotkey-overlay-title="Expel Window into New Column" { consume-or-expel-window-right; }

          // Workspaces (Mod+1 is the anchor; 2-9 share the same
          // semantic title so the overlay isn't flooded).
          Mod+1 hotkey-overlay-title="Switch to Workspace 1-9" { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }
          Mod+3 { focus-workspace 3; }
          Mod+4 { focus-workspace 4; }
          Mod+5 { focus-workspace 5; }
          Mod+6 { focus-workspace 6; }
          Mod+7 { focus-workspace 7; }
          Mod+8 { focus-workspace 8; }
          Mod+9 { focus-workspace 9; }
          Mod+Shift+1 hotkey-overlay-title="Move Column to Workspace 1-9" { move-column-to-workspace 1; }
          Mod+Shift+2 { move-column-to-workspace 2; }
          Mod+Shift+3 { move-column-to-workspace 3; }
          Mod+Shift+4 { move-column-to-workspace 4; }
          Mod+Shift+5 { move-column-to-workspace 5; }
          Mod+Shift+6 { move-column-to-workspace 6; }
          Mod+Shift+7 { move-column-to-workspace 7; }
          Mod+Shift+8 { move-column-to-workspace 8; }
          Mod+Shift+9 { move-column-to-workspace 9; }

          // Workspace navigation (relative)
          Mod+Page_Down hotkey-overlay-title="Switch Workspace Down" { focus-workspace-down; }
          Mod+Page_Up   hotkey-overlay-title="Switch Workspace Up"   { focus-workspace-up; }
          Mod+Ctrl+Page_Down hotkey-overlay-title="Move Column to Workspace Down" { move-column-to-workspace-down; }
          Mod+Ctrl+Page_Up   hotkey-overlay-title="Move Column to Workspace Up"   { move-column-to-workspace-up; }
          Mod+Tab hotkey-overlay-title="Switch to Previous Workspace" { focus-workspace-previous; }
          // Mouse-wheel workspace nav (silent — secondary, mouse-only).
          Mod+WheelScrollDown { focus-workspace-down; }
          Mod+WheelScrollUp   { focus-workspace-up; }

          // Resize
          Mod+R     hotkey-overlay-title="Switch Preset Column Widths" { switch-preset-column-width; }
          Mod+Minus hotkey-overlay-title="Decrease Column Width" { set-column-width "-10%"; }
          Mod+Equal hotkey-overlay-title="Increase Column Width" { set-column-width "+10%"; }

          // Screenshots
          Print     hotkey-overlay-title="Take a Screenshot" { screenshot; }
          Mod+Print hotkey-overlay-title="Screenshot Window" { screenshot-window; }

          // Dedicated / multimedia keys. Kept out of the hotkey overlay
          // (labelled hardware keys, not Mod-chords) and allow-when-locked
          // so they work over gtklock. Mirrors modules/desktops/niri.nix;
          // packages + udev rule + rfkill wrappers are system-level there.
          //
          // Brightness (display) — swayosd OSD bar
          XF86MonBrightnessUp   allow-when-locked=true { spawn "swayosd-client" "--brightness" "raise"; }
          XF86MonBrightnessDown allow-when-locked=true { spawn "swayosd-client" "--brightness" "lower"; }
          // Volume / mic — swayosd OSD bar (capped at 100% via config.toml)
          XF86AudioRaiseVolume  allow-when-locked=true { spawn "swayosd-client" "--output-volume" "raise"; }
          XF86AudioLowerVolume  allow-when-locked=true { spawn "swayosd-client" "--output-volume" "lower"; }
          XF86AudioMute         allow-when-locked=true { spawn "swayosd-client" "--output-volume" "mute-toggle"; }
          XF86AudioMicMute      allow-when-locked=true { spawn "swayosd-client" "--input-volume" "mute-toggle"; }
          // Media (MPRIS) — playerctl, no OSD
          XF86AudioPlay { spawn "playerctl" "play-pause"; }
          XF86AudioNext { spawn "playerctl" "next"; }
          XF86AudioPrev { spawn "playerctl" "previous"; }
          XF86AudioStop { spawn "playerctl" "stop"; }
          // Keyboard backlight — brightnessctl (tpacpi led, levels 0–2)
          XF86KbdBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "--device=tpacpi::kbd_backlight" "set" "+1"; }
          XF86KbdBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--device=tpacpi::kbd_backlight" "set" "1-"; }
          // Radios — rfkill toggles with dunst feedback (wrappers in niri.nix)
          XF86Bluetooth allow-when-locked=true { spawn "steelbore-bt-toggle"; }
          XF86RFKill    allow-when-locked=true { spawn "steelbore-airplane-toggle"; }
      }
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # IRONBAR — Wayland status bar
    # ═══════════════════════════════════════════════════════════════════════════
    "ironbar/config.yaml".text = ''
      anchor_to_edges: true
      position: top
      height: 32

      start:
        - type: workspaces
        - type: focused

      center:
        - type: clock
          format: "%H:%M:%S :: %Y-%m-%d"

      end:
        - type: sys_info
          interval: 1
          format:
            - "CPU: {cpu_percent}%"
            - "RAM: {memory_percent}%"
        - type: tray
    '';

    "ironbar/style.css".text = ''
      * {
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 14px;
          transition: none;
      }

      window {
          background-color: ${steelborePalette.voidNavy};
          color: ${steelborePalette.moltenAmber};
          border-bottom: 2px solid ${steelborePalette.steelBlue};
      }

      .widget {
          padding: 0 10px;
          border-left: 1px solid ${steelborePalette.steelBlue};
      }

      .workspaces button {
          color: ${steelborePalette.steelBlue};
          border-bottom: 2px solid transparent;
      }

      .workspaces button.active {
          color: ${steelborePalette.moltenAmber};
          border-bottom: 2px solid ${steelborePalette.moltenAmber};
      }

      .clock {
          color: ${steelborePalette.moltenAmber};
          font-weight: bold;
      }

      .sys_info {
          color: ${steelborePalette.radiumGreen};
      }
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # WEZTERM — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "wezterm/wezterm.lua".text = ''
      -- Steelbore WezTerm User Configuration
      local wezterm = require 'wezterm'
      local config = {}

      config.font = wezterm.font 'JetBrainsMono Nerd Font'
      config.font_size = 12.0
      config.window_background_opacity = 0.95
      config.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }
      config.enable_tab_bar = true
      config.hide_tab_bar_if_only_one_tab = true
      config.default_prog = { "${pkgs.nushell}/bin/nu" }

      config.colors = {
        foreground = "${steelborePalette.moltenAmber}",
        background = "${steelborePalette.voidNavy}",
        cursor_bg = "${steelborePalette.moltenAmber}",
        cursor_fg = "${steelborePalette.voidNavy}",
        cursor_border = "${steelborePalette.moltenAmber}",
        selection_bg = "${steelborePalette.steelBlue}",
        selection_fg = "${steelborePalette.voidNavy}",
        ansi = {
          "${steelborePalette.voidNavy}",
          "${steelborePalette.redOxide}",
          "${steelborePalette.radiumGreen}",
          "${steelborePalette.moltenAmber}",
          "${steelborePalette.steelBlue}",
          "${steelborePalette.steelBlue}",
          "${steelborePalette.liquidCool}",
          "${steelborePalette.moltenAmber}"
        },
        brights = {
          "${steelborePalette.steelBlue}",
          "${steelborePalette.redOxide}",
          "${steelborePalette.radiumGreen}",
          "${steelborePalette.moltenAmber}",
          "${steelborePalette.liquidCool}",
          "${steelborePalette.liquidCool}",
          "${steelborePalette.liquidCool}",
          "${steelborePalette.moltenAmber}"
        },
        tab_bar = {
          background = "${steelborePalette.voidNavy}",
          active_tab = {
            bg_color = "${steelborePalette.steelBlue}",
            fg_color = "${steelborePalette.moltenAmber}",
          },
          inactive_tab = {
            bg_color = "${steelborePalette.voidNavy}",
            fg_color = "${steelborePalette.steelBlue}",
          },
        },
      }

      return config
    '';


    # ═══════════════════════════════════════════════════════════════════════════
    # RIO — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "rio/config.toml".text = ''
      # Steelbore Rio User Configuration

      [window]
      opacity = 0.95

      [fonts]
      size = 14

      [fonts.regular]
      family = "JetBrainsMono Nerd Font Mono"
      weight = 400

      [fonts.bold]
      family = "JetBrainsMono Nerd Font Mono"
      weight = 700

      [fonts.italic]
      family = "JetBrainsMono Nerd Font Mono"
      weight = 400

      [fonts.bold-italic]
      family = "JetBrainsMono Nerd Font Mono"
      weight = 700

      [[fonts.extras]]
      family = "Symbols Nerd Font"

      [[fonts.extras]]
      family = "Symbols Nerd Font Mono"

      [colors]
      background = '${steelborePalette.voidNavy}'
      foreground = '${steelborePalette.moltenAmber}'
      cursor = '${steelborePalette.moltenAmber}'
      selection-background = '${steelborePalette.steelBlue}'
      selection-foreground = '${steelborePalette.voidNavy}'

      [colors.regular]
      black = '${steelborePalette.voidNavy}'
      red = '${steelborePalette.redOxide}'
      green = '${steelborePalette.radiumGreen}'
      yellow = '${steelborePalette.moltenAmber}'
      blue = '${steelborePalette.steelBlue}'
      magenta = '${steelborePalette.steelBlue}'
      cyan = '${steelborePalette.liquidCool}'
      white = '${steelborePalette.moltenAmber}'

      [colors.bright]
      black = '${steelborePalette.steelBlue}'
      red = '${steelborePalette.redOxide}'
      green = '${steelborePalette.radiumGreen}'
      yellow = '${steelborePalette.moltenAmber}'
      blue = '${steelborePalette.liquidCool}'
      magenta = '${steelborePalette.liquidCool}'
      cyan = '${steelborePalette.liquidCool}'
      white = '${steelborePalette.moltenAmber}'

      [shell]
      program = "${pkgs.nushell}/bin/nu"
      args = []
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # GHOSTTY — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "ghostty/config".text = ''
      # Steelbore Ghostty User Configuration

      font-family = JetBrainsMono Nerd Font
      font-size = 12

      background-opacity = 0.95
      window-padding-x = 10
      window-padding-y = 10

      background = ${steelborePalette.voidNavy}
      foreground = ${steelborePalette.moltenAmber}
      cursor-color = ${steelborePalette.moltenAmber}
      cursor-text = ${steelborePalette.voidNavy}
      selection-background = ${steelborePalette.steelBlue}
      selection-foreground = ${steelborePalette.voidNavy}

      palette = 0=${steelborePalette.voidNavy}
      palette = 1=${steelborePalette.redOxide}
      palette = 2=${steelborePalette.radiumGreen}
      palette = 3=${steelborePalette.moltenAmber}
      palette = 4=${steelborePalette.steelBlue}
      palette = 5=${steelborePalette.steelBlue}
      palette = 6=${steelborePalette.liquidCool}
      palette = 7=${steelborePalette.moltenAmber}
      palette = 8=${steelborePalette.steelBlue}
      palette = 9=${steelborePalette.redOxide}
      palette = 10=${steelborePalette.radiumGreen}
      palette = 11=${steelborePalette.moltenAmber}
      palette = 12=${steelborePalette.liquidCool}
      palette = 13=${steelborePalette.liquidCool}
      palette = 14=${steelborePalette.liquidCool}
      palette = 15=${steelborePalette.moltenAmber}

      # Shell — launches nushell (starship integrated via nushell config)
      command = ${pkgs.nushell}/bin/nu
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # FOOT — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "foot/foot.ini".text = ''
      # Steelbore Foot User Configuration

      [main]
      font=JetBrainsMono Nerd Font:size=12
      shell=${pkgs.nushell}/bin/nu
      term=xterm-256color

      [colors]
      background=${h steelborePalette.voidNavy}
      foreground=${h steelborePalette.moltenAmber}
      regular0=${h steelborePalette.voidNavy}
      regular1=${h steelborePalette.redOxide}
      regular2=${h steelborePalette.radiumGreen}
      regular3=${h steelborePalette.moltenAmber}
      regular4=${h steelborePalette.steelBlue}
      regular5=${h steelborePalette.steelBlue}
      regular6=${h steelborePalette.liquidCool}
      regular7=${h steelborePalette.moltenAmber}
      bright0=${h steelborePalette.steelBlue}
      bright1=${h steelborePalette.redOxide}
      bright2=${h steelborePalette.radiumGreen}
      bright3=${h steelborePalette.moltenAmber}
      bright4=${h steelborePalette.liquidCool}
      bright5=${h steelborePalette.liquidCool}
      bright6=${h steelborePalette.liquidCool}
      bright7=${h steelborePalette.moltenAmber}
      cursor=${h steelborePalette.voidNavy} ${h steelborePalette.moltenAmber}
      selection-foreground=${h steelborePalette.voidNavy}
      selection-background=${h steelborePalette.steelBlue}

      [scrollback]
      lines=10000
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # XFCE4-TERMINAL — User configuration
    # ═══════════════════════════════════════════════════════════════════════════
    "xfce4/terminal/terminalrc".text = ''
      [Configuration]
      FontName=JetBrainsMono Nerd Font 12
      MiscDefaultGeometry=160x48
      RunCustomCommand=TRUE
      CustomCommand=${pkgs.nushell}/bin/nu
      BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
      BackgroundDarkness=0.95
      ColorBackground=${steelborePalette.voidNavy}
      ColorForeground=${steelborePalette.moltenAmber}
      ColorCursor=${steelborePalette.moltenAmber}
      ColorBold=FALSE
      ColorPalette=${steelborePalette.voidNavy};${steelborePalette.redOxide};${steelborePalette.radiumGreen};${steelborePalette.moltenAmber};${steelborePalette.steelBlue};${steelborePalette.steelBlue};${steelborePalette.liquidCool};${steelborePalette.moltenAmber};${steelborePalette.steelBlue};${steelborePalette.redOxide};${steelborePalette.radiumGreen};${steelborePalette.moltenAmber};${steelborePalette.liquidCool};${steelborePalette.liquidCool};${steelborePalette.liquidCool};${steelborePalette.moltenAmber}
      MiscMenubarDefault=FALSE
      ScrollingBar=TERMINAL_SCROLLBAR_NONE
      ScrollingLines=10000
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # KWIN — Enable Krohnkite tiling script
    # ═══════════════════════════════════════════════════════════════════════════
    "kwinrc".text = ''
      [Plugins]
      krohnkiteEnabled=true
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # KWALLET — Pre-enable GPG backend
    # The wallet itself must be created manually via KWallet Manager:
    #   File → New Wallet → choose GPG encryption → select your GPG key.
    # ═══════════════════════════════════════════════════════════════════════════
    "kwalletrc".text = ''
      [Wallet]
      Default Wallet=kdewallet
      Enabled=true
      First Use=false

      [gpg]
      use=true
    '';

    "konsolerc".text = ''
      [Desktop Entry]
      DefaultProfile=Steelbore.profile

      [TabBar]
      CloseTabOnMiddleMouseButton=true
      NewTabButton=false
      TabBarPosition=Top
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # YAKUAKE — KDE drop-down terminal (uses Konsole as backend)
    # Inherits shell and colors from the Konsole Steelbore profile above
    # ═══════════════════════════════════════════════════════════════════════════
    "yakuakerc".text = ''
      [Desktop Entry]
      DefaultProfile=Steelbore.profile

      [Window]
      Height=50
      Width=100
      KeepOpen=false
      AnimationDuration=0
    '';
  };

  # Konsole colorscheme and profile live in $XDG_DATA_HOME/konsole/
  xdg.dataFile = {
    # ═══════════════════════════════════════════════════════════════════════════
    # FLATPAK — VSCode per-app override
    # User-level override (wins over system/NixOS overrides). PATH MUST keep
    # /app/bin:/usr/bin first, otherwise flatpak's `code` entrypoint isn't found
    # and launch dies with `bwrap: execvp code: No such file or directory`. The
    # host bin dirs follow so VSCode's integrated terminal still sees host tools
    # (/run/current-system/sw/bin is also filesystem-exposed below).
    #
    # `force = true`: flatpak rewrites this file as a plain (read-only) file
    # out-of-band, so HM finds a foreign file at the path on the next switch
    # and — with a stale `.backup` already present — refuses to back it up
    # ("would be clobbered"). force makes HM overwrite unconditionally with
    # no backup attempt, so activation can't deadlock on this file again.
    # ═══════════════════════════════════════════════════════════════════════════
    "flatpak/overrides/com.visualstudio.code" = {
      force = true;
      text = ''
        [Context]
        sockets=session-bus;system-bus;gpg-agent;inherit-wayland-socket;
        devices=dri;kvm;shm;
        features=multiarch;per-app-dev-shm;
        filesystems=home;/home/mj/steelbore;host-etc;/run/current-system/sw/bin;/steelbore;host-os;

        [Environment]
        PATH=/app/bin:/usr/bin:/run/wrappers/bin:/home/mj/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:/home/mj/.nix-profile/bin:/nix/profile/bin:/home/mj/.local/state/nix/profile/bin:/etc/profiles/per-user/mj/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin
      '';
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # KONSOLE — User profile and colorscheme
    # ═══════════════════════════════════════════════════════════════════════════
    "konsole/Steelbore.colorscheme".text = ''
      # Steelbore Konsole Color Scheme

      [Background]
      Color=0,0,39

      [BackgroundFaint]
      Color=0,0,39

      [BackgroundIntense]
      Bold=true
      Color=75,126,176

      [Color0]
      Color=0,0,39

      [Color0Faint]
      Color=0,0,39

      [Color0Intense]
      Bold=true
      Color=75,126,176

      [Color1]
      Color=255,92,92

      [Color1Faint]
      Color=255,92,92

      [Color1Intense]
      Bold=true
      Color=255,92,92

      [Color2]
      Color=80,250,123

      [Color2Faint]
      Color=80,250,123

      [Color2Intense]
      Bold=true
      Color=80,250,123

      [Color3]
      Color=217,142,50

      [Color3Faint]
      Color=217,142,50

      [Color3Intense]
      Bold=true
      Color=217,142,50

      [Color4]
      Color=75,126,176

      [Color4Faint]
      Color=75,126,176

      [Color4Intense]
      Bold=true
      Color=139,233,253

      [Color5]
      Color=75,126,176

      [Color5Faint]
      Color=75,126,176

      [Color5Intense]
      Bold=true
      Color=139,233,253

      [Color6]
      Color=139,233,253

      [Color6Faint]
      Color=139,233,253

      [Color6Intense]
      Bold=true
      Color=139,233,253

      [Color7]
      Color=217,142,50

      [Color7Faint]
      Color=217,142,50

      [Color7Intense]
      Bold=true
      Color=217,142,50

      [Foreground]
      Color=217,142,50

      [ForegroundFaint]
      Color=217,142,50

      [ForegroundIntense]
      Bold=true
      Color=217,142,50

      [General]
      Anchor=0.5,0.5
      Blur=false
      ColorRandomization=false
      Description=Steelbore
      FillStyle=Tile
      Opacity=0.95
      Spread=1.0
      Wallpaper=
    '';

    "konsole/Steelbore.profile".text = ''
      # Steelbore Konsole Profile

      [Appearance]
      ColorScheme=Steelbore
      Font=JetBrainsMono Nerd Font,12,-1,5,50,0,0,0,0,0

      [General]
      Command=${pkgs.nushell}/bin/nu
      Name=Steelbore
      Parent=FALLBACK/
      TerminalColumns=160
      TerminalRows=48

      [Scrolling]
      HistoryMode=2
      ScrollFullPage=false

      [Terminal Features]
      BlinkingCursorEnabled=true
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # HALLOY — Rust + iced multi-server IRCv3 client (GUI)
    # ═══════════════════════════════════════════════════════════════════════════
    # Theme schema mirrors halloy's bundled `ferra.toml`. Servers are left
    # as a commented-out Libera Chat example — drop in your nick / channels
    # to start using.
    "halloy/config.toml".text = ''
      # Steelbore Halloy configuration
      theme = "spacecraft-software"

      [font]
      family = "JetBrainsMono Nerd Font"
      size = 13

      [buffer.timestamp]
      format = "%Y-%m-%d %H:%M:%S"

      # Example server (uncomment + fill in):
      # [servers.libera]
      # nickname = "your-nick"
      # server = "irc.libera.chat"
      # port = 6697
      # use_tls = true
      # channels = ["#nixos", "#rust"]
    '';

    "halloy/themes/spacecraft-software.toml".text = ''
      # Steelbore Halloy Theme — Void Navy / Molten Amber palette
      # Schema mirrors halloy/assets/themes/ferra.toml.

      [general]
      background          = "${steelborePalette.voidNavy}"
      horizontal_rule     = "${steelborePalette.steelBlue}"
      scrollbar           = "${steelborePalette.steelBlue}"
      unread_indicator    = "${steelborePalette.moltenAmber}"
      highlight_indicator = "${steelborePalette.radiumGreen}"
      border              = "${steelborePalette.steelBlue}"

      [text]
      primary   = "${steelborePalette.moltenAmber}"
      secondary = "${steelborePalette.steelBlue}"
      tertiary  = "${steelborePalette.liquidCool}"
      success   = "${steelborePalette.radiumGreen}"
      error     = "${steelborePalette.redOxide}"
      warning   = "${steelborePalette.moltenAmber}"
      info      = "${steelborePalette.liquidCool}"
      debug     = "${steelborePalette.steelBlue}"
      trace     = "${steelborePalette.liquidCool}"

      [buffer]
      background            = "${steelborePalette.voidNavy}"
      background_text_input = "${steelborePalette.voidNavy}"
      background_title_bar  = "${steelborePalette.voidNavy}"
      timestamp             = "${steelborePalette.steelBlue}"
      action                = "${steelborePalette.radiumGreen}"
      topic                 = "${steelborePalette.moltenAmber}"
      highlight             = "${steelborePalette.steelBlue}"
      code                  = "${steelborePalette.liquidCool}"
      nickname              = "${steelborePalette.moltenAmber}"
      nickname_offline      = "${steelborePalette.steelBlue}"
      url                   = "${steelborePalette.liquidCool}"
      selection             = "${steelborePalette.steelBlue}"
      border_selected       = "${steelborePalette.moltenAmber}"

      [buffer.server_messages]
      default = "${steelborePalette.steelBlue}"

      [buttons.primary]
      background                = "${steelborePalette.voidNavy}"
      background_hover          = "${steelborePalette.steelBlue}"
      background_selected       = "${steelborePalette.moltenAmber}"
      background_selected_hover = "${steelborePalette.radiumGreen}"

      [buttons.secondary]
      background                = "${steelborePalette.voidNavy}"
      background_hover          = "${steelborePalette.steelBlue}"
      background_selected       = "${steelborePalette.moltenAmber}"
      background_selected_hover = "${steelborePalette.radiumGreen}"

      # IRC mIRC-style formatting palette. Mappings mirror foot/wezterm
      # — entries the Steelbore palette doesn't model directly
      # (brown, magenta, pink, lightgrey) reuse the closest neighbor.
      [formatting]
      white      = "${steelborePalette.moltenAmber}"
      black      = "${steelborePalette.voidNavy}"
      blue       = "${steelborePalette.steelBlue}"
      green      = "${steelborePalette.radiumGreen}"
      red        = "${steelborePalette.redOxide}"
      brown      = "${steelborePalette.moltenAmber}"
      magenta    = "${steelborePalette.steelBlue}"
      orange     = "${steelborePalette.moltenAmber}"
      yellow     = "${steelborePalette.moltenAmber}"
      lightgreen = "${steelborePalette.radiumGreen}"
      cyan       = "${steelborePalette.liquidCool}"
      lightcyan  = "${steelborePalette.liquidCool}"
      lightblue  = "${steelborePalette.liquidCool}"
      pink       = "${steelborePalette.redOxide}"
      grey       = "${steelborePalette.steelBlue}"
      lightgrey  = "${steelborePalette.moltenAmber}"
    '';

    # ═══════════════════════════════════════════════════════════════════════════
    # TINY — Rust + crossterm multi-server IRC client (TUI)
    # ═══════════════════════════════════════════════════════════════════════════
    # Tiny is 256-color only (no truecolor), so palette colors are mapped
    # to their nearest xterm-256 indices:
    #   Void Navy      #000027 → 17  (#00005f)   [also use `default` for bg]
    #   Molten Amber   #D98E32 → 172 (#d78700)
    #   Steel Blue     #4B7EB0 → 67  (#5f87af)
    #   Radium Green   #50FA7B → 84  (#5fff87)
    #   Red Oxide      #FF5C5C → 203 (#ff5f5f)
    #   Liquid Coolant #8BE9FD → 123 (#87ffff)
    # `bg: default` inherits the host terminal's background — which on
    # Bravais is already Void Navy.
    "tiny/config.yml".text = ''
      # Steelbore Tiny configuration

      # Servers — fill in or use /connect at runtime.
      servers: []

      defaults:
          nicks: [unbreakablemj]
          realname: Mohamed Hammad
          join: []
          tls: true

      log_dir: "~/.local/share/tiny/logs"

      scrollback: 4096

      layout: aligned
      max_nick_length: 16

      # 256-color theme. See note above for the palette → index mapping.
      colors:
          # Per-nick color cycle through the palette.
          nick: [172, 67, 84, 123, 203, 84, 67, 172, 123, 67]

          clear:
              fg: default
              bg: default

          user_msg:
              fg: 172            # Molten Amber
              bg: default

          err_msg:
              fg: 203            # Red Oxide
              bg: default
              attrs: [bold]

          topic:
              fg: 67             # Steel Blue
              bg: default
              attrs: [bold]

          cursor:
              fg: 17             # Void Navy on Molten Amber
              bg: 172

          join:
              fg: 84             # Radium Green
              bg: default
              attrs: [bold]

          part:
              fg: 203            # Red Oxide
              bg: default
              attrs: [bold]

          nick_change:
              fg: 84             # Radium Green
              bg: default
              attrs: [bold]

          faded:
              fg: 67             # Steel Blue
              bg: default

          exit_dialogue:
              fg: 172
              bg: 17

          highlight:
              fg: 84             # Radium Green for mentions
              bg: default
              attrs: [bold]

          completion:
              fg: 123            # Liquid Coolant
              bg: default

          timestamp:
              fg: 67             # Steel Blue
              bg: default

          tab_active:
              fg: 172            # Molten Amber
              bg: default
              attrs: [bold]

          tab_normal:
              fg: 67             # Steel Blue
              bg: default

          tab_new_msg:
              fg: 84             # Radium Green
              bg: default

          tab_highlight:
              fg: 203            # Red Oxide
              bg: default
              attrs: [bold]

          tab_joinpart:
              fg: 67             # Steel Blue
              bg: default
    '';
  };

  # XTerm Xresources (loaded by xrdb on X session start)
  xresources.properties = {
    "XTerm*termName"               = "xterm-256color";
    "XTerm*faceName"               = "JetBrainsMono Nerd Font";
    "XTerm*faceSize"               = 12;
    "XTerm*loginShell"             = true;
    "XTerm*scrollBar"              = false;
    "XTerm*saveLines"              = 10000;
    "XTerm*bellIsUrgent"           = true;
    "XTerm*internalBorder"         = 10;
    "XTerm*background"             = steelborePalette.voidNavy;
    "XTerm*foreground"             = steelborePalette.moltenAmber;
    "XTerm*cursorColor"            = steelborePalette.moltenAmber;
    "XTerm*pointerColorBackground" = steelborePalette.voidNavy;
    "XTerm*pointerColorForeground" = steelborePalette.moltenAmber;
    "XTerm*highlightColor"         = steelborePalette.steelBlue;
    "XTerm*color0"                 = steelborePalette.voidNavy;
    "XTerm*color1"                 = steelborePalette.redOxide;
    "XTerm*color2"                 = steelborePalette.radiumGreen;
    "XTerm*color3"                 = steelborePalette.moltenAmber;
    "XTerm*color4"                 = steelborePalette.steelBlue;
    "XTerm*color5"                 = steelborePalette.steelBlue;
    "XTerm*color6"                 = steelborePalette.liquidCool;
    "XTerm*color7"                 = steelborePalette.moltenAmber;
    "XTerm*color8"                 = steelborePalette.steelBlue;
    "XTerm*color9"                 = steelborePalette.redOxide;
    "XTerm*color10"                = steelborePalette.radiumGreen;
    "XTerm*color11"                = steelborePalette.moltenAmber;
    "XTerm*color12"                = steelborePalette.liquidCool;
    "XTerm*color13"                = steelborePalette.liquidCool;
    "XTerm*color14"                = steelborePalette.liquidCool;
    "XTerm*color15"                = steelborePalette.moltenAmber;
  };

  # dconf settings for GNOME-based terminals (Ptyxis, GNOME Console) +
  # system-wide dark-mode keys read by HM's gtk module, by Qt's adwaita
  # platform theme, and by xdg-desktop-portal-gtk when it serves
  # org.freedesktop.appearance.color-scheme to libadwaita apps under
  # Niri / LeftWM. Identical color-scheme value to the one HM writes
  # via `gtk.colorScheme = "dark"` — Nix attrset merge is a no-op when
  # values match.
  dconf.settings = {
    # ── Dark Mode (Niri + LeftWM appearance source) ─────────────────────────
    "org/gnome/desktop/interface" = {
      color-scheme        = "prefer-dark";
      gtk-theme           = "adw-gtk3-dark";
      icon-theme          = "Papirus-Dark";
      cursor-theme        = "Bibata-Modern-Classic";
      cursor-size         = 24;
      font-name           = "Hack Nerd Font 11";
      document-font-name  = "Hack Nerd Font 11";
      monospace-font-name = "JetBrainsMono Nerd Font 11";
    };

    # ── Ptyxis ──────────────────────────────────────────────────────────────
    "org/gnome/Ptyxis" = {
      default-profile-uuid = "steelbore";
      font-name = "JetBrainsMono Nerd Font 12";
      use-system-font = false;
    };
    "org/gnome/Ptyxis/Profiles/steelbore" = {
      label = "Steelbore";
      palette = [
        steelborePalette.voidNavy      # black
        steelborePalette.redOxide      # red
        steelborePalette.radiumGreen   # green
        steelborePalette.moltenAmber   # yellow
        steelborePalette.steelBlue     # blue
        steelborePalette.steelBlue     # magenta
        steelborePalette.liquidCool    # cyan
        steelborePalette.moltenAmber   # white
        steelborePalette.steelBlue     # bright black
        steelborePalette.redOxide      # bright red
        steelborePalette.radiumGreen   # bright green
        steelborePalette.moltenAmber   # bright yellow
        steelborePalette.liquidCool    # bright blue
        steelborePalette.liquidCool    # bright magenta
        steelborePalette.liquidCool    # bright cyan
        steelborePalette.moltenAmber   # bright white
      ];
      background-color = steelborePalette.voidNavy;
      foreground-color = steelborePalette.moltenAmber;
      use-theme-colors = false;
      opacity = 0.95;
    };

    # ── GNOME Console (kgx) ─────────────────────────────────────────────────
    # kgx has limited theming: fixed "night"/"day"/"auto" themes only.
    # Shell is inherited from $SHELL (nushell). Font can be customized.
    "org/gnome/Console" = {
      theme = "night";
      use-system-font = false;
      custom-font = "JetBrainsMono Nerd Font 12";
    };
  };

  # ─── System-wide Dark Mode (Niri + LeftWM) ───────────────────────────────
  # Per-user side of modules/theme/dark-mode.nix. HM's gtk module writes
  # ~/.config/gtk-{3,4}.0/settings.ini with the theme names and
  # gtk-application-prefer-dark-theme=true; it also writes the matching
  # gsettings keys via dconf. The qt module exports QT_QPA_PLATFORMTHEME +
  # QT_STYLE_OVERRIDE through the systemd user env so Qt apps inherit
  # them at process start. Under GNOME/COSMIC/Plasma sessions these are
  # mostly inert — those DEs' own appearance daemons take precedence in
  # their own sessions; this layer "wins" only under Niri / LeftWM.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    # HM 25.11 deprecates the legacy gtk4.theme default at
    # home.stateVersion >= "26.05" (it becomes null and HM stops writing
    # gtk-theme-name into ~/.config/gtk-4.0/settings.ini). Bind it
    # explicitly to keep the legacy behavior across the upgrade and
    # silence the activation warning.
    gtk4.theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    font = {
      name = "Hack Nerd Font";
      size = 11;
    };
  };

  # Force HM to own ~/.gtkrc-2.0 (the gtk2 module writes it at this exact
  # key). DEs in the session blank/rewrite it out-of-band, so HM finds a
  # foreign file on the next switch and — with a stale .backup present —
  # aborts activation ("would be clobbered by backing up"). force overwrites
  # unconditionally with no backup attempt. Same fix as the VSCode flatpak
  # override above. Key must match gtk2's `configLocation` exactly. The gtk2
  # module sets force = false explicitly, so mkForce is needed to override it.
  home.file."${config.home.homeDirectory}/.gtkrc-2.0".force = lib.mkForce true;

  qt = {
    enable = true;
    # `adwaita` brings in adwaita-qt(6) + qadwaitadecorations. HM marks
    # `gnome` (qgnomeplatform) as deprecated in 25.11. `qtct` would need
    # a runtime GUI to configure — not declarative.
    platformTheme.name = "adwaita";
    # `style.name` selects the widget style; -dark gives dark chrome
    # immediately rather than relying on color-scheme inference.
    style.name = "adwaita-dark";
  };

  # Single cursor across X11 + Wayland + GTK + .icons. Bibata ships
  # cursor files for all backends in one package, so enabling every
  # propagation path costs nothing.
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;        # writes ~/.config/gtk-{3,4}.0/settings.ini cursor keys
    x11.enable = true;        # writes ~/.Xresources + Xcursor.theme / .size
    dotIcons.enable = true;   # writes ~/.icons/default/index.theme (XDG)
  };
}
