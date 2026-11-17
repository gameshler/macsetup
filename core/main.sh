#!/usr/bin/env bash

set -euo pipefail

export DOT_FILES="$INSTALL_DIR/dotfiles"
export TABS_DIR="$INSTALL_DIR/core/tabs"
export COMMON_SCRIPT="$TABS_DIR/common-script.sh"
export SETTINGS_LIB="$TABS_DIR/settings-lib.sh"
# Outside TABS_DIR so the menu does not list them; optimize-settings.sh runs them.
export SETTINGS_DIR="$INSTALL_DIR/core/settings"

SETUP_COMMAND='bash <(curl -fsSL https://raw.githubusercontent.com/gameshler/macsetup/main/start.sh)'

# Set by macOS for a process started from an app bundle, and inherited, so it
# names the terminal app whose Full Disk Access grant this session uses.
TERMINAL_APP_ID="${__CFBundleIdentifier:-}"

# Runs on every exit, including one while the libraries below are being
# sourced, so a function they define may not exist yet.
cleanup() {
    local status=$?
    # A second signal must not cut this short, and after a closed window every
    # write fails, which under set -e would end it early as well.
    trap '' HUP INT TERM
    set +e

    if declare -F end_full_disk_access >/dev/null; then
        end_full_disk_access
    fi
    if declare -F end_sudo_session >/dev/null; then
        end_sudo_session
        printf '  Administrator session ended.\n'
    fi

    # TEMP_DIR comes from start.sh. Without it this is not the disposable
    # unpack, so INSTALL_DIR is not deleted even on a clean exit.
    if [ -z "${TEMP_DIR:-}" ]; then
        echo "TEMP_DIR is not set. Keeping ${INSTALL_DIR:-the install directory}."
        return
    fi
    rm -rf "$TEMP_DIR"

    if [ "$status" -eq 0 ]; then
        rm -rf "$INSTALL_DIR"
    else
        echo "Exited with status $status. Keeping $INSTALL_DIR so the run can be retried and inspected."
    fi
}

# Installed before sourcing: checkPackageManager can take the password to
# install Homebrew. Closing the window, ^C or a kill still ends through
# cleanup, so the grant and the password do not outlive the session.
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Sourcing the shared library runs checkPackageManager, so Homebrew is found,
# or installed, before the menu opens, and sudo_keepalive becomes available.
. "$COMMON_SCRIPT"
. "$SETTINGS_LIB"

setup_display() {
    C_RESET=""
    C_DIM=""
    C_BOLD=""
    C_GREEN=""
    C_RED=""
    C_ACCENT=""
    RULE_CHAR="-"
    SEP_CHAR=">"
    COLS=80

    if command -v tput >/dev/null 2>&1; then
        COLS="$(tput cols 2>/dev/null || echo 80)"
    fi
    [ "$COLS" -ge 60 ] 2>/dev/null || COLS=80
    [ "$COLS" -le 100 ] || COLS=100

    [ -t 1 ] || return 0
    case "${TERM:-dumb}" in
    dumb | "") return 0 ;;
    esac
    command -v tput >/dev/null 2>&1 || return 0
    [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ] || return 0

    C_RESET="$(tput sgr0)"
    C_BOLD="$(tput bold)"
    C_DIM="$(tput dim 2>/dev/null || true)"
    C_GREEN="$(tput setaf 2)"
    C_RED="$(tput setaf 1)"
    C_ACCENT="$(tput setaf 6)"
}

clear_screen() {
    clear 2>/dev/null || true
}

rule() {
    local i=0 line=""
    while [ "$i" -lt "$COLS" ]; do
        line="${line}${RULE_CHAR}"
        i=$((i + 1))
    done
    printf '%s%s%s\n' "$C_DIM" "$line" "$C_RESET"
}

header() {
    rule
    printf '  %s%smacsetup%s  %s%s%s  %s%s%s\n' \
        "$C_BOLD" "$C_ACCENT" "$C_RESET" \
        "$C_DIM" "$SEP_CHAR" "$C_RESET" \
        "$C_BOLD" "$1" "$C_RESET"
    rule
}

pause() {
    read -rp "  Press Enter to continue "
}

# Probed once at startup: a grant only takes effect after the terminal is
# reopened, which restarts the menu anyway.
full_disk_access_status() {
    if [ "$FULL_DISK_ACCESS" = "1" ]; then
        printf '  %sFull Disk Access: granted%s\n\n' "$C_DIM" "$C_RESET"
        return 0
    fi

    printf '  %sFull Disk Access: not granted to this terminal%s\n' "$C_BOLD" "$C_RESET"
    printf '  %s%s will fail without it.%s\n' "$C_DIM" "$FULL_DISK_ACCESS_STEPS" "$C_RESET"
    printf '  %sSystem Settings > Privacy & Security > Full Disk Access%s\n\n' "$C_DIM" "$C_RESET"
}

FULL_DISK_ACCESS_PANE="x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"

# Taken here rather than in a tab: the keepalive lives as long as the menu,
# and the exported SUDO_KEEPALIVE_STARTED stops each tab asking again.
startup_sudo() {
    if sudo_keepalive; then
        printf '\n'
        return 0
    fi

    printf '  %sNo administrator access.%s Steps that need it will ask again or fail.\n\n' "$C_RED" "$C_RESET"
    return 1
}

startup_full_disk_access() {
    FULL_DISK_ACCESS=0
    if full_disk_access_granted; then
        FULL_DISK_ACCESS=1
    fi

    full_disk_access_status
    if [ "$FULL_DISK_ACCESS" = "1" ] && [ -n "$TERMINAL_APP_ID" ]; then
        printf '  It is revoked from %s when you quit.\n\n' "$TERMINAL_APP_ID"
        return 0
    fi
    if [ "$FULL_DISK_ACCESS" = "1" ]; then
        printf '  %sThis terminal has no app id, so it cannot be revoked when you quit.%s\n' "$C_RED" "$C_RESET"
        printf '  Turn it off in Full Disk Access when you are done.\n\n'
        return 0
    fi

    if open "$FULL_DISK_ACCESS_PANE" >/dev/null 2>&1; then
        printf '  System Settings is open at Full Disk Access. Turn it on for this\n'
    else
        printf '  %sCould not open System Settings.%s In Full Disk Access, turn it on for this\n' "$C_RED" "$C_RESET"
    fi
    printf '  terminal (%s), let macOS quit and reopen it, then run:\n\n' "${TERMINAL_APP_ID:-unknown app id}"
    printf '    %s\n\n' "$SETUP_COMMAND"
    printf '  It is granted for that run only and revoked when you quit.\n\n'

    read -rp "  Press Enter to continue without it " || true
    return 1
}

# Revoked only when this session started with the grant. A session that
# started without it is the one where the grant was just given, and macOS
# then quits the terminal to apply it: revoking on that exit would undo it.
end_full_disk_access() {
    [ "${FULL_DISK_ACCESS:-0}" = "1" ] || return 0

    if revoke_full_disk_access "$TERMINAL_APP_ID"; then
        printf '  Full Disk Access revoked from %s.\n' "$TERMINAL_APP_ID"
        return 0
    fi

    printf '  Could not revoke Full Disk Access from %s.\n' "${TERMINAL_APP_ID:-this terminal}"
    printf '  Turn it off in System Settings > Privacy & Security > Full Disk Access.\n'
}

# A missing grant already stops at its own prompt, so the pause is only for a
# refused password on its own.
startup_checks() {
    local sudo_ok=1

    clear_screen
    header "Startup checks"
    printf '\n'

    startup_sudo || sudo_ok=0
    if startup_full_disk_access && [ "$sudo_ok" = "0" ]; then
        pause || true
    fi
}

meta_field() {
    local file="$1" field="$2"
    [ -r "$file" ] || return 0
    { sed -n "1,12{s/^# *${field}: *//p;}" "$file" 2>/dev/null || true; } | head -1
}

derive_label() {
    printf '%s' "$1" | tr -- '-_' '  ' |
        awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2); print }'
}

entry_label() {
    local path="$1" label=""

    if [[ -d "$path" ]]; then
        label="$(meta_field "$path/.menu" menu)"
    else
        label="$(meta_field "$path" menu)"
    fi

    if [ -z "$label" ]; then
        label="$(derive_label "$(basename "${path%.sh}")")"
    fi

    printf '%s' "$label"
}

entry_desc() {
    local path="$1"

    if [[ -d "$path" ]]; then
        meta_field "$path/.menu" desc
    else
        meta_field "$path" desc
    fi
}

run_tab() {
    local path="$1" label="$2"
    local status=0

    clear_screen
    header "Running  $SEP_CHAR  $label"
    printf '\n'

    bash "$path" || status=$?

    printf '\n'
    rule
    if [ "$status" -eq 0 ]; then
        printf '  %s%s%s  %s%s%s  %sfinished%s\n' \
            "$C_BOLD" "$label" "$C_RESET" \
            "$C_DIM" "$SEP_CHAR" "$C_RESET" \
            "$C_GREEN" "$C_RESET"
    else
        printf '  %s%s%s  %s%s%s  %sfailed with exit code %s%s\n' \
            "$C_BOLD" "$label" "$C_RESET" \
            "$C_DIM" "$SEP_CHAR" "$C_RESET" \
            "$C_RED" "$status" "$C_RESET"
    fi
    rule
    printf '\n'
    pause
}

draw_menu() {
    local current_dir="$1" depth="$2" crumb="$3"
    local entry label desc
    local i width avail

    clear_screen
    header "$crumb"
    printf '\n'

    if [ "$depth" -eq 0 ]; then
        full_disk_access_status
    fi

    ENTRIES=()
    LABELS=()
    DESCS=()

    if [ "$depth" -eq 0 ]; then
        while IFS= read -r entry; do
            ENTRIES+=("$entry")
        done < <(find "$current_dir" -mindepth 1 -maxdepth 1 -type d | sort)
    else
        while IFS= read -r entry; do
            ENTRIES+=("$entry")
        done < <(find "$current_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type f -name "*.sh" \) | sort)
    fi

    if [ "${#ENTRIES[@]}" -eq 0 ]; then
        printf '  %sNothing here yet.%s\n\n' "$C_DIM" "$C_RESET"
    else
        width=0
        for entry in "${ENTRIES[@]}"; do
            label="$(entry_label "$entry")"
            LABELS+=("$label")
            DESCS+=("$(entry_desc "$entry")")
            [ "${#label}" -le "$width" ] || width="${#label}"
        done

        avail=$((COLS - width - 11))

        i=0
        while [ "$i" -lt "${#ENTRIES[@]}" ]; do
            label="${LABELS[$i]}"
            desc="${DESCS[$i]}"

            if [ "$avail" -lt 12 ]; then
                desc=""
            elif [ "${#desc}" -gt "$avail" ]; then
                desc="${desc:0:$((avail - 1))}..."
            fi

            printf '  %s%3d%s  %-*s  %s%s%s\n' \
                "$C_BOLD" "$((i + 1))" "$C_RESET" \
                "$width" "$label" \
                "$C_DIM" "$desc" "$C_RESET"

            i=$((i + 1))
        done
        printf '\n'
    fi

    if [ "$depth" -eq 0 ]; then
        printf '  %s  q%s  Quit\n\n' "$C_BOLD" "$C_RESET"
    else
        printf '  %s  b%s  Back      %sq%s  Quit\n\n' "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET"
    fi
}

choose_directory() {
    local current_dir="$TABS_DIR"
    local parent_stack=()
    local crumb_stack=()
    local crumb choice index selected n

    while true; do
        crumb="Home"
        if [ "${#crumb_stack[@]}" -gt 0 ]; then
            crumb="$(
                IFS="|"
                printf '%s' "${crumb_stack[*]}"
            )"
            crumb="${crumb//|/  $SEP_CHAR  }"
        fi

        draw_menu "$current_dir" "${#parent_stack[@]}" "$crumb"

        read -rp "  Select  $SEP_CHAR " choice || choice="q"

        case "$choice" in
        q | Q)
            clear_screen
            exit 0
            ;;
        b | B)
            n="${#parent_stack[@]}"
            if [ "$n" -gt 0 ]; then
                current_dir="${parent_stack[$((n - 1))]}"
                parent_stack=("${parent_stack[@]:0:$((n - 1))}")
                crumb_stack=("${crumb_stack[@]:0:$((n - 1))}")
            fi
            continue
            ;;
        "")
            continue
            ;;
        *[!0-9]* | 0*)
            printf '\n  %sNot a valid choice.%s\n\n' "$C_RED" "$C_RESET"
            pause
            continue
            ;;
        esac

        index=$((choice - 1))
        if [ "$index" -ge "${#ENTRIES[@]}" ]; then
            printf '\n  %sNot a valid choice.%s\n\n' "$C_RED" "$C_RESET"
            pause
            continue
        fi

        selected="${ENTRIES[$index]}"
        if [[ -d "$selected" ]]; then
            parent_stack+=("$current_dir")
            crumb_stack+=("${LABELS[$index]}")
            current_dir="$selected"
        else
            run_tab "$selected" "${LABELS[$index]}"
        fi
    done
}

main() {
    setup_display
    startup_checks
    choose_directory
}

main
