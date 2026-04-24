#!/bin/sh -e

. "$COMMON_SCRIPT"

install_depend() {
    DEPENDENCIES="bat tree multitail fastfetch unzip fontconfig starship fzf"
    for pkg in $DEPENDENCIES; do
        if ! brew_program_exists "$pkg"; then
            printf "%b\n" "Installing $pkg...."
            brew install "$pkg"
            printf "%b\n" "$pkg installed successfully!"
        else
            printf "%b\n" "Failed to install $pkg. Please check your Homebrew installation."
            exit 1
        fi
    done
    FONT="font-fira-code-nerd-font"

    if ! brew_program_exists "$FONT"; then
        printf "%b\n" "Installing $FONT...."
        brew install --cask "$FONT"
        printf "%b\n" "$FONT installed successfully!"
    else
        printf "%b\n" "Failed to install $FONT. Please check your Homebrew installation."
        exit 1
    fi

    if [ -e ~/.fzf/install ]; then
        ~/.fzf/install --all
    fi
}

setup_zsh(){
    printf "%b\n" "Setting up Zsh configuration...."

    dotfiles=(starship.toml .zshrc)

    for dotfile in "${dotfiles[@]}"; do
        src="$DOT_FILES/$dotfile"
        dest="$HOME/$dotfile"
        if [ -f "$src" ]; then
            cp "$src" "$dest"
        else
            echo "Warning: $src not found, skipping."
        fi
    done

    if [ ! -f "$HOME/.zshrc" ]; then
        printf "Zsh configuration file not found!"
        exit 1
    fi

    . ~/.zshrc


    printf "Zsh configuration has been set up successfully. Restart Shell."
}

backup_config(){

    printf "%b\n" "Backing up existing Zsh configuration..."

    if [ -f "$HOME/.zshrc" ] && [ ! -f "$HOME/.zshrc.bak" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
        printf "%b\n" "Existing .zshrc backed up to .zshrc.bak."
    fi

    if [ -d "$HOME/.config/zsh" ] && [ ! -d "$HOME/.config/zsh.bak" ]; then
        cp -r "$HOME/.config/zsh" "$HOME/.config/zsh.bak"
        printf "%b\n" "Existing Zsh config backed up to .config/zsh.bak."
    fi
}

backup_config
install_depend
setup_zsh
