# Specification

## Problem

Setting up a new Mac by hand takes a day and produces a machine that is only
approximately like the last one. The applications are whichever ones came to
mind, the command-line tools are installed as they are missed, and the system
settings are re-derived from memory by clicking through System Settings.

Nothing records what the finished state was, so the next machine differs from
this one, and a setting changed by an OS upgrade is never noticed.

This repository is the record. Running it on a clean Mac produces the same
machine every time.

## Users

One developer, on Apple Silicon macOS, setting up a new machine or repairing an
existing one. The scripts are run interactively and attended, not unattended
from a provisioning system.

## Required behavior

### Bootstrap

- Install from a single command with nothing pre-installed except the OS.
- Install Homebrew when it is absent, and detect it when it is present --
  including in the same session that installed it, before any shell restart.
- Present a menu generated from the directory tree, so adding a script adds an
  entry with no registration step.

### Installation

- Install an application or tool only when it is absent. A second run of any
  entry installs nothing.
- Run without interactive prompts. Homebrew must not auto-update before each
  install, and must not ask for confirmation per package.
- Ask for the administrator password at most once per session, however many
  casks require it.
- Install the owner's dotfiles into the locations their applications read.

### System settings

- Apply the owner's preferences for Desktop and Dock, Finder, trackpad,
  Spotlight, keyboard shortcuts, firewall, power, and software update.
- Write every user preference as the logged-in user, so it takes effect on the
  account that is running the script.
- Read every preference back after writing it and report the ones that did not
  take. A preference that cannot be confirmed is reported as a failure, not
  counted as applied.
- Restart the affected service (`Finder`, `Dock`, `Spotlight`) so a change is
  visible without a logout, once per service per run rather than once per key.
- State plainly when a requested setting has no scriptable interface, rather
  than writing a key that silently does nothing.

### Failure behavior

- A failed install reports which package failed, and does not report success.
- A missing dotfile reports the path it looked for, rather than skipping
  silently.
- A script that cannot reach its target -- a missing directory, an unwritable
  preference domain -- creates what it can and reports what it cannot.

## Architecture and data flow

`start.sh` downloads the repository as a zip, unpacks it to
`~/Downloads/macsetup`, and hands control to `core/main.sh`, which exports the
shared paths and presents the menu. Each selection runs one script as a separate
`bash` process that sources `core/tabs/common-script.sh` for the Homebrew
environment and the install helpers.

System settings are data, not code. A settings script declares the preferences
it wants as pipe-delimited rows -- domain, key, type, value, owning service --
and hands them to `apply_settings` in `core/tabs/settings-lib.sh`. That function
is the only scalar `defaults write` in the repository. It writes each row, reads
it back as the logged-in user, reports every key that did not take, and restarts
each distinct owning service once. Verification is therefore a property of the
code path rather than something each script remembers to do, which is what
failed before. Four structural preferences -- dock contents, Spotlight
categories, symbolic hotkeys, and Finder tags -- are arrays or nested
dictionaries that a flat row cannot express; they stay as explicit code and
verify through the same shared helper.

Configuration lives in `dotfiles/` and is copied, not linked. The copy is
one-directional: editing a file in the home directory does not update this
repository.

State lives on the machine, in Homebrew's prefix and in macOS preference
domains. The repository holds no state of its own and keeps no record of what a
previous run did.

## Security and privacy

- No credential, license key, or serial number is committed.
- `sudo` is used only for system-scoped targets: absolute paths under
  `/Library/Preferences`, `pmset`, `socketfilterfw`, and `installer`. Never for
  a user preference domain.
- The administrator password is taken once per session and held by a keepalive
  for the life of that session only.
- `start.sh` executes code fetched over the network, and `office.sh` installs
  packages downloaded from third-party URLs. This is inherent to the design;
  the mitigation is that both are attended and the URLs are in version control
  where they can be reviewed.
- The firewall is enabled as part of the system settings, not left to default.

## Performance and compatibility

- Target: Apple Silicon, macOS 15 (Sequoia). Developed against 15.7.9 (24G830).
- Homebrew is expected at `/opt/homebrew`; `/usr/local` is accepted for Intel
  but is not tested.
- A multi-application install completes without per-package interaction. The
  measure is the number of prompts, not elapsed time: one password prompt and
  no confirmations.
- Preference keys are version-sensitive. A key verified on macOS 15 is not
  assumed to hold on another major version, and the version it was verified
  against is recorded.
- Writes target preference domains, not plist paths. Apple has warned that
  `defaults` will change to operate only on domains, which retires the
  `defaults write /Library/Preferences/...` form the Software Update settings
  currently use. That form is the repository's largest upgrade risk.

## Non-goals

- Unattended or fleet provisioning. There is no configuration profile, no MDM,
  and no CI. The scripts are run by a person at the machine.
- Uninstallation or rollback. There is no path from a configured machine back
  to a clean one.
- Bidirectional dotfile sync. Files are copied out of this repository only.
- Supporting macOS versions other than the current one, or Intel hardware.
- Backing up or migrating an existing machine's data.
- Managing application licences, sign-ins, or any state behind an account.

## Acceptance criteria

- On a clean Mac, the single bootstrap command reaches the menu with no manual
  step in between.
- Selecting three entries in succession, in one session, reports Homebrew as
  already installed each time and re-installs nothing.
- Installing the full cask list prompts for the password once and for
  confirmation never.
- Every entry is idempotent: running it twice changes nothing the second time.
- `~/.config/ghostty/config` exists and matches `dotfiles/` after the developer
  setup entry runs, and `ghostty +show-config` reports those values. Matching
  the file is not sufficient on its own: Ghostty loads the macOS Application
  Support directory after XDG and later files win, so a leftover file there
  overrides a correct XDG config with nothing reported.
- Every user preference the scripts write reads back correctly under
  `defaults read` as the logged-in user, and the System Settings UI agrees.
- No `sudo defaults write` against an unqualified domain remains in the
  repository.
- No scalar `defaults write` exists outside `core/tabs/settings-lib.sh`. A
  settings script declares rows; it does not write them.
- A deliberately misspelled key in a manifest makes the run report a failure,
  rather than exiting 0. This is covered by `bats test/`, because it is the
  failure mode the engine exists to catch.
- `bats test/` passes. It covers the engine's logic only -- the eight branches
  that decide what to write and whether it took, none of which need a Mac.
  Whether a key is the one macOS actually reads is not testable and stays a
  manual check against the System Settings UI.
- A tab script that fails returns to the menu with the install directory intact.
- `shellcheck -S warning` passes on every script.
- `ssh -T git@github.com` authenticates after the Git SSH entry runs.

## Unresolved questions

These block specific settings, not the repository as a whole. Each is tracked in
`TASKS.md`.

- **Finder sidebar.** Favorites are stored in
  `~/Library/Application Support/com.apple.sharedfilelist/` as an
  NSKeyedArchiver blob, with no `defaults` domain behind it. The tool is
  `sbedit`, not `mysides`, and as of 2026-09-17 that is settled on direct
  evidence rather than on deprecation: `mysides` is built on `LSSharedFileList`,
  and on macOS 15.7.9 that API returns an empty list for sidebar favorites
  without reporting an error, while an insert returns a valid-looking item ref
  and leaves the file byte-identical. A tool on that path reports success and
  does nothing. `sbedit` is tested on macOS 13, 15 and 26 and loads `.sfl3` or
  `.sfl4` according to OS version; macOS 26 moves the format to `.sfl4`, so this
  choice also decides whether the setting survives the next upgrade. Applying a
  change needs `killall sharedfilelistd`; `killall Finder` does nothing for it.
  Full Disk Access is a hard prerequisite, and not only to write: with the API
  returning nothing and the file TCC-refused, there is no channel left to read a
  sidebar entry back, so the read-back this specification requires cannot be
  satisfied without the grant. Undecided: take the `sbedit` dependency, or
  document the sidebar as manual.
- **Alfred.** Settings live in an `Alfred.alfredpreferences` bundle keyed by
  generated UUIDs, not in a preference domain; web search sits at
  `preferences/features/websearch/prefs.plist` and the global hotkey under
  General. Alfred caches its preferences in memory and rewrites the file on
  quit, so any edit must happen while Alfred is not running. Automating it
  requires a configured copy to work from. Undecided: read the owner's existing
  bundle, or commit the whole bundle to `dotfiles/`.
- **Browser extensions.** The repository offers four browsers -- Brave, Chrome,
  Firefox and Thorium -- and the mechanism differs per engine: Chromium uses an
  `ExtensionInstallForcelist` preference array, Firefox needs a `policies.json`
  inside the application bundle, and Brave serves the MV2 build of uBlock Origin
  from its own infrastructure rather than the Web Store. Undecided: which browser
  is the target. Evidence gathered 2026-09-17 points at Chrome -- it is the
  default `http` and `https` handler and the only one of the three with a profile
  directory, Brave and Firefox having never been launched -- but Chrome is also
  where the extension set is weakest: full uBlock Origin is gone after the
  Manifest V3 migration, leaving only uBlock Origin Lite, and Decentraleyes'
  effectiveness there is disputed. A second question sits behind the first: this
  Mac has no `/Library/Managed Preferences` and no configuration profiles, and
  whether an unmanaged user-domain write is honored as a mandatory Chrome policy
  is not yet established. If it is not, this becomes a `sudo`-scoped tab.
- **Display scaling.** "More Space" is a scaled display mode with no preference
  key. It needs the `displayplacer` formula plus a mode identifier specific to
  the panel, which does not transfer between machines. Undecided: accept a
  machine-specific value, or document as manual.
- **Software Update.** Four of the six keys are already set as required on this
  machine and are holding their values, so the domain is writable and not
  overridden. Two are not present at all: `AutomaticCheckEnabled` is absent from
  the plist, and the `com.apple.commerce` domain does not exist. Both must be
  created rather than flipped. The open risk is not MDM but `cfprefsd`, which
  caches a live domain and can write a stale copy back over a `defaults write`.
  Verification therefore has to survive a restart, not just a re-read.
- **Display Advanced and AutoFill.** Scope was given on 2026-09-17: disable
  everything in both panes. What blocks them now is enumeration, not the
  requirement -- "everything" is a state without a list, and neither pane's
  toggles can be read off this machine yet.
  The TCC half is now confirmed rather than assumed (2026-09-17): the Safari
  container plist exists at 5.3K with mode `-rw-------` owned by the running
  user, and reading it still returns `NSCocoaErrorDomain Code=257` /
  `NSPOSIXErrorDomain Code=1`. Owning a readable-by-mode file and being refused
  anyway is TCC, so Full Disk Access is a hard prerequisite -- the same one the
  Finder sidebar favorites need. `com.apple.universalcontrol` does not exist as a
  domain at all, so the Display Advanced keys cannot be read off this machine
  until a toggle is changed in the GUI and diffed.
