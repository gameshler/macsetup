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
echo "Downloading Microsoft Office Installer packages..."

# URL for Microsoft_365_and_Office_Installer and Microsoft Office Serializer
OFFICE_INSTALLER_URL="https://mega.nz/file/PNNlWKCa#vBSY-AGuPyXB-qVMZwoSWg_cPd3o2w0008YF6fXNrTw"
OFFICE_SERIALIZER_URL="https://mega.nz/file/PAsTnRJD#JUIWkULr5tHN4VzE-v1iigHCFWAHtYHaZ52Cs0AZUeE"

# Use curl to download the Office Installer and Serializer
curl -L -o ~/Downloads/Microsoft_365_and_Office_Installer.pkg $OFFICE_INSTALLER_URL
curl -L -o ~/Downloads/microsoft_office_ltsc_2024_vl_serializer.pkg $OFFICE_SERIALIZER_URL

# Install Microsoft 365 Office using the downloaded packages
echo "Installing Microsoft 365 Office..."
sudo installer -pkg ~/Downloads/Microsoft_365_and_Office_Installer.pkg -target /

# Install Microsoft Office Serializer (activation)
echo "Installing Microsoft Office Serializer..."
sudo installer -pkg ~/Downloads/microsoft_office_ltsc_2024_vl_serializer.pkg -target /

# Cleanup the downloaded files
echo "Cleaning up..."
rm ~/Downloads/Microsoft_365_and_Office_Installer.pkg
rm ~/Downloads/microsoft_office_ltsc_2024_vl_serializer.pkg

echo "Office installation completed successfully!"
echo "Setup completed successfully!"
