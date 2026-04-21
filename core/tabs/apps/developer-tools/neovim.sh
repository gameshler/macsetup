#!/bin/sh -e

. "$COMMON_SCRIPT"

clone_neovim() {
    if [ -z "${TEMP_DIR:-}" ] || [ ! -d "$TEMP_DIR" ]; then
        printf "Missing or Invalid Temp Directory\n" >&2
        exit 1
    fi

    git clone https://github.com/gameshler/neovim.git "$TEMP_DIR/neovim"

}

install_neovim() {
    if ! brew_program_exists neovim ripgrep git fzf lua; then
        printf "Installing Neovim..."
        brew install neovim ripgrep shellcheck fzf luarocks git
        if [ $? -ne 0 ]; then
            printf "Failed to install Neovim. Please check your Homebrew installation."
            exit 1
        fi
        printf "Neovim installed successfully!"
    else
        printf "Neovim already installed."
    fi
}

link_neovim_config() {
    printf "Linking Neovim Configuration Files..."
    mkdir -p "$HOME/.config/nvim"
    cp -r "$TEMP_DIR/neovim/lua" "$HOME/.config/nvim/"
    cp -r "$TEMP_DIR/neovim/init.lua" "$HOME/.config/nvim/"
    cp -r "$TEMP_DIR/neovim/lazy-lock.json" "$HOME/.config/nvim/"

}

checkPackageManager
install_neovim
clone_neovim
link_neovim_config
