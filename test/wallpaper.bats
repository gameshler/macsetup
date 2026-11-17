#!/usr/bin/env bats

# HOME is a scratch directory, so the store resolves under it and the real
# wallpaper is never touched. plutil runs for real on the scratch file;
# killall only logs.
setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
    : >"$CALL_LOG"

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/wallpaper.sh
    . "$BATS_TEST_DIRNAME/../core/settings/wallpaper.sh"

    STORE_DIR="$(dirname "$WALLPAPER_INDEX")"
    killall() { echo "KILLALL $*" >>"$CALL_LOG"; }
}

choice_of() {
    plutil -extract "$1.Linked.Content.Choices.0.Configuration" raw -o - "$WALLPAPER_INDEX" |
        base64 -d | plutil -extract systemColor json -o - -
}

# An image wallpaper with one display overriding it, as a Mac that was never
# set to black would have.
write_image_store() {
    mkdir -p "$STORE_DIR"
    cat >"$WALLPAPER_INDEX" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AllSpacesAndDisplays</key>
	<dict>
		<key>Linked</key>
		<dict>
			<key>Content</key>
			<dict>
				<key>Choices</key>
				<array>
					<dict>
						<key>Configuration</key>
						<data>aW1hZ2U=</data>
						<key>Provider</key>
						<string>com.apple.wallpaper.choice.image</string>
					</dict>
				</array>
			</dict>
		</dict>
		<key>Type</key>
		<string>linked</string>
	</dict>
	<key>Displays</key>
	<dict>
		<key>37D8832A-2D66-02CA-B9F7-8F30A301B230</key>
		<dict/>
	</dict>
	<key>Spaces</key>
	<dict/>
</dict>
</plist>
EOF
}

@test "the stored choice decodes to the black system colour" {
    [ "$(printf '%s' "$BLACK_WALLPAPER_CONFIGURATION" | base64 -d | plutil -extract type raw -o - -)" = "systemColor" ]
    [ "$(printf '%s' "$BLACK_WALLPAPER_CONFIGURATION" | base64 -d | plutil -extract systemColor.black json -o - -)" = "{}" ]
}

@test "with no store yet, sets black for every Space and display and restarts the agent" {
    set_black_wallpaper

    [ "$(choice_of AllSpacesAndDisplays)" = '{"black":{}}' ]
    [ "$(choice_of SystemDefault)" = '{"black":{}}' ]
    [ "$(head -c 8 "$WALLPAPER_INDEX")" = "bplist00" ]
    grep -qx "KILLALL WallpaperAgent" "$CALL_LOG"
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "replaces an image wallpaper and drops a display that overrides it" {
    write_image_store

    set_black_wallpaper

    [ "$(choice_of AllSpacesAndDisplays)" = '{"black":{}}' ]
    [ "$(plutil -extract Displays json -o - "$WALLPAPER_INDEX")" = "{}" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

# assert_override_dropped <Displays|Spaces>
assert_override_dropped() {
    set_black_wallpaper
    plutil -insert "$1.37D8832A-2D66-02CA-B9F7-8F30A301B230" -dictionary "$WALLPAPER_INDEX"
    : >"$CALL_LOG"

    set_black_wallpaper

    [ "$(plutil -extract "$1" json -o - "$WALLPAPER_INDEX")" = "{}" ]
    grep -qx "KILLALL WallpaperAgent" "$CALL_LOG"
}

@test "a black wallpaper that one display overrides is rewritten without the override" {
    assert_override_dropped Displays
}

@test "a black wallpaper that one Space overrides is rewritten without the override" {
    assert_override_dropped Spaces
}

@test "when the wallpaper is already black everywhere, changes nothing and restarts nothing" {
    set_black_wallpaper
    cp "$WALLPAPER_INDEX" "$BATS_TEST_TMPDIR/first"
    : >"$CALL_LOG"

    set_black_wallpaper

    cmp -s "$WALLPAPER_INDEX" "$BATS_TEST_TMPDIR/first"
    [ ! -s "$CALL_LOG" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "a store that cannot be written is reported, left as it was, and nothing restarts" {
    write_image_store
    cp "$WALLPAPER_INDEX" "$BATS_TEST_TMPDIR/before"
    chmod 500 "$STORE_DIR"

    set_black_wallpaper
    chmod 700 "$STORE_DIR"

    cmp -s "$WALLPAPER_INDEX" "$BATS_TEST_TMPDIR/before"
    [ ! -s "$CALL_LOG" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "Wallpaper"
}
