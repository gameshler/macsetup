#!/bin/sh -e

# menu: Firefox
# desc: Mozilla's browser

. "$COMMON_SCRIPT"

install_firefox() {
    install_cask "firefox"
}

install_firefox
