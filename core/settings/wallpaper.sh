#!/usr/bin/env bash

# Wallpaper: solid black on every display and Space.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

# WallpaperAgent keeps its choice in this store, not in a preference domain,
# and nothing public sets a system colour. The store is written whole, as the
# Wallpaper pane leaves it after Colors > Black on macOS 27.2.1.
WALLPAPER_INDEX="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
# Decoded: {type = systemColor; systemColor = {black = {}}}.
BLACK_WALLPAPER_CONFIGURATION="YnBsaXN0MDDSAQICA1R0eXBlW3N5c3RlbUNvbG9y0QQFVWJsYWNr0AgNEh4hJwAAAAAAAAEBAAAAAAAAAAYAAAAAAAAAAAAAAAAAAAAo"
# Decoded: {values = {}}; a colour has no options.
NO_WALLPAPER_OPTIONS="YnBsaXN0MDDRAQJWdmFsdWVz0AgLEgAAAAAAAAEBAAAAAAAAAAMAAAAAAAAAAAAAAAAAAAAT"

# Prints "black" only when the wallpaper for every Space and display is black
# and no display or Space overrides it.
wallpaper_state() {
    local choice overrides

    choice="$(plutil -extract AllSpacesAndDisplays.Linked.Content.Choices.0.Configuration raw -o - "$WALLPAPER_INDEX" 2>/dev/null)"
    [ "$choice" = "$BLACK_WALLPAPER_CONFIGURATION" ] || {
        printf '%s\n' "not black"
        return 0
    }
    for overrides in Displays Spaces; do
        [ "$(plutil -extract "$overrides" json -o - "$WALLPAPER_INDEX" 2>/dev/null)" = "{}" ] || {
            printf '%s\n' "overridden by $overrides"
            return 0
        }
    done
    printf '%s\n' "black"
}

# _black_wallpaper_section <name> <date>
_black_wallpaper_section() {
    cat <<EOF
	<key>$1</key>
	<dict>
		<key>Linked</key>
		<dict>
			<key>Content</key>
			<dict>
				<key>Choices</key>
				<array>
					<dict>
						<key>Configuration</key>
						<data>$BLACK_WALLPAPER_CONFIGURATION</data>
						<key>Files</key>
						<array/>
						<key>Provider</key>
						<string>com.apple.wallpaper.choice.color</string>
					</dict>
				</array>
				<key>EncodedOptionValues</key>
				<data>$NO_WALLPAPER_OPTIONS</data>
				<key>Shuffle</key>
				<string>\$null</string>
			</dict>
			<key>LastSet</key>
			<date>$2</date>
			<key>LastUse</key>
			<date>$2</date>
		</dict>
		<key>Type</key>
		<string>linked</string>
	</dict>
EOF
}

_black_wallpaper_store() {
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
        '<plist version="1.0">' '<dict>'
    _black_wallpaper_section AllSpacesAndDisplays "$1"
    printf '%s\n' '	<key>Displays</key>' '	<dict/>' '	<key>Spaces</key>' '	<dict/>'
    _black_wallpaper_section SystemDefault "$1"
    printf '%s\n' '</dict>' '</plist>'
}

# Written beside the store and moved into place, so a failed write leaves the
# old store whole. plutil refuses to convert a malformed file.
write_black_wallpaper() {
    local dir tmp

    dir="$(dirname "$WALLPAPER_INDEX")"
    mkdir -p "$dir" 2>/dev/null || return 1
    tmp="$(mktemp "$dir/Index.XXXXXX" 2>/dev/null)" || return 1
    if _black_wallpaper_store "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$tmp" &&
        plutil -convert binary1 "$tmp" >/dev/null 2>&1 &&
        mv -f "$tmp" "$WALLPAPER_INDEX"; then
        return 0
    fi
    rm -f "$tmp"
    return 1
}

set_black_wallpaper() {
    printf "%b\n" "Setting the wallpaper to solid black..."

    [ "$(wallpaper_state)" = "black" ] && return 0
    # WallpaperAgent reads the store when it starts; launchd relaunches it.
    if write_black_wallpaper; then
        killall WallpaperAgent >/dev/null 2>&1 || true
    fi
    verify_value "Wallpaper $WALLPAPER_INDEX" "black" "$(wallpaper_state)" exact || true
}
