#!/bin/bash

# Set up Homebrew
echo "Setting up Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

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
  iterm2 alfred rectangle alt-tab android-file-transfer android-platform-tools keepingyouawake discord slack vlc keka kap time-out figma visual-studio-code sublime-text

# Install formulaes
echo "Installing formulas..."
brew install ffmpeg imagemagick wget telnet tldr

# Set up zsh profile
echo "Setting up zsh profile..."

# Define dotfiles array
DOTFILES=(.gitconfig .gitignore .zshrc)

# Loop through dotfiles and copy them
for dotfile in "${DOTFILES[@]}"; do
  cp ~/macsetup/$dotfile ~/
done

# Source the copied zsh profile
source ~/.zshrc

echo "Setup completed successfully!"
