#!/bin/sh -e

. "$COMMON_SCRIPT"

install_cursor() {
    if ! brew_program_exists cursor; then
        printf "Installing Cursor..."
        brew install --cask cursor
        if [ $? -ne 0 ]; then
            printf "Failed to install Cursor. Please check your Homebrew installation."
            exit 1
        fi
        printf "Cursor installed successfully!"
    else
        printf "Cursor is already installed."
    fi
}

checkPackageManager
install_cursor
