#!/usr/bin/env bats

# sudo runs its command unprivileged and pkgutil only logs, so the only thing
# removed is a scratch copy of the app.
setup() {
    CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
    : >"$CALL_LOG"
    SUDO_REFUSES=0

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/ai.sh
    . "$BATS_TEST_DIRNAME/../core/settings/ai.sh"

    COPILOT_SHIM_APP="$BATS_TEST_TMPDIR/Applications/Microsoft 365 Copilot Shim.app"

    sudo() {
        [ "$SUDO_REFUSES" = "0" ] || return 1
        "$@"
    }
    pkgutil() { echo "PKGUTIL $*" >>"$CALL_LOG"; }
}

@test "when the Copilot shim is installed, removes it and forgets its receipt" {
    mkdir -p "$COPILOT_SHIM_APP/Contents"

    remove_copilot_shim

    [ ! -e "$COPILOT_SHIM_APP" ]
    grep -qx "PKGUTIL --forget com.microsoft.m365copilot.shim" "$CALL_LOG"
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "when the Copilot shim is absent, does nothing and reports nothing" {
    remove_copilot_shim

    [ ! -s "$CALL_LOG" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "when the shim cannot be removed, reports it by name" {
    mkdir -p "$COPILOT_SHIM_APP/Contents"
    SUDO_REFUSES=1

    remove_copilot_shim

    [ -d "$COPILOT_SHIM_APP" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "Copilot Shim"
}
