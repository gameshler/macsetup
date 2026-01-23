#!/bin/sh -e

. "$COMMON_SCRIPT"

installZoom() {
    if ! brew_program_exists zoom; then
        printf "Installing Zoom..."
        brew install --cask zoom
        if [ $? -ne 0 ]; then
            printf "Failed to install Zoom. Please check your Homebrew installation."
            exit 1
        fi
        printf "Zoom installed successfully!"
    else
        printf "Zoom is already installed."
    fi
}

checkPackageManager
installZoom
