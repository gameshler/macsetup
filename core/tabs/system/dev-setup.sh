#!/bin/sh -e

. "$COMMON_SCRIPT"

install_depend() {
    DEPENDENCIES='tree unzip python pipx cmake make jq fd ripgrep automake autoconf ffmpeg imagemagick tldr'
    printf "Installing dependencies..."
    brew install $DEPENDENCIES
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
        printf "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
        nvm install 25
        nvm use stable
    else
        printf "nvm is installed"
        nvm install 25
        nvm use stable
    fi
}

install_npm_depend() {
    DEPENDENCIES='lite-server http-server license gitignore'
    if ! command_exists "pnpm"; then
        curl -fsSL https://get.pnpm.io/install.sh | sh -
    fi
    . ~/.zshrc 
    printf "installing dependencies"
    pnpm install $DEPENDENCIES
}

install_casks() {
    CASKS='ghostty alfred rectangle alt-tab keka docker'
    printf "Installing casks..."
    brew install --cask $CASKS
}

checkPackageManager
install_depend
setup_config
install_nvm
install_npm_depend
install_casks
