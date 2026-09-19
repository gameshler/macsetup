#!/usr/bin/env bats

setup() {
    STORE="$BATS_TEST_TMPDIR/store"
    CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    export STORE CALL_LOG DEFAULTS_BLACKHOLE=""
    mkdir -p "$STORE" "$STUB_BIN"
    : >"$CALL_LOG"

    cat >"$STUB_BIN/defaults" <<'STUB'
#!/usr/bin/env bash
echo "DEFAULTS $*" >>"$CALL_LOG"

cat >/dev/null 2>&1

host=""
if [ "$1" = "-currentHost" ]; then
    host="ByHost__"
    shift
fi

cmd="$1"; shift
domain="$1"; key="$2"
safe="${host}$(printf '%s' "$domain" | tr '/' '_')"

case "$cmd" in
write)
    flag="$3"; value="$4"
    case " $DEFAULTS_BLACKHOLE " in
    *" $key "*) exit 0 ;;
    esac
    mkdir -p "$STORE/$safe"
    if [ "$flag" = "-bool" ]; then
        case "$value" in
        true | TRUE | yes | YES | 1) value=1 ;;
        *) value=0 ;;
        esac
    fi
    printf '%s' "$value" >"$STORE/$safe/$key"
    ;;
read)
    [ -f "$STORE/$safe/$key" ] || exit 1
    cat "$STORE/$safe/$key"
    ;;
esac
exit 0
STUB

    cat >"$STUB_BIN/killall" <<'STUB'
#!/usr/bin/env bash
echo "KILLALL $*" >>"$CALL_LOG"
case "$1" in
Spotlight | sharedfilelistd) exit 1 ;;
esac
exit 0
STUB

    cat >"$STUB_BIN/sudo" <<'STUB'
#!/usr/bin/env bash
echo "SUDO $*" >>"$CALL_LOG"
[ "$1" = "-v" ] && exit 0
[ "$1" = "-n" ] && exit 0
exec "$@"
STUB

    chmod +x "$STUB_BIN"/*
    PATH="$STUB_BIN:$PATH"

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
}

manifest() {
    printf '%s\n' "$1" >"$BATS_TEST_TMPDIR/manifest.txt"
    printf '%s' "$BATS_TEST_TMPDIR/manifest.txt"
}

apply_manifest() {
    apply_settings <"$1"
}

stored() {
    cat "$STORE/$1/$2" 2>/dev/null
}

killall_count() {
    grep -c "^KILLALL $1\$" "$CALL_LOG" || true
}

@test "a correct scalar row applies and reports no failure" {
    f="$(manifest 'com.apple.dock | tilesize | int | 16 | Dock')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 1 of 1"* ]]
    [[ "$output" != *"did not apply"* ]]
    [ "$(stored com.apple.dock tilesize)" = "16" ]
}

@test "a key that lands where nothing reads is reported alone and the rest still apply" {
    export DEFAULTS_BLACKHOLE="ShowPathbarr"
    f="$(manifest 'com.apple.dock   | tilesize      | int  | 16   | Dock
com.apple.finder | ShowPathbarr  | bool | true | Finder
com.apple.finder | ShowStatusBar | bool | true | Finder')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 2 of 3"* ]]
    [[ "$output" == *"1 setting(s) did not apply"* ]]
    [[ "$output" == *"com.apple.finder ShowPathbarr"* ]]
    [[ "$output" != *"tilesize --"* ]]
    [[ "$output" != *"ShowStatusBar --"* ]]
    [ "$(stored com.apple.dock tilesize)" = "16" ]
    [ "$(stored com.apple.finder ShowStatusBar)" = "1" ]
}

@test "a boolean written as true and read back as 1 is not a false failure" {
    f="$(manifest 'com.apple.dock | autohide | bool | true | Dock')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [ "$(stored com.apple.dock autohide)" = "1" ]
    [[ "$output" == *"Applied 1 of 1"* ]]
    [[ "$output" != *"did not apply"* ]]
}

@test "a boolean written as false and read back as 0 is not a false failure" {
    f="$(manifest 'com.apple.dock | show-recents | bool | false | Dock')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [ "$(stored com.apple.dock show-recents)" = "0" ]
    [[ "$output" != *"did not apply"* ]]
}

@test "an empty owner column is accepted and restarts nothing" {
    f="$(manifest 'com.apple.AppleMultitouchTrackpad | Clicking | bool | true |
NSGlobalDomain | com.apple.swipescrolldirection | bool | false |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 2 of 2"* ]]
    [[ "$output" != *"did not apply"* ]]
    [ "$(grep -c '^KILLALL' "$CALL_LOG" || true)" -eq 0 ]
}

@test "a domain that does not exist until written applies cleanly" {
    [ ! -d "$STORE/com.apple.commerce" ]

    f="$(manifest 'com.apple.commerce | AutoUpdate | bool | false |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 1 of 1"* ]]
    [[ "$output" != *"did not apply"* ]]
    [ "$(stored com.apple.commerce AutoUpdate)" = "0" ]
}

@test "an absent key does not abort the caller under set -e" {
    export DEFAULTS_BLACKHOLE="Vanishes"
    f="$(manifest 'com.apple.commerce | Vanishes | bool | true |')"

    run bash -c "set -e
                 . '$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh'
                 apply_settings < '$f'
                 echo REACHED-END"

    [ "$status" -eq 0 ]
    [[ "$output" == *"REACHED-END"* ]]
}

@test "duplicate owners collapse to one restart" {
    f="$(manifest 'com.apple.dock   | tilesize    | int  | 16   | Dock
com.apple.dock   | autohide    | bool | true | Dock
com.apple.dock   | orientation | string | left | Dock
com.apple.finder | ShowPathbar | bool | true | Finder')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 4 of 4"* ]]
    [ "$(killall_count Dock)" -eq 1 ]
    [ "$(killall_count Finder)" -eq 1 ]
}

@test "killall against a stopped process does not abort the run" {
    f="$(manifest 'com.apple.Spotlight | SomeKey | bool | true | Spotlight
com.apple.finder | ShowPathbar | bool | true | Finder')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [ "$(killall_count Spotlight)" -eq 1 ]
    [[ "$output" == *"Applied 2 of 2"* ]]
}

@test "a stopped-process restart does not abort a caller under set -e" {
    f="$(manifest 'com.apple.Spotlight | SomeKey | bool | true | Spotlight')"

    run bash -c "set -e
                 . '$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh'
                 apply_settings < '$f'
                 echo REACHED-END"

    [ "$status" -eq 0 ]
    [[ "$output" == *"REACHED-END"* ]]
}

@test "a run with failed keys still returns 0" {
    export DEFAULTS_BLACKHOLE="A B C"
    f="$(manifest 'com.x | A | bool | true |
com.x | B | bool | true |
com.x | C | bool | true |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 0 of 3"* ]]
    [[ "$output" == *"3 setting(s) did not apply"* ]]
}

@test "the failure count is non-zero even though the status is 0" {
    export DEFAULTS_BLACKHOLE="A"
    f="$(manifest 'com.x | A | bool | true |')"

    apply_settings <"$f"

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
}

@test "every row is processed when a command in the loop reads stdin" {
    f="$(manifest 'com.x | K1 | int | 1 |
com.x | K2 | int | 2 |
com.x | K3 | int | 3 |
com.x | K4 | int | 4 |
com.x | K5 | int | 5 |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 5 of 5"* ]]
    [ "$(stored com.x K5)" = "5" ]
}

@test "each apply_settings call reports only its own failures" {
    export DEFAULTS_BLACKHOLE="KeyA KeyB"
    f1="$BATS_TEST_TMPDIR/m1.txt"
    f2="$BATS_TEST_TMPDIR/m2.txt"
    printf 'com.x | KeyA | bool | true |\ncom.x | Good1 | bool | true |\n' >"$f1"
    printf 'com.x | KeyB | bool | true |\ncom.x | Good2 | bool | true |\n' >"$f2"

    apply_settings <"$f1"
    run apply_manifest "$f2"

    [ "$status" -eq 0 ]
    [[ "$output" == *"KeyB"* ]]
    [[ "$output" != *"KeyA"* ]]
    [[ "$output" == *"1 setting(s) did not apply"* ]]
}

@test "comments and blank lines are ignored" {
    f="$(manifest '# a comment

com.apple.dock | tilesize | int | 16 | Dock
')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 1 of 1"* ]]
}

@test "an unknown type is reported and does not stop the remaining rows" {
    f="$(manifest 'com.x | Bad  | notatype | 1  |
com.x | Good | int      | 42 |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"unknown type 'notatype'"* ]]
    [ "$(stored com.x Good)" = "42" ]
}

@test "an empty manifest is a no-op" {
    f="$(manifest '')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [ "$(grep -c '^DEFAULTS' "$CALL_LOG" || true)" -eq 0 ]
}

@test "a row with an empty value column is a failure, not an applied setting" {
    f="$(manifest 'com.x | Blank | int |  | Finder')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 0 of 1"* ]]
    [[ "$output" == *"empty value, which cannot be verified"* ]]
    [ "$(grep -c '^DEFAULTS write' "$CALL_LOG" || true)" -eq 0 ]
}

@test "an empty value does not restart the row's owner" {
    f="$(manifest 'com.x | Blank | int |  | Finder')"

    run apply_manifest "$f"

    [ "$(killall_count Finder)" -eq 0 ]
}

sudo_calls() {
    grep -c "^SUDO $1" "$CALL_LOG" || true
}

@test "an absolute plist path is written and read with sudo" {
    f="$(manifest '/Library/Preferences/com.apple.SoftwareUpdate | AutomaticCheckEnabled | bool | false |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 1 of 1"* ]]
    [ "$(sudo_calls 'defaults write /Library/Preferences/com.apple.SoftwareUpdate')" -eq 1 ]
    [ "$(sudo_calls 'defaults read /Library/Preferences/com.apple.SoftwareUpdate')" -eq 1 ]
}

@test "an unqualified domain never gets sudo" {
    f="$(manifest 'com.apple.finder | ShowPathbar | bool | true | Finder')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [ "$(grep -c '^SUDO defaults' "$CALL_LOG" || true)" -eq 0 ]
}

@test "a mixed manifest only sudoes the system-scoped row" {
    f="$(manifest '/Library/Preferences/com.apple.SoftwareUpdate | AutomaticDownload | bool | false |
com.apple.dock | tilesize | int | 16 | Dock')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 2 of 2"* ]]
    [ "$(grep -c '^SUDO defaults' "$CALL_LOG" || true)" -eq 2 ]
    [ "$(grep -c '^SUDO defaults.*com.apple.dock' "$CALL_LOG" || true)" -eq 0 ]
}

@test "a -currentHost row is written and read back with the flag" {
    f="$(manifest '-currentHost NSGlobalDomain | com.apple.mouse.tapBehavior | int | 1 |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 1 of 1"* ]]
    [[ "$output" != *"did not apply"* ]]
    [ "$(grep -c '^DEFAULTS -currentHost write NSGlobalDomain' "$CALL_LOG" || true)" -eq 1 ]
    [ "$(grep -c '^DEFAULTS -currentHost read NSGlobalDomain' "$CALL_LOG" || true)" -eq 1 ]
}

@test "the -currentHost prefix is stripped before the domain reaches defaults" {
    f="$(manifest '-currentHost NSGlobalDomain | com.apple.mouse.tapBehavior | int | 1 |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [ "$(stored ByHost__NSGlobalDomain com.apple.mouse.tapBehavior)" = "1" ]
    [ "$(grep -c 'write -currentHost NSGlobalDomain' "$CALL_LOG" || true)" -eq 0 ]
    [ "$(grep -c 'read -currentHost NSGlobalDomain' "$CALL_LOG" || true)" -eq 0 ]
    [ "$(grep -c '^DEFAULTS -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1$' "$CALL_LOG" || true)" -eq 1 ]
}

@test "a per-host write does not land in the plain domain" {
    f="$(manifest '-currentHost NSGlobalDomain | com.apple.mouse.tapBehavior | int | 1 |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [ ! -f "$STORE/NSGlobalDomain/com.apple.mouse.tapBehavior" ]
}

@test "a plain row and a per-host row of the same key are independent" {
    f="$(manifest 'NSGlobalDomain | com.apple.mouse.tapBehavior | int | 0 |
-currentHost NSGlobalDomain | com.apple.mouse.tapBehavior | int | 1 |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 2 of 2"* ]]
    [[ "$output" != *"did not apply"* ]]
    [ "$(stored NSGlobalDomain com.apple.mouse.tapBehavior)" = "0" ]
    [ "$(stored ByHost__NSGlobalDomain com.apple.mouse.tapBehavior)" = "1" ]
}

@test "a per-host row never gets sudo" {
    f="$(manifest '-currentHost NSGlobalDomain | com.apple.mouse.tapBehavior | int | 1 |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [ "$(grep -c '^SUDO defaults' "$CALL_LOG" || true)" -eq 0 ]
}

@test "a failed per-host row is reported with its scope in the label" {
    export DEFAULTS_BLACKHOLE="com.apple.mouse.tapBehavior"
    f="$(manifest '-currentHost NSGlobalDomain | com.apple.mouse.tapBehavior | int | 1 |')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"1 setting(s) did not apply"* ]]
    [[ "$output" == *"-currentHost NSGlobalDomain com.apple.mouse.tapBehavior"* ]]
}

@test "verify_setting reads the per-host scope" {
    mkdir -p "$STORE/ByHost__NSGlobalDomain" "$STORE/NSGlobalDomain"
    printf '1' >"$STORE/ByHost__NSGlobalDomain/com.apple.mouse.tapBehavior"
    printf '0' >"$STORE/NSGlobalDomain/com.apple.mouse.tapBehavior"

    run verify_setting '-currentHost NSGlobalDomain' com.apple.mouse.tapBehavior 1
    [ "$status" -eq 0 ]

    run verify_setting NSGlobalDomain com.apple.mouse.tapBehavior 1
    [ "$status" -eq 1 ]
}

@test "a mixed manifest sudoes the system row and flags only the per-host row" {
    f="$(manifest '/Library/Preferences/com.apple.SoftwareUpdate | AutomaticCheckEnabled | bool | false |
-currentHost NSGlobalDomain | com.apple.mouse.tapBehavior | int | 1 |
com.apple.dock | tilesize | int | 16 | Dock')"

    run apply_manifest "$f"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied 3 of 3"* ]]
    [ "$(grep -c '^SUDO defaults' "$CALL_LOG" || true)" -eq 2 ]
    [ "$(grep -c '^DEFAULTS -currentHost' "$CALL_LOG" || true)" -eq 2 ]
    [ "$(grep -c '^SUDO defaults -currentHost' "$CALL_LOG" || true)" -eq 0 ]
}

@test "verify_setting contains mode matches an array value" {
    mkdir -p "$STORE/com.apple.dock"
    printf '(\n    "file:///System/Applications/System%%20Settings.app/"\n)' \
        >"$STORE/com.apple.dock/persistent-apps"

    run verify_setting com.apple.dock persistent-apps 'System%20Settings.app' contains
    [ "$status" -eq 0 ]

    run verify_setting com.apple.dock persistent-apps 'Safari.app' contains
    [ "$status" -eq 1 ]
}

@test "verify_setting normalizes booleans in exact mode" {
    mkdir -p "$STORE/com.apple.finder"
    printf '1' >"$STORE/com.apple.finder/ShowPathbar"

    run verify_setting com.apple.finder ShowPathbar true
    [ "$status" -eq 0 ]

    run verify_setting com.apple.finder ShowPathbar false
    [ "$status" -eq 1 ]
}

@test "verify_setting absent mode passes when the string is not there" {
    mkdir -p "$STORE/com.apple.Spotlight"
    printf '(\n    {\n        enabled = 0;\n        name = APPLICATIONS;\n    }\n)' \
        >"$STORE/com.apple.Spotlight/orderedItems"

    run verify_setting com.apple.Spotlight orderedItems 'enabled = 1' absent
    [ "$status" -eq 0 ]
}

@test "verify_setting absent mode fails when the string is there" {
    mkdir -p "$STORE/com.apple.Spotlight"
    printf '(\n    {\n        enabled = 0;\n        name = APPLICATIONS;\n    },\n    {\n        enabled = 1;\n        name = BOOKMARKS;\n    }\n)' \
        >"$STORE/com.apple.Spotlight/orderedItems"

    run verify_setting com.apple.Spotlight orderedItems 'enabled = 1' absent
    [ "$status" -eq 1 ]

    run verify_setting com.apple.Spotlight orderedItems 'APPLICATIONS' contains
    [ "$status" -eq 0 ]
}

@test "verify_setting absent mode failures land in the shared report" {
    mkdir -p "$STORE/com.apple.Spotlight"
    printf 'enabled = 1;' >"$STORE/com.apple.Spotlight/orderedItems"

    verify_setting com.apple.Spotlight orderedItems 'enabled = 1' absent || true

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]

    run settings_report
    [[ "$output" == *"expected not to contain 'enabled = 1'"* ]]
}

@test "verify_setting absent mode treats a missing key as absent" {
    run verify_setting com.apple.Spotlight NeverWritten 'enabled = 1' absent
    [ "$status" -eq 0 ]
}

@test "verify_setting rejects an unknown mode" {
    mkdir -p "$STORE/com.x"
    printf '1' >"$STORE/com.x/K"

    run verify_setting com.x K 1 notamode
    [ "$status" -eq 1 ]

    verify_setting com.x K 1 notamode || true
    run settings_report
    [[ "$output" == *"unknown verify mode 'notamode'"* ]]
}

@test "verify_setting failures land in the shared report" {
    mkdir -p "$STORE/com.apple.finder"
    printf '1' >"$STORE/com.apple.finder/ShowPathbar"

    verify_setting com.apple.finder ShowPathbar false || true
    verify_setting com.apple.finder Missing true || true

    [ "$SETTINGS_FAILED_COUNT" -eq 2 ]

    run settings_report
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 setting(s) did not apply"* ]]
    [[ "$output" == *"com.apple.finder Missing"* ]]
}

@test "verify_value contains mode matches a substring of command output" {
    run verify_value "socketfilterfw --getglobalstate" "State = 1" \
        "Firewall is enabled. (State = 1)" contains
    [ "$status" -eq 0 ]
}

@test "verify_value contains mode fails on the opposite state" {
    run verify_value "socketfilterfw --getglobalstate" "State = 1" \
        "Firewall is disabled. (State = 0)" contains
    [ "$status" -eq 1 ]
}

@test "verify_value exact mode compares the whole value" {
    run verify_value "pmset womp" 0 0 exact
    [ "$status" -eq 0 ]

    run verify_value "pmset womp" 0 1 exact
    [ "$status" -eq 1 ]
}

@test "verify_value exact mode does not match a substring" {
    run verify_value "pmset womp" 0 10 exact
    [ "$status" -eq 1 ]
}

@test "verify_value exact mode normalizes booleans on both sides" {
    run verify_value label true 1 exact
    [ "$status" -eq 0 ]

    run verify_value label false 0 exact
    [ "$status" -eq 0 ]
}

@test "verify_value treats an empty value as a failure, not a pass" {
    run verify_value "socketfilterfw --getglobalstate" "State = 1" "" contains
    [ "$status" -eq 1 ]

    run verify_value "pmset womp" 0 "" exact
    [ "$status" -eq 1 ]
}

@test "verify_value failures carry the caller's label into the report" {
    verify_value "socketfilterfw --getglobalstate" "State = 1" \
        "Firewall is disabled. (State = 0)" contains || true
    verify_value "pmset womp" 0 1 exact || true

    [ "$SETTINGS_FAILED_COUNT" -eq 2 ]

    run settings_report
    [[ "$output" == *"socketfilterfw --getglobalstate"* ]]
    [[ "$output" == *"pmset womp -- expected '0', read back '1'"* ]]
}

@test "verify_value rejects an unknown mode" {
    run verify_value label expected actual notamode
    [ "$status" -eq 1 ]
}

@test "verify_setting still delegates through verify_value" {
    mkdir -p "$STORE/ByHost__NSGlobalDomain" "$STORE/NSGlobalDomain"
    printf '1' >"$STORE/ByHost__NSGlobalDomain/com.apple.mouse.tapBehavior"
    printf '0' >"$STORE/NSGlobalDomain/com.apple.mouse.tapBehavior"

    run verify_setting "-currentHost NSGlobalDomain" com.apple.mouse.tapBehavior 1
    [ "$status" -eq 0 ]

    run verify_setting NSGlobalDomain com.apple.mouse.tapBehavior 1
    [ "$status" -eq 1 ]
}
