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

- [ ] Re-baseline every settings tab in `core/tabs/system/` against macOS 27.
  - `SPEC.md:108` still targets macOS 15 (Sequoia) and the appendix records
    15.7.9 keys. Both need updating to 27.2.1 once each key is re-verified.
  - Observed already on 27.2.1:

    | Tab | Observation |
    | --- | --- |
    | `remove-animations.sh` | `reduceMotion` is **absent** from `com.apple.universalaccess`; see the reduce motion task |
    | `spotlight.sh` | `orderedItems` still reads all 21 categories `enabled = 0`, but the domain now also carries `DisabledUTTypes`, `EnabledPreferenceRules` and `PasteboardHistory*` keys the tab does not touch |
    | `spotlight.sh` | hotkeys `64` and `65` read `enabled = false` with the expected parameters |
    | `system-cleanup.sh` | `com.apple.CloudSubscriptionFeatures.optIn 545129924` still exists and reads `0` |
    | `security.sh` | `womp` reads `0` on both battery and AC |
    | `alfred.sh` | the machine-local hotkey directory did not exist when the tab ran; see the Alfred task |

  - **Read-only audit of every manifest row, 2026-11-16: 56 of 58 read back
    as specified.** Every row in `desktop-dock.sh`, `fix-finder.sh`,
    `input.sh` and `system-cleanup.sh` holds, and so does every animation row
    except one. The two failures:

    | Row | Read back |
    | --- | --- |
    | `com.apple.universalaccess reduceMotion` | key absent (TCC; see the reduce motion task) |
    | `/Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled` | key absent, while the other five Software Update keys and `com.apple.commerce AutoUpdate` read correctly |

    `AutomaticCheckEnabled` is the key the appendix recorded as absent and
    needing creation. Either the row never took or `softwareupdated` removed
    it on 27; find out which before writing it again.
  - Also read back: the firewall reports `State = 1`, and the Dock holds only
    System Settings.
  - A row that reads back is not the same as the UI agreeing. The Finder
    complaints below are about settings no manifest row covers.
  - `display.sh` is confirmed fine by the owner, 2026-11-16, and needs no work.
  - Still to check: the Spotlight and Alfred structural checks against the UI,
    and the sidebar file. Neither
    `com.apple.LSSharedFileList.FavoriteItems.sfl3` nor `.sfl4` exists by name
    on 27.2.1; `stat` on a known path worked through TCC on 15, so the file
    has been renamed or moved.
  - ~~`AGENTS.md` cites `core/main.sh:49` and `:53` for the menu discovery
    rule.~~ Updated to `core/main.sh:269` and `:273` with the consolidation.
  - Acceptance criteria: every manifest row and structural check reads back on
    27.2.1, and the appendix and `SPEC.md` name 27.2.1 as the verified version.

- [ ] Fix the Alfred cmd+space hotkey not applying.
  - **Status: fixed 2026-11-16, awaiting the owner's live check.** Do not mark
    this complete until a run with this Mac's local folder moved aside binds
    cmd+space and the hotkey opens Alfred without visiting its preferences.
  - Confirmed read-only on this machine before the change: `prefs.json` was
    written at 23:48 on 2026-11-15 with `localhash`
    `a893a2b86f5f53d443d65a4acf51e39fe0ffa663`, three minutes before the tab
    ran, and the hand-set `local/<hash>/hotkey/prefs.plist` holds exactly
    `default = { key = 49; mod = 1048576; string = " " }`, which is what the
    step writes.
  - `local_prefs_dir` now returns `local/<localhash>` from `prefs.json`
    instead of the first folder that happens to exist, and `set_hotkey`
    creates it. Choosing by id also stops a synced bundle with several Macs'
    folders getting the hotkey written into the wrong one. The id becomes a
    path, so anything but 40 lowercase hex characters is refused.
  - `test/alfred.bats`, six tests against a scratch `HOME` with real
    `plutil`: no local folder yet, binds cmd+space; another Mac's folder
    present, writes only this Mac's; no `prefs.json`, fails with the launch
    hint, creates nothing, and the failure reaches the report; a 40-character
    id that climbs out of `local/`, and a short hex id, are each refused with
    the scratch tree unchanged. Each guard was mutation-checked; the first
    version of the traversal test passed without the hex guard, because the
    length check refused it first, and was lengthened to 40 characters.
    `bats test/` 81 of 81; `shellcheck`, `shfmt` and `typos` clean.
  - Not changed: the bundle path is still the default one, not `current` from
    `prefs.json`. A Mac syncing its Alfred preferences through Dropbox or
    iCloud keeps them elsewhere and the step reports no bundle; that needs
    its own change if the owner ever syncs.
  - The owner had to set the hotkey by hand in Alfred after running the tab.
  - Likely cause, from file timestamps: the tab wrote the web search prefs at
    23:51:04 on 2026-11-15, but
    `preferences/local/a893a2b86f5f53d443d65a4acf51e39fe0ffa663/` was created
    at 00:15:58, together with its `hotkey/prefs.plist` -- the manual change.
    Alfred does not create the machine-local directory on first launch, only
    when a local preference is first changed. `local_prefs_dir` found nothing
    and `set_hotkey` took its "launch Alfred once" branch, even though Alfred
    had been launched.
  - The hash is available without the directory: `prefs.json` in
    `~/Library/Application Support/Alfred/` carries `localhash`. Create the
    directory from that rather than requiring it to exist.
  - Second cause: Spotlight was disabled at 00:14:10, after the Alfred tab
    ran, so cmd+space was still held by Spotlight at the time. **Fixed by
    the consolidation:** Optimize Settings runs Spotlight before Alfred, and
    a test fails if that order changes.
  - Acceptance criteria: on a fresh Alfred install, one run binds cmd+space
    and the hotkey works without opening Alfred Preferences.

- [ ] Fix reduce motion not applying.
  - **Status, 2026-11-16: applied by the owner's Optimize Settings run, UI
    check outstanding.** The run had Full Disk Access for the session, and
    `com.apple.universalaccess reduceMotion` now reads `1`, with the plist
    last written at 04:39. AppKit agrees:
    `NSWorkspace.accessibilityDisplayShouldReduceMotion` returns `true`, while
    `accessibilityDisplayShouldReduceTransparency`, whose key is absent,
    returns `false` as the control. The domain's `History` has no
    reduce motion entry, which fits a `defaults write` rather than a click.
  - The decision below is made: the owner chose Full Disk Access for the
    session, and Optimize Settings names reduce motion up front when the grant
    is missing. No code change was needed.
  - The control still exists on 27.2.1 at **Accessibility > Display > Reduce
    motion** (`display.reduceMotion` in the Accessibility settings
    extension's strings), next to Reduce transparency, which is a different
    setting.
  - Do not mark complete until the owner confirms that toggle shows on.
  - `defaults read com.apple.universalaccess reduceMotion` reports the key does
    not exist. The plist carries `com.apple.macl`, and the terminal lacks Full
    Disk Access, so this is the TCC case `AGENTS.md` already describes: the
    write is refused and the row should already be reported as failed.
  - Decide between requiring Full Disk Access for this step and reporting it as
    a manual step. Either way the tab has to say so up front, not only in the
    failure list.
  - Acceptance criteria: `reduceMotion` reads `1` and Accessibility > Display >
    Reduce motion shows on, or the run names it as a manual step with the
    remedy.

- [ ] Disable everything in Spotlight.
  - The owner reports that not everything in the Spotlight pane is off.
    `orderedItems` reads all off, so the remainder is in the macOS 26+ pane
    sections the tab never wrote -- the new domain keys above suggest results
    from apps, clipboard history and related content. Keys not yet identified.
  - **Controls on 27.2.1, from the English strings of
    `SpotlightPreferenceExtension.appex`, 2026-11-16:** the Search results
    categories (`orderedItems`, already written), and four toggles nothing
    writes yet: Results from Clipboard, Show Related Content, Help Apple
    Improve Search, and content from Apple partners in searches and Look Up.
    Search Privacy, Hidden File Types, Quick Keys and Delete Search History
    are lists or actions, not toggles.
  - The binary is Swift and names none of the four keys as a plain string.
    Candidates read so far: `com.apple.Spotlight` carries only
    `PasteboardHistoryVersion`, `PasteboardHistoryNeedsWipe`, empty
    `DisabledUTTypes` and `EnabledPreferenceRules`, and `ModelName = Canned`;
    `com.apple.spotlight.settings` and `com.apple.lookup.shared` do not exist.
    The pane's own containers under `~/Library/Containers/` are refused
    without Full Disk Access, so the keys may live there.
  - **Diff result, 2026-11-16.** Read-only XML snapshots of every plist in
    `~/Library/Preferences` and `ByHost`, before and after the owner turned
    off Show Related Content, Help Apple Improve Search, results from system
    items and Results from Clipboard:

    | Toggle | Key |
    | --- | --- |
    | Show Related Content | `com.apple.Spotlight EnabledPreferenceRules` gains `Custom.relatedContents` |
    | Results from system items | the same array gains `System.applications`, `System.files`, `System.folders`, `System.iphoneApps`, `System.menuItems` |
    | Help Apple Improve Search | `com.apple.assistant.support "Search Queries Data Sharing Status"`, created as integer `2` |
    | Results from Clipboard | **nothing readable changed** |

    A listed rule hides its results despite the key's name, which is why all
    21 `orderedItems` categories read off while system items still showed.
    Every other changed file held only timestamps or counters.
  - **Built, 2026-11-16:** `hide_spotlight_rules` adds each missing rule with
    `-array-add`, never rewriting the array, and reads each back through
    `verify_value`; the data sharing key is a manifest row.
    `test/spotlight.bats`, five tests against a stubbed `defaults`, each
    guard mutation-checked. Live, against the owner's already-set domain:
    all six rules verified and the array left byte-identical. `bats test/`
    86 of 86.
  - Not proven: that rules written by `defaults` take effect on a Mac where
    the pane never wrote them. Check on the next fresh install, or by
    clearing the array and rerunning.
  - **Open: Results from Clipboard.** Its state is not in any file readable
    without Full Disk Access; no file under `~/Library` outside the caches
    changed apart from those above. It is most likely in the pane's
    container. Next step: repeat the diff from a terminal with the grant,
    including `~/Library/Containers/com.apple.Spotlight-Settings.extension`
    and `~/Library/Group Containers`.
  - **Open: content from Apple partners.** The owner did not mention it;
    confirm whether the pane shows it on 27.2.1 and whether it is off.
  - Acceptance criteria: every toggle in the Spotlight pane reads back off.

- [ ] Disable all Siri suggestions.
  - Candidate domains on this machine: `com.apple.suggestions`,
    `com.apple.siri.sirisuggestions`, `com.apple.assistant.support`
    (`Assistant Enabled` already reads `0`). Keys for the per-app "Show
    suggestions from" list are not yet identified.
  - **Controls on 27.2.1, from the English strings of
    `SiriPreferenceExtension.appex`, 2026-11-16:** the only suggestion
    settings are the per-app sheet behind "Siri Suggestions & Privacy…", with
    two checkboxes per app: "Show Siri Suggestions in application" and
    "Learn from this application" (Contacts and FaceTime word the first one
    differently).
  - Read-only state: `com.apple.suggestions` holds an empty
    `AppCanShowSiriSuggestionsBlacklist`, so the "show" list is likely a
    list of bundle ids that are turned off. No "learn" list exists yet,
    presumably because none has been unchecked. `com.apple.siri.sirisuggestions`
    holds only `osInstalledDates`.
  - **Diff result, 2026-11-16,** after the owner unchecked both boxes for
    every app in the sheet: `com.apple.suggestions
    AppCanShowSiriSuggestionsBlacklist` went from empty to the eleven apps
    the sheet lists, `com.apple.iBooksX`, `com.apple.iCal`,
    `com.apple.AddressBook`, `com.apple.FaceTime`, `com.apple.mail`,
    `com.apple.Maps`, `com.apple.MobileSMS`, `com.apple.news`,
    `com.apple.podcasts`, `com.apple.reminders` and `com.apple.Safari`. Every
    other changed file held only window positions, counters or timestamps.
  - **Built, 2026-11-16:** `core/settings/siri.sh` runs as "Siri
    suggestions" after Spotlight, through the new `ensure_listed` engine
    helper that Spotlight's hide rules now share. `test/siri.bats`, two
    tests; the helper's guards were mutation-checked through both suites.
    Live, against the owner's already-set domain: all eleven verified and the
    array left byte-identical. `bats test/` 88 of 88.
  - **Open: "Learn from this application".** Unchecking it changed nothing
    readable. Either it is stored where Full Disk Access is needed, or the
    checkbox was unavailable because Siri is off (`Assistant Enabled = 0`);
    the owner to confirm which.
  - Not proven: that a list written by `defaults` takes effect on a Mac where
    the pane never wrote it. Check on the next fresh install.
  - Acceptance criteria: Siri > Suggestions and per-app suggestion toggles all
    read off.

- [ ] Disable Apple Intelligence and other AI features, and remove what can be
  removed.
  - Owner, 2026-11-16: disable everything; removing is better wherever it is
    possible.
  - Present on this machine: `/System/Applications/Image Playground.app`,
    `Siri AI.app` and `Siri.app`, plus domains `com.apple.generativesearch`,
    `com.apple.GenerativeFunctions.agentstored`,
    `com.apple.GenerativeModels.AgentSessionKit`,
    `com.apple.generativepartnerservicesettings` and
    `com.apple.AppleIntelligenceReport`.
  - **The system apps cannot be removed.** They live on the sealed system
    volume, and removing them means disabling SIP, which contradicts the
    security goal. The deliverable is disable, not remove, for anything under
    `/System`.
  - **Origin confirmed, 2026-11-16:** `Microsoft 365 Copilot Shim.app` is
    signed by Microsoft (Team ID `UBF8T346G9`) and installed by the Office
    package as its own receipt, `com.microsoft.m365copilot.shim` 0.2607.0601,
    next to the Word, Excel and PowerPoint receipts. Nothing else depends on
    it.
  - **Built, 2026-11-16:** `core/settings/ai.sh` runs as "Apple Intelligence"
    after Siri suggestions. It owns the `CloudSubscriptionFeatures.optIn
    545129924` row, moved from Cleanup, and removes the shim with `sudo rm`
    of its exact path, forgetting the receipt only once the app is confirmed
    gone. `test/ai.bats`, three tests, each guard mutation-checked; `bats
    test/` 91 of 91. Not run live: it needs the owner's sudo session.
  - Already off, read-only: `545129924` reads `0`, `Assistant Enabled` reads
    `0`, and the ChatGPT extension reports `isEnabled = 0` in
    `com.apple.generativepartnerservicesettings`. The pane's AI controls on
    27.2.1 are the Apple Intelligence switch and an Extensions group holding
    ChatGPT.
  - Open: the Office installer adds the shim again on reinstall, and the
    full-suite path passes no choices file. The core path already deselects
    `com.microsoft.defender.shim`; the shim's choice identifier needs
    `installer -showChoicesXML` on the downloaded package before it is added.
    Whether Microsoft AutoUpdate restores it is unknown.
  - Model downloads: `/System/Library/AssetsV2` holds 4.2 GB, but the
    `UAF_FM_*` generative model folders are TCC-refused, so they cannot be
    sized here. MobileAsset manages them; deleting them by hand is not safe
    and they would return. Turning Apple Intelligence off is what releases
    them.
  - Also in scope: ChatGPT and other partner extensions, writing tools, and
    the on-device model downloads, which turning Apple Intelligence off should
    release. Keys not yet identified.
  - Acceptance criteria: Apple Intelligence & Siri shows everything off, and no
    third-party AI app remains in `/Applications`.

- [ ] Disable Tips.
  - `com.apple.tipsd` exists; notification and suggestion keys not yet
    identified. `Tips.app` is a system app and cannot be removed.
  - **Read-only, 2026-11-16:** every `TPS*` key in `com.apple.tipsd` is
    daemon state (counts, dates, pending tips), not a setting. `tipsd` logs
    "Skip checking notification. Notification disabled %d", so it obeys the
    app's notification permission: the switch is Notifications > Tips >
    Allow notifications.
  - That switch is not readable here. `com.apple.ncprefs` no longer exists on
    27.2.1, and notification settings sit in
    `~/Library/Group Containers/group.com.apple.usernoted`, which is
    TCC-refused without Full Disk Access.
  - Next: with Full Disk Access, take XML snapshots of that container's
    `Library/Preferences`, have the owner turn Tips off in the pane, and diff.
    Writing the key would also need Full Disk Access, so Tips would join
    `FULL_DISK_ACCESS_STEPS`. The Spotlight clipboard diff needs the same
    session.
  - Acceptance criteria: no Tips notifications, Tips notifications off in the
    Notifications pane.

- [ ] Turn off four Battery options.
  - Scope from the owner, 2026-11-16, and nothing else in the pane:

    | Battery > Options row | Off is | Mapped by toggle-and-diff, 2026-11-17 |
    | --- | --- | --- |
    | Slightly dim the display on battery | `pmset -b lessbright 0` | on wrote `lessbright 1` on battery |
    | Prevent automatic sleeping on power adapter when the display is off | `pmset -c sleep 1` | on wrote AC `sleep 0`; off wrote back exactly `1` |
    | Wake for network access | `womp 0` | already set by `security.sh` |
    | Optimize video streaming while on battery | `/Library/Preferences/.GlobalPreferences com.apple.coremedia.optimizeVideoStreamingOnBattery` false | not `pmset`; off writes `false` rather than deleting the key |

  - **Built, 2026-11-17:** `core/settings/battery.sh` runs as "Battery" after
    Security. Each `pmset` row is read back from its own section of
    `pmset -g custom`, because `pmset -g` shows only the source in use; the
    video row goes through `apply_settings`. `test/battery.bats`, four tests,
    six mutations killed; `bats test/` 95 of 95. Not run live: it needs the
    owner's sudo session. All three rows already read off after the owner's
    toggle back.
  - The AC row forces `sleep 1`, the value the pane writes, so a custom
    system sleep timer on AC would be reset to 1.
  - Acceptance criteria: all four rows show off or Never in Battery > Options,
    and each mapped `pmset` key reads back as specified.

- [ ] Disable every app in Menu Bar > Allow in the menu bar, every system
  control, and suggestions in the Control Gallery.
  - Owner, 2026-11-17: also turn off Show suggestions in Control Gallery.
  - The 13 KB `ControlCenterDisplayableChronoControlsProviderConfiguration`
    blob is a catalog of the Control Center controls, not a setting.
  - **Mapped by the owner setting the pane by hand and diffing, 2026-11-17:**

    | Change | Key |
    | --- | --- |
    | Control Gallery suggestions off | `-currentHost com.apple.controlcenter ShowSuggestions` false |
    | Battery, Display, FocusModes, NowPlaying, ScreenMirroring, Sound, Spotlight, Timer, WiFi set to Don't Show | `-currentHost com.apple.controlcenter <module>` int 8; absent before |
    | Spotlight icon | also `-currentHost com.apple.Spotlight MenuItemHidden` true |
    | Input menu | `com.apple.TextInputMenu visible` false and `com.apple.TextInputMenuAgent "NSStatusItem VisibleCC Item-0"` false |
    | Siri AI item (`Siri AI.app`, `com.apple.campo`) | `"NSStatusItem VisibleCC Item-0"` deleted, not set false |

  - Bluetooth has no key and was not changed; the owner keeps it.
  - **Built, 2026-11-17:** `core/settings/menu-bar.sh` runs as "Menu bar"
    after Dock and Desktop. Rows restart `ControlCenter` and
    `TextInputMenuAgent`; the Siri AI key is deleted, checked gone, and only
    then is `Siri AI` restarted, which its launch agent relaunches.
    `test/menu-bar.bats`, five tests, eight mutations killed; `bats test/`
    100 of 100. Every row already reads as written on this Mac. Not proven:
    that Control Center honours rows written while it runs on a fresh Mac.
  - Open: Allow in the Menu Bar, the third-party app list, changed no
    readable file. Its storage is `group.com.apple.controlcenter` or
    `group.com.apple.secure-control-center-preferences`, both TCC-refused
    without Full Disk Access; it joins the Tips and Spotlight clipboard diffs.
  - Acceptance criteria: every app in the list reads off and none appears in
    the menu bar after a logout.

- [ ] Set the wallpaper to solid black.
  - macOS ships a black solid colour under Wallpaper > Colors. Mechanism not
    chosen: AppleScript through System Events needs an Automation grant, and
    `desktoppr` would be a new dependency.
  - Already black on this Mac, set by hand 2026-11-15. The choice lives in
    `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`, not
    a preference domain: `AllSpacesAndDisplays` and `SystemDefault` each hold
    one `com.apple.wallpaper.choice.color` choice whose `Configuration`
    decodes to `{type = systemColor; systemColor = {black = {}}}`, and
    `Displays` and `Spaces` are empty. System Events reads `missing value`
    for it.
  - **Built, 2026-11-17:** `core/settings/wallpaper.sh` runs as "Wallpaper"
    after Menu bar. It writes that store whole, to a temp file beside it,
    converted to binary and moved into place, then restarts `WallpaperAgent`,
    which launchd relaunches. A store already black with no display or Space
    override is left untouched. With the pane's date, the generated store is
    identical to this Mac's. `test/wallpaper.bats`, seven tests, ten
    mutations killed; `bats test/` 107 of 107.
  - Not proven: that `WallpaperAgent` takes the store on restart rather than
    writing its own state back. Owner check: pick another wallpaper, run
    Optimize Settings, and see black on every display and Space.
  - Acceptance criteria: every display and every Space shows black, and it
    survives a logout.

- [ ] Harden and tune the rest of the system for performance and security.
  - Observed: FileVault is off, firewall stealth mode is off, SIP is on,
    Gatekeeper assessments are on.
  - **FileVault is out of scope.** The owner turns it on by hand, 2026-11-16.
  - Turn stealth mode on: `sudo socketfilterfw --setstealthmode on` in
    `security.sh`, read back with `--getstealthmode` through `verify_value`.
    Check the exact output string on 27.2.1 before choosing the `contains`
    text; today it prints `Firewall stealth mode is off`.
  - **Built, 2026-11-17:** `enable_stealth_mode` in `security.sh`, run right
    after `enable_firewall`. `socketfilterfw` formats the answer as `Firewall
    stealth mode is %s`, so the read-back is `exact` on `Firewall stealth mode
    is on`, which an off state cannot pass. `test/security.bats`, four tests,
    six mutations killed; `bats test/` 111 of 111. Not run live: it needs the
    owner's sudo session.
  - Read-only, 2026-11-17, already as they should be: Gatekeeper
    assessments on, SIP on, guest account off, no automatic login, crash
    report auto-submit `0`, Remote Login, Screen Sharing and File Sharing not
    loaded, firewall block-all off.
  - Owner, 2026-11-17: do the screen lock and AirPlay Receiver. Automatically
    allow downloaded signed software was explained and not chosen; it stays
    enabled.
  - **Built, 2026-11-17:** `require_password_immediately` in `security.sh`,
    after stealth mode. `sysadminctl -screenLock immediate -password -` asks
    for the login password on the terminal, not sudo, and only when
    `-screenLock status` does not already print `screenLock delay is
    immediate`; that sentence, from the binary's own format strings, is the
    read-back. Three tests, six mutations killed; `bats test/` 114 of 114.
    Not run live: it needs the owner's login password.
  - **Built, 2026-11-17:** `disable_airplay_receiver` in `security.sh`, after
    the screen lock. Diffed when the owner turned it off:
    `-currentHost com.apple.controlcenter AirplayReceiverEnabled` false,
    spelled correctly; the misspelled key older guides cite does not exist on
    27.2.1. Restarts `ControlCenter`. One test, five
    mutations killed; `bats test/` 115 of 115. Already reads `0` here.
  - Owner check on the next run: stealth mode on in Network > Firewall >
    Options, the login password asked once and Lock Screen showing
    Immediately, and AirPlay Receiver still off.
  - Acceptance criteria: stealth mode reads on and shows on in Network >
    Firewall > Options; any further hardening or performance setting is agreed
    first and read back.

- [ ] Take the sudo password before installing Homebrew.
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

- [ ] Displays > Advanced: turn off both Universal Control toggles.
  - Requested by the owner, 2026-11-16: turn off "Allow your pointer and
    keyboard to move between any nearby Mac or iPad" and "Push through the
    edge of a display to connect a nearby Mac or iPad".
  - Read-only, 2026-11-16: `com.apple.universalcontrol` still does not exist
    on 27.2.1, so neither toggle has ever been changed and there is no plist
    to read key names from.
  - Candidate keys, **unverified**: `com.apple.universalcontrol Disable` and
    `DisableMagicEdges`, both bool `true`. Confirm with a before-and-after
    diff of the owner turning the two toggles off, as for Spotlight and Siri,
    before writing either as a manifest row. The diff also shows whether a
    restart of `UniversalControl` is needed for the change to take effect.
  - Acceptance criteria: both toggles read back off and show off in Displays >
    Advanced after the pane is reopened.

- [ ] Finder sidebar: show only Applications, Documents, Downloads, Home,
  external disks and the Trash, and turn off every tag.
  - The owner's list, 2026-11-16, replacing the earlier eight-item list.
    Everything else is hidden: Recents, Shared, Desktop, AirDrop, iCloud
    Drive, Bonjour computers, connected servers, CDs and DVDs, and the Tags
    section.
  - **Trash is not a Finder Settings sidebar option** on any macOS checked so
    far. It could only appear as a favorite pointing at `~/.Trash`, if Finder
    accepts one; check that on 27.2.1 before promising it.
  - Tags: `FavoriteTagNames` reads `( )` and `ShowRecentTags` reads `0`, yet
    tags still show, so on 27.2.1 the visible tag list is stored somewhere
    these keys do not reach. Not yet identified.
  - Favorites (Recents, AirDrop, Desktop, Applications, Documents, Downloads,
    Home) live in an NSKeyedArchiver file under
    `~/Library/Application Support/com.apple.sharedfilelist/`. It was
    `com.apple.LSSharedFileList.FavoriteItems.sfl3` on 15.7.9 and exists under
    neither `.sfl3` nor `.sfl4` on 27.2.1. Reading it needs Full Disk Access,
    which the menu now grants for the session. Apply with
    `killall sharedfilelistd`; `killall Finder` does not reload it.
  - `LSSharedFileList` is a dead end: it returns an empty list and reports
    writes that never reach the file (see `AGENTS.md`). `mysides` is built on
    it and its cask is disabled. **`sbedit` is rejected by the owner,
    2026-11-16, as old and unreliable.** Any tool that edits the favorites
    file is out unless the owner approves it; the remaining route is writing
    the archive directly, which must read back the same way.
  - The Locations toggles (external disks, servers, Bonjour, CDs) may be
    `com.apple.finder` keys rather than entries in the favorites file. Find
    them by reading the domain before and after toggling each one in Finder
    Settings.
  - Acceptance criteria: the sidebar shows exactly those items and no tags,
    and both survive a logout.

## Next phase: Development environment

No open tasks.

## Blocked on a decision

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

- [ ] General > AutoFill and Passwords.
  - **Scope given by the owner 2026-09-17: "disable everything".** Displays >
    Advanced, once part of this task, has its own task in the macOS 27
    section. The remaining work is enumerating the AutoFill toggles.
  - Acceptance criteria: every toggle in General > AutoFill and Passwords reads
    back off, and the pane shows them off after being reopened.
  - **The TCC claim is confirmed, 2026-09-17.** It is not a permissions
    problem and cannot be worked around by fixing modes:

    | Check | Result |
    | --- | --- |
    | `defaults read com.apple.Safari` | `Domain ... does not exist` (resolved into the container) |
    | `ls -l` the container plist | exists, **5.3K, `-rw-------`, owner `rogue`** |
    | `id -un` | `rogue` -- so the owner has read permission |
    | `head -c 8` on it | `Operation not permitted` |
    | `plutil -p` | `NSCocoaErrorDomain Code=257` / `NSPOSIXErrorDomain Code=1` |

    Owning a file with `rw-------` and still being refused is the TCC
    signature. Full Disk Access for the terminal is a hard prerequisite.
  - To unblock: the menu now grants Full Disk Access for the session, which
    makes the Safari container readable and turns "disable everything" into an
    enumerable list.

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
