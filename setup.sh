#!/bin/bash

# Function to check if Homebrew is installed
is_homebrew_installed() {
  command -v brew >/dev/null 2>&1
}

# Check if Homebrew is already installed
if ! is_homebrew_installed; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew is already installed. Skipping installation."
fi

# Add Homebrew to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.zprofile"
eval "$(/opt/homebrew/bin/brew shellenv)"

# Function to check if Oh My Zsh is installed
is_oh_my_zsh_installed() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    return 0
  else
    return 1
  fi
}

# Check if Oh My Zsh is already installed
if ! is_oh_my_zsh_installed; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "Oh My Zsh is already installed. Skipping installation."
fi

# Install casks
echo "Installing casks..."
brew install --cask \
  iterm2 alfred rectangle alt-tab discord slack vlc keka visual-studio-code sublime-text docker

# Install formulaes
echo "Installing formulas..."
brew install ffmpeg imagemagick wget telnet tldr

# Set up zsh profile
echo "Setting up zsh profile..."

# Define dotfiles array
DOTFILES=(.gitconfig .gitignore .zshrc)

# Loop through dotfiles and copy them
for dotfile in "${DOTFILES[@]}"; do
  cp ~/macsetup/$dotfile ~/$dotfile
done

# Source the copied zsh profile
source ~/.zshrc

# Install Nodejs (nvm)
echo "Installing Nodejs (nvm)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
nvm install 20
nvm use 20
npm install -g lite-server http-server license gitignore

echo "Setup completed successfully!"
