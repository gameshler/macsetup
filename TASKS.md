# Tasks

## Current phase: System and security

- [ ] Add `core/tabs/system/security.sh`.
  - **Status: written and verified everywhere except against the real
    root-owned plists.** The script, the `verify_value` helper it needed, nine
    `bats` tests, `shellcheck`, and four stubbed end-to-end runs are done. What
    is outstanding is one live run, which needs a sudo password, and the manual
    pane check after a restart. Do not mark this complete until both are done.
    See "Verification status" below for exactly what is and is not proven.
  - Scope: firewall on, `pmset -a womp 0`, and the six Software Update keys in
    the appendix.
  - Acceptance criteria: `socketfilterfw --getglobalstate` reports enabled;
    `pmset -g | grep womp` reports 0; all six Software Update keys read back as
    specified.
  - Manual validation: re-check the Software Update pane after a restart, not
    just after the write. `cfprefsd` caches live domains and can write a stale
    copy back over a `defaults write`.
  - Note: this is the one script where `sudo` is correct throughout -- every
    target is `/Library/Preferences`, `pmset`, or `socketfilterfw`. The six
    Software Update keys are manifest rows whose domain is an absolute path, so
    the engine adds `sudo` itself; the script must not. `pmset` and
    `socketfilterfw` are not preferences and are checked with their own `-g` and
    `--getglobalstate` reads rather than through the engine.

  ### Verification status

  - `verify_value <label> <expected> <actual> [mode]` was added to
    `settings-lib.sh`, and `verify_setting` is now a read plus a call to it. The
    firewall and `womp` checks have no domain and key to read, so they could not
    go through `verify_setting`, but their failures still belong in the same
    report as the six rows. The alternative was an ad hoc `case` in the tab with
    its own message format and no entry in the failure count.
  - Mode choice is load-bearing and is not interchangeable between the two.
    `socketfilterfw --getglobalstate` prints `Firewall is enabled. (State = 1)`,
    so the check is `contains "State = 1"`. `pmset -g` prints `womp 0`, and that
    check must be `exact`, because under a substring test a `womp` of `10` would
    pass as `0`. There is a `bats` test for exactly that.
  - Both parsers were checked against the real command output on this machine,
    not against an assumed format: `awk '$1 == "womp" { print $2 }'` extracts
    `0`, and the firewall string is as quoted above. `awk` on the first field
    rather than `grep`, so a future setting whose name merely contains `womp`
    cannot match.
  - No owner column on any row. Nothing here is a running app with a preference
    cache the engine could flush: the System Settings pane reads these when it
    opens. `cfprefsd` does cache the domain, but the system instance runs as root
    and would not be reached by the engine's unprivileged `killall`, so a
    `cfprefsd` owner would have looked like a fix while doing nothing. The tab
    prints a line saying the pane may need reopening instead.
  - `bats test/` **45 of 45**, up from 36. Nine new tests cover `verify_value`
    against the real output strings of both commands, the substring-versus-exact
    trap, boolean normalization, an empty value from a missing or failing
    command, the label reaching the report, and `verify_setting` still resolving
    the per-host scope after being split.
  - The new tests were mutation-checked. Degrading `exact` to a substring test
    fails 3 tests including the `womp 10` case; making `verify_value` return 0
    unconditionally fails 14.
  - `shellcheck -S warning` clean on `security.sh` and `settings-lib.sh`. The
    repository-wide gate is **1** finding across **30** scripts, the pre-existing
    `SC2155` on `start.sh:8`.
  - Verified 2026-09-16 end to end against a stubbed `sudo`. Every mutating call
    in this tab goes through `sudo` -- the six rows because the engine elevates
    an absolute-path domain, and `socketfilterfw --setglobalstate` and
    `pmset -a womp` because the script calls it directly -- so a single `sudo`
    stub intercepts all of them. The two reads need no elevation and ran for
    real. The harness was written to a file, run with `bash`, and gated on a live
    stub probe before it was allowed to run the tab.

    | Case | Result |
    | --- | --- |
    | normal run | applied 6 of 6, `All settings applied and verified`, exit 0 |
    | call order | keepalive, firewall, `womp`, then the six rows |
    | every write elevated | 6 `sudo defaults write`, 6 `sudo defaults read`, zero unelevated |
    | stdin trap | stub `sudo` drains stdin; all 6 rows still processed, so no row was swallowed |
    | two keys written somewhere nothing reads | applied 4 of 6, those two named, other four still applied, exit 0 |
    | `sudo` denied outright | all 6 rows reported as failed, exit 0, menu not aborted |
    | second and third run | applied 6 of 6 both times, idempotent |

  - The failure report prints twice, once from `apply_settings` and once from
    `settings_report`. That is the documented consequence of a tab that both
    applies rows and does its own checks, and `desktop-dock.sh` has the same
    shape. Only failures duplicate; a clean run prints one line.
  - **Not verified: the live run against the real root-owned plists.** This is
    the gap carried over from the `settings-lib.sh` task and it is still open --
    a `sudo`-scoped row has never been exercised against a real root-owned file,
    only against a stub. The machine is already in the target state for all
    eight checks, so a plain run would prove nothing. `/tmp/macsetup-security-live.sh`
    does it properly: snapshot, perturb every target to a wrong value, run the
    tab, verify with an independent read pass, check `plutil -p` on disk past
    `cfprefsd`, then run again for idempotency. It leaves `AutomaticCheckEnabled`
    and the whole `com.apple.commerce` domain **absent**, as the appendix records
    them, so the run has to create them rather than overwrite something. It
    switches the firewall off for a few seconds during perturbation and carries
    an `EXIT` trap that re-enables it even on a crash or `^C`.
  - **Not verified: the Software Update pane after a restart.** `cfprefsd` caches
    a live domain and can flush a stale copy back over a `defaults write`, so the
    pane is the only check that catches it.

## Next phase: Development environment

- [x] Add `core/tabs/system/git-ssh.sh`.
  - **Status: done. The live run was completed on 2026-09-20 and both
    acceptance criteria hold.** `ssh -T git@github.com` returns
    `Hi gameshler! You've successfully authenticated`, over the port 443
    fallback, and a second run of the tab exits 0 reporting the key, the
    config block and the uploaded key all already present.
  - The live run found three defects that the nine stubbed scenarios could
    not, each fixed in its own commit:
    - Nothing in the repository installed `gh`, so every run reported the CLI
      missing and fell through to the manual browser path. The tab now
      installs it on demand.
    - `open` returns immediately, so verification ran before the key had been
      pasted into the page and the tab reported a failure it had caused
      itself. The manual path now waits for confirmation first.
    - `verify_github` lacked `StrictHostKeyChecking=accept-new`, which
      `port_22_reachable` already had. On this port-22-refusing network the
      443 route is an unknown host, and `BatchMode=yes` forbids the prompt,
      so ssh aborted with `Host key verification failed.` before
      authenticating at all.
  - Scope: ed25519 key, agent and keychain configuration, `~/.ssh/config`
    entry, upload, verify. Follows the two guides at `README.md:207-210`.
  - Acceptance criteria: `ssh -T git@github.com` authenticates; re-running with
    an existing key changes nothing and never overwrites it.
  - Dependencies: `gh ssh-key add` needs an authenticated `gh`. Without it the
    script copies the public key and opens the browser, making the entry partly
    manual.

  ### Verification status

  - **This network refuses github.com:22.** Confirmed outside the sandbox on
    2026-09-16: `ssh -T git@github.com` returns
    `connect to host github.com port 22: Connection refused`, while
    `ssh -T -p 443 git@ssh.github.com` connects and returns
    `Permission denied (publickey)`, which is the correct answer for an account
    with no key. The acceptance criterion cannot be met on port 22 here, however
    correct the key is, so the tab probes port 22 and writes GitHub's documented
    `Hostname ssh.github.com` / `Port 443` block when it is refused. Same host
    alias, so no git remote needs changing.
  - `nc -z` is not usable for that probe: it reports a closed port on this
    machine even for github.com:443, which demonstrably works. The tab reads
    ssh's own connection error instead.
  - Nothing in the tab overwrites anything. The key is generated only when both
    halves are absent, and the config block is appended only when no
    `Host github.com` entry exists. A private key is the one artifact here that
    cannot be regenerated: every account that lists it and every server that
    trusts it breaks at once if it is replaced.
  - The passphrase prompt is deliberately interactive and deliberately not
    `-N ""`. A passphrase is what `UseKeychain` and `--apple-use-keychain` exist
    to hold; generating without one leaves an unencrypted private key on disk and
    makes both of those no-ops.
  - `--apple-use-keychain` only, with no `-K` fallback. Monterey renamed the flag
    and SPEC.md targets macOS 15, where the long form is confirmed accepted.
  - `ssh -T` exit codes are worthless for the verify: GitHub closes the session
    rather than granting a shell, so ssh exits **1 on success**. The banner is
    the only signal, and that is what the tab matches on.
  - `ssh-add -l` exit codes verified on this machine: `1` is an agent running
    with nothing loaded, `2` is no agent reachable. Only `2` warrants starting
    one -- an agent started inside a tab dies with the script and takes the
    loaded key with it. The status is captured into a variable, because
    `if ! cmd && [ "$?" ... ]` reads the status of the negation rather than of
    the command.
  - Verified 2026-09-16 against a fake `HOME` plus stubs for `ssh`, `ssh-add`,
    `ssh-agent`, `gh`, `pbcopy` and `open`. `ssh-keygen` was **not** stubbed: it
    ran for real into the fake HOME, because whether a usable pair appears is the
    thing worth testing.

    | Case | Result |
    | --- | --- |
    | fresh machine, port 22 open | key generated, plain block written, uploaded, verified |
    | fresh machine, port 22 refused | 443 block written, and the verify then succeeds through it |
    | key and `github.com` entry already present | both left byte-identical, no duplicate upload |
    | config exists without a `github.com` entry | block appended after the existing host, existing entry intact |
    | gh present but not logged in | names the reason, clipboard plus browser fallback |
    | gh not installed | names that reason instead, same fallback |
    | upload succeeds, authentication still fails | reported as a failure, exit 1 |
    | no ssh-agent reachable | starts one, then loads the key |
    | run twice | key unchanged, config unchanged, zero `ssh-key add` calls |

  - Two holes were found in the harness itself and fixed, both of which would
    have made a broken test look like a passing one:
    - `VAR=value setup` scopes the variable to that one command, so the port-22
      case was silently running with the default. It reported a plain config
      block and looked correct.
    - Deleting the `gh` stub does not make gh absent -- a real `gh` was still on
      `PATH` and the tab called it. It got a fake `HOME`, found no credentials
      and reported "not logged in", which is why the case appeared to pass. No
      key was uploaded and `gh api user/keys` still returns **0**, confirmed
      after every run. The gate now probes through `common-script.sh`, which is
      the environment a tab actually sees, and the absent case removes the real
      binary's directory from `PATH`.
  - The gate was mutation-checked: removing the `ssh` stub makes it print
    `GATE FAILED: ssh resolves to '/usr/bin/ssh'` and refuse to run the tab.
  - Note for the live run: if `~/.ssh/config` already has a `Host github.com`
    entry pointing at a different `IdentityFile`, the tab leaves it alone by
    design and the verify will use that other key. That is the conservative
    choice, but it means an existing entry wins over the key just generated.
  - `shellcheck -S warning` clean. Repository-wide gate: **1** finding across
    **32** scripts, the pre-existing `SC2155` on `start.sh:8`. `bats test/`
    45 of 45, untouched by this task.

## Blocked on a decision

- [ ] Finder sidebar: home, Applications, Desktop, Documents, Downloads,
  external disks, Bonjour computers, connected servers.
  - **Primary blocker, established 2026-09-17: the file is TCC-protected and no
    tool can get past that.** Favorites live in
    `~/Library/Application Support/com.apple.sharedfilelist/` as an
    NSKeyedArchiver blob with no preference domain, and reading it fails:

    ```
    head: .../com.apple.LSSharedFileList.FavoriteItems.sfl3: Operation not permitted
    plutil: ... NSCocoaErrorDomain Code=257 "you don't have permission to view it"
            NSUnderlyingError ... NSPOSIXErrorDomain Code=1 "Operation not permitted"
    ```

    Whatever terminal runs `start.sh` needs **Full Disk Access** before any of
    this can work. `sbedit` does not change that: it opens the same file as the
    same unprivileged process. This is a prerequisite the task did not previously
    record, and it needs a GUI grant, so it could not be tested here.
  - **Correction: the directory is not empty.** The earlier note read "the empty
    directory observed on this machine is expected ... the file is not created
    until the first Finder window opens". That was a misread of the TCC denial --
    `ls` of the contents prints `Operation not permitted` and nothing else, which
    looks like an empty directory. `ls -ld` on the directory itself succeeds and
    reports 9 links and 288 bytes, and `stat` on the exact filename succeeds
    because TCC protects directory listing and file contents but not metadata on
    a known path:

    | Path | Result |
    | --- | --- |
    | `com.apple.LSSharedFileList.FavoriteItems.sfl3` | exists, 4403 bytes, mtime Sep 13 2026 |
    | `com.apple.LSSharedFileList.FavoriteItems.sfl4` | No such file or directory |

    So on macOS 15.7.9 (24G830) this is `.sfl3`, confirming the note that `.sfl4`
    only arrives with macOS 26.
  - **Secondary blocker: neither tool is installable from Homebrew.**
    - `sbedit` is not a formula or a cask at all (`brew info sbedit` -> "No
      available formula"), and there is no Go toolchain on this machine, so it
      would need either a Go install or a prebuilt binary downloaded from
      GitHub. Both are decisions rather than mechanics.
    - `mysides` is worse than deprecated: the cask is **disabled in Homebrew as
      of 2025-10-13** ("Deprecated because it is not maintained upstream! It was
      disabled on 2025-10-13"), so `brew install mysides` fails outright. The
      existing "use `sbedit`, NOT `mysides`" guidance stands, but for this
      stronger reason rather than for the `LSSharedFileList` deprecation.
  - ~~Untested hypothesis: `mysides` uses the `LSSharedFileList` API, which is
    IPC to `sharedfilelistd` rather than direct file I/O, so it might sidestep
    TCC entirely and need no Full Disk Access.~~ **Tested and refuted
    2026-09-17.** It did not need `mysides`: the API lives in `CoreServices` and
    is deprecated, not removed, so a throwaway `clang` probe calls it directly
    (`/tmp/sflprobe.m`, `sflprobe2.m`, `sflwrite.m`). The result is worse than a
    TCC denial -- the API does not refuse, it lies.

    | Path | Result |
    | --- | --- |
    | direct file read of the `.sfl3` | REFUSED, "you don't have permission to view it" |
    | `LSSharedFileListCopySnapshot`, FavoriteItems | **OK, 0 items, seed 0** -- no error, no NULL |
    | same, FavoriteVolumes / RecentDocuments / RecentApplications / RecentServers | 0 items, seed 0 |
    | same, **SessionLoginItems** | **1 item ("Alfred 5"), seed 3849487963** |
    | `LSSharedFileListInsertItemURL` | returned a valid-looking item ref |
    | the `.sfl3` after that insert | **byte-identical: 4403 bytes, mtime unchanged** |
    | `LSSharedFileListItemRemove` on that ref | **crashed** -- `NSInvalidArgumentException`, nil object, inside `SFLGenericList _removeItemWithIdentifier:` |

    `SessionLoginItems` is the control that makes the rest conclusive. It
    returns real data with a real seed from the same process, so the probe is
    correct and the API works; the sidebar list specifically is withheld,
    returning an empty list rather than an error. And the write path claims
    success while changing nothing: the insert handed back an item ref and the
    file did not move by a single byte.
  - **Consequence: Full Disk Access is required to *verify* the sidebar, not
    just to apply it.** Both read channels are gone -- the API returns 0 items
    and the file is TCC-refused -- so on this machine there is no way to confirm
    a sidebar write programmatically. `SPEC.md` requires that every setting be
    read back and that one which cannot be confirmed is reported as a failure,
    so the sidebar cannot meet this repository's own acceptance bar without the
    grant. That is a stronger reason for the FDA prerequisite than "the file is
    unreadable".
  - This also settles "use `sbedit`, NOT `mysides`" on first-hand evidence
    rather than on the cask being disabled. Anything built on `LSSharedFileList`
    reports success and does nothing, which is precisely the failure mode the
    whole verification design in `settings-lib.sh` exists to catch.
  - The write probe left no trace: the `.sfl3` is still 4403 bytes with its
    original mtime, and the probe directory was removed. The insert never
    reached the file, so there was nothing to undo -- which is fortunate, since
    the API's own removal call crashes.
  - Apply with `killall sharedfilelistd`. `killall Finder` does nothing here --
    `sharedfilelistd` owns the file.
  - Acceptance criteria: the eight requested items appear in the sidebar and
    survive a logout.
  - To unblock, in order: grant Full Disk Access to the terminal, then decide how
    `sbedit` gets onto the machine. The `mysides` branch of that decision is now
    closed -- it is not merely deprecated and disabled, the API underneath it no
    longer works for this list.

- [ ] Browser extensions: Privacy Badger, Decentraleyes, uBlock Origin.
  - Blocker is still "which browser", but it is now a sharp tradeoff rather than
    an open question. Investigated 2026-09-17.
  - **Correction: the repo offers four browsers, the machine has three of them.**
    `core/tabs/apps/browsers/` holds `brave.sh`, `chrome.sh`, `firefox.sh` and
    `thorium.sh` (cask `alex313031-thorium`). Thorium is **not installed** here,
    so the machine has Brave, Firefox and Chrome from this repo, plus the
    preinstalled Safari. The earlier phrase "the four installed browsers"
    conflated offered with installed.
  - **The machine says Chrome, unambiguously:**

    | Evidence | Result |
    | --- | --- |
    | default `https` handler | `com.google.chrome` |
    | default `http` handler | `com.google.chrome` |
    | Chrome profile | exists, last modified Sep 16 2026 |
    | Brave profile | **no profile directory -- never launched** |
    | Firefox profile | **no profile directory -- never launched** |

    Brave and Firefox have no `Application Support` profile at all, which is what
    a browser that has never been opened once looks like. This lines up with the
    separate open question about the eight casks installed by mistake, which
    includes both of them.
  - **And Chrome is the worst browser for this particular extension set.** Two of
    the three requested extensions are degraded or obsolete there:

    | Extension | On Chrome | On Firefox / Brave |
    | --- | --- | --- |
    | uBlock Origin | **gone.** Removed from the Web Store in late 2024; MV2 disabled July 2025; Chrome 151 removed the last MV2 code paths July 2026. Only uBlock Origin **Lite** remains, capped at 30k static / 5k dynamic rules | full version works |
    | Privacy Badger | available and maintained, heuristic rather than list-based, so MV3 hurts it least | available |
    | Decentraleyes | listed (v3.0.2, Aug 2026) but its effectiveness under MV3 is disputed -- the blocking `webRequest` path it relied on is deprecated. Modern browsers also partition the HTTP cache by top-level domain, which natively covers the tracking vector it was built for | available |

    So the choice is: the browser actually in use (Chrome), accepting uBlock
    Origin Lite and a probably-inert Decentraleyes; or a browser never yet opened
    (Brave/Firefox), getting the full set.
  - Note for Brave: its mechanism is not the Chrome Web Store at all. Brave hosts
    four MV2 extensions (uBlock Origin, AdGuard, NoScript, uMatrix) on its own
    infrastructure, installable from Brave's own extensions settings page, and
    calls this best-effort rather than permanent. An `ExtensionInstallForcelist`
    pointing at Web Store IDs would not be how uBlock Origin gets there.
  - **Second blocker, new: this Mac is unmanaged, and these are enterprise
    policies.** `/Library/Managed Preferences/` does not exist, and
    `profiles list -type configuration` reports no configuration profiles for
    this user. `ExtensionSettings` / `ExtensionInstallForcelist` are policies
    whose macOS format is confirmed as a plist under the `com.google.Chrome`
    domain (checked against Chrome Enterprise policy docs, 2026-09-17).
    **Not verified: whether a plain user-domain `defaults write
    com.google.Chrome ...` is honored as a mandatory policy on an unmanaged Mac,
    or whether it needs a root-owned file under `/Library/Managed Preferences`
    or a configuration profile.** Proving it means launching Chrome and reading
    `chrome://policy`, which force-installs extensions into the daily browser, so
    it was not done unasked. If it needs the managed path, this becomes a
    `sudo`-scoped tab and inherits the same prerequisite as `security.sh`.
  - To unblock, in order: name the browser, then settle whether the policy has to
    be system-scoped.

- [ ] Confirm whether a `gitconfig` CLI is wanted in addition to `gitignore`.
  - Resolved for now as `gitignore` only. Checked against the npm registry on
    2026-09-13:

    | Package | Version | `bin` | Verdict |
    | --- | --- | --- | --- |
    | `gitignore` | 0.7.0 | `gitignore` | CLI. "Automatically fetch gitignore files for any project type" |
    | `gitconfig` | 2.0.8 | **absent** | Library (`main: lib`), a wrapper for `git config`. No command is installed |

  - The behavior described -- generating a config from a project type passed to
    it -- is what `gitignore` does. The npm package named `gitconfig` is
    `teambit/node-gitconfig`, last published 2018, and installing it globally
    provides no executable at all.
  - Reopen this if the intended tool is not from npm. Nothing in an npm search
    for `gitconfig` is a project-type config generator with a CLI, so it would
    need naming or a source URL.

- [ ] Display Advanced, and General > AutoFill and Passwords.
  - **Scope given by the owner 2026-09-17: "disable everything" in both panes.**
    That retires the blocker recorded here previously, which was that no
    document named a wanted state for either pane. It does not retire the whole
    task, because "everything" is a state without a list: neither pane's toggles
    can be enumerated from this machine yet, for the two separate reasons below.
    The remaining work is enumeration, not requirements.
  - Acceptance criteria, now that a target state exists: every toggle present in
    Displays > Advanced and in General > AutoFill and Passwords reads back off,
    and the two panes show them off after being reopened. The read-back is the
    part that needs Full Disk Access.
  - **AutoFill: the TCC claim is confirmed, 2026-09-17.** It is not a permissions
    problem and cannot be worked around by fixing modes:

    | Check | Result |
    | --- | --- |
    | `defaults read com.apple.Safari` | `Domain ... does not exist` (resolved into the container) |
    | `ls -l` the container plist | exists, **5.3K, `-rw-------`, owner `rogue`** |
    | `id -un` | `rogue` -- so the owner has read permission |
    | `head -c 8` on it | `Operation not permitted` |
    | `plutil -p` | `NSCocoaErrorDomain Code=257` / `NSPOSIXErrorDomain Code=1` |

    Owning a file with `rw-------` and still being refused is the TCC signature,
    identical to the Finder sidebar item above. Full Disk Access for the terminal
    is a hard prerequisite.
  - **Display Advanced: no domain has ever been written.**
    `defaults read com.apple.universalcontrol` reports `Domain ... does not
    exist`, so the Universal Control toggles in that pane are all at their
    defaults and there is no existing plist to read key names out of. Confirming
    them means changing a toggle in the GUI and diffing, which needs the scope
    decision first to know which toggle is even relevant.
  - Note: this item and the Finder sidebar share the same Full Disk Access
    prerequisite, so one grant unblocks the TCC half of both.
  - To unblock: grant Full Disk Access to the terminal. That is now the only
    outstanding prerequisite -- it makes the Safari container readable, which
    turns "disable everything" in the AutoFill pane into an enumerable list, and
    it is the same grant the Finder sidebar item needs. Display Advanced also
    needs one GUI toggle flipped and diffed to learn the key names, because the
    domain does not exist until something writes it.

## Completed

Thirty tasks, each verified on this machine before being moved here. The
investigation notes that used to sit under every entry were collapsed on
2026-09-19: the reasoning that still matters lives in comments next to the code
it explains, and the measured findings that generalise are in `AGENTS.md`.

Two entries below were later reversed or superseded; both say so in place.

### Menu and installer

- [x] Stop a failing tab script from deleting the install directory.
      `core/main.sh` ran `bash "$path"` unguarded under `set -euo pipefail`, so
      any non-zero tab exit aborted the menu and fired the cleanup trap. The
      invocation is guarded and the two `exit 1` calls in `common-script.sh`
      became returns.
- [x] Stop an empty category directory from deleting the install directory.
      The same disaster by a different route: under bash 3.2 and `set -u`,
      expanding an empty array is an unbound-variable error, not an empty list.
- [x] Stop `clear` from aborting the menu when the terminal cannot be driven.
      `clear` exits 1 with `TERM` unset *and* with `TERM=dumb`, which is wider
      than the original note claimed. The failure is now swallowed.
- [x] Keep the install directory when the menu exits abnormally. The cleanup
      trap now deletes only on status 0, which ends the whole family of crashes
      above rather than the next instance of it.
- [x] Fix `SC2155` on `start.sh:8`. A real bug, not a style warning:
      `export TEMP_DIR=$(mktemp -d)` reports the status of `export`, so a failed
      `mktemp` left `TEMP_DIR` empty and aimed the download at the filesystem
      root.

### Homebrew

- [x] Bring `common-script.sh` under shellcheck. `#!/bin/zsh -e` made the one
      library every tab depends on the only file the linter refused (`SC1071`).
- [x] Resolve Homebrew without depending on a sourced profile. A tab is a
      non-login shell that never reads `~/.zprofile`, so `command -v brew`
      failed on a machine that has Homebrew and the installer ran again per
      entry. It is now located by path and exported once from `core/main.sh`.
- [x] Make Homebrew non-interactive and batch the installs. Added the
      `HOMEBREW_NO_*` exports, `sudo_keepalive`, and one `brew install` per
      batch instead of one process per package.
- [x] Fix the five `printf` calls that print their own placeholder. The `%s`
      and `%d` sat in the argument rather than the format, so every error
      message in `get_file_from_web` and `office.sh` was garbled. `shellcheck`
      does not catch this: `SC2059` fires on the opposite mistake.

### Preference engine

- [x] Build the preference engine. New `core/tabs/settings-lib.sh`:
      `apply_settings` for `domain | key | type | value | owner` rows,
      `verify_setting` for the structural cases, a read-back on every write, and
      one restart per owning service.
- [x] Add the `bats` suite for the engine. `test/settings-lib.bats`, with
      `defaults`, `killall` and `sudo` stubbed on `PATH` so the suite changes
      nothing on the machine running it.
- [x] Reject a manifest row with an empty value column. It was the one typo the
      engine reported as success, because `defaults read` returns the empty
      string both for a key set to "" and for a key that is not there.
- [x] Give the engine a first-class `-currentHost` scope. Some keys exist only
      in the ByHost plist, so a row without the prefix wrote a key nothing
      reads and then read it straight back and reported success.

### System tabs

- [x] Convert the three existing settings scripts to manifests. This removed
      the `sudo defaults write` calls, which had been writing root's
      preferences and never touching the logged-in account.
- [x] Rewrite `fix-finder.sh` for the full settings list. Manifest grew from 10
      rows to 19, plus `FavoriteTagNames` as explicit code.
- [x] Add `desktop-dock.sh`. Ten rows across two domains and two owners, plus
      `persistent-apps` as explicit code, written before `apply_settings` so
      the engine's single Dock restart is what makes the new tile appear.
- [x] Add `input.sh` for the trackpad. Tap to click became four manifest rows
      once the `-currentHost` scope existed.
- [x] Add `display.sh`. The recorded blocker was withdrawn: `mode:N` from
      `displayplacer list` is resolvable at runtime, so nothing panel-specific
      has to be hardcoded.
- [x] Add `spotlight.sh`. No manifest at all -- both settings are structural.
      Added the `absent` comparison mode, because "every category is off" is
      the absence of `enabled = 1` across 21 entries, not a string to match.
- [x] Add `alfred.sh`. The recorded blocker was withdrawn: UUID keying is true
      of Alfred's workflows but not of either setting here. Alfred is quit
      first, because it rewrites its bundle on exit and would otherwise
      overwrite the changes seconds later.
- [x] Fix the Trash and log cleanup in `system-cleanup.sh`. `rm -rf ~/.Trash/*`
      never matched a dotfile, and the later `find` failed silently under TCC
      while the script claimed success. A denial is now reported with the Full
      Disk Access remedy.
- [x] Remove the `set -e` from `zsh-setup.sh`. One unavailable formula ended
      the tab inside `install_depend` and silently skipped the whole shell
      configuration.

### Development environment

- [x] Fix the `dev-setup.sh` shebang and array use. `#!/usr/bin/env/sh -e`
      names a path that cannot exist, `env` being a file and not a directory.
- [x] Fix `nvm` and `bun` detection, and stop sourcing `~/.zshrc`. `command -v
      nvm` can never succeed because nvm is a shell function, and bun lives in a
      directory no tab has on `PATH`, so both reinstalled on every single run.
- [x] Fix Ghostty config installation. Three defects in four lines. It also now
      moves aside the Application Support file that silently overrides the XDG
      config, which is what was actually happening on this machine.
- [x] Add `core/tabs/system/global-packages.sh`. **Superseded 2026-09-19:**
      folded into `dev-setup.sh` as `install_global_packages`. It needed bun,
      which `dev-setup.sh` installs, so as a separate menu entry it failed for
      anyone who picked it in the wrong order.
- [x] Drop the unconditional `find ~ -name .DS_Store -delete`. **Reversed
      2026-09-19 at the owner's request:** restored as `clear_ds_store`, now
      reporting how many files it removed. A folder's `.DS_Store` overrides the
      view defaults this tab writes, so removing them is what makes the list
      view actually apply everywhere.

### Repository

- [x] Bring the whole repository under the `shfmt` gate. The gate is
      `shfmt -i 4`, not `-i 4 -ci`; `-ci` would rewrite every `case` in the
      repository.
- [x] Reconcile `ROADMAP.md` against what is actually built. All six phases
      still read `Planned`, `Blocked` or `Deferred`, including three that were
      finished.
- [x] Audit the live machine against every manifest row, read-only.

### Presentation and readability, 2026-09-19

- [x] Rewrite the menu in `core/main.sh`. Entries now show a human label and a
      one-line description instead of a filename, `b` and `q` replace the
      numbered Back and Exit rows, and a rule-bounded header carries the
      breadcrumb. Colour comes from `tput` behind a stdout-is-a-terminal,
      `TERM`-is-not-dumb and at-least-eight-colours probe; rules and separators
      stay ASCII so every locale renders the same.
- [x] Add menu metadata to every tab. Each script carries `# menu:` and
      `# desc:` comment lines and each category directory a `.menu` file. Both
      are optional -- an unlabelled script has its filename title-cased -- so a
      new tab appears in the menu whether or not anyone remembered to label it.
      Filenames are unchanged.
- [x] Thin the comments across the tab scripts. The measured findings stayed,
      compressed; the investigation narratives were removed. `AGENTS.md` keeps
      the ones that generalise beyond the file they were found in.

## Completion rule

Move a task to Completed only after its acceptance criteria and validation
pass on a real Mac.

`defaults write` exits 0 for a key nothing reads, including a misspelled one, so
"the script ran" is not evidence. Read the value back as the logged-in user and
confirm the UI agrees. Record skipped validation and residual risk instead of
marking unverified work done.

## Appendix: preference keys verified on this machine

Read directly from macOS 15.7.9 (24G830), arm64, on 2026-09-13. These are
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

| Automatic Updates row | Key | Value | Observed |
| --- | --- | --- | --- |
| Check for updates | `AutomaticCheckEnabled` | `false` | **absent** -- must be created |
| Download new updates when available | `AutomaticDownload` | `false` | already `0` |
| Install macOS updates | `AutomaticallyInstallMacOSUpdates` | `false` | already `0` |
| Install application updates from the App Store | `com.apple.commerce AutoUpdate` | `false` | **domain does not exist** -- must be created |
| Install Security Responses and system files | `CriticalUpdateInstall` | `true` | already `1` |
| (same row, second key) | `ConfigDataInstall` | `true` | already `1` |

The last row of the UI is backed by two keys. Setting only one leaves the
checkbox in a mixed state that reads as enabled while half the behavior is off.

### Keyboard shortcuts

`com.apple.symbolichotkeys AppleSymbolicHotKeys`, entries `64` (show Spotlight
search) and `65` (show Finder search window), each `enabled = false` while
preserving the `value` dictionary of `{type: standard, parameters: [...]}`.
Followed by `activateSettings -u`.
