#!/bin/sh -e

. "$COMMON_SCRIPT"

install_librewolf() {
    if ! brew_program_exists librewolf; then
        printf "Installing LibreWolf..."
        brew install --cask librewolf --no-quarantine
        if [ $? -ne 0 ]; then
            printf "Failed to install LibreWolf Browser. Please check your Homebrew installation."
            exit 1
        fi
        printf "LibreWolf Browser installed successfully!"
    else
        printf "LibreWolf Browser is already installed."
    fi
}

checkPackageManager
install_librewolf
