# macsetup

Provision a Mac from a single command: Homebrew, applications, command-line
tools, dotfiles, and a set of macOS settings tuned for performance and
security. Every setting is read back after it is written, and the run ends with
a list of anything that did not apply.

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [What the menu offers](#what-the-menu-offers)
- [macOS settings](#macos-settings)
- [Set by hand](#set-by-hand)
- [Development](#development)

## Requirements

- An Apple Silicon Mac running macOS 27 (verified on 27.2.1).
- An administrator account. The menu asks for the password once, at startup,
  and ends the sudo session when it exits.

## Quick start

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/gameshler/macsetup/main/start.sh)
```

The script downloads the repository to `~/Downloads/macsetup`, installs
Homebrew if it is missing, and opens an interactive menu. Choose an entry with
its number, `b` to go back, and `q` to quit. Every entry can be run again
safely: anything already installed or set is skipped.

## What the menu offers

### System Settings

| Entry | What it does |
| --- | --- |
| Optimize Settings | Applies and verifies every macOS setting below, then prints one report. |
| Developer Setup | Command-line tools, Node through nvm, bun with global packages, developer apps, and the git and Ghostty dotfiles. |
| Shell Setup | zsh plugins and tools, the starship prompt, a Nerd Font, and the `.zshrc` and starship dotfiles. |
| Git SSH Key | Creates an ed25519 key, configures the SSH agent, uploads the key to GitHub, and verifies the connection. Falls back to port 443 when port 22 is blocked. |

Developer Setup installs:

- **Formulas:** `tree`, `unzip`, `python`, `pipx`, `cmake`, `make`, `jq`, `fd`,
  `ripgrep`, `automake`, `autoconf`, `ffmpeg`, `imagemagick`, `tlrc`, `rust`,
  `git`, `uv`.
- **Apps:** Ghostty, Alfred, Rectangle, Keka, Docker Desktop, Conductor, and
  Claude Code.
- **Node:** nvm, then Node 25.
- **Global packages, through bun:** `lite-server`, `http-server`, `license`,
  `gitignore`.

Shell Setup installs `zsh-autocomplete`, `bat`, `tree`, `multitail`,
`fastfetch`, `unzip`, `fontconfig`, `starship`, `fzf`, and the Fira Code Nerd
Font. An existing `~/.zshrc` is backed up to `~/.zshrc.bak` first.

### Applications

| Category | Apps |
| --- | --- |
| Browsers | Brave, Google Chrome, Firefox, Thorium |
| Communication | Discord, Signal, Slack, Telegram, WhatsApp, Zoom |
| Developer Tools | Cursor, GitHub Desktop, Neovim (with the owner's config), Sublime Text, Visual Studio Code, Zed |
| Office | Microsoft Office: Word, Excel, PowerPoint, and Outlook |

## macOS settings

Optimize Settings runs these areas in order. Services such as Finder, the Dock
and Control Center restart once at the end, so changes show without logging
out.

| Area | Settings |
| --- | --- |
| Security | Firewall and stealth mode on; password required immediately after sleep or the screen saver; AirPlay Receiver and wake for network access off; automatic update downloads and installs off, security updates on |
| Battery | Slightly dim the display on battery, off; prevent sleep on the power adapter when the display is off, off; optimize video streaming on battery, off |
| Spotlight | Every result category and file type hidden, cmd+space released for Alfred, Help Apple Improve Search off. Indexing stays on, because Alfred uses it. |
| Siri suggestions | Suggestions off in every app |
| Apple Intelligence | Turned off, and the Microsoft 365 Copilot app removed |
| Alfred | cmd+space hotkey; Google as the only web search |
| Dock and Desktop | Smallest Dock on the left, hidden automatically, no launch animation or recent apps, holding only System Settings; no desktop items, widgets, or Stage Manager |
| Menu bar | Every system item hidden, including Wi-Fi, Bluetooth, Sound, Spotlight, Siri, and Time Machine; Control Gallery suggestions off |
| Wallpaper | Solid black on every display and Space |
| Finder | Home folder in new windows, list view, folders open in tabs, all file extensions shown without a warning, search the current folder, path and status bars on, recent tags off, nothing on the desktop |
| Trackpad | Tap to click on, natural scrolling off |
| Animations | Reduced motion; window, scroll, Finder, Mail, and Quick Look animations off; Dock and Mission Control animations shortened |
| Display | Universal Control off; the built-in display set to its More Space resolution |
| Cleanup | Empty the Trash and old logs; Spaces kept in a fixed order |

The Bluetooth radio, FileVault, and Weather in the menu bar are left as they
are.

## Set by hand

Some settings are stored where macOS requires Full Disk Access, which I do not
grant the terminal. I set these myself after a run:

- Finder > Settings
  - Sidebar: tick only Applications, Documents, Downloads, Home, and External
    disks
  - Sidebar: Recent Tags off
  - Tags: uncheck every tag under Show these tags in the sidebar
- System Settings
  - Notifications > Tips > Allow notifications: off
  - Spotlight > Results from Clipboard: off
  - Menu Bar > Allow in the Menu Bar: every app off
  - General > AutoFill & Passwords: every option off
  - Accessibility > Display > Reduce motion: on
- Empty the Trash

These are also done by hand, by choice:

- FileVault
- Browser extensions: Privacy Badger, Decentraleyes, and uBlock Origin

## Development

The scripts change the machine they run on, so never run `core/main.sh` from a
checkout you want to keep: it deletes its install directory on a clean exit.
`AGENTS.md` explains how to run it safely against a copy, and the rules every
change follows.

Checks, which also run in CI except `bats`:

```sh
find . -name '*.sh' -not -path './.git/*' -print0 |
    xargs -0 shellcheck -S warning -e SC1090,SC1091
shfmt -d -i 4 .
bats test/
typos
```

Project documents:

- [`SPEC.md`](SPEC.md): requirements and decisions
- [`ROADMAP.md`](ROADMAP.md): phases and their status
- [`TASKS.md`](TASKS.md): open work and the verified preference keys
- [`AGENTS.md`](AGENTS.md): instructions for contributors and coding agents
