#!/usr/bin/env bats

# pmset and defaults are functions backed by scratch files, and sudo runs its
# command unprivileged, so no real power setting or preference is touched.
# The starting state is every option on, as the owner's toggle left it.
setup() {
    POWER="$BATS_TEST_TMPDIR/power"
    VIDEO="$BATS_TEST_TMPDIR/video"
    mkdir -p "$POWER"
    printf '%s\n' "lessbright 1" "sleep 1" >"$POWER/battery"
    printf '%s\n' "sleep 0" >"$POWER/ac"
    echo 1 >"$VIDEO"
    DROPPED_WRITE="" SUDO_REFUSES=0

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/battery.sh
    . "$BATS_TEST_DIRNAME/../core/settings/battery.sh"

    sudo() {
        [ "$SUDO_REFUSES" = "0" ] || return 1
        "$@"
    }
    pmset() {
        local file
        case "$1" in
        -g)
            printf 'Battery Power:\n'
            sed 's/^/ /' "$POWER/battery"
            printf 'AC Power:\n'
            sed 's/^/ /' "$POWER/ac"
            return 0
            ;;
        -b) file="$POWER/battery" ;;
        -c) file="$POWER/ac" ;;
        *) return 1 ;;
        esac
        [ "$1 $2" = "$DROPPED_WRITE" ] && return 0
        sed -i '' "s/^$2 .*/$2 $3/" "$file"
    }
    defaults() {
        [ "$2" = "/Library/Preferences/.GlobalPreferences" ] || return 1
        [ "$3" = "com.apple.coremedia.optimizeVideoStreamingOnBattery" ] || return 1
        case "$1 $4 $5" in
        "write -bool false") echo 0 >"$VIDEO" ;;
        read*) cat "$VIDEO" ;;
        *) return 1 ;;
        esac
    }
}

power_value() {
    awk -v key="$2" '$1 == key { print $2 }' "$POWER/$1"
}

@test "turns off dimming on battery, the no-sleep option on AC, and video optimization" {
    battery

    [ "$(power_value battery lessbright)" = "0" ]
    [ "$(power_value ac sleep)" = "1" ]
    [ "$(cat "$VIDEO")" = "0" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "reads each value from its own power source, not the first match" {
    printf '%s\n' "lessbright 1" "sleep 0" >"$POWER/battery"
    printf '%s\n' "lessbright 0" "sleep 1" >"$POWER/ac"
    DROPPED_WRITE="-b lessbright"

    battery

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "Battery Power lessbright"
}

@test "an AC sleep write that does not stick is reported by name" {
    DROPPED_WRITE="-c sleep"

    battery

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "AC Power sleep"
}

@test "without sudo, every row is reported and the area still finishes" {
    SUDO_REFUSES=1

    # Called directly, so a non-zero return fails the test, and the failures
    # stay in this shell for the report.
    battery

    [ "$SETTINGS_FAILED_COUNT" -eq 3 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "Battery Power lessbright"
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "AC Power sleep"
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "optimizeVideoStreamingOnBattery"
}
