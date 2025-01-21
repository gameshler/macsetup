#!/bin/bash

# Configuration options
CONFIG_FILE="$HOME/.mac_setup_config"
DEFAULT_CONFIG='{
  "install_homebrew": true,
  "install_oh_my_zsh": true,
  "casks": ["iterm2", "alfred", "rectangle", "alt-tab", "discord", "slack", "vlc", "keka", "visual-studio-code", "sublime-text", "docker"],
  "formulae": ["ffmpeg", "imagemagick", "wget", "telnet", "tldr"]
}'

# Function to load configuration
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
  else
    echo "$DEFAULT_CONFIG" >"$CONFIG_FILE"
    . "$CONFIG_FILE"
  fi
}

# Load configuration
load_config

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to install Homebrew
install_homebrew() {
  if ! command_exists brew; then
    log_message "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.zprofile"
    return 0
  fi
  log_message "Homebrew is already installed."
  return 1
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
  if ! [ -d "$HOME/.oh-my-zsh" ]; then
    log_message "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    return 0
  fi
  log_message "Oh My Zsh is already installed."
  return 1
}

# Function to install casks
install_casks() {
  local casks=("$@")
  for cask in "${casks[@]}"; do
    brew install --cask "$cask"
  done
}

# Function to install formulaes
install_formulaes() {
  local formulaes=("$@")
  for formula in "${formulaes[@]}"; do
    brew install "$formula"
  done
}

# Main installation function
main_installation() {
  log_message "Starting Mac setup..."

  # Install Homebrew
  if $install_homebrew; then
    log_message "Homebrew installation successful."
  else
    log_message "Error installing Homebrew. Exiting."
    exit 1
  fi

  # Install Oh My Zsh
  if $install_oh_my_zsh; then
    log_message "Oh My Zsh installation successful."
  else
    log_message "Error installing Oh My Zsh. Continuing without it."
  fi

  # Install casks
  log_message "Installing casks..."
  install_casks "${config[casks]}"

  # Install formulaes
  log_message "Installing formulaes..."
  install_formulaes "${config[formulae]}"

  # Set up zsh profile
  log_message "Setting up zsh profile..."

  # Define dotfiles array
  DOTFILES=(.gitconfig .gitignore .zshrc)

  # Loop through dotfiles and copy them
  for dotfile in "${DOTFILES[@]}"; do
    cp ~/macsetup/$dotfile ~/$dotfile
  done

  # Source the copied zsh profile
  source ~/.zshrc

  # Install Nodejs (nvm)
  log_message "Installing Nodejs (nvm)..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  nvm install 20
  nvm use 20
  npm install -g lite-server http-server license gitignore

  log_message "Setup completed successfully!"
}

# Run the main installation function
main_installation
