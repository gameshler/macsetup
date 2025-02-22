#!/bin/bash

is_homebrew_installed() {
  command -v brew >/dev/null 2>&1
}

if ! is_homebrew_installed; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew is already installed. Skipping installation."
fi
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.zprofile"
echo "Installing casks..."
brew install --cask \
  iterm2 alfred rectangle alt-tab discord slack vlc keka visual-studio-code sublime-text docker
echo "Installing formulas..."
brew install ffmpeg imagemagick wget telnet tldr
DOTFILES=(.gitconfig .gitignore .zshrc)
for dotfile in "${DOTFILES[@]}"; do
  cp ~/macsetup/$dotfile ~/
  cp ~/macsetup/$dotfile ~/$dotfile
done
source ~/.zshrc
echo "Installing Nodejs (nvm)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
nvm install 20
nvm use 20
npm install -g lite-server http-server license gitignore
echo "Setup completed successfully!"
