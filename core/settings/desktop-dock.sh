#!/usr/bin/env bash

# Dock and Desktop: a small dock on the left, hidden desktop icons.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

set_dock_contents() {
    local system_settings='<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file:///System/Applications/System%20Settings.app/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>'

    printf "%b\n" "Setting Dock contents to System Settings only..."
    defaults write com.apple.dock persistent-apps -array 2>/dev/null || true
    defaults write com.apple.dock persistent-apps -array-add "$system_settings" 2>/dev/null || true

    verify_setting com.apple.dock persistent-apps "System%20Settings.app" contains || true
}

desktop_dock() {
    printf "%b\n" "Configuring Desktop and Dock..."

    set_dock_contents

    apply_settings <<'EOF'
com.apple.WindowManager | EnableStandardClickToShowDesktop | bool   | false | WindowManager
com.apple.WindowManager | StandardHideDesktopIcons         | bool   | true  | WindowManager
com.apple.WindowManager | HideDesktop                      | bool   | true  | WindowManager
com.apple.WindowManager | StandardHideWidgets              | bool   | true  | WindowManager
com.apple.WindowManager | StageManagerHideWidgets          | bool   | true  | WindowManager
com.apple.dock          | tilesize                         | int    | 16    | Dock
com.apple.dock          | autohide                         | bool   | true  | Dock
com.apple.dock          | orientation                      | string | left  | Dock
com.apple.dock          | launchanim                       | bool   | false | Dock
com.apple.dock          | show-recents                     | bool   | false | Dock
EOF
}
