#!/usr/bin/env bats

# `defaults` is a function backed by one file per array, so the real
# com.apple.Spotlight domain is never read or written.
setup() {
    RULES="$BATS_TEST_TMPDIR/EnabledPreferenceRules"
    TYPES="$BATS_TEST_TMPDIR/DisabledUTTypes"
    DROPPED_RULE=""
    : >"$RULES"
    : >"$TYPES"

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/spotlight.sh
    . "$BATS_TEST_DIRNAME/../core/settings/spotlight.sh"

    defaults() {
        local file="$BATS_TEST_TMPDIR/$3"
        [ "$2" = "com.apple.Spotlight" ] || return 1
        case "$3" in EnabledPreferenceRules | DisabledUTTypes) ;; *) return 1 ;; esac
        case "$1" in
        read)
            [ -s "$file" ] || return 1
            printf '(\n'
            sed 's/.*/    "&",/' "$file"
            printf ')\n'
            ;;
        write)
            [ "$4" = "-array-add" ] || return 1
            [ "$5" = "$DROPPED_RULE" ] || printf '%s\n' "$5" >>"$file"
            ;;
        *) return 1 ;;
        esac
    }
}

@test "with no rules yet, lists every hide rule and reports nothing" {
    hide_spotlight_rules

    [ "$(LC_ALL=C sort "$RULES" | tr '\n' ' ')" = "Custom.relatedContents Domain.IMAGES Domain.MENU_OTHER Domain.MOVIES Domain.MUSIC Domain.PDF Domain.PRESENTATIONS Domain.SOURCE Domain.SPREADSHEETS System.applications System.documents System.files System.folders System.iphoneApps System.menuItems " ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "hides every file type the Files subcategories cover, as the pane lists them" {
    hide_spotlight_rules

    [ "$(wc -l <"$TYPES" | tr -d ' ')" -eq 83 ]
    grep -qx com.adobe.pdf "$TYPES"
    grep -qx public.source-code "$TYPES"
    grep -qx public.spreadsheet "$TYPES"
    grep -qx dyn.ah62d4rv4ge81a7dk "$TYPES"
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "a file type that does not stick is reported by name" {
    DROPPED_RULE="public.movie"

    hide_spotlight_rules

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "DisabledUTTypes public.movie"
}

@test "keeps a rule set some other way and adds only the missing ones" {
    printf '%s\n' System.files Custom.somethingElse >"$RULES"

    hide_spotlight_rules

    grep -qx Custom.somethingElse "$RULES"
    [ "$(grep -cx System.files "$RULES")" -eq 1 ]
    [ "$(wc -l <"$RULES" | tr -d ' ')" -eq 16 ]
}

@test "a second run adds nothing" {
    hide_spotlight_rules
    cp "$RULES" "$BATS_TEST_TMPDIR/first"

    hide_spotlight_rules

    cmp -s "$RULES" "$BATS_TEST_TMPDIR/first"
    cp "$TYPES" "$BATS_TEST_TMPDIR/first-types"
    hide_spotlight_rules
    cmp -s "$TYPES" "$BATS_TEST_TMPDIR/first-types"
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "a rule that does not stick is reported by name" {
    DROPPED_RULE="System.menuItems"

    hide_spotlight_rules

    [ "$SETTINGS_FAILED_COUNT" -eq 1 ]
    printf '%s\n' "$SETTINGS_FAILED_KEYS" | grep -qF "System.menuItems"
}

@test "a rule is matched whole, not as a prefix of a longer one" {
    printf '%s\n' System.filesAndMore >"$RULES"

    hide_spotlight_rules

    grep -qx System.files "$RULES"
}
