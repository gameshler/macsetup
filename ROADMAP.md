# Roadmap

## Phase 1: Repair the foundation

Status: Complete except one live check, 2026-09-17

Eight of the nine exit criteria below are met and were re-verified on
2026-09-17. The exception is the cask password-prompt count, which cannot be
checked without running a real cask install under `sudo`.

### Outcome

The menu becomes usable for more than one action per session. Homebrew is
detected rather than reinstalled, dotfiles reach the locations their
applications read, and a multi-application install runs without interaction.

### Included work

- Resolve Homebrew by path before testing `PATH`, and export its environment
  from `core/main.sh` so every tab inherits it.
- Export the non-interactive Homebrew environment and add a session-wide sudo
  keepalive.
- Batch installs into one `brew install` call against a cached package list.
- Fix Ghostty config installation and rename `dotfiles/config` to a name that
  says what it configures.
- Replace the detection of `nvm` and `bun` with tests that work in a shell that
  has sourced no profile.
- Remove `. ~/.zshrc` from tab scripts.
- Stop `core/main.sh:72` from treating a tab's non-zero exit as fatal. Today it
  aborts the menu and the `EXIT` trap deletes `$INSTALL_DIR`.
- Build `core/tabs/settings-lib.sh`: `apply_settings` and `verify_setting`, plus
  the owner-to-restart table and boolean normalization, and export
  `SETTINGS_LIB` from `core/main.sh`.
- Add `test/settings-lib.bats` covering the eight engine branches that need no
  Mac state. `bats-core` is the repository's first dev dependency.
- Convert `fix-finder.sh`, `remove-animations.sh`, and `system-cleanup.sh` to
  manifests. This removes `sudo` from every user-domain write as a consequence
  of the conversion rather than as 32 separate edits, and gives those keys
  read-back verification they have never had.

### Dependencies and risks

Nothing depends on this phase's predecessors; everything else depends on it.
While Homebrew is reinstalled per action, every other entry pays that cost, and
while `sudo defaults` remains, no settings work can be verified -- a new setting
written the same way would silently fail in the same place.

The engine is built here rather than alongside the first new settings script,
because Phases 2 and 3 add roughly forty keys and would otherwise establish the
hand-written pattern before there is anything to replace it with. Converting the
three existing scripts first is also what proves the engine works: those keys
have known-correct values on this machine, so a conversion that reports them as
applied and reads them back is a real test, not a rehearsal.

Risk: removing `sudo` changes which account the existing preferences apply to.
Settings that appeared to work because they were set by hand in the GUI will now
genuinely be written by the script. That is the intent, but it means the first
run after this phase is the first time these scripts have changed anything.

### Exit criteria

- Three menu entries in one session each report Homebrew as installed. **Met.**
  `brew_path` resolves the binary at `/opt/homebrew/bin/brew` without consulting
  `PATH`. Reproduced under `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, the environment
  a tab actually gets: the old `command -v brew` logic reports not-installed and
  would re-run the installer, the new logic resolves it.
- `~/.config/ghostty/config` exists and matches `dotfiles/`. **Met, with a
  caveat that changed the task.** Matching the file is necessary but not
  sufficient: Ghostty reads its macOS Application Support directory after XDG
  and later files win, so the check is `ghostty +show-config`, not `cmp`. See
  the Ghostty entry in `TASKS.md`.
- A cask install run prompts for the password once and never for confirmation.
  **Not verified.** `--no-ask` is confirmed a real flag on Homebrew 7.0.3 and
  `sudo_keepalive` holds one timestamp for the session, but counting actual
  prompts needs a live cask install under `sudo`, which this working session
  cannot run. This is the one criterion holding the phase open.
- `grep -rn 'sudo defaults write com\.apple\|sudo killall' core/` returns
  nothing.
- Every *scalar* write goes through `settings-lib.sh`. A bare
  `grep -rn 'defaults write' core/tabs/system/` is the wrong check and
  contradicts `SPEC.md`: four structural preferences -- dock contents, Spotlight
  categories, symbolic hotkeys, and Finder tags -- are arrays or nested
  dictionaries that a flat manifest row cannot express, so they stay as explicit
  `-array` and `-dict-add` calls and verify through the same shared helper.
  The check is that none of those matches is a scalar write.
- A manifest row with a deliberately misspelled key makes the run report that
  key as failed.
- `bats test/` passes, and breaking boolean normalization makes it fail.
- A tab that exits 1 returns to the menu with `$INSTALL_DIR` still present.
- `shellcheck -S warning` passes on every changed script.

## Phase 2: Desktop, Finder, and input

Status: Complete, 2026-09-17

`desktop-dock.sh`, the `fix-finder.sh` rewrite, and `input.sh` are all done and
recorded in `TASKS.md`. The Finder sidebar stayed excluded as planned, and the
reason is now first-hand rather than inferred: `LSSharedFileList` returns an
empty list for sidebar favorites without reporting an error, and the backing
file is TCC-protected. It is tracked under "Blocked on a decision".

### Outcome

The interface settings apply from a script: Desktop and Dock, Finder, and
trackpad.

### Included work

- Desktop and Dock: Stage Manager and widget visibility, click-to-reveal,
  dock size, position, autohide, launch animation, recent apps, and reducing
  the dock to System Settings alone.
- Finder: desktop items, new-window target, tabs, list view, extensions,
  search scope, path bar, status bar, tags.
- Trackpad: tap to click, natural scrolling off.

### Dependencies and risks

Depends on Phase 1. The preference keys are verified against macOS 15.7.9 by
reading them off a machine already configured by hand, so the risk is not
whether the keys are right but whether they survive a macOS upgrade.

Finder and Dock are restarted to apply changes, which closes open Finder
windows. The engine restarts each service once per run rather than once per key,
so this happens twice, not twenty-six times.

Risk: `cfprefsd` caches a live domain and can flush a stale copy back over a
`defaults write`, silently reverting it. Dockutil added a `cfprefsd` restart in
1.1.4 for exactly this, and this phase writes eleven dock keys. The mitigation
lives in `settings-lib.sh` and therefore applies to every key in the phase; this
is the main reason the engine is worth its cost.

The Finder sidebar is deliberately excluded: it has no preference domain. It is
tracked as an unresolved question in `SPEC.md`.

### Exit criteria

Every key reads back correctly under `defaults read` as the logged-in user, and
the System Settings UI agrees after the service restarts.

## Phase 3: System and security

Status: Code complete, blocked on a live run, 2026-09-17

Spotlight's categories and the two symbolic hotkeys are done and verified.
`security.sh` is written, `shellcheck` clean, and covered by nine `bats` tests
and four stubbed end-to-end runs, but every one of its writes goes through
`sudo`, so none has ever run against a real root-owned plist. That run and the
post-restart pane check are what remain.

### Outcome

Spotlight, its keyboard shortcuts, the firewall, power, and software update are
set from a script.

### Included work

- Disable every Spotlight result category, without disabling metadata indexing.
- Free cmd+space by disabling symbolic hotkeys 64 and 65.
- Enable the firewall.
- Set wake for network access to never.
- Disable automatic updates except security responses and system data files.

### Dependencies and risks

Depends on Phase 1. Ordering matters within the phase: cmd+space has to be freed
before Phase 5 assigns it to Alfred, or Alfred refuses the binding.

Spotlight indexing stays on deliberately. Alfred's file search reads Spotlight's
index; disabling the categories removes the Spotlight UI results, which is the
actual requirement, without breaking Alfred.

Risk: `cfprefsd` caches live preference domains and can write a stale copy back
over a `defaults write`. This applies to the whole phase, but Software Update is
where it bites, because two of its six keys have to be created rather than
flipped. Verification has to survive a restart, not just a re-read.

### Exit criteria

- cmd+space opens nothing.
- `socketfilterfw --getglobalstate` reports enabled.
- `pmset -g | grep womp` reports 0.
- Spotlight returns no results for any category.
- The Software Update pane matches all six written values after a restart, with
  Security Responses and system files the only row left enabled.

## Phase 4: Development environment

Status: Code complete, blocked on a live run, 2026-09-17

The global bun packages are done, installed by `dev-setup.sh` rather than by a
separate tab. `git-ssh.sh` is written and verified against nine
stubbed scenarios, but its live run is deliberately not done: it generates a
private key and edits `~/.ssh/config`, and `~/.ssh` is outside what this working
session may touch. Run it from the menu.

One finding from that work changes the exit criteria below: this network refuses
`github.com:22`, so the tab probes port 22 and falls back to GitHub's documented
`ssh.github.com` on port 443.

### Outcome

A new machine can clone and push to GitHub, and the global tooling is present.

### Included work

- Install the global packages with `bun add -g`.
- Generate an SSH key, configure the agent and keychain, upload the key, and
  verify, following the two GitHub guides linked in `README.md`.

### Dependencies and risks

Depends on Phase 1. Uploading the key needs an authenticated `gh`; without it
the script falls back to copying the public key and opening the browser, which
makes this entry partly manual.

Risk: the entry must never overwrite an existing key. Detect and reuse.

### Exit criteria

- `ssh -T git@github.com` authenticates, via the port 443 fallback on a network
  that refuses port 22. The exit code is not the signal: GitHub closes the
  session rather than granting a shell, so `ssh` exits **1 on success** and the
  banner is what the tab matches on.
- Re-running the entry with a key already present changes nothing.

## Phase 5: Application configuration

Status: Half done, half blocked, 2026-09-17

Alfred is done: `alfred.sh` sets the cmd+space hotkey and reduces web search to
Google. The browser half is still blocked on which browser is the target, so the
phase as a whole is not complete. One of the two decisions this phase was
blocked on is therefore resolved.

### Outcome

Alfred and the browser are configured, not merely installed.

### Included work

- Alfred: cmd+space hotkey, web search reduced to Google.
- Browser: Privacy Badger, Decentraleyes, and an uBlock Origin variant.

### Dependencies and risks

Depends on Phase 3 for the freed hotkey. Of the two decisions recorded in
`SPEC.md`, the Alfred one is settled and implemented; only "which browser is the
target" is still open.

Alfred must not be running when its plists are written. It caches preferences in
memory and rewrites the file on quit, so an edit made while it runs is lost. The
sequence is quit, write, relaunch.

Full uBlock Origin cannot be installed on Chrome after the Manifest V3
migration. If Chrome is the target, the deliverable is uBlock Origin Lite, which
is a different and less capable extension. This is stated up front rather than
discovered after the fact.

### Exit criteria

- Alfred opens on cmd+space and lists only Google under web search.
- The three extensions are present and enabled in the chosen browser, or the
  substitution is documented.

## Phase 6: Deferred

Status: Partly done, 2026-09-17

Display scaling ("More Space") is **no longer deferred and is implemented** in
`core/tabs/system/display.sh`. It is the one item here that found a scriptable
interface, via the `displayplacer` formula and a mode identifier specific to the
panel, which does not transfer between machines.

Still deferred: the Display Advanced pane and General AutoFill and Passwords.
The owner gave a target state for both on 2026-09-17 -- "disable everything" --
so these are no longer blocked on requirements. What blocks them now is
enumeration. "Everything" is a state without a list, and neither pane's toggles
can be read off this machine: the Safari container is TCC-refused, and
`com.apple.universalcontrol` does not exist as a domain until something writes
it. Full Disk Access is the prerequisite for the first, and a GUI toggle diffed
against the plist for the second.

The intent is that these are documented as manual steps in `README.md` until a
scriptable interface is confirmed. Writing a guessed key that exits 0 and does
nothing is worse than a documented manual step, because it looks like it worked.

**That documentation does not exist yet.** Checked 2026-09-17: `README.md` has
no Displays section and no AutoFill entry, and its only "Advanced" lines are the
three Finder ones at `README.md:58-60`. This paragraph previously asserted the
manual steps were written, which was never true. Writing them is blocked on the
same enumeration problem as implementing them -- a manual step that cannot name
which toggles to flip is not a usable instruction -- so it waits on Full Disk
Access and the GUI diff.
