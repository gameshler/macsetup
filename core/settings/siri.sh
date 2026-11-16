#!/usr/bin/env bash

# Siri suggestions: turn them off in every app the pane lists.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

# The apps "Siri Suggestions & Privacy" lists on macOS 27.2.1, as the pane
# wrote them when each "Show Siri Suggestions in application" was unchecked.
SIRI_SUGGESTION_APPS='com.apple.iBooksX com.apple.iCal com.apple.AddressBook
com.apple.FaceTime com.apple.mail com.apple.Maps com.apple.MobileSMS
com.apple.news com.apple.podcasts com.apple.reminders com.apple.Safari'

disable_siri_suggestions() {
    printf "%b\n" "Turning off Siri suggestions in every app..."

    # shellcheck disable=SC2086 # one bundle id per word
    ensure_listed com.apple.suggestions AppCanShowSiriSuggestionsBlacklist $SIRI_SUGGESTION_APPS
}
