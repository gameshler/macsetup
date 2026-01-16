#!/bin/sh -e

command_exists() {
for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || return 1
done
return 0
}

brew_program_exists() {
for cmd in "$@"; do
    brew list "$cmd" >/dev/null 2>&1 || return 1
done
return 0
}

checkPackageManager() {
  if command_exists "brew"; then
  printf "Homebrew is Installed"
  else
  	printf "Homebrew is not installed"
  	printf "Installing Homebrew..."
  	sudo -A /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  	install_result=$?

  	if [ $install_result -ne 0]; then
  		printf "Failed to install Homebrew"
  		exit 1
  	fi

  	if [ -f "/opt/homebrew/bin/brew" ]; then
    	echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.zprofile"
    	eval "$(/opt/homebrew/bin/brew shellenv)"
  	elif [ -f "/usr/local/bin/brew" ]; then
    	eval "$(/usr/local/bin/brew shellenv)"
  	fi
  	trap EXIT INT TERM
  fi
}

