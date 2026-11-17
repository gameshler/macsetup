#!/usr/bin/env bats

# defaults keeps one scratch file per key and killall only logs, so no real
# preference is written and nothing in the menu bar restarts.
setup() {
    STORE="$BATS_TEST_TMPDIR/store"
    CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STORE"
    : >"$CALL_LOG"
    UNDELETABLE=""

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/menu-bar.sh
    . "$BATS_TEST_DIRNAME/../core/settings/menu-bar.sh"

    defaults() {
        local scope="" file
        [ "$1" = "-currentHost" ] && scope="byhost " && shift
        file="$STORE/$(printf '%s' "$scope$2 $3" | tr ' /' '__')"
        case "$1" in
        write) printf '%s\n' "$5" >"$file" ;;
        read) cat "$file" 2>/dev/null ;;
        delete)
            [ "$2 $3" = "$UNDELETABLE" ] && return 0
            command rm "$file" 2>/dev/null
            ;;
        *) return 1 ;;
        esac
    }
    killall() { echo "KILLALL $*" >>"$CALL_LOG"; }
}

stored() {
    cat "$STORE/$(printf '%s' "$1" | tr ' /' '__')"
}

@test "hides each system control, the Spotlight icon and the input menu, and turns off gallery suggestions" {
    local control
    menu_bar

    for control in Battery Display FocusModes NowPlaying ScreenMirroring Sound Spotlight Timer WiFi; do
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
