#!/usr/bin/env bash

# menu: Git SSH Key
# desc: Create a GitHub SSH key and upload it

. "$COMMON_SCRIPT"

SSH_DIR="$HOME/.ssh"
KEY="$SSH_DIR/id_ed25519"
PUB="$KEY.pub"
CONFIG="$SSH_DIR/config"

key_comment() {
    local email
    email="$(git config --get user.email 2>/dev/null)"

    if [ -n "$email" ]; then
        printf '%s' "$email"
        return 0
    fi

    printf '%s@%s' "$(whoami)" "$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
}

port_22_reachable() {
    local out
    out="$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
        -T git@github.com </dev/null 2>&1)"

    case "$out" in
    *"port 22: Connection refused"* | *"port 22: Operation timed out"* | \
        *"port 22: Connection timed out"* | *"port 22: Network is unreachable"*)
        return 1
        ;;
    esac

    return 0
}

ensure_key() {
    local comment

    if [ -e "$KEY" ] || [ -e "$PUB" ]; then
        printf "%b\n" "An ed25519 key already exists at $KEY; leaving it untouched."
        return 0
    fi

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    comment="$(key_comment)"
    printf "%b\n" "Generating an ed25519 key labelled $comment..."
    printf "%b\n" "Choose a passphrase. It is stored in the keychain, so it is asked for once."

    ssh-keygen -t ed25519 -C "$comment" -f "$KEY" || {
        printf "%b\n" "ssh-keygen failed; no key was written."
        return 1
    }
}

configure_ssh() {
    if [ -f "$CONFIG" ] && grep -qE '^[[:space:]]*Host[[:space:]]+.*\bgithub\.com\b' "$CONFIG"; then
        printf "%b\n" "$CONFIG already has a github.com entry; leaving it untouched."
        return 0
    fi

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    printf "%b\n" "Adding a github.com block to $CONFIG..."

    printf '\n' >>"$CONFIG"

    if port_22_reachable; then
        cat >>"$CONFIG" <<EOF
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile $KEY
EOF
    else
        printf "%b\n" "github.com:22 is refused on this network; routing over ssh.github.com:443."
        cat >>"$CONFIG" <<EOF
Host github.com
  Hostname ssh.github.com
  Port 443
  User git
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile $KEY
EOF
    fi

    chmod 600 "$CONFIG"
}

load_key() {
    local agent_status

    [ -f "$KEY" ] || return 1

    ssh-add -l >/dev/null 2>&1
    agent_status=$?

    if [ "$agent_status" -eq 2 ]; then
        printf "%b\n" "Starting ssh-agent..."
        eval "$(ssh-agent -s)" >/dev/null
    fi

    printf "%b\n" "Adding the key to the agent and the keychain..."
    ssh-add --apple-use-keychain "$KEY" || printf "%b\n" "ssh-add did not load the key."
}

ensure_gh() {
    if command_exists gh; then
        return 0
    fi

    printf "%b\n" "GitHub CLI is not installed; installing it..."
    install_package gh || return 1
    command_exists gh
}

key_already_uploaded() {
    local material
    material="$(awk '{ print $2 }' "$PUB" 2>/dev/null)"
    [ -n "$material" ] || return 1

    gh api user/keys --jq '.[].key' 2>/dev/null |
        awk '{ print $2 }' |
        grep -qxF -- "$material"
}

manual_upload() {
    if pbcopy <"$PUB"; then
        printf "%b\n" "The public key is on the clipboard. Paste it into the page opening now."
    else
        printf "%b\n" "Could not reach the clipboard. Copy the key below into the page opening now:"
        cat "$PUB"
    fi

    open "https://github.com/settings/ssh/new"

    printf "%b\n" "GitHub accepts the key the moment you save it there."
    read -rp "  Press Enter once the key is saved on GitHub " || true
}

upload_key() {
    local title

    [ -f "$PUB" ] || {
        printf "%b\n" "No public key at $PUB; nothing to upload."
        return 1
    }

    if ! ensure_gh; then
        printf "%b\n" "GitHub CLI is not available, so the key cannot be uploaded here."
        manual_upload
        return 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        printf "%b\n" "GitHub CLI is not logged in, so the key cannot be uploaded here."
        printf "%b\n" "Run \`gh auth login\` to do this automatically next time."
        manual_upload
        return 1
    fi

    if key_already_uploaded; then
        printf "%b\n" "This key is already on the GitHub account; not adding a duplicate."
        return 0
    fi

    title="$(scutil --get LocalHostName 2>/dev/null || hostname -s) (macsetup)"
    printf "%b\n" "Uploading the public key as \"$title\"..."

    if gh ssh-key add "$PUB" --type authentication --title "$title"; then
        return 0
    fi

    printf "%b\n" "gh ssh-key add failed. It needs the admin:public_key scope:"
    printf "%b\n" "  gh auth refresh -h github.com -s admin:public_key"
    return 1
}

verify_github() {
    local out

    printf "%b\n" "Verifying authentication against GitHub..."

    out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -T git@github.com </dev/null 2>&1)"

    case "$out" in
    *"successfully authenticated"*)
        printf "%b\n" "$out"
        printf "%b\n" "GitHub SSH authentication works."
        return 0
        ;;
    esac

    printf "%b\n" "Could not authenticate to GitHub:"
    printf "%b\n" "$out"
    return 1
}

git_ssh() {
    printf "%b\n" "Setting up the GitHub SSH key..."

    ensure_key || return 1
    configure_ssh
    load_key
    upload_key
    verify_github
}

git_ssh
