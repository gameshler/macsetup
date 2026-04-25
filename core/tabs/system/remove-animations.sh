#!/bin/sh -e

. "$COMMON_SCRIPT"

remove_animations() {
    printf "%b\n" "Reducing motion and animations on macOS..."

    # Reduce motion in Accessibility settings (most effective)
    printf "%b\n" "Setting reduce motion preference..."
    sudo defaults write com.apple.universalaccess reduceMotion -bool true

    # Disable window animations
    printf "%b\n" "Disabling window animations..."
    sudo defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

    # Speed up window resize animations
    printf "%b\n" "Speeding up window resize animations..."
    sudo defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

    # Disable smooth scrolling
    printf "%b\n" "Disabling smooth scrolling..."
    sudo defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false

    # Disable animation when opening and closing windows
    printf "%b\n" "Disabling window open/close animations..."
    sudo defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

    # Disable animation when opening a Quick Look window
    printf "%b\n" "Disabling Quick Look animations..."
    sudo defaults write -g QLPanelAnimationDuration -float 0

    # Disable animation when opening the Info window in Finder
    printf "%b\n" "Disabling Finder Info window animations..."
    sudo defaults write com.apple.finder DisableAllAnimations -bool true

    # Speed up Mission Control animations
    printf "%b\n" "Speeding up Mission Control animations..."
    sudo defaults write com.apple.dock expose-animation-duration -float 0.1
    sudo defaults write com.apple.dock expose-group-apps -bool true

    # Speed up Launchpad animations
    printf "%b\n" "Speeding up Launchpad animations..."
    sudo defaults write com.apple.dock springboard-show-duration -float 0.1
    sudo defaults write com.apple.dock springboard-hide-duration -float 0.1

    # Disable dock hiding animation
    printf "%b\n" "Disabling dock hiding animations..."
    sudo defaults write com.apple.dock autohide-time-modifier -float 0
    sudo defaults write com.apple.dock autohide-delay -float 0

    # Disable animations in Mail.app
    printf "%b\n" "Disabling Mail animations..."
    sudo defaults write com.apple.mail DisableReplyAnimations -bool true
    sudo defaults write com.apple.mail DisableSendAnimations -bool true

    # Disable zoom animation when focusing on text input fields
    printf "%b\n" "Disabling text field zoom animations..."
    sudo defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true

    printf "%b\n" "Motion and animations have been reduced."
    sudo killall Dock
    printf "%b\n" "Dock Restarted."
}

remove_animations
