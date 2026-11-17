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

@test "the security area turns stealth mode on after the firewall" {
    local calls="$BATS_TEST_TMPDIR/calls"
    enable_firewall() { echo firewall >>"$calls"; }
    enable_stealth_mode() { echo stealth >>"$calls"; }
    disable_wake_on_network() { :; }
    set_software_update() { :; }
    sudo_keepalive() { return 0; }

    security

    [ "$(tr '\n' ' ' <"$calls")" = "firewall stealth " ]
}
