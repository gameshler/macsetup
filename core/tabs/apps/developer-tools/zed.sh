#!/bin/sh -e

. "$COMMON_SCRIPT"

installZed() {
    if ! brew_program_exists zed; then
        printf "Installing Zed..."
        brew install --cask zed
        if [ $? -ne 0 ]; then
            printf "Failed to install Zed. Please check your Homebrew installation."
            exit 1
        fi
        printf "Zed installed successfully!"
    else
        printf "Zed is already installed."
    fi
}

checkPackageManager
installZed
