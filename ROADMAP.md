# Roadmap

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Repair the foundation | Complete except one live check |
| 2 | Desktop, Finder, and input | Complete, 2026-09-17 |
| 3 | System and security | Complete, 2026-11-17 |
| 4 | Development environment | Complete, 2026-09-20 |
| 5 | Application configuration | Complete, 2026-11-17 |
| 6 | Deferred settings | Complete, 2026-11-17 |
| 7 | macOS 27 system optimization | Complete except one known gap |

## Phase 1: Repair the foundation

**Status:** complete except one live check. Eight of the nine exit criteria
were met and re-verified on 2026-09-17. The cask password-prompt count has not
been measured, because it needs a real cask install under `sudo`.

### Outcome

The menu supports more than one action per session. Homebrew is detected
instead of reinstalled, dotfiles reach the locations their applications read,
and a multi-application install runs without interaction.

### Included work

- Resolve Homebrew by path before consulting `PATH`, and export its
  environment from `core/main.sh` so every tab inherits it.
- Export a non-interactive Homebrew environment and add a session-wide sudo
  keepalive.
- Batch installs into one `brew install` call.
- Fix the Ghostty config install, and rename `dotfiles/config` after what it
  configures.
- Detect `nvm` and `bun` in a way that works in a shell with no profile.
- Remove `. ~/.zshrc` from tab scripts.
- Stop a tab's non-zero exit from aborting the menu, which used to fire the
  `EXIT` trap and delete `$INSTALL_DIR`.
- Build the preference engine, `core/tabs/settings-lib.sh`, with
  `apply_settings`, `verify_setting`, owner restarts and boolean
  normalization, and add `test/settings-lib.bats`.
- Convert `fix-finder.sh`, `remove-animations.sh` and `system-cleanup.sh` to
  manifests, which removed `sudo` from every user-domain write.

### Dependencies and risks

Every later phase depends on this one. While Homebrew was reinstalled per
action, every entry paid that cost, and while `sudo defaults` remained, no
settings work could be verified.

The engine was built here, before the first new settings script, so the
roughly forty keys added in Phases 2 and 3 would not establish a hand-written
pattern first. Converting the three existing scripts also proved the engine:
those keys had known-correct values on the machine, so reading them back was a
real test.

Removing `sudo` changed which account the existing preferences applied to.
Settings that appeared to work because they had been set by hand were, from
this phase on, genuinely written by the scripts.

### Exit criteria

- [x] Three menu entries in one session each report Homebrew as installed.
  `brew_path` resolves `/opt/homebrew/bin/brew` without consulting `PATH`,
  reproduced under the minimal `PATH` a tab receives.
- [x] `~/.config/ghostty/config` matches `dotfiles/`, checked with
  `ghostty +show-config` because Ghostty reads its Application Support
  directory after XDG.
- [ ] A cask install prompts for the password once and never for
  confirmation. `--no-ask` is a real flag on Homebrew 7.0.3 and the keepalive
  holds one timestamp per session, but the prompt count has not been measured.
- [x] `grep -rn 'sudo defaults write com\.apple\|sudo killall' core/` returns
  nothing.
- [x] Every scalar write goes through `settings-lib.sh`. Structural writes
  (arrays, dictionaries and files) remain explicit code and verify through the
  shared helpers.
- [x] A manifest row with a misspelled key is reported as failed.
- [x] `bats test/` passes, and breaking boolean normalization makes it fail.
- [x] A tab that exits 1 returns to the menu with `$INSTALL_DIR` present.
- [x] `shellcheck -S warning` passes on every changed script.

## Phase 2: Desktop, Finder, and input

**Status:** complete, 2026-09-17. `desktop-dock.sh`, the `fix-finder.sh`
rewrite and `input.sh` are done. The Finder sidebar was excluded as planned
and is now set by hand (see `SPEC.md`).

### Outcome

Desktop and Dock, Finder, and trackpad settings apply from a script.

### Included work

- Desktop and Dock: Stage Manager and widget visibility, click to reveal the
  desktop, Dock size, position, autohide, launch animation, recent apps, and a
  Dock reduced to System Settings.
- Finder: desktop items, new-window target, tabs, list view, extensions, search
  scope, path bar, status bar, and tags.
- Trackpad: tap to click on, natural scrolling off.

### Dependencies and risks

Depends on Phase 1. The keys were first read off a machine configured by hand
on macOS 15.7.9 and read back again on 27.2.1, so the remaining risk is that a
future macOS upgrade changes them.

Finder and Dock restart to apply changes, which closes open Finder windows. The
engine restarts each service once per run, not once per key.

`cfprefsd` caches live domains and can write a stale copy back over a
`defaults write`. The engine's read-back and owner restarts apply to every key
in the phase, which is the main reason the engine is worth its cost.

### Exit criteria

- [x] Every key reads back under `defaults read` as the logged-in user, and
  System Settings agrees after the services restart.

## Phase 3: System and security

**Status:** complete, 2026-11-17. Spotlight categories and the two symbolic
hotkeys were verified on 2026-09-17. `security.sh` ran live on macOS 27.2.1,
and the firewall, wake setting and Software Update keys read back after a
restart.

### Outcome

Spotlight, its keyboard shortcuts, the firewall, power, and Software Update are
set from a script.

### Included work

- Disable every Spotlight result category without disabling indexing.
- Free cmd+space by disabling symbolic hotkeys 64 and 65.
- Enable the firewall.
- Set wake for network access to never.
- Turn off automatic downloads and installs, keeping system data files and
  security updates.

### Dependencies and risks

Depends on Phase 1. cmd+space has to be freed before Alfred is assigned it,
or Alfred refuses the binding.

Spotlight indexing stays on, because Alfred's file search reads the Spotlight
index. Disabling the categories removes Spotlight's results, which is the
requirement, without breaking Alfred.

Two Software Update keys had to be created rather than changed, which is where
`cfprefsd` caching is most likely to revert a write, so verification had to
survive a restart. On macOS 27, `AutomaticCheckEnabled` no longer maps to a
toggle and macOS deletes it, so it was dropped.

### Exit criteria

- [x] cmd+space opens nothing but Alfred.
- [x] `socketfilterfw --getglobalstate` reports enabled.
- [x] `pmset -g | grep womp` reports 0.
- [x] Spotlight returns no results for any category.
- [x] The Software Update pane matches the five written values after a restart.

## Phase 4: Development environment

**Status:** complete, 2026-09-20. The global packages are installed by
`dev-setup.sh` with bun. `git-ssh.sh` passed nine stubbed scenarios and a live
run: `ssh -T git@github.com` authenticates over the port 443 fallback, and a
second run changes nothing.

The live run found three defects the stubs could not: `gh` was not installed by
anything in the repository, verification ran before the key was uploaded, and
the 443 route lacked `StrictHostKeyChecking=accept-new`, so an unknown host key
failed the check before authentication.

### Outcome

A new machine can clone from and push to GitHub, and the global tooling is
present.

### Included work

- Install the global packages with `bun add -g`.
- Generate an SSH key, configure the agent and keychain, upload the key, and
  verify it.

### Dependencies and risks

Depends on Phase 1. Uploading the key needs an authenticated `gh`; without it,
the script copies the public key and opens the browser, which makes the step
partly manual. The entry never overwrites an existing key.

### Exit criteria

- [x] `ssh -T git@github.com` authenticates, through port 443 on a network
  that refuses port 22. GitHub closes the session instead of granting a shell,
  so `ssh` exits 1 on success and the tab matches the banner instead.
- [x] Re-running the entry with a key present changes nothing.

## Phase 5: Application configuration

**Status:** complete, 2026-11-17. `alfred.sh` sets the cmd+space hotkey and
reduces web search to Google, confirmed by the owner. Browser extensions were
withdrawn: the owner installs them by hand.

### Outcome

Alfred is configured, not merely installed.

### Included work

- Alfred: cmd+space hotkey, web search reduced to Google.

### Dependencies and risks

Depends on Phase 3 for the freed hotkey. Alfred caches its preferences in
memory and rewrites them on quit, so the sequence is quit, write, relaunch.

### Exit criteria

- [x] Alfred opens on cmd+space and lists only Google under web search.

## Phase 6: Deferred settings

**Status:** complete, 2026-11-17.

- Display scaling ("More Space") is automated in `core/settings/display.sh`
  through `displayplacer`, which picks the widest scaled mode at run time.
- Displays > Advanced: both Universal Control toggles were found by changing
  the pane and comparing preferences, and are written by `display.sh`.
- General > AutoFill & Passwords is stored where Full Disk Access is required,
  so it is documented in `README.md` under Set by hand.

A guessed key that exits 0 and does nothing is worse than a documented manual
step, because it looks as if it worked.

## Phase 7: macOS 27 system optimization

**Status:** complete except one known gap, 2026-11-17. Requested by the owner
after a fresh install of macOS 27.2.1 (26B131). Every manifest row read back
after a restart.

### Outcome

The Mac is tuned for performance and security from one Optimize Settings entry,
which runs every settings area in a fixed order and ends in a single report.

### Included work

- Consolidate the settings tabs into modules under `core/settings/`.
- Take the sudo password once at startup and end the session on every exit.
- Security: stealth mode, immediate screen lock, AirPlay Receiver off.
- Battery: four options in Battery > Options.
- Spotlight, Siri suggestions, and Apple Intelligence: everything off, and the
  Copilot shim removed.
- Menu bar: every system item hidden and Control Gallery suggestions off.
- Wallpaper: solid black on every display and Space.
- Display: Universal Control off.
- Move settings that need Full Disk Access to Set by hand in `README.md`.

### Dependencies and risks

Depends on Phases 1 to 3. Keys verified on macOS 15 were re-verified on 27,
and new keys were found by having the owner change each pane while preferences
were compared before and after. The owner does not grant the terminal Full
Disk Access, so settings stored behind TCC are manual.

### Exit criteria

- [x] Every manifest row reads back after a restart.
- [x] The owner confirmed each pane.
- [ ] On a Mac without Homebrew, the first run asks for the password once and
  installs Homebrew without a manual `sudo -v`. Known gap: the owner will run
  this separately.
