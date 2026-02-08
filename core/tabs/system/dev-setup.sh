#!/bin/zsh -e

. "$COMMON_SCRIPT"

installDepend() {
    DEPENDENCIES='tree unzip python pipx cmake make jq fd ripgrep automake autoconf ffmpeg imagemagick tldr'
    printf "Installing dependencies..."
    brew install $DEPENDENCIES
}

setupZshConfig() {
    printf "Setting up Zsh Configuration..."

    dotfiles=(.gitconfig .zshrc)

    for dotfile in "${dotfiles[@]}"; do
        src="$DOT_FILES/$dotfile"
        dest="$HOME/$dotfile"
        if [ -f "$src" ]; then
            cp "$src" "$dest"
        else
            echo "Warning: $src not found, skipping."
        fi
    done

    source ~/.zshrc

    if [ ! -f "$HOME/.zshrc" ]; then
        printf "Zsh configuration file not found!"
        exit 1
    fi

    printf "Zsh configuration has been set up successfully. Restart Shell."

}

installNvm() {
    if ! command_exists "nvm"; then 
     printf "Installing NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        nvm install 25
        nvm use stable
    else 
     printf "nvm is installed"
        nvm install 25
        nvm use stable
    fi
}

installNpmDepend() {
    DEPENDENCIES='lite-server http-server license gitignore'
    if ! command_exists "pnpm"; then
    curl -fsSL https://get.pnpm.io/install.sh | sh -
    fi
    source ~/.zshrc
    printf "installing dependencies"
    pnpm install $DEPENDENCIES
}

installCasks() {
    CASKS='iterm2 alfred rectangle alt-tab keka docker'
    printf "Installing casks..."
    brew install --cask $CASKS
}

checkPackageManager
installDepend
setupZshConfig
installNvm
installNpmDepend
installCasks
