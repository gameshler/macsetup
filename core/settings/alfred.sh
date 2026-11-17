#!/usr/bin/env bash

# Alfred: bind it to cmd+space and trim its web searches.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

ALFRED_PREFS_JSON="$HOME/Library/Application Support/Alfred/prefs.json"
ALFRED_BUNDLE="$HOME/Library/Application Support/Alfred/Alfred.alfredpreferences"
WEBSEARCH="$ALFRED_BUNDLE/preferences/features/websearch"
LOCAL_PREFS="$ALFRED_BUNDLE/preferences/local"

BUILTIN_SEARCHES='amazon applemaps ask bing drive drivesearch duckduckgo ebay
facebook flickr gmail gmailsearch gtranslate help images imdb linkedin lucky
maps pinterest rottentomatoes twitter twittersearch twitteruser weather wiki
wolfram yahoo youtube yubnub'

HOTKEY_KEY=49
HOTKEY_MOD=1048576

ALFRED_BUNDLE_ID="com.runningwithcrayons.Alfred"

alfred_running() {
    pgrep -x Alfred >/dev/null 2>&1
}

plist_value() {
    local out
    out="$(/usr/bin/plutil -extract "$2" raw -o - "$1" 2>/dev/null)" || return 1
    printf '%s' "$out"
}

quit_alfred() {
    local waited=0

    alfred_running || return 0

    printf "%b\n" "Quitting Alfred so the preferences can be written..."

    if ! osascript -e "quit app id \"$ALFRED_BUNDLE_ID\"" >/dev/null 2>&1; then
        printf "%b\n" "Could not quit Alfred gracefully; terminating it instead."
        killall Alfred >/dev/null 2>&1 || true
    fi

    while alfred_running && [ "$waited" -lt 10 ]; do
        sleep 1
        waited=$((waited + 1))
    done

    if alfred_running; then
        printf "%b\n" "Alfred is still running after ${waited}s; it would overwrite these changes."
        return 1
    fi

    return 0
}

write_disabled() {
    local dir="$1" file

    file="$dir/prefs.plist"
    mkdir -p "$dir" || return 1

    if [ ! -f "$file" ]; then
        /usr/bin/plutil -create xml1 "$file" >/dev/null 2>&1 || return 1
    fi

    /usr/bin/plutil -replace disabled -bool true "$file" >/dev/null 2>&1
}

disable_web_searches() {
    local name still_enabled=""

    printf "%b\n" "Disabling the built-in web searches other than Google..."

    for name in $BUILTIN_SEARCHES; do
        write_disabled "$WEBSEARCH/$name" || true
    done

    for name in $BUILTIN_SEARCHES; do
        if [ "$(plist_value "$WEBSEARCH/$name/prefs.plist" disabled)" != "true" ]; then
            still_enabled="${still_enabled}${name} "
        fi
    done

    verify_value "Alfred web searches still enabled" "" "${still_enabled% }" exact || true
}

# Alfred records this Mac's id in prefs.json on first launch, but creates the
# matching folder under local/ only when a local preference is first changed
# in its UI. So the id is the source, and the folder may not exist yet. The id
# becomes a path, so anything but a 40-character hex id is refused.
local_prefs_dir() {
    local hash
    hash="$(plist_value "$ALFRED_PREFS_JSON" localhash)" || return 1

    case "$hash" in
    *[!0-9a-f]*) return 1 ;;
    esac
    [ "${#hash}" -eq 40 ] || return 1

    printf '%s' "$LOCAL_PREFS/$hash"
}

set_hotkey() {
    local dir file

    printf "%b\n" "Setting the Alfred hotkey to cmd+space..."

    if ! dir="$(local_prefs_dir)"; then
        printf "%b\n" "No id for this Mac in $ALFRED_PREFS_JSON."
        printf "%b\n" "Launch Alfred once so it records one, then run this again."
        verify_value "Alfred hotkey" "cmd+space" "no id for this Mac in prefs.json" exact || true
        return 1
    fi

    file="$dir/hotkey/prefs.plist"
    mkdir -p "$dir/hotkey" || return 1

    if [ ! -f "$file" ]; then
        /usr/bin/plutil -create xml1 "$file" >/dev/null 2>&1 || return 1
    fi

    /usr/bin/plutil -replace default -json \
        "{\"key\":$HOTKEY_KEY,\"mod\":$HOTKEY_MOD,\"string\":\" \"}" \
        "$file" >/dev/null 2>&1 || true

    verify_value "Alfred hotkey key" "$HOTKEY_KEY" "$(plist_value "$file" default.key)" exact || true
    verify_value "Alfred hotkey mod" "$HOTKEY_MOD" "$(plist_value "$file" default.mod)" exact || true
}

alfred() {
    local was_running=0

    printf "%b\n" "Configuring Alfred..."

    if [ ! -d "$ALFRED_BUNDLE" ]; then
        printf "%b\n" "No Alfred preferences bundle at $ALFRED_BUNDLE."
        printf "%b\n" "Install Alfred and launch it once, then run this again."
        return 0
    fi

    alfred_running && was_running=1

    if ! quit_alfred; then
        printf "%b\n" "Leaving the Alfred preferences alone."
        return 1
    fi

    disable_web_searches
    set_hotkey

    if [ "$was_running" = "1" ]; then
        printf "%b\n" "Relaunching Alfred..."
        if ! open -b "$ALFRED_BUNDLE_ID" >/dev/null 2>&1; then
            verify_value "Alfred relaunch" "running" "not running" exact || true
        fi
    fi
}
