#!/bin/sh -e

. "$COMMON_SCRIPT"

fix_finder() {
    printf "%b\n" "Applying global theme settings for Finder..."

    # Set the default Finder view to list view
    printf "%b\n" "Setting default Finder view to list view..."
    sudo defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

    # Configure list view settings for all folders
    printf "%b\n" "Configuring list view settings for all folders..."
    # Set default list view settings for new folders
    sudo defaults write com.apple.finder FK_StandardViewSettings -dict-add ListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'

    # Clear existing folder view settings to force use of default settings
    printf "%b\n" "Clearing existing folder view settings..."
    sudo defaults delete com.apple.finder FXInfoPanesExpanded 2>/dev/null || true
    sudo defaults delete com.apple.finder FXDesktopVolumePositions 2>/dev/null || true

    # Set list view for all view types
    printf "%b\n" "Setting list view for all folder types..."
    sudo defaults write com.apple.finder FK_StandardViewSettings -dict-add ExtendedListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'

    # Sets default search scope to the current folder
    printf "%b\n" "Setting default search scope to the current folder..."
    sudo defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

    # Remove trash items older than 30 days
    printf "%b\n" "Removing trash items older than 30 days..."
    sudo defaults write com.apple.finder "FXRemoveOldTrashItems" -bool "true"

    # Remove .DS_Store files to reset folder view settings
    printf "%b\n" "Removing .DS_Store files to reset folder view settings..."
    find ~ -name ".DS_Store" -type f -delete 2>/dev/null || true

    # Show all filename extensions
    printf "%b\n" "Showing all filename extensions in Finder..."
    sudo defaults write NSGlobalDomain AppleShowAllExtensions -bool true

    # Set the sidebar icon size to small
    printf "%b\n" "Setting sidebar icon size to small..."
    sudo defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1

    # Show status bar in Finder
    printf "%b\n" "Showing status bar in Finder..."
    sudo defaults write com.apple.finder ShowStatusBar -bool true

    # Show path bar in Finder
    printf "%b\n" "Showing path bar in Finder..."
    sudo defaults write com.apple.finder ShowPathbar -bool true

    # Clean up Finder's sidebar
    printf "%b\n" "Cleaning up Finder's sidebar..."
    sudo defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true
    sudo defaults write com.apple.finder SidebarPlacesSectionDisclosedState -bool true
    sudo defaults write com.apple.finder SidebarShowingiCloudDesktop -bool false

    # Restart Finder to apply changes
    printf "%b\n" "Finder has been restarted and settings have been applied."
    sudo killall Finder
}

fix_finder
