#!/bin/sh -e

. "$COMMON_SCRIPT"

install_slack() {
    if ! brew_program_exists slack; then
        printf "Installing Slack..."
        brew install --cask slack
        if [ $? -ne 0 ]; then
            printf "Failed to install Slack. Please check your Homebrew installation."
            exit 1
        fi
        printf "Slack installed successfully!"
    else
        printf "Slack is already installed."
    fi
}

checkPackageManager
install_slack
