#!/usr/bin/env bash

# Menu bar: hide the system controls, the input menu and the Siri AI item,
# and turn off suggestions in the Control Gallery. Bluetooth is left as the
# owner set it. Sourced by core/tabs/system/optimize-settings.sh, which runs it.

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

menu_bar() {
    printf "%b\n" "Hiding the menu bar controls..."

    # 8 is Don't Show in Menu Bar. The Spotlight icon is a Control Center
    # module on macOS 27, so Control Center owns its row too.
    apply_settings <<'EOF'
-currentHost com.apple.controlcenter | ShowSuggestions               | bool | false | ControlCenter
-currentHost com.apple.controlcenter | Battery                       | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Display                       | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | FocusModes                    | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | NowPlaying                    | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | ScreenMirroring               | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Sound                         | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Spotlight                     | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | Timer                         | int  | 8     | ControlCenter
-currentHost com.apple.controlcenter | WiFi                          | int  | 8     | ControlCenter
-currentHost com.apple.Spotlight     | MenuItemHidden                | bool | true  | ControlCenter
com.apple.TextInputMenu              | visible                       | bool | false | TextInputMenuAgent
com.apple.TextInputMenuAgent         | NSStatusItem VisibleCC Item-0 | bool | false | TextInputMenuAgent
EOF

    hide_siri_ai_item
}
