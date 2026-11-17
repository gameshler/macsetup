#!/usr/bin/env bash

# menu: Optimize Settings
# desc: Apply and verify every macOS settings change

. "$COMMON_SCRIPT"
. "$SETTINGS_LIB"

# Each area lives in $SETTINGS_DIR, outside core/tabs/, so the menu does not
# list it. A module only defines functions; sourcing it changes nothing.
if [ ! -d "${SETTINGS_DIR:-}" ]; then
    printf "%b\n" "SETTINGS_DIR does not name the settings modules; run this from the menu."
    exit 1
fi

for module in "$SETTINGS_DIR"/*.sh; do
    . "$module"
done

# An area returns non-zero only when it stopped before finishing, such as the
# display step finding a second display. The keys it did write report
# themselves; this names the area so the run cannot end "all verified".
run_area() {
    local label="$1" area="$2"

    printf '\n'
    "$area" && return 0
    _settings_record_failure "$label" "stopped before finishing; see its output above"
}

optimize_settings() {
    printf "%b\n" "Optimizing macOS settings..."
    check_full_disk_access || true

    run_area "Security" security
    run_area "Battery" battery
    # Before Alfred: Alfred cannot take cmd+space while Spotlight holds it.
    run_area "Spotlight" spotlight
    run_area "Siri suggestions" disable_siri_suggestions
    run_area "Apple Intelligence" disable_ai
    run_area "Alfred" alfred
    run_area "Dock and Desktop" desktop_dock
    run_area "Finder" fix_finder
    run_area "Trackpad" configure_input
    run_area "Animations" remove_animations
    run_area "Display" display
    run_area "Cleanup" cleanup_system

    printf '\n'
    settings_report
}

optimize_settings
