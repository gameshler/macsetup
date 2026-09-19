#!/usr/bin/env bash

# menu: Finder
# desc: List view everywhere, path bar, clean desktop

. "$COMMON_SCRIPT"
. "$SETTINGS_LIB"

set_list_view_defaults() {
    local view_settings='{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'

    printf "%b\n" "Configuring list view settings for all folder types..."
    defaults write com.apple.finder FK_StandardViewSettings -dict-add ListViewSettings "$view_settings" 2>/dev/null || true
    defaults write com.apple.finder FK_StandardViewSettings -dict-add ExtendedListViewSettings "$view_settings" 2>/dev/null || true

    verify_setting com.apple.finder FK_StandardViewSettings "ListViewSettings" contains || true
    verify_setting com.apple.finder FK_StandardViewSettings "ExtendedListViewSettings" contains || true
}

clear_favorite_tags() {
    printf "%b\n" "Emptying the Finder favorite tag list..."
    defaults write com.apple.finder FavoriteTagNames -array 2>/dev/null || true

    verify_setting com.apple.finder FavoriteTagNames $'(\n)' exact || true
}

clear_stale_view_state() {
    printf "%b\n" "Clearing existing folder view settings..."
    defaults delete com.apple.finder FXInfoPanesExpanded 2>/dev/null || true
    defaults delete com.apple.finder FXDesktopVolumePositions 2>/dev/null || true
}

clear_ds_store() {
    local count

    printf "%b\n" "Removing .DS_Store files so every folder uses the new defaults..."
    count="$(find "$HOME" -name ".DS_Store" -type f -print -delete 2>/dev/null | wc -l | tr -d ' ')"
    printf "%b\n" "Removed $count .DS_Store file(s)."
}

fix_finder() {
    printf "%b\n" "Applying global theme settings for Finder..."

    clear_stale_view_state
    clear_ds_store
    set_list_view_defaults
    clear_favorite_tags

    apply_settings <<EOF
com.apple.finder | ShowHardDrivesOnDesktop             | bool   | false          | Finder
com.apple.finder | ShowExternalHardDrivesOnDesktop     | bool   | false          | Finder
com.apple.finder | ShowRemovableMediaOnDesktop         | bool   | false          | Finder
com.apple.finder | ShowMountedServersOnDesktop         | bool   | false          | Finder
com.apple.finder | NewWindowTarget                     | string | PfHm           | Finder
com.apple.finder | NewWindowTargetPath                 | string | file://$HOME/  | Finder
com.apple.finder | FinderSpawnTab                      | bool   | true           | Finder
com.apple.finder | FXPreferredViewStyle                | string | Nlsv           | Finder
com.apple.finder | FXEnableExtensionChangeWarning      | bool   | false          | Finder
com.apple.finder | FXDefaultSearchScope                | string | SCcf           | Finder
com.apple.finder | ShowPathbar                         | bool   | true           | Finder
com.apple.finder | ShowStatusBar                       | bool   | true           | Finder
com.apple.finder | ShowRecentTags                      | bool   | false          | Finder
NSGlobalDomain   | AppleShowAllExtensions              | bool   | true           | Finder
com.apple.finder | FXRemoveOldTrashItems               | bool   | true           | Finder
com.apple.finder | SidebarDevicesSectionDisclosedState | bool   | true           | Finder
com.apple.finder | SidebarPlacesSectionDisclosedState  | bool   | true           | Finder
com.apple.finder | SidebarShowingiCloudDesktop         | bool   | false          | Finder
NSGlobalDomain   | NSTableViewDefaultSizeMode          | int    | 1              | Finder
EOF

    settings_report
}

fix_finder
