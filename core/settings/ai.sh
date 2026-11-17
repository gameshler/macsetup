#!/usr/bin/env bash

# Apple Intelligence: opt out, and remove the AI apps that can be removed.
# Sourced by core/tabs/system/optimize-settings.sh, which runs it.

# Installed by the Office package as its own receipt, signed by Microsoft;
# nothing else in the suite depends on it. Apps under /System are on the
# sealed volume and cannot be removed without turning SIP off.
COPILOT_SHIM_APP="/Applications/Microsoft 365 Copilot Shim.app"
COPILOT_SHIM_RECEIPT="com.microsoft.m365copilot.shim"

remove_copilot_shim() {
    local state="installed"

    [ -d "$COPILOT_SHIM_APP" ] || return 0

    printf "%b\n" "Removing Microsoft 365 Copilot Shim..."
    sudo rm -rf -- "$COPILOT_SHIM_APP" </dev/null 2>/dev/null || true

    [ -e "$COPILOT_SHIM_APP" ] || state="removed"
    verify_value "Microsoft 365 Copilot Shim" "removed" "$state" exact || return 0

    sudo pkgutil --forget "$COPILOT_SHIM_RECEIPT" </dev/null >/dev/null 2>&1 || true
}

disable_ai() {
    printf "%b\n" "Turning off Apple Intelligence..."

    apply_settings <<'EOF'
com.apple.CloudSubscriptionFeatures.optIn | 545129924 | bool | false |
EOF

    remove_copilot_shim
}
