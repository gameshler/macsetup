#!/bin/sh -e

. "$COMMON_SCRIPT"

install_firefox() {
    if ! brew_program_exists firefox; then
        printf "Installing Mozilla Firefox..."
        brew install --cask firefox
        if [ $? -ne 0 ]; then
            printf "Failed to install Firefox Browser. Please check your Homebrew installation."
            exit 1
        fi
        printf "Firefox Browser installed successfully!"
    else
        printf "Firefox Browser is already installed."
    fi
}

checkPackageManager
install_firefox
