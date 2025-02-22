#!/bin/bash

<<<<<<< HEAD:setup.sh
# Configuration options
CONFIG_FILE="$HOME/.mac_setup_config"
DEFAULT_CONFIG='{
  "install_homebrew": false,
  "install_oh_my_zsh": false,
  "install_office": false,
  "casks": ["iterm2", "alfred", "rectangle", "alt-tab", "discord", "slack", "vlc", "keka", "visual-studio-code", "sublime-text", "docker"],
  "formulae": ["ffmpeg", "imagemagick", "wget", "telnet", "tldr"],
  "office_pkg_url": "https://mega.nz/file/PNNlWKCa#vBSY-AGuPyXB-qVMZwoSWg_cPd3o2w0008YF6fXNrTw",
  "serializer_url": "https://mega.nz/file/PAsTnRJD#JUIWkULr5tHN4VzE-v1iigHCFWAHtYHaZ52Cs0AZUeE",
  "office_apps": ["Word", "Excel", "PowerPoint"]
}'

# Function to load configuration
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
=======
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
>>>>>>> parent of 6dbaf8b (Updated Script):Mac Setup/setup.sh
  else
    echo "$DEFAULT_CONFIG" >"$CONFIG_FILE"
    . "$CONFIG_FILE"
  fi
}

# Load configuration
load_config

<<<<<<< HEAD:setup.sh
# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}
=======
# Install casks
echo "Installing casks..."
brew install --cask \
  iterm2 alfred rectangle alt-tab android-file-transfer android-platform-tools keepingyouawake discord slack vlc keka kap time-out figma visual-studio-code sublime-text
>>>>>>> parent of 6dbaf8b (Updated Script):Mac Setup/setup.sh

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

<<<<<<< HEAD:setup.sh
# Function to install casks
install_casks() {
  local casks=("$@")
  for cask in "${casks[@]}"; do
    brew install --cask "$cask"
  done
}
=======
# Loop through dotfiles and copy them
for dotfile in "${DOTFILES[@]}"; do
  cp ~/macsetup/$dotfile ~/
done
>>>>>>> parent of 6dbaf8b (Updated Script):Mac Setup/setup.sh

# Function to install formulaes
install_formulaes() {
  local formulaes=("$@")
  for formula in "${formulaes[@]}"; do
    brew install "$formula"
  done
}

<<<<<<< HEAD:setup.sh
# Function to download Office
download_office_files() {
  log_message "Downloading Office installation files..."
  mkdir -p ~/Downloads/Microsoft_Office
  # Download PKG file
  curl -fsSL "${config[office_pkg_url]}" -o ~/Downloads/Microsoft_Office/Microsoft_Office.pkg
  # Download Serializer
  curl -fsSL "${config[serializer_url]}" -o ~/Downloads/Microsoft_Office/Microsoft_Office_VL_Serializer.pkg
}

install_office() {
  if [ "${config[install_office]}" != "true" ] ||
    [ -z "${config[office_pkg_url]}" ] ||
    [ -z "${config[serializer_url]}" ]; then
    return
  fi

  log_message "Starting Office installation..."

  # Remove existing Office installation
  if [ -d "/Applications/Microsoft Office" ]; then
    log_message "Removing existing Office installation..."
    rm -rf "/Applications/Microsoft Office"
  fi

  # Download files
  download_office_files

  # Install Office PKG
  log_message "Installing Office PKG..."
  sudo installer -pkg ~/Downloads/Microsoft_Office/Microsoft_Office.pkg -target /

  # Install Serializer
  log_message "Installing Office Serializer..."
  sudo installer -pkg ~/Downloads/Microsoft_Office/Microsoft_Office_VL_Serializer.pkg -target /

  # Verify installation
  log_message "Verifying Office installation..."
  for app in "${config[office_apps]}"; do
    if [ ! -f "/Applications/Microsoft $app.app" ]; then
      log_message "Error: $app not found after installation"
      return 1
    fi
  done

  log_message "Office installation and activation completed successfully!"
  return 0
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

  # Install Office
  if $install_office; then
    log_message "Installation Successful"
  else
    log_message "Error installing Office. Continuing without it."
  fi

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
=======
echo "Setup completed successfully!"
>>>>>>> parent of 6dbaf8b (Updated Script):Mac Setup/setup.sh
