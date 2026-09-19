#!/bin/sh -e

# menu: Thorium
# desc: Performance-tuned Chromium build

. "$COMMON_SCRIPT"

install_thorium() {
    install_cask "alex313031-thorium"
}

install_thorium
