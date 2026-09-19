#!/bin/sh -e

# menu: Brave
# desc: Privacy-focused Chromium browser

. "$COMMON_SCRIPT"

install_brave() {
    install_cask "brave-browser"
}

install_brave
