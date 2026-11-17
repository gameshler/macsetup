# Repository instructions

## Scope

This repository provisions a Mac from a single command. It installs Homebrew,
the applications and command-line tools the owner uses, and the dotfiles that
configure them, and it applies the owner's macOS system settings.

It is a set of shell scripts behind an interactive menu. There is no build
step, package, or runtime; the deliverable is a configured machine. The only
development dependency is `bats-core`, which tests the parts of the repository
that can be tested without changing the machine.

## Operating principles

- Working code only. Plausibility is not correctness; verify before reporting
  done.
- Never fabricate file paths, preference keys, command output, or test results.
  Read the file, run the command, or say what is unknown.
- Say when a premise appears wrong before implementing around it.
- Touch only what the task requires. Avoid drive-by refactors or cleanup.
- Keep communication direct and concise.

## Architecture

| Path | Role |
| --- | --- |
| `start.sh` | Bootstrap. Downloads the repository zip, unpacks it to `~/Downloads/macsetup`, and runs `core/main.sh`. |
| `core/main.sh` | Interactive menu. Walks `core/tabs/` and runs the chosen script. Exports `DOT_FILES`, `TABS_DIR`, `COMMON_SCRIPT`, `SETTINGS_LIB` and `SETTINGS_DIR`. |
| `core/tabs/common-script.sh` | Shared library sourced by every tab. Resolves Homebrew and defines the install helpers. |
| `core/tabs/settings-lib.sh` | The preference engine. Applies a manifest, reads every key back, and restarts each owning service once. |
| `core/tabs/system/` | Scripts that change macOS. `optimize-settings.sh` is the single entry for every settings change. |
| `core/settings/` | One module per settings area, run in order by `optimize-settings.sh`. Kept outside `core/tabs/` so the menu never lists them. |
| `core/tabs/apps/` | Application installers, grouped by category. |
| `dotfiles/` | Configuration files copied into the home directory. |
| `test/` | `bats` suites. |

### Menu discovery

The menu is generated from the directory tree: a script becomes an entry by
existing in the right directory, and nothing registers it.

`draw_menu` in `core/main.sh` lists only directories at the top level, and
every directory and `*.sh` file one level down. A shared library must therefore
live at the root of `core/tabs/`, never under `core/tabs/system/`: one level
deeper it becomes a menu entry that runs itself. That is why
`common-script.sh` and `settings-lib.sh` sit where they do.

### Environment contract

`start.sh` exports `TEMP_DIR` and `INSTALL_DIR`, and `core/main.sh` exports the
other five paths. Tab scripts depend on all seven, and none is set when a
script is run directly; export them first to test a script in isolation.

`run_tab` in `core/main.sh` runs each tab as `bash "$path"`, a separate
non-interactive, non-login process. It inherits the exported environment and
the terminal's stdin, and nothing else: it does not read `~/.zprofile` or
`~/.zshrc`.

### Session lifecycle

Before the menu opens, `core/main.sh` sources both libraries (which finds or
installs Homebrew), takes the sudo password once, and checks Full Disk Access.
The sudo keepalive lasts as long as the menu, and the exported
`SUDO_KEEPALIVE_STARTED` makes every tab's `sudo_keepalive` return without
asking again. A refused password or a missing grant is reported, and the menu
still opens.

On every exit (`q`, an error, `^C`, a closed window, or a kill), `cleanup` ends
the sudo session with `sudo -k` and, if the session started with Full Disk
Access, revokes it with `tccutil` by the terminal's bundle identifier. A session
that started without the grant is the one where it was just given, and macOS
quits the terminal to apply it, so revoking then would undo it. `cleanup` then
deletes `TEMP_DIR`, and deletes `INSTALL_DIR` only when the exit status is 0.

`core/main.sh` installs the `cleanup` trap before it sources the libraries,
because sourcing can already take the password to install Homebrew. `cleanup`
therefore skips functions the libraries have not defined yet, ignores further
signals, and turns off `set -e`, so a failed write to a closed window cannot
stop it before the removals. Without `TEMP_DIR`, which only `start.sh` sets,
it deletes nothing.

The owner does not grant the terminal Full Disk Access. Settings that need it
are listed in `README.md` under Set by hand.

## Hard rules

### Safety

#### Never run `tccutil reset` without an app id

`tccutil reset SystemPolicyAllFiles` with no bundle identifier clears Full Disk
Access for every app on the machine, prints `Successfully reset`, and cannot be
undone: the decisions are not backed up, and listing them needs the access just
removed. This happened by mistake on 2026-11-16. `revoke_full_disk_access`
refuses an empty or malformed id before calling `tccutil`. Keep that guard,
keep `tccutil` stubbed in every test and harness, and never run it by hand to
see what it does.

#### Never point `INSTALL_DIR` at a directory you want to keep

`cleanup` runs `rm -rf "$INSTALL_DIR"` on every clean exit, because it is
designed for the disposable unpack that `start.sh` makes at
`~/Downloads/macsetup`. Setting `INSTALL_DIR="$PWD"` to test from a checkout
deletes the checkout when the menu exits. Always run against a throwaway copy
(see [Running the menu](#running-the-menu)).

#### Keep the tab invocation guarded

`core/main.sh` runs under `set -euo pipefail`. An unguarded `bash "$path"`
would let any non-zero exit from a tab abort the menu. Before the cleanup trap
learned to keep the install directory on failure, that abort also deleted it.
`run_tab` captures the status, reports it, and falls through to `pause`. Do not
remove that guard or add an unguarded call to a tab. For the same reason,
`install_package` and `install_cask` `return 1` rather than `exit 1`: one failed
package should not end the tab.

A settings run reports failed keys and returns 0 regardless. Reporting is the
engine's job; aborting is not.

#### Guard every array expansion against an empty array

The only bash on a stock Mac is 3.2.57, and `core/main.sh` runs under
`set -euo pipefail`. On bash 3.2 an empty array counts as unset, so `set -u`
kills the script:

```sh
$ /bin/bash -c 'set -u; a=(); printf "%s\n" "${a[@]}"; echo survived'
/bin/bash: a[@]: unbound variable
```

zsh and bash 4.4 print an empty line and carry on, which makes this easy to
miss: the shell used to test a fragment is not the shell that runs the menu.
`${#name[@]}` is safe on an unset array; `${name[@]}` is not. Count first:

```sh
if [ "${#ENTRIES[@]}" -eq 0 ]; then
    printf '  %sNothing here yet.%s\n\n' "$C_DIM" "$C_RESET"
else
    for entry in "${ENTRIES[@]}"; do
```

#### Never widen a destructive command

Never widen a `find`, `rm`, or `killall` beyond what the task needs. A stray
`find ~` traverses the entire home directory on every run.

#### Never commit a secret

Never commit a credential, license key, or serial. `office.sh` downloads a
serializer package from a URL; the URL is not a substitute for a review.

### Preferences

#### Never use `sudo` for a user preference

`defaults` resolves an unqualified domain against the calling user. Under
`sudo` that is root, so the write lands in `/var/root/Library/Preferences/` and
has no effect on the logged-in account. The same applies to `killall Finder`
and `killall Dock`, which under `sudo` target root's nonexistent session.

```sh
defaults write com.apple.finder ShowPathbar -bool true        # correct
sudo defaults write com.apple.finder ShowPathbar -bool true   # writes to root
```

`sudo` is correct only for a system-scoped target: an absolute path under
`/Library/Preferences`, `pmset`, `socketfilterfw`, or `installer`.

#### Never trust a `defaults write` exit code

`defaults write` exits 0 for a key that nothing reads, including a misspelled
one. A run that printed no error is not evidence. Read the value back as the
logged-in user and confirm System Settings agrees.

Some domains cannot be written at all without Full Disk Access.
`com.apple.universalaccess` is TCC-protected (its plist carries a
`com.apple.macl` extended attribute), and `defaults write` answers
`Could not write domain ...; exiting`, while the domain still reads normally.
Only the read-back distinguishes "protected" from "applied". A row against such
a domain is reported as failed on every run and is a manual step, not a bug.

A step that needs Full Disk Access is named in `FULL_DISK_ACCESS_STEPS` in
`settings-lib.sh`. The home screen prints that list when the grant is missing,
and `check_full_disk_access` announces it once before the steps run, so no step
checks on its own. The probe reads the system `TCC.db`, which is mode 0644, so
only TCC can refuse it.

#### Write scalar preferences through the manifest

`apply_settings` in `core/tabs/settings-lib.sh` reads pipe-delimited rows and
is the only place a scalar `defaults write` happens. It writes each row, reads
it back, reports every key that did not take, and restarts each distinct owner
once at the end.

```sh
apply_settings <<'EOF'
com.apple.dock   | tilesize    | int  | 16   | Dock
com.apple.finder | ShowPathbar | bool | true | Finder
EOF
```

Adding a setting is a row, not a new write, verify and restart sequence. The
engine exists because the repository broke the previous rule 32 times.

The engine owns these details, so no caller has to remember them:

- **Booleans.** `defaults read` returns `1` and `0`, not `true` and `false`, so
  both sides are normalized before comparison.
- **Scope.** The domain column carries the scope in one of three forms, and the
  read-back resolves the scope on the same condition as the write, or the row
  reports a false failure on every run. A caller that adds its own `sudo` or
  `-currentHost` reintroduces the bug above.

  | Domain column | Scope |
  | --- | --- |
  | `com.apple.dock` | the calling user |
  | `/Library/Preferences/com.apple.SoftwareUpdate` | the system, written with `sudo` |
  | `-currentHost NSGlobalDomain` | this host only |

  The per-host form is spelled exactly like the `defaults` flag it becomes, and
  it is not optional: macOS stores some settings only per host.
  `com.apple.mouse.tapBehavior` lives in
  `~/Library/Preferences/ByHost/.GlobalPreferences.<hardware-uuid>.plist` and
  is absent from the plain global domain, so a row without the prefix writes a
  key nothing reads, reads it straight back, and reports success. Per-host and
  `sudo` never combine, because ByHost files are under the user's own
  preferences.
- **A dedicated file descriptor.** Rows are read on FD 3, never stdin. A tab
  inherits the menu's terminal stdin, and anything in the loop that reads stdin
  (in practice, `sudo` asking for a password) would consume the next row. The
  symptom is a run that reports "applied 1 of 1" while every later row was
  swallowed. The password is taken through the shared keepalive before the
  loop, so `sudo` never prompts inside it.
- **No pipes.** Feed the manifest by heredoc or redirect. The right-hand side of
  a pipe runs in a subshell, so `SETTINGS_FAILED_COUNT` and the report would not
  survive back to the caller, and a failed run would look clean.
- **Tolerant restarts.** Every `killall` is `|| true`. `killall` exits non-zero
  when the target is not running, which is normal for some owners, and under
  `set -e` that would abort the script.

#### Structural settings are explicit code that verifies through the engine

Arrays, dictionaries, deletions, and files cannot be a manifest row. These stay
as explicit code in their module:

- `com.apple.dock persistent-apps`
- `com.apple.Spotlight orderedItems` and `com.apple.symbolichotkeys
  AppleSymbolicHotKeys`
- `com.apple.finder FavoriteTagNames` and `FK_StandardViewSettings`
- `com.apple.systemuiserver menuExtras`, and the deleted menu bar keys in
  `com.apple.campo` and `com.apple.systemuiserver`
- Alfred's preference bundle and the wallpaper store, written with `plutil`

An array that only needs certain items present goes through
`ensure_listed <domain> <key> <item>...`, never a whole `-array` write. It adds
each missing item with `-array-add` and reads every item back, so items added
some other way survive and a second run writes nothing.
`com.apple.Spotlight EnabledPreferenceRules` and `DisabledUTTypes`, and
`com.apple.suggestions AppCanShowSiriSuggestionsBlacklist` use it.

Structural code still verifies through the shared helpers rather than its own
read-back, so its failures land in the same report:

- `verify_setting <domain> <key> <expected> [exact|contains|absent]` reads a key
  and compares it.
- `verify_value <label> <expected> <actual> [mode]` compares a value the caller
  already holds, for checks with no domain and key, such as
  `socketfilterfw --getglobalstate`, `pmset`, and `sysadminctl`.

Pick the mode by what the setting asserts:

- `exact` for a whole value, with booleans normalized on both sides. `womp`
  must be `exact`, or a value of `10` would pass as `0`.
- `contains` to prove something is present inside a structure or a sentence.
  The firewall state is embedded in a sentence, so it uses `contains`.
- `absent` to prove something is not there. "Every Spotlight category is off"
  is the absence of `enabled = 1` across 21 entries; a `contains` check on a
  category name would pass a half-disabled array, so the two modes go together.

`pmset -g` shows only the power source in use, so a value set with `pmset -b`
or `pmset -c` is read from its own section of `pmset -g custom`
(`Battery Power` or `AC Power`) through `pmset_value` in
`core/settings/battery.sh`. Both sections carry the same keys, so reading the
first match checks the wrong source.

#### Restart the process that owns the preference

macOS brokers preference reads through `cfprefsd`, which caches a live domain
and can flush a stale copy back over a `defaults write`. Dockutil added a
`cfprefsd` restart in 1.1.4 because Dock settings were being silently reverted.
A write to a domain whose owner is running is not safe until that owner
reloads.

| What changed | Restart |
| --- | --- |
| `com.apple.finder` | `killall Finder` |
| `com.apple.dock` | `killall Dock` |
| Control Center menu bar items | `killall ControlCenter` |
| `com.apple.systemuiserver menuExtras` | `killall SystemUIServer` |
| Wallpaper store | `killall WallpaperAgent` |
| `com.apple.symbolichotkeys` | `activateSettings -u` |
| Finder sidebar (`.sfl3`, `.sfl4`) | `killall sharedfilelistd`, not `killall Finder`. Needs Full Disk Access, and is set by hand. |
| Alfred preferences | Quit Alfred before writing, then relaunch it. |

Alfred is the inverted case: it caches its preferences in memory and
overwrites the file on quit, so an edit made while it runs is lost. Its hotkey
is a machine-local preference under `preferences/local/<localhash>/`. Take the
hash from `localhash` in `~/Library/Application Support/Alfred/prefs.json`,
which Alfred writes on first launch, and create the folder. Never wait for it:
Alfred creates it only when a local preference is first changed in its UI, so
on a fresh install it is missing even after Alfred has run.

Verified live on 2026-09-17: `killall Finder`, `killall Dock` and
`killall WindowManager` from an unprivileged tab each terminate the process,
and launchd relaunches it in under a second. `activateSettings -u` returns 0.

#### An empty result from an API is not proof of an empty list

`LSSharedFileList` is the cautionary case, measured on macOS 15.7.9. Asked for
sidebar favorites, it returns 0 items with seed 0 (no error, no NULL, no TCC
denial) for a file that is 4403 bytes on disk.
`LSSharedFileListInsertItemURL` returns a valid-looking item and leaves the file
byte-identical, and `LSSharedFileListItemRemove` on that item crashes inside
`SFLGenericList`. A tool built on it reports success and changes nothing.

What made this diagnosable was asking the same API for a different list in the
same process: `SessionLoginItems` returns real items and a real seed. That
control separates "my code is wrong" from "this list is being withheld". Find
one before concluding that an empty result means empty.

Two lessons follow. A deprecated API can be reachable and still hollow, so
probe it rather than trusting its presence or its return code. And when every
read channel is gone (the API is empty and the file is TCC-refused), the
setting cannot be verified, which under this repository's rules makes it a
reported failure or a manual step, never a blind write.

#### Prefer domain syntax over a plist path

Apple has warned that `defaults` will operate only on preference domains, which
would retire the `defaults write /path/to/some.plist` form. Writes to
`/Library/Preferences/...` use that form today and are the most likely to break
on a macOS upgrade. Do not add new path-based writes.

#### Add a settings area as a module, not a menu entry

Every settings change runs from Optimize Settings. A new area is a file in
`core/settings/` that only defines functions, plus one `run_area` line in
`core/tabs/system/optimize-settings.sh`, placed where its order matters:
Spotlight runs before Alfred, because Alfred cannot take cmd+space while
Spotlight holds it.

A module must not source the libraries, call its own entry function, or print
its own `settings_report`. The optimizer does all three, so the run ends in a
single failure list. An area returns non-zero only when it stopped before
finishing, and the optimizer adds it to that list. A step that needs Full Disk
Access goes in `FULL_DISK_ACCESS_STEPS`.

### Shell and tools

#### Never detect an installed tool with `command -v` alone

Tab scripts run in a shell that has not sourced any profile. `command -v`
fails for anything whose `PATH` entry comes from `.zshrc` or `.zprofile`, and
always fails for a shell function. Both cases silently reinstall on every run.

| Target | Correct test |
| --- | --- |
| Homebrew | `-x /opt/homebrew/bin/brew` or `-x /usr/local/bin/brew`, then `eval "$(brew shellenv)"` |
| nvm | `-s "$HOME/.nvm/nvm.sh"`; nvm is a shell function, never a binary |
| bun | `-x "$HOME/.bun/bin/bun"` |

#### Never source `~/.zshrc` from a tab script

`dotfiles/.zshrc` is zsh-only: it uses `setopt`, `bindkey`, and `$'...'`. Tab
scripts run under `bash` or `sh`, where those are syntax errors, and under
`set -e` the script aborts. Export what is needed directly.

#### Homebrew runs non-interactively

`common-script.sh` exports the Homebrew environment for every tab. Do not
reintroduce per-install prompts or per-package `brew` invocations.
`HOMEBREW_NO_AUTO_UPDATE` in particular stops `brew update` from running before
each install, which otherwise dominates a multi-application run. Batch installs
into one `brew install` call, and take the sudo password once through the
shared keepalive rather than per cask.

#### Spell a cask by its canonical name, never an alias

`brew list` answers "is this installed?" in three different ways:

```sh
brew list -1 | grep -x python              # no match; it is python@3.14
brew list --formula --versions python      # python@3.14 3.14.7   rc=0
brew list --cask --versions docker         # no output            rc=1
brew list --cask --versions docker-desktop # docker-desktop ...   rc=0
```

`brew list -1` prints canonical names only, and `--versions` resolves an alias
for a formula but not for a cask, even though `brew install docker` accepts the
alias. `_brew_install_batch` handles the formula case through
`_brew_alias_installed`; there is no equivalent for casks. A cask written as an
alias is reinstalled on every run, with no error, and the application is
downloaded again each time. `dev-setup.sh` says `docker-desktop`, not
`docker`. After adding a cask, run `brew list --cask --versions <name>`; if it
prints nothing while the app is installed, the name is wrong.

#### Put `--` before an argument that can begin with a dash

BSD `tr` parses its arguments with getopt, so a set that starts with `-` is
read as flags:

```sh
$ printf 'fix-finder' | tr '-_' '  '
tr: illegal option -- _
usage: tr [-Ccsu] string1 string2
```

The pipeline does not stop. It writes usage text to stderr and passes nothing
on, so the menu renders garbled instead of failing. `--` ends option parsing:

```sh
printf '%s' "$1" | tr -- '-_' '  '
```

The same applies to `grep -- "$pattern"` and `rm -- "$file"` whenever the value
comes from a variable, a file name, or a branch name.

## Commands

There is no build or package step. These are the gates:

```sh
find . -name '*.sh' -not -path './.git/*' -print0 |
    xargs -0 shellcheck -S warning -e SC1090,SC1091
shfmt -d -i 4 .        # brew install shfmt
bats test/             # brew install bats-core
typos                  # brew install typos-cli
```

CI runs three of the four on every pull request and on pushes to `main`:
`.github/workflows/shellcheck.yml` runs `shellcheck` and then `shfmt`, and
`.github/workflows/typos.yml` runs `typos`. Each tool is pinned (shellcheck
through `reviewdog/action-shellcheck`, shfmt to a release binary, typos to a
tag), so a runner image upgrade cannot change the verdict. `bats` runs locally
only, and CI is not a substitute for validation on a Mac.

Notes on the gates:

- The CI shellcheck job uses `--severity=warning --exclude=SC1090,SC1091`, the
  same flags as the local gate. Keep them in step: a stricter CI gate fails
  work that passed locally.
- `SC1090` and `SC1091` are excluded because every tab sources
  `"$COMMON_SCRIPT"` through a variable that shellcheck cannot resolve.
- The lint gate uses `find`, not a `**` glob. `**` needs `shopt -s globstar`,
  which bash 3.2 lacks; under `/bin/bash` the glob silently degrades to
  `*/*.sh` and misses everything under `core/tabs/apps/*/`.
- `shfmt -d -i 4 .` also reads scratch scripts under `.context/`, so delete any
  you leave there.
- `_typos.toml` sets `ignore-hidden = false` so the `.menu` files are spell
  checked. Their text is what the menu prints, and `typos` skips dotfiles by
  default.
- `core/tabs/common-script.sh` and `core/tabs/settings-lib.sh` declare
  `#!/usr/bin/env bash`. Do not change either to `#!/bin/zsh`: shellcheck
  refuses to analyze a zsh shebang (`SC1071`). Both are only ever sourced by
  bash tab scripts, so bash is also the truthful declaration.

### Running the menu

To run the menu without `start.sh`, run it against a copy, never your
checkout:

```sh
work="$(mktemp -d)/macsetup"
git clone . "$work"
export TEMP_DIR="$(mktemp -d)" INSTALL_DIR="$work"
"$work/core/main.sh"
```

## Testing

Most of this repository changes the machine it runs on and cannot be tested.
The exception is the logic that decides what to write or install and whether it
took, which is string handling. Tests live in `test/*.bats`; `bats test/` runs
the top level only, so `-r` is not needed.

| Suite | Covers | Isolation |
| --- | --- | --- |
| `settings-lib.bats` | The preference engine | `defaults`, `killall`, `sudo` stubbed |
| `common-script.bats` | Batch installs and the Homebrew install branch | `brew` stubbed as a function; skips without a real Homebrew |
| `optimize-settings.bats` | Area order and the single report | stub modules |
| `full-disk-access.bats` | The probe and the revoke guard | `tccutil` stubbed |
| `main-exit.bats` | `cleanup` on startup failures, a closed window, and a second signal | copy of `main.sh` with a stub library, `sudo` on `PATH` |
| `alfred.bats`, `wallpaper.bats` | The hotkey write and the wallpaper store | scratch `HOME` |
| `spotlight.bats`, `siri.bats`, `menu-bar.bats`, `display.bats` | Hide rules, suggestion lists, menu bar rows, Universal Control | stubbed `defaults` |
| `ai.bats` | Copilot shim removal | scratch copy, `sudo` and `pkgutil` stubbed |
| `battery.bats` | Battery options | stubbed `pmset` |
| `security.bats` | Stealth mode, screen lock, AirPlay Receiver | scratch `socketfilterfw`, stubbed `sysadminctl` and `defaults` |

`test/common-script.bats` skips when no real Homebrew is present, because
sourcing the library without one runs the Homebrew installer.

Writing assertions:

- Use plain `$status` and `$output` checks; `run` captures both and always
  returns 0 itself. Do not add `bats-assert` or `bats-support`: they have to be
  vendored into the repository, which costs more than they are worth here.
- Never leave `[[ ]]` or a `!`-negated command anywhere but a test's last line
  without `|| false`. `bats` runs under `/bin/bash` 3.2, where neither trips
  `set -e`, so the assertion passes whatever it compares. 30 of the 43 in
  `test/settings-lib.bats` could not fail until each gained `|| false`. Prefer
  `[ ]`, `grep -q`, or a `grep -c ... -eq 0` count for a negative check.

### Test harnesses that run a tab

Testing a whole tab means intercepting `brew`, `defaults`, `sudo` and similar
commands. Twice the interception silently failed and a harness installed real
applications while printing normal-looking output, because a skipped stub
looks exactly like a working one.

- **Run the harness with `bash`, from a file.** The interactive shell here is
  zsh, where `rm() { ... }` is a parse error against the `rm` alias, which
  aborts the whole stub file; `export -f` does not exist in zsh either.
- **Prefer exported shell functions to `PATH` stubs.** `checkPackageManager`
  runs `eval "$(brew shellenv)"`, which puts `/opt/homebrew/bin` ahead of a
  stub directory; a function wins regardless of `PATH`. A `PATH` stub cannot
  shadow a Homebrew-installed binary at all. When the tool under test is a
  formula, `brew uninstall` it for the run and reinstall it afterwards, which
  also tests the tab's install branch. `display.sh` was verified this way
  against `displayplacer`.
- **Probe before acting.** Run one stubbed command in a child `bash`, through
  `common-script.sh` rather than the raw `PATH`, and compare its output with
  what the stub should print. If it does not match, exit without running a tab.
- **Make a command truly absent to test the "not installed" branch.** Deleting
  a stub is not enough: the real command has to leave `PATH`, and because
  `command_exists` falls back to `open -Ra`, the `open` stub has to fail for
  that name too. Never remove the directory holding `brew`:
  `checkPackageManager` downloads and runs the Homebrew installer when
  `brew_path` comes back empty.
- **Check stdin handling.** Running a tab with `</dev/null` hides whether it
  consumes the menu's stdin. `run_tab` leaves the terminal's stdin attached and
  then reads the next choice from it, so a tab that consumes it makes the menu
  skip an entry or exit. Pipe two marker lines in and check what is left, and
  give the stub an explicit `cat >/dev/null`. `display.sh`, `alfred.sh` and
  `dev-setup.sh` were checked this way. Inside a harness loop, read the work
  list on FD 3 and run the body with stdin on `/dev/null`.
- **Branch on `plutil`'s exit code.** `plutil -extract` prints its error to
  stdout and exits 1, so `2>/dev/null` suppresses nothing: a missing key comes
  back as a `file does not exist ...` string that is then compared as if it
  were a value. `alfred.sh` wraps this in `plist_value`.
- **Stub the failure as well as the success.** An `osascript` stub that always
  exited 0 hid a real bug in `alfred.sh`: the app is `Alfred 5.app`, so
  `tell application "Alfred"` fails with -1728 on the real machine. Quit and
  relaunch an application by bundle identifier, never by name, because the
  name carries the major version.
- **Avoid the owner's aliases.** `rm` is aliased to `trash -v` and `cp` to
  `cp -i`. Use `/bin/rm` and `/bin/cp -f` in a harness, or an overwrite prompt
  will hang it.
- **A stubbed `killall` proves the call, not the restart.** A changed pid shows
  the process died, not that its replacement read the new value. Record an
  epoch before the write and compare it with the relaunched process's start
  time from `ps -o lstart= -p <pid>`: a process that started after the write
  necessarily read it at launch. Whether the pane then looks right stays a
  manual check.

## Validation

A change is validated on a Mac. CI checks spelling, formatting and shell
syntax only: shellcheck cannot catch a wrong preference key, and `bats` covers
the logic but not whether a key is the one macOS reads.

- Run `shellcheck` on every changed script before reporting done.
- Run `bats test/` when `main.sh`, `settings-lib.sh`, `common-script.sh`,
  `optimize-settings.sh`, or a module in `core/settings/` changes.
- For a settings change, read every key back with `defaults read` as the
  logged-in user and confirm it in System Settings.
- For an install change, run the affected entry twice. The second run must
  detect what the first installed and skip it.
- Report what was verified on a real machine and what was not. An unverified
  preference key is unverified, however plausible it looks.

## Documentation routing

- `SPEC.md`: requirements, boundaries, acceptance criteria, and settled
  decisions.
- `ROADMAP.md`: phase order, risks, and exit criteria.
- `TASKS.md`: open work, validation status, and verified preference keys.
- `README.md`: the user-facing description of the setup, and the manual steps
  the scripts do not automate.

## Maintenance

Keep this file short enough to follow. Add a rule only when it prevents a real,
repeated mistake; every rule here exists because the pattern it forbids is in
the repository's history.
