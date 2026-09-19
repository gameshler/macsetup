#!/bin/sh -e

# menu: Google Chrome
# desc: Google's browser

. "$COMMON_SCRIPT"

install_chrome() {
    install_cask "google-chrome"
}

install_chrome
