#!/usr/bin/env bash

# menu: Security
# desc: Firewall on, automatic updates off

. "$COMMON_SCRIPT"
. "$SETTINGS_LIB"

FIREWALL="/usr/libexec/ApplicationFirewall/socketfilterfw"

enable_firewall() {
    local state

    printf "%b\n" "Enabling the application firewall..."

    sudo "$FIREWALL" --setglobalstate on >/dev/null 2>&1 || true

    state="$("$FIREWALL" --getglobalstate 2>/dev/null)"
    verify_value "socketfilterfw --getglobalstate" "State = 1" "$state" contains || true
}

disable_wake_on_network() {
    local womp

    printf "%b\n" "Disabling wake for network access..."

    sudo pmset -a womp 0 >/dev/null 2>&1 || true

    womp="$(pmset -g 2>/dev/null | awk '$1 == "womp" { print $2 }')"
    verify_value "pmset womp" "0" "$womp" exact || true
}

set_software_update() {
    printf "%b\n" "Configuring Software Update..."

    apply_settings <<'EOF'
/Library/Preferences/com.apple.SoftwareUpdate | AutomaticCheckEnabled            | bool | false |
/Library/Preferences/com.apple.SoftwareUpdate | AutomaticDownload                | bool | false |
/Library/Preferences/com.apple.SoftwareUpdate | AutomaticallyInstallMacOSUpdates | bool | false |
/Library/Preferences/com.apple.SoftwareUpdate | CriticalUpdateInstall            | bool | true  |
/Library/Preferences/com.apple.SoftwareUpdate | ConfigDataInstall                | bool | true  |
/Library/Preferences/com.apple.commerce       | AutoUpdate                       | bool | false |
EOF
}

security() {
    printf "%b\n" "Configuring security and software updates..."

    sudo_keepalive || printf "%b\n" "No held sudo session; every change here will prompt or fail."

    enable_firewall
    disable_wake_on_network
    set_software_update

    printf "%b\n" "Software Update changes may not show in System Settings until it is reopened."

    settings_report
}

security
