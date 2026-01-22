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

get_file_from_web() {
	url="$1"
	file="$2"

	if [ -z "$url" ] || [ -z "$file" ]; then
		printf "Usage: get_file_from_web URL FILE\n" >&2
		return 2
	fi

	case "$file" in
		./*) file="$(pwd)/${file#./}" ;;
		/*) ;;
		*) file="$(pwd)/$file" ;;
	esac

	file_directory=$(dirname "$file")
	if [ ! -d "$file_directory" ]; then
		mkdir -p "$file_directory" || { printf "Failed to create directory %s\n" "$file_directory" >&2; return 1; }
	fi

	tmpdir=""
	created_tmpdir=0
	if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
		tmpdir="$TEMP_DIR"
	else
		tmpdir="$(mktemp -d 2>/dev/null || true)"
		if [ -z "$tmpdir" ]; then
			printf "Failed to create temporary directory.\n" >&2
			return 1
		fi
		created_tmpdir=1
	fi

	tmpfile="$tmpdir/$(basename "$file").part.$$"

	rc=0
	if command_exists curl; then
		if curl --fail --location --show-error --progress-bar -o "$tmpfile" "$url"; then
			mv "$tmpfile" "$file"
			rc=0
		else
			rc=$?
			rm -f "$tmpfile"
			printf "Failed to download %s (curl rc=%d)\n" "$url" "$rc" >&2
		fi
	else
		printf "Error: curl is not installed.\n" >&2
		rc=1
	fi

	if [ "$created_tmpdir" -eq 1 ] && [ -d "$tmpdir" ]; then
		rm -rf "$tmpdir"
	fi

	return $rc
}
