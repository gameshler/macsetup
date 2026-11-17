#!/usr/bin/env bash

# Battery: turn off the Battery > Options rows the owner named. The fourth,
# Wake for network access, is womp, which security.sh already sets.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

# pmset_value <section> <key>: <section> is a header of `pmset -g custom`,
# "Battery Power" or "AC Power"; the same key appears under both.
pmset_value() {
    pmset -g custom 2>/dev/null | awk -v section="$1:" -v key="$2" '
        /^[^ ]/ { in_section = ($0 == section); next }
        in_section && $1 == key { print $2; exit }'
}

# set_pmset <-b|-c> <key> <value>: pmset is not a preference, so each write
# is read back here rather than through apply_settings.
set_pmset() {
    local source="$1" key="$2" value="$3" section="Battery Power"

    [ "$source" = "-c" ] && section="AC Power"
    sudo pmset "$source" "$key" "$value" </dev/null >/dev/null 2>&1 || true
    verify_value "pmset $section $key" "$value" "$(pmset_value "$section" "$key")" exact || true
}

# A desktop Mac has no battery, so it has none of these options.
has_battery() {
    pmset -g batt 2>/dev/null | grep -q InternalBattery
}

battery() {
    if ! has_battery; then
        printf "%b\n" "This Mac has no battery; leaving the Battery options alone."
        return 0
    fi

    printf "%b\n" "Turning off the Battery options..."

    # Slightly dim the display on battery.
    set_pmset -b lessbright 0
    # Prevent automatic sleeping on power adapter when the display is off:
    # on is sleep 0, and the pane writes 1 when it is turned off.
    set_pmset -c sleep 1

    apply_settings <<'EOF'
/Library/Preferences/.GlobalPreferences | com.apple.coremedia.optimizeVideoStreamingOnBattery | bool | false |
EOF
}
