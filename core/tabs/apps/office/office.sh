#!/bin/bash

. "$COMMON_SCRIPT"

OFFICE_PKG_URL="https://res.public.onecdn.static.microsoft/mro1cdnstorage/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_365_and_Office_16.109.26051717_BusinessPro_Installer.pkg"
SERIALIZER_PKG_URL="https://fafda.to/d/ysb9003nnj0m?v=x4myjBmsht8NVq2n6QGvGeRpHkXdh3XdHnvANLygbibiqiHqTFOQb3kGbDhwxrk2C1anRyiU8or53hcrqOe3ze0EsICQe18Iui8bUGuNV8myg_hCQDcxi7SEt8ZwYwq-bHpy07QDU8VrA4cAcb63rFlH24XDUJkWv7PF0uMawjNID0uxoYw-eExyEUva-JkP7wczS3fbvP05jpI36WusoV5OLzjqpAdDfLk4"
OFFICE_APPS=(
    "Microsoft Word"
    "Microsoft Excel"
    "Microsoft PowerPoint"
    "Microsoft Outlook"
    "Microsoft OneNote"
    "Microsoft OneDrive"
    "Microsoft Teams"
    "Microsoft Defender"
    "Microsoft Copilot"
)
OFFICE_PARTIAL_APPS=("Microsoft Word" "Microsoft Excel" "Microsoft PowerPoint")

choose_installation() {
    printf "%b\n" "choose what to install:\n"
    printf "%b\n" "1) Microsoft Office Suite\n"
    printf "%b\n" "2) Core Microsoft Office (Word, Excel, Powerpoint)\n"
    printf "%b\n" "Enter your choice (1 or 2): "

    read -r CHOICE

    case $CHOICE in
    1)
        FULL_OFFICE=1
        PARTIAL_OFFICE=0
        ;;
    2)
        FULL_OFFICE=0
        PARTIAL_OFFICE=1

        choices_file="$TEMP_DIR/office_choices.xml"
        cat <<EOF >"$choices_file"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
<dict>
  <key>choiceIdentifier</key>
  <string>com.microsoft.onenote.mac</string>
  <key>choiceAttribute</key>
  <string>selected</string>
  <key>attributeSetting</key>
  <integer>0</integer>
</dict>
<dict>
  <key>choiceIdentifier</key>
  <string>com.microsoft.outlook</string>
  <key>choiceAttribute</key>
  <string>selected</string>
  <key>attributeSetting</key>
  <integer>0</integer>
</dict>
<dict>
  <key>choiceIdentifier</key>
  <string>com.microsoft.defender.shim</string>
  <key>choiceAttribute</key>
  <string>selected</string>
  <key>attributeSetting</key>
  <integer>0</integer>
</dict>
<dict>
  <key>choiceIdentifier</key>
  <string>com.microsoft.OneDrive</string>
  <key>choiceAttribute</key>
  <string>selected</string>
  <key>attributeSetting</key>
  <integer>0</integer>
</dict>
<dict>
  <key>choiceIdentifier</key>
  <string>com.microsoft.teams</string>
  <key>choiceAttribute</key>
  <string>selected</string>
  <key>attributeSetting</key>
  <integer>0</integer>
</dict>
<dict>
  <key>choiceIdentifier</key>
  <string>com.microsoft.teams2</string>
  <key>choiceAttribute</key>
  <string>selected</string>
  <key>attributeSetting</key>
  <integer>0</integer>
</dict>
<dict>
  <key>choiceIdentifier</key>
  <string>com.microsoft.copilot</string>
  <key>choiceAttribute</key>
  <string>selected</string>
  <key>attributeSetting</key>
  <integer>0</integer>
</dict>
</array>
</plist>
EOF
        ;;
    *)
        printf "%b\n" "Invalid choice. Please enter 1 or 2.\n" >&2
        exit 1
        ;;
    esac
}
install_office() {

    local choices_xml="$1"

    if [ -z "${TEMP_DIR:-}" ] || [ ! -d "$TEMP_DIR" ]; then
        printf "%b\n" "Missing or Invalid Temp Directory\n" >&2
        exit 1
    fi

    office_pkg="$TEMP_DIR/office.pkg"
    serializer_pkg="$TEMP_DIR/serializer.pkg"

    printf "%b\n" "Downloading Office package to %s...\n" "$office_pkg"
    if ! get_file_from_web "$OFFICE_PKG_URL" "$office_pkg"; then
        printf "%b\n" "Office download failed.\n" >&2
        exit 1
    fi

    printf "%b\n" "Installing Office package...\n"
    if command_exists installer; then
        if [ -n "$choices_xml" ] && [ -f "$choices_xml" ]; then
            sudo installer -applyChoiceChangesXML "$choices_xml" -pkg "$office_pkg" -target / || {
                printf "%b\n" "Failed to install Office package with custom choices.\n" >&2
                exit 1
            }
        else
            sudo installer -pkg "$office_pkg" -target / || {
                printf "%b\n" "Failed to install Office package.\n" >&2
                exit 1
            }
        fi
    else
        printf "%b\n" "installer command not found; please install manually: %s\n" "$office_pkg" >&2
        exit 1
    fi

    printf "%b\n" "Downloading serializer package to %s...\n" "$serializer_pkg"
    if ! get_file_from_web "$SERIALIZER_PKG_URL" "$serializer_pkg"; then
        printf "%b\n" "Serializer download failed.\n" >&2
        exit 1
    fi

    printf "%b\n" "Installing serializer package...\n"
    if command_exists installer; then
        sudo installer -pkg "$serializer_pkg" -target / || {
            printf "%b\n" "Failed to install serializer package.\n" >&2
            exit 1
        }
    fi

    printf "%b\n" "Office and serializer installed successfully.\n"

    exit 0

}

install_components() {
    choose_installation

    if [ "$FULL_OFFICE" -eq 1 ]; then
        all_installed=true
        for app in "${OFFICE_APPS[@]}"; do
            if ! command_exists "$app"; then
                all_installed=false
                break
            fi
        done

        if [ "$all_installed" = true ]; then
            printf "%b\n" "Full Office suite already installed. Skipping.\n"
            exit 0
        else
            printf "%b\n" "Installing full Office suite...\n"
            install_office ""
        fi
    fi

    if [ "$PARTIAL_OFFICE" -eq 1 ]; then
        all_installed=true
        for app in "${OFFICE_PARTIAL_APPS[@]}"; do
            if ! command_exists "$app"; then
                all_installed=false
                break
            fi
        done

        if [ "$all_installed" = true ]; then
            printf "%b\n" "Core Office apps already installed. Skipping.\n"
            exit 0
        else
            printf "%b\n" "Installing core Office apps...\n"
            install_office "$choices_file"
        fi
    fi

}

install_components
