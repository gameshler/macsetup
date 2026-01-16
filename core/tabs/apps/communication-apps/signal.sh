#!/bin/sh -e

. "$COMMON_SCRIPT"

installSignal() {
    if ! brew_program_exists signal; then
        printf "Installing Signal..."
        brew install --cask signal
        if [ $? -ne 0 ]; then
            printf "Failed to install Signal. Please check your Homebrew installation."
            exit 1
        fi
        printf "Signal installed successfully!"
    else
        printf "Signal is already installed."
    fi
}

checkPackageManager
installSignal
