# SPDX-License-Identifier: GPL-3.0-or-later
# Steelbore Bravais — Home Manager: Shells (bash, Nushell, Ion) + Starship + session vars
# Split from home.nix in Phase D (elegance plan 3.1); zero behavior change.
{
  lib,
  pkgs,
  steelborePalette,
  steelboreApps,
  mcp-servers,
  ...
}:

let
  # Handler roles (lib/default-apps.nix). `termEditor` is what $EDITOR runs;
  # `editor` — deliberately a separate role — is what a double-click opens.
  # Selection is one word per role in the repo-root default-apps.nix.
  termEditor = steelboreApps.roles.termEditor.exec pkgs;
  browserCmd = steelboreApps.roles.browser.exec pkgs;

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

  # mcpctl from the `mcp-servers` flake input (constraint #7: flake-input
  # package consumed by attr-path, threaded via extraSpecialArgs). Referenced
  # by store path rather than name so `rebuild`'s drift probe does not depend
  # on PATH ordering or on the package still being in home.packages.
  mcpctl = "${mcp-servers.packages.${pkgs.stdenv.hostPlatform.system}.mcpctl}/bin/mcpctl";
in
{
  # Session variables
  home.sessionVariables = {
    EDITOR = termEditor;
    VISUAL = termEditor;
    # Same registry entry the browser's MIME bindings come from, so $BROWSER
    # and mimeapps.list can no longer disagree. Change: app set browser <slug>
    BROWSER = browserCmd;
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
          red = steelborePalette.error; # red_oxide     — OS / username cap
          peach = steelborePalette.foreground; # molten_amber  — directory block
          yellow = "#6272A4"; # slag_grey     — git block
          green = steelborePalette.success; # radium_green  — language runtimes
          sapphire = steelborePalette.accent; # steel_blue    — docker / conda
          lavender = steelborePalette.info; # liquid_cool   — time block

          # Dark canvas (foreground text on bright section blocks)
          crust = steelborePalette.background;
          mantle = steelborePalette.background;
          base = steelborePalette.background;

          # Secondary surfaces
          surface0 = "#050530";
          surface1 = "#050530";
          surface2 = "#050530";

          # Dim / muted scale
          overlay0 = "#6272A4";
          overlay1 = "#6272A4";
          overlay2 = "#6272A4";

          # Foreground text scale
          text = steelborePalette.foreground;
          subtext0 = "#E6E6F0";
          subtext1 = "#E6E6F0";

          # Remaining catppuccin role keys mapped to nearest Steelbore semantic
          rosewater = steelborePalette.error;
          flamingo = steelborePalette.error;
          pink = steelborePalette.error;
          mauve = steelborePalette.error;
          maroon = steelborePalette.error;
          teal = steelborePalette.info;
          sky = steelborePalette.info;
          blue = steelborePalette.accent;
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

        # Steelbore palette — interpolated from the canonical lib/palette.nix
        # (Nushell needs literal strings inside color_config records; Nix
        # interpolation bakes them in at build time).
        let steelbore = {
          background:    "${steelborePalette.background}"
          foreground: "${steelborePalette.foreground}"
          accent:   "${steelborePalette.accent}"
          success: "${steelborePalette.success}"
          error:    "${steelborePalette.error}"
          info:  "${steelborePalette.info}"
        }

        $env.config = {
          show_banner: false,
          ls: { use_ls_colors: true, clickable_links: true },
          cursor_shape: { emacs: block, vi_insert: block, vi_normal: block },
          color_config: {
            separator:        $steelbore.accent
            leading_trailing_space_bg: { attr: "n" }
            header:           { fg: $steelbore.foreground attr: "b" }
            empty:            $steelbore.info
            bool:             {|v| if $v { $steelbore.success } else { $steelbore.error } }
            int:              $steelbore.foreground
            filesize:         {|v| if $v == 0b { $steelbore.accent } else if $v < 1mb { $steelbore.info } else { $steelbore.foreground } }
            duration:         $steelbore.foreground
            date:             {|v| (date now) - $v | if $in < 1hr { { fg: $steelbore.success attr: "b" } } else if $in < 6hr { $steelbore.success } else if $in < 1day { $steelbore.foreground } else if $in < 3day { $steelbore.info } else if $in < 1wk { { fg: $steelbore.info attr: "b" } } else if $in < 6wk { $steelbore.accent } else if $in < 52wk { { fg: $steelbore.accent attr: "b" } } else { "dark_gray" } }
            range:            $steelbore.foreground
            float:            $steelbore.foreground
            string:           $steelbore.foreground
            nothing:          $steelbore.info
            binary:           $steelbore.info
            cell-path:        $steelbore.accent
            row_index:        { fg: $steelbore.accent attr: "b" }
            record:           $steelbore.foreground
            list:             $steelbore.foreground
            block:            $steelbore.foreground
            hints:            "dark_gray"
            search_result:    { fg: $steelbore.background bg: $steelbore.foreground }

            shape_and:                { fg: $steelbore.success attr: "b" }
            shape_binary:             { fg: $steelbore.info attr: "b" }
            shape_block:              { fg: $steelbore.info attr: "b" }
            shape_bool:               $steelbore.success
            shape_closure:            { fg: $steelbore.success attr: "b" }
            shape_custom:             $steelbore.success
            shape_datetime:           { fg: $steelbore.info attr: "b" }
            shape_directory:          $steelbore.info
            shape_external:           $steelbore.foreground
            shape_externalarg:        { fg: $steelbore.success attr: "b" }
            shape_external_resolved:  { fg: $steelbore.info attr: "b" }
            shape_filepath:           $steelbore.accent
            shape_flag:               { fg: $steelbore.accent attr: "b" }
            shape_float:              { fg: $steelbore.foreground attr: "b" }
            shape_garbage:            { fg: $steelbore.error bg: $steelbore.background attr: "b" }
            shape_glob_interpolation: { fg: $steelbore.info attr: "b" }
            shape_globpattern:        { fg: $steelbore.info attr: "b" }
            shape_int:                { fg: $steelbore.foreground attr: "b" }
            shape_internalcall:       { fg: $steelbore.foreground attr: "b" }
            shape_keyword:            { fg: $steelbore.success attr: "b" }
            shape_list:               { fg: $steelbore.info attr: "b" }
            shape_literal:            $steelbore.accent
            shape_match_pattern:      $steelbore.success
            shape_matching_brackets:  { attr: "u" }
            shape_nothing:            $steelbore.info
            shape_operator:           $steelbore.foreground
            shape_or:                 { fg: $steelbore.success attr: "b" }
            shape_pipe:               { fg: $steelbore.success attr: "b" }
            shape_range:              { fg: $steelbore.foreground attr: "b" }
            shape_record:             { fg: $steelbore.info attr: "b" }
            shape_redirection:        { fg: $steelbore.success attr: "b" }
            shape_signature:          { fg: $steelbore.success attr: "b" }
            shape_string:             $steelbore.accent
            shape_string_interpolation: { fg: $steelbore.info attr: "b" }
            shape_table:              { fg: $steelbore.accent attr: "b" }
            shape_variable:           $steelbore.accent
            shape_vardecl:            $steelbore.accent
            shape_raw_string:         $steelbore.accent
            shape_garbage_unknown:    { fg: $steelbore.error attr: "b" }
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
        alias edit = ${termEditor}

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
        #
        # This moves flake.lock, which also re-points the vendored Copilot
        # skills in .github/skills/. Follow with `nu pkgs/sync-skills.nu` and
        # commit both, or the Skills Drift workflow fails on the next push.
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

        # ── theme ─────────────────────────────────────────────────────────
        # Discover and switch the system theme. Reads the resolved registry
        # from the `theme-registry` flake output, which evaluates only the
        # palette library — walking nixosConfigurations instead would cost
        # about a minute per theme.
        #
        #   theme list          every theme, with swatches
        #   theme show [slug]   role table for one (default: the active theme)
        #   theme set <slug>    rewrite theme.nix (then rebuild)
        #   theme try <slug>    build a theme WITHOUT touching theme.nix
        def "theme registry" [] {
          let repo = "/spacecraft-software/bravais"
          let out = (do { ^nix build --no-link --print-out-paths $"($repo)#theme-registry" } | complete)
          if $out.exit_code != 0 {
            print $"(ansi red)could not evaluate the theme registry:(ansi reset)"
            print $out.stderr
            return null
          }
          open ($out.stdout | str trim)
        }

        # A truecolor block. Nushell's `ansi` builtin takes named colors, so
        # the escape is built by hand from the registry's "R,G,B" triples.
        def "theme swatch" [rgb: string] {
          let c = ($rgb | str replace --all "," ";")
          $"(ansi -e $'48;2;($c)m')  (ansi reset)"
        }

        def theme [action?: string, slug?: string] {
          let reg = (theme registry)
          if $reg == null { return }

          match (if $action == null { "list" } else { $action }) {
            # Printed, not a returned table: Nushell strips ANSI inside table
            # cells, so swatches would silently vanish. `theme registry`
            # remains the structured/pipeable view.
            "list" => {
              print $"(ansi dark_gray)* = active   swatches: bg fg accent structure success error warning(ansi reset)"
              for t in $reg.themes {
                let mark = (if $t.active { $"(ansi green)*(ansi reset)" } else { " " })
                let sw = ([ background foreground accent structure success error warning ]
                  | each { |r| theme swatch ($t.colors | get $r | get rgb) } | str join "")
                print $"($mark) ($t.slug | fill -a l -w 40)($sw)  (ansi dark_gray)($t.source)(ansi reset)"
              }
            }
            "show" => {
              let want = (if $slug == null { $reg.active } else { $slug })
              let hit = ($reg.themes | where slug == $want)
              if ($hit | is-empty) {
                print $"(ansi red)unknown theme '($want)' — try: theme list(ansi reset)"
                return
              }
              let t = ($hit | first)
              let mark = (if $t.active { " — active" } else { "" })
              print $"(ansi cyan)($t.slug)(ansi reset)  [($t.source)]($mark)"
              if not $t.hasSurfaceClass {
                print $"(ansi yellow)legacy six-role contract — no surface class \(§11.2\); surface roles fall back to the canvas(ansi reset)"
              }
              for r in ($t.colors | transpose role color) {
                print $"  (theme swatch $r.color.rgb)  ($r.role | fill -a l -w 12) ($r.color.hex)  (ansi dark_gray)x256 ($r.color.x256)(ansi reset)"
              }
            }
            "set" => {
              if $slug == null { print $"(ansi red)theme set needs a slug — try: theme list(ansi reset)"; return }
              if ($reg.themes | where slug == $slug | is-empty) {
                print $"(ansi red)unknown theme '($slug)' — try: theme list(ansi reset)"; return
              }
              if $slug == $reg.active { print $"(ansi green)already active: ($slug)(ansi reset)"; return }
              let f = "/spacecraft-software/bravais/theme.nix"
              # Anchored at the binding so the slug list in the file's comment
              # block is never rewritten.
              ^sd $'active = "($reg.active)"' $'active = "($slug)"' $f
              print $"(ansi green)theme.nix: ($reg.active) → ($slug)(ansi reset)"
              print $"run (ansi cyan)rebuild(ansi reset) to apply, or (ansi cyan)theme set ($reg.active)(ansi reset) to undo"
            }
            "try" => {
              if $slug == null { print $"(ansi red)theme try needs a slug — try: theme list(ansi reset)"; return }
              if ($reg.themes | where slug == $slug | is-empty) {
                print $"(ansi red)unknown theme '($slug)' — try: theme list(ansi reset)"; return
              }
              print $"(ansi yellow)building ($slug) without touching theme.nix — `theme set ($slug)` to keep it(ansi reset)"
              cd /spacecraft-software/bravais
              # Built from `themeSystems`, not `nixosConfigurations`, so that
              # `nix flake check` never has to evaluate 15 whole systems in one
              # process (it OOMs). That costs us `nixos-rebuild --flake`, so
              # activation is the same two steps nixos-rebuild does internally:
              # point the system profile at the build, then switch to it.
              let sys = (do { ^nix build --no-link --print-out-paths --option warn-dirty false $".#themeSystems.($nu.os-info.arch)-linux.($slug)" } | complete)
              if $sys.exit_code != 0 {
                print $"(ansi red)build failed:(ansi reset)"; print $sys.stderr; return
              }
              let out = ($sys.stdout | str trim)
              sudo nix-env -p /nix/var/nix/profiles/system --set $out
              sudo $"($out)/bin/switch-to-configuration" switch
              print $"(ansi green)($slug) is live.(ansi reset) (ansi cyan)theme set ($slug)(ansi reset) to keep it across rebuilds, or (ansi cyan)rebuild(ansi reset) to go back to ($reg.active)"
            }
            "help" => { help theme }
            _ => { print $"(ansi red)unknown action '($action)' — try: list, show, set, try, help(ansi reset)" }
          }
        }

        # ── app ───────────────────────────────────────────────────────────
        # Which program handles what. Reads the resolved registry from the
        # `app-registry` flake output, which evaluates only the builtins-only
        # default-apps library — never a system config, so this is instant.
        #
        #   app list                  every role and its active app
        #   app show [role]           one role, with every MIME type it binds
        #   app candidates <role>     every app that can fill a role
        #   app set <role> <slug>     rewrite default-apps.nix (then rebuild)
        def "app registry" [] {
          let repo = "/spacecraft-software/bravais"
          let out = (do { ^nix build --no-link --print-out-paths $"($repo)#app-registry" } | complete)
          if $out.exit_code != 0 {
            print $"(ansi red)could not evaluate the app registry:(ansi reset)"
            print $out.stderr
            return null
          }
          open ($out.stdout | str trim)
        }

        def app [action?: string, a?: string, b?: string] {
          let reg = (app registry)
          if $reg == null { return }
          let roles = ($reg.roles | transpose role info)
          let roleList = ($roles.role | str join ", ")

          # Printed, not returned: Nushell strips ANSI inside table cells, so
          # the active marks would vanish. `app registry` is the pipeable view.
          match (if $action == null { "list" } else { $action }) {
            "list" => {
              print $"(ansi dark_gray)change with: app set <role> <slug>   options: app candidates <role>(ansi reset)"
              for r in $roles {
                let id = (if ($r.info.desktopId | is-empty) { "—" } else { $r.info.desktopId })
                let n = ($r.info.mimeTypes | length)
                let types = (if $n == 0 { "env vars only" } else if $n == 1 { "1 MIME type" } else { $"($n) MIME types" })
                print $"  (ansi cyan)($r.role | fill -a l -w 12)(ansi reset) (ansi green)($r.info.slug | fill -a l -w 20)(ansi reset) ($id | fill -a l -w 34) (ansi dark_gray)($types)(ansi reset)"
              }
            }
            "show" => {
              let want = (if $a == null { "editor" } else { $a })
              if not ($want in $roles.role) {
                print $"(ansi red)unknown role '($want)' — try: ($roleList)(ansi reset)"; return
              }
              let i = ($reg.roles | get $want)
              print $"(ansi cyan)($want)(ansi reset)  ($i.description)"
              print $"  app       (ansi green)($i.name)(ansi reset)  (ansi dark_gray)[($i.slug), ($i.source)](ansi reset)"
              if not ($i.desktopId | is-empty) { print $"  desktop   ($i.desktopId)" }
              if ($i.mimeTypes | is-empty) {
                print $"  (ansi dark_gray)binds no MIME types — this role drives environment variables only(ansi reset)"
              } else {
                print $"  binds     ($i.mimeTypes | length) MIME types"
                for m in ($i.mimeTypes | sort) { print $"            (ansi dark_gray)($m)(ansi reset)" }
              }
            }
            "candidates" => {
              if $a == null {
                print $"(ansi red)app candidates needs a role — try: ($roleList)(ansi reset)"; return
              }
              if not ($a in $roles.role) {
                print $"(ansi red)unknown role '($a)' — try: ($roleList)(ansi reset)"; return
              }
              let active = ($reg.roles | get $a | get slug)
              print $"(ansi dark_gray)* = active(ansi reset)"
              for s in ($reg.roles | get $a | get candidates) {
                let e = ($reg.catalog | get $s)
                let mark = (if $s == $active { $"(ansi green)*(ansi reset)" } else { " " })
                let id = (if ($e.desktopId | is-empty) { "—" } else { $e.desktopId })
                print $"($mark) ($s | fill -a l -w 20) ($e.name | fill -a l -w 22) (ansi dark_gray)($id | fill -a l -w 34) ($e.source)(ansi reset)"
              }
            }
            "set" => {
              if ($a == null) or ($b == null) {
                print $"(ansi red)app set needs a role and a slug — e.g. app set editor cosmic-edit(ansi reset)"
                print $"(ansi dark_gray)roles: ($roleList)(ansi reset)"; return
              }
              if not ($a in $roles.role) {
                print $"(ansi red)unknown role '($a)' — try: ($roleList)(ansi reset)"; return
              }
              let cand = ($reg.roles | get $a | get candidates)
              if not ($b in $cand) {
                print $"(ansi red)'($b)' cannot fill the role '($a)'(ansi reset)"
                print $"(ansi dark_gray)candidates: ($cand | str join ', ')(ansi reset)"
                print $"(ansi dark_gray)or add it: /spacecraft-software/bravais/apps/($b).nix — see apps/README.md(ansi reset)"
                return
              }
              let cur = ($reg.roles | get $a | get slug)
              if $b == $cur { print $"(ansi green)already active: ($a) = ($cur)(ansi reset)"; return }
              let f = "/spacecraft-software/bravais/default-apps.nix"
              # Anchored at the binding so the slug list in the file's comment
              # block is never rewritten. This is why default-apps.nix does
              # not align its `=` signs.
              ^sd $'($a) = "($cur)"' $'($a) = "($b)"' $f
              print $"(ansi green)default-apps.nix: ($a) ($cur) → ($b)(ansi reset)"
              print $"run (ansi cyan)rebuild(ansi reset) to apply, or (ansi cyan)app set ($a) ($cur)(ansi reset) to undo"
            }
            "help" => { help app }
            _ => { print $"(ansi red)unknown action '($action)' — try: list, show, candidates, set, help(ansi reset)" }
          }
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
          let stamp = ($nu.home-dir | path join ".cache" "bravais-vendored-check")
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

            # MCP host configs are NOT part of this flake. They live in
            # /spacecraft-software/mcp-servers, are generated from that repo's
            # mcp.toml, and reach the machine only through `mcpctl deploy` — an
            # imperative write into files that Claude Code, goose, Codex and the
            # rest own. A rebuild cannot carry them along, so this only reports.
            #
            # Deliberately a warning and not an automatic deploy. `deploy` refuses
            # a host whose process is running, and a rebuild is usually run from an
            # agent session — so an auto-deploy would silently skip ~/.claude.json,
            # the file most likely to be stale, while reporting success. Surfacing
            # the skip is the useful half; the write stays a deliberate step.
            # mcpctl comes from the `mcp-servers` flake input, so it is always
            # present — no PATH probe, and no cargo-artifact fallback. Note the
            # input is `git+file:`, which sees COMMITTED content only: this
            # binary is the manifest logic as of the rev in flake.lock, so an
            # uncommitted mcpctl change is not what runs here.
            let mcp_repo = "/spacecraft-software/mcp-servers"
            if ($mcp_repo | path exists) {
              # --dry-run --json is read-only; it never writes to $HOME.
              let probe = (^${mcpctl} deploy --dry-run --json --repo $mcp_repo | complete)
              if $probe.exit_code == 0 {
                let report = ($probe.stdout | from json | get data)
                let drifted = ($report.files | where dirty | length)
                if $drifted > 0 {
                  print $"(ansi yellow)($drifted) MCP host config\(s\) drifted from the manifest — run: mcpctl deploy --yes(ansi reset)"
                }
                if ($report.blocked | length) > 0 {
                  print $"(ansi yellow)MCP deploy would skip a running host — close it and re-run mcpctl deploy:(ansi reset)"
                  # `for`, not `each`: `each` returns a list and Nushell renders it.
                  for entry in $report.blocked { print $"  ($entry)" }
                }
              } else {
                print $"(ansi yellow)mcpctl drift probe failed:(ansi reset)"; print $probe.stderr
              }
            }
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
      alias edit = ${termEditor}
    '';
  };
}
