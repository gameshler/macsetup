#!/bin/sh -e

. "$COMMON_SCRIPT"

install_telegram() {
    if ! brew_program_exists telegram-desktop; then
        printf "Installing Telegram..."
        brew install --cask telegram-desktop
        if [ $? -ne 0 ]; then
            printf "Failed to install Telegram. Please check your Homebrew installation."
            exit 1
        fi
        printf "Telegram installed successfully!"
    else
        printf "Telegram is already installed."
    fi
}

checkPackageManager
install_telegram
