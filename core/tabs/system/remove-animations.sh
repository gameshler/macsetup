#!/bin/sh -e

. "$COMMON_SCRIPT"

remove_animations() {
    printf "Reducing motion and animations on macOS..."

    # Reduce motion in Accessibility settings (most effective)
    printf "Setting reduce motion preference..."
    sudo defaults write com.apple.universalaccess reduceMotion -bool true

    # Disable window animations
    printf "Disabling window animations..."
    sudo defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

    # Speed up window resize animations
    printf "Speeding up window resize animations..."
    sudo defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

    # Disable smooth scrolling
    printf "Disabling smooth scrolling..."
    sudo defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false

    # Disable animation when opening and closing windows
    printf "Disabling window open/close animations..."
    sudo defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

    # Disable animation when opening a Quick Look window
    printf "Disabling Quick Look animations..."
    sudo defaults write -g QLPanelAnimationDuration -float 0

    # Disable animation when opening the Info window in Finder
    printf "Disabling Finder Info window animations..."
    sudo defaults write com.apple.finder DisableAllAnimations -bool true

    # Speed up Mission Control animations
    printf "Speeding up Mission Control animations..."
    sudo defaults write com.apple.dock expose-animation-duration -float 0.1
    sudo defaults write com.apple.dock expose-group-apps -bool true

    # Speed up Launchpad animations
    printf "Speeding up Launchpad animations..."
    sudo defaults write com.apple.dock springboard-show-duration -float 0.1
    sudo defaults write com.apple.dock springboard-hide-duration -float 0.1

    # Disable dock hiding animation
    printf "Disabling dock hiding animations..."
    sudo defaults write com.apple.dock autohide-time-modifier -float 0
    sudo defaults write com.apple.dock autohide-delay -float 0

    # Disable animations in Mail.app
    printf "Disabling Mail animations..."
    sudo defaults write com.apple.mail DisableReplyAnimations -bool true
    sudo defaults write com.apple.mail DisableSendAnimations -bool true

    # Disable zoom animation when focusing on text input fields
    printf "Disabling text field zoom animations..."
    sudo defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true

    printf "Motion and animations have been reduced."
    sudo killall Dock
    printf "Dock Restarted."
}

checkPackageManager
remove_animations
