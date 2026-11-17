#!/usr/bin/env bats

# FIREWALL is a scratch script keeping stealth mode in a file, and sudo runs
# its command unprivileged, so the real firewall is never read or changed.
setup() {
    STEALTH="$BATS_TEST_TMPDIR/stealth"
    echo off >"$STEALTH"
    export STEALTH STICKS=1
    SUDO_REFUSES=0

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/security.sh
    . "$BATS_TEST_DIRNAME/../core/settings/security.sh"

    FIREWALL="$BATS_TEST_TMPDIR/socketfilterfw"
    cat >"$FIREWALL" <<'EOF'
#!/bin/sh
case "$1" in
--getstealthmode) echo "Firewall stealth mode is $(cat "$STEALTH")" ;;
--setstealthmode) [ "$STICKS" = "1" ] && echo "$2" >"$STEALTH" ;;
*) exit 1 ;;
esac
exit 0
EOF
    chmod +x "$FIREWALL"

    sudo() {
        [ "$SUDO_REFUSES" = "0" ] || return 1
        "$@"
    }

    # The delay is a file; a write logs, and lands only when LOCK_STICKS=1.
    LOCK="$BATS_TEST_TMPDIR/lock"
    echo 300 >"$LOCK"
    LOCK_LOG="$BATS_TEST_TMPDIR/lock.log"
    : >"$LOCK_LOG"
    LOCK_STICKS=1
    sysadminctl() {
        [ "$1" = "-screenLock" ] || return 1
        case "$2" in
        status)
            if [ "$(cat "$LOCK")" = "immediate" ]; then
                echo "2026-11-17 sysadminctl[1:2] screenLock delay is immediate" >&2
            else
                echo "2026-11-17 sysadminctl[1:2] screenLock delay is $(cat "$LOCK") seconds" >&2
            fi
            ;;
        *)
            echo "SET $*" >>"$LOCK_LOG"
            [ "$LOCK_STICKS" = "1" ] && echo "$2" >"$LOCK"
            ;;
        esac
        return 0
    }
}

@test "with stealth mode off, turns it on and reports nothing" {
    enable_stealth_mode

    [ "$(cat "$STEALTH")" = "on" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "stealth mode that does not stick is reported by name" {
    STICKS=0

    enable_stealth_mode

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "socketfilterfw --getstealthmode"
}

@test "without sudo, stealth mode is reported and the step still finishes" {
    SUDO_REFUSES=1

    enable_stealth_mode

    [ "$(cat "$STEALTH")" = "off" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
}

@test "the security area turns stealth mode on after the firewall, then the screen lock and AirPlay" {
    local calls="$BATS_TEST_TMPDIR/calls"
    enable_firewall() { echo firewall >>"$calls"; }
    enable_stealth_mode() { echo stealth >>"$calls"; }
    require_password_immediately() { echo lock >>"$calls"; }
    disable_airplay_receiver() { echo airplay >>"$calls"; }
    disable_wake_on_network() { :; }
    set_software_update() { :; }
    sudo_keepalive() { return 0; }

    security

    [ "$(tr '\n' ' ' <"$calls")" = "firewall stealth lock airplay " ]
}

@test "with a five-minute delay, asks for the login password once and requires it immediately" {
    require_password_immediately

    [ "$(cat "$LOCK")" = "immediate" ]
    [ "$(cat "$LOCK_LOG")" = "SET -screenLock immediate -password -" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "when the password is already required immediately, asks for nothing" {
    echo immediate >"$LOCK"

    require_password_immediately

    [ ! -s "$LOCK_LOG" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "a refused or wrong login password is reported by name" {
    LOCK_STICKS=0

    require_password_immediately

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "sysadminctl -screenLock"
}

@test "turns AirPlay Receiver off for this Mac and restarts Control Center" {
    local store="$BATS_TEST_TMPDIR/airplay" calls="$BATS_TEST_TMPDIR/airplay-calls"
    defaults() {
        [ "$1 $2 $3" = "-currentHost write com.apple.controlcenter" ] && [ "$4" = "AirplayReceiverEnabled" ] &&
            printf '%s\n' "$6" >"$store" && return 0
        [ "$1 $2 $3 $4" = "-currentHost read com.apple.controlcenter AirplayReceiverEnabled" ] && cat "$store"
    }
    killall() { echo "KILLALL $*" >>"$calls"; }

    disable_airplay_receiver

    [ "$(cat "$store")" = "false" ]
    grep -qx "KILLALL ControlCenter" "$calls"
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}
