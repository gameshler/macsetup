#!/usr/bin/env bats

# `defaults` is a function backed by one file per array, so the real
# com.apple.Spotlight domain is never read or written.
setup() {
    RULES="$BATS_TEST_TMPDIR/EnabledPreferenceRules"
    DROPPED_RULE=""
    : >"$RULES"

    # shellcheck source=../core/tabs/settings-lib.sh
    . "$BATS_TEST_DIRNAME/../core/tabs/settings-lib.sh"
    # shellcheck source=../core/settings/spotlight.sh
    . "$BATS_TEST_DIRNAME/../core/settings/spotlight.sh"

    defaults() {
        case "$1 $2 $3" in
        "read com.apple.Spotlight EnabledPreferenceRules")
            [ -s "$RULES" ] || return 1
            printf '(\n'
            sed 's/.*/    "&",/' "$RULES"
            printf ')\n'
            ;;
        "write com.apple.Spotlight EnabledPreferenceRules")
            [ "$4" = "-array-add" ] || return 1
            [ "$5" = "$DROPPED_RULE" ] || printf '%s\n' "$5" >>"$RULES"
            ;;
        *) return 1 ;;
        esac
    }
}

@test "with no rules yet, lists every hide rule and reports nothing" {
    hide_spotlight_rules

    [ "$(sort "$RULES" | tr '\n' ' ')" = "Custom.relatedContents System.applications System.files System.folders System.iphoneApps System.menuItems " ]
    [ "$SETTINGS_FAILED_COUNT" -eq 0 ]
}

@test "keeps a rule set some other way and adds only the missing ones" {
    printf '%s\n' System.files Custom.somethingElse >"$RULES"

    hide_spotlight_rules

    grep -qx Custom.somethingElse "$RULES"
    [ "$(grep -cx System.files "$RULES")" -eq 1 ]
    [ "$(wc -l <"$RULES" | tr -d ' ')" -eq 7 ]
}

@test "a second run adds nothing" {
    hide_spotlight_rules
    cp "$RULES" "$BATS_TEST_TMPDIR/first"

    hide_spotlight_rules

    cmp -s "$RULES" "$BATS_TEST_TMPDIR/first"
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
