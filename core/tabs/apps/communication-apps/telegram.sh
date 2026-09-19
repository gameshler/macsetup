#!/bin/sh -e

# menu: Telegram
# desc: Messaging

. "$COMMON_SCRIPT"

install_telegram() {
    install_cask "telegram-desktop"
}

install_telegram
