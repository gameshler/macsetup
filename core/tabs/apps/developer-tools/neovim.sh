#!/bin/sh -e

. "$COMMON_SCRIPT"

clone_neovim() {
    if [ -z "${TEMP_DIR:-}" ] || [ ! -d "$TEMP_DIR" ]; then
        printf "%b\n" "Missing or Invalid Temp Directory\n" >&2
        exit 1
    fi

    git clone https://github.com/gameshler/neovim.git "$TEMP_DIR/neovim"

}

install_neovim() {
    if ! brew_program_exists neovim ripgrep git fzf lua; then
        printf "%b\n" "Installing Neovim..."
        brew install neovim ripgrep shellcheck fzf luarocks git
        if [ $? -ne 0 ]; then
            printf "%b\n" "Failed to install Neovim. Please check your Homebrew installation."
            exit 1
        fi
        printf "%b\n" "Neovim installed successfully!"
    else
        printf "%b\n" "Neovim already installed."
    fi
}

link_neovim_config() {
    printf "%b\n" "Linking Neovim Configuration Files..."
    mkdir -p "$HOME/.config/nvim"
    cp -r "$TEMP_DIR/neovim/lua" "$HOME/.config/nvim/"
    cp -r "$TEMP_DIR/neovim/init.lua" "$HOME/.config/nvim/"
    cp -r "$TEMP_DIR/neovim/lazy-lock.json" "$HOME/.config/nvim/"

}

install_neovim
clone_neovim
link_neovim_config
