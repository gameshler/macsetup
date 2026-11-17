#!/usr/bin/env bats

# defaults keeps one scratch file per key and killall only logs, so no real
# preference is written and nothing in the menu bar restarts.
setup() {
    STORE="$BATS_TEST_TMPDIR/store"
    CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STORE"
    : >"$CALL_LOG"
    UNDELETABLE="" STUCK_ARRAY="-"
    TIME_MACHINE_MENU="/System/Library/CoreServices/Menu Extras/TimeMachine.menu"
    VPN_MENU="/System/Library/CoreServices/Menu Extras/VPN.menu"

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/menu-bar.sh
    . "$BATS_TEST_DIRNAME/../core/settings/menu-bar.sh"

    defaults() {
        local scope="" file
        [ "$1" = "-currentHost" ] && scope="byhost " && shift
        file="$STORE/$(printf '%s' "$scope$2 $3" | tr ' /' '__')"
        case "$1" in
        write)
            if [ "$4" = "-array" ]; then
                shift 4
                [ "$*" = "$STUCK_ARRAY" ] && return 0
                {
                    printf '(\n'
                    [ "$#" -eq 0 ] || printf '    "%s",\n' "$@"
                    printf ')\n'
                } >"$file"
            else
                printf '%s\n' "$5" >"$file"
            fi
            ;;
        read) cat "$file" 2>/dev/null ;;
        delete)
            [ "$2 $3" = "$UNDELETABLE" ] && return 0
            command rm "$file" 2>/dev/null
            ;;
        *) return 1 ;;
        esac
    }
    killall() { echo "KILLALL $*" >>"$CALL_LOG"; }

    # The Weather agent's launchd job is a file; bootout removes it unless
    # BOOTOUT_STICKS=0.
    WEATHER_JOB="$BATS_TEST_TMPDIR/weather-job"
    BOOTOUT_STICKS=1
    launchctl() {
        echo "LAUNCHCTL $*" >>"$CALL_LOG"
        [ "$2" = "gui/$(id -u)/com.apple.weather.menu" ] || return 1
        case "$1" in
        print) [ -e "$WEATHER_JOB" ] ;;
        bootout) [ "$BOOTOUT_STICKS" = "0" ] || command rm "$WEATHER_JOB" ;;
        *) return 1 ;;
        esac
    }
}

stored() {
    cat "$STORE/$(printf '%s' "$1" | tr ' /' '__')"
}

@test "hides each system control, the Spotlight icon and the input menu, and turns off gallery suggestions" {
    local control
    menu_bar

    for control in AirDrop Battery Bluetooth Display FocusModes KeyboardBrightness NowPlaying ScreenMirroring Sound Spotlight TimeMachine Timer UserSwitcher Weather WiFi; do
        [ "$(stored "byhost com.apple.controlcenter $control")" = "8" ]
    done
    [ "$(stored "byhost com.apple.controlcenter ShowSuggestions")" = "false" ]
    [ "$(stored "byhost com.apple.Spotlight MenuItemHidden")" = "true" ]
    [ "$(stored "com.apple.TextInputMenu visible")" = "false" ]
    [ "$(stored "com.apple.TextInputMenuAgent NSStatusItem VisibleCC Item-0")" = "false" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "hides the Bluetooth icon too; only the radio is left to the owner" {
    menu_bar

    [ "$(stored "byhost com.apple.controlcenter Bluetooth")" = "8" ]
}

@test "restarts Control Center and the input menu once each, and Siri AI not at all when its item is already hidden" {
    menu_bar

    [ "$(grep -cx "KILLALL ControlCenter" "$CALL_LOG")" -eq 1 ]
    [ "$(grep -cx "KILLALL TextInputMenuAgent" "$CALL_LOG")" -eq 1 ]
    [ "$(grep -cF "Siri AI" "$CALL_LOG")" -eq 0 ]
    [ "$(grep -cF "SystemUIServer" "$CALL_LOG")" -eq 0 ]
}

# Time Machine also shows through SystemUIServer, the older menu extra route.
@test "removes the Time Machine menu extra and its visible key, keeping any other extra" {
    defaults write com.apple.systemuiserver "NSStatusItem VisibleCC com.apple.menuextra.TimeMachine" -bool true
    defaults write com.apple.systemuiserver menuExtras -array "$VPN_MENU" "$TIME_MACHINE_MENU"

    menu_bar

    [ ! -e "$STORE/com.apple.systemuiserver_NSStatusItem_VisibleCC_com.apple.menuextra.TimeMachine" ]
    [ "$(stored "com.apple.systemuiserver menuExtras")" = "$(printf '(\n    "%s",\n)' "$VPN_MENU")" ]
    [ "$(grep -cx "KILLALL SystemUIServer" "$CALL_LOG")" -eq 1 ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "with Time Machine the only extra, leaves an empty list, as the pane does" {
    defaults write com.apple.systemuiserver menuExtras -array "$TIME_MACHINE_MENU"

    menu_bar

    [ "$(stored "com.apple.systemuiserver menuExtras")" = "$(printf '(\n)')" ]
}

@test "a Time Machine extra that will not go away is reported by name" {
    defaults write com.apple.systemuiserver menuExtras -array "$TIME_MACHINE_MENU"
    STUCK_ARRAY=""

    menu_bar

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "TimeMachine.menu"
}

@test "removes the Siri AI item's visible key, as the pane does" {
    defaults write com.apple.campo "NSStatusItem VisibleCC Item-0" -bool true

    menu_bar

    [ ! -e "$STORE/com.apple.campo_NSStatusItem_VisibleCC_Item-0" ]
    grep -qx "KILLALL Siri AI" "$CALL_LOG"
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "a Siri AI key that will not go away is reported by name" {
    defaults write com.apple.campo "NSStatusItem VisibleCC Item-0" -bool true
    UNDELETABLE="com.apple.campo NSStatusItem VisibleCC Item-0"

    menu_bar

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "com.apple.campo"
    [ "$(grep -cF "Siri AI" "$CALL_LOG")" -eq 0 ]
}

# The pane's Weather switch also removes the Weather app's menu agent job;
# the setting alone leaves the icon up.
@test "removes the Weather menu agent's launchd job, as the pane does" {
    : >"$WEATHER_JOB"

    menu_bar

    [ ! -e "$WEATHER_JOB" ]
    grep -qx "LAUNCHCTL bootout gui/$(id -u)/com.apple.weather.menu" "$CALL_LOG"
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "with no Weather menu agent loaded, boots nothing out" {
    menu_bar

    [ "$(grep -c "LAUNCHCTL bootout" "$CALL_LOG")" -eq 0 ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "a Weather menu agent that will not go away is reported by name" {
    : >"$WEATHER_JOB"
    BOOTOUT_STICKS=0

    menu_bar

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "com.apple.weather.menu"
}
