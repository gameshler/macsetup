#!/bin/sh -e

# menu: GitHub Desktop
# desc: Git client from GitHub

. "$COMMON_SCRIPT"

install_github_desktop() {
    install_cask "github"
}

install_github_desktop
