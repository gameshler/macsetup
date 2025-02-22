#!/bin/bash

CONFIG_FILE="$HOME/.mac_setup_config"
DEFAULT_CONFIG='{
  "casks": ["iterm2", "alfred", "rectangle", "alt-tab", "discord", "slack", "vlc", "keka", "visual-studio-code", "sublime-text", "docker"],
  "formulae": ["ffmpeg", "imagemagick", "wget", "telnet", "tldr"],
  "office_pkg_url": "https://mega.nz/file/PNNlWKCa#vBSY-AGuPyXB-qVMZwoSWg_cPd3o2w0008YF6fXNrTw",
  "serializer_url": "https://mega.nz/file/PAsTnRJD#JUIWkULr5tHN4VzE-v1iigHCFWAHtYHaZ52Cs0AZUeE",
  "office_apps": ["Word", "Excel", "PowerPoint"]
}'

load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
  else
    echo "$DEFAULT_CONFIG" >"$CONFIG_FILE"
    . "$CONFIG_FILE"
  fi
}

load_config
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

install_homebrew() {
  log_message "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.zprofile"
}

install_oh_my_zsh() {
  log_message "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_casks() {
  local casks=("$@")
  for cask in "${casks[@]}"; do
    brew install --cask "$cask"
  done
}
install_formulaes() {
  local formulaes=("$@")
  for formula in "${formulaes[@]}"; do
    brew install "$formula"
  done
}

download_office_files() {
  log_message "Downloading Office installation files..."
  mkdir -p ~/Downloads/Microsoft_Office
  # Download PKG file
  curl -fsSL "${config[office_pkg_url]}" -o ~/Downloads/Microsoft_Office/Microsoft_Office.pkg
  # Download Serializer
  curl -fsSL "${config[serializer_url]}" -o ~/Downloads/Microsoft_Office/Microsoft_Office_VL_Serializer.pkg
}

install_office() {
  log_message "Starting Office installation..."
  if [ -d "/Applications/Microsoft Office" ]; then
    log_message "Removing existing Office installation..."
    rm -rf "/Applications/Microsoft Office"
  fi

  download_office_files
  # check links
  log_message "Installing Office PKG..."
  sudo installer -pkg ~/Downloads/Microsoft_Office/Microsoft_Office.pkg -target /

  log_message "Installing Office Serializer..."
  sudo installer -pkg ~/Downloads/Microsoft_Office/Microsoft_Office_VL_Serializer.pkg -target /

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

main_installation() {
  log_message "Starting Mac setup..."
  install_homebrew
  install_oh_my_zsh
  install_casks "${config[casks]}"
  install_formulaes "${config[formulae]}"
  install_office
  log_message "setting up zsh profile..."
  DOTFILES=(.gitconfig .gitignore .zshrc)
  for dotfile in "${DOTFILES[@]}"; do
    cp ~/macsetup/$dotfile ~/$dotfile
  done
  source ~/.zshrc
  log_message "Installing Nodejs (nvm)..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  nvm install 20
  nvm use 20
  npm install -g lite-server http-server license gitignore

  log_message "Setup completed successfully!"
}

main_installation
