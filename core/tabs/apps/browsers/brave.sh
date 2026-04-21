#!/bin/sh -e

. "$COMMON_SCRIPT"

install_brave() {
    if ! brew_program_exists brave-browser; then
        printf "Installing Brave..."
        brew install --cask brave-browser
        if [ $? -ne 0 ]; then
            printf "Failed to install Brave Browser. Please check your homebrew installation."
            exit 1
        fi
        printf "Brave Browser installed successfully!"
    else
        printf "Brave Browser is already installed."
    fi
}

checkPackageManager
install_brave
