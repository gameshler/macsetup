#!/usr/bin/env/sh -e

. "$COMMON_SCRIPT"

install_depend() {
    DEPENDENCIES='tree unzip python pipx cmake make jq fd ripgrep automake autoconf ffmpeg imagemagick tldr rust git'
    printf "%b\n" "Installing dependencies..."
    for pkg in $DEPENDENCIES; do
        install_package "$pkg"
    done

}

setup_config() {

    dotfiles=(.gitconfig .gitignore)

    for dotfile in "${dotfiles[@]}"; do
        src="$DOT_FILES/$dotfile"
        dest="$HOME/$dotfile"
        if [ -f "$src" ]; then
            cp "$src" "$dest"
        else
            echo "Warning: $src not found, skipping."
        fi
    done

    . ~/.zshrc

}

install_nvm() {
    if ! command_exists "nvm"; then
        printf "%b\n" "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

        nvm install 25
        nvm use stable
    else
        printf "%b\n" "nvm is installed"
        nvm install 25
        nvm use stable
    fi
}

install_npm_depend() {
    if ! command_exists "pnpm"; then
        curl -fsSL https://get.pnpm.io/install.sh | sh -

        export PNPM_HOME="/Users/$USER/Library/pnpm"
        case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
        esac

    fi
    . ~/.zshrc
}

install_casks() {
    CASKS='ghostty alfred rectangle alt-tab keka docker conductor'
    printf "%b\n" "Installing casks..."
    for pkg in $CASKS; do
        install_cask "$pkg"
    done

    CONFIG="$HOME/Library/Application\ Support/com.mitchellh.ghostty/"

    if [ -f "$CONFIG" ]; then
        cp "$DOT_FILES/config" "$CONFIG"
    fi

}

install_claude() {
     if ! command_exists "claude"; then
         curl -fsSL https://claude.ai/install.sh | bash
         claude --version 
     else 
         printf "%b\n" "claude is installed"
         printf "%b\n" "Please run /login if not authenticated"
     fi
   
}

install_depend
setup_config
install_nvm
install_npm_depend
install_casks
install_claude
