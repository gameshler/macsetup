#!/bin/sh -e

# menu: Visual Studio Code
# desc: Microsoft's code editor

. "$COMMON_SCRIPT"

install_vscode() {
    install_cask "visual-studio-code"
}

install_vscode
