#!/usr/bin/env bash

# Spotlight: turn it off and free cmd+space.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

SYMBOLIC_HOTKEYS_PLIST="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"

SPOTLIGHT_CATEGORIES='APPLICATIONS MENU_EXPRESSION CONTACT MENU_CONVERSION
MENU_DEFINITION DOCUMENTS EVENT_TODO DIRECTORIES FONTS IMAGES MESSAGES MOVIES
MUSIC MENU_OTHER PDF PRESENTATIONS MENU_SPOTLIGHT_SUGGESTIONS SPREADSHEETS
SYSTEM_PREFS TIPS BOOKMARKS'

disable_spotlight_categories() {
    local name

    printf "%b\n" "Disabling all Spotlight result categories..."

    set --
    for name in $SPOTLIGHT_CATEGORIES; do
        set -- "$@" "<dict><key>enabled</key><false/><key>name</key><string>$name</string></dict>"
    done

    defaults write com.apple.Spotlight orderedItems -array "$@" 2>/dev/null || true

    verify_setting com.apple.Spotlight orderedItems "APPLICATIONS" contains || true
    verify_setting com.apple.Spotlight orderedItems "enabled = 1" absent || true
}

# Written by the macOS 27 pane when Show Related Content and the results from
# system items (applications, files, folders, iPhone apps, menu items) are
# turned off. Despite the key's name, a listed rule hides its results.
SPOTLIGHT_HIDDEN_RULES='Custom.relatedContents System.applications System.files
System.folders System.iphoneApps System.menuItems'

spotlight_rule_listed() {
    defaults read com.apple.Spotlight EnabledPreferenceRules 2>/dev/null |
        tr -d ' ",()' | grep -qxF -- "$1"
}

# Added one at a time rather than written as a whole array, so a rule set some
# other way stays and nothing is turned back on.
hide_spotlight_rules() {
    local rule state

    printf "%b\n" "Hiding related content and system items from Spotlight..."

    for rule in $SPOTLIGHT_HIDDEN_RULES; do
        spotlight_rule_listed "$rule" && continue
        defaults write com.apple.Spotlight EnabledPreferenceRules -array-add "$rule" 2>/dev/null || true
    done

    for rule in $SPOTLIGHT_HIDDEN_RULES; do
        state="missing"
        spotlight_rule_listed "$rule" && state="listed"
        verify_value "com.apple.Spotlight EnabledPreferenceRules $rule" "listed" "$state" exact || true
    done
}

disable_symbolic_hotkey() {
    local id="$1" fallback_parameters="$2" value_xml

    value_xml="$(/usr/bin/plutil -extract "AppleSymbolicHotKeys.$id.value" xml1 -o - \
        "$SYMBOLIC_HOTKEYS_PLIST" 2>/dev/null |
        sed -e '1,/<plist/d' -e '/<\/plist>/d')"

    if [ -z "$value_xml" ]; then
        printf "%b\n" "Hotkey $id has no saved binding; writing the macOS default."
        value_xml="<dict><key>type</key><string>standard</string><key>parameters</key><array>$fallback_parameters</array></dict>"
    fi

    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" \
        "<dict><key>enabled</key><false/><key>value</key>${value_xml}</dict>" 2>/dev/null || true

    verify_setting com.apple.symbolichotkeys AppleSymbolicHotKeys \
        "$id =     {
        enabled = 0;" contains || true
}

disable_spotlight_hotkeys() {
    printf "%b\n" "Disabling the Spotlight keyboard shortcuts..."

    disable_symbolic_hotkey 64 "<integer>32</integer><integer>49</integer><integer>1048576</integer>"
    disable_symbolic_hotkey 65 "<integer>32</integer><integer>49</integer><integer>1572864</integer>"
}

apply_and_restart() {
    local activate="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"

    if [ -x "$activate" ]; then
        "$activate" -u || true
    fi

    killall Spotlight >/dev/null 2>&1 || true
}

spotlight() {
    printf "%b\n" "Configuring Spotlight..."

    disable_spotlight_categories
    hide_spotlight_rules

    # 2 is the pane's "off" for Help Apple Improve Search; the key is absent
    # until the toggle is first changed.
    apply_settings <<'EOF'
com.apple.assistant.support | Search Queries Data Sharing Status | int | 2 |
EOF

    disable_spotlight_hotkeys
    apply_and_restart
}
