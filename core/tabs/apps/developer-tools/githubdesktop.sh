#!/bin/sh -e

. "$COMMON_SCRIPT"

install_github_desktop() {
    if ! brew_program_exists github; then
        printf "Installing Github Desktop..."
        brew install --cask github
        if [ $? -ne 0 ]; then
            printf "Failed to install Github Desktop. Please check your Homebrew installation."
            exit 1
        fi
        printf "Github Desktop installed successfully!"
    else
        printf "Github Desktop is already installed."
    fi
}

install_github_desktop
