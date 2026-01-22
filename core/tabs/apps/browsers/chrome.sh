#!/bin/sh -e

. "$COMMON_SCRIPT"

installChrome() {
    if ! brew_program_exists google-chrome; then
        printf "Installing Google Chrome..."
        brew install --cask google-chrome
        if [ $? -ne 0 ]; then
            printf "Failed to install Google Chrome Browser. Please check your Homebrew installation."
            exit 1
        fi
        printf "Google Chrome Browser installed successfully!"
    else
        printf "Google Chrome Browser is already installed."
    fi
}

checkPackageManager
installChrome
