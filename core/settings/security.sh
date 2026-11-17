#!/usr/bin/env bash

# Security: firewall and stealth mode on, the password required as soon as
# the screen locks, automatic updates off.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

FIREWALL="/usr/libexec/ApplicationFirewall/socketfilterfw"

enable_firewall() {
    local state

    printf "%b\n" "Enabling the application firewall..."

    sudo "$FIREWALL" --setglobalstate on >/dev/null 2>&1 || true

    state="$("$FIREWALL" --getglobalstate 2>/dev/null)"
    verify_value "socketfilterfw --getglobalstate" "State = 1" "$state" contains || true
}

# Stealth mode: no reply to pings or to probes of closed ports. It needs the
# firewall on, so it runs after enable_firewall.
enable_stealth_mode() {
    local state

    printf "%b\n" "Enabling firewall stealth mode..."

    sudo "$FIREWALL" --setstealthmode on >/dev/null 2>&1 || true

    state="$("$FIREWALL" --getstealthmode 2>/dev/null)"
    verify_value "socketfilterfw --getstealthmode" "Firewall stealth mode is on" "$state" exact || true
}

screen_lock_state() {
    sysadminctl -screenLock status </dev/null 2>&1
}

# Lock Screen > Require password after screen saver begins or display is
# turned off. sysadminctl needs the login password, not sudo, and with "-"
# asks for it on the terminal; it is only asked when the delay is not
# already immediate.
require_password_immediately() {
    printf "%b\n" "Requiring the password as soon as the screen locks..."

    case "$(screen_lock_state)" in
    *"screenLock delay is immediate"*) return 0 ;;
    esac

    printf "%b\n" "sysadminctl asks for your login password here."
    sysadminctl -screenLock immediate -password - || true

    verify_value "sysadminctl -screenLock" "screenLock delay is immediate" "$(screen_lock_state)" contains || true
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
    enable_stealth_mode
    require_password_immediately
    disable_wake_on_network
    set_software_update

    printf "%b\n" "Software Update changes may not show in System Settings until it is reopened."
}
