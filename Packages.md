```markdown
# Packages

**Legend:**
🦀 = Written in Rust
⚡ = Written in Zig
🐹 = Written in Go
🐍 = Written in Python
(λ) = Written in Scheme (Lisp)
⚠️ = Standard/Reliability Stack (C/C++/Shell/TS/Web)
`[CLI ⌨️]` = Command Line Interface
`[TUI 🎛️]` = Terminal User Interface
`[GUI 🖱️]` = Graphical User Interface

---

### **1. Boot & Login**
* **Bootloader Manager**
    * **Lanzaboote** 🦀 `[CLI ⌨️]` *(Secure Boot Manager)*
* **Login Managers**
    * **Greetd** 🦀 `[CLI ⌨️]` *(Minimal and flexible login daemon)*
    * **Tuigreet** 🦀 `[TUI 🎛️]` *(Console UI greeter, best for Niri/LeftWM)*
    * **Lemurs** 🦀 `[TUI 🎛️]` *(Customizable terminal/TUI display manager)*
    * **cosmic-greeter** 🦀 `[GUI 🖱️]` *(Official COSMIC desktop login manager)*
* **System Components**
    * **xdg-desktop-portal-cosmic** 🦀 `[CLI ⌨️]` *(Wayland Portal backend)*
    * **sudo-rs** 🦀 `[CLI ⌨️]` *(Memory-safe `sudo` implementation)*

### **2. Desktop & Window Management**
* **Window Managers & Sessions**
    * **niri** 🦀 `[Wayland]` *(The Spacecraft Software Standard scrollable tiling manager)*
    * **leftwm** 🦀 `[X11]` *(Lightweight, themeable X11 tiling window manager)*
    * **COSMIC DE** 🦀 `[Wayland]` *(System76's Rust-based desktop environment)*
    * **cosmic-session** 🦀 `[CLI ⌨️]` *(COSMIC Session Manager)*
* **Desktop Suites**
    * **DankMaterialShell** 🐹 `[GUI 🖱️]` *(Go/Qt - Total shell replacement)*
* **Launchers**
    * **anyrun** 🦀 `[GUI 🖱️]` *(Fast, extensible Wayland application launcher)*
    * **rlaunch** 🦀 `[GUI 🖱️]` *(Lightweight application launcher for X11)*
    * **onagre** 🦀 `[GUI 🖱️]` *(Application launcher based on iced GUI library)*
* **Input Tools**
    * **xremap** 🦀 `[CLI ⌨️]` *(Dynamic key remapper for Linux)*

### **3. System Monitoring & Panels**
* **Bars & Widgets**
    * **Ironbar** 🦀 `[GUI 🖱️]` *(The "Steelbore" GTK4 taskbar/panel)*
    * **eww** 🦀 `[GUI 🖱️]` *(ElKowars wacky widgets - custom UI creator)*
* **Notifications**
    * **wired** 🦀 `[Daemon]` *(Lightweight, customizable notification daemon)*
* **Hardware & Kernel**
    * **kmon** 🦀 `[TUI 🎛️]` *(Linux kernel manager and monitor)*
    * **bottom** 🦀 `[TUI 🎛️]` *(Cross-platform graphical process/system monitor)*
    * **bandwhich** 🦀 `[TUI 🎛️]` *(Terminal bandwidth utilization tool)*
    * **Mission Center** 🦀 `[GUI 🖱️]` *(Modern system task manager)*
    * **macchina** 🦀 `[CLI ⌨️]` *(Fast system info fetcher)*

### **4. Package & System Management**
* **The Rust Stack**
    * **Omni** 🦀 `[CLI ⌨️]` *(Universal Package Manager bridging all distros)*
    * **Zap** 🦀 `[CLI ⌨️]` *(High-performance AppImage/System package manager)*
    * **topgrade** 🦀 `[CLI ⌨️]` *(CLI tool to upgrade all software on your system)*
    * **Paru** 🦀 `[CLI ⌨️]` *(Feature-rich, fast AUR Helper)*
    * **cargo-update** 🦀 `[CLI ⌨️]` *(Updater for `cargo install` binaries)*
    * **linutil** 🦀 `[TUI 🎛️]` *(Distro agnostic maintenance and setup tool)*
* **Dotfile Management**
    * **dotter** 🦀 `[CLI ⌨️]` *(Dotfile manager and templater)*
* **The Standard Stack**
    * **Guix** (λ) `[CLI ⌨️]` *(Functional package manager in Guile Scheme)*
    * **am** ⚠️ `[CLI ⌨️]` *(AppImage Manager built in Bash)*
    * **brew** ⚠️ `[CLI ⌨️]` *(Homebrew for Linux, Ruby-based)*
    * **Flatpak** ⚠️ `[CLI ⌨️]` *(Universal sandboxed app packaging - C)*
    * **Nix** ⚠️ `[CLI ⌨️]` *(Declarative package manager - C++)*

### **5. File & Disk Management**
* **File Managers**
    * **yazi** 🦀 `[TUI 🎛️]` *(Blazing fast async terminal file manager)*
    * **broot** 🦀 `[TUI 🎛️]` *(Tree-based terminal file manager)*
    * **superfile** 🐹 `[TUI 🎛️]` *(Modern, visually rich terminal file manager in Go)*
    * **cosmic-files** 🦀 `[GUI 🖱️]` *(Official file manager for COSMIC Desktop)*
    * **Spacedrive** 🦀 `[GUI 🖱️]` *(Cross-platform virtual distributed file explorer)*
* **Disk Usage & Cleaning**
    * **dust** 🦀 `[CLI ⌨️]` *(Intuitive disk usage analyzer / `du` alternative)*
    * **dua** 🦀 `[TUI 🎛️]` *(Interactive, parallel disk usage viewer)*
    * **fclones** 🦀 `[CLI ⌨️]` *(Extremely fast duplicate file finder)*
    * **kondo** 🦀 `[CLI ⌨️]` *(CLI tool to clean unneeded software project files)*
* **Partitioning**
    * **disktui** 🦀 `[TUI 🎛️]` *(Interactive Partition Manager)*
    * **gptman** 🦀 `[CLI ⌨️]` *(Scriptable GPT Manager)*

### **6. Core Utilities (The "Modern Unix" Stack)**
* **File Operations**
    * **fd** 🦀 `[CLI ⌨️]` *(User-friendly `find` replacement)*
    * **ripgrep** 🦀 `[CLI ⌨️]` *(Fast `grep` alternative)*
    * **bat** 🦀 `[CLI ⌨️]` *(`cat` with syntax highlighting and Git integration)*
    * **eza** 🦀 `[CLI ⌨️]` *(Modern `ls` replacement with git/tree support)*
    * **sd** 🦀 `[CLI ⌨️]` *(Intuitive `sed` replacement for find-and-replace)*
    * **ouch** 🦀 `[CLI ⌨️]` *(Painless compression/decompression for all archives)*
    * **zoxide** 🦀 `[CLI ⌨️]` *(Smarter `cd` command with history)*
* **Text Processing & System Utils**
    * **jaq** 🦀 `[CLI ⌨️]` *(JSON processor / fast `jq` clone)*
    * **uutils** 🦀 `[CLI ⌨️]` *(Cross-platform Rust Coreutils reimplementation)*
    * **rustybox** 🦀 `[CLI ⌨️]` *(100% Rust Busybox clone)*
    * **procs** 🦀 `[CLI ⌨️]` *(Modern `ps` alternative with colored output)*
    * **tokei** 🦀 `[CLI ⌨️]` *(Fast code statistics/line-counting tool)*

### **7. Development & Git**
* **Git & Ops**
    * **gitui** 🦀 `[TUI 🎛️]` *(Blazing fast, keyboard-driven Git UI)*
    * **delta** 🦀 `[CLI ⌨️]` *(Syntax-highlighting pager for git diffs)*
    * **jujutsu (jj)** 🦀 `[CLI ⌨️]` *(Git-compatible DVCS with a focus on simplicity)*
    * **cpx** 🦀 `[CLI ⌨️]` *(Competitive Programming Helper tool)*
    * **Gitway** 🦀 `[CLI ⌨️]` *(Spacecraft Software SSH transport for Git — drop-in for ssh-add / ssh-keygen / GIT_SSH_COMMAND)*
* **Containers**
    * **Podman** 🐹 `[CLI ⌨️]` *(Daemonless, Docker-compatible container engine)*
* **Toolchains & Env**
    * **rustup** 🦀 `[CLI ⌨️]` *(The official Rust toolchain installer)*
    * **lorri** 🦀 `[CLI ⌨️]` *(Rust-based Nix environment manager daemon)*
    * **just** 🦀 `[CLI ⌨️]` *(Handy command runner / modern `make`)*

### **8. Security & Encryption**
* **Tools**
    * **age** (rage) 🦀 `[CLI ⌨️]` *(Modern, simple, secure file encryption)*
    * **sequoia** 🦀 `[CLI ⌨️]` *(Modern OpenPGP implementation)*
    * **sequoia-chameleon** 🦀 `[CLI ⌨️]` *(GnuPG drop-in replacement using Sequoia)*
    * **rbw** 🦀 `[CLI ⌨️]` *(Unofficial CLI client for Bitwarden)*
    * **Goldwarden** 🦀 `[GUI 🖱️]` *(Feature-rich desktop Bitwarden client)*
    * **Authenticator** 🦀 `[GUI 🖱️]` *(Two-factor authentication code generator)*
* **Backup & App Stores**
    * **Pika Backup** 🦀 `[GUI 🖱️]` *(Simple frontend for the Borg backup tool)*
    * **cosmic-store** 🦀 `[GUI 🖱️]` *(Official App Store for COSMIC Desktop)*

### **9. Networking & Internet**
* **Network Management**
    * **impala** 🦀 `[TUI 🎛️]` *(Rust TUI for managing Wi-Fi via iwd)*
    * **iwd** ⚠️ `[CLI ⌨️]` *(Modern Wi-Fi daemon by Intel - C)*
    * **nmstate** 🦀 `[CLI ⌨️]` *(Declarative network configuration tool)*
    * **AdGuard VPN CLI** 🐹 `[CLI ⌨️]` *(Command-line interface for AdGuard VPN)*
* **Diagnostics & Tools**
    * **xh** 🦀 `[CLI ⌨️]` *(Friendly and fast `curl` replacement)*
    * **monolith** 🦀 `[CLI ⌨️]` *(Saves complete web pages as single HTML files)*
    * **lychee** 🦀 `[CLI ⌨️]` *(Fast, async link checker)*
    * **ssh-rs** 🦀 `[CLI ⌨️]` *(Pure Rust SSH2 protocol implementation)*
    * **dog** 🦀 `[CLI ⌨️]` *(DNS client / user-friendly `dig` replacement)*
    * **gping** 🦀 `[CLI ⌨️]` *(Ping command, but with a real-time graph)*
    * **rustscan** 🦀 `[CLI ⌨️]` *(Extremely fast port scanner / Nmap wrapper)*
    * **sniffglue** 🦀 `[CLI ⌨️]` *(Secure multithreaded packet sniffer)*
    * **Trippy** 🦀 `[TUI 🎛️]` *(Network diagnostic tool / modern traceroute)*
* **Standard Stack**
    * **wget2** ⚠️ `[CLI ⌨️]` *(Faster, multithreaded wget - C)*
    * **curl** ⚠️ `[CLI ⌨️]` *(The gold standard for data transfer - C)*
* **GUI Apps**
    * **Sniffnet** 🦀 `[GUI 🖱️]` *(Application to comfortably monitor your network traffic)*
    * **Mullvad VPN** 🦀 `[GUI 🖱️]` *(Privacy-focused VPN client app)*
    * **rqbit** 🦀 `[GUI 🖱️]` *(Fast and simple BitTorrent client)*

### **10. Terminal Environment**
* **Emulators**
    * **Ghostty** ⚡ `[GUI 🖱️]` *(Zig - High-performance, native terminal)*
    * **Alacritty** 🦀 `[GUI 🖱️]` *(Extremely fast, GPU-accelerated terminal emulator)*
    * **WezTerm** 🦀 `[GUI 🖱️]` *(GPU-accelerated terminal and multiplexer)*
    * **Rio** 🦀 `[GUI 🖱️]` *(Hardware-accelerated terminal for the modern era)*
    * **cosmic-term** 🦀 `[GUI 🖱️]` *(Official COSMIC terminal emulator)*
* **Shells**
    * **nushell** 🦀 `[CLI ⌨️]` *(Data-driven, object-oriented shell)*
    * **Brush** 🦀 `[CLI ⌨️]` *(Bash-Compatible shell written in Rust)*
    * **starship** 🦀 `[CLI ⌨️]` *(Extremely customizable, cross-shell prompt)*
    * **atuin** 🦀 `[CLI ⌨️]` *(Magical, synced shell history using SQLite)*
    * **Ion** 🦀 `[CLI ⌨️]` *(Modern, fast system shell by Redox OS)*
* **Tools**
    * **zellij** 🦀 `[TUI 🎛️]` *(User-friendly terminal multiplexer / `tmux` alternative)*
    * **t-rec** 🦀 `[CLI ⌨️]` *(Terminal recorder that outputs to GIF/MP4)*

### **11. Communication**
* **Matrix**
    * **matrix-commander-rs** 🦀 `[CLI ⌨️]` *(Command-line Matrix client)*
    * **iamb** 🦀 `[TUI 🎛️]` *(Vim-like terminal-based Matrix client)*
    * **rumatui** 🦀 `[TUI 🎛️]` *(Terminal user interface for Matrix chat)*
    * **Fractal** 🦀 `[GUI 🖱️]` *(Official GNOME Matrix messaging client)*
* **Discord**
    * **disrust** 🦀 `[TUI 🎛️]` *(Terminal Discord client)*
    * **RivetUI** 🦀 `[TUI 🎛️]` *(TUI client for Discord)*
    * **LemonCord** 🦀 `[GUI 🖱️]` *(Third-party Discord desktop client)*
    * **fastcord** 🦀 `[GUI 🖱️]` *(Lightweight alternative Discord client)*
* **Fediverse / Social**
    * **ebou** 🦀 `[GUI 🖱️]` *(Cross-platform Mastodon client)*
    * **NewsFlash** 🦀 `[GUI 🖱️]` *(Modern RSS/Atom feed reader)*

### **12. Text Editing**
* **CLI/TUI**
    * **helix** 🦀 `[TUI 🎛️]` *(Post-modern, multiple-selection modal text editor)*
    * **rsvim** 🦀 `[TUI 🎛️]` *(Vim implementation built from scratch in Rust)*
    * **amp** 🦀 `[TUI 🎛️]` *(Vi/Vim-inspired terminal text editor)*
    * **msedit** 🦀 `[TUI 🎛️]` *(Minimalist terminal text editor)*
    * **Vim** ⚠️ `[TUI 🎛️]` *(The classic Vi IMproved text editor — Flatpak)*
* **GUI**
    * **Zed** 🦀 `[GUI 🖱️]` *(High-performance, multiplayer code editor)*
    * **Lapce** 🦀 `[GUI 🖱️]` *(Lightning-fast, native IDE)*
    * **Tau** 🦀 `[GUI 🖱️]` *(GTK-based text editor built around Xi-editor core)*
    * **cosmic-edit** 🦀 `[GUI 🖱️]` *(Official COSMIC text editor)*
    * **neovide** 🦀 `[GUI 🖱️]` *(No-nonsense graphical Neovim frontend)*
    * **emacs-pgtk** ⚠️ `[GUI 🖱️]` *(Emacs with pure GTK backend — Wayland-native)*
    * **vscode-fhs** ⚠️ `[GUI 🖱️]` *(VS Code in FHS-compatible wrapper)*

### **13. Multimedia & Processing**
* **Video/Audio Players**
    * **mpv** ⚠️ `[TUI 🎛️]` *(Versatile, high-quality command-line media player - C)*
    * **Amberol** 🦀 `[GUI 🖱️]` *(Small, simple local music player)*
    * **Shortwave** 🦀 `[GUI 🖱️]` *(Internet radio player)*
    * **ncspot** 🦀 `[TUI 🎛️]` *(Cross-platform Spotify TUI client)*
    * **Psst** 🦀 `[GUI 🖱️]` *(Fast, native Spotify GUI client)*
    * **termusic** 🦀 `[TUI 🎛️]` *(Terminal music player with album art support)*
    * **radio-browser-rust** 🦀 `[CLI ⌨️]` *(CLI to search and play internet radio stations)*
    * **Loupe** 🦀 `[GUI 🖱️]` *(Official GNOME image viewer)*
    * **viu** 🦀 `[CLI ⌨️]` *(Terminal image viewer with kitty/sixel support)*
    * **Mousai** 🦀 `[GUI 🖱️]` *(Song identification app / Shazam clone)*
* **Processing & Encoders**
    * **ffmpeg** ⚠️ `[CLI ⌨️]` *(The standard multimedia processing toolkit - C)*
    * **rav1e** 🦀 `[CLI ⌨️]` *(Fastest and safest AV1 video encoder)*
    * **gifski** 🦀 `[CLI ⌨️]` *(High-quality GIF encoder based on pngquant)*
    * **oxipng** 🦀 `[CLI ⌨️]` *(Multithreaded, lossless PNG optimization tool)*
    * **Gyroflow** 🦀 `[GUI 🖱️]` *(Advanced video stabilization tool)*
    * **Video Trimmer** 🦀 `[GUI 🖱️]` *(GTK app to quickly trim videos)*
* **Downloaders**
    * **yt-dlp** 🐍 `[CLI ⌨️]` *(Feature-rich YouTube downloader and extractor)*
    * **Gydl** 🦀 `[GUI 🖱️]` *(Graphical frontend for yt-dlp)*

### **14. AI & Productivity**
* **AI Coding Agents**
    * **OpenAI Codex CLI** ⚠️ `[CLI ⌨️]` *(TypeScript - Official OpenAI local coding agent with MCP support)*
    * **MiniMax CLI** 🦀 `[CLI ⌨️]` *(Rust - Terminal-native AI coding assistant powered by MiniMax)*
    * **Kilo** ⚠️ `[CLI ⌨️]` *(TypeScript - Agentic engineering platform)*
    * **Kiro CLI** ⚠️ `[CLI ⌨️]` *(AI-native CLI designed to supercharge developer workflows)*
    * **Kimi-CLI** ⚠️ `[CLI ⌨️]` *(Command-line interface for Moonshot AI, specialized for long-context coding)*
* **CLI AI Assistants**
    * **GitHub Copilot CLI** ⚠️ `[CLI ⌨️]` *(TypeScript - GitHub's official AI terminal assistant)*
    * **OpenCode** 🐹 `[CLI ⌨️]` *(Go - Open source AI coding assistant)*
    * **aichat** 🦀 `[CLI ⌨️]` *(Universal CLI Chat REPL for multiple LLMs)*
    * **gemini-cli** 🦀 `[CLI ⌨️]` *(Command-line client for Google Gemini)*
    * **claude-cli** 🦀 `[CLI ⌨️]` *(Command-line client for Anthropic Claude)*
* **Knowledge & Workflow**
    * **appflowy** 🦀 `[GUI 🖱️]` *(Open Source Notion alternative prioritizing privacy)*
    * **AFFiNE** 🦀 `[GUI 🖱️]` *(Next-gen knowledge base and collaborative whiteboard)*
    * **gws-cli** 🦀 `[CLI ⌨️]` *(Rust - Unified Google Workspace CLI dynamically built for humans and AI agents)*
