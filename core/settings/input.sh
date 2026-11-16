#!/usr/bin/env bash

# Trackpad: tap to click, natural scrolling off.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

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
}
