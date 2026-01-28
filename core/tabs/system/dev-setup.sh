#!/bin/sh -e

. "$COMMON_SCRIPT"

installDepend() {
  DEPENDENCIES='tree unzip python pipx cmake make jq fd ripgrep automake autoconf ffmpeg imagemagick tldr'
  printf "Installing dependencies..."
  brew install $DEPENDENCIES
}

setupZshConfig() {
  printf "Setting up Zsh Configuration..."

  if [ ! -f "$HOME/.oh-my-zsh" ]; then
    printf "oh-my-zsh file not found!"
    printf "installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    printf "Oh My Zsh is already installed. Skipping installation."
  fi

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

installNvm(){
  if command_exists "nvm"; then
    printf "nvm is installed"
    nvm install 25
    nvm use stable
  else
    printf "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    nvm install 25
    nvm use stable
  fi
}

installNpmDepend() {
  DEPENDENCIES='lite-server http-server license gitignore'
  printf "installing dependencies"
  npm install $DEPENDENCIES
}

installCasks(){
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

