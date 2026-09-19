#!/usr/bin/env bash

set -euo pipefail

REPO="gameshler/macsetup"
BRANCH="main"
TEMP_DIR=$(mktemp -d -t macsetup-XXXXXX)
export TEMP_DIR
export INSTALL_DIR="$HOME/Downloads/macsetup"

main() {
    ZIP_FILE="$TEMP_DIR/$BRANCH.zip"
    if ! curl -fsSL -o "$ZIP_FILE" "https://github.com/$REPO/archive/refs/heads/$BRANCH.zip"; then
        echo -e "Failed to download repository"
        exit 1
    fi

    if ! unzip -q "$ZIP_FILE" -d "$TEMP_DIR"; then
        echo -e "Failed to extract repository"
        exit 1
    fi

    EXTRACTED_DIR="$TEMP_DIR/$(basename "$REPO")-$BRANCH"
    if [[ ! -d "$EXTRACTED_DIR" ]]; then
        echo -e "Extracted directory not found at $EXTRACTED_DIR"
        exit 1
    fi

    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    mkdir -p "$(dirname "$INSTALL_DIR")"
    mv "$EXTRACTED_DIR" "$INSTALL_DIR"

    find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} +

    MAIN_SCRIPT="$INSTALL_DIR/core/main.sh"
    if [[ -f "$MAIN_SCRIPT" ]]; then
        "$MAIN_SCRIPT"
    else
        echo -e "Main script not found at $MAIN_SCRIPT"
        exit 1
    fi
}

main
