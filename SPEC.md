# Specification

## Problem

Setting up a Mac by hand takes a day and produces a machine that only
approximately matches the previous one. Applications are installed as they come
to mind, command-line tools as they are missed, and system settings are
re-derived from memory in System Settings. Nothing records the finished state,
so each machine drifts from the last, and a setting reverted by an OS upgrade
goes unnoticed.

This repository is that record. Running it on a clean Mac produces the same
machine every time.

## Users

A single developer on Apple Silicon, setting up a new Mac or repairing an
existing one. Runs are interactive and attended; nothing is provisioned
unattended.

## Required behavior

### Bootstrap

- Install from a single command on a Mac with nothing but the OS.
- Install Homebrew when it is absent, and detect it when present, including in
  the session that just installed it, before any shell restart.
- Present a menu generated from the directory tree, so adding a script adds an
  entry with no registration step.

### Installation

- Install an application or tool only when it is absent. A second run of any
  entry installs nothing.
- Run without interactive prompts: Homebrew does not auto-update before each
  install and does not ask for confirmation per package.
- Ask for the administrator password at most once per session.
- Copy the owner's dotfiles to the locations their applications read.

### System settings

- Apply the owner's preferences from one menu entry, Optimize Settings, in a
  fixed order: security, battery, Spotlight, Siri suggestions, Apple
  Intelligence, Alfred, Dock and Desktop, menu bar, wallpaper, Finder,
  trackpad, animations, display, and cleanup.
- Write every user preference as the logged-in user, so it applies to the
  account running the script.
- Read every setting back after writing it, and report each one that did not
  apply in a single list at the end of the run. A setting that cannot be
  confirmed is a failure, not a success.
- Restart each service that owns a changed preference, once per run, so the
  change is visible without logging out.
- When a setting has no scriptable interface, or can only be reached with Full
  Disk Access, say so and list it as a manual step in `README.md` instead of
  writing a key that silently does nothing.

### Failure behavior

- A failed install names the package that failed and does not report success.
- A missing dotfile reports the path it looked for instead of skipping
  silently.
- A script that cannot reach its target, such as a missing directory or an
  unwritable preference domain, does what it can and reports what it cannot.
- A tab script that fails returns to the menu with the install directory
  intact.

## Architecture and data flow

`start.sh` downloads the repository as a zip, unpacks it to
`~/Downloads/macsetup`, and runs `core/main.sh`. The menu exports the shared
paths, takes the administrator password once, and runs each selection as a
separate `bash` process. Every tab sources `core/tabs/common-script.sh` for the
Homebrew environment and the install helpers.

System settings are declared as data. A settings module lists the preferences
it wants as pipe-delimited rows (domain, key, type, value, owning service) and
passes them to `apply_settings` in `core/tabs/settings-lib.sh`, which writes
each row, reads it back as the logged-in user, records any mismatch, and
restarts each owning service once. Verification is therefore a property of the
code path rather than something each module must remember.

A small number of settings are arrays, nested dictionaries, or files rather
than scalar values: Dock contents, Spotlight categories, symbolic hotkeys,
Finder tags, menu extras, Alfred's preference bundle, and the wallpaper store.
These are written by explicit code in their module and verified through the
same shared helpers, so their failures land in the same report.

Dotfiles in `dotfiles/` are copied, not linked. Editing a file in the home
directory does not update this repository.

All state lives on the machine, in Homebrew's prefix and in macOS preference
domains. The repository keeps no record of previous runs.

## Security and privacy

- No credential, license key, or serial number is committed.
- `sudo` is used only for system-scoped targets: absolute paths under
  `/Library/Preferences`, `pmset`, `socketfilterfw`, and `installer`. It is
  never used for a user preference domain. The screen lock delay is set with
  `sysadminctl`, which asks for the login password instead.
- The administrator password is taken once per session, held by a keepalive
  for that session only, and released with `sudo -k` on every exit.
- The terminal is not granted Full Disk Access. Settings that need it are set
  by hand from the list in `README.md`. If a grant is present, the menu
  revokes it on exit by bundle identifier only.
- `start.sh` runs code fetched over the network, and `office.sh` installs
  packages downloaded from third-party URLs. This is inherent to the design.
  The mitigation is that both run attended and their URLs are under version
  control, where they can be reviewed.
- The firewall and its stealth mode are enabled, a password is required
  immediately after sleep or the screen saver, and AirPlay Receiver and wake
  for network access are off.

## Performance and compatibility

- Target: Apple Silicon on macOS 27, verified against 27.2.1 (26B131) on
  2026-11-17. The repository was first developed against macOS 15.7.9
  (24G830).
- Homebrew is expected at `/opt/homebrew`. `/usr/local` is accepted for Intel
  but not tested.
- A multi-application install completes without per-package interaction. The
  measure is prompts, not elapsed time: one password prompt and no
  confirmations.
- Preference keys are version-sensitive. A key verified on one macOS release is
  not assumed to hold on the next major version, and the version each key was
  verified against is recorded in `TASKS.md`.
- Writes target preference domains rather than plist paths where possible.
  Apple has warned that `defaults` will operate only on domains, which would
  retire the `/Library/Preferences/...` path form the Software Update and
  battery settings use. That form is the largest upgrade risk.

## Non-goals

- Unattended or fleet provisioning, configuration profiles, or MDM. CI lints
  the scripts but provisions nothing.
- Uninstallation or rollback to a clean machine.
- Bidirectional dotfile sync.
- macOS versions other than the current one, or Intel hardware.
- Backing up or migrating an existing machine's data.
- Application licenses, sign-ins, or any state behind an account.
- FileVault and the Bluetooth radio, which the owner manages by hand.

## Acceptance criteria

- On a clean Mac, the bootstrap command reaches the menu with no manual step in
  between.
- Three entries run in one session each report Homebrew as already installed
  and reinstall nothing.
- Installing the full cask list prompts for the password once and never for
  confirmation.
- Every entry is idempotent: a second run changes nothing.
- After the developer setup entry, `~/.config/ghostty/config` matches
  `dotfiles/` and `ghostty +show-config` reports those values. Matching the
  file alone is not enough: Ghostty loads its Application Support directory
  after XDG, so a leftover file there would override a correct config without
  any report.
- Every user preference the scripts write reads back correctly under
  `defaults read` as the logged-in user, and System Settings agrees.
- No `sudo defaults write` against an unqualified domain exists in the
  repository.
- No scalar `defaults write` exists outside `core/tabs/settings-lib.sh`.
- A deliberately misspelled key in a manifest makes the run report a failure.
- `bats test/` passes. It covers the decisions the scripts make about what to
  write and whether it applied. Whether a key is the one macOS actually reads
  is not testable and remains a manual check against System Settings.
- `shellcheck -S warning` passes on every script.
- `ssh -T git@github.com` authenticates after the Git SSH Key entry runs.

## Decisions

Each of these was an open question; all are now settled.

- **Finder sidebar: set by hand.** Sidebar favorites live in an
  NSKeyedArchiver file under `~/Library/Application Support/com.apple.sharedfilelist/`
  with no preference domain. `LSSharedFileList`, the API behind `mysides`,
  returns an empty list for sidebar favorites on macOS 15 without an error,
  and the file is protected by TCC, so nothing can be read back without Full
  Disk Access. The owner rejected `sbedit` and does not grant Full Disk Access,
  so the sidebar is in `README.md` under Set by hand (2026-11-17).
- **Alfred: written directly.** Alfred's settings live in an
  `Alfred.alfredpreferences` bundle, and it rewrites them on quit. `alfred.sh`
  quits Alfred, writes the cmd+space hotkey into this Mac's local preference
  folder and disables every web search except Google, then relaunches it.
- **Browser extensions: installed by hand.** Each browser engine needs a
  different mechanism, and the owner chose to install Privacy Badger,
  Decentraleyes and uBlock Origin manually (2026-11-17).
- **Display scaling: automated.** "More Space" has no preference key.
  `display.sh` uses `displayplacer` and picks the widest scaled mode at run
  time, so no panel-specific value is stored. It configures a single built-in
  display only.
- **Software Update: five keys.** Downloads and installs are off; system data
  files and security updates stay on. macOS 27 has no check-for-updates
  toggle and deletes `AutomaticCheckEnabled` on its next scan, so that key is
  not written (2026-11-17).
- **Displays Advanced and AutoFill.** Universal Control's two toggles were
  found by changing the pane and comparing preferences, and are written.
  AutoFill & Passwords is stored where Full Disk Access is required, so it is
  set by hand (2026-11-17).
- **Weather in the menu bar: left alone.** A new install keeps it out of the
  menu bar, and its icon is drawn by the Weather app's own launchd agent
  rather than by the setting (2026-11-17).
