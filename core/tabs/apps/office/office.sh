#!/bin/sh -e

. "$COMMON_SCRIPT"

OFFICE_PKG_URL="https://officecdnmac.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_365_and_Office_16.105.26011018_Installer.pkg"
SERIALIZER_PKG_URL="https://trashbytes.net/dl/W1nDXBrtIJ72C7prwQ2geNwcz8aF5bhtPKkRSBWlh2BV_1MmH9uXKcACDwH1mMSu8HohphcINbjRzZxnqui-8PiDK6Sb-RcICv70i7PlmpP9hx3g0IlcfWSjZXxyjwnbMPMNBo8JeCRy22BOXhsAmw?v=1769184328-2B4JGHe8M6T77DllMcDyrMOo4S6vgmltmJIbmkyAMBc%3D"

choose_installation(){
  printf "choose what to install:\n"
  printf "1) Install Microsoft Office Suite\n"
  printf "2) Install Microsoft Office (Word, Excel, Powerpoint)\n"
  printf "Enter your choice (1 or 2): "

  read -r CHOICE

  case $CHOICE in
    1)
      FULL_OFFICE=1; PARTIAL_OFFICE=0 ;;
    2)
      FULL_OFFICE=0; PARTIAL_OFFICE=1

choices_file="$TEMP_DIR/office_choices.xml"
      cat << EOF > "$choices_file"
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
</array>
</plist>
EOF
;;
    *)
      printf "Invalid choice. Please enter 1 or 2.\n" >&2
      exit 1
      ;;
  esac
}

installOffice() {

local choices_xml="$1"

if [ -z "${TEMP_DIR:-}" ] || [ ! -d "$TEMP_DIR" ]; then
	printf "Missing or Invalid Temp Directory\n" >&2
	exit 1
fi

if command_exists "Microsoft Word"; then
 printf "Microsoft Office is already installed.\n"
 exit 0
fi

office_pkg="$TEMP_DIR/office.pkg"
serializer_pkg="$TEMP_DIR/serializer.pkg"

printf "Downloading Office package to %s...\n" "$office_pkg"
if ! get_file_from_web "$OFFICE_PKG_URL" "$office_pkg"; then
	printf "Office download failed.\n" >&2
	exit 1
fi

printf "Installing Office package...\n"
  if command_exists installer; then
    if [ -n "$choices_xml" ] && [ -f "$choices_xml" ]; then
      sudo installer -applyChoiceChangesXML "$choices_xml" -pkg "$office_pkg" -target / || {
        printf "Failed to install Office package with custom choices.\n" >&2
        exit 1
      }
    else
      sudo installer -pkg "$office_pkg" -target / || {
        printf "Failed to install Office package.\n" >&2
        exit 1
      }
    fi
  else
    printf "installer command not found; please install manually: %s\n" "$office_pkg" >&2
    exit 1
  fi

printf "Downloading serializer package to %s...\n" "$serializer_pkg"
if ! get_file_from_web "$SERIALIZER_PKG_URL" "$serializer_pkg"; then
	printf "Serializer download failed.\n" >&2
	exit 1
fi

printf "Installing serializer package...\n"
if command_exists installer; then
	sudo installer -pkg "$serializer_pkg" -target / || {
		printf "Failed to install serializer package.\n" >&2
		exit 1
	}
fi

printf "Office and serializer installed successfully.\n"

exit 0

}

install_components() {
  choose_installation

  if ["$FULL_OFFICE" -eq 1]; then
   installOffice ""
  fi
  if ["$PARTIAL_OFFICE" -eq 1]; then
   installOffice "$choices_file"
  fi
}

install_components

