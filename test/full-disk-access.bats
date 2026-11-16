#!/usr/bin/env bats

# The real probe is a file TCC refuses without Full Disk Access. Here a file
# with its permissions removed stands in for the refusal.
setup() {
    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"

    READABLE="$BATS_TEST_TMPDIR/readable"
    REFUSED="$BATS_TEST_TMPDIR/refused"
    printf 'x' >"$READABLE"
    printf 'x' >"$REFUSED"
    chmod 000 "$REFUSED"
}

@test "when the probe file can be read, reports access granted" {
    FULL_DISK_ACCESS_PROBE="$READABLE"

    run full_disk_access_granted

    [ "$status" -eq 0 ]
}

@test "when the probe file is refused, reports access missing" {
    FULL_DISK_ACCESS_PROBE="$REFUSED"

    run full_disk_access_granted

    [ "$status" -eq 1 ]
}

@test "when the probe file does not exist, reports access missing" {
    FULL_DISK_ACCESS_PROBE="$BATS_TEST_TMPDIR/absent"

    run full_disk_access_granted

    [ "$status" -eq 1 ]
}

@test "without access, a step announces that it needs Full Disk Access" {
    FULL_DISK_ACCESS_PROBE="$REFUSED"

    run check_full_disk_access "Reduce motion"

    [ "$status" -eq 1 ]
    printf '%s\n' "$output" | grep -qF "Reduce motion needs Full Disk Access"
}

@test "without access, the announcement names where to grant it" {
    FULL_DISK_ACCESS_PROBE="$REFUSED"

    run check_full_disk_access "Reduce motion"

    printf '%s\n' "$output" | grep -qF "Privacy & Security > Full Disk Access"
}

@test "with access, a step runs without any announcement" {
    FULL_DISK_ACCESS_PROBE="$READABLE"

    run check_full_disk_access "Reduce motion"

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# tccutil and sqlite3 are always stubbed here: a real `tccutil reset` changes
# the machine, and without an app id it clears every app's grant.
stub_revocation() {
    CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
    : >"$CALL_LOG"
    tccutil() {
        echo "TCCUTIL $*" >>"$CALL_LOG"
        return "${TCCUTIL_STATUS:-0}"
    }
    sqlite3() {
        [ -n "${GRANT_ROWS:-}" ] || return 1
        echo "$GRANT_ROWS"
    }
}

@test "revoking resets Full Disk Access for the named terminal only" {
    stub_revocation
    FULL_DISK_ACCESS_PROBE="$REFUSED"

    run revoke_full_disk_access com.mitchellh.ghostty

    [ "$status" -eq 0 ]
    [ "$(cat "$CALL_LOG")" = "TCCUTIL reset SystemPolicyAllFiles com.mitchellh.ghostty" ]
}

@test "without a terminal app id, revoking refuses and never calls tccutil" {
    stub_revocation

    run revoke_full_disk_access ""

    [ "$status" -eq 1 ]
    [ ! -s "$CALL_LOG" ]
}

@test "with an app id that is not a bundle identifier, never calls tccutil" {
    stub_revocation

    run revoke_full_disk_access "com.example'; DROP TABLE access; --"

    [ "$status" -eq 1 ]
    [ ! -s "$CALL_LOG" ]
}

@test "when tccutil fails, revoking reports failure" {
    stub_revocation
    TCCUTIL_STATUS=64
    FULL_DISK_ACCESS_PROBE="$REFUSED"

    run revoke_full_disk_access com.mitchellh.ghostty

    [ "$status" -eq 1 ]
}

@test "when the grant is still recorded after the reset, revoking reports failure" {
    stub_revocation
    FULL_DISK_ACCESS_PROBE="$READABLE"
    GRANT_ROWS=1

    run revoke_full_disk_access com.mitchellh.ghostty

    [ "$status" -eq 1 ]
}

@test "when the probe still reads but no grant is recorded, revoking succeeds" {
    stub_revocation
    FULL_DISK_ACCESS_PROBE="$READABLE"
    GRANT_ROWS=0

    run revoke_full_disk_access com.mitchellh.ghostty

    [ "$status" -eq 0 ]
}

@test "when the grant cannot be read back at all, revoking reports failure" {
    stub_revocation
    FULL_DISK_ACCESS_PROBE="$READABLE"
    GRANT_ROWS=""

    run revoke_full_disk_access com.mitchellh.ghostty

    [ "$status" -eq 1 ]
}
