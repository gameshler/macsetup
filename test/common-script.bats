#!/usr/bin/env bats

# Sourcing common-script.sh runs checkPackageManager, which downloads and runs
# the Homebrew installer when no brew binary exists. Skip rather than let a
# test install Homebrew.
setup() {
    if [ ! -x /opt/homebrew/bin/brew ] && [ ! -x /usr/local/bin/brew ]; then
        skip "sourcing common-script.sh would install Homebrew"
    fi

    INSTALLED="$BATS_TEST_TMPDIR/installed"
    CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
    UNKNOWN_FORMULAE=""
    : >"$INSTALLED"
    : >"$CALL_LOG"

    # shellcheck disable=SC1091
    . "$BATS_TEST_DIRNAME/../core/tabs/common-script.sh" >/dev/null

    # A function, not a PATH stub: common-script.sh has just prepended the
    # real Homebrew prefix to PATH, and a function wins regardless.
    brew() {
        case "$1" in
        list) brew_stub_list "$@" ;;
        install) brew_stub_install "$@" ;;
        *) return 1 ;;
        esac
    }
}

brew_stub_list() {
    case "$*" in
    *--versions*) grep -qxF -- "${!#}" "$INSTALLED" ;;
    *) cat "$INSTALLED" ;;
    esac
}

# Mirrors real brew: one unknown name fails the whole call and installs nothing.
brew_stub_install() {
    local name
    shift
    echo "INSTALL $*" >>"$CALL_LOG"
    for name in "$@"; do
        case " $UNKNOWN_FORMULAE " in
        *" $name "*)
            echo "Warning: No available formula with the name \"$name\"."
            return 1
            ;;
        esac
    done
    for name in "$@"; do
        case "$name" in
        -*) ;;
        *) echo "$name" >>"$INSTALLED" ;;
        esac
    done
}

@test "when every name exists, installs them in a single brew call" {
    run install_packages jq fd uv

    [ "$status" -eq 0 ]
    [ "$(grep -c '^INSTALL' "$CALL_LOG")" -eq 1 ]
    [ "$(sort "$INSTALLED" | tr '\n' ' ')" = "fd jq uv " ]
}

@test "when one name is unknown, still installs every other name" {
    UNKNOWN_FORMULAE="tldr"

    run install_packages jq tldr uv

    [ "$(sort "$INSTALLED" | tr '\n' ' ')" = "jq uv " ]
}

@test "when one name is unknown, fails and names only that package" {
    UNKNOWN_FORMULAE="tldr"

    run install_packages jq tldr uv

    [ "$status" -eq 1 ]
    printf '%s\n' "$output" | grep -qxF "Failed to install: tldr"
}

# checkPackageManager's install branch, with nothing real reachable: brew_path
# reports no Homebrew once, curl hands /bin/bash a script that only logs, and
# HOME is a scratch directory so .zprofile is never touched.
stub_missing_homebrew() {
    FAKE_BREW="$BATS_TEST_TMPDIR/brew"
    printf '#!/bin/sh\nexit 0\n' >"$FAKE_BREW"
    chmod +x "$FAKE_BREW"
    HOME="$BATS_TEST_TMPDIR"
    export CALL_LOG FAKE_BREW HOME

    brew_path() {
        if [ -f "$BATS_TEST_TMPDIR/brew-installed" ]; then
            printf '%s\n' "$FAKE_BREW"
            return 0
        fi
        return 1
    }
    sudo_keepalive() {
        echo "SUDO" >>"$CALL_LOG"
        return "${SUDO_STATUS:-0}"
    }
    curl() {
        printf '%s\n' 'echo INSTALLER >>"$CALL_LOG"; : >"$(dirname "$FAKE_BREW")/brew-installed"'
    }
}

@test "when Homebrew is missing, takes the sudo password before running its installer" {
    stub_missing_homebrew

    run checkPackageManager

    [ "$status" -eq 0 ]
    [ "$(tr '\n' ' ' <"$CALL_LOG")" = "SUDO INSTALLER " ]
}

@test "when Homebrew is missing and sudo is refused, does not run its installer" {
    stub_missing_homebrew
    SUDO_STATUS=1

    run checkPackageManager

    [ "$status" -eq 1 ]
    [ "$(grep -c INSTALLER "$CALL_LOG")" -eq 0 ]
}
