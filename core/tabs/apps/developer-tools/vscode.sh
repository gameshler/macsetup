#!/bin/sh -e

. "$COMMON_SCRIPT"

install_vscode() {
    if ! brew_program_exists visual-studio-code; then
        printf "Installing VS Code..."
        brew install --cask visual-studio-code
        if [ $? -ne 0 ]; then
            printf "Failed to install VS Code. Please check your Homebrew installation."
            exit 1
        fi
        printf "VS Code installed successfully!"
    else
        printf "VS Code is already installed."
    fi
}

checkPackageManager
install_vscode
