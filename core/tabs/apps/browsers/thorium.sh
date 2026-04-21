#!/bin/sh -e

. "$COMMON_SCRIPT"

install_thorium() {
    if ! brew_program_exists alex313031-thorium; then
        printf "Installing Thorium..."
        brew install --cask alex313031-thorium
        if [ $? -ne 0 ]; then
            printf "Failed to install Thorium Browser. Please check your Homebrew installation."
            exit 1
        fi
        printf "Thorium Browser installed successfully!"
    else
        printf "Thorium Browser is already installed."
    fi
}

checkPackageManager
install_thorium
