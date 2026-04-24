#!/bin/sh
set -e

. "$COMMON_SCRIPT"

install_package() {
    pkg="$1"

    if brew_program_exists "$pkg"; then
        printf "%b\n" "$pkg is already installed. Skipping."
        return 0
    fi

    printf "%b\n" "Installing $pkg..."

    if brew install "$pkg"; then
        printf "%b\n" "$pkg installed successfully!"
    else
        printf "%b\n" "Failed to install $pkg."
        exit 1
    fi
}

install_cask() {
    pkg="$1"

    if brew_program_exists "$pkg"; then
        printf "%b\n" "$pkg is already installed. Skipping."
        return 0
    fi

    printf "%b\n" "Installing cask $pkg..."

    if brew install --cask "$pkg"; then
        printf "%b\n" "$pkg installed successfully!"
    else
        printf "%b\n" "Failed to install cask $pkg."
        exit 1
    fi
}

backup_config() {
    printf "%b\n" "Backing up existing Zsh configuration..."

    if [ -f "$HOME/.zshrc" ] && [ ! -f "$HOME/.zshrc.bak" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
        printf "%b\n" "Backed up ~/.zshrc to ~/.zshrc.bak"
    fi

    if [ -d "$HOME/.config/zsh" ] && [ ! -d "$HOME/.config/zsh.bak" ]; then
        cp -r "$HOME/.config/zsh" "$HOME/.config/zsh.bak"
        printf "%b\n" "Backed up ~/.config/zsh to ~/.config/zsh.bak"
    fi
}

install_depend() {
    printf "%b\n" "Installing dependencies..."

    DEPENDENCIES="zsh-autocomplete bat tree multitail fastfetch unzip fontconfig starship fzf"

    for pkg in $DEPENDENCIES; do
        install_package "$pkg"
    done

    install_cask "font-fira-code-nerd-font"

    if [ -f "$HOME/.fzf/install" ]; then
        "$HOME/.fzf/install" --all
    fi
}

setup_zsh() {
    printf "%b\n" "Setting up Zsh configuration..."

    mkdir -p "$HOME/.config"

    if [ -f "$DOT_FILES/starship.toml" ]; then
        cp "$DOT_FILES/starship.toml" "$HOME/.config/starship.toml"
        printf "%b\n" "Installed starship config."
    else
        printf "%b\n" "Warning: starship.toml not found, skipping."
    fi

    if [ -f "$DOT_FILES/.zshrc" ]; then
        cp "$DOT_FILES/.zshrc" "$HOME/.zshrc"
        printf "%b\n" "Installed .zshrc"
    else
        printf "%b\n" "Error: .zshrc not found in $DOT_FILES"
        exit 1
    fi

    printf "%b\n" ""
    printf "%b\n" "Zsh configuration complete."
    printf "%b\n" "Restart your shell or run:"
    printf "%b\n" "source ~/.zshrc"
}

backup_config
install_depend
setup_zsh
