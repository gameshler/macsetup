# Repository instructions

## Scope

This repository provisions a Mac from a single command: it installs Homebrew,
the applications and command-line tools the owner uses, the dotfiles that
configure them, and the macOS system settings the owner prefers.

It is a set of shell scripts behind an interactive menu. There is no build step,
no package, and no runtime. The deliverable is a configured machine.

One dev dependency exists: `bats-core`, for the preference engine's tests. It is
the only part of the repository that can be tested without changing the machine.

## Operating principles

- Working code only. Plausibility is not correctness; verify before reporting
  done.
- Never fabricate file paths, preference keys, command output, or test results.
  Read the file, run the command, or say what is unknown.
- Say when a premise appears wrong before implementing around it.
- Touch only what the task requires. Avoid drive-by refactors or cleanup.
- Keep communication direct and concise. Skip flattery, filler, and emoji.

## Architecture

| Path | Role |
| --- | --- |
| `start.sh` | Bootstrap. Downloads the repository zip, unpacks it to `~/Downloads/macsetup`, runs `core/main.sh`. |
| `core/main.sh` | Interactive menu. Walks `core/tabs/` and runs the chosen script. Sets `DOT_FILES`, `TABS_DIR`, `COMMON_SCRIPT`. |
| `core/tabs/common-script.sh` | Shared library. Sourced by every tab script. Resolves Homebrew and defines the install helpers. |
| `core/tabs/settings-lib.sh` | Shared library. The preference engine: applies a manifest, reads every key back, restarts the owning services once. |
| `core/tabs/system/` | Scripts that change macOS itself. |
| `core/tabs/apps/` | Scripts that install applications, grouped by category. |
| `dotfiles/` | Configuration files copied into the home directory. |

The menu is generated from the directory tree. A new script becomes a new menu
entry by existing in the right directory; nothing registers it.

A shared library must live at `core/tabs/` root, never under `core/tabs/system/`.
`core/main.sh:49` lists directories only at the root level, so a file there is
invisible to the menu, while `core/main.sh:53` lists every `*.sh` inside a
subdirectory. That is why `common-script.sh` and `settings-lib.sh` sit where they
do. Putting a library one level deeper turns it into a menu entry that runs
itself.

### Environment contract

`start.sh` exports `TEMP_DIR` and `INSTALL_DIR`. `core/main.sh` exports
`DOT_FILES`, `TABS_DIR`, `COMMON_SCRIPT`, and `SETTINGS_LIB`. Tab scripts depend
on all six and none of them are set when a script is run directly. To test one
script in isolation, export them first.

`core/main.sh` runs each tab as `bash "$path"`, a separate non-interactive,
non-login process. It inherits the exported environment and nothing else. It
does not read `~/.zprofile` or `~/.zshrc`.

## Hard rules

### Never use `sudo` for a user preference

`defaults` resolves an unqualified domain against the calling user. Under `sudo`
that is root, so the write lands in `/var/root/Library/Preferences/` and has no
effect on the logged-in account. The same applies to `killall Finder` and
`killall Dock`, which under `sudo` target root's nonexistent session.

```sh
defaults write com.apple.finder ShowPathbar -bool true    # correct
sudo defaults write com.apple.finder ShowPathbar -bool true   # writes to root
```

`sudo` is correct only for a genuinely system-scoped target: an absolute path
under `/Library/Preferences`, `pmset`, `socketfilterfw`, or `installer`.

### Never trust a `defaults write` exit code

`defaults write` exits 0 for a key that nothing reads, including a misspelled
one. A run that printed no error is not evidence. Read the value back as the
logged-in user and confirm the System Settings UI agrees.

Some domains cannot be written at all. `com.apple.universalaccess` is
TCC-protected -- its plist carries a `com.apple.macl` xattr -- and `defaults
write` answers `Could not write domain ...; exiting` unless the calling terminal
has Full Disk Access. The domain still reads fine, so only the read-back
distinguishes "protected" from "applied". A row against such a domain is
reported as failed on every run and is a manual step, not a bug to fix.

### Write scalar preferences through the manifest, never by hand

`core/tabs/settings-lib.sh` holds `apply_settings`, which reads pipe-delimited
rows on stdin and is the only place a scalar `defaults write` happens. It writes
each row, reads it back, reports every key that did not take, and restarts each
distinct owner once at the end.

```sh
apply_settings <<'EOF'
com.apple.dock   | tilesize    | int  | 16   | Dock
com.apple.finder | ShowPathbar | bool | true | Finder
EOF
```

Adding a setting is a row, not a new write/verify/restart trio. This exists
because the rule above is the one the repository already broke 32 times.

Details the engine owns, so no caller has to remember them:

- `defaults read` returns `1` and `0` for a boolean, not `true` and `false`.
  Comparing the written literal against the read value fails every bool unless
  both sides are normalized first.
- The domain column carries the scope, in three forms. The engine decides from
  the row; a caller that adds its own `sudo` or `-currentHost` reintroduces the
  bug in the rule above. **The read-back resolves the scope on the same
  condition as the write**, or the row reports a false failure on every run.

  | Domain column | Scope |
  | --- | --- |
  | `com.apple.dock` | the calling user |
  | `/Library/Preferences/com.apple.SoftwareUpdate` | the system, written with `sudo` |
  | `-currentHost NSGlobalDomain` | this host only |

  An unqualified domain is never written with `sudo`: that writes `/var/root` and
  never reaches the logged-in account. A root-owned plist read without `sudo`
  fails or returns a different file.

  The per-host form is spelled exactly like the `defaults` flag it becomes. It is
  not optional decoration: macOS stores some settings **only** per host.
  `com.apple.mouse.tapBehavior` lives in
  `~/Library/Preferences/ByHost/.GlobalPreferences.<hardware-uuid>.plist` and is
  absent from the plain global domain, so a row without the prefix writes a key
  nothing reads, reads it straight back, and reports success. Per-host and `sudo`
  never combine -- ByHost files are under the user's own preferences directory.
- Rows are fed on a dedicated file descriptor, never on stdin. A tab script
  inherits the menu's terminal stdin (`core/main.sh:90`), and anything inside
  the loop that reads stdin -- `sudo` asking for a password is the case that
  will actually happen -- consumes the next manifest row instead. Use
  `while IFS='|' read -r ... <&3; done 3<<'EOF'`, and take the password through
  the shared keepalive before the loop so `sudo` never prompts inside it. The
  engine owns this; a caller just writes `apply_settings <<'EOF'`. The symptom
  when it is missing is a run that reports "applied 1 of 1" and looks like a
  success while every row after the first was swallowed.
- Feed the manifest by heredoc or redirect, never by a pipe. The right-hand side
  of a pipe runs in a subshell, so `SETTINGS_FAILED_COUNT` and the collected
  report do not survive back to the caller and a failed run looks clean.
- Every `killall` is `|| true`. `killall` exits non-zero when the target is not
  running, which is normal for `Spotlight` and `sharedfilelistd`, and under
  `set -e` that aborts the script. See the next rule for why that is worse than
  it sounds.

The manifest covers scalar key/value writes, which is most of them. Four cases
are structural and stay as explicit code: `com.apple.dock persistent-apps`,
`com.apple.Spotlight orderedItems`, `com.apple.symbolichotkeys`
`AppleSymbolicHotKeys`, and `com.apple.finder FavoriteTagNames`. Those still
verify through the shared `verify_setting` helper rather than rolling their own
read-back. `pmset` and `socketfilterfw` are not preferences at all: they get
their own reads and report through `verify_value`.

`verify_setting <domain> <key> <expected> [exact|contains|absent]`. Pick the mode
by what the setting actually asserts:

- `exact` for a whole value, with booleans normalized on both sides.
- `contains` to prove something is present inside a structure.
- `absent` to prove something is **not** there. Some structural settings can only
  be stated negatively: "every Spotlight category is off" is not a string the
  read-back contains, it is the absence of `enabled = 1` across twenty-one
  entries. A `contains` check on the category name would pass a half-disabled
  array, so those two go together -- one proves the array was written, the other
  proves nothing in it is still on.

`verify_value <label> <expected> <actual> [mode]` is the same comparison against
a value the caller already holds, for a check with no domain and key to read --
`socketfilterfw --getglobalstate` and `pmset -g`. `verify_setting` is a read plus
`verify_value`. Use it rather than an ad hoc `case`, so those failures land in the
one report with every row, and pick the mode just as carefully: the firewall check
has to be `contains` because the state is embedded in a sentence, while `womp` has
to be `exact` or a value of `10` would pass as `0`.

### Restart the process that owns the preference, not the one you assume

macOS brokers preference reads through `cfprefsd`, which caches a live domain
and can flush a stale copy back over a `defaults write`. Dockutil hit exactly
this and added a `cfprefsd` restart in 1.1.4 because dock settings were being
silently reverted. A write to a domain whose owning app is running is not safe
until that owner reloads.

| What changed | Restart |
| --- | --- |
| `com.apple.finder` keys | `killall Finder` |
| `com.apple.dock` keys | `killall Dock` |
| Finder sidebar (`.sfl3` / `.sfl4`) | `killall sharedfilelistd` -- `killall Finder` does NOT apply these. Needs Full Disk Access, and `LSSharedFileList` is a dead end: see below |
| `com.apple.symbolichotkeys` | `activateSettings -u` |
| Alfred plists | quit Alfred BEFORE writing, then relaunch |

Alfred is the inverted case: it caches its own preferences in memory and
overwrites the file on quit, so editing while it runs loses the change.

Verified live on 2026-09-17 for all three owners any manifest declares: `killall
Finder`, `killall Dock` and `killall WindowManager` from an unprivileged tab all
terminate the process and launchd brings it straight back, in under a second.
`activateSettings` is present at the path above and `-u` returns 0.

### An API that returns an empty list is not the same as an empty list

`LSSharedFileList` is the cautionary case, measured on macOS 15.7.9. Asked for
sidebar favorites it returns **0 items with seed 0** -- no error, no NULL, no TCC
denial -- for a file that is 4403 bytes on disk. `LSSharedFileListInsertItemURL`
returns a valid-looking item ref and leaves that file byte-identical, and
`LSSharedFileListItemRemove` on that ref crashes inside `SFLGenericList`. A tool
built on it reports success and changes nothing.

What made this diagnosable was asking the same API for a **different list** in
the same process: `SessionLoginItems` comes back with real items and a real seed.
That is the control which separates "my code is wrong" from "this list is being
withheld". Always find one before concluding that an empty result means empty.

Two consequences worth carrying: a deprecated API can be reachable and still be
hollow, so probe it rather than trusting either its presence or its return code;
and when every read channel is gone -- API empty, file TCC-refused -- the setting
cannot be verified at all, which under this repository's rules makes it a
reportable failure rather than something to write blindly.

### Prefer domain syntax over a plist path

Apple has warned that `defaults` will change to operate only on preference
domains, which retires the `defaults write /path/to/some.plist` form. Writes to
`/Library/Preferences/...` in this repository use that form today and are the
part most likely to break on a macOS upgrade. Do not add new path-based writes.

### Never detect an installed tool with `command -v` alone

Tab scripts run in a shell that has not sourced any profile. `command -v` fails
for anything whose `PATH` entry comes from `.zshrc` or `.zprofile`, and it fails
permanently for a shell function. Both cases silently reinstall on every run.

| Target | Correct test |
| --- | --- |
| Homebrew | `-x /opt/homebrew/bin/brew` or `-x /usr/local/bin/brew`, then `eval "$(brew shellenv)"` |
| nvm | `-s "$HOME/.nvm/nvm.sh"` -- nvm is a shell function and never a binary |
| bun | `-x "$HOME/.bun/bin/bun"` |

### Never source `~/.zshrc` from a tab script

`dotfiles/.zshrc` is zsh-only: it uses `setopt`, `bindkey`, and `$'...'`. Tab
scripts run under `bash` or `sh`, where those are syntax errors, and under
`set -e` that aborts the script. Export what is needed directly.

### Homebrew runs non-interactively

`core/tabs/common-script.sh` exports the Homebrew environment for every tab.
Do not reintroduce per-install prompts or per-package `brew` invocations:
`HOMEBREW_NO_AUTO_UPDATE` in particular is what stops `brew update` from running
before each install, which dominates the cost of a multi-application run.

Batch installs into one `brew install` call with every package name, and take
the sudo password once through the shared keepalive rather than per cask.

### Keep the tab invocation in `core/main.sh` guarded

`core/main.sh:3` sets `set -euo pipefail`. An unguarded `bash "$path"` therefore
makes any non-zero exit from a tab abort the menu, which fires the `EXIT` trap,
which is `rm -rf "$INSTALL_DIR"`: the user sees a script fail and the whole
install directory disappear. That was live until the call was changed to capture
the status into `run_status`, report it, and fall through to `pause`.

Do not remove that guard, and do not add a new unguarded call to a tab. For the
same reason `install_package` and `install_cask` `return 1` rather than
`exit 1` -- one failed package should not end the tab.

A settings script reports failed keys and returns 0 regardless. Reporting is the
engine's job; aborting is not.

### Never point `INSTALL_DIR` at a directory you want to keep

`core/main.sh` traps `EXIT` and runs `cleanup`, which is
`rm -rf "$TEMP_DIR"; rm -rf "$INSTALL_DIR"` (`core/main.sh:30-32,113`). It deletes
its own install directory on every exit, including a clean one, because it is
designed to run against the disposable unpack that `start.sh` makes at
`~/Downloads/macsetup`.

Setting `INSTALL_DIR="$PWD"` to test from a checkout therefore deletes the
checkout the moment the menu exits. Always run against a throwaway copy.

### Guard every array expansion against an empty array

`core/main.sh` runs under `set -euo pipefail`, and the only bash on a stock Mac
is 3.2.57. On bash 3.2 an array with no elements counts as unset, so `set -u`
kills the script:

```sh
$ /bin/bash -c 'set -u; a=(); printf "%s\n" "${a[@]}"; echo survived'
/bin/bash: a[@]: unbound variable
```

zsh and bash 4.4 both print an empty line and carry on, which is why this is
easy to miss: the interactive shell used to test a fragment is not the shell
that runs the menu.

`${#name[@]}` is safe on an unset array. `${name[@]}` is not. Count first:

```sh
if [ "${#ENTRIES[@]}" -eq 0 ]; then
    printf '  %sNothing here yet.%s\n\n' "$C_DIM" "$C_RESET"
else
    for entry in "${ENTRIES[@]}"; do
```

The cost of getting this wrong is not a stack trace. `set -e` fires the EXIT
trap, and that trap runs `rm -rf "$INSTALL_DIR"`. One empty category directory
would take the checkout with it.

### Spell a cask by its canonical name, never an alias

`brew list` answers "is this installed?" three different ways:

```sh
brew list -1 | grep -x python              # no match; it is python@3.14
brew list --formula --versions python      # python@3.14 3.14.7   rc=0
brew list --cask --versions docker         # no output            rc=1
brew list --cask --versions docker-desktop # docker-desktop ...   rc=0
```

`brew list -1` prints canonical names only. `--versions` resolves an alias for a
formula but not for a cask, even though `brew install docker` accepts the alias.
`_brew_install_batch` covers the formula case through `_brew_alias_installed`;
there is no equivalent for casks.

A cask written as an alias is therefore reinstalled on every run: no error, no
warning, just a re-download of a large application forever. `dev-setup.sh` says
`docker-desktop`, not `docker`. After adding a cask, run
`brew list --cask --versions <name>`; if it prints nothing while the app is
installed, the manifest has the wrong name.

### Put `--` before an argument that can begin with a dash

BSD `tr` parses its arguments with getopt, so a set that starts with `-` is read
as a flag cluster:

```sh
$ printf 'fix-finder' | tr '-_' '  '
tr: illegal option -- _
usage: tr [-Ccsu] string1 string2
```

The pipeline does not stop. It writes usage text to stderr and passes nothing
on, so the menu renders garbled instead of failing, which is the harder failure
to notice. `--` ends option parsing:

```sh
printf '%s' "$1" | tr -- '-_' '  '
```

The same rule applies to `grep -- "$pattern"` and `rm -- "$file"` whenever the
value comes from a variable, a filename, or a branch name.

### Other

- Never commit a credential, a license key, or a serial. `office.sh` downloads
  a serializer package from a URL; the URL is not a substitute for a review.
- Never widen a `find`, `rm`, or `killall` beyond what the task needs. A stray
  `find ~` traverses the entire home directory on every run.

## Commands

There is no build or package step. The gates are:

```sh
find . -name '*.sh' -not -path './.git/*' -print0 |
    xargs -0 shellcheck -S warning -e SC1090,SC1091
shfmt -d -i 4 .        # requires: brew install shfmt
bats test/             # requires: brew install bats-core
typos                  # requires: brew install typos-cli
```

CI runs three of these four gates on every pull request and on pushes to `main`:
`.github/workflows/shellcheck.yml` runs `shellcheck` then `shfmt`, and
`.github/workflows/typos.yml` runs `typos`. Both workflows pin their tools --
shellcheck through `reviewdog/action-shellcheck`, shfmt to a release binary,
typos to a tag -- so a runner image upgrade cannot change the verdict. `bats`
stays local, and CI is not a substitute for the Mac validation below.

The shellcheck job passes `--severity=warning --exclude=SC1090,SC1091`, the same
flags as the local gate. Keep the two in step: a CI gate stricter than the local
one fails work that passed on the machine it was written on.

`_typos.toml` sets `ignore-hidden = false` so the six `.menu` files are spell
checked. Their text is what the menu prints, so a typo there is user facing,
and `typos` skips dotfiles by default.

The lint gate is driven by `find`, not by a `**` glob, because `**` needs
`shopt -s globstar` and the system bash on macOS is 3.2, which has no such
option. Under `/bin/bash` the glob form silently degrades to `*/*.sh` and covers
10 of the repository's 29 scripts, missing everything under `core/tabs/apps/*/`
-- a gate that passes while never reading two thirds of the files. It works in
`zsh` and in bash 4, which is why the problem is easy to miss.

`SC1090` and `SC1091` are excluded because every tab script sources
`"$COMMON_SCRIPT"` through a variable that shellcheck cannot resolve.

`bats` covers `core/tabs/settings-lib.sh` only. Most of this repository changes
the machine it runs on and cannot be tested; the engine is the exception,
because deciding what to write and whether it took is string handling. Use plain
`$status` and `$output` checks -- `run` captures both and always returns 0
itself. Do not add `bats-assert` or `bats-support`: they have to be vendored
into a `test_helper/` directory in the repository, which is more weight than the
assertions are worth here.

Tests live in `test/*.bats`. `bats test/` runs the top level of a directory
only; there is no nesting, so `-r` is not needed.

`core/tabs/common-script.sh` declares `#!/usr/bin/env bash` and is linted. Do
not change it back to `#!/bin/zsh`: shellcheck refuses to analyze a zsh shebang
(`SC1071`), which would leave the most widely sourced file in the repository
unchecked. It is only ever sourced, so the shebang has no effect at runtime,
which is exactly why it is free to be the declaration that keeps the linter
working.

`core/tabs/settings-lib.sh` must declare `#!/usr/bin/env bash`, not `#!/bin/zsh`.
Copying the sibling's shebang would put the file that decides whether forty
preferences applied correctly into the same unlinted hole, which defeats the
reason it exists. It is sourced by `bash` tab scripts, so bash is also the
truthful declaration.

To run the menu without going through `start.sh`, run it against a **copy**,
never against your checkout. See the rule below.

```sh
work="$(mktemp -d)/macsetup"
git clone . "$work"
export TEMP_DIR="$(mktemp -d)" INSTALL_DIR="$work"
"$work/core/main.sh"
```

### Gate a test harness on a live stub before it runs a tab

Testing a tab means intercepting `brew`, `defaults`, `sudo` and friends. Twice
now the interception has silently failed and the harness installed real
applications. Both times the harness reported normal-looking output while doing
it, because a skipped stub looks exactly like a working one.

- Write the harness to a file and run it with `bash`. The interactive shell here
  is zsh, where `rm() { ... }` is a parse error against the `rm` alias -- that
  aborts the whole stub file at the first such definition, and `export -f` does
  not exist in zsh either.
- Prefer exported shell functions over `PATH` stubs. `checkPackageManager` runs
  `eval "$(brew shellenv)"`, which puts `/opt/homebrew/bin` ahead of a stub
  directory; a function wins regardless of `PATH`.
- Probe before acting. Run one stubbed command in a child `bash` and compare its
  output to what the stub should print. If it does not match, exit -- do not run
  a single tab. Probe **through `common-script.sh`**, not against the raw `PATH`:
  that file runs `checkPackageManager` at source time, so the ordering a tab sees
  is not the one the harness set up.
- Deleting a stub does not make a command absent. To test the "tool is not
  installed" branch, the real one has to leave `PATH` as well, and `command_exists`
  falls back to `open -Ra`, so the `open` stub has to fail for that name too.
  Never strip the directory holding `brew` to achieve this: `checkPackageManager`
  downloads and runs the Homebrew installer when `brew_path` comes back empty.
- Running a tab with `</dev/null` in a harness hides whether it eats the menu's
  stdin. `core/main.sh:90` runs `bash "$path"` with the terminal's stdin still
  attached and then reads the next choice from that same stdin, so a tab that
  consumes it makes the menu skip an entry or exit. Test it by piping two marker
  lines in and checking what is left afterwards, and give the stub an explicit
  `cat >/dev/null` so the guard is actually exercised. `display.sh`, `alfred.sh`
  and `dev-setup.sh` are checked this way.
- `plutil -extract` prints its error to **stdout**, not stderr, and exits 1. So
  `"$(plutil -extract ... 2>/dev/null)"` suppresses nothing: a missing key comes
  back as a 431-byte `file does not exist ...` string that then gets compared as
  if it were a value, or printed into the failure report. Branch on the exit
  code. `alfred.sh` wraps this in a `plist_value` helper.
- Stub the failure, not just the success. An `osascript` stub that always exits 0
  hid a real bug in `alfred.sh` for a whole harness run: the app on disk is
  `Alfred 5.app`, so `tell application "Alfred"` fails with -1728 on the real
  machine and the tab was silently falling through to `killall`. Quit and
  relaunch an application by **bundle id**, never by name -- the name carries the
  major version, the bundle id does not.
- A `PATH` stub cannot shadow a real binary installed by Homebrew at all, because
  `brew shellenv` prepends `/opt/homebrew/bin` after the harness has set `PATH`.
  When the tool under test is a brew formula, `brew uninstall` it for the
  duration of the run and reinstall it afterwards -- which doubles as a real test
  of the tab's own install branch. This is how `display.sh` was verified against
  `displayplacer`.
- `rm` is aliased to `trash -v` and `cp` to `cp -i` in the owner's shell. Use
  `/bin/rm` and `/bin/cp -f` in a harness, or an overwrite prompt will hang it.
- A stubbed `killall` proves the call was made, not that the service restarted.
  The whole settings engine was signed off with `killall` stubbed, so no Finder,
  Dock or WindowManager had ever actually been relaunched by it. When closing
  that kind of gap, a changed pid is still weak evidence -- it shows the process
  died, not that the new one read the new value. Capture an epoch before the
  write and compare it to the relaunched process's start time from
  `ps -o lstart= -p <pid>`: a process that started after the write necessarily
  read it at launch. That is checkable without the GUI, and whether the pane then
  *looks* right stays a manual check.

Anything inside the harness that reads stdin -- `grep`, `defaults`, `sudo` --
swallows the loop's own input, exactly as described for the manifest above. Read
the work list on FD 3 and run the body with stdin on `/dev/null`.

## Validation

A change here is validated on a Mac. CI checks spelling and shell syntax only:
shellcheck cannot catch a wrong preference key, and `bats` covers the engine's
logic but not whether a key is the one macOS actually reads. A green pipeline
says nothing about whether a setting applied.

- Run `shellcheck` on every changed script before reporting done.
- Run `bats test/` when `core/tabs/settings-lib.sh` changes.
- For a settings change, read every key back with `defaults read` as the
  logged-in user and confirm against the System Settings UI.
- For an install change, run the affected menu entry twice. The second run must
  detect what the first installed and skip it.
- Report what was verified on a real machine and what was not. An unverified
  preference key is unverified, however plausible it looks.

## Documentation routing

- `SPEC.md` for requirements, boundaries, and acceptance criteria.
- `ROADMAP.md` for phase order, risks, and exit criteria.
- `TASKS.md` for current work and validation status.
- `README.md` is the user-facing description of the setup and the reference for
  the manual steps the scripts do not automate.

## Maintenance

Keep this file short enough to follow. Add a rule only when it prevents a real
repeat mistake. Every rule above exists because the pattern it forbids is
already in the repository's history.
