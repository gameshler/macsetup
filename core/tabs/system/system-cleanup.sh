#!/bin/sh -e

. "$COMMON_SCRIPT"

cleanup_system() {
    printf "%b\n" "Performing system cleanup..."
    # Fix Missions control to NEVER rearrange spaces
    printf "%b\n" "Fixing Mission Control to never rearrange spaces..."
    sudo defaults write com.apple.dock mru-spaces -bool false

    # Apple Intelligence Crap
    sudo defaults write com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool "false"

    # Empty Trash
    printf "%b\n" "Emptying Trash..."
    sudo rm -rf ~/.Trash/*

    # Remove old log files
    printf "%b\n" "Removing old log files..."
    find /var/log -type f -name "*.log" -mtime +30 -exec sudo rm -f {} \;
    find /var/log -type f -name "*.old" -mtime +30 -exec sudo rm -f {} \;
    find /var/log -type f -name "*.err" -mtime +30 -exec sudo rm -f {} \;

}

cleanup_system
