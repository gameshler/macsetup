#!/usr/bin/env bats

# `defaults` is a function backed by one file, so the real
# com.apple.suggestions domain is never read or written.
setup() {
    BLOCKED="$BATS_TEST_TMPDIR/AppCanShowSiriSuggestionsBlacklist"
    : >"$BLOCKED"

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/siri.sh
    . "$BATS_TEST_DIRNAME/../core/settings/siri.sh"

    defaults() {
        case "$1 $2 $3" in
        "read com.apple.suggestions AppCanShowSiriSuggestionsBlacklist")
            printf '(\n'
            sed 's/.*/    "&",/' "$BLOCKED"
            printf ')\n'
            ;;
        "write com.apple.suggestions AppCanShowSiriSuggestionsBlacklist")
            [ "$4" = "-array-add" ] && printf '%s\n' "$5" >>"$BLOCKED"
            ;;
        *) return 1 ;;
        esac
    }
}

@test "turns off suggestions in each of the eleven apps the pane lists" {
    disable_siri_suggestions

    [ "$(LC_ALL=C sort "$BLOCKED" | tr '\n' ' ')" = "com.apple.AddressBook com.apple.FaceTime com.apple.Maps com.apple.MobileSMS com.apple.Safari com.apple.iBooksX com.apple.iCal com.apple.mail com.apple.news com.apple.podcasts com.apple.reminders " ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "keeps an app blocked some other way and does not list an app twice" {
    printf '%s\n' com.apple.Safari com.example.Other >"$BLOCKED"

    disable_siri_suggestions

    grep -qx com.example.Other "$BLOCKED"
    [ "$(grep -cx com.apple.Safari "$BLOCKED")" -eq 1 ]
}
