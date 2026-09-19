#!/bin/sh -e

# menu: Slack
# desc: Team messaging

. "$COMMON_SCRIPT"

install_slack() {
    install_cask "slack"
}

install_slack
