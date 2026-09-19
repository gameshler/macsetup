#!/usr/bin/env bash

# menu: System Cleanup
# desc: Empty Trash, opt out of Apple Intelligence

. "$COMMON_SCRIPT"
. "$SETTINGS_LIB"

cleanup_system() {
    printf "%b\n" "Performing system cleanup..."

    apply_settings <<'EOF'
com.apple.dock                            | mru-spaces | bool | false | Dock
com.apple.CloudSubscriptionFeatures.optIn | 545129924  | bool | false |
EOF

    printf "%b\n" "Emptying Trash..."
    if [ ! -d "$HOME/.Trash" ]; then
        printf "%b\n" "No ~/.Trash directory; nothing to empty."
    elif ! find "$HOME/.Trash" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null; then
        _settings_record_failure "Trash" \
            "could not be emptied; grant the terminal Full Disk Access in System Settings > Privacy & Security"
    fi

    printf "%b\n" "Removing old log files..."
    sudo_keepalive || printf "%b\n" "No held sudo session; log cleanup may prompt or be skipped."
    find /var/log -type f \( -name "*.log" -o -name "*.old" -o -name "*.err" \) \
        -mtime +30 -exec sudo rm -f {} +

    settings_report
}

cleanup_system
