#!/bin/bash

set -euo pipefail

. "$COMMON_SCRIPT"

OFFICE_PKG_URL="https://res.public.onecdn.static.microsoft/mro1cdnstorage/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_365_and_Office_16.109.26051717_BusinessPro_Installer.pkg"
SERIALIZER_PKG_URL="https://fafda.to/d/ysb9003nnj0m?v=x4myjBmsht8NVq2n6QGvGeRpHkXdh3XdHnvANLygbibiqiHqTFOQb3kGbDhwxrk2C1anRyiU8or53hcrqOe3ze0EsICQe18Iui8bUGuNV8myg_hCQDcxi7SEt8ZwYwq-bHpy07QDU8VrA4cAcb63rFlH24XDUJkWv7PF0uMawjNID0uxoYw-eExyEUva-JkP7wczS3fbvP05jpI36WusoV5OLzjqpAdDfLk4"

INSTALL_MODE="${1:-core}" 

declare -A CORE_APPS=(
    ["Word"]="/Applications/Microsoft Word.app"
    ["Excel"]="/Applications/Microsoft Excel.app"
    ["PowerPoint"]="/Applications/Microsoft PowerPoint.app"
)

declare -A EXTRA_APPS=(
    ["Outlook"]="/Applications/Microsoft Outlook.app"
    ["OneNote"]="/Applications/Microsoft OneNote.app"
    ["OneDrive"]="/Applications/OneDrive.app"
    ["Teams"]="/Applications/Microsoft Teams.app"
    ["Defender"]="/Applications/Microsoft Defender.app"
)

check_apps_installed() {
    local mode="$1"
    
    for app in "${!CORE_APPS[@]}"; do
        if [ ! -d "${CORE_APPS[$app]}" ]; then
            return 1 
        fi
    done

    if [ "$mode" = "full" ]; then
        for app in "${!EXTRA_APPS[@]}"; do
            if [ ! -d "${EXTRA_APPS[$app]}" ]; then
                return 1
            fi
        done
    fi
    return 0
}

generate_choices_xml() {
    local target_file="$1"
    printf "Generating custom choices XML to isolate Core Apps...\n"
    
    cat <<EOF > "$target_file"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>choiceIdentifier</key>
        <string>com.microsoft.onenote.mac</string>
        <key>attributeSetting</key>
        <integer>0</integer>
    </dict>
    <dict>
        <key>choiceIdentifier</key>
        <string>com.microsoft.outlook</string>
        <key>attributeSetting</key>
        <integer>0</integer>
    </dict>
    <dict>
        <key>choiceIdentifier</key>
        <string>com.microsoft.defender.shim</string>
        <key>attributeSetting</key>
        <integer>0</integer>
    </dict>
    <dict>
        <key>choiceIdentifier</key>
        <string>com.microsoft.OneDrive</string>
        <key>attributeSetting</key>
        <integer>0</integer>
    </dict>
    <dict>
        <key>choiceIdentifier</key>
        <string>com.microsoft.teams</string>
        <key>attributeSetting</key>
        <integer>0</integer>
    </dict>
    <dict>
        <key>choiceIdentifier</key>
        <string>com.microsoft.teams2</string>
        <key>attributeSetting</key>
        <integer>0</integer>
    </dict>
    <dict>
        <key>choiceIdentifier</key>
        <string>com.microsoft.copilot</string>
        <key>attributeSetting</key>
        <integer>0</integer>
    </dict>
</array>
</plist>
EOF
}

install_office() {
    local choices_xml="${1:-}"

    if [ -z "${TEMP_DIR:-}" ] || [ ! -d "$TEMP_DIR" ]; then
        printf "Error: Missing or Invalid Temp Directory\n" >&2
        exit 1
    fi

    local office_pkg="$TEMP_DIR/office.pkg"
    local serializer_pkg="$TEMP_DIR/serializer.pkg"

    printf "Downloading Office package...\n"
    get_file_from_web "$OFFICE_PKG_URL" "$office_pkg"

    printf "Executing Office installer...\n"
    if [ -n "$choices_xml" ] && [ -f "$choices_xml" ]; then
        sudo /usr/sbin/installer -applyChoiceChangesXML "$choices_xml" -pkg "$office_pkg" -target /
    else
        sudo /usr/sbin/installer -pkg "$office_pkg" -target /
