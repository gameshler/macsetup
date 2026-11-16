#!/usr/bin/env bats

# Runs the real optimize-settings.sh against stub area modules, so nothing on
# the machine changes. COMMON_SCRIPT is a stub because sourcing the real one
# resolves, or installs, Homebrew.
setup() {
    STUB_MODULES="$BATS_TEST_TMPDIR/settings"
    mkdir -p "$STUB_MODULES"

    COMMON_SCRIPT="$BATS_TEST_TMPDIR/common-script.sh"
    printf 'sudo_keepalive() { return 0; }\n' >"$COMMON_SCRIPT"

    export COMMON_SCRIPT
    export SETTINGS_LIB="$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    export SETTINGS_DIR="$STUB_MODULES"
    export FAILING_STEP="" GRANTED=1

    local step
    for step in security spotlight alfred desktop_dock fix_finder configure_input remove_animations display cleanup_system; do
        printf '%s() { echo "STEP %s"; [ "$FAILING_STEP" != "%s" ]; }\n' \
            "$step" "$step" "$step" >"$STUB_MODULES/$step.sh"
    done

    # Sourced after settings-lib.sh like every module, so it replaces the real
    # probe and the test does not depend on this terminal's grant.
    printf 'full_disk_access_granted() { [ "$GRANTED" = "1" ]; }\n' >"$STUB_MODULES/probe.sh"
}

run_optimizer() {
    run bash "$BATS_TEST_DIRNAME/../core/tabs/system/optimize-settings.sh"
}

@test "runs every area once, in order, with Spotlight before Alfred" {
    run_optimizer

    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | sed -n 's/^STEP //p' | tr '\n' ' ')" = \
        "security spotlight alfred desktop_dock fix_finder configure_input remove_animations display cleanup_system " ]
}

@test "a clean run ends with one all-verified line" {
    run_optimizer

    [ "$(printf '%s\n' "$output" | grep -c 'All settings applied and verified')" -eq 1 ]
    [ "$(printf '%s\n' "$output" | tail -1)" = "All settings applied and verified." ]
}

@test "an area that stops early is named in the one report at the end" {
    FAILING_STEP="display"

    run_optimizer

    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'did not apply:')" -eq 1 ]
    printf '%s\n' "$output" | tail -1 | grep -qF "Display -- stopped before finishing"
    printf '%s\n' "$output" | grep -qx "STEP cleanup_system"
}

@test "without Full Disk Access, announces the affected steps once, before any area runs" {
    GRANTED=0

    run_optimizer

    [ "$(printf '%s\n' "$output" | grep -c 'these steps will fail')" -eq 1 ]
    [ "$(printf '%s\n' "$output" | grep -n 'these steps will fail' | cut -d: -f1)" -lt \
        "$(printf '%s\n' "$output" | grep -n '^STEP security' | cut -d: -f1)" ]
}

@test "with Full Disk Access, announces nothing about it" {
    run_optimizer

    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -qx "STEP security"
    [ "$(printf '%s\n' "$output" | grep -c 'Full Disk Access')" -eq 0 ]
}

@test "without SETTINGS_DIR, stops before sourcing anything" {
    SETTINGS_DIR=""

    run_optimizer

    [ "$status" -eq 1 ]
    [ "$(printf '%s\n' "$output" | grep -c '^STEP')" -eq 0 ]
}

# Every command a module could run is a logging stub, so a module that does
# work when sourced shows up in the log instead of changing the machine.
@test "the real modules define every area the optimizer runs, and do nothing when sourced" {
    local bin="$BATS_TEST_TMPDIR/bin" log="$BATS_TEST_TMPDIR/sourced.log" cmd
    mkdir -p "$bin"
    for cmd in defaults sudo killall osascript open find pmset plutil displayplacer pgrep rm; do
        printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$cmd" "$log" >"$bin/$cmd"
        chmod +x "$bin/$cmd"
    done
    : >"$log"

    run env PATH="$bin:$PATH" bash -c '
        for module in "$1"/*.sh; do . "$module"; done
        for area in security spotlight alfred desktop_dock fix_finder configure_input remove_animations display cleanup_system; do
            declare -F "$area" >/dev/null || echo "MISSING $area"
        done
    ' _ "$BATS_TEST_DIRNAME/../core/settings"

    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -s "$log" ]
}
