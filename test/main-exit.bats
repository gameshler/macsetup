#!/usr/bin/env bats

# core/main.sh is copied into a scratch INSTALL_DIR whose shared library is a
# stub, and sudo is a PATH stub that only logs, so no real Homebrew install,
# password or menu is involved. Each stub library ends the run while it is
# being sourced, which is where checkPackageManager would take the password.
setup() {
    INSTALL_DIR="$BATS_TEST_TMPDIR/install"
    TEMP_DIR="$BATS_TEST_TMPDIR/temp"
    SUDO_LOG="$BATS_TEST_TMPDIR/sudo.log"
    mkdir -p "$INSTALL_DIR/core/tabs" "$TEMP_DIR" "$BATS_TEST_TMPDIR/bin"
    cp "$BATS_TEST_DIRNAME/../core/main.sh" "$INSTALL_DIR/core/main.sh"
    : >"$INSTALL_DIR/core/tabs/settings-lib.sh"
    : >"$SUDO_LOG"

    printf '#!/bin/sh\necho "sudo $*" >>"%s"\n' "$SUDO_LOG" >"$BATS_TEST_TMPDIR/bin/sudo"
    chmod +x "$BATS_TEST_TMPDIR/bin/sudo"
    export INSTALL_DIR TEMP_DIR
    PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# stub_library <body>: the shared library defines the real end_sudo_session,
# taken from common-script.sh, then runs <body>.
stub_library() {
    local real
    real="$(awk '/^end_sudo_session\(\) \{/{f=1} f{print} f&&/^}/{exit}' \
        "$BATS_TEST_DIRNAME/../core/tabs/common-script.sh")"
    [ -n "$real" ] || {
        echo "end_sudo_session not found in common-script.sh" >&2
        return 1
    }
    printf '%s\n%s\n' "$real" "$1" >"$INSTALL_DIR/core/tabs/common-script.sh"
}

@test "when the shared library exits while sourced, drops sudo and removes only TEMP_DIR" {
    stub_library 'exit 1'

    run bash "$INSTALL_DIR/core/main.sh"

    [ "$status" -eq 1 ]
    grep -qx "sudo -k" "$SUDO_LOG"
    [ ! -e "$TEMP_DIR" ]
    [ -d "$INSTALL_DIR" ]
}

# Closing the window sends HUP.
@test "when the window closes while the shared library is sourced, still drops sudo" {
    stub_library 'kill -HUP $$; sleep 2'

    run bash "$INSTALL_DIR/core/main.sh"

    [ "$status" -eq 129 ]
    grep -qx "sudo -k" "$SUDO_LOG"
    [ ! -e "$TEMP_DIR" ]
}

@test "a second signal during cleanup does not cut it short" {
    stub_library 'sudo() { kill -TERM $$; command sudo "$@"; }; exit 1'

    run bash "$INSTALL_DIR/core/main.sh"

    [ "$status" -eq 1 ]
    grep -qx "sudo -k" "$SUDO_LOG"
    [ ! -e "$TEMP_DIR" ]
}

# With a session held, cleanup writes before it removes anything.
@test "with the terminal gone, cleanup still removes TEMP_DIR" {
    stub_library 'SUDO_KEEPALIVE_STARTED=1; exit 1'

    bash "$INSTALL_DIR/core/main.sh" >&- 2>/dev/null || true

    grep -qx "sudo -k" "$SUDO_LOG"
    [ ! -e "$TEMP_DIR" ]
}

# TEMP_DIR comes from start.sh. Without it this is not the disposable unpack,
# so even a clean exit must not delete INSTALL_DIR.
@test "without TEMP_DIR, a clean exit keeps INSTALL_DIR" {
    stub_library 'exit 0'
    unset TEMP_DIR

    run bash "$INSTALL_DIR/core/main.sh"

    [ "$status" -eq 0 ]
    [ -d "$INSTALL_DIR" ]
    printf '%s\n' "$output" | grep -qF "TEMP_DIR is not set. Keeping $INSTALL_DIR."
}

@test "when no library defined end_sudo_session, says nothing about ending a session" {
    printf 'exit 1\n' >"$INSTALL_DIR/core/tabs/common-script.sh"

    run bash "$INSTALL_DIR/core/main.sh"

    [ "$(printf '%s\n' "$output" | grep -c 'Administrator session ended')" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'command not found')" -eq 0 ]
    [ ! -e "$TEMP_DIR" ]
}

@test "reports the administrator session ended only when one was held" {
    stub_library 'exit 1'
    run bash "$INSTALL_DIR/core/main.sh"
    [ "$(printf '%s\n' "$output" | grep -c 'Administrator session ended')" -eq 0 ]

    mkdir -p "$TEMP_DIR"
    stub_library 'SUDO_KEEPALIVE_STARTED=1; exit 1'
    run bash "$INSTALL_DIR/core/main.sh"
    printf '%s\n' "$output" | grep -q 'Administrator session ended'
}
