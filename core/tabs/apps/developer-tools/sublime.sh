#!/bin/sh -e

. "$COMMON_SCRIPT"

installSublime() {
    if ! brew_program_exists sublime-text; then
        printf "Installing Sublime..."
        brew install --cask sublime-text
        if [ $? -ne 0 ]; then
            printf "Failed to install Sublime. Please check your Homebrew installation."
            exit 1
        fi
        printf "Sublime installed successfully!"
    else
        printf "Sublime is already installed."
    fi
}

checkPackageManager
installSublime
