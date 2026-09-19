#!/usr/bin/env bash

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ANALYTICS=1

command_exists() {
    for cmd in "$@"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            continue
        fi
        if command -v open >/dev/null 2>&1 && open -Ra "$cmd" >/dev/null 2>&1; then
            continue
        fi
        return 1
    done
    return 0
}

brew_program_exists() {
    _installed=$(brew list -1 2>/dev/null || true)
    for cmd in "$@"; do
        printf '%s\n' "$_installed" | grep -qxF -- "$cmd" || return 1
    done
    return 0
}

sudo_keepalive() {
    if [ "${SUDO_KEEPALIVE_STARTED:-0}" = "1" ]; then
        return 0
    fi

    printf "%b\n" "Requesting administrator access once for this session..."
    sudo -v || return 1

    _sudo_parent=$$
    (
        while kill -0 "$_sudo_parent" 2>/dev/null; do
            sudo -n true 2>/dev/null || break
            sleep 50
        done
    ) >/dev/null 2>&1 &

    SUDO_KEEPALIVE_STARTED=1
    export SUDO_KEEPALIVE_STARTED
    return 0
}

_brew_alias_installed() {
    if [ "$1" = cask ]; then
        brew list --cask --versions "$2" >/dev/null 2>&1
    else
        brew list --formula --versions "$2" >/dev/null 2>&1
    fi
}

_brew_install_batch() {
    _kind="$1"
    shift
    [ "$#" -gt 0 ] || return 0

    if [ "$_kind" = cask ]; then
        _installed=$(brew list --cask -1 2>/dev/null || true)
    else
        _installed=$(brew list --formula -1 2>/dev/null || true)
    fi

    _remaining="$#"
    while [ "$_remaining" -gt 0 ]; do
        _pkg="$1"
        shift
        if printf '%s\n' "$_installed" | grep -qxF -- "$_pkg"; then
            printf "%b\n" "$_pkg is already installed. Skipping."
        elif _brew_alias_installed "$_kind" "$_pkg"; then
            printf "%b\n" "$_pkg is already installed under its canonical name. Skipping."
        else
            set -- "$@" "$_pkg"
        fi
        _remaining=$((_remaining - 1))
    done

    if [ "$#" -eq 0 ]; then
        return 0
    fi

    printf "%b\n" "Installing: $*"

    if [ "$_kind" = cask ]; then
        sudo_keepalive || printf "%b\n" "No held sudo session; casks may prompt individually."
        if brew install --cask --no-ask "$@"; then
            printf "%b\n" "Installed: $*"
            return 0
        fi
    else
        if brew install --formula --no-ask "$@"; then
            printf "%b\n" "Installed: $*"
            return 0
        fi
    fi

    printf "%b\n" "Failed to install one or more of: $*"
    return 1
}

install_packages() {
    _brew_install_batch formula "$@"
}

install_casks() {
    _brew_install_batch cask "$@"
}

brew_path() {
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$candidate" ]; then
            printf "%s\n" "$candidate"
            return 0
        fi
    done
    return 1
}

checkPackageManager() {
    brew_bin=$(brew_path) || brew_bin=""

    if [ -n "$brew_bin" ]; then
        eval "$("$brew_bin" shellenv)"
        printf "%b\n" "Homebrew is Installed"
        return 0
    fi

    printf "%b\n" "Homebrew is not installed"
    printf "%b\n" "Installing Homebrew..."

    if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        printf "%b\n" "Failed to install Homebrew"
        exit 1
    fi

    brew_bin=$(brew_path) || brew_bin=""
    if [ -z "$brew_bin" ]; then
        printf "%b\n" "Homebrew installed but no brew binary at /opt/homebrew or /usr/local"
        exit 1
    fi

    eval "$("$brew_bin" shellenv)"

    if ! grep -qs 'brew shellenv' "$HOME/.zprofile"; then
        printf '%s\n' "eval \"\$($brew_bin shellenv)\"" >>"$HOME/.zprofile"
    fi
}

install_package() {
    _brew_install_batch formula "$@"
}

install_cask() {
    _brew_install_batch cask "$@"
}

get_file_from_web() {
    url="$1"
    file="$2"

    if [ -z "$url" ] || [ -z "$file" ]; then
        printf "%b\n" "Url or File does not exist\n" >&2
        return 2
    fi

    case "$file" in
    ./*) file="$(pwd)/${file#./}" ;;
    /*) ;;
    *) file="$(pwd)/$file" ;;
    esac

    file_directory=$(dirname "$file")
    if [ ! -d "$file_directory" ]; then
        mkdir -p "$file_directory" || {
            printf "%b\n" "Failed to create directory $file_directory\n" >&2
            return 1
        }
    fi

    if [ -z "${TEMP_DIR:-}" ] || [ ! -d "$TEMP_DIR" ]; then
        printf "%b\n" "Missing or Invalid Temp Directory\n" >&2
        return 2
    fi

    tmpdir="$TEMP_DIR"
    tmpfile="$tmpdir/$(basename "$file").part.$$"

    rc=0
    if command_exists curl; then
        if curl --fail --location --show-error --progress-bar -o "$tmpfile" "$url"; then
            mv "$tmpfile" "$file"
            rc=0
        else
            rc=$?
            rm -f "$tmpfile"
            printf "%b\n" "Failed to download $url (curl rc=$rc)\n" >&2
        fi
    else
        printf "%b\n" "Error: curl is not installed.\n" >&2
        rc=1
    fi

    return $rc
}

checkPackageManager
