#!/bin/sh -e

. "$COMMON_SCRIPT"

install_whatsapp() {
    if ! brew_program_exists whatsapp; then
        printf "Installing WhatsApp..."
        brew install --cask whatsapp
        if [ $? -ne 0 ]; then
            printf "Failed to install WhatsApp. Please check your Homebrew installation."
            exit 1
        fi
        printf "WhatsApp installed successfully!"
    else
        printf "WhatsApp is already installed."
    fi
}

checkPackageManager
install_whatsapp
