#!/usr/bin/env bash

# menu: Trackpad
# desc: Tap to click, natural scrolling off

. "$COMMON_SCRIPT"
. "$SETTINGS_LIB"

configure_input() {
    printf "%b\n" "Configuring trackpad input..."

    apply_settings <<'EOF'
com.apple.AppleMultitouchTrackpad                  | Clicking                       | bool | true  |
com.apple.driver.AppleBluetoothMultitouch.trackpad | Clicking                       | bool | true  |
NSGlobalDomain                                     | com.apple.mouse.tapBehavior    | int  | 1     |
-currentHost NSGlobalDomain                        | com.apple.mouse.tapBehavior    | int  | 1     |
NSGlobalDomain                                     | com.apple.swipescrolldirection | bool | false |
EOF

    printf "%b\n" "Trackpad settings take effect at the next login."

    settings_report
}

configure_input
