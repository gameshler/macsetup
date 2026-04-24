#!/bin/sh -e

. "$COMMON_SCRIPT"

install_discord() {
    if ! brew_program_exists discord; then
        printf "Installing Discord..."
        brew install --cask discord
        if [ $? -ne 0 ]; then
            printf "Failed to install Discord. Please check your Homebrew installation."
            exit 1
        fi
        printf "Discord installed successfully!"
    else
        printf "Discord is already installed."
    fi
}

install_discord
