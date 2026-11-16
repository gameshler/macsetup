#!/usr/bin/env bash

# Animations: turn off window and Mission Control animations.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

remove_animations() {
    printf "%b\n" "Reducing motion and animations on macOS..."

    apply_settings <<'EOF'
com.apple.universalaccess | reduceMotion                       | bool  | true  |
NSGlobalDomain           | NSAutomaticWindowAnimationsEnabled  | bool  | false |
NSGlobalDomain           | NSWindowResizeTime                  | float | 0.001 |
NSGlobalDomain           | NSScrollAnimationEnabled            | bool  | false |
NSGlobalDomain           | QLPanelAnimationDuration            | float | 0     |
NSGlobalDomain           | NSTextShowsControlCharacters        | bool  | true  |
com.apple.finder         | DisableAllAnimations                | bool  | true  | Finder
com.apple.dock           | expose-animation-duration           | float | 0.1   | Dock
com.apple.dock           | expose-group-apps                   | bool  | true  | Dock
com.apple.dock           | springboard-show-duration           | float | 0.1   | Dock
com.apple.dock           | springboard-hide-duration           | float | 0.1   | Dock
com.apple.dock           | autohide-time-modifier              | float | 0     | Dock
com.apple.dock           | autohide-delay                      | float | 0     | Dock
com.apple.mail           | DisableReplyAnimations              | bool  | true  |
com.apple.mail           | DisableSendAnimations               | bool  | true  |
EOF
}
