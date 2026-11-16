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
