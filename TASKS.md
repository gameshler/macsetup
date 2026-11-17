# Tasks

## Current phase: System and security

No open tasks.

## Queued: macOS 27 system optimization

Requested by the owner on 2026-11-16 after a fresh install of macOS 27.2.1
(26B131). The goal is a Mac optimized for performance and security. Every key
in the appendix was verified on macOS 15.7.9 and none of it is verified on 27
until it is read back here. Observations below were taken read-only on
2026-11-16; nothing was written.

Owner decisions, 2026-11-16, after testing the repository on the new install:

- Consolidating the settings tabs into one entry is approved.
- Bluetooth stays a manual toggle. It is not to be forced off on every run.
- Battery: only the four options named in the battery task.
- FileVault is done by hand and stays out of the repository.
- Firewall stealth mode goes on.
- Apple Intelligence and AI features: disable everything, and remove whatever
  can be removed.
- The repository checks whether the terminal has Full Disk Access.
- 2026-11-17: Full Disk Access is not granted to the terminal, not even for
  a session, because the owner judges it a risk. A setting that needs it is
  set by hand and listed under Set by hand in `README.md`.

- [ ] Take the sudo password before installing Homebrew.
  - **Known gap, owner, 2026-11-17:** the owner runs this separately on a
    Mac without Homebrew; until then it is unproven that the menu's sudo
    prompt at startup carries through to the installer.
  - **Status: fixed 2026-11-16, not yet validated on a Mac without
    Homebrew.** `checkPackageManager` now calls `sudo_keepalive` before the
    installer and exits 1 without running it when sudo is refused. Do not
    mark this complete until the next fresh install shows a single password
    prompt and Homebrew installing with no manual `sudo -v`.
  - Two tests in `test/common-script.bats` drive the install branch with
    `brew_path`, `sudo_keepalive` and `curl` stubbed as functions and `HOME`
    in a scratch directory: the password is taken before the installer
    runs, and a refused password means the installer never runs. Both were
    red before the change. `bats test/` 52 of 52.
  - `sudo -v` reads the password from the terminal, not stdin, so asking at
    source time cannot swallow the menu's next choice.
  - Found by the owner on the new install: with no Homebrew present, the run
    only worked after a manual `sudo -v` first.
  - Cause: `checkPackageManager` in `core/tabs/common-script.sh` runs the
    Homebrew installer with `NONINTERACTIVE=1`. Confirmed in the installer's
    source on 2026-11-16: in that mode it adds `-n` to every `sudo`, which
    fails instead of prompting, so it needs credentials already cached.
    `sudo_keepalive` exists in the same file but is not called on that path.
  - Acceptance criteria: on a Mac without Homebrew, the first run asks for the
    password once and installs Homebrew without a manual `sudo -v`.

## Next phase: Development environment

No open tasks.

## Blocked on a decision

No open tasks.

## Completed

Each task was verified on a real Mac before being moved here. The investigation
behind them is in git history, in comments next to the code, and in `AGENTS.md`
where it generalises.

### macOS 27 system optimization, 2026-11-16

- [x] Consolidate the settings tabs into one Optimize Settings entry. The nine
  areas are modules in `core/settings/`, run in a fixed order with Spotlight
  before Alfred, behind one Full Disk Access announcement and one report;
  validated live by the owner.
- [x] Make Full Disk Access and the sudo password temporary for the session.
  The menu takes both at startup, and on every exit revokes the terminal's
  grant by app id and runs `sudo -k`; validated live by the owner.
- [x] Fix `dev-setup.sh` silently installing none of its formulas. The removed
  `tldr` formula failed the whole batch, so it became `tlrc`, and a failed
  batch now retries one package at a time and names only the failures.
- [x] ~~Disable Bluetooth.~~ Withdrawn at the owner's request: Bluetooth stays
  a manual toggle.
- [x] Make the `[[ ]]` assertions in `test/settings-lib.bats` able to fail.
  Under `/bin/bash` 3.2, 30 of 43 passed whatever they compared; each now ends
  in `|| false`, and every asserted-string mutant now fails, 2026-11-17.
- [x] Turn off both Universal Control toggles in Displays > Advanced. The
  owner's toggle showed `-currentHost com.apple.universalcontrol Disable` and
  `DisableMagicEdges`, both true; `display.sh` writes them before More Space
  and read them back live, 2026-11-17.
- [x] Re-baseline the settings against macOS 27. All 75 manifest rows and the
  structural checks read back on 27.2.1, and `SPEC.md` and the appendix name
  it as the verified version, 2026-11-17.
- [x] ~~Browser extensions: Privacy Badger, Decentraleyes, uBlock Origin.~~
  Withdrawn at the owner's request, 2026-11-17: installed by hand.
- [x] Confirm whether a `gitconfig` CLI is wanted: no. `gitignore` does the
  job and npm's `gitconfig` is a library with no command; closed by the owner,
  2026-11-17.
- [x] ~~Disable Tips, set the Finder sidebar and tags, turn off General >
  AutoFill and Passwords.~~ Each is stored only where Full Disk Access is
  needed, which the owner does not grant, so they moved to Set by hand in
  `README.md`, 2026-11-17. The readable Finder tag keys stay in `fix-finder.sh`.
- [x] Fix the Alfred cmd+space hotkey not applying. The step writes this
  Mac's `local/<id>/hotkey/prefs.plist`; it reads cmd+space after a restart
  and the owner confirmed it works, 2026-11-17.
- [x] Fix reduce motion not applying. `reduceMotion` reads 1 after a restart;
  on a Mac without Full Disk Access it is under Set by hand in `README.md`,
  2026-11-17.
- [x] Disable everything in Spotlight. 15 hidden categories, the Files
  subcategories and 83 file types read back after a restart; the pane on
  27.2.1 has no "content from Apple partners" toggle, and Results from
  Clipboard is under Set by hand, 2026-11-17.
- [x] Disable Apple Intelligence and AI features. Everything reads off, no
  third-party AI app is in `/Applications`, and the Copilot shim is gone.
  The system apps are on the sealed volume and are disabled, not removed.
  Not proven: whether Microsoft AutoUpdate restores the Office shim, whose
  choice id still needs `installer -showChoicesXML`, 2026-11-17.
- [x] Turn off four Battery options. `pmset -b lessbright 0`, `pmset -c sleep
  1` and the video streaming key read back after a restart; owner checked the
  pane, 2026-11-17.
- [x] Hide every system menu bar item. All Control Center items, Spotlight,
  the input menu, Siri AI and the Time Machine extra stay hidden after a
  restart. Weather is left alone: a new install keeps it out of the menu bar,
  and its icon comes from its own launchd agent. Third-party apps are under
  Set by hand, 2026-11-17.
- [x] Set the wallpaper to solid black. It reads black on the display and
  every Space after a restart, 2026-11-17.
- [x] Harden the rest of the system. Firewall and stealth mode on, password
  required immediately, AirPlay Receiver and wake for network access off, all
  read back after a restart, 2026-11-17.
- [x] Add `core/tabs/system/security.sh`. Firewall on, wake for network
  access 0 and five Software Update keys read back after a restart.
  `AutomaticCheckEnabled` was dropped at the owner's request: macOS 27 has no
  check toggle, keeps checking, and deletes the key on its next scan,
  2026-11-17.
- [x] Disable all Siri suggestions. "Show Siri Suggestions in application" is
  off for all eleven apps after a restart. The "Learn from this application"
  box the pane's strings name does not appear on this Mac, so there is
  nothing to set, 2026-11-17.

### Menu and installer

- [x] Stop a failing tab script from deleting the install directory. The tab
  call in `core/main.sh` is guarded, so a non-zero exit no longer aborts the
  menu into the cleanup trap.
- [x] Stop an empty category directory from deleting the install directory.
  Under bash 3.2 and `set -u` an empty array expansion is an unbound-variable
  error, so arrays are counted before they are expanded.
- [x] Stop `clear` from aborting the menu when the terminal cannot be driven.
  `clear` exits 1 with `TERM` unset or `dumb`, so its failure is swallowed.
- [x] Keep the install directory when the menu exits abnormally. The cleanup
  trap deletes it only on exit status 0.
- [x] Fix `SC2155` on `start.sh:8`. `export TEMP_DIR=$(mktemp -d)` hid a failed
  `mktemp`, which aimed the download at the filesystem root.

### Homebrew

- [x] Bring `common-script.sh` under shellcheck. Its `#!/bin/zsh -e` shebang
  made shellcheck refuse the file (`SC1071`), so it now declares bash.
- [x] Resolve Homebrew without depending on a sourced profile. Tabs never read
  `~/.zprofile`, so brew is located by path instead of by `command -v`.
- [x] Make Homebrew non-interactive and batch the installs. The `HOMEBREW_NO_*`
  exports, `sudo_keepalive` and one `brew install` per batch replaced
  per-package prompts and processes.
- [x] Fix the five `printf` calls that print their own placeholder. The `%s`
  and `%d` sat in the argument rather than the format, garbling every error in
  `get_file_from_web` and `office.sh`.

### Preference engine

- [x] Build the preference engine. `apply_settings` in
  `core/tabs/settings-lib.sh` writes `domain | key | type | value | owner`
  rows, reads each one back, and restarts each owner once.
- [x] Add the `bats` suite for the engine. `test/settings-lib.bats` stubs
  `defaults`, `killall` and `sudo` on `PATH`, so it changes nothing on the
  machine running it.
- [x] Reject a manifest row with an empty value column. `defaults read` returns
  an empty string for both an empty and a missing key, so such a row could
  never be verified.
- [x] Give the engine a first-class `-currentHost` scope. Some keys exist only
  in the ByHost plist, and a row without the prefix wrote a key nothing reads.

### System tabs

These modules now live in `core/settings/` and run from Optimize Settings.

- [x] Convert the three existing settings scripts to manifests. This removed
  the `sudo defaults write` calls, which had been writing root's preferences
  instead of the logged-in user's.
- [x] Rewrite `fix-finder.sh` for the full settings list. It has 19 manifest
  rows plus `FavoriteTagNames` as explicit code.
- [x] Add `desktop-dock.sh`. Ten rows plus `persistent-apps`, written before the
  engine's single Dock restart so the new tile appears.
- [x] Add `input.sh` for the trackpad. Tap to click is four rows across the
  plain and `-currentHost` scopes.
- [x] Add `display.sh`. It picks the widest scaled mode from
  `displayplacer list` at runtime, so nothing is hardcoded per panel.
- [x] Add `spotlight.sh`. Both settings are structural, and "every category is
  off" needed the engine's new `absent` mode.
- [x] Add `alfred.sh`. It quits Alfred before writing, because Alfred rewrites
  its bundle on exit and would overwrite the changes.
- [x] Fix the Trash and log cleanup in `system-cleanup.sh`. The old glob skipped
  dotfiles and the `find` failed silently under TCC; a denial is now reported
  with the Full Disk Access remedy.
- [x] Remove the `set -e` from `zsh-setup.sh`. One unavailable formula ended
  the tab and skipped the whole shell configuration.

### Development environment

- [x] Add `core/tabs/system/git-ssh.sh`. It creates an ed25519 key, configures
  the agent and `~/.ssh/config` with a port 443 fallback where github.com:22 is
  refused, uploads the key and verifies with `ssh -T`; validated live
  2026-09-20.
- [x] Fix the `dev-setup.sh` shebang and array use. `#!/usr/bin/env/sh -e`
  named a path that cannot exist.
- [x] Fix `nvm` and `bun` detection, and stop sourcing `~/.zshrc`. Both
  reinstalled on every run, because nvm is a shell function and bun is not on a
  tab's `PATH`.
- [x] Fix Ghostty config installation. Three defects were fixed, and the
  Application Support file that silently overrode the XDG config is moved
  aside.
- [x] Add `core/tabs/system/global-packages.sh`. **Superseded:** folded into
  `dev-setup.sh` as `install_global_packages`, since it needed the bun that
  `dev-setup.sh` installs.
- [x] Drop the unconditional `find ~ -name .DS_Store -delete`. **Reversed at the
  owner's request:** restored as `clear_ds_store`, because a folder's
  `.DS_Store` overrides the list view defaults.

### Repository

- [x] Bring the whole repository under the `shfmt` gate. The gate is
  `shfmt -i 4`; adding `-ci` would rewrite every `case` in the repository.
- [x] Reconcile `ROADMAP.md` against what is actually built. All six phases
  read Planned, Blocked or Deferred, including three that were finished.
- [x] Audit the live machine against every manifest row, read-only. Every row
  was read back without writing anything.

### Presentation and readability, 2026-09-19

- [x] Rewrite the menu in `core/main.sh`. Entries show a label and a
  description under a breadcrumb header, with `b` and `q` for back and quit,
  and colour only on a terminal that supports it.
- [x] Add menu metadata to every tab. Optional `# menu:` and `# desc:` lines and
  `.menu` files name each entry, falling back to the title-cased filename.
- [x] Thin the comments across the tab scripts. Investigation narratives were
  removed, and the findings that generalise moved to `AGENTS.md`.

## Completion rule

Move a task to Completed only after its acceptance criteria and validation
pass on a real Mac.

`defaults write` exits 0 for a key nothing reads, including a misspelled one, so
"the script ran" is not evidence. Read the value back as the logged-in user and
confirm the UI agrees. Record skipped validation and residual risk instead of
marking unverified work done.

## Appendix: preference keys verified on this machine

Read directly from macOS 15.7.9 (24G830), arm64, on 2026-09-13, and read back
again on macOS 27.2.1 (26B131) on 2026-11-17: all 75 manifest rows in
`core/settings/` and every structural check below hold on 27.2.1. These are
observed values, not recalled ones. Keys marked *unset* are absent from the
current preferences and need the documented value written explicitly.

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
| Tap to click | `com.apple.AppleMultitouchTrackpad Clicking` | `true`, mirrored to `com.apple.driver.AppleBluetoothMultitouch.trackpad` and `NSGlobalDomain com.apple.mouse.tapBehavior` = `1` |

Correction to the tap-to-click row, found on 2026-09-15 while implementing it.
`com.apple.mouse.tapBehavior` is **per-host**. On this machine it exists only in
`~/Library/Preferences/ByHost/.GlobalPreferences.<hardware-uuid>.plist`;
`defaults read NSGlobalDomain com.apple.mouse.tapBehavior` reports the pair does
not exist, while `defaults -currentHost read` returns `1`. That per-host copy is
the one macOS wrote when the checkbox was ticked in System Settings, so it is the
authoritative one. Tap to click is therefore **four** keys, not three: the two
trackpad domains, the plain global copy, and the per-host copy.
| Natural scrolling, off | `NSGlobalDomain com.apple.swipescrolldirection` | `false` |

### Spotlight

`com.apple.Spotlight orderedItems`, all 21 categories with `enabled = 0`:

`APPLICATIONS`, `MENU_EXPRESSION`, `CONTACT`, `MENU_CONVERSION`,
`MENU_DEFINITION`, `DOCUMENTS`, `EVENT_TODO`, `DIRECTORIES`, `FONTS`, `IMAGES`,
`MESSAGES`, `MOVIES`, `MUSIC`, `MENU_OTHER`, `PDF`, `PRESENTATIONS`,
`MENU_SPOTLIGHT_SUGGESTIONS`, `SPREADSHEETS`, `SYSTEM_PREFS`, `TIPS`,
`BOOKMARKS`.

### Software Update

Domain `/Library/Preferences/com.apple.SoftwareUpdate`, written with `sudo`
because the target is a system path. The requirement is everything off except
Security Responses and system files, which is two keys, not one.

Upgrade risk: this is the path-based `defaults` form, which Apple has warned
will be retired when `defaults` moves to domains only. It is the most
upgrade-fragile part of the plan. Verify after every macOS major update.

| Automatic Updates row | Key | Value | Observed on 15.7.9 |
| --- | --- | --- | --- |
| Check for updates | `AutomaticCheckEnabled` | `false` | **absent** -- must be created |
| Download new updates when available | `AutomaticDownload` | `false` | already `0` |
| Install macOS updates | `AutomaticallyInstallMacOSUpdates` | `false` | already `0` |
| Install application updates from the App Store | `com.apple.commerce AutoUpdate` | `false` | **domain does not exist** -- must be created |
| Install Security Responses and system files | `CriticalUpdateInstall` | `true` | already `1` |
| (same row, second key) | `ConfigDataInstall` | `true` | already `1` |

On 27.2.1 the pane no longer has a check toggle, only a Check for Updates
button, and `softwareupdate --schedule` still reports automatic checking on.
macOS deletes `AutomaticCheckEnabled` on its next scan, so the step no longer
writes it; the other five keys hold after a restart. The security row is renamed Install system
data files and security updates.

The last row of the UI is backed by two keys. Setting only one leaves the
checkbox in a mixed state that reads as enabled while half the behavior is off.

### Keyboard shortcuts

`com.apple.symbolichotkeys AppleSymbolicHotKeys`, entries `64` (show Spotlight
search) and `65` (show Finder search window), each `enabled = false` while
preserving the `value` dictionary of `{type: standard, parameters: [...]}`.
Followed by `activateSettings -u`.

### Added on macOS 27.2.1

Each found by the owner changing the pane and diffing, 2026-11-16 to 11-17.

| Setting | Key | Value |
| --- | --- | --- |
| Spotlight: related content and system items hidden | `com.apple.Spotlight EnabledPreferenceRules` | lists the six rules in `spotlight.sh` |
| Help Apple Improve Search, off | `com.apple.assistant.support "Search Queries Data Sharing Status"` | `2` |
| Siri suggestions, off per app | `com.apple.suggestions AppCanShowSiriSuggestionsBlacklist` | the eleven bundle ids in `siri.sh` |
| Apple Intelligence, off | `com.apple.CloudSubscriptionFeatures.optIn 545129924` | `false` |
| Slightly dim the display on battery, off | `pmset -b lessbright` | `0` |
| Prevent sleeping on power adapter when the display is off, off | `pmset -c sleep` | `1` |
| Optimize video streaming on battery, off | `/Library/Preferences/.GlobalPreferences com.apple.coremedia.optimizeVideoStreamingOnBattery` | `false` |
| Menu bar items, Don't Show | `-currentHost com.apple.controlcenter <item>` for AirDrop, Battery, Bluetooth, Display, FocusModes, KeyboardBrightness, NowPlaying, ScreenMirroring, Sound, Spotlight, TimeMachine, Timer, UserSwitcher, WiFi | `8`; `2` is shown |
| Control Gallery suggestions, off | `-currentHost com.apple.controlcenter ShowSuggestions` | `false` |
| AirPlay Receiver, off | `-currentHost com.apple.controlcenter AirplayReceiverEnabled` | `false` |
| Universal Control, off | `-currentHost com.apple.universalcontrol Disable` and `DisableMagicEdges` | `true` |
| Password after screen lock, immediately | `sysadminctl -screenLock` | `immediate` |
| Wallpaper, solid black | `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` | a `systemColor` `black` choice |
