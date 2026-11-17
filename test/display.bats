#!/usr/bin/env bats

# defaults keeps one scratch file per key and killall only logs, so no real
# preference is written. set_more_space is replaced, because it drives
# displayplacer.
setup() {
    STORE="$BATS_TEST_TMPDIR/store"
    CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$STORE"
    : >"$CALL_LOG"

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/display.sh
    . "$BATS_TEST_DIRNAME/../core/settings/display.sh"

    defaults() {
        local scope="" file
        [ "$1" = "-currentHost" ] && scope="byhost " && shift
        file="$STORE/$(printf '%s' "$scope$2 $3" | tr ' ' '_')"
        case "$1" in
        write) printf '%s\n' "$5" >"$file" ;;
        read) cat "$file" 2>/dev/null ;;
        *) return 1 ;;
        esac
    }
    killall() { echo "KILLALL $*" >>"$CALL_LOG"; }
    set_more_space() { echo "MORE SPACE" >>"$CALL_LOG"; }
}

@test "turns off both Universal Control toggles for this Mac and restarts it" {
    disable_universal_control

    [ "$(cat "$STORE/byhost_com.apple.universalcontrol_Disable")" = "true" ]
    [ "$(cat "$STORE/byhost_com.apple.universalcontrol_DisableMagicEdges")" = "true" ]
    grep -qx "KILLALL UniversalControl" "$CALL_LOG"
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "the display area turns Universal Control off before More Space" {
    set_more_space() {
        echo "MORE SPACE" >>"$CALL_LOG"
        return 1
    }

    run display

    [ "$status" -eq 1 ]
    [ "$(grep -v '^KILLALL' "$CALL_LOG")" = "MORE SPACE" ]
    [ -e "$STORE/byhost_com.apple.universalcontrol_DisableMagicEdges" ]
}
