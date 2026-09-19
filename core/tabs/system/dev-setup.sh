#!/usr/bin/env bash

# menu: Developer Setup
# desc: CLI tools, Node, bun, global packages and apps

. "$COMMON_SCRIPT"

DEPENDENCIES='tree unzip python pipx cmake make jq fd ripgrep automake autoconf ffmpeg imagemagick tldr rust git'

CASKS='ghostty alfred rectangle keka docker-desktop conductor claude-code'

GLOBAL_PACKAGES='lite-server http-server license gitignore'

install_depend() {
    printf "%b\n" "Installing dependencies..."
    # shellcheck disable=SC2086
    install_packages $DEPENDENCIES
}

setup_config() {
    for dotfile in .gitconfig .gitignore; do
        src="$DOT_FILES/$dotfile"
        dest="$HOME/$dotfile"
        if [ -f "$src" ]; then
            cp "$src" "$dest"
        else
            printf "%b\n" "Warning: $src not found, skipping."
        fi
    done
}

load_nvm() {
    NVM_DIR="$HOME/.nvm"
    export NVM_DIR

    [ -s "$NVM_DIR/nvm.sh" ] || return 1

    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    return 0
}

install_nvm() {
    if load_nvm; then
        printf "%b\n" "nvm is installed"
    else
        printf "%b\n" "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash

        if ! load_nvm; then
            printf "%b\n" "nvm installed but $HOME/.nvm/nvm.sh is missing; skipping Node setup."
            return 1
        fi
    fi

    nvm install 25
    nvm use stable
}

load_bun() {
    BUN_INSTALL="$HOME/.bun"
    [ -x "$BUN_INSTALL/bin/bun" ] || return 1

    PATH="$BUN_INSTALL/bin:$PATH"
    export BUN_INSTALL PATH
    return 0
}

install_pkg() {
    if load_bun; then
        printf "%b\n" "bun is installed"
        return 0
    fi

    printf "%b\n" "Installing bun..."
    curl -fsSL https://bun.sh/install | bash

    load_bun || printf "%b\n" "bun installed but $HOME/.bun/bin/bun is missing."
}

bun_global_packages() {
    bun pm ls -g </dev/null 2>/dev/null |
        awk 'NR > 1 { name = $NF; sub(/@[^@]*$/, "", name); print name }'
}

install_global_packages() {
    local installed missing="" pkg

    printf "%b\n" "Installing global bun packages..."

    if ! load_bun; then
        printf "%b\n" "bun is not installed at $HOME/.bun/bin/bun; skipping global packages."
        return 1
    fi

    installed="$(bun_global_packages)"
    for pkg in $GLOBAL_PACKAGES; do
        printf '%s\n' "$installed" | grep -qxF -- "$pkg" || missing="${missing}${pkg} "
    done

    if [ -z "$missing" ]; then
        printf "%b\n" "Already installed: $GLOBAL_PACKAGES"
    else
        printf "%b\n" "Installing: ${missing% }"
        # shellcheck disable=SC2086
        bun add -g $missing </dev/null || printf "%b\n" "bun add reported a failure; checking what landed anyway."
    fi

    missing=""
    for pkg in $GLOBAL_PACKAGES; do
        [ -x "$BUN_INSTALL/bin/$pkg" ] || missing="${missing}${pkg} "
    done

    if [ -z "$missing" ]; then
        printf "%b\n" "All global package commands are installed in $BUN_INSTALL/bin."
        return 0
    fi

    printf "%b\n" "Not installed: ${missing% }"
    return 1
}

setup_casks() {
    printf "%b\n" "Installing casks..."
    # shellcheck disable=SC2086
    install_casks $CASKS

    install_ghostty_config
}

install_ghostty_config() {
    GHOSTTY_SRC="$DOT_FILES/ghostty.config"
    GHOSTTY_DIR="$HOME/.config/ghostty"
    GHOSTTY_APPSUPPORT="$HOME/Library/Application Support/com.mitchellh.ghostty"

    if [ ! -f "$GHOSTTY_SRC" ]; then
        printf "%b\n" "Warning: $GHOSTTY_SRC not found, skipping Ghostty config."
        return 1
    fi

    mkdir -p "$GHOSTTY_DIR"
    cp "$GHOSTTY_SRC" "$GHOSTTY_DIR/config"
    printf "%b\n" "Installed Ghostty config to $GHOSTTY_DIR/config"

    for _override in config config.ghostty; do
        _path="$GHOSTTY_APPSUPPORT/$_override"
        if [ -f "$_path" ]; then
            mv "$_path" "$_path.superseded"
            printf "%b\n" "Moved aside $_path, which would have overridden the installed config."
        fi
    done

    if cmp -s "$GHOSTTY_SRC" "$GHOSTTY_DIR/config"; then
        printf "%b\n" "Verified: $GHOSTTY_DIR/config matches $GHOSTTY_SRC."
    else
        printf "%b\n" "Ghostty config did not copy correctly to $GHOSTTY_DIR/config."
    fi
}

install_depend
setup_config
install_nvm
install_pkg
install_global_packages
setup_casks
