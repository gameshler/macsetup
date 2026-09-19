#!/bin/sh -e

# menu: Signal
# desc: Encrypted messaging

. "$COMMON_SCRIPT"

install_signal() {
    install_cask "signal"
}

install_signal
