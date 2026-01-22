#!/bin/sh -e

. "$COMMON_SCRIPT"

OFFICE_PKG_URL="https://drive.usercontent.google.com/download?id=1pJWOhKQy8bpJ6lb3KBjP6FI4svztflsE&export=download&authuser=0&confirm=t&uuid=6e26f0f0-8d4c-4897-8011-05092730ab8b&at=APcXIO2IiVe-L-BPPHvNEaXF1zG8:1769118187754"
SERIALIZER_PKG_URL="https://drive.usercontent.google.com/download?id=11-uNaVy01Pq-pW8tDcy2TyIjHvMjrSJr&export=download&authuser=0&confirm=t&uuid=55a431eb-28bb-4dd9-babb-151cb392368e&at=APcXIO0DRDyEUB7nn2rTgh8vt2FT:1769118234441"

if [ -z "${TEMP_DIR:-}" ] || [ ! -d "$TEMP_DIR" ]; then
	printf "Missing or Invalid Temp Directory\n" >&2
	exit 1
fi

office_pkg="$TEMP_DIR/office.pkg"
serializer_pkg="$TEMP_DIR/serializer.pkg"

printf "Downloading Office package to %s...\n" "$office_pkg"
if ! get_file_from_web "$OFFICE_PKG_URL" "$office_pkg"; then
	printf "Office download failed.\n" >&2
	exit 1
fi

printf "Installing Office package...\n"
if command_exists installer; then
	sudo installer -pkg "$office_pkg" -target / || {
		printf "Failed to install Office package.\n" >&2
		exit 1
	}
else
	printf "installer command not found; please install manually: %s\n" "$office_pkg" >&2
	exit 1
fi

printf "Downloading serializer package to %s...\n" "$serializer_pkg"
if ! get_file_from_web "$SERIALIZER_PKG_URL" "$serializer_pkg"; then
	printf "Serializer download failed.\n" >&2
	exit 1
fi

printf "Installing serializer package...\n"
if command_exists installer; then
	sudo installer -pkg "$serializer_pkg" -target / || {
		printf "Failed to install serializer package.\n" >&2
		exit 1
	}
fi

printf "Office and serializer installed successfully.\n"

exit 0

