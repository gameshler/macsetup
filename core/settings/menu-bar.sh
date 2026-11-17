#!/usr/bin/env bash

# Menu bar: hide every system control, the input menu, Time Machine's menu
# extra and the Siri AI item, and turn off suggestions in the Control Gallery.
# The Bluetooth icon is hidden too; only the Bluetooth radio is left to the
# owner.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

# Siri AI.app owns com.apple.campo. Hiding its item in the pane deletes this
# key rather than writing false, so the step does the same.
SIRI_AI_ITEM_KEY="NSStatusItem VisibleCC Item-0"

hide_siri_ai_item() {
    local state="removed"

    [ -n "$(_settings_read com.apple.campo "$SIRI_AI_ITEM_KEY")" ] || return 0
    defaults delete com.apple.campo "$SIRI_AI_ITEM_KEY" </dev/null 2>/dev/null || true
    [ -z "$(_settings_read com.apple.campo "$SIRI_AI_ITEM_KEY")" ] || state="present"
    verify_value "com.apple.campo $SIRI_AI_ITEM_KEY" "removed" "$state" exact || return 0
    # Its launch agent relaunches it, now without the item.
    killall "Siri AI" >/dev/null 2>&1 || true
}

# Time Machine also shows through SystemUIServer. Hiding it in the pane
# deletes this key and drops its entry from menuExtras.
TIME_MACHINE_ITEM_KEY="NSStatusItem VisibleCC com.apple.menuextra.TimeMachine"
TIME_MACHINE_EXTRA="/System/Library/CoreServices/Menu Extras/TimeMachine.menu"

# One path per line, as `defaults read` quotes them.
menu_extras() {
    _settings_read com.apple.systemuiserver menuExtras | sed -n 's/^ *"\(.*\)",\{0,1\}$/\1/p'
}

# Returns 1 when there was no key to delete.
_delete_time_machine_key() {
    local state="removed"

    [ -n "$(_settings_read com.apple.systemuiserver "$TIME_MACHINE_ITEM_KEY")" ] || return 1
    defaults delete com.apple.systemuiserver "$TIME_MACHINE_ITEM_KEY" </dev/null 2>/dev/null || true
    [ -z "$(_settings_read com.apple.systemuiserver "$TIME_MACHINE_ITEM_KEY")" ] || state="present"
    verify_value "com.apple.systemuiserver $TIME_MACHINE_ITEM_KEY" "removed" "$state" exact || true
}

# Rewrites menuExtras without Time Machine, keeping every other extra.
# Returns 1 when Time Machine was not listed.
_drop_time_machine_extra() {
    local extra state="removed"

    menu_extras | grep -qxF "$TIME_MACHINE_EXTRA" || return 1
    set --
    while IFS= read -r extra; do
        [ -n "$extra" ] && [ "$extra" != "$TIME_MACHINE_EXTRA" ] && set -- "$@" "$extra"
    done <<EOF
$(menu_extras)
EOF
    defaults write com.apple.systemuiserver menuExtras -array "$@" </dev/null 2>/dev/null || true
    menu_extras | grep -qxF "$TIME_MACHINE_EXTRA" && state="present"
    verify_value "com.apple.systemuiserver menuExtras $TIME_MACHINE_EXTRA" "removed" "$state" exact || true
}

hide_time_machine_extra() {
    local changed=1

    _delete_time_machine_key && changed=0
    _drop_time_machine_extra && changed=0
    [ "$changed" = "0" ] || return 0
    killall SystemUIServer >/dev/null 2>&1 || true
}

menu_bar() {
    printf "%b\n" "Hiding the menu bar controls..."

    # 8 is Don't Show in Menu Bar. The Spotlight icon is a Control Center
    # module on macOS 27, so Control Center owns its row too.
    apply_settings <<'EOF'
-currentHost com.apple.controlcenter | ShowSuggestions               | bool | false | ControlCenter
-currentHost com.apple.controlcenter | AirDrop                       | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Battery                       | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Bluetooth                     | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Display                       | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | FocusModes                    | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | KeyboardBrightness            | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | NowPlaying                    | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | ScreenMirroring               | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Sound                         | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Spotlight                     | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | TimeMachine                   | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Timer                         | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | UserSwitcher                  | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Weather                       | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | WiFi                          | int  | 8     | ControlCenter
-currentHost com.apple.Spotlight     | MenuItemHidden                | bool | true  | ControlCenter
com.apple.TextInputMenu              | visible                       | bool | false | TextInputMenuAgent
com.apple.TextInputMenuAgent         | NSStatusItem VisibleCC Item-0 | bool | false | TextInputMenuAgent
EOF

    hide_siri_ai_item
    hide_time_machine_extra
}
