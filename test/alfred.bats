#!/usr/bin/env bats

# HOME is a scratch directory, so the module's paths resolve under it and the
# real Alfred preferences are never touched. plutil runs for real on those
# scratch files: it only reads and writes the file it is given.
setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    ALFRED_DIR="$HOME/Library/Application Support/Alfred"
    LOCAL="$ALFRED_DIR/Alfred.alfredpreferences/preferences/local"
    HASH="a893a2b86f5f53d443d65a4acf51e39fe0ffa663"
    mkdir -p "$LOCAL"

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/alfred.sh
    . "$BATS_TEST_DIRNAME/../core/settings/alfred.sh"
}

write_prefs_json() {
    printf '{\n  "current" : "%s",\n  "localhash" : "%s"\n}\n' \
        "$ALFRED_DIR/Alfred.alfredpreferences" "$1" >"$ALFRED_DIR/prefs.json"
}

hotkey_field() {
    /usr/bin/plutil -extract "default.$2" raw -o - "$LOCAL/$1/hotkey/prefs.plist"
}

@test "when Alfred has never changed a local preference, creates this Mac's folder and binds cmd+space" {
    write_prefs_json "$HASH"

    set_hotkey

    [ "$(hotkey_field "$HASH" key)" = "49" ]
    [ "$(hotkey_field "$HASH" mod)" = "1048576" ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "when another Mac's folder already exists, writes to this Mac's folder only" {
    write_prefs_json "$HASH"
    mkdir -p "$LOCAL/0000000000000000000000000000000000000000"

    set_hotkey

    [ "$(hotkey_field "$HASH" key)" = "49" ]
    [ ! -e "$LOCAL/0000000000000000000000000000000000000000/hotkey" ]
}

@test "when prefs.json is missing, reports the hotkey as failed and creates nothing" {
    run set_hotkey

    [ "$status" -eq 1 ]
    printf '%s\n' "$output" | grep -qF "Launch Alfred once"
    [ -z "$(ls -A "$LOCAL")" ]
}

@test "the failure reaches the report when prefs.json is missing" {
    set_hotkey || true

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "Alfred hotkey"
}

# The id becomes a path, so a refusal is checked against the whole scratch
# tree rather than one folder: "../../x" lands outside local/.
assert_refused_without_writing() {
    local before
    write_prefs_json "$1"
    before="$(find "$HOME" | sort)"

    run set_hotkey

    [ "$status" -eq 1 ]
    [ "$(find "$HOME" | sort)" = "$before" ]
}

@test "when localhash would climb out of local/, refuses it and creates nothing" {
    assert_refused_without_writing "../../xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

@test "when localhash is hex but not 40 characters, refuses it and creates nothing" {
    assert_refused_without_writing "a893a2b86f"
}
