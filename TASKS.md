# Tasks

Current work, its validation status, and the preference keys verified on this
machine. Phase order and exit criteria are in `ROADMAP.md`; requirements are in
`SPEC.md`.

## Open

- [ ] Take the sudo password before installing Homebrew.
  - **Known gap (owner, 2026-11-17):** the owner will run this separately on a
    Mac without Homebrew. Until then it is unproven that the password taken
    at startup carries through to the installer.
  - **Status:** fixed 2026-11-16, not yet validated on a Mac without Homebrew.
    `checkPackageManager` calls `sudo_keepalive` before running the installer,
    and exits 1 without running it when sudo is refused.
  - **Cause:** `checkPackageManager` in `core/tabs/common-script.sh` runs the
    Homebrew installer with `NONINTERACTIVE=1`. In that mode the installer adds
    `-n` to every `sudo`, which fails instead of prompting, so credentials must
    already be cached. Found by the owner on the new install, where the run
    only worked after a manual `sudo -v`.
  - **Tests:** two cases in `test/common-script.bats` stub `brew_path`,
    `sudo_keepalive` and `curl` and use a scratch `HOME`. They prove the
    password is taken before the installer runs, and that a refused password
    means the installer never runs. Both failed before the fix. `sudo -v`
    reads from the terminal, not stdin, so it cannot consume the menu's next
    choice.
  - **Acceptance criteria:** on a Mac without Homebrew, the first run asks for
    the password once and installs Homebrew without a manual `sudo -v`.
- [ ] Measure the cask password-prompt count (Phase 1 exit criterion).
  - **Status:** not measured. `--no-ask` is a real flag on Homebrew 7.0.3 and
    the keepalive holds one timestamp per session, but counting prompts needs a
    real cask install under `sudo`. The fresh-Mac run above is the natural
    opportunity.
  - **Acceptance criteria:** installing the full cask list prompts for the
    password once and never for confirmation.

## Owner decisions

Recorded 2026-11-16 and 2026-11-17, after testing the repository on a fresh
macOS 27.2.1 install.

- Every settings area runs from one Optimize Settings entry.
- Bluetooth stays a manual toggle; only its menu bar icon is hidden.
- FileVault is set by hand and stays out of the repository.
- Battery: only the four options in Battery > Options.
- Firewall stealth mode is on.
- Apple Intelligence and AI features: disable everything, and remove whatever
  can be removed.
- The menu reports whether the terminal has Full Disk Access.
- The terminal is never granted Full Disk Access, not even for one session.
  A setting that needs it is set by hand and listed under Set by hand in
  `README.md`.
- `sbedit` is not used for the Finder sidebar.
- Browser extensions are installed by hand.
- Weather in the menu bar is left alone; a new install keeps it hidden.
- Software Update does not write `AutomaticCheckEnabled`.

## Completed

Each task was verified on a real Mac before it moved here. The investigation
behind each one is in git history, in comments next to the code, and, where it
generalizes, in `AGENTS.md`.

### macOS 27 system optimization, 2026-11-16 to 2026-11-17

- [x] Consolidate the settings tabs into one Optimize Settings entry. The areas
  are modules in `core/settings/`, run in a fixed order with Spotlight before
  Alfred, and end in one report. Validated live by the owner.
- [x] Make the sudo session temporary. The menu takes the password at startup
  and runs `sudo -k` on every exit. A Full Disk Access grant, if present, is
  revoked by bundle identifier. Validated live by the owner.
- [x] Fix `dev-setup.sh` silently installing none of its formulas. The removed
  `tldr` formula failed the whole batch, so it became `tlrc`, and a failed
  batch now retries one package at a time and names only the failures.
- [x] ~~Disable Bluetooth.~~ Withdrawn by the owner: Bluetooth stays a manual
  toggle.
- [x] Make the `[[ ]]` assertions in `test/settings-lib.bats` able to fail.
  Under `/bin/bash` 3.2, 30 of 43 passed whatever they compared. Each now ends
  in `|| false`, and every asserted-string mutant fails.
- [x] Turn off both Universal Control toggles in Displays > Advanced:
  `-currentHost com.apple.universalcontrol Disable` and `DisableMagicEdges`,
  written by `display.sh` before More Space.
- [x] Re-baseline the settings against macOS 27. Every manifest row and
  structural check reads back on 27.2.1.
- [x] ~~Install browser extensions.~~ Withdrawn by the owner: installed by
  hand.
- [x] Decide whether a `gitconfig` CLI is wanted: no. `gitignore` covers the
  need, and npm's `gitconfig` is a library with no command.
- [x] ~~Disable Tips, set the Finder sidebar and tags, turn off AutoFill &
  Passwords.~~ Each is stored where Full Disk Access is required, so they
  moved to Set by hand in `README.md`. The readable Finder tag keys remain in
  `fix-finder.sh`.
- [x] Fix the Alfred cmd+space hotkey. The step writes this Mac's
  `local/<id>/hotkey/prefs.plist`; it reads cmd+space after a restart, and
  the owner confirmed it works.
- [x] Fix reduce motion. `reduceMotion` reads 1 after a restart. On a Mac
  without Full Disk Access it is a manual step.
- [x] Disable everything in Spotlight. Fifteen hidden categories and 83 file
  types read back after a restart. The 27.2.1 pane has no "content from Apple
  partners" toggle, and Results from Clipboard is a manual step.
- [x] Disable all Siri suggestions. "Show Siri Suggestions in application" is
  off for all eleven apps after a restart. The "Learn from this application"
  checkbox named in the pane's strings does not appear on this Mac.
- [x] Disable Apple Intelligence and AI features. Everything reads off, no
  third-party AI app remains in `/Applications`, and the Copilot shim is
  removed. System apps live on the sealed volume, so they are disabled rather
  than removed. **Residual risk:** whether Microsoft AutoUpdate restores the
  shim is unknown, and excluding it from a fresh Office install needs its
  choice identifier from `installer -showChoicesXML`.
- [x] Turn off four Battery options. `pmset -b lessbright 0`, `pmset -c sleep
  1` and the video streaming key read back after a restart, and the owner
  checked the pane.
- [x] Hide every system menu bar item. All Control Center items, the Spotlight
  icon, the input menu, Siri AI and the Time Machine extra stay hidden after a
  restart. Third-party app icons are a manual step.
- [x] Set the wallpaper to solid black on the display and every Space; it
  survives a restart.
- [x] Harden the system. Firewall and stealth mode are on, a password is
  required immediately, and AirPlay Receiver and wake for network access are
  off, all read back after a restart.
- [x] Add `security.sh`. The firewall, `womp 0` and five Software Update keys
  read back after a restart.

### Menu and installer

- [x] Stop a failing tab script from deleting the install directory. The tab
  call in `core/main.sh` is guarded, so a non-zero exit no longer aborts the
  menu into the cleanup trap.
- [x] Stop an empty category directory from deleting the install directory.
  Under bash 3.2 with `set -u`, expanding an empty array is an
  unbound-variable error, so arrays are counted before they are expanded.
- [x] Stop `clear` from aborting the menu when the terminal cannot be driven.
  `clear` exits 1 with `TERM` unset or `dumb`, so its failure is ignored.
- [x] Keep the install directory when the menu exits abnormally. The cleanup
  trap deletes it only on exit status 0.
- [x] Fix `SC2155` in `start.sh`. `export TEMP_DIR=$(mktemp -d)` hid a failed
  `mktemp`, which aimed the download at the filesystem root.

### Homebrew

- [x] Bring `common-script.sh` under shellcheck. Its `#!/bin/zsh -e` shebang
  made shellcheck refuse the file (`SC1071`), so it now declares bash.
- [x] Resolve Homebrew without a sourced profile. Tabs never read
  `~/.zprofile`, so `brew` is located by path instead of by `command -v`.
- [x] Make Homebrew non-interactive and batch the installs. The `HOMEBREW_NO_*`
  exports, `sudo_keepalive` and one `brew install` per batch replaced
  per-package prompts and processes.
- [x] Fix five `printf` calls that printed their own placeholder. The `%s` and
  `%d` were in the argument instead of the format string, which garbled every
  error from `get_file_from_web` and `office.sh`.

### Preference engine

- [x] Build the preference engine. `apply_settings` in
  `core/tabs/settings-lib.sh` writes `domain | key | type | value | owner`
  rows, reads each back, and restarts each owner once.
- [x] Add the `bats` suite for the engine. `test/settings-lib.bats` stubs
  `defaults`, `killall` and `sudo`, so it changes nothing on the machine.
- [x] Reject a manifest row with an empty value. `defaults read` returns an
  empty string for both an empty and a missing key, so such a row could never
  be verified.
- [x] Give the engine a first-class `-currentHost` scope. Some keys exist only
  in the ByHost plist, and a row without the prefix wrote a key nothing reads.

### Settings modules

These modules now live in `core/settings/` and run from Optimize Settings.

- [x] Convert the three existing settings scripts to manifests. This removed
  the `sudo defaults write` calls, which had been writing root's preferences
  instead of the logged-in user's.
- [x] Rewrite `fix-finder.sh` for the full settings list: 19 manifest rows plus
  `FavoriteTagNames` as explicit code.
- [x] Add `desktop-dock.sh`: ten rows plus `persistent-apps`, written before the
  engine's single Dock restart so the new tile appears.
- [x] Add `input.sh` for the trackpad. Tap to click is four rows across the
  plain and `-currentHost` scopes.
- [x] Add `display.sh`. It picks the widest scaled mode from
  `displayplacer list` at run time, so nothing is hardcoded per panel.
- [x] Add `spotlight.sh`. Both settings are structural, and "every category is
  off" needed the engine's `absent` mode.
- [x] Add `alfred.sh`. It quits Alfred before writing, because Alfred rewrites
  its bundle on exit and would overwrite the changes.
- [x] Fix the Trash and log cleanup in `system-cleanup.sh`. The old glob skipped
  dotfiles and `find` failed silently under TCC; a denial is now reported with
  its remedy.
- [x] Remove `set -e` from `zsh-setup.sh`. One unavailable formula ended the tab
  and skipped the whole shell configuration.

### Development environment

- [x] Add `core/tabs/system/git-ssh.sh`. It creates an ed25519 key, configures
  the agent and `~/.ssh/config` with a port 443 fallback where port 22 is
  refused, uploads the key, and verifies with `ssh -T`. Validated live on
  2026-09-20.
- [x] Fix the `dev-setup.sh` shebang and array use. `#!/usr/bin/env/sh -e`
  named a path that cannot exist.
- [x] Fix `nvm` and `bun` detection, and stop sourcing `~/.zshrc`. Both
  reinstalled on every run, because nvm is a shell function and bun is not on
  a tab's `PATH`.
- [x] Fix the Ghostty config install. Three defects were fixed, and the
  Application Support file that silently overrode the XDG config is moved
  aside.
- [x] ~~Add `global-packages.sh`.~~ Superseded: folded into `dev-setup.sh` as
  `install_global_packages`, since it needs the bun that `dev-setup.sh`
  installs.
- [x] Drop the unconditional `find ~ -name .DS_Store -delete`. Reversed at the
  owner's request and restored as `clear_ds_store`, because a folder's
  `.DS_Store` overrides the list view defaults.

### Repository

- [x] Bring the whole repository under the `shfmt` gate. The gate is
  `shfmt -i 4`; adding `-ci` would rewrite every `case` statement.
- [x] Reconcile `ROADMAP.md` with what is built.
- [x] Audit the live machine against every manifest row, read-only.

### Presentation, 2026-09-19

- [x] Rewrite the menu in `core/main.sh`. Entries show a label and a
  description under a breadcrumb header, with `b` and `q` for back and quit,
  and color only on a terminal that supports it.
- [x] Add menu metadata to every tab. Optional `# menu:` and `# desc:` lines and
  `.menu` files name each entry, falling back to the title-cased file name.
- [x] Thin the comments in the tab scripts. Investigation notes were removed,
  and the findings that generalize moved to `AGENTS.md`.

## Completion rule

Move a task to Completed only after its acceptance criteria and validation pass
on a real Mac.

`defaults write` exits 0 for a key nothing reads, including a misspelled one,
so "the script ran" is not evidence. Read the value back as the logged-in user
and confirm System Settings agrees. Record skipped validation and residual risk
instead of marking unverified work done.

## Appendix: verified preference keys

Read from macOS 15.7.9 (24G830) on arm64 on 2026-09-13, and read back on macOS
27.2.1 (26B131) on 2026-11-17. These are observed values, not recalled ones.
A key marked *unset* was absent and has to be written explicitly.

### Desktop and Dock

| Setting | Key | Value |
| --- | --- | --- |
| Click wallpaper to reveal desktop, only in Stage Manager | `com.apple.WindowManager EnableStandardClickToShowDesktop` | `false` |
| Show items on desktop, off | `com.apple.WindowManager StandardHideDesktopIcons` | `true` |
| Show items in Stage Manager, off | `com.apple.WindowManager HideDesktop` | `true` |
| Widgets on desktop, off | `com.apple.WindowManager StandardHideWidgets` | `true` |
| Widgets in Stage Manager, off | `com.apple.WindowManager StageManagerHideWidgets` | `true` |
| Dock size, minimum | `com.apple.dock tilesize` | `16` |
| Autohide | `com.apple.dock autohide` | `true` |
| Position | `com.apple.dock orientation` | `left` |
| Animate opening applications, off | `com.apple.dock launchanim` | `false` |
| Suggested and recent apps, off | `com.apple.dock show-recents` | `false` |
| Dock contents | `com.apple.dock persistent-apps` | cleared, then System Settings re-added at `file:///System/Applications/System%20Settings.app/` |

### Finder

| Setting | Key | Value |
| --- | --- | --- |
| Hard disks on desktop | `com.apple.finder ShowHardDrivesOnDesktop` | `false` |
| External disks on desktop | `com.apple.finder ShowExternalHardDrivesOnDesktop` | `false` |
| Removable media on desktop | `com.apple.finder ShowRemovableMediaOnDesktop` | `false` |
| Servers on desktop | `com.apple.finder ShowMountedServersOnDesktop` | `false` (unset) |
| New windows show Home | `com.apple.finder NewWindowTarget` | `PfHm`, with `NewWindowTargetPath` = `file://$HOME/` |
| Open folders in tabs | `com.apple.finder FinderSpawnTab` | `true` |
| List view | `com.apple.finder FXPreferredViewStyle` | `Nlsv` |
| Show all extensions | `NSGlobalDomain AppleShowAllExtensions` | `true` |
| No extension-change warning | `com.apple.finder FXEnableExtensionChangeWarning` | `false` |
| Search current folder | `com.apple.finder FXDefaultSearchScope` | `SCcf` |
| Path bar | `com.apple.finder ShowPathbar` | `true` |
| Status bar | `com.apple.finder ShowStatusBar` | `true` |
| Tags | `com.apple.finder ShowRecentTags` | `false`, with `FavoriteTagNames` emptied |

### Trackpad

| Setting | Key | Value |
| --- | --- | --- |
| Tap to click | `com.apple.AppleMultitouchTrackpad Clicking` | `true`, mirrored to `com.apple.driver.AppleBluetoothMultitouch.trackpad`, `NSGlobalDomain com.apple.mouse.tapBehavior` = `1`, and its `-currentHost` copy |
| Natural scrolling, off | `NSGlobalDomain com.apple.swipescrolldirection` | `false` |

`com.apple.mouse.tapBehavior` is per-host. On this machine it exists only in
`~/Library/Preferences/ByHost/.GlobalPreferences.<hardware-uuid>.plist`:
`defaults read NSGlobalDomain com.apple.mouse.tapBehavior` reports it missing,
while `defaults -currentHost read` returns `1`. The per-host copy is the one
macOS wrote when the checkbox was ticked, so it is authoritative, and tap to
click is four keys rather than three (found 2026-09-15).

### Spotlight

`com.apple.Spotlight orderedItems`, all 21 categories with `enabled = 0`:

`APPLICATIONS`, `MENU_EXPRESSION`, `CONTACT`, `MENU_CONVERSION`,
`MENU_DEFINITION`, `DOCUMENTS`, `EVENT_TODO`, `DIRECTORIES`, `FONTS`, `IMAGES`,
`MESSAGES`, `MOVIES`, `MUSIC`, `MENU_OTHER`, `PDF`, `PRESENTATIONS`,
`MENU_SPOTLIGHT_SUGGESTIONS`, `SPREADSHEETS`, `SYSTEM_PREFS`, `TIPS`,
`BOOKMARKS`.

### Software Update

Domain `/Library/Preferences/com.apple.SoftwareUpdate`, written with `sudo`
because the target is a system path. Everything is off except system data
files and security updates, which is two keys, not one: setting only one leaves
the checkbox in a mixed state that reads as enabled while half the behavior is
off.

This is the path-based `defaults` form, which Apple has warned will be retired.
It is the most upgrade-fragile part of the repository; verify it after every
major macOS update.

| Automatic Updates row | Key | Value | Observed on 15.7.9 |
| --- | --- | --- | --- |
| Download new updates when available | `AutomaticDownload` | `false` | already `0` |
| Install macOS updates | `AutomaticallyInstallMacOSUpdates` | `false` | already `0` |
| Install application updates from the App Store | `com.apple.commerce AutoUpdate` | `false` | domain did not exist; created |
| Install system data files and security updates | `CriticalUpdateInstall` | `true` | already `1` |
| (same row, second key) | `ConfigDataInstall` | `true` | already `1` |

On 27.2.1 the pane has no check-for-updates toggle, only a Check for Updates
button, and `softwareupdate --schedule` reports automatic checking on. macOS
deletes `AutomaticCheckEnabled` on its next scan, so it is no longer written.
The other five keys hold after a restart.

### Keyboard shortcuts

`com.apple.symbolichotkeys AppleSymbolicHotKeys` entries `64` (show Spotlight
search) and `65` (show Finder search window), each `enabled = false` with the
existing `value` dictionary preserved, followed by `activateSettings -u`.

### Added on macOS 27.2.1

Each found by the owner changing the pane while preferences were compared
before and after, 2026-11-16 to 2026-11-17.

| Setting | Key | Value |
| --- | --- | --- |
| Spotlight categories and Files subcategories hidden | `com.apple.Spotlight EnabledPreferenceRules` | the fifteen rules in `spotlight.sh` |
| Spotlight file types hidden | `com.apple.Spotlight DisabledUTTypes` | the 83 types in `spotlight.sh` |
| Help Apple Improve Search, off | `com.apple.assistant.support "Search Queries Data Sharing Status"` | `2` |
| Siri suggestions, off per app | `com.apple.suggestions AppCanShowSiriSuggestionsBlacklist` | the eleven bundle identifiers in `siri.sh` |
| Apple Intelligence, off | `com.apple.CloudSubscriptionFeatures.optIn 545129924` | `false` |
| Slightly dim the display on battery, off | `pmset -b lessbright` | `0` |
| Prevent sleeping on power adapter when the display is off, off | `pmset -c sleep` | `1` |
| Optimize video streaming on battery, off | `/Library/Preferences/.GlobalPreferences com.apple.coremedia.optimizeVideoStreamingOnBattery` | `false` |
| Menu bar items, Don't Show | `-currentHost com.apple.controlcenter <item>` for AirDrop, Battery, Bluetooth, Display, FocusModes, KeyboardBrightness, NowPlaying, ScreenMirroring, Sound, Spotlight, TimeMachine, Timer, UserSwitcher, WiFi | `8` (`2` is shown) |
| Spotlight menu bar icon, hidden | `-currentHost com.apple.Spotlight MenuItemHidden` | `true` |
| Input menu, hidden | `com.apple.TextInputMenu visible` and `com.apple.TextInputMenuAgent "NSStatusItem VisibleCC Item-0"` | `false` |
| Siri AI menu bar item, hidden | `com.apple.campo "NSStatusItem VisibleCC Item-0"` | deleted |
| Time Machine menu extra, hidden | `com.apple.systemuiserver "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine"`, and `TimeMachine.menu` in `menuExtras` | deleted |
| Control Gallery suggestions, off | `-currentHost com.apple.controlcenter ShowSuggestions` | `false` |
| AirPlay Receiver, off | `-currentHost com.apple.controlcenter AirplayReceiverEnabled` | `false` |
| Universal Control, off | `-currentHost com.apple.universalcontrol Disable` and `DisableMagicEdges` | `true` |
| Password after sleep or screen saver, immediately | `sysadminctl -screenLock` | `immediate` |
| Wallpaper, solid black | `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` | a `systemColor` `black` choice |
