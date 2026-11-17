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

# Written by the macOS 27 pane when Show Related Content, the results from
# system items (applications, files, folders, iPhone apps, menu items) and
# each Files subcategory (Developer, Documents, Images, Movies, Music, Others,
# PDFs, Presentations, Spreadsheets) are turned off. Despite the key's name, a
# listed rule hides its results.
SPOTLIGHT_HIDDEN_RULES='Custom.relatedContents System.applications System.files
System.folders System.iphoneApps System.menuItems Domain.SOURCE System.documents
Domain.IMAGES Domain.MOVIES Domain.MUSIC Domain.MENU_OTHER Domain.PDF
Domain.PRESENTATIONS Domain.SPREADSHEETS'

# The file types those subcategories cover, as the pane wrote them on 27.2.1.
SPOTLIGHT_DISABLED_TYPES='com.adobe.pdf com.apple.applescript.alias-object
com.apple.applescript.data-object com.apple.applescript.text-object
com.apple.applescript.url-object com.apple.coreanimation-bundle
com.apple.coreanimation-xml com.apple.dashcode.css
com.apple.dashcode.javascript com.apple.dashcode.json
com.apple.dashcode.manifest com.apple.dashcode.xml
com.apple.dt.bundle.unit-test.objective-c com.apple.dt.document.scheme
com.apple.dt.document.snapshot com.apple.dt.document.workspace
com.apple.dt.dvt.plug-in com.apple.dt.ide.plug-in com.apple.dt.playground
com.apple.instruments.tracetemplate com.apple.interfacebuilder.document
com.apple.interfacebuilder.document.cocoa com.apple.iphone.developerprofile
com.apple.iphone.mobileprovision com.apple.iwork.keynote.key
com.apple.iwork.numbers.numbers com.apple.iwork.numbers.sffnumbers
com.apple.iwork.numbers.template com.apple.keynote.key
com.apple.localized-pdf-bundle com.apple.mach-o-binary
com.apple.mach-o-executable com.apple.mach-o-object com.apple.property-list
com.apple.protected-mpeg-4-audio com.apple.quartzdebug.introspectiontrace
com.apple.quicktime-movie com.apple.rez-source
com.apple.scripting-definition com.apple.symbol-export
com.apple.x11-mach-o-executable com.apple.xcode.archive
com.apple.xcode.configsettings com.apple.xcode.docset com.apple.xcode.dsym
com.apple.xcode.model com.apple.xcode.mom com.apple.xcode.plugin
com.apple.xcode.plugindata com.apple.xcode.project
com.apple.xcode.projectdata com.apple.xcode.strings-text
com.apple.xcode.usersettings com.microsoft.excel.sheet.binary.macroenabled
com.microsoft.excel.xls com.microsoft.powerpoint.ppt
com.microsoft.windows-dynamic-link-library com.microsoft.windows-executable
com.sun.java-archive com.sun.java-class com.sun.web-application-archive
dyn.ah62d4rv4ge80u5pbsa dyn.ah62d4rv4ge81a7dk
org.openxmlformats.spreadsheetml.sheet
org.openxmlformats.spreadsheetml.sheet.macroenabled public.3gpp public.3gpp2
public.audio public.html public.image public.movie public.mpeg public.mpeg-4
public.mpeg-4-audio public.mpeg-video public.object-code public.presentation
public.shell-script public.source-code public.spreadsheet
public.unix-executable public.xhtml public.xml'

hide_spotlight_rules() {
    printf "%b\n" "Hiding related content, system items and file types from Spotlight..."

    # shellcheck disable=SC2086 # one rule per word
    ensure_listed com.apple.Spotlight EnabledPreferenceRules $SPOTLIGHT_HIDDEN_RULES
    # shellcheck disable=SC2086 # one type per word
    ensure_listed com.apple.Spotlight DisabledUTTypes $SPOTLIGHT_DISABLED_TYPES
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
